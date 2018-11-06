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
import Alamofire
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
        case upload(images: [ImageData])
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
    
    let progressBar = BehaviorSubject<Float>(value: 0.0)
    
    let flashSettings = PublishSubject<FlashSettings>()
    
    let events = PublishSubject<Event>()
    
    var originalScreenBrightness: CGFloat = 0.0
    var cameraState: CameraState
    
    let disposeBag = DisposeBag()

    init() {
        cameraState = CameraState(flashStream: flashSettings)//, photoStream: samplePhotos)
        
        sampleState
            .observeOn(MainScheduler.instance)
            .filter { if case .previewUser = $0 { return true } else { return false } }
            .subscribe { _ in self.cameraState.unlockCameraSettings() }
            .disposed(by: disposeBag)
            
        sampleState
            .observeOn(MainScheduler.instance)
            .filter { if case .referenceSample = $0 { return true } else { return false } }
            .flatMap { _ in self.captureReferencePhoto() }
            .subscribe { _ in
                print("Took Reference Sample!")
                self.sampleState.onNext(.sample)
            }
            .disposed(by: disposeBag)
        
        sampleState
            .observeOn(MainScheduler.instance)
            .filter { if case .sample = $0 { return true } else { return false } }
            .flatMap { _ in self.cameraState.preparePhotoSettings(numPhotos: 4) }
            .flatMap { _ in self.captureSamplePhotos() }
            .subscribe(onNext: { imageData in
                //print("Got Sample Photos :: \(photos)")
                self.sampleState.onNext(.upload(images: imageData))
            }).disposed(by: disposeBag)
        
        sampleState
            .observeOn(MainScheduler.instance)
            .filter { if case .upload = $0 { return true } else { return false } }
            .subscribe(onNext: {
                print("")
                if case .upload(let imageData) = $0 {
                    print("Uploading Images!")
                    for photo in imageData {
                        photo.metaData.prettyPrint()
                    }
                    
                    uploadImageData(imageData: imageData, progressBar: self.progressBar)
                        .subscribe(onNext: { _ in
                            print("Done Upload")
                            self.sampleState.onNext(.previewUser)
                        }).disposed(by: self.disposeBag)
                }
            }).disposed(by: disposeBag)
    }
    
    func cancel() {
        events.onNext(.cancel)
    }
    
    private func captureSamplePhotos() -> Observable<[ImageData]> {
        let flashSettings = [
            FlashSettings(area: 1, areas: 1),
            FlashSettings(area: 1, areas: 2),
            FlashSettings(area: 2, areas: 2),
            FlashSettings(area: 0, areas: 1)]
        
        return Observable.from(flashSettings)
            .map { (Camera(cameraState: self.cameraState), $0) }
            .serialMap { (camera, flashSetting) in camera.capturePhoto(flashSetting) }
            .map { photo in  createUIImageSet(cameraState: self.cameraState, photo: photo)}
            //.do(onNext: { imageData in UIImageWriteToSavedPhotosAlbum(imageData.image, nil, nil, nil) })
            .toArray()
    }
    
    //Eventually scale exposure to that it doesnt clip in reflection
    private func captureReferencePhoto() -> Observable<Bool> {
        let flashSetting = FlashSettings(area: 1, areas: 1)
        
        //.repeatElement When we need more then one?
        return Observable.once(flashSetting)
            .map { (Camera(cameraState: self.cameraState), $0) }
            .serialMap { (camera, flashSetting) in camera.capturePhoto(flashSetting) }
            .do { self.cameraState.lockCameraSettings() }
            .toArray()
            .map { _ in true }
    }
}
