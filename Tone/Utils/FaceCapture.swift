//
//  FaceCapture.swift
//  Tone
//
//  Created by Doug MacEwen on 4/10/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation
import AVFoundation
import RxSwift
import Vision

class FaceCapture {
    let pixelBuffer: CVPixelBuffer
    let orientation: CGImagePropertyOrientation
    let videoPreviewLayer: AVCaptureVideoPreviewLayer
    let flashSettings: FlashSettings
    let imageSize: ImageSize
    //let landmarkImageSize: CGSize
    let rawMetadata: [String: Any]
    
    //Keep private to keep us from accessing in its raw form (it can be kind of confusing/messy to interact with)
    private var faceLandmarks: VNFaceLandmarks2D
    
    init(pixelBuffer: CVPixelBuffer, faceLandmarks: VNFaceLandmarks2D, orientation: CGImagePropertyOrientation, videoPreviewLayer: AVCaptureVideoPreviewLayer, flashSettings: FlashSettings = FlashSettings(), rawMetadata: [String: Any]) {
        self.pixelBuffer = pixelBuffer
        self.faceLandmarks = faceLandmarks
        self.orientation = orientation
        self.videoPreviewLayer = videoPreviewLayer
        self.flashSettings = flashSettings
        self.imageSize = ImageSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        //self.landmarkImageSize = FaceCapture.convertSize(self.imageSize)
        self.rawMetadata = rawMetadata
    }
    
    static func create(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, videoPreviewLayer: AVCaptureVideoPreviewLayer, flashSettings: FlashSettings = FlashSettings()) -> Observable<FaceCapture?> {
        
        return FaceCapture.getFaceLandmarks(pixelBuffer, orientation)
            .map { faceLandmarks in
                guard let foundFaceLandmarks = faceLandmarks else { return nil }
                
                return FaceCapture(pixelBuffer: pixelBuffer, faceLandmarks: foundFaceLandmarks, orientation: orientation, videoPreviewLayer: videoPreviewLayer, flashSettings: flashSettings, rawMetadata: [:])
            }
    }
    
    static func create(capturePhoto: AVCapturePhoto, orientation: CGImagePropertyOrientation, videoPreviewLayer: AVCaptureVideoPreviewLayer, flashSettings: FlashSettings = FlashSettings()) -> Observable<FaceCapture?> {
        
        return FaceCapture.getFaceLandmarks(capturePhoto.pixelBuffer!, orientation)
            .map { faceLandmarks in
                guard let foundFaceLandmarks = faceLandmarks else { return nil }
                
                return FaceCapture(pixelBuffer: capturePhoto.pixelBuffer!, faceLandmarks: foundFaceLandmarks, orientation: orientation, videoPreviewLayer: videoPreviewLayer, flashSettings: flashSettings, rawMetadata: capturePhoto.metadata)
            }
    }
    /*
    private static func convertSize(_ size: CGSize) -> CGSize {
        return CGSize.init(width: size.height, height: size.width)
    }
    
    private static func convertPoint(_ point: CGPoint, size: CGSize) -> CGPoint {
        return CGPoint.init(x: size.height - point.y, y: size.width - point.x)
        //return CGPoint.init(x: point.y, y: size.width - point.x)

    }
    */
    private static func getFaceLandmarks(_ pixelBuffer: CVPixelBuffer, _ orientation: CGImagePropertyOrientation) -> Observable<VNFaceLandmarks2D?> {
        return Observable<VNFaceLandmarks2D?>.create { observable in
            var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
            
            let cameraIntrinsicData = CMGetAttachment(pixelBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil)
            if cameraIntrinsicData != nil {
                requestHandlerOptions[VNImageOption.cameraIntrinsics] = cameraIntrinsicData
            }
            
            let faceLandmarksRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request, error) in
                if error != nil {
                    print("FaceLandmarks error: \(String(describing: error)).")
                }
                
                guard let landmarksRequest = request as? VNDetectFaceLandmarksRequest,
                    let results = landmarksRequest.results as? [VNFaceObservation] else {
                        observable.onNext(nil)
                        observable.onCompleted()
                        return
                }
                
                if results.count > 0 {
                    observable.onNext(results[0].landmarks)
                    observable.onCompleted()
                } else {
                    observable.onNext(nil)
                    observable.onCompleted()
                }
            })
            
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                            orientation: orientation,
                                                            options: requestHandlerOptions)
            
            do {
                try imageRequestHandler.perform([faceLandmarksRequest])
            } catch let error as NSError {
                NSLog("Failed to perform FaceLandmarkRequest: %@", error)
                fatalError("Error Landmarking")
            }
            
            return Disposables.create()
        }
    }
    
    //Every Coordinate passed out as a CGPoint, CGRect, CGVec, CGSize should be in ImageCood
    
    func getJawDisplayPoints() -> [DisplayPoint]? {
        guard let faceContour = self.faceLandmarks.faceContour else { return nil }
        
        return faceContour
            .pointsInImage(imageSize: self.imageSize.toLandmarkSize().size)
            .map { LandmarkPoint($0).toDisplayPoint(size: self.imageSize) }
    }
    
    func getAllImagePoints() -> [ImagePoint]? {
        guard let allPoints = self.faceLandmarks.allPoints else { return nil }
        return allPoints.pointsInImage(imageSize: self.imageSize.toLandmarkSize().size).map { LandmarkPoint($0).toImagePoint(size: self.imageSize) }
    }
    
    func getAllPointsBB() -> CGRect? {
        guard let allPoints = self.getAllImagePoints() else { return nil }
        return CGRect.fromPoints(points: allPoints.map { $0.point },  imgSize: self.imageSize.size)
    }
    
    func getAllPointsSize() -> CGSize? {
        guard let allPointsBB = self.getAllPointsBB() else { return nil }
        return CGSize.from(rect: allPointsBB)
    }
    
    func getLeftEyeImageBB() -> CGRect? {
        guard let leftEye = self.faceLandmarks.leftEye else { return nil }
        let leftEyePoints = leftEye.pointsInImage(imageSize: self.imageSize.toLandmarkSize().size).map { LandmarkPoint($0).toImagePoint(size: self.imageSize) }
        return CGRect.fromPoints(points: leftEyePoints.map { $0.point }, imgSize: self.imageSize.size)
    }
    
    func getLeftEyeImageSize() -> CGSize? {
        guard let leftEyeBB = self.getLeftEyeImageBB() else { return nil }
        return CGSize.from(rect: leftEyeBB)
    }
    
    func getRightEyeImageBB() -> CGRect? {
        guard let rightEye = self.faceLandmarks.rightEye else { return nil }
        let rightEyePoints = rightEye.pointsInImage(imageSize: self.imageSize.toLandmarkSize().size).map { LandmarkPoint($0).toImagePoint(size: self.imageSize) }
        return CGRect.fromPoints(points: rightEyePoints.map { $0.point }, imgSize: self.imageSize.size)
    }
    
    func getRightEyeImageSize() -> CGSize? {
        guard let rightEyeBB = self.getRightEyeImageBB() else { return nil }
        return CGSize.from(rect: rightEyeBB)
    }
    /*
    func displayToImagePoint(point: CGPoint) -> CGPoint {
        return videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: point)
    }
    
    func imagetoDisplayPoint(point: CGPoint) -> CGPoint {
        return videoPreviewLayer.layerPointConverted(fromCaptureDevicePoint: point)
    }
 */
    /*
    private func getCIImage(crop: CGRect?) -> CIImage {
        let image = CIImage.init(cvImageBuffer: self.pixelBuffer)
        if crop != nil {
            return image.cropped(to: crop!)
        }
        return image
    }
 */
    
    func getImage() -> Image {
        let image = CIImage.init(cvImageBuffer: self.pixelBuffer)
        let landmarks = self.getAllImagePoints()!
        return Image(image: image, landmarks: landmarks.map { $0.point })
    }
}

