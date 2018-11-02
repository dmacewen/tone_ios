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

        viewModel.userFaceState.asObserver()
            .map { $0.message }
            .bind(to: userPrompt.rx.text)
            .disposed(by: disposeBag)
        
        viewModel.userFaceState//.asObserver()
            .map { $0 == .ok }
            .bind(to: takeSampleButton.rx.isEnabled)
            .disposed(by: disposeBag)
        
        takeSampleButton.rx.tap
            .subscribe({ _ in
                self.viewModel.sampleState.onNext(.referenceSample)
            }).disposed(by: disposeBag)
        
        viewModel.sampleState
            .map { if case .previewUser = $0 { return false } else { return true }}
            .bind(to: UILayer.rx.isHidden )
            .disposed(by: disposeBag)
        
        viewModel.flashSettings
            .subscribe(onNext: { flashSetting in
                //Flash Shim while working on checkers
                let area = flashSetting.area
                let areas = flashSetting.areas
                
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
            .do { self.setupPreview(cameraState: self.viewModel.cameraState) }
            .flatMap { _ in self.viewModel.cameraState.preparePhotoSettings(numPhotos: 4) }
            .subscribe { print("Preview Processed!") }
            .disposed(by: disposeBag)

        
        viewModel.sampleState
            .subscribe(onNext: { sampleState in
                switch(sampleState) {
                case .previewUser:
                    self.setupPreview(cameraState: self.viewModel.cameraState)

                    print("PREVIEW!!!")
                    return
                    
                case .referenceSample:
                    print("REFERENCE PHOTOS!!!")
                    return
                
                case .sample:
                    print("SAMPLE PHOTOS!!!")
                    return
                
                case .upload:
                    print("UPLOADS!!!")
                    return
                }
                
            }).disposed(by: disposeBag)
        
    }
    
    func setupPreview(cameraState: CameraState) {
        //Save original screen brightness so we can revert to it later
        viewModel.originalScreenBrightness = UIScreen.main.brightness
        UIScreen.main.brightness = CGFloat(1.0)

        //Create View Preview Layer
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: cameraState.captureSession)
        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer.frame = view.layer.bounds
        
        //Set Video Preview Layer to Root View
        rootView.backgroundColor = UIColor.black
        rootView.layer.insertSublayer(videoPreviewLayer, below: UILayer.layer)
    }
}
