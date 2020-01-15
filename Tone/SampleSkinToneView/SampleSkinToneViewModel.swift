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

class SampleSkinToneViewModel: ViewModel {
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
        case showHelp
        case beginSetUp
        case beginPreview
        case beginFlash
        case beginProcessing
        case beginUpload
        case doneSample
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
                return Message(message: "Looking Good - Click Sample!", tip: "Hit the button to capture your skin tone")
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
                return Message(message: "Center your face in the screen", tip: "Try moving the phone to your left")
            case .faceTooFarRight:
                return Message(message: "Center your face in the screen", tip: "Try moving the phone to your left")
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

    var originalScreenBrightness: CGFloat = 0.0
    var videoSize = CGSize.init(width: 0, height: 0)
    let user: User

    let events = BehaviorSubject<Event>(value: .beginSetUp)
    let userFaceState = BehaviorSubject<UserFaceStates>(value: .noFaceFound)
    
    let samplePhotos = PublishSubject<AVCapturePhoto>()
    let uploadProgress = BehaviorSubject<Float>(value: 0.0)

    let didFlashViewLoad = PublishSubject<Bool>()
    let flashSettingsTaskStream = PublishSubject<FlashSettingsTask>()

    let videoPreviewLayerStream = BehaviorSubject<AVCaptureVideoPreviewLayer?>(value: nil)
    let drawPointsStream = BehaviorSubject<[DisplayPoint]>(value: [])
    
    let shouldProcessRealtime = BehaviorSubject<ProcessRealtime>(value: .yes)
    let exposeAndEndVideoOneShot = BehaviorSubject<Bool>(value: false)

    lazy var cameraState: CameraState = CameraState(flashTaskStream: self.flashSettingsTaskStream)
    lazy var video: Video = Video(cameraState: self.cameraState, shouldProcessRealtime: self.shouldProcessRealtime)
    
    var disposeBag = DisposeBag()
        
    //Shared Between Flash and Draw Overlay
    let videoOverlayRenderer = UIGraphicsImageRenderer(size: UIScreen.main.bounds.size)
    
    init(user: User) {
        self.user = user
        super.init()
        self.isCancelable = true
    }

    override func afterLoad() {

        DispatchQueue.global(qos: .userInitiated).async { [unowned video, unowned cameraState, unowned self] in
            self.exposeAndEndVideoOneShot
                .filter { $0 }
                .take(1)
                .subscribe(onNext: { [unowned self] _ in
                    self.video.pauseProcessing()
                }).disposed(by: self.disposeBag)

            video.realtimeDataStream
                .subscribe(onNext: { [weak self, unowned cameraState] realtimeDataOptional in

                    guard let localSelf = self else { return }
                    
                    guard let realtimeData = realtimeDataOptional else {
                        localSelf.userFaceState.onNext(.noFaceFound)
                        cameraState.exposurePointStream.onNext(NormalizedImagePoint.init(x: 0.5, y: 0.5))
                        return
                    }
                    
                    guard let videoLayer = try! localSelf.videoPreviewLayerStream.value() else {
                        localSelf.userFaceState.onNext(.noFaceFound)
                        cameraState.exposurePointStream.onNext(NormalizedImagePoint.init(x: 0.5, y: 0.5))
                        return
                    }

                    print("SETTING EXPOSURE POINT")
                    cameraState.exposurePointStream.onNext(realtimeData.exposurePoint.toNormalizedImagePoint(size: realtimeData.size))
                    
                    let displayPoints = realtimeData.landmarks.map { $0.toDisplayPoint(size: realtimeData.size, videoLayer: videoLayer) }

                    //Overlay points on image if the user selects the option
                    if try! localSelf.user.settings.showAllLandmarks.value() {
                        localSelf.drawPointsStream.onNext(displayPoints) 
                    }

                    if try! localSelf.user.settings.showExposureLandmarks.value() {
                        localSelf.drawPointsStream.onNext([realtimeData.exposurePoint.toDisplayPoint(size: realtimeData.size, videoLayer: videoLayer)]) 
                    }

                    if try! localSelf.user.settings.showBalanceLandmarks.value() {
                        localSelf.drawPointsStream.onNext(realtimeData.balancePoints.map { $0.toDisplayPoint(size: realtimeData.size, videoLayer: videoLayer)}) 
                    }

                    if try! localSelf.user.settings.showBrightnessLandmarks.value() {
                        localSelf.drawPointsStream.onNext(realtimeData.brightnessPoints.map { $0.toDisplayPoint(size: realtimeData.size, videoLayer: videoLayer)}) 
                    }

                    if try! localSelf.user.settings.showFacingCameraLandmarks.value() {
                        localSelf.drawPointsStream.onNext(realtimeData.facingCameraPoints.map { $0.toDisplayPoint(size: realtimeData.size, videoLayer: videoLayer)}) 
                    }

                    if try! localSelf.user.settings.showEyeExposureLandmarks.value() {
                        localSelf.drawPointsStream.onNext(realtimeData.eyeExposurePoints.map { $0.toDisplayPoint(size: realtimeData.size, videoLayer: videoLayer)})
                    }
                    
                    //Calculate the size of the face
                    let xImageValues = realtimeData.landmarks.map { $0.point.x }
                    let yImageValues = realtimeData.landmarks.map { $0.point.y }
                    
                    let minImagePoint = ImagePoint.init(x: xImageValues.min()!, y: yImageValues.min()!)
                    let maxImagePoint = ImagePoint.init(x: xImageValues.max()!, y: yImageValues.max()!)
                    
                    //Check that the user is lined up and properly lit for a good capture. Give feedback if not
                    let faceSizeState = localSelf.checkFaceSize(min: minImagePoint, max: maxImagePoint, imageSize: realtimeData.size)
                    if faceSizeState != .ok {
                        localSelf.userFaceState.onNext(faceSizeState)
                        return
                    }
                    
                    if realtimeData.isTooBright {
                        localSelf.userFaceState.onNext(.tooBright)
                        return
                    }
                    
                    if realtimeData.isRotated {
                        localSelf.userFaceState.onNext(.faceRotated)
                        return
                    }
                    
                    if realtimeData.isNotHorizontallyAligned {
                        localSelf.userFaceState.onNext(.faceTiltedHorizontally)
                        return
                    }
                    
                    if realtimeData.isNotVerticallyAligned {
                        localSelf.userFaceState.onNext(.faceTiltedVertically)
                        return
                    }
                    
                    let xDisplayValues = displayPoints.map { $0.point.x }
                    let yDisplayValues = displayPoints.map { $0.point.y }
                    
                    let minDisplayPoint = DisplayPoint.init(x: xDisplayValues.min()!, y: yDisplayValues.min()!)
                    let maxDisplayPoint = DisplayPoint.init(x: xDisplayValues.max()!, y: yDisplayValues.max()!)
                    
                    let faceClipState = localSelf.checkFaceClipped(min: minDisplayPoint, max: maxDisplayPoint)
                    if faceClipState != .ok {
                        localSelf.userFaceState.onNext(faceClipState)
                        return
                    }
                    
                    if realtimeData.isLightingUnbalanced {
                        localSelf.userFaceState.onNext(.faceGradient)
                        return
                    }
                    
                    localSelf.userFaceState.onNext(.ok)
                }).disposed(by: self.disposeBag)
            self.events.onNext(.beginPreview)
        }
    }
    
