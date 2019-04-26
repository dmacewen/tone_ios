//
//  FlashUtils.swift
//  Tone
//
//  Created by Doug MacEwen on 4/24/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//
/*
import Foundation
import AVFoundation
import UIKit

func getFlashImage(flashSetting: FlashSettings, size: CGSize, renderer: UIGraphicsImageRenderer) -> UIImage {
    let area = flashSetting.area
    let areas = flashSetting.areas
    
    let checkerSize = 10
    let width = size.width
    let columns = Int((width / CGFloat(checkerSize)))
    
    let height = size.height
    let rows = Int((height / CGFloat(checkerSize)))
    
    //let renderer = UIGraphicsImageRenderer(size: CGSize(width: (columns * checkerSize), height: (rows * checkerSize)))
    //Replace with Checkerboard CIFilter?
    let img = renderer.image { ctx in
        ctx.cgContext.setFillColor(UIColor.white.cgColor)
        ctx.cgContext.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        ctx.cgContext.setFillColor(UIColor.black.cgColor)
        
        let whiteRatio = area
        let blackRatio = areas - area
        let numLocations = rows * columns
        
        var location = 0
        var white = whiteRatio
        var black = blackRatio
        
        while location <= numLocations {
            
            if white > 0 {
                location += 1
                white -= 1
            }
            
            if black > 0 {
                let row = location / columns
                let column = location % columns
                ctx.cgContext.fill(CGRect(x: (column * checkerSize), y: (row * checkerSize), width: checkerSize, height: checkerSize))
                
                location += 1
                black -= 1
            }
            
            if (white == 0) && (black == 0) {
                white = whiteRatio
                black = blackRatio
            }
        }
        //Draw Focus Point where we want users to look
        let focusPointY = Int(round(height * 0.2)) - 3
        let focusPointX = Int(width * 0.5) - 3
        ctx.cgContext.setFillColor(UIColor.blue.cgColor)
        ctx.cgContext.fill(CGRect(x: focusPointX, y: focusPointY, width: 7, height: 7))
        
        ctx.cgContext.setFillColor(UIColor.black.cgColor)
        print("Done Rendering Flash \(flashSetting.area) / \(flashSetting.areas)")
    }
    
    return img
}
*/
