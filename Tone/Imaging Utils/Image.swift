//
//  Image.swift
//  Tone
//
//  Created by Doug MacEwen on 4/12/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation
import AVFoundation
import CoreImage
import Vision

class Image {
    var image: CIImage
    var landmarks: [CGPoint]
    private var imageMetadata = ImageMetadata()
    
    init(image: CIImage, landmarks: [CGPoint]) {
        self.image = image
        self.landmarks = landmarks
    }
    
    deinit {
        print("DESTORYING IMAGE!")
    }
    
    static func from(image: Image, crop: CGRect, landmarks: [CGPoint]) -> Image {
        let ciImage = image.image.cropped(to: crop.toInt())
        let croppedLandmarks = landmarks.map { CGPoint.init(x: $0.x - crop.toInt().minX, y: $0.y - crop.toInt().minY) }
        let newImage = Image(image: ciImage, landmarks: croppedLandmarks)
        newImage.imageMetadata.isCropped = true
        newImage.imageMetadata.bbInParent = crop
        return newImage
    }
    
    func getImageMetadata() -> ImageMetadata {
        self.imageMetadata.landmarks = landmarks
        return self.imageMetadata
    }
    
    func crop(_ crop: CGRect) {
        self.image = self.image.cropped(to: crop.toInt())
        imageMetadata.isCropped = true
        imageMetadata.bbInParent = crop
        self.landmarks = self.landmarks.map { CGPoint.init(x: $0.x - crop.toInt().minX, y: $0.y - crop.toInt().minY) }
    }
    
    func scale(_ scale: CGFloat) {
        guard let bbInParent = self.imageMetadata.bbInParent else {
            print("NO BB!")
            return
        }
        //print("Extent vs Crop :: \(image.extent) vs \(imageMetadata.bbInParent!)")
        let scaledBBX = ceil(bbInParent.minX * scale)
        let scaledBBY = ceil(bbInParent.minY * scale)
        let scaledBBWidth = floor(bbInParent.width * scale)
        let scaledBBHeight = floor(bbInParent.height * scale)
        let scaledRect = CGRect.init(x: scaledBBX, y: scaledBBY, width: scaledBBWidth, height: scaledBBHeight) //Eventually use for crop?
        print("Cropping To :: \(scaledRect)")
        
        let toScaleFilter = CIFilter(name:"CILanczosScaleTransform")
        toScaleFilter!.setValue(self.image, forKey: kCIInputImageKey)
        toScaleFilter!.setValue(scale, forKey: kCIInputScaleKey)
        toScaleFilter!.setValue(1, forKey: kCIInputAspectRatioKey)
        
        imageMetadata.isScaled = true
        imageMetadata.scaleRatio = scale
        self.image = toScaleFilter!.outputImage!.cropped(to: scaledRect)
        self.landmarks = self.landmarks.map { CGPoint.init(x: $0.x * scale, y: $0.y * scale) }
        self.imageMetadata.bbInParent = CGRect.init(x: scaledBBX, y: scaledBBY, width: scaledBBWidth, height: scaledBBHeight)
    }
    
    func rotate() {
        let toRotateFilter = CIFilter(name:"CIAffineTransform")
        let affineRotationTransform = CGAffineTransform.init(rotationAngle: -CGFloat.pi/2)
        toRotateFilter!.setValue(affineRotationTransform, forKey: kCIInputTransformKey)
        toRotateFilter!.setValue(self.image, forKey: kCIInputImageKey)
        self.imageMetadata.isRotated = true
        self.image = toRotateFilter!.outputImage!
        
        guard let bbInParent = self.imageMetadata.bbInParent else {
            return
        }
        
        let newX = bbInParent.minY
        let newY = bbInParent.minX
        let newWidth = bbInParent.height
        let newHeight = bbInParent.width
        
        self.imageMetadata.bbInParent = CGRect.init(x: newX, y: newY, width: newWidth, height: newHeight)
    }
    
    func updateParentBB(rotate: Bool) {
        if !rotate {
            return
        }
        
        guard let bbInParent = self.imageMetadata.bbInParent else {
            return
        }
        
        let newX = bbInParent.minY
        let newY = bbInParent.minX
        let newWidth = bbInParent.height
        let newHeight = bbInParent.width
        
        self.imageMetadata.bbInParent = CGRect.init(x: newX, y: newY, width: newWidth, height: newHeight)
    }
    
    func updateParentBB(parentCrop crop: CGRect) {
        guard let bbInParent = self.imageMetadata.bbInParent else {
            return
        }
        
        let newX = bbInParent.minX - crop.minX
        let newY = bbInParent.minY - crop.minY
        self.imageMetadata.bbInParent = CGRect.init(x: newX, y: newY, width: bbInParent.width, height: bbInParent.height)
    }
    
    func updateParentBB(parenScale scale: CGFloat) {
        guard let bbInParent = imageMetadata.bbInParent else {
            return
        }
        
        let newX = bbInParent.minX * scale
        let newY = bbInParent.minY * scale
        let newWidth = bbInParent.width * scale
        let newHeight = bbInParent.height * scale
        
        imageMetadata.bbInParent = CGRect.init(x: newX, y: newY, width: newWidth, height: newHeight)
    }
}
