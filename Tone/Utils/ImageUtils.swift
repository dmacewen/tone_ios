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

struct RealTimeFaceData {
    var landmarks: [ImagePoint]
    var isLightingUnbalanced: Bool
    var balancePoints: [ImagePoint]
    var isTooBright: Bool
    var brightnessPoints: [ImagePoint]
    var exposurePoint: ImagePoint
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

let MAX_BRIGHTNESS_SCORE: CGFloat = 20_000

func getRightCheekPoint(landmarks: [ImagePoint]) -> ImagePoint {
    let middleRightEye = landmarks[64]
    let middleNose = landmarks[58]
    return ImagePoint.init(x: middleNose.x, y: middleRightEye.y)
}

func getLeftCheekPoint(landmarks: [ImagePoint]) -> ImagePoint {
    let middleLeftEye = landmarks[63]
    let middleNose = landmarks[52]
    return ImagePoint.init(x: middleNose.x, y: middleLeftEye.y)
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

func isLightingUnequal(points: (ImagePoint, ImagePoint), faceCapture: FaceCapture, exposureRatios: ExposureRatios) -> UnbalanceDirection? {
    guard let left = faceCapture.sampleRegion(center: points.0) else {
        print("Cant Sample Left Region")
        return nil
    }
    
    let left_exposureScore = getExposureScore(intensity: left, exposureRatios: exposureRatios)
    
    guard let right = faceCapture.sampleRegion(center: points.1) else {
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
    
    let sets = [(foreheadBalance, foreheadPair), (eyeBalance, eyePair), (upperCheekBalance, upperCheekPair), (lowerCheekBalance, lowerCheekPair)]
    
    let balancePoints = sets.flatMap { set -> [ImagePoint] in
        let (balance, pair) = set
        var left = pair.0
        var right = pair.1
        if balance == .left {
            right.color = UIColor.red.cgColor
            left.color = UIColor.yellow.cgColor
        } else if balance == .right {
            left.color = UIColor.red.cgColor
            right.color = UIColor.yellow.cgColor
        }
        return [left, right]
    }
    
    let isBrightnessUnbalanced = !foreheadBalance.ok || !eyeBalance.ok || !upperCheekBalance.ok || !lowerCheekBalance.ok

    return (isBrightnessUnbalanced, balancePoints)
}

func isTooBright(faceCapture: FaceCapture, cameraState: CameraState) -> (Bool, [ImagePoint])? {
    faceCapture.lock()
    defer { faceCapture.unlock() }
    
    guard let facePoints = faceCapture.getAllImagePoints() else { return nil }
    
    let exposureRatios = cameraState.getStandardizedExposureData()

    //Exposure Points
    let leftCheekPoint = getLeftCheekPoint(landmarks: facePoints)
    //leftCheekPoint.color = UIColor.blue.cgColor
    let rightCheekPoint = getRightCheekPoint(landmarks: facePoints)
    //rightCheekPoint.color = UIColor.red.cgColor
    let chinPoint = getChinPoint(landmarks: facePoints)
    //chinPoint.color = UIColor.green.cgColor
    let foreheadPoint = getForeheadPoint(landmarks: facePoints)
    //foreheadPoint.color = UIColor.yellow.cgColor
    
    guard let leftCheekSample = faceCapture.sampleRegion(center: leftCheekPoint) else { return nil }
    guard let rightCheekSample = faceCapture.sampleRegion(center: rightCheekPoint) else { return nil }
    guard let chinSample = faceCapture.sampleRegion(center: chinPoint) else { return nil }
    guard let foreheadSample = faceCapture.sampleRegion(center: foreheadPoint) else { return nil }
    
    let sortedSamples = [(leftCheekSample, leftCheekPoint), (rightCheekSample, rightCheekPoint), (chinSample, chinPoint), (foreheadSample, foreheadPoint)].sorted { A, B in
        return A.0 > B.0
    }
        
    var brightnessPoints = sortedSamples.map { $0.1 }
    //print("Brightnesses :: \(sortedSamples.map { $0.0 } )")
    brightnessPoints[0].color = UIColor.red.cgColor
    //brightnessPoints[1].color = UIColor.yellow.cgColor
    //brightnessPoints[2].color = UIColor.green.cgColor
    brightnessPoints[3].color = UIColor.magenta.cgColor

    let brightestExposureScore = getExposureScore(intensity: sortedSamples.first!.0, exposureRatios: exposureRatios)
    print("BRIGHTEST EXPOSURE SCORE :: \(brightestExposureScore)")
    let isTooBright = brightestExposureScore > MAX_BRIGHTNESS_SCORE
    
    return (isTooBright, brightnessPoints)
}
