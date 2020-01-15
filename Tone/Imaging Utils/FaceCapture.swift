//
//  FaceCapture.swift
//  Tone
//
//  Wraps around an Image, its metadata, and the facial landmarks
//  Can calculate facial landmarks with getFacialLandmarks. Automatically run in FaceCapture::Create
//  Provides some helper methods for handling facial landmarks and sampling data from the image
//
//  Created by Doug MacEwen on 4/10/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit
import RxSwift
import Vision

class FaceCapture {
    private var pixelBuffer: CVPixelBuffer?
    let orientation: CGImagePropertyOrientation
    let flashSettings: FlashSettings
    let imageSize: ImageSize
    let rawMetadata: [String: Any]
    let exposurePoint: NormalizedImagePoint?
    
    //Keep private to keep us from accessing in its raw form (it can be kind of confusing/messy to interact with)
    private var faceLandmarks: VNFaceLandmarks2D
    private var isLocked = false
    
    init(pixelBuffer: CVPixelBuffer,
         faceLandmarks: VNFaceLandmarks2D,
         orientation: CGImagePropertyOrientation,
         flashSettings: FlashSettings = FlashSettings(),
         rawMetadata: [String: Any],
         exposurePoint: NormalizedImagePoint?) {

        self.pixelBuffer = pixelBuffer
        self.faceLandmarks = faceLandmarks
        self.orientation = orientation
        self.flashSettings = flashSettings
        self.imageSize = ImageSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        self.rawMetadata = rawMetadata
        self.exposurePoint = exposurePoint
    }

    static func create(pixelBuffer: CVPixelBuffer,
                       orientation: CGImagePropertyOrientation,
                       flashSettings: FlashSettings = FlashSettings(),
                       metadata: [String: Any] = [:],
                       exposurePoint: NormalizedImagePoint? = nil) -> Observable<FaceCapture?> {
        
        return FaceCapture.getFaceLandmarks(pixelBuffer, orientation)
            .map { faceLandmarks in
                guard let foundFaceLandmarks = faceLandmarks else { return nil }
                
                return FaceCapture(pixelBuffer: pixelBuffer,
                                   faceLandmarks: foundFaceLandmarks,
                                   orientation: orientation,
                                   flashSettings: flashSettings,
                                   rawMetadata: metadata,
                                   exposurePoint: exposurePoint)
            }
    }

