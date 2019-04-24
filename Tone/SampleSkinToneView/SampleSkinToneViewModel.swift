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
import UIKit

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
        case beginSetUp
        case beginPreview
        case beginFlash
        case beginProcessing
        case beginUpload
        case resumePreview
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
        case faceTiltedVertically
        case faceTiltedHorizontally
        case faceRotated
        
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
            case .faceTiltedVertically:
                return Message(message: "You're taking the photo at an angle!", tip: "Try adjusting your head up or down")
            case .faceTiltedHorizontally:
                return Message(message: "You're not facing the camera!", tip: "Try adjusting your left up or right")
            case .faceRotated:
                return Message(message: "Your head is at an angle!", tip: "Try aligning your head vertically")
            case .faceGradient:
                return Message(message: "You're Unevenly Lit!", tip: "Try facing away from the brightest lights in the room")
            }
        }
    }
    let user: User
    //let sampleState = BehaviorSubject<SampleStates>(value: .setup)
    let userFaceState = BehaviorSubject<UserFaceStates>(value: .noFaceFound)
    
    //let referencePhotos = PublishSubject<AVCapturePhoto>()
    let samplePhotos = PublishSubject<AVCapturePhoto>()
    
    let uploadProgress = BehaviorSubject<Float>(value: 0.0)
    let videoPreviewLayerStream = BehaviorSubject<AVCaptureVideoPreviewLayer?>(value: nil)
    let drawPointsStream = BehaviorSubject<[DisplayPoint]>(value: [])
    
    let flashSettingsTaskStream = PublishSubject<FlashSettingsTask>()
    
    let events = BehaviorSubject<Event>(value: .beginSetUp)
    
    var originalScreenBrightness: CGFloat = 0.0
    var videoSize = CGSize.init(width: 0, height: 0)

    lazy var cameraState: CameraState = CameraState(flashTaskStream: self.flashSettingsTaskStream)
    lazy var video: Video = Video(cameraState: self.cameraState, videoPreviewLayerStream: self.videoPreviewLayerStream)
    
    var disposeBag = DisposeBag()
        
    //Shared Between Flash and Draw Overlay
    let renderer = UIGraphicsImageRenderer(size: UIScreen.main.bounds.size)
    let context = CIContext() //For processing PNGs
    
    init(user: User) {
        self.user = user
        
        flashSettingsTaskStream.subscribe(onNext: { _ in
            print("IN MODEL: Recieved a flash task!")
        }).disposed(by: disposeBag)
        
        //Asynchronously load the video stream. Lets the views load first
        DispatchQueue.global(qos: .userInitiated).async {
            self.video.realtimeDataStream
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
                    //print("Real Time Size :: \(realtimeData.size) | Video Layer Size :: \(self.videoSize)")
                    if try! user.settings.showAllLandmarks.value() { self.drawPointsStream.onNext(displayPoints) }
                    if try! user.settings.showExposureLandmarks.value() { self.drawPointsStream.onNext([realtimeData.exposurePoint.toDisplayPoint(size: realtimeData.size, videoLayer: videoLayer)]) }
                    if try! user.settings.showBalanceLandmarks.value() { self.drawPointsStream.onNext(realtimeData.balancePoints.map { $0.toDisplayPoint(size: realtimeData.size, videoLayer: videoLayer)}) }
                    if try! user.settings.showBrightnessLandmarks.value() { self.drawPointsStream.onNext(realtimeData.brightnessPoints.map { $0.toDisplayPoint(size: realtimeData.size, videoLayer: videoLayer)}) }
                    if try! user.settings.showFacingCameraLandmarks.value() { self.drawPointsStream.onNext(realtimeData.facingCameraPoints.map { $0.toDisplayPoint(size: realtimeData.size, videoLayer: videoLayer)}) }
                   /*
                    let xImageValues = realtimeData.landmarks.map { $0.point.x }
                    let yImageValues = realtimeData.landmarks.map { $0.point.y }
                    
                    let minImagePoint = ImagePoint.init(x: xImageValues.min()!, y: yImageValues.min()!)
                    let maxImagePoint = ImagePoint.init(x: xImageValues.max()!, y: yImageValues.max()!)
                    
                    let faceSizeState = self.checkFaceSize(min: minImagePoint, max: maxImagePoint, imageSize: realtimeData.size)
                    if faceSizeState != .ok {
                        self.userFaceState.onNext(faceSizeState)
                        return
                    }
                    
                    if realtimeData.isRotated {
                        self.userFaceState.onNext(.faceRotated)
                        return
                    }
                    
                    if realtimeData.isNotHorizontallyAligned {
                        self.userFaceState.onNext(.faceTiltedHorizontally)
                        return
                    }
                    
                    if realtimeData.isNotVerticallyAligned {
                        self.userFaceState.onNext(.faceTiltedVertically)
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
        */
                    self.userFaceState.onNext(.ok)
                }).disposed(by: self.disposeBag)
            
            self.events.onNext(.beginPreview)

        }
    }
    
    func takeSample() {
        print("TAKING SAMPLE, BEGINNING FLASH!")

        events.onNext(.beginFlash)
        
        DispatchQueue.global(qos: .userInitiated).async {
            Observable.just(self.screenFlashSettings.count)
                .flatMap { numberOfCaptures in self.cameraState.preparePhotoSettings(numPhotos: numberOfCaptures) }
                .flatMap { _ in Observable.from(self.screenFlashSettings) }
                .map { flashSetting in (Camera(cameraState: self.cameraState), flashSetting) }
                //.serialFlatMap { (camera, flashSetting) in camera.capturePhoto(flashSetting) }
                .serialMap { (camera, flashSetting) in camera.capturePhoto(flashSetting) }
                .do(onCompleted: { self.events.onNext(.beginProcessing) })
                .flatMap { photoData -> Observable<FaceCapture?> in
                    let (capturePhoto, flashSettings) = photoData
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
                        
                        let pngDataFace = self.context.pngRepresentation(of: faceImage.image, format: CIFormat.BGRA8, colorSpace: CGColorSpace.init(name: CGColorSpace.sRGB)!, options: [:])!
                        
                        let pngDataLeftEye = self.context.pngRepresentation(of: leftEyeImage.image, format: CIFormat.BGRA8, colorSpace: CGColorSpace.init(name: CGColorSpace.sRGB)!, options: [:])!
                        
                        let pngDataRightEye = self.context.pngRepresentation(of: rightEyeImage.image, format: CIFormat.BGRA8, colorSpace: CGColorSpace.init(name: CGColorSpace.sRGB)!, options: [:])!
                        
                        let setMetadata = SetMetadata.getFrom(faceImage: faceImage, leftEyeImage: leftEyeImage, rightEyeImage: rightEyeImage, flashSettings: faceCapture.flashSettings, cameraState: self.cameraState, rawMetadata: faceCapture.rawMetadata)
                        
                        return ImageData(faceData: pngDataFace, leftEyeData: pngDataLeftEye, rightEyeData: pngDataRightEye, setMetadata: setMetadata)
                        //DONT FORGET TO TRANSFER EYE WIDTH AS WELL!
                    }
                }
                .do(onCompleted: { self.events.onNext(.beginUpload) })
                .flatMap { imageData -> Observable<UploadStatus> in
                    self.uploadProgress.onNext(0.0)
                    print("Uploading Images!")
                    for photo in imageData {
                        photo.setMetadata.prettyPrint()
                    }
                    
                    return uploadImageData(imageData: imageData, progressBar: self.uploadProgress, user: self.user)
                }
                .subscribe(onNext: { uploadStatus in
                    if uploadStatus.doneUpload && !uploadStatus.responseRecieved {
                        self.events.onNext(.beginProcessing)
                    } else if uploadStatus.doneUpload && uploadStatus.responseRecieved {
                        print("Done Uploading \(self.user.email)")
                        self.events.onNext(.resumePreview)
                        self.cameraState.resetCameraState()
                    }
                }).disposed(by: self.disposeBag)
        }
    }
    
    func cancel() {
        events.onNext(.cancel)
    }
    
    private func checkFaceSize(min: ImagePoint, max: ImagePoint, imageSize: ImageSize) -> UserFaceStates {
        let width = max.point.x - min.point.x
        let height = 1.5 * (max.point.y - min.point.y) //1.65 is just a ~random value approximate where the top of the head is since points only cover up to the eyebrows
        
        let fractionWidth = width / imageSize.size.width
        let fractionHeight = height / imageSize.size.height
        
        //Mostly to avoid picking up background faces
        if (fractionWidth < 0.20) || (fractionHeight < 0.20) {
            return .noFaceFound
        } else if (fractionWidth < 0.4) || (fractionHeight < 0.85) {
            return .faceTooFar
        } else if (fractionWidth > 0.7) || (fractionHeight > 1.0) {
            return .faceTooClose
        }
        
        return .ok
    }
    
    private func checkFaceClipped(min: DisplayPoint, max: DisplayPoint) -> UserFaceStates {
        let height = 1.5 * (max.point.y - min.point.y)
        let margin = CGFloat(20)
 
        if min.point.x < (-1 * margin) {
            return .faceTooFarLeft
        } else if max.point.x > self.videoSize.width + margin {
            return .faceTooFarRight
        } else if max.point.y > self.videoSize.height { //This is a hard cutoff of facial features we actually want.. make sure its in the frame
            return .faceTooFarDown
        } else if (max.point.y - height) < (-1 * margin) {
            return .faceTooFarUp
        }
        
        return .ok
    }
    
    private func getEncapsulatingSize(sizes: [CGSize]) -> CGSize {
        let maxWidth = sizes.map { $0.width }.max()!
        let maxHeight = sizes.map { $0.height }.max()!
        return CGSize.init(width: maxWidth, height: maxHeight)
    }
}

