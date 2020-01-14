//
//  CaptureUtils.swift
//  Tone
//
//  Camera State provides a reactive interface to the current state of the camera hardware
//     It can be used to read state (isAdjustingExposure, isAdjustingWB)
//     It can be used to set state (exposurePoint via exposurePointStream)
//     It can be used to lock settings (Exposure, WB, etc)
//     It is used as the interface to FlashSettings via flashTaskStream
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

struct FlashSettingsTask {
    var flashSettings: FlashSettings
    let isDone = BehaviorSubject<Bool>(value: false)
}

struct ExposureRatios {
    let iso: CGFloat
    let exposure: CGFloat
}

class CameraState {
    var capturePhotoOutput: AVCapturePhotoOutput
    var captureDevice: AVCaptureDevice
    var captureSession: AVCaptureSession
    
    weak var flashTaskStream: PublishSubject<FlashSettingsTask>?
    var isAvailable =  BehaviorSubject<Bool>(value: true)
    var photoSettingsIndex = 0

    let disposeBag: DisposeBag = DisposeBag()
    
    private var areSettingsLocked = false
    private let sampleSettingsClock: Observable<Int>
    
    let exposurePointStream = BehaviorSubject<NormalizedImagePoint>(value: NormalizedImagePoint.init(x: 0.5, y: 0.5))
    
    init(flashTaskStream: PublishSubject<FlashSettingsTask>?) {
        print("Setting up camera...")
        self.flashTaskStream = flashTaskStream

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
        
        //Provides a sampling rate for different camera settings like isAdjustingExposure and isAdjustingWB
        sampleSettingsClock = Observable.interval(DispatchTimeInterval.milliseconds(100), scheduler: ConcurrentMainScheduler.instance)
        
        exposurePointStream
            .filter {[unowned self] _ in !self.areSettingsLocked }
            .subscribe(onNext: { [unowned self] exposurePoint in
            //NEEDS TO BE LOCKED FOR CONFIG
                print("EXPOSING!")
                
                ///TESTING
                var testExposurePoint = exposurePoint.point
                testExposurePoint.y = 1 - testExposurePoint.y
                self.captureDevice.exposurePointOfInterest = testExposurePoint//exposurePoint.point
                self.captureDevice.exposureMode = AVCaptureDevice.ExposureMode.autoExpose
            }).disposed(by: disposeBag)
    }
    
    func getIsAdjustingExposure() -> Observable<Bool> {
        return self.sampleSettingsClock.map { [unowned self] _ -> Bool in self.captureDevice.isAdjustingExposure }
    }
    
    func getIsAdjustingWB() -> Observable<Bool> {
        return self.sampleSettingsClock.map {[unowned self] _ in self.captureDevice.isAdjustingWhiteBalance }
    }
    
    func isExposureOffsetAboveThreshold(_ hasBeenNonZero:Bool = true) -> Bool {
        //Zero value is unfortunately what 'exposureTargetOffset' is set to when it hasnt taken a measurement (or so it seems)
        return (abs(self.captureDevice.exposureTargetOffset) > 0.15) || (!hasBeenNonZero && (self.captureDevice.exposureTargetOffset == 0.0))
    }
    
    func getIsExposureOffsetAboveThreshold() -> Observable<Bool> {
        var hasBeenNonZero = false
        return self.sampleSettingsClock
            .do(onNext: { [unowned self] _ in
                if self.captureDevice.exposureTargetOffset != 0 {
                    hasBeenNonZero = true
                }
            })
            .map { [unowned self] _ in return self.isExposureOffsetAboveThreshold(hasBeenNonZero) }
            .do(onNext: { [unowned self] isAbove in
                if isAbove {
                    self.captureDevice.exposureMode = AVCaptureDevice.ExposureMode.autoExpose
                    //self.captureDevice.exposureMode = AVCaptureDevice.ExposureMode.continuousAutoExposure
                }
            })
    }
    
    func resetCameraState() {
        self.photoSettingsIndex = 0
        self.unlockCameraSettings()
    }
    
