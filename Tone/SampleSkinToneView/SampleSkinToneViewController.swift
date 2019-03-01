//
//  SampleSkinToneViewController.swift
//  Tone
//
//  Created by Doug MacEwen on 10/30/18.
//  Copyright © 2018 Doug MacEwen. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit
import RxSwift
import RxCocoa

class SampleSkinToneViewController: UIViewController {
    var viewModel: SampleSkinToneViewModel!
    
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var takeSampleButton: UIButton!
    @IBOutlet weak var UILayer: UIView!
    @IBOutlet weak var InteractionLayer: UIView!
    
    @IBOutlet weak var UploadProgessLayer: UIView!
    @IBOutlet weak var ProgessLayer: UIView!
    @IBOutlet weak var ProgessSpinner: UIActivityIndicatorView!
    @IBOutlet weak var UploadLayer: UIView!
    @IBOutlet weak var UploadBar: UIProgressView!

    
    @IBOutlet weak var rootView: UIView!
    
    @IBOutlet weak var FlashLayer: UIImageView!
    
    @IBOutlet weak var userPrompt: UITextField!
    @IBOutlet weak var userTip: UITextField!
    
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Sample Skin Tone"
        print("Saving Original Screen Brightness!")
        self.viewModel.originalScreenBrightness = UIScreen.main.brightness
        
        cancelButton.rx.tap
            .single()
            .subscribe(onNext: { _ in self.viewModel.cancel() })
            .disposed(by: disposeBag)
        
        takeSampleButton.rx.tap
            .subscribe(onNext: { _ in
                self.viewModel.sampleState.onNext(.referenceSample)
            }).disposed(by: disposeBag)

        viewModel.userFaceState
            .asDriver(onErrorJustReturn: .noFaceFound)
            .distinctUntilChanged()
            .throttle(0.5)
            .drive(onNext:{
                self.userPrompt.text = $0.prompt.message
                self.userTip.text = $0.prompt.tip
            })
            .disposed(by: disposeBag)
        
        viewModel.userFaceState
            .map { $0 == .ok }
            .bind(to: takeSampleButton.rx.isEnabled)
            .disposed(by: disposeBag)
        
        viewModel.sampleState
           // .observeOn(MainScheduler.instance)
            .map { if case .previewUser = $0 { return false } else { return true } }
            .bind(to: InteractionLayer.rx.isHidden )
            .disposed(by: disposeBag)
        
        viewModel.sampleState
        //    .observeOn(MainScheduler.instance)
            .map { if case .upload = $0 { return false } else { return true } }
            .bind(to: UploadProgessLayer.rx.isHidden )
            .disposed(by: disposeBag)
        
        viewModel.uploadProgress
            .bind(to: UploadBar.rx.progress)
            .disposed(by: disposeBag)
        
        viewModel.uploadProgress
            .map { $0 == 1.0 }
            .distinctUntilChanged()
            .subscribe(onNext: { isUploaded in
                print("isUploaded! :: \(isUploaded)")
                if isUploaded {
                    self.ProgessLayer.isHidden = false
                    self.UploadLayer.isHidden = true
                    self.ProgessSpinner.startAnimating()
                } else {
                    self.ProgessLayer.isHidden = true
                    self.UploadLayer.isHidden = false
                }
            }).disposed(by: disposeBag)

        
        viewModel.sampleState
            .observeOn(MainScheduler.instance)
            .map { (state) -> Bool in
                switch(state) {
                case .previewUser, .upload(_): return false
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

        viewModel.flashSettings
            .observeOn(MainScheduler.instance)
            .subscribeOn(MainScheduler.instance)
            .subscribe(onNext: { flashSetting in
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
                
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: (columns * checkerSize), height: (rows * checkerSize)))
                //Replace with Checkerboard CIFilter?
                let img = renderer.image { ctx in
                    ctx.cgContext.setFillColor(UIColor.white.cgColor)
                    ctx.cgContext.fill(CGRect(x: 0, y: 0, width: width, height: height))
                    
                    ctx.cgContext.setFillColor(UIColor.black.cgColor)

                    if area != 0 {
                        for row in 0 ..< rows {
                            for column in 0 ..< columns {
                                if ((row + column) % areas) + 1 > area {
                                    ctx.cgContext.fill(CGRect(x: (column * checkerSize), y: (row * checkerSize), width: checkerSize, height: checkerSize))
                                }
                            }
                        }
                    } else {
                        ctx.cgContext.fill(CGRect(x: 0, y: 0, width: width, height: height))
                    }
                }
                
                self.FlashLayer.image = img
                print("Done Drawing!")
            }).disposed(by: disposeBag)
        
        
        
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
                
                //Set Video Preview Layer to Root View
                self.InteractionLayer.layer.insertSublayer(videoPreviewLayer, below: self.UILayer.layer)
            }, onError: { error in print(error) } ).disposed(by: disposeBag)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewModel.video.pauseProcessing()
    }
}
