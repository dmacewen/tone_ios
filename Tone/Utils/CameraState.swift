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

struct FlashSettings: Codable {
    var area: Int = 0
    var areas: Int = 0
}

struct RealTimeFaceData {
    var landmarks: VNFaceLandmarks2D
    var isLightingBalanced: Bool
    var iso: Float
    var exposureDuration: Float
}

//Defining a Camera how we want it
class CameraState {
    var capturePhotoOutput: AVCapturePhotoOutput
    var captureDevice: AVCaptureDevice
    var captureSession: AVCaptureSession
    
    //var flashStream: PublishSubject<FlashSettings>
    var flashStream: BehaviorSubject<FlashSettings>
    var isAvailable =  BehaviorSubject<Bool>(value: true)
    var photoSettingsIndex = 0
    
    let isAdjustingExposure: ConnectableObservable<Bool>//Variable<Bool>
    let isAdjustingWB: ConnectableObservable<Bool>//Variable<Bool>
    let disposeBag = DisposeBag()
    
    let exposurePointStream = BehaviorSubject<CGPoint>(value: CGPoint.init(x: 0.5, y: 0.5))

    init(flashStream: BehaviorSubject<FlashSettings>) {
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
        
        exposurePointStream.subscribe(onNext: {  exposurePoint in
            //print("Setting exposure point to \(exposurePoint)")
            self.captureDevice.exposurePointOfInterest = exposurePoint
            self.captureDevice.exposureMode = AVCaptureDevice.ExposureMode.autoExpose
        }).disposed(by: disposeBag)
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
    
    //Minimizes ISO by Maximizing Exposure Duration while targeting the Metered Exposure
    private func calculateTargetExposure() -> (CMTime, Float) {
        var maxExposureDuration = self.captureDevice.activeFormat.maxExposureDuration
        let minISO = self.captureDevice.activeFormat.minISO
        
        maxExposureDuration = maxExposureDuration.convertScale(self.captureDevice.exposureDuration.timescale, method: CMTimeRoundingMethod.default)
        var exposureRatio = Float64(maxExposureDuration.value) / Float64(self.captureDevice.exposureDuration.value)
        var isoRatio = Float64(self.captureDevice.iso) / Float64(minISO)
        
        if isoRatio < exposureRatio {
            exposureRatio = isoRatio
        } else {
            isoRatio = exposureRatio
        }
        
        let targetISO = self.captureDevice.iso / Float(isoRatio)
        let targetExposureDuration = CMTimeMultiplyByFloat64(self.captureDevice.exposureDuration, multiplier: exposureRatio)
        
        print("Min ISO :: \(minISO) | Max Exposure Duration :: \(maxExposureDuration.value)")
        print("Exposure Duration :: \(self.captureDevice.exposureDuration.value) -> \(targetExposureDuration.value)")
        print("ISO :: \(self.captureDevice.iso) -> \(targetISO)")
        
        return (targetExposureDuration, targetISO)
    }

    func lockCameraSettings() -> Observable<Bool> {
        captureDevice.exposureMode = AVCaptureDevice.ExposureMode.locked
        print("LOCKING CAMERA SETTINGS")
        
        return Observable.combineLatest(isAdjustingExposure, isAdjustingWB) { $0 || $1 }
            .observeOn(MainScheduler.instance)
            .filter { !$0 }
            .take(1)
            .flatMap { _ in
                return Observable.create { observable in
                    self.captureDevice.setWhiteBalanceModeLocked(with: AVCaptureDevice.currentWhiteBalanceGains, completionHandler: { time in
                        
                        let (targetExposureDuration, targetISO) = self.calculateTargetExposure()
                        
                        self.captureDevice.setExposureModeCustom(duration: targetExposureDuration, iso: targetISO, completionHandler: { time in
                                print("LOCKED CAMERA SETTINGS")
                                observable.onNext(true)
                        })
                    })
                    return Disposables.create()
                }
            }
    }
    
    func unlockCameraSettings() {
        print("UNLOCKING CAMERA SETTINGS!")
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
        //return UIDeviceOrientation.landscapeLeft
        return exifOrientationForDeviceOrientation(UIDevice.current.orientation)
    }
}

func getPhotoSettings() -> AVCapturePhotoSettings {
    print("GETTING NEW PHOTO SETTINGS")
    let photoSettings = AVCapturePhotoSettings.init(format: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    //photoSettings.processedFileType = AVFileType.tif
    photoSettings.isAutoStillImageStabilizationEnabled = true
    photoSettings.isHighResolutionPhotoEnabled = true
    photoSettings.flashMode = .off
    return photoSettings
}
