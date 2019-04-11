//
//  CGExtensions.swift
//  Tone
//
//  Created by Doug MacEwen on 4/10/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation
import AVFoundation

extension CGPoint {
    static func - (left: CGPoint, right: CGPoint) -> CGPoint {
        return CGPoint(x: left.x - right.x, y: left.y - right.y)
    }
    
    static func + (left: CGPoint, right: CGPoint) -> CGPoint {
        return CGPoint(x: left.x + right.x, y: left.y + right.y)
    }
    
    static func - (left: CGPoint, right: CGVector) -> CGPoint {
        return CGPoint(x: left.x - right.dx, y: left.y - right.dy)
    }
    
    static func + (left: CGPoint, right: CGVector) -> CGPoint {
        return CGPoint(x: left.x + right.dx, y: left.y + right.dy)
    }
    
    static func * (left: CGPoint, right: CGFloat) -> CGPoint {
        return CGPoint(x: left.x * right, y: left.y * right)
    }
    
    func getOffset (_ right: CGPoint) -> CGVector {
        return CGVector(dx: right.x - self.x, dy: right.y - self.y)
    }
    
    func toInt() -> CGPoint {
        return CGPoint.init(x: Int(self.x), y: Int(self.y))
    }
}

extension CGRect {
    static func fromPoints<T:MutableCollection>(points: T, imgSize: CGSize) -> CGRect where T.Iterator.Element == CGPoint {
        var minX = points.map { $0.x }.min()!
        if minX < 0 { minX = 0 }
        var maxX = points.map { $0.x }.max()!
        if maxX > imgSize.width { maxX = imgSize.width }//Landmarks can sometimes be placed outside image?
        let width = maxX - minX
        
        var minY = points.map { $0.y }.min()!
        if minY < 0 { minY = 0 }
        var maxY = points.map { $0.y }.max()!
        if maxY > imgSize.height { maxY = imgSize.height }
        let height = maxY - minY
        
        precondition(minX + width < imgSize.width)
        precondition(minY + height < imgSize.height)
        
        return CGRect(x: minX, y: minY, width: width, height: height)
    }
    
    static func fromBoundingBoxes<T:MutableCollection>(rectangles: T, imgSize: CGSize) -> CGRect where T.Iterator.Element == CGRect{
        var minX = rectangles.map { $0.minX }.min()!
        if minX < 0 { minX = 0 }
        var maxX = rectangles.map { $0.maxX }.max()!
        if maxX > imgSize.width { maxX = imgSize.width }//Landmarks can sometimes be placed outside image?
        let width = maxX - minX
        
        var minY = rectangles.map { $0.minY }.min()!
        if minY < 0 { minY = 0 }
        var maxY = rectangles.map { $0.maxY }.max()!
        if maxY > imgSize.height { maxY = imgSize.height }
        let height = maxY - minY
        
        precondition(minX + width < imgSize.width)
        precondition(minY + height < imgSize.height)
        
        return CGRect(x: minX, y: minY, width: width, height: height)
    }
    
    static func * (left: CGRect, right: CGFloat) -> CGRect {
        return CGRect(x: left.minX * right, y: left.minY * right, width: left.width * right, height: left.height * right)
    }
    
    func addOffsetVector(vector: CGVector, imgSize: CGSize) -> CGRect {
        let x = self.minX + vector.dx
        let y = self.minY + vector.dy
        
        precondition(x >= 0)
        precondition(y >= 0)
        precondition(x < imgSize.width)
        precondition(y < imgSize.height)
        
        return CGRect(x: x, y: y, width: self.width, height: self.height)
    }
    
    func subOffsetVector(vector: CGVector, imgSize: CGSize) -> CGRect {
        let x = self.minX - vector.dx
        let y = self.minY - vector.dy
        
        precondition(x >= 0)
        precondition(y >= 0)
        precondition(x < imgSize.width)
        precondition(y < imgSize.height)
        
        return CGRect(x: x, y: y, width: self.width, height: self.height)
    }
    
    func toInt() -> CGRect {
        return CGRect(x: Int(self.minX), y: Int(self.minY), width: Int(self.width), height: Int(self.height))
    }
}
