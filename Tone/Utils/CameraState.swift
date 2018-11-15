//
//  CaptureUtils.swift
//  Tone
//
//  Created by Doug MacEwen on 11/1/18.
//  Copyright © 2018 Doug MacEwen. All rights reserved.
//

import Foundation
import AVFoundation
import RxSwift
import AVKit
import Vision

struct PhotoSettings {
    var iso = 0.0
    var exposure = 0.0
    var whiteBalance = [0.0, 0.0, 0.0]
}

struct FlashSettings {
    var area = 0
    var areas = 0
}

struct RealTimeFaceData {
    var landmarks: VNFaceLandmarks2D
    var cheekRatio: Float
    var iso: Float
    var exposureDuration: Float
}

//Defining a Camera how we want it
class CameraState {
    var capturePhotoOutput: AVCapturePhotoOutput
    var captureDevice: AVCaptureDevice
    var captureSession: AVCaptureSession
    
    var flashStream: PublishSubject<FlashSettings>
    var isAvailable =  BehaviorSubject<Bool>(value: true)
    var photoSettingsIndex = 0
    
    let isAdjustingExposure: ConnectableObservable<Bool>//Variable<Bool>
    let isAdjustingWB: ConnectableObservable<Bool>//Variable<Bool>
    let disposeBag = DisposeBag()

    init(flashStream: PublishSubject<FlashSettings>) {
        print("Setting up camera...")
        self.flashStream = flashStream

        //Create Capture Session
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
        captureSession.automaticallyConfiguresCaptureDeviceForWideColor = false
        
        //Set up Capture Photo Output
        capturePhotoOutput = AVCapturePhotoOutput()
        capturePhotoOutput.isHighResolutionCaptureEnabled = true
        
        //Add Capture Photo Output to Capture Session
        captureSession.addOutput(capturePhotoOutput)
        captureSession.startRunning()
        
        captureDevice = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: AVCaptureDevice.Position.front)!
        
        do {
            try captureDevice.lockForConfiguration()
            print("Capture Device LOCKED")
        } catch {
            fatalError("Could Not Lock device for configuration")
        }
        
        //Set colorspace to sRGB so that color processing is consistent between devices that dont support larger colorspaces
        captureDevice.activeColorSpace = AVCaptureColorSpace.sRGB
        
        captureSession.beginConfiguration()
        
        do {
            //Add capture device to capture session
            let input = try AVCaptureDeviceInput(device: captureDevice)
            captureSession.addInput(input)
        } catch {
            fatalError("Could Not Add Capture Device to Current Capture Session!")
        }
        
        captureSession.commitConfiguration()
        print("Commited Capture Session")
        
        //isAdjustingExposure = Variable(self.captureDevice.isAdjustingExposure)
        //isAdjustingWB = Variable(self.captureDevice.isAdjustingWhiteBalance)
        let captureDeviceLocal = captureDevice
        
        isAdjustingExposure = self.captureDevice.rx.observe(AVCaptureDevice.self, "adjustingExposure")
            .map { _ in captureDeviceLocal.isAdjustingExposure }
            .replay(1)
        
        isAdjustingWB = self.captureDevice.rx.observe(AVCaptureDevice.self, "adjustingWhiteBalance")
            .map { _ in captureDeviceLocal.isAdjustingWhiteBalance }
            .replay(1)
        
        _ = isAdjustingWB.connect()
        _ = isAdjustingExposure.connect()
            //.subscribe(onNext: { print("Adjusting Exposure \($0)") })
            //.disposed(by: disposeBag)

/*
        
        isAdjustingExposure
            .subscribe(onNext: {
                print("Is Adjusting Exposure? :: \($0)")
            }, onCompleted: { print("Completed Ajusting Exposure Observable...") }).disposed(by: disposeBag)
        
        isAdjustingWB
            .subscribe(onNext: {
                print("Is Adjusting WB? :: \($0)")
            }, onCompleted: { print("Completed Ajusting WB Observable...") }).disposed(by: disposeBag)
        
        
        _ = isAdjustingExposure.connect()
        _ = isAdjustingWB.connect()*/
        print("SET UP IS ADJUSTING")
    }
    
    //Prepares numPhotos prepared settings
    func preparePhotoSettings(numPhotos: Int) -> Observable<Bool> {
        print("Preparing PhotoSettings!")
        let photoSettings = (0..<numPhotos).map { _ in getPhotoSettings() }
        return Observable.create { observer in
            self.capturePhotoOutput.setPreparedPhotoSettingsArray(photoSettings) {
                isPrepared, error in
                guard error == nil else {
                    observer.on(.error(error!))
                    return
                }
                observer.on(.next(isPrepared))
                observer.on(.completed)
            }
            return Disposables.create()
        }
    }

    func lockCameraSettings() -> Observable<Bool> {
        captureDevice.exposureMode = AVCaptureDevice.ExposureMode.locked
        return Observable.create { observable in
            self.captureDevice.setWhiteBalanceModeLocked(with: AVCaptureDevice.currentWhiteBalanceGains, completionHandler: { time in
                observable.onNext(true)
            })
            return Disposables.create()
        }
    }
    
    func unlockCameraSettings() {
        let middlePoint = CGPoint.init(x: 0.5, y: 0.5)
        captureDevice.exposurePointOfInterest = middlePoint
        captureDevice.exposureMode = AVCaptureDevice.ExposureMode.continuousAutoExposure
        captureDevice.whiteBalanceMode = AVCaptureDevice.WhiteBalanceMode.continuousAutoWhiteBalance
    }
    
    func exifOrientationForDeviceOrientation(_ deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        
        switch deviceOrientation {
        case .portraitUpsideDown:
            return .rightMirrored
            
        case .landscapeLeft:
            return .downMirrored
            
        case .landscapeRight:
            return .upMirrored
            
        default:
            return .leftMirrored
        }
    }
    
    func exifOrientationForCurrentDeviceOrientation() -> CGImagePropertyOrientation {
        return exifOrientationForDeviceOrientation(UIDevice.current.orientation)
    }
}



func getPhotoSettings() -> AVCapturePhotoSettings {
    let photoSettings = AVCapturePhotoSettings.init(format: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    //photoSettings.processedFileType = AVFileType.tif
    photoSettings.isAutoStillImageStabilizationEnabled = true
    photoSettings.isHighResolutionPhotoEnabled = true
    photoSettings.flashMode = .off
    return photoSettings
}
