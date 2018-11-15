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

func createUIImageSet(cameraState: CameraState, photoData: (VNFaceLandmarks2D, AVCapturePhoto, Data)?) -> ImageData {
    guard let (landmarks, capture, data) = photoData else {
        fatalError("Could Not Find Landmarks")
    }
    print("png data :: \(data)")
    let tempImage = UIImage.init(data: capture.fileDataRepresentation()!)!
    //let image = UIImage.init(: photo)
    let landmarkPoints = landmarks.allPoints!.pointsInImage(imageSize: tempImage.size)
    let metaData = MetaData.getFrom(cameraState: cameraState, capture: capture, faceLandmarks: landmarkPoints)

    //var image = UIImage.init(cgImage: photo.cgImageRepresentation()!.takeUnretainedValue()) //Add orientation if necessary
    return ImageData(imageData: data, metaData: metaData)
}

func getCheekRatio(pixelBuffer: CVImageBuffer, landmarks: VNFaceLandmarks2D) -> Float? {
    CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
    
    let bufferWidth = CVPixelBufferGetWidth(pixelBuffer)
    let bufferHeight = CVPixelBufferGetHeight(pixelBuffer)
    
    let width = bufferHeight
    let height = bufferWidth
    
    let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)!
    
    let byteBuffer = baseAddress.assumingMemoryBound(to: UInt8.self)
    
    //Indexed from bottom left of screen
    let facePoints = landmarks.faceContour!.pointsInImage(imageSize: CGSize(width: width, height: height))
    let count = facePoints.count
    
    let sampleSquareSideLength = Int((facePoints[1].y - facePoints[2].y))
    if sampleSquareSideLength < 0 {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
        return nil
    }
    
    let faceStartingPoint = 2
    var leftSampleSquareStart = facePoints[faceStartingPoint]
    leftSampleSquareStart.y = CGFloat(height) - leftSampleSquareStart.y
    
    if leftSampleSquareStart.x < 0 || leftSampleSquareStart.y < 0 {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
        return nil
    }
    
    var rightSampleSquareStart = facePoints[count - (faceStartingPoint + 1)]
    rightSampleSquareStart.y = CGFloat(height) - rightSampleSquareStart.y
    
    if rightSampleSquareStart.x < 0 || rightSampleSquareStart.y < 0 {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
        return nil
    }
    
    let fractionOfPixels = 2
    
    var leftValueSum = 0
    for j in Int(leftSampleSquareStart.x) ..< (Int(leftSampleSquareStart.x) + sampleSquareSideLength) {
        for i in Int(leftSampleSquareStart.y) ..< (Int(leftSampleSquareStart.y) + sampleSquareSideLength) {
            if (i + j) % fractionOfPixels == 0 {
                
                let isOutsideHeight = (j >= bufferHeight) || (j < 0)
                let isOutsideWidth = (i >= bufferWidth) || (i < 0)
                if isOutsideHeight || isOutsideWidth {
                    //print("\n\nLeft Sample OUT OF BOUNDS\n\n")
                    CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
                    return 0.0
                }
                
                let index = (j * bufferWidth + i) * 4
                let value = [byteBuffer[index], byteBuffer[index + 1], byteBuffer[index + 2]].max()!
                leftValueSum += Int(value)
            }
        }
    }
    
    var rightValueSum = 0
    for j in (Int(rightSampleSquareStart.x) - sampleSquareSideLength) ..< Int(rightSampleSquareStart.x)  {
        for i in Int(rightSampleSquareStart.y) ..< (Int(rightSampleSquareStart.y) + sampleSquareSideLength) {
            if (i + j) % fractionOfPixels == 0 {
                
                let isOutsideHeight = (j >= bufferHeight) || (j < 0)
                let isOutsideWidth = (i >= bufferWidth) || (i < 0)
                if isOutsideHeight || isOutsideWidth {
                    //print("\n\nRight Sample OUT OF BOUNDS\n\n")
                    CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
                    return 0.0
                }
                
                let index = (j * bufferWidth + i) * 4
                let value = [byteBuffer[index], byteBuffer[index + 1], byteBuffer[index + 2]].max()!
                rightValueSum += Int(value)
            }
        }
    }
    
    let sampleArea = (sampleSquareSideLength * sampleSquareSideLength) / fractionOfPixels
    
    let rightValueAverage = Float(rightValueSum) / Float(sampleArea)
    let leftValueAverage = Float(leftValueSum) / Float(sampleArea)
    
    let cheekRatio = abs((rightValueAverage / 255) - (leftValueAverage / 255))
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
    
    return cheekRatio
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

func convertImageToLinear(_ input: CIImage) -> CIImage
{
    print("Converting To Linear! \(input)")
    let toLinearFilter = CIFilter(name:"CISRGBToneCurveToLinear")
    toLinearFilter!.setValue(input, forKey: kCIInputImageKey)
    let linear = toLinearFilter!.outputImage!
    print("Linear Image :: \(linear)")
    return linear
}