//3 Coord Systems. Landmark, Display, Buffer/Image
// - Landmark: Origin at bottom left of Portrait image
// - Display: Origin at top left of Portrait image
// - Image/Buffer: Origin at top left of LANDSCAPE iamge

//Points as returned by the landmarking function
struct LandmarkPoint {
    let point: CGPoint
    
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
        let newX = landmarkSize.size.height - self.point.y
        let newY = landmarkSize.size.width - self.point.x
        return ImagePoint(x: newX, y: newY)
    }
    
    func toDisplayPoint(size: ImageSize) -> DisplayPoint {
        let landmarkSize = size.toLandmarkSize()
        let newX = self.point.x
        let newY = landmarkSize.size.height - self.point.y
        return DisplayPoint(x: newX, y: newY)
    }
}

struct LandmarkSize {
    let size: CGSize
    
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
        let newSize = CGSize(width: self.size.height, height: self.size.width)
        return ImageSize(newSize)
    }
    
    func toDisplaySize() -> DisplaySize {
        return DisplaySize(self.size)
    }
}

//Points in the native image buffer
struct ImagePoint {
    let point: CGPoint
    
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
        let newX = size.size.height - self.point.y
        let newY = size.size.width - self.point.x
        return LandmarkPoint(x: newX, y: newY)
    }
    
    func toDisplayPoint(size: ImageSize) -> DisplayPoint {
        let newX = size.size.height - self.point.y
        let newY = self.point.x
        return DisplayPoint(x: newX, y: newY)
    }
}

struct ImageSize {
    let size: CGSize
    
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
        let newSize = CGSize(width: self.size.height, height: self.size.width)
        return LandmarkSize(newSize)
    }
    
    func toDisplaySize() -> DisplaySize {
        let newSize = CGSize(width: self.size.height, height: self.size.width)
        return DisplaySize(newSize)
    }
}

//The orientation (BUT NOT THE CROP RIGHT NOW! of the display orientation)
struct DisplayPoint {
    let point: CGPoint
    
    init(_ point: CGPoint) {
        self.point = point
    }
    
    init(x: CGFloat, y: CGFloat) {
        self.point = CGPoint.init(x: x, y: y)
    }
    
    init(x: Int, y: Int) {
        self.point = CGPoint.init(x: x, y: y)
    }
    
    func toLandmarkPoint(size: ImageSize) -> DisplayPoint {
        let displaySize = size.toDisplaySize()
        let newX = self.point.x
        let newY = displaySize.size.height - self.point.y
        return DisplayPoint(x: newX, y: newY)
    }
    
    func toImagePoint(size: ImageSize) -> ImagePoint {
        let displaySize = size.toDisplaySize()
        let newX = displaySize.size.height - self.point.y
        let newY = displaySize.size.width - self.point.x
        return ImagePoint(x: newX, y: newY)
    }
}

struct DisplaySize {
    let size: CGSize
    
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
        return LandmarkSize(self.size)
    }
    
    func toImageSize() -> ImageSize {
        let newSize = CGSize(width: self.size.height, height: self.size.width)
        return ImageSize(newSize)
    }
}
