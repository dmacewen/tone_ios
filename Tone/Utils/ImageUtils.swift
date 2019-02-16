//
//  ImageUtils.swift
//  Tone
//
//  Created by Doug MacEwen on 11/5/18.
//  Copyright © 2018 Doug MacEwen. All rights reserved.
//

import Foundation
import AVFoundation
import RxSwift
import UIKit
import Vision

struct WhiteBalance : Codable {
    let x: Float
    let y: Float
}

struct MetaData : Codable {
    let iso: Float
    let exposureTime: Float64
    let whiteBalance: WhiteBalance
    let faceLandmarks: [CGPoint]
    let faceLandmarksSource = "apple"
    
    static func getFrom(cameraState: CameraState, capture: AVCapturePhoto, faceLandmarks: [CGPoint]) -> MetaData {
        let meta = capture.metadata
        let exif = meta["{Exif}"] as! [String: Any]
        //print("Exif :: \(exif)")
        
        let iso = (exif["ISOSpeedRatings"] as! Array)[0] as Float
        let exposureTime = exif["ExposureTime"] as! Float64
        let whiteBalanceChromacity = cameraState.captureDevice.chromaticityValues(for: cameraState.captureDevice.deviceWhiteBalanceGains)
        let whiteBalance = WhiteBalance(x: whiteBalanceChromacity.x, y: whiteBalanceChromacity.y)
        
        let faceLandmarksInt = faceLandmarks.map { CGPoint(x: Int($0.x), y: Int($0.y)) }
        
        return MetaData(iso: iso, exposureTime: exposureTime, whiteBalance: whiteBalance, faceLandmarks: faceLandmarksInt)
    }
    
    func prettyPrint() {
        print("ISO :: \(iso) | Exposure Time :: \(exposureTime) | White Balance (x: \(whiteBalance.x), y: \(whiteBalance.y))")
    }
}

struct ImageData {
    let imageData: Data
    let metaData: MetaData
}

struct ImageByteBuffer {
    private let byteBuffer: UnsafeMutablePointer<UInt8>
    private let width: Int
    private let bufferWidth: Int
    private let height: Int
    private let bufferHeight: Int
    private let bytesPerRow: Int
    private let sampleHalfSideLength: CGFloat = 5.0
    
    static func from(_ pixelBuffer: CVImageBuffer) -> ImageByteBuffer {
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)!
        let byteBuffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        let bufferWidth = CVPixelBufferGetWidth(pixelBuffer)
        let bufferHeight = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        //Buffer is rotated 90 degrees to left
        return ImageByteBuffer(byteBuffer: byteBuffer, width: bufferHeight, bufferWidth: bufferWidth, height: bufferWidth, bufferHeight: bufferHeight, bytesPerRow: bytesPerRow)
    }
    
    private func validPoint(_ point: CGPoint) -> Bool {
        return (point.x > 0) && (point.y > 0) && (Int(point.x) < bufferWidth) && (Int(point.y) < bufferHeight)
    }
    
    func size() -> CGSize {
        return CGSize(width: width, height: height)
    }
    
    //Convert Portait Coordinates from Landmarks to Left Landscape Coordinates of Buffer
    private func convertPortraitPointToLandscapePoint(point: CGPoint) -> CGPoint {
        return CGPoint.init(x: CGFloat(height) - point.y, y: point.x)
    }
    
    func sampleLandmarkRegion(landmarkPoint: CGPoint) -> Float? {
        let point = convertPortraitPointToLandscapePoint(point: landmarkPoint)

        if !validPoint(point) { return nil }
        
        let startPoint = CGPoint.init(x: point.x - sampleHalfSideLength, y: point.y - sampleHalfSideLength)
        let endPoint = CGPoint.init(x: point.x + sampleHalfSideLength, y: point.y + sampleHalfSideLength)
        
        if !validPoint(startPoint) || !validPoint(endPoint) { return nil }
        
        var sum = 0
        for y in Int(startPoint.y) ..< Int(endPoint.y) {
            let bufferRowOffset = y * bytesPerRow
            for x in Int(startPoint.x) ..< Int(endPoint.x) {
                let bufferIndex = bufferRowOffset + (x * 4) //Index into the buffer
                sum += Int(byteBuffer[bufferIndex]) + Int(byteBuffer[bufferIndex + 1]) + Int(byteBuffer[bufferIndex + 2])
            }
        }
        
        let averageSubpixelValue = Float(sum) / Float(pow((2 * sampleHalfSideLength) + 1, 2)) // Area of the sample x 3 sub pixels each

        return averageSubpixelValue
    }
}

func getImageMetadata(cameraState: CameraState, photoData: (VNFaceLandmarks2D, AVCapturePhoto)?) -> MetaData {
    guard let (landmarks, capture) = photoData else {
        fatalError("Could Not Find Landmarks")
    }
    
    let image = UIImage.init(data: capture.fileDataRepresentation()!)!
    let landmarkPoints = landmarks.allPoints!.pointsInImage(imageSize: image.size)
    return MetaData.getFrom(cameraState: cameraState, capture: capture, faceLandmarks: landmarkPoints)
}

