//
//  Points.swift
//  Tone
//
//  Created by Doug MacEwen on 4/16/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

//3 Coord Systems. Landmark, Display, Buffer/Image
// - Landmark: Origin at bottom left of Portrait image
// - Display: Origin at top left of Portrait image
// - Image/Buffer: Origin at top left of LANDSCAPE iamge

//Points as returned by the landmarking function
struct LandmarkPoint {
    let point: CGPoint
    var x: CGFloat { return self.point.x }
    var y: CGFloat { return self.point.y }
    
    init(_ point: CGPoint) {
        self.point = point
    }
    
    init(x: CGFloat, y: CGFloat) {
        self.point = CGPoint.init(x: x, y: y)
    }
    
    init(x: Int, y: Int) {
        self.point = CGPoint.init(x: x, y: y)
    }
    
    func toImagePoint(size: ImageSize) -> ImagePoint {
        let landmarkSize = size.toLandmarkSize()
        let newX = landmarkSize.height - self.y
        let newY = landmarkSize.width - self.x
        return ImagePoint(x: newX, y: newY)
    }
    
    func toDisplayPoint(size: ImageSize, videoLayer: AVCaptureVideoPreviewLayer) -> DisplayPoint {
        let imagePoint = self.toImagePoint(size: size)
        return imagePoint.toDisplayPoint(size: size, videoLayer: videoLayer)
    }
}

struct LandmarkSize {
    let size: CGSize
    var width: CGFloat { return self.size.width }
    var height: CGFloat { return self.size.height }
    
    init(_ size: CGSize) {
        self.size = size
    }
    
    init(width: CGFloat, height: CGFloat) {
        self.size = CGSize.init(width: width, height: height)
    }
    
    init(width: Int, height: Int) {
        self.size = CGSize.init(width: width, height: height)
    }
    
    func toImageSize() -> ImageSize {
        let newSize = CGSize(width: self.height, height: self.width)
        return ImageSize(newSize)
    }
    
    func toDisplaySize(videoLayer: AVCaptureVideoPreviewLayer) -> DisplaySize {
        return self.toImageSize().toDisplaySize(videoLayer: videoLayer)
    }
}

//Points in the native image buffer
struct ImagePoint {
    let point: CGPoint
    var x: CGFloat { return self.point.x }
    var y: CGFloat { return self.point.y }
    var color: CGColor? = nil
    
    init(_ point: CGPoint) {
        self.point = point
    }
    
    init(x: CGFloat, y: CGFloat) {
        self.point = CGPoint.init(x: x, y: y)
    }
    
    init(x: Int, y: Int) {
        self.point = CGPoint.init(x: x, y: y)
    }
    
    func toLandmarkPoint(size: ImageSize) -> LandmarkPoint {
        let newX = size.height - self.y
        let newY = size.width - self.x
        return LandmarkPoint(x: newX, y: newY)
    }
    
    func toDisplayPoint(size: ImageSize, videoLayer: AVCaptureVideoPreviewLayer) -> DisplayPoint {
        let normalizedImagePoint = self.toNormalizedImagePoint(size: size)
        let normalizedX = normalizedImagePoint.x
        let normalizedY = 1 - normalizedImagePoint.y
        
        guard let color = self.color else {
            return DisplayPoint.init(videoLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint.init(x: normalizedX, y: normalizedY)))
        }
        return DisplayPoint.init(videoLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint.init(x: normalizedX, y: normalizedY)), color: color)
    }
    
    func toNormalizedImagePoint(size: ImageSize) -> NormalizedImagePoint {
        let normalizedX = self.x / size.width
        let normalizedY = self.y / size.height
        return NormalizedImagePoint.init(x: normalizedX, y: normalizedY)
    }
}

struct NormalizedImagePoint {
    let point: CGPoint
    var x: CGFloat { return self.point.x }
    var y: CGFloat { return self.point.y }
    
    init(_ point: CGPoint) {
        /* Landmarks can return points larger than 1.0. Display seems to handle them fine
        precondition(point.x < 1.0)
        precondition(point.y < 1.0)
         */
        
        self.point = point
    }
    
    init(x: CGFloat, y: CGFloat) {
        /* Landmarks can return points larger than 1.0. Display seems to handle them fine
        precondition(x < 1.0)
        precondition(y < 1.0)
         */
        
        self.point = CGPoint.init(x: x, y: y)
    }
    
    init(x: Int, y: Int) {
        /* Landmarks can return points larger than 1.0. Display seems to handle them fine
        precondition(x < 1)
        precondition(y < 1)
        */
        
        self.point = CGPoint.init(x: x, y: y)
    }
}

struct ImageSize {
    let size: CGSize
    var width: CGFloat { return self.size.width }
    var height: CGFloat { return self.size.height }
    
    init(_ size: CGSize) {
        self.size = size
    }
    
    init(width: CGFloat, height: CGFloat) {
        self.size = CGSize.init(width: width, height: height)
    }
    
    init(width: Int, height: Int) {
        self.size = CGSize.init(width: width, height: height)
    }
    
    func toLandmarkSize() -> LandmarkSize {
        let newSize = CGSize(width: self.height, height: self.width)
        return LandmarkSize(newSize)
    }
    
    func toDisplaySize(videoLayer: AVCaptureVideoPreviewLayer) -> DisplaySize {
        let imageBoundsPoint = ImagePoint.init(x: self.width, y: self.height)
        let displayBoundsPoint = imageBoundsPoint.toDisplayPoint(size: self, videoLayer: videoLayer)
        return DisplaySize.init(width: displayBoundsPoint.x, height: displayBoundsPoint.y)
    }
}


struct DisplayPoint {
    let point: CGPoint
    var x: CGFloat { return self.point.x }
    var y: CGFloat { return self.point.y }
    var color = UIColor.blue.cgColor
    
    init(_ point: CGPoint) {
        self.point = point
    }
    
    init(_ point: CGPoint, color: CGColor) {
        self.point = point
        self.color = color
    }
    
    init(x: CGFloat, y: CGFloat) {
        self.point = CGPoint.init(x: x, y: y)
    }
    
    init(x: CGFloat, y: CGFloat, color: CGColor) {
        self.point = CGPoint.init(x: x, y: y)
        self.color = color
    }
    
    init(x: Int, y: Int) {
        self.point = CGPoint.init(x: x, y: y)
    }
    
    init(x: Int, y: Int, color: CGColor) {
        self.point = CGPoint.init(x: x, y: y)
        self.color = color
    }
}

struct DisplaySize {
    let size: CGSize
    var width: CGFloat { return self.size.width }
    var height: CGFloat { return self.size.height }
    
    init(_ size: CGSize) {
        self.size = size
    }
    
    init(width: CGFloat, height: CGFloat) {
        self.size = CGSize.init(width: width, height: height)
    }
    
    init(width: Int, height: Int) {
        self.size = CGSize.init(width: width, height: height)
    }
}
