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
    
    @IBOutlet weak var rootView: UIView!
    @IBOutlet weak var bottomFlash: UIView!
    @IBOutlet weak var topFlash: UIView!
    
    @IBOutlet weak var userPrompt: UITextField!
    
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Sample Skin Tone"
        
        cancelButton.rx.tap
            .single()
            .subscribe(onNext: { _ in self.viewModel.cancel() })
            .disposed(by: disposeBag)
        
        takeSampleButton.rx.tap
            .subscribe(onNext: { _ in
                self.viewModel.sampleState.onNext(.referenceSample)
            }).disposed(by: disposeBag)

        viewModel.userFaceState
            .map { $0.message }
            .bind(to: userPrompt.rx.text)
            .disposed(by: disposeBag)
        
        viewModel.userFaceState
            .map { $0 == .ok }
            .bind(to: takeSampleButton.rx.isEnabled)
            .disposed(by: disposeBag)
        
        viewModel.sampleState
            .observeOn(MainScheduler.instance)
            .map { .previewUser != $0}
            .bind(to: InteractionLayer.rx.isHidden )
            .disposed(by: disposeBag)
        
        viewModel.flashSettings
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { flashSetting in
                //Flash Shim while working on checkers
                let area = flashSetting.area
                let areas = flashSetting.areas
                print("Setting Flash! Area: \(area) Areas: \(areas)")
                if areas == 2 {
                    if area == 1 {
                        self.topFlash.isHidden = false
                        self.bottomFlash.isHidden = true
                    } else {
                        self.bottomFlash.isHidden = false
                        self.topFlash.isHidden = true
                    }
                } else if areas == 1 {
                    if area == 0 {
                        self.topFlash.isHidden = true
                        self.topFlash.isHidden = true
                    } else {
                        self.topFlash.isHidden = false
                        self.topFlash.isHidden = false
                    }
                }
            }).disposed(by: disposeBag)
        
        viewModel.sampleState
            .filter { $0 == .previewUser }
            .take(1)
            .subscribe(onNext: { _ in
                print("Setting up preview!")
                //Save original screen brightness so we can revert to it later
                self.viewModel.originalScreenBrightness = UIScreen.main.brightness
                UIScreen.main.brightness = CGFloat(1.0)
                
                //Create View Preview Layer
                let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.viewModel.cameraState.captureSession)
                videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
                videoPreviewLayer.frame = self.view.layer.bounds
                
                //Set Video Preview Layer to Root View
                self.rootView.backgroundColor = UIColor.black
                self.InteractionLayer.layer.insertSublayer(videoPreviewLayer, below: self.UILayer.layer)
            }, onError: { error in print(error) } ).disposed(by: disposeBag)
    }
}
