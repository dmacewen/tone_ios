//
//  Image.swift
//  Tone
//
//  Created by Doug MacEwen on 4/12/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation
import AVFoundation
import Vision

class Image {
    var image: CIImage
    var landmarks: [CGPoint]
    var imageMetadata = ImageMetadata()
    
    init(image: CIImage, landmarks: [CGPoint]) {
        self.image = image
        self.landmarks = landmarks
    }
    
    func crop(_ crop: CGRect) {
        self.image = self.image.cropped(to: crop)
        imageMetadata.isCropped = true
        self.landmarks = self.landmarks.map { CGPoint.init(x: $0.x - crop.minX, y: $0.y - crop.minY) }
    }
    
    static func from(image: Image, crop: CGRect) -> Image {
        //NOT AN IMPLEMENTATION
        return Image(image: image.image, landmarks: image.landmarks)
    }
}
