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
    private let capture = PublishSubject<AVCapturePhoto>()
    private let disposeBag = DisposeBag()
    
    init(cameraState: CameraState) {
        print("New Camera")
        self.cameraState = cameraState
    }
    
    func capturePhoto(_ flashSettings: FlashSettings) -> PublishSubject<AVCapturePhoto> {
        print("Beginning to capture photo!")
        self.cameraState.flashStream.onNext(flashSettings)
        
        Observable.combineLatest(cameraState.isAdjustingExposure, cameraState.isAdjustingWB) { $0 || $1 }
            //.observeOn(MainScheduler.instance)
            .filter { !$0 }
            .take(1)
            .subscribe(onNext: { _ in
                print("Captuing Photo with Flash Settings :: \(flashSettings.area) \(flashSettings.areas)")
                print("Getting Photo Settings!")
                let photoSettings = self.cameraState.capturePhotoOutput.preparedPhotoSettingsArray.count > self.cameraState.photoSettingsIndex
                    ? self.cameraState.capturePhotoOutput.preparedPhotoSettingsArray[self.cameraState.photoSettingsIndex]
                    : getPhotoSettings()
                
                self.cameraState.photoSettingsIndex += 1
                print("Capturing!")
                self.cameraState.capturePhotoOutput.capturePhoto(with: photoSettings, delegate: self)
            }).disposed(by: disposeBag)
        
        return capture
    }
}

extension Camera: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            fatalError("Error in capture!")
        }
        
        capture.onNext(photo)
        capture.onCompleted()
    }
}