    private static func processFaceCaptures(_ cameraState: CameraState, _ faceCaptures: [FaceCapture]) -> [ImageData] {
        print("Processing Face Captures")

        let leftEyeSizes = faceCaptures.map { $0.getLeftEyeImageSize()! }
        let leftEyeCropSize = SampleSkinToneViewModel.getEncapsulatingSize(sizes: leftEyeSizes) * 1.5 //Add a buffer of 25%
        
        let rightEyeSizes = faceCaptures.map { $0.getRightEyeImageSize()! }
        let rightEyeCropSize = SampleSkinToneViewModel.getEncapsulatingSize(sizes: rightEyeSizes) * 1.5 //Add a buffer of 25%
        
        //We ultimately want a crop that crops from the right jaw to the left, top of the image to the bottom of the Image (want hair and neck in image)
        let faceSizes = faceCaptures.map { $0.getAllPointsSize()! }
        let faceCropSize = SampleSkinToneViewModel.getEncapsulatingSize(sizes: faceSizes) * 1.10
        let fullFaceWidth = faceCaptures[0].imageSize.size.width

        let context = CIContext() //For processing PNGs

        return faceCaptures.map { faceCapture -> ImageData in
            let leftEyeCrop = faceCapture.getLeftEyeImageBB()!.scaleToSize(size: leftEyeCropSize, imgSize: faceCapture.imageSize.size)
            let rightEyeCrop = faceCapture.getRightEyeImageBB()!.scaleToSize(size: rightEyeCropSize, imgSize: faceCapture.imageSize.size)
            var faceCrop = faceCapture.getAllPointsBB()!.scaleToSize(size: faceCropSize, imgSize: faceCapture.imageSize.size)
            faceCrop = CGRect.init(x: 0, y: faceCrop.minY, width: fullFaceWidth, height: faceCrop.height)

            let exposurePoint = faceCapture.exposurePoint!.toImagePoint(size: faceCapture.imageSize)
            let croppedExposurePoint = ImagePoint.init(x: exposurePoint.x - faceCrop.minX, y: exposurePoint.y - faceCrop.minY).toNormalizedImagePoint(size: ImageSize.init(faceCrop.size))

            let faceImage = faceCapture.getImage()
            
            let leftEyeImage = Image.from(image: faceImage, crop: leftEyeCrop, landmarks: Array(faceImage.landmarks[8...15]))
            let rightEyeImage = Image.from(image: faceImage, crop: rightEyeCrop, landmarks: Array(faceImage.landmarks[16...23]))
            faceImage.crop(faceCrop)
            leftEyeImage.updateParentBB(parentCrop: faceCrop)
            rightEyeImage.updateParentBB(parentCrop: faceCrop)
            
            let longSide = [faceCrop.width, faceCrop.height].max()!
            let scaleRatio = 1080 / longSide
            faceImage.scale(scaleRatio) 
            
            faceImage.rotate()
            leftEyeImage.rotate()
            rightEyeImage.rotate()
            let rotatedCroppedExposurePoint = NormalizedImagePoint.init(x: croppedExposurePoint.y, y: croppedExposurePoint.x)
            
            leftEyeImage.updateParentBB(rotate: true)
            rightEyeImage.updateParentBB(rotate: true)

            let pngDataFace = context.pngRepresentation(of: faceImage.image, format: CIFormat.BGRA8, colorSpace: CGColorSpace.init(name: CGColorSpace.sRGB)!, options: [:])!
            
            let pngDataLeftEye = context.pngRepresentation(of: leftEyeImage.image, format: CIFormat.BGRA8, colorSpace: CGColorSpace.init(name: CGColorSpace.sRGB)!, options: [:])!
            
            let pngDataRightEye = context.pngRepresentation(of: rightEyeImage.image, format: CIFormat.BGRA8, colorSpace: CGColorSpace.init(name: CGColorSpace.sRGB)!, options: [:])!

            let setMetadata = SetMetadata.getFrom(faceImage: faceImage,
                                                  leftEyeImage: leftEyeImage,
                                                  rightEyeImage: rightEyeImage,
                                                  flashSettings: faceCapture.flashSettings,
                                                  cameraState: cameraState,
                                                  rawMetadata: faceCapture.rawMetadata,
                                                  exposurePoint: rotatedCroppedExposurePoint)
            
            return ImageData(faceData: pngDataFace, leftEyeData: pngDataLeftEye, rightEyeData: pngDataRightEye, setMetadata: setMetadata)
        }
    }
    
