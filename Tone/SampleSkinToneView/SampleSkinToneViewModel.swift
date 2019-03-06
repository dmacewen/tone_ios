//
//  SampleSkinToneViewModel.swift
//  Tone
//
//  Created by Doug MacEwen on 10/30/18.
//  Copyright © 2018 Doug MacEwen. All rights reserved.
//

import Foundation
import RxSwift
import AVFoundation
import Alamofire
import Vision

class SampleSkinToneViewModel {
    
    let screenFlashSettings = [
        //FlashSettings(area: 9, areas: 9),
        //FlashSettings(area: 8, areas: 9),
        FlashSettings(area: 7, areas: 7),
        FlashSettings(area: 6, areas: 7),
        FlashSettings(area: 5, areas: 7),
        FlashSettings(area: 4, areas: 7),
        FlashSettings(area: 3, areas: 7),
        FlashSettings(area: 2, areas: 7),
        FlashSettings(area: 1, areas: 7),
        FlashSettings(area: 0, areas: 7)]
    
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
                return Message(message: "Your Face Is Too Bright!", tip: "Try facing away from bright lights or trying again somewhere darker")
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
    
    let flashSettings = BehaviorSubject<FlashSettings>(value: FlashSettings(area: 0, areas: 0))
    
    let events = PublishSubject<Event>()
    
    var originalScreenBrightness: CGFloat = 0.0
    var cameraState: CameraState
    var video: Video
    var videoSize = CGSize.init(width: 0, height: 0)
    
    let disposeBag = DisposeBag()
    
    init() {
        cameraState = CameraState(flashStream: flashSettings)
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
                
                if !faceData!.isLightingBalanced {
                    self.userFaceState.onNext(.faceGradient)
                    return
                }
                
                let maxExposureIso: Float = 50.0
                let maxExposureDuration: Float = 0.50
                
                let totalExposureMultiple = (faceData!.iso/maxExposureIso) * (faceData!.exposureDuration/maxExposureDuration)
                
                if totalExposureMultiple < 1.0 {
                    self.userFaceState.onNext(.tooBright)
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
            .subscribe(onNext: {
                switch $0 {
                case .previewUser:
                    self.video.resumeProcessing()
                default:
                    self.video.pauseProcessing()
                }
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
            .flatMap { _ in self.cameraState.preparePhotoSettings(numPhotos: self.screenFlashSettings.count) }
            .flatMap { _ in self.captureSamplePhotos() }
            .subscribe(onNext: { imageData in
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
        let context = CIContext()
        
        return Observable.from(screenFlashSettings)
            .observeOn(MainScheduler.instance)
            //.observeOn(SerialDispatchQueueScheduler.init(internalSerialQueueName: "com.tone.imageCaptureQueue"))
            .map { (Camera(cameraState: self.cameraState), $0) }
            .serialMap { (camera, flashSetting) in camera.capturePhoto(flashSetting) }
            .flatMap { capture in self.getFaceLandmarks(capture: capture) }
            .toArray()
            .map { photoData in
                let imageData = photoData.map { photoDatum -> ImageData in
                    guard let (_, capturePhoto, _) = photoDatum else {
                        fatalError("Did not recieve face data")
                    }
                    
                    let ciImage = CIImage(cgImage: capturePhoto.cgImageRepresentation()!.takeUnretainedValue())
                    var imageTransforms = ImageTransforms()
                    //let linearCIImage = convertImageToLinear(ciImage, &imageTransforms)
                    //let rotatedCIImage = rotateImage(linearCIImage, &imageTransforms)
                    let rotatedCIImage = rotateImage(ciImage, &imageTransforms)
                    let pngData = context.pngRepresentation(of: rotatedCIImage, format: CIFormat.BGRA8, colorSpace: CGColorSpace.init(name:  CGColorSpace.sRGB)!, options: [:])
                    let metaData = getImageMetadata(cameraState: self.cameraState, photoData: photoDatum, imageTransforms: imageTransforms)
                    return ImageData(imageData: pngData!, metaData: metaData)
                }
                
                return imageData
            }
    }
    
    //Eventually scale exposure to that it doesnt clip in reflection
    private func captureReferencePhoto() -> Observable<Bool> {
        let flashSetting = FlashSettings(area: 3, areas: 3)
        
        //.repeatElement When we need more then one?
        return Observable.just(flashSetting)
            .observeOn(MainScheduler.instance)
            //.observeOn(SerialDispatchQueueScheduler.init(internalSerialQueueName: "com.tone.imageCaptureQueue"))
            .map { (Camera(cameraState: self.cameraState), $0) }
            .do(onNext: { _ in self.cameraState.unlockCameraSettings() })
            .serialMap { (camera, flashSetting) in camera.capturePhoto(flashSetting) }
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
        } else if (fractionWidth < 0.55) || (fractionHeight < 0.6) {
            return .faceTooFar
        } else if (fractionWidth > 0.7) || (fractionHeight > 0.8) {
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
    
    func getFaceLandmarks(capture: (AVCapturePhoto, FlashSettings)) -> Observable<(VNFaceLandmarks2D, AVCapturePhoto, FlashSettings)?> {
        let (photo, flashSettings) = capture
        return getFacialLandmarks(cameraState: cameraState, pixelBuffer: photo.pixelBuffer!)
            .map({
                guard let (landmarks, _) = $0 else {
                    return nil
                }
                return (landmarks, photo, flashSettings)
            })
    }
}

