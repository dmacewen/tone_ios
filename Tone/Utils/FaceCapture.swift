//
//  FaceCapture.swift
//  Tone
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
    let pixelBuffer: CVPixelBuffer
    let orientation: CGImagePropertyOrientation
    let videoPreviewLayer: AVCaptureVideoPreviewLayer
    let flashSettings: FlashSettings
    let imageSize: ImageSize
    let rawMetadata: [String: Any]
    
    //Keep private to keep us from accessing in its raw form (it can be kind of confusing/messy to interact with)
    private var faceLandmarks: VNFaceLandmarks2D
    private var isLocked = false
    
    init(pixelBuffer: CVPixelBuffer, faceLandmarks: VNFaceLandmarks2D, orientation: CGImagePropertyOrientation, videoPreviewLayer: AVCaptureVideoPreviewLayer, flashSettings: FlashSettings = FlashSettings(), rawMetadata: [String: Any]) {
        self.pixelBuffer = pixelBuffer
        self.faceLandmarks = faceLandmarks
        self.orientation = orientation
        self.videoPreviewLayer = videoPreviewLayer
        self.flashSettings = flashSettings
        self.imageSize = ImageSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        self.rawMetadata = rawMetadata
    }
    
    static func create(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, videoPreviewLayer: AVCaptureVideoPreviewLayer, flashSettings: FlashSettings = FlashSettings()) -> Observable<FaceCapture?> {
        
        return FaceCapture.getFaceLandmarks(pixelBuffer, orientation)
            .map { faceLandmarks in
                guard let foundFaceLandmarks = faceLandmarks else { return nil }
                
                return FaceCapture(pixelBuffer: pixelBuffer, faceLandmarks: foundFaceLandmarks, orientation: orientation, videoPreviewLayer: videoPreviewLayer, flashSettings: flashSettings, rawMetadata: [:])
            }
    }
    
    static func create(capturePhoto: AVCapturePhoto, orientation: CGImagePropertyOrientation, videoPreviewLayer: AVCaptureVideoPreviewLayer, flashSettings: FlashSettings = FlashSettings()) -> Observable<FaceCapture?> {
        
        return FaceCapture.getFaceLandmarks(capturePhoto.pixelBuffer!, orientation)
            .map { faceLandmarks in
                guard let foundFaceLandmarks = faceLandmarks else { return nil }
                
                return FaceCapture(pixelBuffer: capturePhoto.pixelBuffer!, faceLandmarks: foundFaceLandmarks, orientation: orientation, videoPreviewLayer: videoPreviewLayer, flashSettings: flashSettings, rawMetadata: capturePhoto.metadata)
            }
    }

    private static func getFaceLandmarks(_ pixelBuffer: CVPixelBuffer, _ orientation: CGImagePropertyOrientation) -> Observable<VNFaceLandmarks2D?> {
        return Observable<VNFaceLandmarks2D?>.create { observable in
            var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
            
            let cameraIntrinsicData = CMGetAttachment(pixelBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil)
            if cameraIntrinsicData != nil {
                requestHandlerOptions[VNImageOption.cameraIntrinsics] = cameraIntrinsicData
            }
            
            let faceLandmarksRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request, error) in
                if error != nil {
                    print("FaceLandmarks error: \(String(describing: error)).")
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
            
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                            orientation: orientation,
                                                            options: requestHandlerOptions)
            
            do {
                try imageRequestHandler.perform([faceLandmarksRequest])
            } catch let error as NSError {
                NSLog("Failed to perform FaceLandmarkRequest: %@", error)
                fatalError("Error Landmarking")
            }
            
            return Disposables.create()
        }
    }
    
    func lock() {
        precondition(!isLocked)
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
        self.isLocked = true
    }
    
    func unlock() {
        precondition(isLocked)
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
        self.isLocked = false
    }
    
    //Every Coordinate passed out as a CGPoint, CGRect, CGVec, CGSize should be in ImageCood
    private func isValidPoint(_ point: ImagePoint) -> Bool {
        return self.imageSize.size.contains(point: point.point)
    }
    
    func sampleRegion(center: ImagePoint) -> CGFloat? {
        precondition(isLocked)
        if !self.isValidPoint(center) { return nil }
        
        let sideLength = 15
        let halfSideLength = floor(CGFloat(sideLength - 1) / 2)
        
        let start = ImagePoint.init(x: center.point.x - halfSideLength, y: center.point.y - halfSideLength)
        let end = ImagePoint.init(x: center.point.x + halfSideLength, y: center.point.y + halfSideLength)
        
        if !self.isValidPoint(start) || !self.isValidPoint(end) { return nil }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(self.pixelBuffer)
        guard let baseAddress = CVPixelBufferGetBaseAddress(self.pixelBuffer) else { return nil }
        let byteBuffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        var sum = 0
        for y in Int(start.point.y) ..< Int(end.point.y) {
            let bufferRowOffset = y * bytesPerRow
            for x in Int(start.point.x) ..< Int(end.point.x) {
                let bufferIndex = bufferRowOffset + (x * 4) //Index into the buffer
                sum += Int(byteBuffer[bufferIndex]) + Int(byteBuffer[bufferIndex + 1]) + Int(byteBuffer[bufferIndex + 2])
            }
        }
        
        let averageSubpixelValue = CGFloat(sum) / CGFloat(pow((2 * halfSideLength) + 1, 2)) // Area of the sample x 3 sub pixels each
        
        return averageSubpixelValue
    }
