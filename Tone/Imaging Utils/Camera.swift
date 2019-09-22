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
    
    deinit {
        print("Desroying Camera!")
    }
    
    func capturePhoto(_ flashSettings: FlashSettings, _ triggerExposure: BehaviorSubject<Bool>) -> Observable<(AVCapturePhoto, FlashSettings, NormalizedImagePoint)> {
       return Observable<FlashSettingsTask>.create { observer in
                print("Beginning to capture photo!")
                self.flashSettings = flashSettings
        
                let flashTask = FlashSettingsTask(flashSettings: flashSettings)
                self.cameraState.flashTaskStream!.onNext(flashTask)
        
                print("Waiting for flash to set")
                observer.onNext(flashTask)
                observer.onCompleted()
                return Disposables.create()
            }
            .flatMap { flashTask in flashTask.isDone }
            .filter { $0 }
            //Find Exposure Point
            //End Video
            //.flatMap { _ in self.cameraState.setWhiteBalanceToD65() }
        /*
            .flatMap { passthrough in
                if flashSettings.area == flashSettings.areas {
                    triggerExposure.onNext(true) //Does this trigger two exposures? One in SampleSkintoneViewModel and one here?
                    return realtimeDataStream //TODO: Define realtime data stream...
                        .take(1)
                        .map { realtimeData in
                            cameraState.exposurePointStream.onNext(realtimeData.exposurePoint)
                            return passthrough
                        }
                }
                return Observable.just(passthrough)
            }
 */
        
            .do(onNext: { _ in
                if flashSettings.area == flashSettings.areas {
                    print("Triggering Exposure!")
                    triggerExposure.onNext(true) //Does this trigger two exposures? One in SampleSkintoneViewModel and one here?
                }
            })
            .flatMap { _ in Observable.combineLatest(self.cameraState.getIsAdjustingExposure(), self.cameraState.getIsAdjustingWB()) { $0 || $1 } }
            .distinctUntilChanged()
            .do(onNext: { combined in print("(is Adjusting Ex) and (is Adjusting WB) :: \(combined)") })
            .filter { !$0 }
            .take(1)
            .flatMap { _ in self.cameraState.lockExposureBias() } //Lock exposure bias before for proper metering
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
                    print("Is above threshold :: \(self.cameraState.isExposureOffsetAboveThreshold())")
                }
            }
            .flatMap { _ in self.capture }
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
