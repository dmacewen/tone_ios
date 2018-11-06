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

struct WhiteBalance : Codable {
    let x: Float
    let y: Float
}

struct MetaData : Codable {
    let iso: Float
    let exposureTime: Float64
    let whiteBalance: WhiteBalance
    
    static func getFrom(cameraState: CameraState, photo: AVCapturePhoto) -> MetaData {
        let meta = photo.metadata
        let exif = meta["{Exif}"] as! [String: Any]
        //print("Exif :: \(exif)")
        
        let iso = (exif["ISOSpeedRatings"] as! Array)[0] as Float
        let exposureTime = exif["ExposureTime"] as! Float64
        let whiteBalanceChromacity = cameraState.captureDevice.chromaticityValues(for: cameraState.captureDevice.deviceWhiteBalanceGains)
        let whiteBalance = WhiteBalance(x: whiteBalanceChromacity.x, y: whiteBalanceChromacity.y)
        
        return MetaData(iso: iso, exposureTime: exposureTime, whiteBalance: whiteBalance)
    }
    
    func prettyPrint() {
        print("ISO :: \(iso) | Exposure Time :: \(exposureTime) | White Balance (x: \(whiteBalance.x), y: \(whiteBalance.y))")
    }
}
/*
struct FaceData {
    //TODO
}
*/

struct ImageData {
    let image: UIImage
    let metaData: MetaData
    //let faceData: FaceData
}

func createUIImageSet(cameraState: CameraState, photo: AVCapturePhoto) -> ImageData {
    let metaData = MetaData.getFrom(cameraState: cameraState, photo: photo)
    let image = UIImage.init(data: photo.fileDataRepresentation()!)!
    //var image = UIImage.init(cgImage: photo.cgImageRepresentation()!.takeUnretainedValue()) //Add orientation if necessary
    return ImageData(image: image, metaData: metaData)
}