/*
    func getJawDisplayPoints() -> [DisplayPoint]? {
        guard let faceContour = self.faceLandmarks.faceContour else { return nil }
        
        return faceContour
            .pointsInImage(imageSize: self.imageSize.toLandmarkSize().size)
            .map { LandmarkPoint($0).toDisplayPoint(size: self.imageSize) }
    }
 */
    
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
        let image = CIImage.init(cvImageBuffer: self.pixelBuffer)
        let landmarks = self.getAllImagePoints()!
        return Image(image: image, landmarks: landmarks.map { $0.point })
    }
}

//3 Coord Systems. Landmark, Display, Buffer/Image
// - Landmark: Origin at bottom left of Portrait image
// - Display: Origin at top left of Portrait image
// - Image/Buffer: Origin at top left of LANDSCAPE iamge

//Points as returned by the landmarking function
struct LandmarkPoint {
    let point: CGPoint
    
    init(_ point: CGPoint) {
        self.point = point
    }
    
    init(x: CGFloat, y: CGFloat) {
        self.point = CGPoint.init(x: x, y: y)
    }
    
    init(x: Int, y: Int) {
        self.point = CGPoint.init(x: x, y: y)
    }
    
    func toImagePoint(size: ImageSize) -> ImagePoint {
        let landmarkSize = size.toLandmarkSize()
        let newX = landmarkSize.size.height - self.point.y
        let newY = landmarkSize.size.width - self.point.x
        return ImagePoint(x: newX, y: newY)
    }
    
    func toDisplayPoint(size: ImageSize, videoLayer: AVCaptureVideoPreviewLayer) -> DisplayPoint {
        let imagePoint = self.toImagePoint(size: size)
        return imagePoint.toDisplayPoint(size: size, videoLayer: videoLayer)
    }
}

struct LandmarkSize {
    let size: CGSize
    
    init(_ size: CGSize) {
        self.size = size
    }
    
    init(width: CGFloat, height: CGFloat) {
        self.size = CGSize.init(width: width, height: height)
    }

    init(width: Int, height: Int) {
        self.size = CGSize.init(width: width, height: height)
    }
    
    func toImageSize() -> ImageSize {
        let newSize = CGSize(width: self.size.height, height: self.size.width)
        return ImageSize(newSize)
    }
    
    func toDisplaySize(videoLayer: AVCaptureVideoPreviewLayer) -> DisplaySize {
        return self.toImageSize().toDisplaySize(videoLayer: videoLayer)
    }
}

//Points in the native image buffer
struct ImagePoint {
    let point: CGPoint
    
    init(_ point: CGPoint) {
        self.point = point
    }
    
    init(x: CGFloat, y: CGFloat) {
        self.point = CGPoint.init(x: x, y: y)
    }
    
    init(x: Int, y: Int) {
        self.point = CGPoint.init(x: x, y: y)
    }
    
    func toLandmarkPoint(size: ImageSize) -> LandmarkPoint {
        let newX = size.size.height - self.point.y
        let newY = size.size.width - self.point.x
        return LandmarkPoint(x: newX, y: newY)
    }

    func toDisplayPoint(size: ImageSize, videoLayer: AVCaptureVideoPreviewLayer) -> DisplayPoint {
        let normalizedImagePoint = self.toNormalizedImagePoint(size: size)
        let normalizedX = normalizedImagePoint.point.x
        let normalizedY = 1 - normalizedImagePoint.point.y
        return DisplayPoint.init(videoLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint.init(x: normalizedX, y: normalizedY))) //Needs to be 0.0 - 1.0
    }
    
    func toNormalizedImagePoint(size: ImageSize) -> NormalizedImagePoint {
        let normalizedX = self.point.x / size.size.width
        let normalizedY = self.point.y / size.size.height
        return NormalizedImagePoint.init(x: normalizedX, y: normalizedY)
    }
}

struct NormalizedImagePoint {
    let point: CGPoint
    
    init(_ point: CGPoint) {
        self.point = point
    }
    
    init(x: CGFloat, y: CGFloat) {
        self.point = CGPoint.init(x: x, y: y)
    }
    