    private static func getFaceLandmarks(_ pixelBuffer: CVPixelBuffer, _ orientation: CGImagePropertyOrientation) -> Observable<VNFaceLandmarks2D?> {
        //Wraps the facial landmarking async call as an observable
        return Observable<VNFaceLandmarks2D?>.create { [unowned pixelBuffer] observable in
            DispatchQueue.global(qos: .userInitiated).async {[unowned pixelBuffer] in
                var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
                
                let cameraIntrinsicData = CMGetAttachment(pixelBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil)
                if cameraIntrinsicData != nil {
                    requestHandlerOptions[VNImageOption.cameraIntrinsics] = cameraIntrinsicData
                }
                
                let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                                orientation: orientation,
                                                                options: requestHandlerOptions)
                
            
                let faceLandmarksRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request, error) in
                    if error != nil {
                        print("FaceLandmarks error: \(String(describing: error)).")
                        observable.onNext(nil)
                        observable.onCompleted()
                    }
                    
                    guard let landmarksRequest = request as? VNDetectFaceLandmarksRequest,
                        let results = landmarksRequest.results as? [VNFaceObservation] else {
                            observable.onNext(nil)
                            observable.onCompleted()
                            return
                    }
                    
                    if results.count > 0 {
                        observable.onNext(results[0].landmarks)
                        observable.onCompleted()
                    } else {
                        observable.onNext(nil)
                        observable.onCompleted()
                    }
                })

                //3 is better but will need to rework things for the new landmarks. Also, New 76 point contellation could be nice in the future too
                faceLandmarksRequest.revision = VNDetectFaceLandmarksRequestRevision2 
                
                do {
                    try imageRequestHandler.perform([faceLandmarksRequest])
                } catch {
                    print("Failed to perform FaceLandmarkRequest: \(error)")
                }
            }
            
            return Disposables.create()
        }
    }
    
    func lock() {
        precondition(!isLocked)
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags.readOnly)
        self.isLocked = true
    }
    
    func unlock() {
        precondition(isLocked)
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags.readOnly)
        self.isLocked = false
    }
    
    //Every Coordinate passed out as a CGPoint, CGRect, CGVec, CGSize should be in ImageCood
    private func isValidPoint(_ point: ImagePoint) -> Bool {
        return self.imageSize.size.contains(point: point.point)
    }
    
    func sampleRegionIntensity(center: ImagePoint) -> CGFloat? {
        precondition(isLocked)
        if !self.isValidPoint(center) { return nil }
        
        //One more grid/orientation to be aware of...
        let orientedCenter = CVImageBufferIsFlipped(self.pixelBuffer!) ? ImagePoint.init(x: center.x, y: self.imageSize.height - center.y) : center
        
        let halfSideLength = CGFloat(7)
        
        let start = ImagePoint.init(x: orientedCenter.x - halfSideLength, y: orientedCenter.y - halfSideLength)
        let end = ImagePoint.init(x: orientedCenter.x + halfSideLength, y: orientedCenter.y + halfSideLength)
        
        if !self.isValidPoint(start) || !self.isValidPoint(end) { return nil }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(self.pixelBuffer!)
        guard let baseAddress = CVPixelBufferGetBaseAddress(self.pixelBuffer!) else { return nil }
        let byteBuffer = baseAddress.assumingMemoryBound(to: UInt8.self)

        var sum = 0
        var counter = 0
        for y in Int(start.y) ..< Int(end.y) {
            let bufferRowOffset = y * bytesPerRow
            for x in Int(start.x) ..< Int(end.x) {
                let bufferIndex = bufferRowOffset + (x * 4) //Index into the buffer
                if bufferIndex % 5 == 0 {
                    sum += Int(byteBuffer[bufferIndex]) + Int(byteBuffer[bufferIndex + 1]) + Int(byteBuffer[bufferIndex + 2])
                    counter += 3
                }
            }
        }

        return CGFloat(sum) / CGFloat(counter)
    }
    
    func sampleRegionIntensitySmall(center: ImagePoint) -> CGFloat? {
        precondition(isLocked)
        if !self.isValidPoint(center) { return nil }
        if !self.isValidPoint(ImagePoint.init(x: center.x - 1, y: center.y - 1)) { return nil }
        if !self.isValidPoint(ImagePoint.init(x: center.x + 1, y: center.y + 1)) { return nil }
        //One more grid/orientation to be aware of...
        let orientedCenter = CVImageBufferIsFlipped(self.pixelBuffer!) ? ImagePoint.init(x: center.x, y: self.imageSize.height - center.y) : center
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(self.pixelBuffer!)
        guard let baseAddress = CVPixelBufferGetBaseAddress(self.pixelBuffer!) else { return nil }
        let byteBuffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        let offsets = [-1, 0, 1]
        var sum: UInt = 0
        
        let xStart = (Int(orientedCenter.x) - 1) * 4
        let xEnd = (Int(orientedCenter.x) + 1) * 4
        
        for yOffset in offsets {
            let y = (Int(orientedCenter.y) + yOffset) * bytesPerRow
            let start = y + xStart
            let end = y + xEnd
            
            for subpixelIndex in start...end {
                sum += UInt(byteBuffer[subpixelIndex])
            }
        }
        
        return CGFloat(sum) / CGFloat(36)
    }
    
    func getAllImagePoints() -> [ImagePoint]? {
        guard let allPoints = self.faceLandmarks.allPoints else { return nil }
        return allPoints.pointsInImage(imageSize: self.imageSize.toLandmarkSize().size).map { LandmarkPoint($0).toImagePoint(size: self.imageSize) }
    }
    
    func getAllPointsBB() -> CGRect? {
        guard let allPoints = self.getAllImagePoints() else { return nil }
        return CGRect.fromPoints(points: allPoints.map { $0.point },  imgSize: self.imageSize.size)
    }
    
    func getAllPointsSize() -> CGSize? {
        guard let allPointsBB = self.getAllPointsBB() else { return nil }
        return CGSize.from(rect: allPointsBB)
    }
    
    func getLeftEyeImageBB() -> CGRect? {
        guard let leftEye = self.faceLandmarks.leftEye else { return nil }
        let leftEyePoints = leftEye.pointsInImage(imageSize: self.imageSize.toLandmarkSize().size).map { LandmarkPoint($0).toImagePoint(size: self.imageSize) }
        return CGRect.fromPoints(points: leftEyePoints.map { $0.point }, imgSize: self.imageSize.size)
    }
    
    func getLeftEyeImageSize() -> CGSize? {
        guard let leftEyeBB = self.getLeftEyeImageBB() else { return nil }
        return CGSize.from(rect: leftEyeBB)
    }
    
    func getRightEyeImageBB() -> CGRect? {
        guard let rightEye = self.faceLandmarks.rightEye else { return nil }
        let rightEyePoints = rightEye.pointsInImage(imageSize: self.imageSize.toLandmarkSize().size).map { LandmarkPoint($0).toImagePoint(size: self.imageSize) }
        return CGRect.fromPoints(points: rightEyePoints.map { $0.point }, imgSize: self.imageSize.size)
    }
    
    func getRightEyeImageSize() -> CGSize? {
        guard let rightEyeBB = self.getRightEyeImageBB() else { return nil }
        return CGSize.from(rect: rightEyeBB)
    }

    func getImage() -> Image {
        let image = CIImage.init(cvImageBuffer: self.pixelBuffer!)
        let landmarks = self.getAllImagePoints()!
        return Image(image: image, landmarks: landmarks.map { $0.point })
    }
}
