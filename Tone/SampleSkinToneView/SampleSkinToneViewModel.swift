//
//  SampleSkinToneViewModel.swift
//  Tone
//
//  Created by Doug MacEwen on 10/30/18.
//  Copyright © 2018 Doug MacEwen. All rights reserved.
//

import Foundation
//import Foundation.NSTimer

import RxSwift
import RxSwiftExt

import AVFoundation
import UIKit
//import Alamofire
//import RxAlamofire
//import Compression

class SampleSkinToneViewModel {
    enum Event {
        case cancel
    }
    
    enum SampleStates {
        case previewUser
        case referenceSample
        case sample
        case upload
    }
    
    enum UserFaceStates {
        case ok
        case noFaceFound
        case tooDark
        case tooBright
        case faceGradient
        case faceTooFar
        
        var message: String {
            switch self {
            case .ok: return "Looking Good!"
            case .noFaceFound: return "Looking For You..."
            case .tooDark: return "It's A Little Too Dark Here..."// Lets try again in a room with a bit more light"
            case .tooBright: return "It's A Little Too Bright Here..."// Try facing away from the brightest light in the room or moving to a darker area"
            case .faceTooFar: return "You're Too Far Away!"// Bring me closer to your face!"
            case .faceGradient: return "You're Too Unevenly Lit!"// Try and face away from the brightest light in the room"
            }
        }
    }
    
    
    let userFaceState = BehaviorSubject<UserFaceStates>(value: .ok/*.noFaceFound*/)
    let sampleState = BehaviorSubject<SampleStates>(value: .previewUser)
    
    let referencePhotos = PublishSubject<AVCapturePhoto>()
    let samplePhotos = PublishSubject<AVCapturePhoto>()
    
    let flashSettings = PublishSubject<FlashSettings>()
    
    let events = PublishSubject<Event>()
    
    var originalScreenBrightness: CGFloat = 0.0
    var camera: Camera
    
    let disposeBag = DisposeBag()

    init() {
        camera = Camera(flashStream: flashSettings, photoStream: samplePhotos)
        print("finished setup")
        
        sampleState
            .observeOn(MainScheduler.instance)
            .filter { $0 == .referenceSample }
            .subscribe { _ in
                print("Taking Reference Sample!")
                self.sampleState.onNext(.sample)
            }
            .disposed(by: disposeBag)
        
        sampleState
            .observeOn(MainScheduler.instance)
            .filter { $0 == .sample }
            .subscribe { _ in
                print("Taking Samples!")
                
                let sampleFlashSettings = [FlashSettings(area: 1, areas: 1), FlashSettings(area: 1, areas: 2),FlashSettings(area: 2, areas: 2),FlashSettings(area: 0, areas: 1)]
                
                Observable<FlashSettings>.from(sampleFlashSettings)
                    .observeOn(MainScheduler.instance)
                    .pausableBuffered(self.camera.isAvailable, limit: 4)
                    .subscribe(onNext: { flashSetting in
                        self.camera.isAvailable.onNext(false)
                        self.camera.capturePhoto(flashSettings: flashSetting)
                    }, onError: { error in print(error) })
                    .disposed(by: self.disposeBag)
            }
            .disposed(by: disposeBag)
        
        samplePhotos
            .take(4)
            .toArray()
            .subscribe(onNext: { _ in
               print("Got All The Photos!!!")
                self.sampleState.onNext(.upload)
            })
            .disposed(by: disposeBag)
        
        sampleState
            .observeOn(MainScheduler.instance)
            .filter { $0 == .upload }
            .subscribe { _ in
                print("Uploading Images!")
                self.sampleState.onNext(.previewUser)
            }
            .disposed(by: disposeBag)
    }
    
    func cancel() {
        events.onNext(.cancel)
    }
}


//.observeOn(MainScheduler.instance)
//.do { self.setupPreview(cameraState: self.viewModel.cameraState) }
//.flatMap { _ in return self.camera.preparePhotoSettings(numPhotos: 4).asObservable() }
//.flatMap { _ in return self.camera.capturePhoto(flashSettings: FlashSettings(area: 1, areas: 1)).asObservable() }
//.flatMap { _ in return self.camera.capturePhoto(flashSettings: FlashSettings(area: 1, areas: 2)).asObservable() }
//.flatMap { _ in return self.viewModel.getCamera().capturePhoto(flashSettings: FlashSettings(area: 2, areas: 2)).asObservable() }
//.flatMap { _ in return self.viewModel.getCamera().capturePhoto(flashSettings: FlashSettings(area: 0, areas: 1)).asObservable() }
