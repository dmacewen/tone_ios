//
//  Metadata.swift
//  Tone
//
//  Created by Doug MacEwen on 4/10/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//
import Foundation
import AVFoundation

struct ImageTransforms : Codable {
    var isGammaSBGR = false
    var isRotated = false
    var isCropped = false
    var isScaled = false
    var scaleRatio: CGFloat = 1.0
    
    func getStringRepresentation() -> String{
        return "(isGammaSBGR :: \(self.isGammaSBGR) | isRotated :: \(self.isRotated)) | isCropped :: \(self.isCropped) | isScaled :: \(self.isScaled) | scaleRatio:: \(self.scaleRatio)"
    }
}

struct WhiteBalance : Codable {
    let x: Float
    let y: Float
}

struct MetaData : Codable {
    let iso: Float
    let exposureTime: Float64
    let whiteBalance: WhiteBalance
    let faceLandmarks: [CGPoint]
    let leftEyeBB: CGRect
    let rightEyeBB: CGRect
    let faceLandmarksSource = "apple"
    let flashSettings: FlashSettings
    let imageTransforms: ImageTransforms
    
    
    static func getFrom(cameraState: CameraState, captureMetadata: [String: Any], faceLandmarks: [CGPoint], leftEyeBB: CGRect, rightEyeBB: CGRect, flashSetting: FlashSettings, imageTransforms: ImageTransforms) -> MetaData {
        let meta = captureMetadata
        let exif = meta["{Exif}"] as! [String: Any]
        //print("Exif :: \(exif)")
        
        let iso = (exif["ISOSpeedRatings"] as! Array)[0] as Float
        let exposureTime = exif["ExposureTime"] as! Float64
        let whiteBalanceChromacity = cameraState.captureDevice.chromaticityValues(for: cameraState.captureDevice.deviceWhiteBalanceGains)
        let whiteBalance = WhiteBalance(x: whiteBalanceChromacity.x, y: whiteBalanceChromacity.y)
        
        //let faceLandmarksInt = faceLandmarks.map { CGPoint(x: Int($0.x), y: Int($0.y)) }
        
        return MetaData(iso: iso, exposureTime: exposureTime, whiteBalance: whiteBalance, faceLandmarks: faceLandmarks, leftEyeBB: leftEyeBB, rightEyeBB: rightEyeBB, flashSettings: flashSetting, imageTransforms: imageTransforms)
    }
    
    func prettyPrint() {
        print("ISO :: \(iso) | Exposure Time :: \(exposureTime) | White Balance (x: \(whiteBalance.x), y: \(whiteBalance.y)) | Flash Settings :: \(flashSettings.area)/\(flashSettings.areas) | Image Transforms :: \(self.imageTransforms.getStringRepresentation())")
    }
}