func getRightCheekPoint(landmarks: [CGPoint]) -> CGPoint {
    let middleRightEye = landmarks[64]
    let middleNose = landmarks[58]
    return CGPoint.init(x: middleRightEye.x, y: middleNose.y)
}

func getLeftCheekPoint(landmarks: [CGPoint]) -> CGPoint {
    let middleLeftEye = landmarks[63]
    let middleNose = landmarks[52]
    return CGPoint.init(x: middleLeftEye.x, y: middleNose.y)
}

func getCheekRatio(pixelBuffer: CVImageBuffer, landmarks: VNFaceLandmarks2D) -> (Float, Bool)? {
    CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly) }
    
    let imageByteBuffer = ImageByteBuffer.from(pixelBuffer)
    let facePoints = landmarks.allPoints!.pointsInImage(imageSize: imageByteBuffer.size())
    
    let leftCheekPoint = getLeftCheekPoint(landmarks: facePoints)
    let rightCheekPoint = getRightCheekPoint(landmarks: facePoints)
    
    let leftCheekSample = imageByteBuffer.sampleLandmarkRegion(landmarkPoint: leftCheekPoint)
    let rightCheekSample = imageByteBuffer.sampleLandmarkRegion(landmarkPoint: rightCheekPoint)
    
    if (leftCheekSample == nil) || (rightCheekSample == nil) { return nil }
    
    let leftRightRatio = leftCheekSample! / rightCheekSample!
    
    return (leftRightRatio, leftRightRatio < 1)
}

//Error :: 2018-11-14 11:44:19.689414-0800 Tone[32016:9326030] LandmarkDetector error -20:out of bounds in int vision::mod::LandmarkAttributes::computeBlinkFunction(const vImage_Buffer &, const Geometry2D_rect2D &, const std::vector<Geometry2D_point2D> &, vImage_Buffer &, vImage_Buffer &, std::vector<float> &, std::vector<float> &) @ /BuildRoot/Library/Caches/com.apple.xbs/Sources/Vision/Vision-2.0.62/LandmarkDetector/LandmarkDetector_Attributes.mm:535

//Seems to be caused by covering the mouth/face... I.E. When looking at a second computer screen, supporting your face with your hand. Fingers/palm covering mouth and thumb resting on cheekbone... Kinda a weird description... Towards edge of image. Face inside image frame but hand extending out of the frame... Probably not an issue, just something thats come up. Does not change expected functionality

//Was able to replciate just by holding my face towards the edge of the frame looking at a ~45 - 90 degree angle away from the phone (at a second screen in this case...)

func getFacialLandmarks(cameraState: CameraState, pixelBuffer: CVPixelBuffer) -> Observable<(VNFaceLandmarks2D, CVPixelBuffer)?> {
    return Observable<(VNFaceLandmarks2D, CVPixelBuffer)?>.create { observable in
        var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
        
        let cameraIntrinsicData = CMGetAttachment(pixelBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil)
        if cameraIntrinsicData != nil {
            requestHandlerOptions[VNImageOption.cameraIntrinsics] = cameraIntrinsicData
        }
        
        let exifOrientation = cameraState.exifOrientationForCurrentDeviceOrientation()
        
        // Perform face landmark tracking on detected faces.
        let faceLandmarksRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request, error) in
            if error != nil {
                print("FaceLandmarks error: \(String(describing: error)).")
            }
            
            guard let landmarksRequest = request as? VNDetectFaceLandmarksRequest,
                let results = landmarksRequest.results as? [VNFaceObservation] else {
                    observable.onNext(nil)
                    observable.onCompleted()
                    return
            }
            
            if results.count > 0 {
                let faceLandmarks = results[0].landmarks!
                observable.onNext((faceLandmarks, pixelBuffer))
                observable.onCompleted()
            } else {
                observable.onNext(nil)
                observable.onCompleted()
            }
        })
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                        orientation: exifOrientation,
                                                        options: requestHandlerOptions)
        
        do {
            try imageRequestHandler.perform([faceLandmarksRequest])
        } catch let error as NSError {
            NSLog("Failed to perform FaceLandmarkRequest: %@", error)
            fatalError("Error Landmarking")
        }
        
        return Disposables.create()
    }
}
//Needs a context to have been created
func convertImageToLinear(_ input: CIImage) -> CIImage {
    let toLinearFilter = CIFilter(name:"CISRGBToneCurveToLinear")
    toLinearFilter!.setValue(input, forKey: kCIInputImageKey)
    return toLinearFilter!.outputImage!
}
//Needs a context to have been created
func rotateImage(_ input: CIImage) -> CIImage {
    let toRotateFilter = CIFilter(name:"CIAffineTransform")
    let affineRotationTransform = CGAffineTransform.init(rotationAngle: -CGFloat.pi/2)
    toRotateFilter!.setValue(affineRotationTransform, forKey: kCIInputTransformKey)
    toRotateFilter!.setValue(input, forKey: kCIInputImageKey)
    return toRotateFilter!.outputImage!
}