    //Prepares numPhotos prepared settings
    func preparePhotoSettings(numPhotos: Int) -> Observable<Bool> {
        print("Preparing PhotoSettings!")
        let photoSettings = (0..<numPhotos).map { _ in getPhotoSettings() }
        return Observable.create { [unowned self] observer in
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
        let maxExposureDuration = CMTime.init(value: 1, timescale: 10) //Dont want exposures longer than 1/10 sec b/c motion blur
        let minISO = self.captureDevice.activeFormat.minISO
        
        var exposureRatio = CMTimeGetSeconds(maxExposureDuration) / CMTimeGetSeconds(self.captureDevice.exposureDuration)
        var isoRatio = Float64(self.captureDevice.iso) / Float64(minISO)
        
        if isoRatio < exposureRatio {
            exposureRatio = isoRatio
        } else {
            isoRatio = exposureRatio
        }
        
        let targetISO = self.captureDevice.iso / Float(isoRatio)
        let targetExposureDuration = CMTimeMultiplyByFloat64(self.captureDevice.exposureDuration, multiplier: exposureRatio)
        
        print("Min ISO :: \(minISO) | Max Exposure Duration :: \(CMTimeGetSeconds(maxExposureDuration))")
        print("Exposure Duration :: \(self.captureDevice.exposureDuration.value) -> \(targetExposureDuration.value)")
        print("ISO :: \(self.captureDevice.iso) -> \(targetISO)")
        
        return (targetExposureDuration, targetISO)
    }
    
    func lockCameraSettings() -> Observable<Bool> {
        if self.areSettingsLocked {
            return Observable.just(true)
        }
        
        print("LOCKING CAMERA SETTINGS")
        return Observable.combineLatest(self.getIsAdjustingExposure(), self.getIsAdjustingWB(), self.getIsExposureOffsetAboveThreshold()) { $0 || $1 || $2 }
            .filter { !$0 }
            .take(1)
            .observeOn(MainScheduler.instance)
            .flatMap { [unowned self] _ in self.lockExposure() }
            .flatMap { [unowned self] _ in self.lockWhiteBalance() }
            .do(onNext: { [unowned self] _ in self.areSettingsLocked = true })
            .do(onNext: { _ in print("DONE LOCKING CAMERA SETTINGS") })
    }
    
    private func lockWhiteBalance() -> Observable<Bool> {
        return Observable.create { [unowned self] observable in
            DispatchQueue.main.async {
                self.captureDevice.setWhiteBalanceModeLocked(with: AVCaptureDevice.currentWhiteBalanceGains, completionHandler: { time in
                    observable.onNext(true)
                    observable.onCompleted()
                })
            }
            return Disposables.create()
        }
    }
    
    private func lockExposure() -> Observable<Bool> {
        return Observable.create { [unowned self] observable in
            DispatchQueue.main.async {
                self.captureDevice.exposureMode = AVCaptureDevice.ExposureMode.custom
                let (targetExposureDuration, targetISO) = self.calculateTargetExposure()
                self.captureDevice.setExposureModeCustom(duration: targetExposureDuration, iso: targetISO, completionHandler: { time in
                    observable.onNext(true)
                    observable.onCompleted()
                })
            }
            return Disposables.create()
        }
    }
    
    func lockExposureBias() -> Observable<Bool> {
        return Observable.create { [unowned self] observable in
            DispatchQueue.main.async {
                //Underexpose in order to avoid clipping highlights
                self.captureDevice.setExposureTargetBias(-1.0, completionHandler: { time in
                    observable.onNext(true)
                    observable.onCompleted()
                })
            }
            return Disposables.create()
        }
    }
    
    func delay(_ duration: Double = 1.0) -> Observable<Bool> {
        return Observable.create { observer in
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + duration) {
                observer.onNext(true)
                observer.onCompleted()
            }
            return Disposables.create()
        }
    }
    
    func unlockCameraSettings() {
        print("UNLOCKING CAMERA SETTINGS!")
        self.areSettingsLocked = false
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
        }     }
    
    func exifOrientationForCurrentDeviceOrientation() -> CGImagePropertyOrientation {
        return exifOrientationForDeviceOrientation(UIDevice.current.orientation)
    }
    
    func getStandardizedExposureData() -> ExposureRatios {
        let minExposureDuration = self.captureDevice.activeFormat.minExposureDuration
        let minISO = self.captureDevice.activeFormat.minISO
        
        let exposureRatio =  CGFloat(CMTimeGetSeconds(self.captureDevice.exposureDuration) / CMTimeGetSeconds(minExposureDuration))
        let isoRatio = CGFloat(self.captureDevice.iso / minISO)
        
        return ExposureRatios(iso: isoRatio, exposure: exposureRatio)
    }
}

func getPhotoSettings() -> AVCapturePhotoSettings {
    print("GETTING NEW PHOTO SETTINGS")
    let photoSettings = AVCapturePhotoSettings.init(format: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    photoSettings.isAutoStillImageStabilizationEnabled = false
    photoSettings.isHighResolutionPhotoEnabled = true
    photoSettings.flashMode = .off
    return photoSettings
}
