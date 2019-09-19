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

class ImageData {
    let faceData: Data
    let leftEyeData: Data
    let rightEyeData: Data
    let setMetadata: SetMetadata
    
    init(faceData: Data, leftEyeData: Data, rightEyeData: Data, setMetadata: SetMetadata) {
        print("Creating Image Data!")
        self.faceData = faceData
        self.leftEyeData = leftEyeData
        self.rightEyeData = rightEyeData
        self.setMetadata = setMetadata
    }
    deinit { print("Destroying Image Data!")}
}

struct RealTimeFaceData {
    var landmarks: [ImagePoint]
    var isLightingUnbalanced: Bool
    var balancePoints: [ImagePoint]
    var isTooBright: Bool
    var brightnessPoints: [ImagePoint]
    var isNotHorizontallyAligned: Bool
    var isNotVerticallyAligned: Bool
    var isRotated: Bool
    var facingCameraPoints: [ImagePoint]
    var exposurePoint: ImagePoint
    var eyeExposurePoints: [ImagePoint]
    var size: ImageSize
}

enum UnbalanceDirection {
    case left
    case right
    case balanced
    
    var ok: Bool {
        switch self {
        case .left, .right:
            return false
        case .balanced:
            return true
        }
    }
}

let MAX_BRIGHTNESS_SCORE: CGFloat = 250

func getRightCheekPoint(landmarks: [ImagePoint]) -> ImagePoint {
    let middleRightEye = landmarks[64]
    let middleNose = landmarks[58]
    return ImagePoint.init(x: middleNose.x, y: middleRightEye.y)
}

func getRightEyePoint(landmarks: [ImagePoint]) -> ImagePoint {
    return landmarks[18]
}

func getRightEyePupilPoint(landmarks: [ImagePoint]) -> ImagePoint {
    return landmarks[64]
}

func getRightEyeLeftSclera(landmarks: [ImagePoint]) -> ImagePoint {
    let x = /*(landmarks[16].x + landmarks[17].x + landmarks[23].x) / 3*/ landmarks[64].x
    let y = (landmarks[16].y + landmarks[17].y + landmarks[23].y) / 3
    return ImagePoint.init(x: x, y: y)
}

func getRightEyeLeftScleraBB(landmarks: [ImagePoint]) -> CGRect {
    let x = landmarks[18].x
    let y = (landmarks[17].y + landmarks[18].y + landmarks[22].y + landmarks[23].y) / 4
    let width = landmarks[22].x - x
    let height = landmarks[16].y - y
    return CGRect.init(x: x, y: y, width: width, height: height)
}


func getRightEyeRightSclera(landmarks: [ImagePoint]) -> ImagePoint {
    let x = /*(landmarks[19].x + landmarks[20].x + landmarks[21].x) / 3*/ landmarks[64].x
    let y = (landmarks[19].y + landmarks[20].y + landmarks[21].y) / 3
    return ImagePoint.init(x: x, y: y)
}

func getRightEyeRightScleraBB(landmarks: [ImagePoint]) -> CGRect {
    let x = landmarks[18].x
    let y = landmarks[20].y
    let width = landmarks[22].x - x
    let bottom_y = (landmarks[18].y + landmarks[19].y + landmarks[21].y + landmarks[22].y) / 4
    let height = bottom_y - y
    return CGRect.init(x: x, y: y, width: width, height: height)
}

func getLeftCheekPoint(landmarks: [ImagePoint]) -> ImagePoint {
    let middleLeftEye = landmarks[63]
    let middleNose = landmarks[52]
    return ImagePoint.init(x: middleNose.x, y: middleLeftEye.y)
}

func getLeftEyePoint(landmarks: [ImagePoint]) -> ImagePoint {
    return landmarks[10]
}

func getLeftEyePupilPoint(landmarks: [ImagePoint]) -> ImagePoint {
    return landmarks[63]
}

