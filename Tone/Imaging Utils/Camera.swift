//
//  Camera.swift
//  Tone
//
//  Created by Doug MacEwen on 11/14/18.
//  Copyright © 2018 Doug MacEwen. All rights reserved.
//

import Foundation
import AVFoundation
import RxSwift

class Camera: NSObject {
    private var cameraState: CameraState
    private let capture = PublishSubject<(AVCapturePhoto, FlashSettings, NormalizedImagePoint)>()
    private let disposeBag = DisposeBag()
    private var flashSettings: FlashSettings?
    
    init(cameraState: CameraState) {
        print("New Camera")
        self.cameraState = cameraState
    }
    
    //func capturePhoto(_ flashSettings: FlashSettings) -> PublishSubject<(AVCapturePhoto, FlashSettings)> {
    func capturePhoto(_ flashSettings: FlashSettings) -> Observable<(AVCapturePhoto, FlashSettings, NormalizedImagePoint)> {
        return Observable.create { observer in
            print("Beginning to capture photo!")
            self.flashSettings = flashSettings
            
            let flashTask = FlashSettingsTask(flashSettings: flashSettings)
            self.cameraState.flashTaskStream.onNext(flashTask)
            
            print("Waiting for flash to set")
            return Observable.combineLatest(self.cameraState.isAdjustingExposure, self.cameraState.isAdjustingWB, flashTask.isDone) { $0 || $1 || !$2 }
                .distinctUntilChanged()
                .do(onNext: { isDoneSetting in print("Is Done Setting Flash :: \(isDoneSetting)") })
                .do(onNext: { combined in
                    print("(is Adjusting Ex) and (is Adjusting WB) and (is not Done) :: \(combined)")
                })
                .filter { !$0 }
                .take(1)
                .flatMap { _ in self.cameraState.lockCameraSettings() }
                .map { _ in
                    print("Captuing Photo with Flash Settings :: \(flashSettings.area) \(flashSettings.areas)")
                    print("Getting Photo Settings!")
                    let photoSettings = self.cameraState.capturePhotoOutput.preparedPhotoSettingsArray.count >= self.cameraState.photoSettingsIndex
                        ? self.cameraState.capturePhotoOutput.preparedPhotoSettingsArray[self.cameraState.photoSettingsIndex]
                        : getPhotoSettings()
                    
                    self.cameraState.photoSettingsIndex += 1
                    print("Capturing!")
                    DispatchQueue.main.async {
                        print("Called Capture")
                        self.cameraState.capturePhotoOutput.capturePhoto(with: photoSettings, delegate: self)
                        print("==> Camera Settings :: \(self.cameraState.captureDevice.iso) | \(self.cameraState.captureDevice.exposureDuration.seconds)")
                        print("==> Camera Offset and Bias:: \(self.cameraState.captureDevice.exposureTargetOffset) | \(self.cameraState.captureDevice.exposureTargetBias)")
                        self.cameraState.isExposureOffsetAboveThreshold.take(1).subscribe(onNext: { print("Is above threshold :: \($0)") }).disposed(by: self.disposeBag)
                    }
                }
                .flatMap { _ in self.capture }
                .subscribe(onNext: { observer.onNext($0) }, onError: { observer.onError($0) }, onCompleted: { observer.onCompleted() })
        }
    }
}

extension Camera: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        NSLog("Done Capture and Processing!")
        guard error == nil else {
            fatalError("Error in capture!")
        }
        
        guard let flashSetting = self.flashSettings else {
            fatalError("No Flash Setting Found! What flash setting was used?")
        }
    
        capture.onNext((photo, flashSetting, try! cameraState.exposurePointStream.value()))
        capture.onCompleted()
    }
}
