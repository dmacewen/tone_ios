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
    var faceLandmarks: Observable<VNFaceLandmarks2D?>
    let videoPreviewLayer: AVCaptureVideoPreviewLayer
    
    init(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, videoPreviewLayer: AVCaptureVideoPreviewLayer) {
        self.pixelBuffer = pixelBuffer
        self.orientation = orientation
        self.faceLandmarks = FaceCapture.getFaceLandmarks(pixelBuffer, orientation)
        self.videoPreviewLayer = videoPreviewLayer
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
                    let faceLandmarks = results[0].landmarks!
                    observable.onNext(faceLandmarks)
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
    
    func landmarkToImagePoint(point: vector_float2, faceBB: CGRect) -> CGPoint {
        return VNImagePointForFaceLandmarkPoint(point, faceBB, CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer))
    }
    
    func landmarkToDisplayPoint(point: vector_float2, faceBB: CGRect) -> CGPoint {
        let imagePoint = landmarkToImagePoint(point: point, faceBB: faceBB)
        return imagetoDisplayPoint(point: imagePoint)
    }
    
    func displayToImagePoint(point: CGPoint) -> CGPoint {
        return videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: point)
    }
    
    func imagetoDisplayPoint(point: CGPoint) -> CGPoint {
        return videoPreviewLayer.layerPointConverted(fromCaptureDevicePoint: point)
    }
}
