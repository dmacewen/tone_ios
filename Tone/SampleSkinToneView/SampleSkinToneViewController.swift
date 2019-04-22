//
//  SampleSkinToneViewController.swift
//  Tone
//
//  Created by Doug MacEwen on 10/30/18.
//  Copyright © 2018 Doug MacEwen. All rights reserved.
//
/*
import Foundation
import AVFoundation
import UIKit
import RxSwift
import RxCocoa

class SampleSkinToneViewController: UIViewController {
    var viewModel: SampleSkinToneViewModel!

    let disposeBag = DisposeBag()

    override func viewDidLoad() {
        /*
        super.viewDidLoad()
        title = "Sample Skin Tone"
        print("Saving Original Screen Brightness!")
        self.viewModel.originalScreenBrightness = UIScreen.main.brightness
*/
       
        /*
        viewModel.sampleState
            .observeOn(MainScheduler.instance)
            .map { if case .previewUser = $0 { return false } else { return true } }
            .bind(to: InteractionLayer.rx.isHidden )
            .disposed(by: disposeBag)
        */
        /*
        viewModel.sampleState
            .observeOn(MainScheduler.instance)
            .map { state in
                if case .upload = state { return false }
                else if case .process = state { return false }
                else if case .prepping = state { return false }
                else { return true }
            }
            .bind(to: UploadProgessLayer.rx.isHidden )
            .disposed(by: disposeBag)
 */
        /*
        viewModel.sampleState
            .observeOn(MainScheduler.instance)
            .filter { if case .process = $0 { return true } else { return false }}
            .subscribe(onNext: { _ in
                print("Processing...")
                self.ProgessLayer.isHidden = false
                self.UploadLayer.isHidden = true
                self.PreppingLayer.isHidden = true
                self.ProgessSpinner.startAnimating()
            }).disposed(by: disposeBag)
 */
        /*
        viewModel.sampleState
            .observeOn(MainScheduler.instance)
            .filter { if case .prepping = $0 { return true } else { return false }}
            .subscribe(onNext: { _ in
                print("Prepping...")
                self.PreppingLayer.isHidden = false
                self.ProgessLayer.isHidden = true
                self.UploadLayer.isHidden = true
                self.PreppingSpinner.startAnimating()
            }).disposed(by: disposeBag)
*/

        /*
        viewModel.uploadProgress
            //.map { $0 == 1.0 }
            .distinctUntilChanged()
            .subscribe(onNext: { uploadAmount in
                let currentState = try! self.viewModel.sampleState.value()
                if case .upload(_) = currentState {
                    if uploadAmount == 1.0 {
                        print("Upload Done")
                        self.ProgessLayer.isHidden = false
                        self.UploadLayer.isHidden = true
                        self.PreppingLayer.isHidden = true
                        self.ProgessSpinner.startAnimating()
                    } else {
                        self.ProgessLayer.isHidden = true
                        self.PreppingLayer.isHidden = true
                        self.UploadLayer.isHidden = false
                    }
                }
            }).disposed(by: disposeBag)
*/
        /*
        viewModel.sampleState
            .observeOn(MainScheduler.instance)
            .map { (state) -> Bool in
                switch(state) {
                case .previewUser, .process(_), .upload(_), .prepping: return false
                case .referenceSample, .sample: return true
                }
            }
            .distinctUntilChanged()
            .subscribe(onNext: { isFlashLayer in
                if isFlashLayer {
                    print("Saving Original Screen Brightness!")
                    self.viewModel.originalScreenBrightness = UIScreen.main.brightness
                    print("Maxing Screen Brightness!")
                    UIScreen.main.brightness = CGFloat(1.0)
                    self.FlashLayer.isHidden = false
                } else {
                    print("Setting screen brightness to original value!")
                    UIScreen.main.brightness = self.viewModel.originalScreenBrightness
                    self.FlashLayer.isHidden = true
                }
            })
            .disposed(by: disposeBag)
 */
/*
        viewModel.flashSettingsTaskStream
            .observeOn(MainScheduler.instance)
            .subscribeOn(MainScheduler.instance)
            .subscribe(onNext: { flashSettingTask in
                flashSettingTask.isDone.onNext(false)
                let flashSetting = flashSettingTask.flashSettings
                if flashSetting.areas == 0 {
                    //Return Early if Areas is 0
                    print("Zero Areas Returning Early")
                    return
                }
                let area = flashSetting.area
                let areas = flashSetting.areas
                let screenSize = UIScreen.main.bounds
                
                let checkerSize = 10
                let width = screenSize.width
                let columns = Int((width / CGFloat(checkerSize)))
                
                let height = screenSize.height
                let rows = Int((height / CGFloat(checkerSize)))
                
                print("Setting Flash! Area: \(area) Areas: \(areas)")
                
                //let renderer = UIGraphicsImageRenderer(size: CGSize(width: (columns * checkerSize), height: (rows * checkerSize)))
                //Replace with Checkerboard CIFilter?
                let img = self.renderer.image { ctx in
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
                    print("Done Rendering!")
                }
                
                self.FlashLayer.image = img
                self.FlashLayer.setNeedsDisplay()
                print("Animating?? :: \(self.FlashLayer.isAnimating)")
                print("Done Drawing!")
                flashSettingTask.isDone.onNext(true)

                /*
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    flashSettingTask.isDone.onNext(true)
                }
                */
 
                //flashSettingTask.isDone.onCompleted()
            }).disposed(by: disposeBag)
        */
        /*
        viewModel.drawPointsStream
            .observeOn(MainScheduler.instance)
            .subscribeOn(MainScheduler.instance)
            //.distinctUntilChanged()
            .subscribe(onNext: { points in
                let size = 5
                let halfSize = 2 //floor size/2
                
                //REUSE THIS!
                //let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
                
                //Replace with Checkerboard CIFilter?
                let img = self.renderer.image { ctx in
                    
                    ctx.cgContext.setFillColor(UIColor.red.cgColor)
                
                    for point in points {
                        ctx.cgContext.setFillColor(point.color)
                        ctx.cgContext.fill(CGRect(x: Int(point.x) - halfSize, y: Int(point.y) - halfSize, width: size, height: size))
                    }
                }
                
                //self.FlashLayer.image = img
                self.OverlayLayer.image = img
            }).disposed(by: disposeBag)
        */
        /*
        viewModel.sampleState
            .filter { if case .previewUser = $0 { return true } else { return false } }
            .take(1)
            .subscribe(onNext: { _ in
                print("Setting up preview!")
                //Create View Preview Layer
                let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.viewModel.cameraState.captureSession)
                videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
                //videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
                videoPreviewLayer.frame = self.view.layer.bounds
                self.viewModel.videoSize = videoPreviewLayer.bounds.size
                
                self.InteractionLayer.layer.insertSublayer(videoPreviewLayer, below: self.UILayer.layer)
                
                //Provide Access to video preview layer for converting between coordinate systems.... there might be a better way?
                self.viewModel.videoPreviewLayerStream.onNext(videoPreviewLayer)
            }, onError: { error in print(error) } ).disposed(by: disposeBag)
 */
    }
    /*
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewModel.video.pauseProcessing()
    }
 */
}
*/
