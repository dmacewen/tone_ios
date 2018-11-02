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

struct PhotoSettings {
    var iso = 0.0
    var exposure = 0.0
    var whiteBalance = [0.0, 0.0, 0.0]
}

// areas: the number of equal areas to divide the screen into
// area: the specific area to illuminate
//Ex.
// (area, areas)
// (0, 1) is all black
// (1, 1) is all white
// (1, 2) is half 1 of the screen is illuminated
// (2, 2) is half 2 of the screen is illuminated

struct FlashSettings {
    var area = 0
    var areas = 0
}

//Defining a Camera how we want it
class Camera: NSObject {
    var capturePhotoOutput: AVCapturePhotoOutput
    var captureDevice: AVCaptureDevice
    var captureSession: AVCaptureSession
    
    private var flashStream: PublishSubject<FlashSettings>
    private var photoSettingsIndex = 0
    
    private let capture = PublishSubject<AVCapturePhoto>()
    
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
    }
    
    //Prepares numPhotos prepared settings
    func preparePhotoSettings(numPhotos: Int) -> Observable<Bool> {
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
    
    func capturePhoto(flashSettings: FlashSettings) -> PublishSubject<AVCapturePhoto> {
        //flashStream.onNext(flashSettings)
        
        //Move to chain? bind isAdjustingExposure?
        if captureDevice.isAdjustingExposure == true {
            //fatalError("Still Adjusting Exposure")
            print("Still Adjusting Exposure")

            /*
             print("Posponing Capture!")
             
             delay(0.5) {
             return self.capturePhoto(flashSettings: flashSettings, photoSettings: photoSettings)
             }
             */
        }
        print("Captuing Photo with Flash Settings :: \(flashSettings.area) \(flashSettings.areas)")
        flashStream.onNext(flashSettings)
        
        let photoSettings = capturePhotoOutput.preparedPhotoSettingsArray.count > photoSettingsIndex
            ? capturePhotoOutput.preparedPhotoSettingsArray[photoSettingsIndex]
            : getPhotoSettings()
        
        photoSettingsIndex += 1
        capturePhotoOutput.capturePhoto(with: photoSettings, delegate: self)
        
        return capture
    }
}

extension Camera: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            capture.onError(error!)
            return
        }
        capture.onNext(photo)
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
