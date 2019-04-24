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
    private let capture = PublishSubject<(AVCapturePhoto, FlashSettings)>()
    private let disposeBag = DisposeBag()
    private var flashSettings: FlashSettings?
    
    init(cameraState: CameraState) {
        print("New Camera")
        self.cameraState = cameraState
    }
    
    //func capturePhoto(_ flashSettings: FlashSettings) -> PublishSubject<(AVCapturePhoto, FlashSettings)> {
    func capturePhoto(_ flashSettings: FlashSettings) -> Observable<(AVCapturePhoto, FlashSettings)> {

        print("Beginning to capture photo!")
        self.flashSettings = flashSettings
        
        let flashTask = FlashSettingsTask(flashSettings: flashSettings)
        self.cameraState.flashTaskStream.onNext(flashTask)
        /*
        isDoneDrawingFlash
            .filter { $0 }
        */
        return Observable.combineLatest(cameraState.isAdjustingExposure, cameraState.isAdjustingWB, flashTask.isDone.observeOn(MainScheduler.instance)) { $0 || $1 || !$2 }
            .observeOn(MainScheduler.instance)
            .subscribeOn(MainScheduler.instance)
            .filter { !$0 }
            .take(1)
            .map { _ in
                print("Captuing Photo with Flash Settings :: \(flashSettings.area) \(flashSettings.areas)")
                print("Getting Photo Settings!")
                let photoSettings = self.cameraState.capturePhotoOutput.preparedPhotoSettingsArray.count >= self.cameraState.photoSettingsIndex
                    ? self.cameraState.capturePhotoOutput.preparedPhotoSettingsArray[self.cameraState.photoSettingsIndex]
                    : getPhotoSettings()
                
                self.cameraState.photoSettingsIndex += 1
                print("Capturing!")
                self.cameraState.capturePhotoOutput.capturePhoto(with: photoSettings, delegate: self)
            }
            .flatMap { _ in self.capture }
            /*
            .subscribe(onNext: { _ in
                print("Captuing Photo with Flash Settings :: \(flashSettings.area) \(flashSettings.areas)")
                print("Getting Photo Settings!")
                let photoSettings = self.cameraState.capturePhotoOutput.preparedPhotoSettingsArray.count >= self.cameraState.photoSettingsIndex
                    ? self.cameraState.capturePhotoOutput.preparedPhotoSettingsArray[self.cameraState.photoSettingsIndex]
                    : getPhotoSettings()
                
                self.cameraState.photoSettingsIndex += 1
                print("Capturing!")
                self.cameraState.capturePhotoOutput.capturePhoto(with: photoSettings, delegate: self)
            }).disposed(by: disposeBag)
 */
        
        //return capture.take(1)
        //return capture//.take(1)
        //print("Returning!")
        //return capture
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
    
        
        capture.onNext((photo, flashSetting))
        capture.onCompleted()
    }
}