func getLeftEyeLeftSclera(landmarks: [ImagePoint]) -> ImagePoint {
    let x = /*(landmarks[8].x + landmarks[9].x + landmarks[15].x) / 3*/ landmarks[63].x
    let y = (landmarks[8].y + landmarks[9].y + landmarks[15].y) / 3
    return ImagePoint.init(x: x, y: y)
}

func getLeftEyeLeftScleraBB(landmarks: [ImagePoint]) -> CGRect {
    let x = landmarks[10].x
    let y = (landmarks[9].y + landmarks[10].y + landmarks[14].y + landmarks[15].y) / 4
    let width = landmarks[14].x - x
    let height = landmarks[8].y - y
    return CGRect.init(x: x, y: y, width: width, height: height)
}

func getLeftEyeRightSclera(landmarks: [ImagePoint]) -> ImagePoint {
    let x = /*(landmarks[11].x + landmarks[12].x + landmarks[13].x) / 3*/ landmarks[63].x
    let y = (landmarks[11].y + landmarks[12].y + landmarks[13].y) / 3
    return ImagePoint.init(x: x, y: y)
}

func getLeftEyeRightScleraBB(landmarks: [ImagePoint]) -> CGRect {
    let x = landmarks[10].x
    let y = landmarks[12].y
    let width = landmarks[14].x - x
    let bottom_y = (landmarks[10].y + landmarks[11].y + landmarks[13].y + landmarks[14].y) / 4
    let height = bottom_y - y
    return CGRect.init(x: x, y: y, width: width, height: height)
}

func getChinPoint(landmarks: [ImagePoint]) -> ImagePoint {
    let centerLipBottom = landmarks[31]
    let centerJawBottom = landmarks[45]
    return ImagePoint.init(x: (centerLipBottom.x + centerJawBottom.x) / 2, y: (centerLipBottom.y + centerJawBottom.y) / 2)
}

func getForeheadPoint(landmarks: [ImagePoint]) -> ImagePoint {
    let leftEyebrowInner = landmarks[3]
    let rightEyebrowInner = landmarks[4]
    let offset = abs(leftEyebrowInner.y - rightEyebrowInner.y) / 3
    return ImagePoint.init(x: ((leftEyebrowInner.x + rightEyebrowInner.x) / 2) - offset, y: (leftEyebrowInner.y + rightEyebrowInner.y) / 2)
}

func getForeheadPair(landmarks: [ImagePoint]) -> (ImagePoint, ImagePoint) {
    let offset = abs(landmarks[2].y - landmarks[1].y)
    let leftEyeBrowSample = ImagePoint.init(x: landmarks[2].x - offset, y: landmarks[2].y)
    let rightEyeBrowSample = ImagePoint.init(x: landmarks[5].x - offset, y: landmarks[5].y)
    return (leftEyeBrowSample, rightEyeBrowSample)
}

func getEyePair(landmarks: [ImagePoint]) -> (ImagePoint, ImagePoint) {
    return (landmarks[51], landmarks[59])
}

func getUpperCheekPair(landmarks: [ImagePoint]) -> (ImagePoint, ImagePoint) {
    let leftUpperCheek = ImagePoint.init(x: landmarks[55].x, y: landmarks[8].y)
    let rightUpperCheek = ImagePoint.init(x: landmarks[55].x, y: landmarks[20].y)
    return (leftUpperCheek, rightUpperCheek)
}

func getLowerCheekPair(landmarks: [ImagePoint]) -> (ImagePoint, ImagePoint) {
    let offset = abs(landmarks[33].y - landmarks[29].y) * (1/3)
    let leftLowerCheek = ImagePoint.init(x: landmarks[33].x, y: landmarks[33].y + offset)
    let rightLowerCheek = ImagePoint.init(x: landmarks[29].x , y: landmarks[29].y - offset)
    return (leftLowerCheek, rightLowerCheek)
}

