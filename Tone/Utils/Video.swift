//
//  Video.swift
//  Tone
//
//  Created by Doug MacEwen on 11/14/18.
//  Copyright © 2018 Doug MacEwen. All rights reserved.
//

import Foundation
import AVFoundation
import RxSwift
import AVKit

class Video:  NSObject {
    private var cameraState: CameraState
    let realtimeDataStream: Observable<RealTimeFaceData?>
    private let pixelBufferSubject = PublishSubject<CVPixelBuffer>()
    private let videoDataOutput: AVCaptureVideoDataOutput
    
    init(cameraState: CameraState, videoPreviewLayerStream:  BehaviorSubject<AVCaptureVideoPreviewLayer?>) {
        self.cameraState = cameraState
        
        self.realtimeDataStream = pixelBufferSubject
            //.flatMap { getFacialLandmarks(cameraState: cameraState, pixelBuffer: $0) }
            .flatMap { pixelBuffer -> Observable<FaceCapture?> in
                guard let videoPreviewLayer = try! videoPreviewLayerStream.value() else { return Observable.just(nil) }
                return FaceCapture.create(pixelBuffer: pixelBuffer, orientation: cameraState.exifOrientationForCurrentDeviceOrientation(), videoPreviewLayer: videoPreviewLayer)
            }
            .map { faceCaptureOptional -> RealTimeFaceData? in
                guard let faceCapture = faceCaptureOptional else {
                    print("No Face Capture")
                    return nil
                }
                guard let allImagePoints = faceCapture.getAllImagePoints() else {
                    print("No All Image Points")
                    return nil
                }
                guard let (isTooBright, brightnessPoints) = isTooBright(faceCapture: faceCapture, cameraState: cameraState) else {
                    print("No Is Too Bright")
                    return nil
                }
                let test = isLightingUnbalanced(faceCapture: faceCapture, cameraState: cameraState)
                print("TEST :: \(test)")
                guard let (isLightingUnbalanced, balancePoints) = test else {
                    print("No Is Lighting Unbalanced")
                    return nil
                }
                /*
                guard let (isLightingUnbalanced, balancePoints) = isLightingUnbalanced(faceCapture: faceCapture, cameraState: cameraState) else {
                    print("No Is Lighting Unbalanced")
                    return nil
                }*/
                
                return RealTimeFaceData(landmarks: allImagePoints, isLightingUnbalanced: isLightingUnbalanced, balancePoints: balancePoints, isTooBright: isTooBright, brightnessPoints: brightnessPoints, exposurePoint: brightnessPoints.first!, size: faceCapture.imageSize)
            }
            .asObservable()

        self.videoDataOutput = AVCaptureVideoDataOutput()
        super.init()
        
        self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
        self.videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        
        // Create a serial dispatch queue used for the sample buffer delegate as well as when a still image is captured.
        // A serial dispatch queue must be used to guarantee that video frames will be delivered in order.
        let videoDataOutputQueue = DispatchQueue(label: "com.Tone-Cosmetics.Tone")
        self.videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        
        if cameraState.captureSession.canAddOutput(self.videoDataOutput) {
            cameraState.captureSession.addOutput(self.videoDataOutput)
        }
        
        videoDataOutput.connection(with: .video)?.isEnabled = true
        
        if let captureConnection = videoDataOutput.connection(with: AVMediaType.video) {
            if captureConnection.isCameraIntrinsicMatrixDeliverySupported {
                captureConnection.isCameraIntrinsicMatrixDeliveryEnabled = true
            }
        }
    }
    
    func pauseProcessing() {
        cameraState.captureSession.removeOutput(self.videoDataOutput)
    }
    
    func resumeProcessing() {
        if cameraState.captureSession.canAddOutput(self.videoDataOutput) {
            cameraState.captureSession.addOutput(self.videoDataOutput)
        } else {
            print("Can't Resume Video Processing")
        }
    }
}

extension Video: AVCaptureVideoDataOutputSampleBufferDelegate {
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    /// - Tag: PerformRequests
    // Handle delegate method callback on receiving a sample buffer.
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to obtain a CVPixelBuffer for the current output frame.")
            return
        }
        
        pixelBufferSubject.onNext(pixelBuffer as CVPixelBuffer)
    }
}
