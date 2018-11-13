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
    
    struct Message {
        let message: String
        let tip: String
    }
    
    enum UserFaceStates {
        case ok
        case noFaceFound
        case tooDark
        case tooBright
        case faceGradient
        case faceTooFar
        case faceTooClose
        case faceTooFarDown
        case faceTooFarUp
        case faceTooFarLeft
        case faceTooFarRight
        
        var prompt: Message {
            switch self {
            case .ok:
                return Message(message: "Looking Good!", tip: "Hit the button to capture your skin tone")
            case .noFaceFound:
                return Message(message: "Looking For You...", tip: "Is the camera pointed towards you?")
            case .tooDark:
                return Message(message: "It's A Little Too Dark Here", tip: "Lets try again in a room with a bit more light")
            case .tooBright:
                return Message(message: "It's A Little Too Bright Here", tip: "Try facing away from bright lights or trying again somewhere darker")
            case .faceTooFar:
                return Message(message: "You're Too Far Away!", tip: "Bring the phone closer to your face!")
            case .faceTooClose:
                return Message(message: "You're Too Close!", tip: "Move the phone a little farther from your face!")
            case .faceTooFarDown:
                return Message(message: "Your chin is cropped!", tip: "Try moving the phone down")
            case .faceTooFarUp:
                return Message(message: "Your head is cropped!", tip: "Try moving the phone up")
            case .faceTooFarLeft:
                return Message(message: "Your left cheek is cropped!", tip: "Try moving the phone to your left")
            case .faceTooFarRight:
                return Message(message: "Your right cheek is cropped!", tip: "Try moving the phone to your right")
            case .faceGradient:
                return Message(message: "You're Unevenly Lit!", tip: "Try facing away from the brightest lights in the room")
            //case .faceGradient:
                //return "The Lighting On Your Face Is Uneven!"// Try and face away from the brightest light in the room"
            }
        }
    }
    
    
    let userFaceState = BehaviorSubject<UserFaceStates>(value: .noFaceFound)
    let sampleState = BehaviorSubject<SampleStates>(value: .previewUser)
    
    let referencePhotos = PublishSubject<AVCapturePhoto>()
    let samplePhotos = PublishSubject<AVCapturePhoto>()
    
    let uploadProgress = BehaviorSubject<Float>(value: 0.0)
    
    let flashSettings = PublishSubject<FlashSettings>()
    
    let events = PublishSubject<Event>()
    
    var originalScreenBrightness: CGFloat = 0.0
    var cameraState: CameraState
    var video: Video
    var videoSize = CGSize.init(width: 0, height: 0)
    
    let disposeBag = DisposeBag()
    
    init() {
        cameraState = CameraState(flashStream: flashSettings)//, photoStream: samplePhotos)
        video = Video(cameraState: cameraState)
        
        video.faceLandmarks
            .subscribe(onNext: { faceData in
                if faceData == nil {
                    self.userFaceState.onNext(.noFaceFound)
                    return
                }
                
                let facePoints = faceData!.landmarks.faceContour!.pointsInImage(imageSize: self.videoSize)
                let xValues = facePoints.map { $0.x }
                let yValues = facePoints.map { $0.y }
                
                let max = CGPoint.init(x: xValues.max()!, y: yValues.max()!)
                let min = CGPoint.init(x: xValues.min()!, y: yValues.min()!)
                
                let faceSizeState = self.checkFaceSize(min: min, max: max)
                
                if faceSizeState != .ok {
                    self.userFaceState.onNext(faceSizeState)
                    return
                }
                
                //print("Cheek Ratio! :: \(faceData!.cheekRatio)")
                if faceData!.cheekRatio > 0.15 {
                    self.userFaceState.onNext(.faceGradient)
                    return
                }
                
                let faceClipState = self.checkFaceClipped(min: min, max: max)
                
                if faceClipState != .ok {
                    self.userFaceState.onNext(faceClipState)
                    return
                }
                
                self.userFaceState.onNext(.ok)
            }).disposed(by: disposeBag)
        
        sampleState
            .subscribe(onCompleted: { print("Sample State Completed!!!") })
            .disposed(by: disposeBag)
        
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
            .flatMap { _ in self.cameraState.preparePhotoSettings(numPhotos: 3) }
            .flatMap { _ in self.captureSamplePhotos() }
            .subscribe(onNext: { imageData in
                //print("Got Sample Photos :: \(photos)")
                self.sampleState.onNext(.upload(images: imageData))
            }).disposed(by: disposeBag)
        
        sampleState
            .observeOn(MainScheduler.instance)
            .filter { if case .upload = $0 { return true } else { return false } }
            .subscribe(onNext: {
                self.uploadProgress.onNext(0.0)
                if case .upload(let imageData) = $0 {
                    print("Uploading Images!")
                    for photo in imageData {
                        photo.metaData.prettyPrint()
                    }
                    
                    uploadImageData(imageData: imageData, progressBar: self.uploadProgress)
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
            FlashSettings(area: 2, areas: 2),
            FlashSettings(area: 1, areas: 2),
            FlashSettings(area: 0, areas: 2)]
        
        return Observable.from(flashSettings)
            .observeOn(MainScheduler.instance)
            .map { (Camera(cameraState: self.cameraState), $0) }
            .serialMap { (camera, flashSetting) in camera.capturePhoto(flashSetting) }
            .map { photo in  createUIImageSet(cameraState: self.cameraState, photo: photo)}
            //.do(onNext: { imageData in UIImageWriteToSavedPhotosAlbum(imageData.image, nil, nil, nil) })
            .toArray()
    }
    
    //Eventually scale exposure to that it doesnt clip in reflection
    private func captureReferencePhoto() -> Observable<Bool> {
        let flashSetting = FlashSettings(area: 2, areas: 2)
        
        //.repeatElement When we need more then one?
        return Observable.once(flashSetting)
            .observeOn(MainScheduler.instance)
            .map { (Camera(cameraState: self.cameraState), $0) }
            .serialMap { (camera, flashSetting) in camera.capturePhoto(flashSetting) }
            //.do { self.cameraState.lockCameraSettings() }
            .toArray()
            .flatMap { _ in self.cameraState.lockCameraSettings() }
            .map { _ in true }
    }
    
    private func checkFaceSize(min: CGPoint, max: CGPoint) -> UserFaceStates {
        let width = max.x - min.x
        let height = 1.65 * (max.y - min.y)
        
        let fractionWidth = width / self.videoSize.width
        let fractionHeight = height / self.videoSize.height
        
        //Mostly to avoid picking up background faces
        if (fractionWidth < 0.20) || (fractionHeight < 0.20) {
            return .noFaceFound
        } else if (fractionWidth < 0.65) || (fractionHeight < 0.7) {
            return .faceTooFar
        } else if (fractionWidth > 0.9) || (fractionHeight > 1.0) {
            return .faceTooClose
        }
        
        return .ok
    }
    
    private func checkFaceClipped(min: CGPoint, max: CGPoint) -> UserFaceStates {
        let height = 1.65 * (max.y - min.y)

        if min.x < 0 {
            return .faceTooFarLeft
        } else if max.x > self.videoSize.width {
            return .faceTooFarRight
        } else if min.y < -10 {
            return .faceTooFarDown
        } else if (min.y + height) > self.videoSize.height {
            return .faceTooFarUp
        }
        
        return .ok
    }
}