func getInnerEyeScleraPair(landmarks: [ImagePoint]) -> (ImagePoint, ImagePoint) {
    let leftEyeRightSclera = getLeftEyeRightSclera(landmarks: landmarks)
    let rightEyeLeftSclera = getRightEyeLeftSclera(landmarks: landmarks)
    return (leftEyeRightSclera, rightEyeLeftSclera)
}

func getOuterEyeScleraPair(landmarks: [ImagePoint]) -> (ImagePoint, ImagePoint) {
    let leftEyeLeftSclera = getLeftEyeLeftSclera(landmarks: landmarks)
    let rightEyeRightSclera = getRightEyeRightSclera(landmarks: landmarks)
    return (leftEyeLeftSclera, rightEyeRightSclera)
}

func getFirstRow(landmarks: [ImagePoint]) -> CGFloat {
    return (1/3) * (landmarks[10].x + landmarks[60].x + landmarks[18].x)
}

func getFirstCol(landmarks: [ImagePoint]) -> CGFloat {
    //Maybe dont include #63? -> its partially dependent on where the user is looking?
    return (1/3) * (landmarks[10].y + landmarks[63].y + landmarks[14].y)
}

func getMiddleRow(landmarks: [ImagePoint]) -> CGFloat {
    return (1/5) * (landmarks[53].x + landmarks[54].x + landmarks[55].x + landmarks[56].x + landmarks[55].x)
}

func getMiddleCol(landmarks: [ImagePoint]) -> CGFloat {
    return (1/4) * (landmarks[60].y + landmarks[61].y + landmarks[62].y + landmarks[55].y)
}

func getLastRow(landmarks: [ImagePoint]) -> CGFloat {
    return landmarks[45].x
}

func getLastCol(landmarks: [ImagePoint]) -> CGFloat {
    //Maybe dont include #64? -> its partially dependent on where the user is looking?
    return (1/3) * (landmarks[18].y + landmarks[64].y + landmarks[22].y)
}

func isLightingUnequal(points: (ImagePoint, ImagePoint), faceCapture: FaceCapture, exposureRatios: ExposureRatios) -> UnbalanceDirection? {
    guard let left = faceCapture.sampleRegionIntensity(center: points.0) else {
        print("Cant Sample Left Region")
        return nil
    }
    
    let left_exposureScore = getExposureScore(intensity: left, exposureRatios: exposureRatios)
    
    guard let right = faceCapture.sampleRegionIntensity(center: points.1) else {
        print("Cant Sample Right Region")
        return nil
    }
    
    let right_exposureScore = getExposureScore(intensity: right, exposureRatios: exposureRatios)

    if abs(left_exposureScore - right_exposureScore) <= MAX_BRIGHTNESS_SCORE / 4 {
        return .balanced
    } else if left_exposureScore > right_exposureScore {
        return .left
    }
    
    return .right
}

func sampleRect(faceCapture: FaceCapture, rect: CGRect) -> [(CGFloat, ImagePoint)] {
    //let sampleRatios: [CGFloat] = [0.3, 0.5, 0.7]
    let sampleRatios: [CGFloat] = [0.3, 0.4, 0.5, 0.6, 0.7]

    var results: [(CGFloat, ImagePoint)] = []
    
    for yRatio in sampleRatios {
        for xRatio in sampleRatios {
            let samplePoint = ImagePoint(x: Int(rect.minX + (xRatio * rect.height)), y: Int(rect.minY + (yRatio * rect.height)))
            let sampleIntensity = faceCapture.sampleRegionIntensitySmall(center: samplePoint) ?? 0.0
            results.append((sampleIntensity, samplePoint))
        }
    }
    
    return results
}

