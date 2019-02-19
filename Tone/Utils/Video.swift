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
    let faceLandmarks: Observable<RealTimeFaceData?>
    private let pixelBufferSubject = PublishSubject<CVImageBuffer>()
    private let videoDataOutput: AVCaptureVideoDataOutput
    
    init(cameraState: CameraState) {
        self.cameraState = cameraState
        
        self.faceLandmarks = pixelBufferSubject
            .flatMap { getFacialLandmarks(cameraState: cameraState, pixelBuffer: $0) }
            .map({ (faceLandmarksOptional) -> RealTimeFaceData? in
                guard let (faceLandmarks, pixelBuffer) = faceLandmarksOptional else {
                    return nil
                }
                
                guard let (exposurePoint, isLightingBalanced) = getExposureInfo(pixelBuffer: pixelBuffer, landmarks: faceLandmarks) else {
                    return nil
                }
                
                cameraState.exposurePointStream.onNext(exposurePoint)
                
                let exposureDurationValue = Float(cameraState.captureDevice.exposureDuration.value)
                let exposureDurationTimeScale = Float(cameraState.captureDevice.exposureDuration.timescale)
                let exposureDuration = exposureDurationValue / exposureDurationTimeScale
                
                return RealTimeFaceData(landmarks: faceLandmarks, isLightingBalanced: isLightingBalanced, iso: cameraState.captureDevice.iso, exposureDuration: exposureDuration)
            })
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
        
        pixelBufferSubject.onNext(pixelBuffer)
    }
}
