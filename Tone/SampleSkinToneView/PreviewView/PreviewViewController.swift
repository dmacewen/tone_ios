//
//  PreviewViewController.swift
//  Tone
//
//  Created by Doug MacEwen on 4/22/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit
import RxSwift
import RxCocoa

class PreviewViewController: ReactiveUIViewController<SampleSkinToneViewModel> {
    let disposeBag = DisposeBag()
    
    @IBOutlet weak var rootView: UIView!
    @IBOutlet weak var UILayer: UIView!
    @IBOutlet weak var InteractionLayer: UIView!
    @IBOutlet weak var OverlayLayer: UIImageView!
    
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var takeSampleButton: UIButton!
    
    @IBOutlet weak var userPrompt: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Preview Sample Skin Tone"
        
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.viewModel!.cameraState.captureSession)
        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer.frame = self.view.layer.bounds
        self.viewModel!.videoSize = videoPreviewLayer.bounds.size
        
        DispatchQueue.main.async {
            self.InteractionLayer.layer.insertSublayer(videoPreviewLayer, below: self.UILayer.layer)
            self.viewModel!.videoPreviewLayerStream.onNext(videoPreviewLayer)
        }
        
        //Provide Access to video preview layer for converting between coordinate systems.... there might be a better way?
        
        self.cancelButton.rx.tap
            .single()
            .subscribe(onNext: { _ in self.viewModel!.cancel() })
            .disposed(by: self.disposeBag)
        

        self.takeSampleButton.rx.tap
            .subscribe(onNext: { _ in
                self.viewModel!.takeSample()
            }).disposed(by: self.disposeBag)
        
        self.viewModel!.userFaceState
            .asDriver(onErrorJustReturn: .noFaceFound)
            .distinctUntilChanged()
            .throttle(0.5)
            .drive(onNext:{ faceState in
                DispatchQueue.main.async {
                    self.userPrompt.text = faceState.prompt.message
                }
                //self.userTip.text = $0.prompt.tip
            })
            .disposed(by: self.disposeBag)
        
        self.viewModel!.userFaceState
            .map { $0 == .ok }
            .bind(to: self.takeSampleButton.rx.isEnabled)
            .disposed(by: self.disposeBag)
        
        viewModel!.drawPointsStream
            .subscribe(onNext: { points in
                let size = 5
                let halfSize = 2 //floor size/2
                
                let img = self.viewModel!.renderer.image { ctx in
                    for point in points {
                        ctx.cgContext.setFillColor(point.color)
                        ctx.cgContext.fill(CGRect(x: Int(point.x) - halfSize, y: Int(point.y) - halfSize, width: size, height: size))
                    }
                }
                
                DispatchQueue.main.async {
                    self.OverlayLayer.image = img
                }
            }).disposed(by: disposeBag)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.async {
            self.viewModel!.video.resumeProcessing()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        DispatchQueue.main.async {
            self.viewModel!.video.pauseProcessing()
        }
    }
}