func getEyeExposurePoints(faceCapture: FaceCapture) -> (Int, [ImagePoint])? {
    faceCapture.lock()
    defer { faceCapture.unlock() }
    
    guard let facePoints = faceCapture.getAllImagePoints() else {
        print("No All Image Points in Get Eye Exposure Points")
        return nil
    }

    let LL_sclera = getLeftEyeLeftScleraBB(landmarks: facePoints)//.toCornerPoints().map { ImagePoint($0) }
    let LL_res = sampleRect(faceCapture: faceCapture, rect: LL_sclera).sorted { $0.0 > $1.0 }.first!

    let LR_sclera = getLeftEyeRightScleraBB(landmarks: facePoints)//.toCornerPoints().map { ImagePoint($0) }
    let LR_res = sampleRect(faceCapture: faceCapture, rect: LR_sclera).sorted { $0.0 > $1.0 }.first!

    let RL_sclera = getRightEyeLeftScleraBB(landmarks: facePoints)//.toCornerPoints().map { ImagePoint($0) }
    let RL_res = sampleRect(faceCapture: faceCapture, rect: RL_sclera).sorted { $0.0 > $1.0 }.first!

    let RR_sclera = getRightEyeRightScleraBB(landmarks: facePoints)//.toCornerPoints().map { ImagePoint($0) }
    let RR_res = sampleRect(faceCapture: faceCapture, rect: RR_sclera).sorted { $0.0 > $1.0 }.first!
    
    let resultPoints = [LL_res, LR_res, RL_res, RR_res].sorted { $0.0 > $1.0 }
    
    return (0, resultPoints.map { $0.1 })
}

func getExposureScore(intensity: CGFloat, exposureRatios: ExposureRatios) -> CGFloat {
    let inverseISO = CGFloat(1 / exposureRatios.iso)
    let inverseExposure = CGFloat(1 / exposureRatios.exposure)
    return CGFloat(intensity) * inverseISO * inverseExposure * 100_000
}

func isLightingUnbalanced(faceCapture: FaceCapture, cameraState: CameraState) -> (Bool, [ImagePoint])? {
    faceCapture.lock()
    defer { faceCapture.unlock() }
    
    guard let facePoints = faceCapture.getAllImagePoints() else {
        print("No All Image Points in Lighting Unbalanced")
        return nil
    }

    let exposureRatios = cameraState.getStandardizedExposureData()
    
    //BalanceLightCheckPoints
    let foreheadPair = getForeheadPair(landmarks: facePoints)
    let eyePair = getEyePair(landmarks: facePoints)
    let upperCheekPair = getUpperCheekPair(landmarks: facePoints)
    let lowerCheekPair = getLowerCheekPair(landmarks: facePoints)
    let innerEyeScleraPair = getInnerEyeScleraPair(landmarks: facePoints)
    let outerEyeScleraPair = getOuterEyeScleraPair(landmarks: facePoints)

    guard let foreheadBalance = isLightingUnequal(points: foreheadPair, faceCapture: faceCapture, exposureRatios: exposureRatios) else {
        print("Cant check FOREHEAD balance")
        return nil
    }

    guard let eyeBalance = isLightingUnequal(points: eyePair, faceCapture: faceCapture, exposureRatios: exposureRatios) else {
        print("Cant check EYE balance")
        return nil
    }

    guard let upperCheekBalance = isLightingUnequal(points: upperCheekPair, faceCapture: faceCapture, exposureRatios: exposureRatios) else {
        print("Cant check UPPER CHEEK balance")
        return nil
    }

    guard let lowerCheekBalance = isLightingUnequal(points: lowerCheekPair, faceCapture: faceCapture, exposureRatios: exposureRatios) else {
        print("Cant check LOWER CHEEK balance")
        return nil
    }
    
    guard let innerEyeScleraBalance = isLightingUnequal(points: innerEyeScleraPair, faceCapture: faceCapture, exposureRatios: exposureRatios) else {
        print("Cant check INNER EYE SCLERA balance")
        return nil
    }
    
    guard let outerEyeScleraBalance = isLightingUnequal(points: outerEyeScleraPair, faceCapture: faceCapture, exposureRatios: exposureRatios) else {
        print("Cant check INNER EYE SCLERA balance")
        return nil
    }
    
    let sets = [(foreheadBalance, foreheadPair), (eyeBalance, eyePair), (upperCheekBalance, upperCheekPair), (lowerCheekBalance, lowerCheekPair), (innerEyeScleraBalance, innerEyeScleraPair), (outerEyeScleraBalance, outerEyeScleraPair)]
    
    let balancePoints = sets.flatMap { set -> [ImagePoint] in
        let (balance, pair) = set
        var left = pair.0
        var right = pair.1
        if balance == .left {
            left.color = UIColor.red.cgColor
            right.color = UIColor.yellow.cgColor
        } else if balance == .right {
            right.color = UIColor.red.cgColor
            left.color = UIColor.yellow.cgColor
        }
        return [left, right]
    }
    
    let isBrightnessUnbalanced = !foreheadBalance.ok || !eyeBalance.ok || !upperCheekBalance.ok || !lowerCheekBalance.ok || !innerEyeScleraBalance.ok || !outerEyeScleraBalance.ok

    return (isBrightnessUnbalanced, balancePoints)
}

