//
//  Metadata.swift
//  Tone
//
//  Created by Doug MacEwen on 4/10/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//
import Foundation
import AVFoundation

struct WhiteBalance : Codable {
    let x: Float
    let y: Float
    
    static func getFrom(captureDevice: AVCaptureDevice) -> WhiteBalance {
        let whiteBalanceChromacity = captureDevice.chromaticityValues(for: captureDevice.deviceWhiteBalanceGains)
        return WhiteBalance(x: whiteBalanceChromacity.x, y: whiteBalanceChromacity.y)
    }
}

struct ImageMetadata : Codable {
    var isGammaSBGR = false
    var isRotated = false
    var isCropped = false
    var isScaled = false
    
    var scaleRatio: CGFloat = 1.0
    var bbInParent: CGRect? = nil
    var landmarks: [CGPoint]? = nil
    
    func getStringRepresentation() -> String{
        return "(isGammaSBGR :: \(self.isGammaSBGR) | isRotated :: \(self.isRotated)) | isCropped :: \(self.isCropped) | isScaled :: \(self.isScaled) | scaleRatio:: \(self.scaleRatio)"
    }
}

struct SetMetadata : Codable {
    let faceLandmarksSource = "apple"
    let iso: Float64
    let exposureTime: Float64
    let whiteBalance: WhiteBalance
    let flashSettings: FlashSettings

    let faceImageTransforms: ImageMetadata
    let leftEyeImageTransforms: ImageMetadata
    let rightEyeImageTransforms: ImageMetadata
    
    init(iso: Float64, exposureTime: Float64, whiteBalance: WhiteBalance, flashSettings: FlashSettings, faceImageTransforms: ImageMetadata, leftEyeImageTransforms: ImageMetadata, rightEyeImageTransforms: ImageMetadata) {
        self.iso = iso
        self.exposureTime = exposureTime
        self.whiteBalance = whiteBalance
        self.flashSettings = flashSettings
        
        self.faceImageTransforms = faceImageTransforms
        self.leftEyeImageTransforms = leftEyeImageTransforms
        self.rightEyeImageTransforms = rightEyeImageTransforms
    }

    static func getFrom(faceImage: Image, leftEyeImage: Image, rightEyeImage: Image, flashSettings: FlashSettings, cameraState: CameraState, rawMetadata: [String: Any]) -> SetMetadata {
        let (iso, exposure) = SetMetadata.extractRelevantMetadata(rawMetadata)
        let whiteBalance = WhiteBalance.getFrom(captureDevice: cameraState.captureDevice)
        
        return SetMetadata(iso: iso, exposureTime: exposure, whiteBalance: whiteBalance, flashSettings: flashSettings, faceImageTransforms: faceImage.imageMetadata, leftEyeImageTransforms: leftEyeImage.imageMetadata, rightEyeImageTransforms: rightEyeImage.imageMetadata)
    }
    
    static private func extractRelevantMetadata(_ metadata: [String: Any]) -> (Float64, Float64) {
        let exif = metadata["{Exif}"] as! [String: Any]
        let iso = (exif["ISOSpeedRatings"] as! Array)[0] as Float64
        let exposureTime = exif["ExposureTime"] as! Float64
        
        return (iso, exposureTime)
    }
    
    func prettyPrint() {
        print("ISO :: \(iso) | Exposure Time :: \(exposureTime) | White Balance (x: \(whiteBalance.x), y: \(whiteBalance.y)) | Flash Settings :: \(flashSettings.area)/\(flashSettings.areas)")
    }
}
