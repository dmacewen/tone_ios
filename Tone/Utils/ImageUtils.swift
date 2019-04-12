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

struct ImageData {
    let faceData: Data
    let leftEyeData: Data
    let rightEyeData: Data
    let setMetadata: SetMetadata
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
    
    func convertPortraitPointToLandscapeRatioPoint(point: CGPoint) -> CGPoint {
        let landscapePoint = self.convertPortraitPointToLandscapePoint(point: point)
        return CGPoint.init(x: landscapePoint.x / CGFloat(bufferWidth), y: landscapePoint.y / CGFloat(bufferHeight))
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

func getRightEyePoint(landmarks: [CGPoint]) -> CGPoint {
    return landmarks[16]
}

func bufferBoundingBox(_ bb: CGRect, imgSize: CGSize, margin: CGFloat = 0.25) -> CGRect {
    let sizeMultiplier = 1 + (2 * margin)
    
    var newX = bb.minX - (margin * bb.width)
    if newX < 0 {
        newX = 0
    }
    
    var newY = bb.minY - (margin * bb.height)
    if newY < 0 {
        newY = 0
    }
    
    var newWidth = bb.width * sizeMultiplier
    if newWidth > imgSize.width {
        newWidth = imgSize.width
    }
    
    var newHeight = bb.height * sizeMultiplier
    if newHeight > imgSize.height {
        newHeight = imgSize.height
    }
    
    return CGRect.init(x: newX, y: newY, width: newWidth, height: newHeight)
}

func getRightEyeBB(landmarks: [CGPoint], imgSize: CGSize) -> CGRect {
    let eyePoints = landmarks[16...23]
    return bufferBoundingBox(CGRect.fromPoints(points: eyePoints, imgSize: imgSize), imgSize: imgSize)
}

func getLeftEyeBB(landmarks: [CGPoint], imgSize: CGSize) -> CGRect {
    let eyePoints = landmarks[8...15]
    return bufferBoundingBox(CGRect.fromPoints(points: eyePoints, imgSize: imgSize), imgSize: imgSize)
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

func getChinPoint(landmarks: [CGPoint]) -> CGPoint {
    let centerLipBottom = landmarks[31]
    let centerJawBottom = landmarks[45]
    return CGPoint.init(x: (centerLipBottom.x + centerJawBottom.x) / 2, y: (centerLipBottom.y + centerJawBottom.y) / 2)
}

func getForeheadPoint(landmarks: [CGPoint]) -> CGPoint {
    let leftEyebrowInner = landmarks[3]
    let rightEyebrowInner = landmarks[4]
    return CGPoint.init(x: (leftEyebrowInner.x + rightEyebrowInner.x) / 2, y: (leftEyebrowInner.y + rightEyebrowInner.y) / 2)
}

func getForeheadPair(landmarks: [CGPoint]) -> (CGPoint, CGPoint) {
    let offset = abs(landmarks[2].x - landmarks[1].x)
    let leftEyeBrowSample = CGPoint.init(x: landmarks[2].x, y: landmarks[2].y - offset)
    let rightEyeBrowSample = CGPoint.init(x: landmarks[5].x, y: landmarks[5].y - offset)
    return (leftEyeBrowSample, rightEyeBrowSample)
}

func getEyePair(landmarks: [CGPoint]) -> (CGPoint, CGPoint) {
    return (landmarks[51], landmarks[59])
}

func getUpperCheekPair(landmarks: [CGPoint]) -> (CGPoint, CGPoint) {
    let leftUpperCheek = CGPoint.init(x: landmarks[8].x, y: landmarks[55].y)
    let rightUpperCheek = CGPoint.init(x: landmarks[20].x, y: landmarks[55].y)
    return (leftUpperCheek, rightUpperCheek)
}

func getLowerCheekPair(landmarks: [CGPoint]) -> (CGPoint, CGPoint) {
    let offset = abs(landmarks[26].y - landmarks[35].y)
    let leftUpperCheek = CGPoint.init(x: landmarks[33].x - offset, y: landmarks[33].y)
    let rightUpperCheek = CGPoint.init(x: landmarks[29].x + offset, y: landmarks[29].y)
    return (leftUpperCheek, rightUpperCheek)
}

func isLightingEqual(points: (CGPoint, CGPoint), imageByteBuffer: ImageByteBuffer, exposureRatios: ExposureRatios) -> Bool? {
    guard let A = imageByteBuffer.sampleLandmarkRegion(landmarkPoint: points.0) else { return nil }
    let A_exposureScore = getExposureScore(intensity: A, exposureRatios: exposureRatios)
    
    guard let B = imageByteBuffer.sampleLandmarkRegion(landmarkPoint: points.1) else { return nil }
    let B_exposureScore = getExposureScore(intensity: B, exposureRatios: exposureRatios)
    //print("A vs B | \(A_exposureScore) vs \(B_exposureScore)")

    if abs(A_exposureScore - B_exposureScore) > 25 {
        return false
    }
    
    return true
}

func getExposureInfo(pixelBuffer: CVImageBuffer, landmarks: VNFaceLandmarks2D, cameraState: CameraState) -> (CGPoint, Bool, Bool)? {
    CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly) }
    let exposureRatios = cameraState.getStandardizedExposureData()
    
    let imageByteBuffer = ImageByteBuffer.from(pixelBuffer)
    let facePoints = landmarks.allPoints!.pointsInImage(imageSize: imageByteBuffer.size())
    
    //BalanceLightCheckPoints
    let foreheadPair = getForeheadPair(landmarks: facePoints)
    let eyePair = getEyePair(landmarks: facePoints)
    let upperCheekPair = getUpperCheekPair(landmarks: facePoints)
    let lowerCheekPair = getLowerCheekPair(landmarks: facePoints)
    
    guard let isForeheadEqual = isLightingEqual(points: foreheadPair, imageByteBuffer: imageByteBuffer, exposureRatios: exposureRatios) else { return nil }
    guard let isEyeEqual = isLightingEqual(points: eyePair, imageByteBuffer: imageByteBuffer, exposureRatios: exposureRatios) else { return nil }
    guard let isUpperCheekEqual = isLightingEqual(points: upperCheekPair, imageByteBuffer: imageByteBuffer, exposureRatios: exposureRatios) else { return nil }
    guard let isLowerCheekEqual = isLightingEqual(points: lowerCheekPair, imageByteBuffer: imageByteBuffer, exposureRatios: exposureRatios) else { return nil }
    
    //print("FOREHEAD: \(isForeheadEqual) | EYE: \(isEyeEqual) | UPPER CHEEK: \(isUpperCheekEqual) | LOWER CHEEK: \(isLowerCheekEqual)")
    let isBrightnessBalanced = isForeheadEqual && isEyeEqual && isUpperCheekEqual && isLowerCheekEqual

    //Exposure Points
    let leftCheekPoint = getLeftCheekPoint(landmarks: facePoints)
    let rightCheekPoint = getRightCheekPoint(landmarks: facePoints)
    let chinPoint = getChinPoint(landmarks: facePoints)
    let foreheadPoint = getForeheadPoint(landmarks: facePoints)
    
    
    guard let leftCheekSample = imageByteBuffer.sampleLandmarkRegion(landmarkPoint: leftCheekPoint) else { return nil }
    guard let rightCheekSample = imageByteBuffer.sampleLandmarkRegion(landmarkPoint: rightCheekPoint) else { return nil }
    guard let chinSample = imageByteBuffer.sampleLandmarkRegion(landmarkPoint: chinPoint) else { return nil }
    guard let foreheadSample = imageByteBuffer.sampleLandmarkRegion(landmarkPoint: foreheadPoint) else { return nil }
    
    let sortedSamples = [(leftCheekSample, leftCheekPoint), (rightCheekSample, rightCheekPoint), (chinSample, chinPoint), (foreheadSample, foreheadPoint)].sorted { A, B in
        return A.0 > B.0
    }
    
    let brightestPoint = imageByteBuffer.convertPortraitPointToLandscapeRatioPoint(point: sortedSamples.first!.1)
    
    let brightestExposureScore = getExposureScore(intensity: sortedSamples.first!.0, exposureRatios: exposureRatios)
    //print("BRIGHTEST EXPOSURE SCORE :: \(brightestExposureScore)")
    let isTooBright = brightestExposureScore > 100
    /*
    let brightnessRatio = ((sortedSamples.first!.0 - sortedSamples.last!.0) / sortedSamples.last!.0)
    print("Brightness Ratio :: \(brightnessRatio)")
    if brightnessRatio > 0.3 {
        return (brightestPoint, false)
    }
    */
    return (brightestPoint, isBrightnessBalanced, isTooBright)
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
/*
func getReflectionBrightness(_ cameraState: CameraState, _ capture: (AVCapturePhoto, FlashSettings)) -> Observable<Int8> {
    let (photo, flashSettings) = capture
    return getFacialLandmarks(cameraState: cameraState, pixelBuffer: photo.pixelBuffer!)
        .map { landmarks in
            guard let (landmarks, pixelBuffer) = landmarks else {
                return 0
            }
            
            CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
            defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly) }
            //let imageByteBuffer = ImageByteBuffer.from(pixelBuffer)
            //let facePoints = landmarks.allPoints!.pointsInImage(imageSize: imageByteBuffer.size())
            
            return 0
        }
}
 */

func convertPortraitPointToLandscapePoint(points: [CGPoint], imgSize: CGSize) -> [CGPoint] {
    return points.map { CGPoint.init(x: CGFloat(imgSize.height) - $0.y, y: $0.x) }
}

func calculateFaceCrop(faceLandmarks: [VNFaceLandmarks2D], imgSize: CGSize) -> [CGRect] {
    let faceLandmarkPoints = faceLandmarks.map { $0.allPoints!.pointsInImage(imageSize: imgSize) }

    let orientedFaceLandmarkPoints = faceLandmarkPoints.map { convertPortraitPointToLandscapePoint(points: $0, imgSize: imgSize)}
    let newImgSize = CGSize(width: imgSize.height, height: imgSize.width)
    
    //Find the offsets from each images right eye to the target right eye
    let targetPoint = getRightEyePoint(landmarks: orientedFaceLandmarkPoints[0])
    let offsets = orientedFaceLandmarkPoints.map { getRightEyePoint(landmarks: $0).getOffset(targetPoint) }
    
    //Get All of the Faces Bounding Boxes
    let BBs = orientedFaceLandmarkPoints.map { CGRect.fromPoints(points: $0, imgSize: newImgSize) }
    
    //"Align" All of the bounding boxes to the target image by adding the offset vector
    let alignedBBs = zip(BBs, offsets).map { BB, offset in BB.addOffsetVector(vector: offset, imgSize: newImgSize) }
    
    //Create new bounding box that bounds all the aligned images
    let BB = CGRect.fromBoundingBoxes(rectangles: alignedBBs, imgSize: newImgSize)
    
    //Create the invdividual crops by subtracting the offset vector from the Set BB
    let crops = offsets.map { offset in BB.subOffsetVector(vector: offset, imgSize: newImgSize) }
    
    return crops
}

func calculateEyeCrops(faceLandmarks: [VNFaceLandmarks2D], imgSize: CGSize) -> [(CGRect, CGRect)] {
    let faceLandmarkPoints = faceLandmarks.map { $0.allPoints!.pointsInImage(imageSize: imgSize) }
    
    let orientedFaceLandmarkPoints = faceLandmarkPoints.map { convertPortraitPointToLandscapePoint(points: $0, imgSize: imgSize)}
    let newImgSize = CGSize(width: imgSize.height, height: imgSize.width)

    let eyeCrops = orientedFaceLandmarkPoints.map { landmarkPoints -> (CGRect, CGRect) in
        let leftEyeBB = getLeftEyeBB(landmarks: landmarkPoints, imgSize: newImgSize)
        let rightEyeBB = getRightEyeBB(landmarks:  landmarkPoints, imgSize: newImgSize)
        return (leftEyeBB, rightEyeBB)
    }
    
    let maxWidthLeft = eyeCrops
        .map { LREyeCrops in LREyeCrops.0.width }
        .max()!
    
    let maxHeightLeft = eyeCrops
        .map { LREyeCrops in LREyeCrops.0.height }
        .max()!
    
    let maxWidthRight = eyeCrops
        .map { LREyeCrops in LREyeCrops.1.width }
        .max()!
    
    let maxHeightRight = eyeCrops
        .map { LREyeCrops in LREyeCrops.1.height }
        .max()!

    let eyeCropsEqualized = eyeCrops.map { LREyeCrop -> (CGRect, CGRect) in
        let (leftEyeCrop, rightEyeCrop) = LREyeCrop
        
        let leftWidthDiff = (maxWidthLeft - leftEyeCrop.width) / 2
        let leftHeightDiff = (maxHeightLeft - leftEyeCrop.height) / 2
        let rightWidthDiff = (maxWidthRight - rightEyeCrop.width) / 2
        let rightHeightDiff = (maxHeightRight - rightEyeCrop.height) / 2

        let leftEyeCropEqualized = CGRect.init(x: leftEyeCrop.minX - leftWidthDiff, y: leftEyeCrop.minY - leftHeightDiff, width: maxWidthLeft, height: maxHeightLeft).toInt()
        let rightEyeCropEqualized = CGRect.init(x: rightEyeCrop.minX - rightWidthDiff, y: rightEyeCrop.minY - rightHeightDiff, width: maxWidthRight, height: maxHeightRight).toInt()
        return (leftEyeCropEqualized, rightEyeCropEqualized)
    }
    
    return eyeCropsEqualized
}

func getExposureScore(intensity: Float, exposureRatios: ExposureRatios) -> Float64 {
    let inverseISO = 1 / exposureRatios.iso
    let inverseExposure = 1 / exposureRatios.exposure
    return Float64(intensity) * inverseISO * inverseExposure * 100_000
}


//Needs a context to have been created
func cropImage(_ input: CIImage, dimensions: CGRect, _ imageTransforms: inout ImageTransforms) -> CIImage {
    let toCroppedFilter = CIFilter(name:"CICrop")
    toCroppedFilter!.setValue(input, forKey: kCIInputImageKey)
    toCroppedFilter!.setValue(dimensions, forKey: kCIAttributeTypeRectangle)

    imageTransforms.isCropped = true
    return toCroppedFilter!.outputImage!
}

//Needs a context to have been created
func convertImageToLinear(_ input: CIImage, _ imageTransforms: inout ImageTransforms) -> CIImage {
    let toLinearFilter = CIFilter(name:"CISRGBToneCurveToLinear")
    toLinearFilter!.setValue(input, forKey: kCIInputImageKey)
    imageTransforms.isGammaSBGR = true
    return toLinearFilter!.outputImage!
}

//Needs a context to have been created
func rotateImage(_ input: CIImage, _ imageTransforms: inout ImageTransforms) -> CIImage {
    let toRotateFilter = CIFilter(name:"CIAffineTransform")
    let affineRotationTransform = CGAffineTransform.init(rotationAngle: -CGFloat.pi/2)
    toRotateFilter!.setValue(affineRotationTransform, forKey: kCIInputTransformKey)
    toRotateFilter!.setValue(input, forKey: kCIInputImageKey)
    imageTransforms.isRotated = true
    return toRotateFilter!.outputImage!
}

//Needs a context to have been created
func scaleImage(_ input: CIImage, scale: CGFloat, _ imageTransforms: inout ImageTransforms) -> CIImage {
    let toScaleFilter = CIFilter(name:"CILanczosScaleTransform")
    toScaleFilter!.setValue(input, forKey: kCIInputImageKey)
    toScaleFilter!.setValue(scale, forKey: kCIInputScaleKey)
    toScaleFilter!.setValue(1, forKey: kCIInputAspectRatioKey)
    
    imageTransforms.isScaled = true
    return toScaleFilter!.outputImage!
}