func isTooBright(faceCapture: FaceCapture, cameraState: CameraState) -> (Bool, [ImagePoint])? {
    faceCapture.lock()
    defer { faceCapture.unlock() }
    
    guard let facePoints = faceCapture.getAllImagePoints() else { return nil }
    
    let exposureRatios = cameraState.getStandardizedExposureData()

    //Exposure Points
    let leftCheekPoint = getLeftCheekPoint(landmarks: facePoints)
    let rightCheekPoint = getRightCheekPoint(landmarks: facePoints)
    let chinPoint = getChinPoint(landmarks: facePoints)
    let foreheadPoint = getForeheadPoint(landmarks: facePoints)
    let leftEyePupilPoint = getLeftEyePupilPoint(landmarks: facePoints)
    let rightEyePupilPoint = getRightEyePupilPoint(landmarks: facePoints)
    
    //let leftEyeLeftScleraPoint = getLeftEyeLeftSclera(landmarks: facePoints)
    let leftEyeRightScleraPoint = getLeftEyeRightSclera(landmarks: facePoints)
    let rightEyeLeftScleraPoint = getRightEyeLeftSclera(landmarks: facePoints)
    //let rightEyeRightScleraPoint = getRightEyeRightSclera(landmarks: facePoints)

    
    guard let leftCheekSample = faceCapture.sampleRegionIntensity(center: leftCheekPoint) else { return nil }
    guard let rightCheekSample = faceCapture.sampleRegionIntensity(center: rightCheekPoint) else { return nil }
    guard let chinSample = faceCapture.sampleRegionIntensity(center: chinPoint) else { return nil }
    guard let foreheadSample = faceCapture.sampleRegionIntensity(center: foreheadPoint) else { return nil }
    
    guard let leftPupilSample = faceCapture.sampleRegionIntensity(center: leftEyePupilPoint) else { return nil }
    guard let rightPupilSample = faceCapture.sampleRegionIntensity(center: rightEyePupilPoint) else { return nil }
    
    //guard let leftEyeLeftScleraSample = faceCapture.sampleRegionIntensity(center: leftEyeLeftScleraPoint) else { return nil }
    guard let leftEyeRightScleraSample = faceCapture.sampleRegionIntensity(center: leftEyeRightScleraPoint) else { return nil }
    guard let rightEyeLeftScleraSample = faceCapture.sampleRegionIntensity(center: rightEyeLeftScleraPoint) else { return nil }
    //guard let rightEyeRightScleraSample = faceCapture.sampleRegionIntensity(center: rightEyeRightScleraPoint) else { return nil }
    
    let sortedSamples = [
        (leftCheekSample, leftCheekPoint),
        (rightCheekSample, rightCheekPoint),
        (chinSample, chinPoint),
        (foreheadSample, foreheadPoint),
        (leftPupilSample, leftEyePupilPoint),
        (rightPupilSample, rightEyePupilPoint),
        //(leftEyeLeftScleraSample, leftEyeLeftScleraPoint),
        (leftEyeRightScleraSample, leftEyeRightScleraPoint),
        (rightEyeLeftScleraSample, rightEyeLeftScleraPoint)
        //(rightEyeRightScleraSample, rightEyeRightScleraPoint)
        ].sorted { A, B in
        return A.0 > B.0
    }
        
    var brightnessPoints = sortedSamples.map { $0.1 }
    brightnessPoints[0].color = UIColor.red.cgColor

    let brightestExposureScore = getExposureScore(intensity: sortedSamples[0].0, exposureRatios: exposureRatios)
    let isTooBright = brightestExposureScore > MAX_BRIGHTNESS_SCORE
    
    return (isTooBright, brightnessPoints)
}


