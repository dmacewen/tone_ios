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
            .map { .previewUser != $0}
            .bind(to: InteractionLayer.rx.isHidden )
            .disposed(by: disposeBag)
        
        viewModel.flashSettings
            .observeOn(MainScheduler.instance)
            .distinctUntilChanged({ (A, B) -> Bool in
                return (A.areas == B.areas && A.area == B.area)
            })
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
            .do(onNext: {_ in self.setupPreview(camera: self.viewModel.camera) })
            .subscribe { _ in print("Preview Processed!") }
            .disposed(by: disposeBag)
        
        viewModel.sampleState
            .filter { $0 == .referenceSample }
            .subscribe { _ in
                print("Taking Reference Sample!")
                self.viewModel.sampleState.onNext(.sample)
            }
            .disposed(by: disposeBag)
        
        viewModel.sampleState
            .filter { $0 == .sample }
            .do(onNext: { _ in print("CAPTURING SAMPLE") } )
            //.do { self.setupPreview(cameraState: self.viewModel.cameraState) }
            .flatMap { _ in self.viewModel.camera.preparePhotoSettings(numPhotos: 4).asObservable() }
            .flatMap { _ in self.viewModel.camera.capturePhoto(flashSettings: FlashSettings(area: 1, areas: 1)).asObserver() }
            .flatMap { _ in self.viewModel.camera.capturePhoto(flashSettings: FlashSettings(area: 1, areas: 2)).asObserver() }
            .flatMap { _ in self.viewModel.camera.capturePhoto(flashSettings: FlashSettings(area: 2, areas: 2)).asObserver() }
            .flatMap { _ in self.viewModel.camera.capturePhoto(flashSettings: FlashSettings(area: 0, areas: 1)).asObserver() }
            .subscribe { _ in
                print("Taking Samples!")
                self.viewModel.sampleState.onNext(.upload)
            }
            .disposed(by: disposeBag)
        
        viewModel.sampleState
            .filter { $0 == .upload }
            .subscribe { _ in
                print("Uploading Images!")
                self.viewModel.sampleState.onNext(.previewUser)
            }
            .disposed(by: disposeBag)
        
    }
    
    func setupPreview(camera: Camera) {
        print("Setting up preview!")
        //Save original screen brightness so we can revert to it later
        viewModel.originalScreenBrightness = UIScreen.main.brightness
        UIScreen.main.brightness = CGFloat(1.0)

        //Create View Preview Layer
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: camera.captureSession)
        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer.frame = view.layer.bounds
        
        //Set Video Preview Layer to Root View
        rootView.backgroundColor = UIColor.black
        //rootView.layer.insertSublayer(videoPreviewLayer, below: UILayer.layer)
        //UILayer.layer.insertSublayer(videoPreviewLayer, below: UILayer.layer)
        InteractionLayer.layer.insertSublayer(videoPreviewLayer, below: UILayer.layer)
    }
}
