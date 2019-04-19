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
        FlashSettings(area: 14, areas: 14),
        FlashSettings(area: 13, areas: 14),
        FlashSettings(area: 12, areas: 14),
        FlashSettings(area: 11, areas: 14),
        FlashSettings(area: 10, areas: 14),
        FlashSettings(area: 9, areas: 14),
        FlashSettings(area: 8, areas: 14),
        FlashSettings(area: 7, areas: 14),]
    
    enum Event {
        case cancel
    }
    
    enum SampleStates {
        case prepping
        case previewUser
        case referenceSample
        case sample
        case process(photoData: [(AVCapturePhoto, FlashSettings)?])
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
                return Message(message: "It's Too Bright!", tip: "Try facing away from bright lights or trying again somewhere darker")
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
    let user: User
    let sampleState = BehaviorSubject<SampleStates>(value: .prepping)
    let userFaceState = BehaviorSubject<UserFaceStates>(value: .noFaceFound)
    
    let referencePhotos = PublishSubject<AVCapturePhoto>()
    let samplePhotos = PublishSubject<AVCapturePhoto>()
    
    let uploadProgress = BehaviorSubject<Float>(value: 0.0)
    let videoPreviewLayerStream = BehaviorSubject<AVCaptureVideoPreviewLayer?>(value: nil)
    let drawPointsStream = BehaviorSubject<[DisplayPoint]>(value: [])
    
    let flashSettings = BehaviorSubject<FlashSettings>(value: FlashSettings(area: 0, areas: 0))
    
    let events = PublishSubject<Event>()
    
    var originalScreenBrightness: CGFloat = 0.0
    var cameraState: CameraState
    var video: Video
    var videoSize = CGSize.init(width: 0, height: 0)
    
    var disposeBag = DisposeBag()
    
    init(user: User) {
        self.user = user
        cameraState = CameraState(flashStream: flashSettings)
        video = Video(cameraState: cameraState, videoPreviewLayerStream: videoPreviewLayerStream)
        
        video.realtimeDataStream
            .subscribe(onNext: { realtimeDataOptional in
                guard let realtimeData = realtimeDataOptional else {
                    //print("No realtime data")
                    self.userFaceState.onNext(.noFaceFound)
                    return
                }
                
                guard let videoLayer = try! self.videoPreviewLayerStream.value() else {
                    //print("No video preview layer")
                    self.userFaceState.onNext(.noFaceFound)
                    return
                }

                self.cameraState.exposurePointStream.onNext(realtimeData.exposurePoint.toNormalizedImagePoint(size: realtimeData.size))
                let displayPoints = realtimeData.landmarks.map { $0.toDisplayPoint(size: realtimeData.size, videoLayer: videoLayer) }
                
                if try! user.settings.showAllLandmarks.value() { self.drawPointsStream.onNext(displayPoints) }
                if try! user.settings.showExposureLandmarks.value() { self.drawPointsStream.onNext([realtimeData.exposurePoint.toDisplayPoint(size: realtimeData.size, videoLayer: videoLayer)]) }
                if try! user.settings.showBalanceLandmarks.value() { self.drawPointsStream.onNext(realtimeData.balancePoints.map { $0.toDisplayPoint(size: realtimeData.size, videoLayer: videoLayer)}) }
                if try! user.settings.showBrightnessLandmarks.value() { self.drawPointsStream.onNext(realtimeData.brightnessPoints.map { $0.toDisplayPoint(size: realtimeData.size, videoLayer: videoLayer)}) }

                let xImageValues = realtimeData.landmarks.map { $0.point.x }
                let yImageValues = realtimeData.landmarks.map { $0.point.y }
                
                let minImagePoint = ImagePoint.init(x: xImageValues.min()!, y: yImageValues.min()!)
                let maxImagePoint = ImagePoint.init(x: xImageValues.max()!, y: yImageValues.max()!)
                
                let faceSizeState = self.checkFaceSize(min: minImagePoint, max: maxImagePoint, imageSize: realtimeData.size)
                if faceSizeState != .ok {
                    self.userFaceState.onNext(faceSizeState)
                    return
                }
                
                let xDisplayValues = displayPoints.map { $0.point.x }
                let yDisplayValues = displayPoints.map { $0.point.y }
                
                let minDisplayPoint = DisplayPoint.init(x: xDisplayValues.min()!, y: yDisplayValues.min()!)
                let maxDisplayPoint = DisplayPoint.init(x: xDisplayValues.max()!, y: yDisplayValues.max()!)
                
                let faceClipState = self.checkFaceClipped(min: minDisplayPoint, max: maxDisplayPoint)
                if faceClipState != .ok {
                    self.userFaceState.onNext(faceClipState)
                    return
                }
                
                if realtimeData.isTooBright {
                    self.userFaceState.onNext(.tooBright)
                    return
                }
                
                if realtimeData.isLightingUnbalanced {
                    self.userFaceState.onNext(.faceGradient)
                    return
                }
                
                self.userFaceState.onNext(.ok)
            }).disposed(by: disposeBag)
        
        sampleState
            .subscribe(onNext: {
                switch $0 {
                case .previewUser:
                    self.cameraState.resetCameraState()
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
            .flatMap { _ in self.cameraState.preparePhotoSettings(numPhotos: self.screenFlashSettings.count + 1) }
            .flatMap { _ in self.captureReferencePhoto() }
            .subscribe { _ in
                print("Took Reference Sample!")
                self.sampleState.onNext(.sample)
            }
            .disposed(by: disposeBag)
        
        sampleState
            .observeOn(MainScheduler.instance)
            .filter { if case .sample = $0 { return true } else { return false } }
            //.flatMap { _ in self.cameraState.preparePhotoSettings(numPhotos: self.screenFlashSettings.count) }
            .flatMap { _ in self.captureSamplePhotos() }
            .subscribe(onNext: { photoData in
                self.sampleState.onNext(.process(photoData: photoData))
            }).disposed(by: disposeBag)
        
        sampleState
            .observeOn(MainScheduler.instance)
            .filter { if case .process = $0 { return true } else { return false } }
            .flatMap { processState -> Observable<[ImageData]> in
                if case .process(let photoData) = processState {
                    return self.processSamplePhotos(photoData)
                }
                return self.processSamplePhotos([nil])
            }
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
                        photo.setMetadata.prettyPrint()
                    }
                    
                    uploadImageData(imageData: imageData, progressBar: self.uploadProgress, user: self.user)
                        .subscribe(onNext: { _ in
                            print("Done Uploading to \(user.email)")
                            self.sampleState.onNext(.previewUser)
                        }).disposed(by: self.disposeBag)
                }
            }).disposed(by: disposeBag)
        
        sampleState.onNext(.previewUser)
    }
    
    func cancel() {
        events.onNext(.cancel)
    }
    
    private func captureSamplePhotos() -> Observable<[(AVCapturePhoto, FlashSettings)]> {
        return Observable.from(screenFlashSettings)
            .observeOn(MainScheduler.instance)
            //.observeOn(SerialDispatchQueueScheduler.init(internalSerialQueueName: "com.tone.imageCaptureQueue"))
            .map { (Camera(cameraState: self.cameraState), $0) }
            .serialMap { (camera, flashSetting) in camera.capturePhoto(flashSetting) }
            .toArray()
    }
    
    private func getEncapsulatingSize(sizes: [CGSize]) -> CGSize {
        let maxWidth = sizes.map { $0.width }.max()!
        let maxHeight = sizes.map { $0.height }.max()!
        return CGSize.init(width: maxWidth, height: maxHeight)
    }
    
    
    private func processSamplePhotos(_ photoData: [(AVCapturePhoto, FlashSettings)?]) -> Observable<[ImageData]> {
        let context = CIContext()
        
        return Observable.from(photoData)
            .observeOn(MainScheduler.instance) //Observe on background thread to free up the main thread?
            .flatMap { photoData -> Observable<FaceCapture?> in
                let (capturePhoto, flashSettings) = photoData!
                return FaceCapture.create(capturePhoto: capturePhoto, orientation: self.cameraState.exifOrientationForCurrentDeviceOrientation(), videoPreviewLayer: try! self.videoPreviewLayerStream.value()!, flashSettings: flashSettings)
            }
            .map { $0! } //TODO: Better error handling... All faces must have landmarks
            .toArray()
            .map { faceCaptures -> [ImageData] in
                //Find Face Crops and Left, Right Eye Crops
                //let leftEyeBBs = faceCaptures.map { bufferBoundingBox($0.getLeftEyeImageBB()!, imgSize: $0.imageSize) }
                let leftEyeSizes = faceCaptures.map { $0.getLeftEyeImageSize()! }
                let leftEyeCropSize = self.getEncapsulatingSize(sizes: leftEyeSizes) * 1.5 //Add a buffer of 25%
                
                let rightEyeSizes = faceCaptures.map { $0.getRightEyeImageSize()! }
                let rightEyeCropSize = self.getEncapsulatingSize(sizes: rightEyeSizes) * 1.5 //Add a buffer of 25%
                
                //We ultimately want a crop that crops from the right jaw to the left, top of the image to the bottom of the chin (want hair in image)
                let faceSizes = faceCaptures.map { $0.getAllPointsSize()! }
                let faceCropSize = self.getEncapsulatingSize(sizes: faceSizes) * 1.10
                let faceBBs = faceCaptures.map { $0.getAllPointsBB()! }
                let scaledFaceBBs = faceBBs.map { $0.scaleToSize(size: faceCropSize, imgSize: faceCaptures[0].imageSize.size) }
                let encapsulatingMaxX = scaledFaceBBs.map { $0.maxX }.max()!
                let faceCropWidth = encapsulatingMaxX
                
                return faceCaptures.map { faceCapture -> ImageData in
                    let leftEyeCrop = faceCapture.getLeftEyeImageBB()!.scaleToSize(size: leftEyeCropSize, imgSize: faceCapture.imageSize.size)
                    let rightEyeCrop = faceCapture.getRightEyeImageBB()!.scaleToSize(size: rightEyeCropSize, imgSize: faceCapture.imageSize.size)
                    var faceCrop = faceCapture.getAllPointsBB()!.scaleToSize(size: faceCropSize, imgSize: faceCapture.imageSize.size)
                    //faceCrop = CGRect.init(x: faceCrop.minX, y: 0, width: faceCrop.width, height: faceCropHeight)
                    faceCrop = CGRect.init(x: 0, y: faceCrop.minY, width: faceCropWidth, height: faceCrop.height)
                    
                    let faceImage = faceCapture.getImage()
                    let leftEyeImage = Image.from(image: faceImage, crop: leftEyeCrop, landmarks: Array(faceImage.landmarks[8...15]))
                    let rightEyeImage = Image.from(image: faceImage, crop: rightEyeCrop, landmarks: Array(faceImage.landmarks[16...23]))
                    faceImage.crop(faceCrop)
                    leftEyeImage.updateParentBB(parentCrop: faceCrop)
                    rightEyeImage.updateParentBB(parentCrop: faceCrop)
                    
                    let longSide = [faceCrop.width, faceCrop.height].max()!
                    let scaleRatio = 1080 / longSide
                    faceImage.scale(scaleRatio) //Dont forget to scale BB to eventually let you crop after scaling!
                    //leftEyeImage.updateParentBB(parentScale: scaleRatio)
                    //rightEyeImage.updateParentBB(parentScale: scaleRatio)
                    

                    faceImage.rotate()
                    leftEyeImage.rotate()
                    rightEyeImage.rotate()
                    
                    leftEyeImage.updateParentBB(rotate: true)
                    rightEyeImage.updateParentBB(rotate: true)
                    
                    
                    let pngDataFace = context.pngRepresentation(of: faceImage.image, format: CIFormat.BGRA8, colorSpace: CGColorSpace.init(name: CGColorSpace.sRGB)!, options: [:])!
                    
                    let pngDataLeftEye = context.pngRepresentation(of: leftEyeImage.image, format: CIFormat.BGRA8, colorSpace: CGColorSpace.init(name: CGColorSpace.sRGB)!, options: [:])!
                    
                    let pngDataRightEye = context.pngRepresentation(of: rightEyeImage.image, format: CIFormat.BGRA8, colorSpace: CGColorSpace.init(name: CGColorSpace.sRGB)!, options: [:])!
                    
                    let setMetadata = SetMetadata.getFrom(faceImage: faceImage, leftEyeImage: leftEyeImage, rightEyeImage: rightEyeImage, flashSettings: faceCapture.flashSettings, cameraState: self.cameraState, rawMetadata: faceCapture.rawMetadata)
                
                    return ImageData(faceData: pngDataFace, leftEyeData: pngDataLeftEye, rightEyeData: pngDataRightEye, setMetadata: setMetadata)
                    //DONT FORGET TO TRANSFER EYE WIDTH AS WELL!
                }
            }
    }
    
    //Eventually scale exposure to that it doesnt clip in reflection
    private func captureReferencePhoto() -> Observable<Bool> {
        let flashSetting = FlashSettings(area: 1, areas: 1)
        
        return Observable.just(flashSetting)
            .observeOn(MainScheduler.instance)
            .map { (Camera(cameraState: self.cameraState), $0) }
            .do(onNext: { _ in self.cameraState.unlockCameraSettings() })
            .serialMap { (camera, flashSetting) in camera.capturePhoto(flashSetting) }
            .flatMap { _ in self.cameraState.lockCameraSettings() }
            .map { _ in true }
    }
    
    private func checkFaceSize(min: ImagePoint, max: ImagePoint, imageSize: ImageSize) -> UserFaceStates {
        let width = max.point.x - min.point.x
        let height = 1.5 * (max.point.y - min.point.y) //1.65 is just a ~random value approximate where the top of the head is since points only cover up to the eyebrows
        
        let fractionWidth = width / imageSize.size.width
        let fractionHeight = height / imageSize.size.height
        
        //Mostly to avoid picking up background faces
        if (fractionWidth < 0.20) || (fractionHeight < 0.20) {
            return .noFaceFound
        } else if (fractionWidth < 0.3) || (fractionHeight < 0.6) {
            return .faceTooFar
        } else if (fractionWidth > 0.7) || (fractionHeight > 0.9) {
            return .faceTooClose
        }
        
        return .ok
    }
    
    private func checkFaceClipped(min: DisplayPoint, max: DisplayPoint) -> UserFaceStates {
        let height = 1.5 * (max.point.y - min.point.y)
 
        if min.point.x < -10 {
            return .faceTooFarLeft
        } else if max.point.x > self.videoSize.width + 10 {
            return .faceTooFarRight
        } else if max.point.y > self.videoSize.height + 10 {
            return .faceTooFarDown
        } else if (max.point.y - height) < -10 {
            return .faceTooFarUp
        }
        
        return .ok
    }
}