    init(x: Int, y: Int) {
        self.point = CGPoint.init(x: x, y: y)
    }
}

struct ImageSize {
    let size: CGSize
    
    init(_ size: CGSize) {
        self.size = size
    }
    
    init(width: CGFloat, height: CGFloat) {
        self.size = CGSize.init(width: width, height: height)
    }
    
    init(width: Int, height: Int) {
        self.size = CGSize.init(width: width, height: height)
    }
    
    func toLandmarkSize() -> LandmarkSize {
        let newSize = CGSize(width: self.size.height, height: self.size.width)
        return LandmarkSize(newSize)
    }
    
    func toDisplaySize(videoLayer: AVCaptureVideoPreviewLayer) -> DisplaySize {
        let imageBoundsPoint = ImagePoint.init(x: self.size.width, y: self.size.height)
        let displayBoundsPoint = imageBoundsPoint.toDisplayPoint(size: self, videoLayer: videoLayer)
        return DisplaySize.init(width: displayBoundsPoint.point.x, height: displayBoundsPoint.point.y)
    }
}


struct DisplayPoint {
    let point: CGPoint
    var color = UIColor.black.cgColor

    init(_ point: CGPoint) {
        self.point = point
    }
    
    init(_ point: CGPoint, color: CGColor) {
        self.point = point
        self.color = color
    }
    
    init(x: CGFloat, y: CGFloat) {
        self.point = CGPoint.init(x: x, y: y)
    }
    
    init(x: CGFloat, y: CGFloat, color: CGColor) {
        self.point = CGPoint.init(x: x, y: y)
        self.color = color
    }
    
    init(x: Int, y: Int) {
        self.point = CGPoint.init(x: x, y: y)
    }
    
    init(x: Int, y: Int, color: CGColor) {
        self.point = CGPoint.init(x: x, y: y)
        self.color = color
    }
    /*
    func toLandmarkPoint(size: ImageSize, videoLayer: AVCaptureVideoPreviewLayer) -> DisplayPoint {
        let displaySize = size.toDisplaySize(videoLayer: videoLayer)
        let newX = self.point.x
        let newY = displaySize.size.height - self.point.y
        return DisplayPoint(x: newX, y: newY)
    }
    
    func toImagePoint(size: ImageSize, videoLayer: AVCaptureVideoPreviewLayer) -> ImagePoint {
        let displaySize = size.toDisplaySize(videoLayer: videoLayer)
        let newX = displaySize.size.height - self.point.y
        let newY = displaySize.size.width - self.point.x
        return ImagePoint(x: newX, y: newY)
    }
 
    static func convertToDisplayLayer(point: ImagePoint, videoLayer: AVCaptureVideoPreviewLayer) -> DisplayPoint {
        return DisplayPoint.init(videoLayer.layerPointConverted(fromCaptureDevicePoint: point.point))
    }
    
    static func convertFromDisplayLayer(point: DisplayPoint, videoLayer: AVCaptureVideoPreviewLayer) -> ImagePoint{
        return ImagePoint.init(videoLayer.captureDevicePointConverted(fromLayerPoint: point.point))
    }
 */
}

struct DisplaySize {
    let size: CGSize
    
    init(_ size: CGSize) {
        self.size = size
    }
    
    init(width: CGFloat, height: CGFloat) {
        self.size = CGSize.init(width: width, height: height)
    }
    
    init(width: Int, height: Int) {
        self.size = CGSize.init(width: width, height: height)
    }
    /*
    
    func toLandmarkSize(videoLayer: AVCaptureVideoPreviewLayer) -> LandmarkSize {
        return LandmarkSize(self.size)
    }
    
    func toImageSize(videoLayer: AVCaptureVideoPreviewLayer) -> ImageSize {
        let newSize = CGSize(width: self.size.height, height: self.size.width)
        return ImageSize(newSize)
    }
 
    
    static func convertToDisplayLayer(size: ImageSize, videoLayer: AVCaptureVideoPreviewLayer) -> DisplaySize {
        let imageBoundsPoint = CGPoint.init(x: size.size.width, y: size.size.height)
        let displayBoundsPoint = DisplayPoint.init(videoLayer.layerPointConverted(fromCaptureDevicePoint: imageBoundsPoint))
        return DisplaySize.init(width: displayBoundsPoint.point.x, height: displayBoundsPoint.point.y)
    }

    static func convertToImageLayer(size: DisplaySize, videoLayer: AVCaptureVideoPreviewLayer) -> ImageSize {
        let displayBoundsPoint = CGPoint.init(x: size.size.width, y: size.size.height)
        let imageBoundsPoint = ImagePoint.init(videoLayer.captureDevicePointConverted(fromLayerPoint: displayBoundsPoint))
        
        return ImageSize.init(width: imageBoundsPoint.point.x, height: imageBoundsPoint.point.y)
    }
 */
}
