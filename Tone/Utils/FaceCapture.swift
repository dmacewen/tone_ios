//
//  FaceCapture.swift
//  Tone
//
//  Created by Doug MacEwen on 4/10/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation
import AVFoundation
import RxSwift
import Vision

class FaceCapture {
    let pixelBuffer: CVPixelBuffer
    let orientation: CGImagePropertyOrientation
    let videoPreviewLayer: AVCaptureVideoPreviewLayer
    let flashSettings: FlashSettings
    let imageSize: CGSize
    let rawMetadata: [String: Any]
    
    //Keep private to keep us from accessing in its raw form (it can be kind of confusing/messy to interact with)
    private var faceLandmarks: VNFaceLandmarks2D
    
    init(pixelBuffer: CVPixelBuffer, faceLandmarks: VNFaceLandmarks2D, orientation: CGImagePropertyOrientation, videoPreviewLayer: AVCaptureVideoPreviewLayer, flashSettings: FlashSettings = FlashSettings(), rawMetadata: [String: Any]) {
        self.pixelBuffer = pixelBuffer
        self.faceLandmarks = faceLandmarks
        self.orientation = orientation
        self.videoPreviewLayer = videoPreviewLayer
        self.flashSettings = flashSettings
        self.imageSize = CGSize.init(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
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
    
    func getJawDisplayPoints() -> [CGPoint]? {
        guard let faceContour = self.faceLandmarks.faceContour else { return nil }
        
        return faceContour
            .pointsInImage(imageSize: self.imageSize)
            .map { self.imagetoDisplayPoint(point: $0) }
    }
    
    func getAllImagePoints() -> [CGPoint]? {
        guard let allPoints = self.faceLandmarks.allPoints else { return nil }
        return allPoints.pointsInImage(imageSize: self.imageSize)
    }
    
    func getAllPointsBB() -> CGRect? {
        guard let allPoints = self.getAllImagePoints() else { return nil }
        return CGRect.fromPoints(points: allPoints,  imgSize: self.imageSize)
    }
    
    func getAllPointsSize() -> CGSize? {
        guard let allPointsBB = self.getAllPointsBB() else { return nil }
        return CGSize.from(rect: allPointsBB)
    }
    
    func getLeftEyeImageBB() -> CGRect? {
        guard let leftEye = self.faceLandmarks.leftEye else { return nil }
        let leftEyePoints = leftEye.pointsInImage(imageSize: self.imageSize)
        return CGRect.fromPoints(points: leftEyePoints, imgSize: self.imageSize)
    }
    
    func getLeftEyeImageSize() -> CGSize? {
        guard let leftEyeBB = self.getLeftEyeImageBB() else { return nil }
        return CGSize.from(rect: leftEyeBB)
    }
    
    func getRightEyeImageBB() -> CGRect? {
        guard let rightEye = self.faceLandmarks.rightEye else { return nil }
        let rightEyePoints = rightEye.pointsInImage(imageSize: self.imageSize)
        return CGRect.fromPoints(points: rightEyePoints, imgSize: self.imageSize)
    }
    
    func getRightEyeImageSize() -> CGSize? {
        guard let rightEyeBB = self.getRightEyeImageBB() else { return nil }
        return CGSize.from(rect: rightEyeBB)
    }
    
    func displayToImagePoint(point: CGPoint) -> CGPoint {
        return videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: point)
    }
    
    func imagetoDisplayPoint(point: CGPoint) -> CGPoint {
        return videoPreviewLayer.layerPointConverted(fromCaptureDevicePoint: point)
    }
    /*
    private func getCIImage(crop: CGRect?) -> CIImage {
        let image = CIImage.init(cvImageBuffer: self.pixelBuffer)
        if crop != nil {
            return image.cropped(to: crop!)
        }
        return image
    }
 */
    
    func getImage() -> Image {
        let image = CIImage.init(cvImageBuffer: self.pixelBuffer)
        let landmarks = self.getAllImagePoints()!
        return Image(image: image, landmarks: landmarks)
    }
}
