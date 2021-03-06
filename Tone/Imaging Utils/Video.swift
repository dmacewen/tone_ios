//
//  Video.swift
//  Tone
//  
//  Handles video stream. Adds video stream to capture session automatically on initilization
//  Optionally processes video stream in real time providing:
//      Facial Landmarking
//      Interpretation of user including lighting, position, device orientation
//
//  Allows consumer to stop and resume processing
//
//  Created by Doug MacEwen on 11/14/18.
//  Copyright © 2018 Doug MacEwen. All rights reserved.
//

import Foundation
import AVFoundation
import RxSwift
import AVKit

enum ProcessRealtime {
    case no
    case once
    case yes
}

class Video:  NSObject {
    private var cameraState: CameraState
    let realtimeDataStream: Observable<RealTimeFaceData?>
    private let pixelBufferSubject = PublishSubject<CVPixelBuffer>()
    private let videoDataOutput: AVCaptureVideoDataOutput
    
    init(cameraState: CameraState, shouldProcessRealtime: BehaviorSubject<ProcessRealtime>) {
        self.cameraState = cameraState
        
        self.realtimeDataStream = pixelBufferSubject
            .filter { _ in
                switch try! shouldProcessRealtime.value() {
                case .no:
                    return false
                case .once:
                    shouldProcessRealtime.onNext(.no)
                    return true
                case .yes:
                    return true
                }
            }
            .throttle(RxTimeInterval.milliseconds(100), scheduler: MainScheduler.asyncInstance) //No need to calculate the face location 60 times a second...
            .flatMap { pixelBuffer -> Observable<FaceCapture?> in
                return FaceCapture.create(pixelBuffer: pixelBuffer, orientation: cameraState.exifOrientationForCurrentDeviceOrientation())
            }
            .map { faceCaptureOptional -> RealTimeFaceData? in
                print("Processing Realtime")
                guard let faceCapture = faceCaptureOptional else { return nil }
                guard let allImagePoints = faceCapture.getAllImagePoints() else { return nil }
                
                guard let (exposurePointIndex, eyeExposurePoints) = getEyeExposurePoints(faceCapture) else { return nil }
                
                guard let (isTooBright, brightnessPoints) = isTooBright(faceCapture, cameraState) 
                else { return nil }

                guard let (isLightingUnbalanced, balancePoints) = isLightingUnbalanced(faceCapture, cameraState) 
                else { return nil }

                guard let (isNotHorizontallyAligned, isNotVerticallyAligned, isRotated, facingCameraPoints) = isFaceNotParallelToCamera(faceCapture, cameraState)
                else { return nil }
                
                return RealTimeFaceData(
                    landmarks: allImagePoints,
                    isLightingUnbalanced: isLightingUnbalanced,
                    balancePoints: balancePoints,
                    isTooBright: isTooBright,
                    brightnessPoints: brightnessPoints,
                    isNotHorizontallyAligned: isNotHorizontallyAligned,
                    isNotVerticallyAligned: isNotVerticallyAligned,
                    isRotated: isRotated,
                    facingCameraPoints: facingCameraPoints,
                    exposurePoint: eyeExposurePoints[exposurePointIndex],
                    eyeExposurePoints: eyeExposurePoints,
                    size: faceCapture.imageSize)
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
    // Handle delegate method callback on receiving a sample buffer.
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to obtain a CVPixelBuffer for the current output frame.")
            return
        }
        
        pixelBufferSubject.onNext(pixelBuffer as CVPixelBuffer)
    }
}
