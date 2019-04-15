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
        
        precondition(floor(minX + width) <= imgSize.width)
        precondition(floor(minY + height) <= imgSize.height)
        
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
    /*
    static func from(point: CGPoint, size: CGSize) -> CGRect {
        return CGRect.init(x: point.x, y: point.y, width: size.width, height: size.height)
    }
 */
    
    static func * (left: CGRect, right: CGFloat) -> CGRect {
        return CGRect(x: left.minX * right, y: left.minY * right, width: left.width * right, height: left.height * right)
    }
    
    func scaleToSize(size: CGSize, imgSize: CGSize) -> CGRect {
        let widthDiff = abs(self.width - size.width)
        let heightDiff = abs(self.height - size.height)
        
        var newX = self.minX - floor(widthDiff / 2)
        var newY = self.minY - floor(heightDiff / 2)
        
        if newX < 0 { newX = 0 }
        if newY < 0 { newY = 0 }
        if (newX + size.width) > imgSize.width { newX -= ((newX + size.width) - imgSize.width) }
        if (newY + size.height) > imgSize.height { newY -= ((newY + size.height) - imgSize.height) }
        
        precondition(newX >= 0)
        precondition(newY >= 0)
        
        let origin = CGPoint(x: newX, y: newY)
        
        return CGRect.init(origin: origin, size: size)
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
        return CGRect(x: Int(ceil(self.minX)), y: Int(ceil(self.minY)), width: Int(floor(self.width)), height: Int(floor(self.height)))
    }
}

extension CGSize {
    static func from(rect: CGRect) -> CGSize {
        return CGSize.init(width: rect.width, height: rect.height)
    }
    
    static func * (left: CGSize, right: CGFloat) -> CGSize {
        return CGSize(width: left.width * right, height: left.height * right)
    }
}