    func takeSample() {
        print("TAKING SAMPLE, BEGINNING FLASH!")
        
        self.didFlashViewLoad
            .observeOn(MainScheduler.instance)
            .filter { $0 }
            .take(1)
            .flatMap { [unowned cameraState] _ in cameraState.preparePhotoSettings(numPhotos: 8)}
            .flatMap { [unowned self] _ in Observable.from(self.screenFlashSettings) }
            .map { [unowned cameraState] flashSetting in (Camera(cameraState: cameraState), flashSetting) }
            .concatMap {[unowned self] (camera, flashSetting) in camera.capturePhoto(flashSetting, self.exposeAndEndVideoOneShot) }
            .do(onCompleted: { [unowned events, unowned self] in
                self.video.pauseProcessing() //Only really need this for the first capture
                events.onNext(.beginProcessing)
            })
            .flatMap { [unowned cameraState] capturePhoto, flashSettings, exposurePoint -> Observable<FaceCapture?> in
                return FaceCapture.create(pixelBuffer: capturePhoto.pixelBuffer!,
                                          orientation: cameraState.exifOrientationForCurrentDeviceOrientation(),
                                          flashSettings: flashSettings,
                                          metadata: capturePhoto.metadata,
                                          exposurePoint: exposurePoint)
            }
            .compactMap { $0 }
            .toArray()
            .map { [unowned cameraState] faceCaptures in SampleSkinToneViewModel.processFaceCaptures(cameraState, faceCaptures) }
            .do(onSuccess: { [unowned events] _ in events.onNext(.beginUpload) })
            .asObservable()
            .flatMap { [unowned self] (imageData: [ImageData]) -> Observable<UploadStatus> in
                self.uploadProgress.onNext(0.0)
                for photo in imageData { photo.setMetadata.prettyPrint() }
                return self.user.uploadNewCapture(imageData: imageData, progressBar: self.uploadProgress)
            }
            .subscribe(onNext: { [unowned events] uploadStatus in
                if uploadStatus.doneUpload && !uploadStatus.responseRecieved {
                    events.onNext(.beginProcessing)
                }
            }, onError: { _ in
                print("ERROR in taking and processing")
            }, onCompleted: { [unowned self] in
                self.events.onNext(.doneSample)
            }, onDisposed: {
                print("Disposing Capture and Processing")
            })
            .disposed(by: disposeBag)
        events.onNext(.beginFlash)
    }
    
    func cancel() {
        events.onNext(.cancel)
    }
    
    func showHelp() {
        events.onNext(.showHelp)
    }
    
    private func checkFaceSize(min: ImagePoint, max: ImagePoint, imageSize: ImageSize) -> UserFaceStates {
        let width = max.point.x - min.point.x
        let height = 1.5 * (max.point.y - min.point.y)
        
        let fractionWidth = width / imageSize.size.width
        let fractionHeight = height / imageSize.size.height
        
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
    
    private static func getEncapsulatingSize(sizes: [CGSize]) -> CGSize {
        let maxWidth = sizes.map { $0.width }.max()!
        let maxHeight = sizes.map { $0.height }.max()!
        return CGSize.init(width: maxWidth, height: maxHeight)
    }
}
