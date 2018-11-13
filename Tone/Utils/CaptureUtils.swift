//
//  CaptureUtils.swift
//  Tone
//
//  Created by Doug MacEwen on 11/1/18.
//  Copyright © 2018 Doug MacEwen. All rights reserved.
//

import Foundation
import AVFoundation
import RxSwift
import Vision
import AVKit

struct PhotoSettings {
    var iso = 0.0
    var exposure = 0.0
    var whiteBalance = [0.0, 0.0, 0.0]
}

// areas: the number of equal areas to divide the screen into
// area: the specific area to illuminate
//Ex.
// (area, areas)
// (0, 1) is all black
// (1, 1) is all white
// (1, 2) is half 1 of the screen is illuminated
// (2, 2) is half 2 of the screen is illuminated

struct FlashSettings {
    var area = 0
    var areas = 0
}

struct RealTimeFaceData {
    var landmarks: VNFaceLandmarks2D
    var cheekRatio: Float
}

//Defining a Camera how we want it
class CameraState {
    var capturePhotoOutput: AVCapturePhotoOutput
    var captureDevice: AVCaptureDevice
    var captureSession: AVCaptureSession
    
    var flashStream: PublishSubject<FlashSettings>
    var isAvailable =  BehaviorSubject<Bool>(value: true)
    var photoSettingsIndex = 0
    
    init(flashStream: PublishSubject<FlashSettings>) {
        print("Setting up camera...")
        self.flashStream = flashStream

        //Create Capture Session
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
        captureSession.automaticallyConfiguresCaptureDeviceForWideColor = false
        
        //Set up Capture Photo Output
        capturePhotoOutput = AVCapturePhotoOutput()
        capturePhotoOutput.isHighResolutionCaptureEnabled = true
        
        //Add Capture Photo Output to Capture Session
        captureSession.addOutput(capturePhotoOutput)
        captureSession.startRunning()
        
        captureDevice = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: AVCaptureDevice.Position.front)!
        
        do {
            try captureDevice.lockForConfiguration()
            print("Capture Device LOCKED")
        } catch {
            fatalError("Could Not Lock device for configuration")
        }
        
        //Set colorspace to sRGB so that color processing is consistent between devices that dont support larger colorspaces
        captureDevice.activeColorSpace = AVCaptureColorSpace.sRGB
        
        captureSession.beginConfiguration()
        
        do {
            //Add capture device to capture session
            let input = try AVCaptureDeviceInput(device: captureDevice)
            captureSession.addInput(input)
        } catch {
            fatalError("Could Not Add Capture Device to Current Capture Session!")
        }
        
        captureSession.commitConfiguration()
        print("Commited Capture Session")
    }
    
    //Prepares numPhotos prepared settings
    func preparePhotoSettings(numPhotos: Int) -> Observable<Bool> {
        print("Preparing PhotoSettings!")
        let photoSettings = (0..<numPhotos).map { _ in getPhotoSettings() }
        return Observable.create { observer in
            self.capturePhotoOutput.setPreparedPhotoSettingsArray(photoSettings) {
                isPrepared, error in
                guard error == nil else {
                    observer.on(.error(error!))
                    return
                }
                observer.on(.next(isPrepared))
                observer.on(.completed)
            }
            return Disposables.create()
        }
    }

    func lockCameraSettings() -> Observable<Bool> {
        captureDevice.exposureMode = AVCaptureDevice.ExposureMode.locked
        return Observable.create { observable in
            self.captureDevice.setWhiteBalanceModeLocked(with: AVCaptureDevice.currentWhiteBalanceGains, completionHandler: { time in
                observable.onNext(true)
            })
            return Disposables.create()
        }
    }
    
    func unlockCameraSettings() {
        let middlePoint = CGPoint.init(x: 0.5, y: 0.5)
        captureDevice.exposurePointOfInterest = middlePoint
        captureDevice.exposureMode = AVCaptureDevice.ExposureMode.continuousAutoExposure
        captureDevice.whiteBalanceMode = AVCaptureDevice.WhiteBalanceMode.continuousAutoWhiteBalance
    }
    
    func exifOrientationForDeviceOrientation(_ deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        
        switch deviceOrientation {
        case .portraitUpsideDown:
            return .rightMirrored
            
        case .landscapeLeft:
            return .downMirrored
            
        case .landscapeRight:
            return .upMirrored
            
        default:
            return .leftMirrored
        }
    }
    
    func exifOrientationForCurrentDeviceOrientation() -> CGImagePropertyOrientation {
        return exifOrientationForDeviceOrientation(UIDevice.current.orientation)
    }
}