func isFaceNotParallelToCamera(faceCapture: FaceCapture, cameraState: CameraState) -> (Bool, Bool, Bool, [ImagePoint])? {
    guard let facePoints = faceCapture.getAllImagePoints() else { return nil }
    
    var isNotVerticallyAligned = true
    var isNotHorizontallyAligned = true
    var isRotated = true

    let firstRowX = getFirstRow(landmarks: facePoints)
    let middleRowX = getMiddleRow(landmarks: facePoints)
    let lastRowX = getLastRow(landmarks: facePoints)
    
    let firstColY = getFirstCol(landmarks: facePoints)
    let middleColY = getMiddleCol(landmarks: facePoints)
    let lastColY = getLastCol(landmarks: facePoints)
    
    let leftEyePoint = getLeftEyePoint(landmarks: facePoints)
    let rightEyePoint = getRightEyePoint(landmarks: facePoints)
    
    let eyeWidth = abs(leftEyePoint.y - rightEyePoint.y)
    let eyeHeight = abs(leftEyePoint.x - rightEyePoint.x)
    let rotatedRatio = eyeHeight / eyeWidth
    if rotatedRatio < 0.1 {
        isRotated = false
    }
    
    let firstSectionHeight = middleRowX - firstRowX
    let combinedSectionHeight = lastRowX - firstRowX
    let firstSectionHeightRatio = firstSectionHeight / combinedSectionHeight

    if (firstSectionHeightRatio > 0.35) && (firstSectionHeightRatio < 0.55) {
        isNotVerticallyAligned = false
    }
    
    let firstSectionWidth = firstColY - middleColY
    let combinedSectionWidth = firstColY - lastColY
    let firstSectionWidthRatio = firstSectionWidth / combinedSectionWidth
    
    if (firstSectionWidthRatio > 0.4) && (firstSectionWidthRatio < 0.6) {
        isNotHorizontallyAligned = false
    }
    /*
    print("---")
    print("Height :: \(isNotVerticallyAligned) | Width :: \(isNotHorizontallyAligned) | Rotated :: \(isRotated)")
    print("Height Ratio :: \(firstSectionHeightRatio) | Width Ratio :: \(firstSectionWidthRatio) | Rotated Ratio :: \(rotatedRatio)")
    */
    let A = ImagePoint.init(x: firstRowX, y: firstColY)
    let B = ImagePoint.init(x: firstRowX, y: middleColY)
    let C = ImagePoint.init(x: firstRowX, y: lastColY)
    
    let D = ImagePoint.init(x: middleRowX, y: firstColY)
    let E = ImagePoint.init(x: middleRowX, y: middleColY)
    let F = ImagePoint.init(x: middleRowX, y: lastColY)
    
    let G = ImagePoint.init(x: lastRowX, y: firstColY)
    let H = ImagePoint.init(x: lastRowX, y: middleColY)
    let I = ImagePoint.init(x: lastRowX, y: lastColY)

    return (isNotHorizontallyAligned, isNotVerticallyAligned, isRotated, [A, B, C, D, E, F, G, H, I])
}