class Camera: NSObject {
    private var cameraState: CameraState
    private let capture = PublishSubject<AVCapturePhoto>()
    
    
    init(cameraState: CameraState) {
        print("New Camera")
        self.cameraState = cameraState
    }

    func capturePhoto(_ flashSettings: FlashSettings) -> PublishSubject<AVCapturePhoto> {
        //Move to chain? bind isAdjustingExposure?
        print("Beginning to capture photo!")
        print("White Balance Mode :: \(cameraState.captureDevice.whiteBalanceMode.rawValue)")
        print("Exposure Mode :: \(cameraState.captureDevice.exposureMode.rawValue)")
        
        

        if cameraState.captureDevice.isAdjustingExposure == true {
            //fatalError("Still Adjusting Exposure")
            print("\nStill Adjusting Exposure!!\n")
            
            /*
             print("Posponing Capture!")
             
             delay(0.5) {
             return self.capturePhoto(flashSettings: flashSettings, photoSettings: photoSettings)
             }
             */
        }
        
        if cameraState.captureDevice.isAdjustingWhiteBalance == true {
            //fatalError("Still Adjusting Exposure")
            print("\nStill Adjusting White Balance!!\n")
            
            /*
             print("Posponing Capture!")
             
             delay(0.5) {
             return self.capturePhoto(flashSettings: flashSettings, photoSettings: photoSettings)
             }
             */
        }
        
        print("Captuing Photo with Flash Settings :: \(flashSettings.area) \(flashSettings.areas)")
        cameraState.flashStream.onNext(flashSettings)
        print("Getting Photo Settings!")
        let photoSettings = cameraState.capturePhotoOutput.preparedPhotoSettingsArray.count > cameraState.photoSettingsIndex
            ? cameraState.capturePhotoOutput.preparedPhotoSettingsArray[cameraState.photoSettingsIndex]
            : getPhotoSettings()
        
        cameraState.photoSettingsIndex += 1
        print("Capturing!")
        cameraState.capturePhotoOutput.capturePhoto(with: photoSettings, delegate: self)
        return capture
    }
}

extension Camera: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("Done Capture!")
        guard error == nil else {
            fatalError("Error in capture!")
        }
        
        capture.onNext(photo)
        capture.onCompleted()
    }
}

func getPhotoSettings() -> AVCapturePhotoSettings {
    let photoSettings = AVCapturePhotoSettings.init(format: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    //photoSettings.processedFileType = AVFileType.tif
    photoSettings.isAutoStillImageStabilizationEnabled = true
    photoSettings.isHighResolutionPhotoEnabled = true
    photoSettings.flashMode = .off
    return photoSettings
}

class Video:  NSObject {
    private var cameraState: CameraState
    let faceLandmarks = PublishSubject<RealTimeFaceData?>()
    
    init(cameraState: CameraState) {
        self.cameraState = cameraState
        
        super.init()
        
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        
        // Create a serial dispatch queue used for the sample buffer delegate as well as when a still image is captured.
        // A serial dispatch queue must be used to guarantee that video frames will be delivered in order.
        let videoDataOutputQueue = DispatchQueue(label: "com.Tone-Cosmetics.Tone")
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        
        if cameraState.captureSession.canAddOutput(videoDataOutput) {
            cameraState.captureSession.addOutput(videoDataOutput)
        }
        
        videoDataOutput.connection(with: .video)?.isEnabled = true
        
        if let captureConnection = videoDataOutput.connection(with: AVMediaType.video) {
            if captureConnection.isCameraIntrinsicMatrixDeliverySupported {
                captureConnection.isCameraIntrinsicMatrixDeliveryEnabled = true
            }
        }
        
        //self.videoDataOutput = videoDataOutput
        //self.videoDataOutputQueue = videoDataOutputQueue
        
        //self.captureDevice = inputDevice
        //self.captureDeviceResolution = resolution
    }
}

extension Video: AVCaptureVideoDataOutputSampleBufferDelegate {
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    /// - Tag: PerformRequests
    // Handle delegate method callback on receiving a sample buffer.
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
        
        let cameraIntrinsicData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil)
        if cameraIntrinsicData != nil {
            requestHandlerOptions[VNImageOption.cameraIntrinsics] = cameraIntrinsicData
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to obtain a CVPixelBuffer for the current output frame.")
            return
        }
        
        let exifOrientation = self.cameraState.exifOrientationForCurrentDeviceOrientation()
        
        // Perform face landmark tracking on detected faces.
        //var faceLandmarkRequests = [VNDetectFaceLandmarksRequest]()
        let faceLandmarksRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request, error) in
            
            if error != nil {
                print("FaceLandmarks error: \(String(describing: error)).")
            }
            
            guard let landmarksRequest = request as? VNDetectFaceLandmarksRequest,
                let results = landmarksRequest.results as? [VNFaceObservation] else {
                    return
            }
            
            if results.count > 0 {
                
                //CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
                CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)

                let bufferWidth = CVPixelBufferGetWidth(pixelBuffer)
                let bufferHeight = CVPixelBufferGetHeight(pixelBuffer)
                
                let width = bufferHeight
                let height = bufferWidth
                
                //print("Width :: \(width) | Height :: \(height)")
                //let bitsPerComponent = 8
                
                //let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
                let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)!
                
                let byteBuffer = baseAddress.assumingMemoryBound(to: UInt8.self)
                
                //let index = 12
                //let b = byteBuffer[index]
                //let g = byteBuffer[index + 1]
                //let r = byteBuffer[index + 2]
                //let a = byteBuffer[index + 3]
                
                //print("Index :: \(index) | BGR :: (\(b), \(g), \(r))")
                
                let faceLandmarks = results[0].landmarks
                //Indexed from bottom left of screen
                let facePoints = faceLandmarks!.faceContour!.pointsInImage(imageSize: CGSize(width: width, height: height))
                let count = facePoints.count
                
                var sampleSquareSideLength = Int((facePoints[1].y - facePoints[2].y) / 2)
                if sampleSquareSideLength < 0 {
                    sampleSquareSideLength = 1
                }
                //print("Sample Square Side Length :: \(sampleSquareSideLength)")

                let faceStartingPoint = 2
                var leftSampleSquareStart = facePoints[faceStartingPoint]
                leftSampleSquareStart.y = CGFloat(height) - leftSampleSquareStart.y
                var rightSampleSquareStart = facePoints[count - (faceStartingPoint + 1)]
                rightSampleSquareStart.y = CGFloat(height) - rightSampleSquareStart.y
                
                var leftValueSum = 0
                
                for j in Int(leftSampleSquareStart.x) ..< (Int(leftSampleSquareStart.x) + sampleSquareSideLength) {
                    for i in Int(leftSampleSquareStart.y) ..< (Int(leftSampleSquareStart.y) + sampleSquareSideLength) {
                    //for i in (Int(rightSampleSquareStart.x) - sampleSquareSideLength) ..< Int(rightSampleSquareStart.x)  {
                        let index = (j * bufferWidth + i) * 4
                        let value = [byteBuffer[index], byteBuffer[index + 1], byteBuffer[index + 2]].max()!
                        leftValueSum += Int(value)
                    }
                }
                
                var rightValueSum = 0
                for j in (Int(rightSampleSquareStart.x) - sampleSquareSideLength) ..< Int(rightSampleSquareStart.x)  {
                    for i in Int(rightSampleSquareStart.y) ..< (Int(rightSampleSquareStart.y) + sampleSquareSideLength) {
                    //for i in Int(leftSampleSquareStart.x) ..< (Int(leftSampleSquareStart.x) + sampleSquareSideLength) {
                        let index = (j * bufferWidth + i) * 4
                        let value = [byteBuffer[index], byteBuffer[index + 1], byteBuffer[index + 2]].max()!
                        rightValueSum += Int(value)
                    }
                }
                
                let sampleArea = sampleSquareSideLength * sampleSquareSideLength
                
                let rightValueAverage = Float(rightValueSum) / Float(sampleArea)
                let leftValueAverage = Float(leftValueSum) / Float(sampleArea)
                
                let cheekRatio = abs((rightValueAverage / 255) - (leftValueAverage / 255))

                //print("Right Average Value :: \(rightValueAverage) | Left AverageValue :: \(leftValueAverage)")
                //print("\(cheekRatio)% difference | Right Average Value :: \(rightValueAverage) | Left AverageValue :: \(leftValueAverage)")
                
                self.faceLandmarks.onNext(RealTimeFaceData(landmarks: results[0].landmarks!, cheekRatio: cheekRatio))
                CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
                //CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))

            } else {
                self.faceLandmarks.onNext(nil)
            }
        })
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                        orientation: exifOrientation,
                                                        options: requestHandlerOptions)
        
        do {
            try imageRequestHandler.perform([faceLandmarksRequest])
        } catch let error as NSError {
            NSLog("Failed to perform FaceLandmarkRequest: %@", error)
        }
    }
}
