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

class PreviewViewController: ReactiveUIViewController {
    let disposeBag = DisposeBag()
    
    @IBOutlet weak var rootView: UIView!
    @IBOutlet weak var UILayer: UIView!
    @IBOutlet weak var InteractionLayer: UIView!
    @IBOutlet weak var OverlayLayer: UIImageView!
    
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var helpButton: UIButton!
    @IBOutlet weak var takeSampleButton: UIButton!
    
    @IBOutlet weak var userPrompt: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Preview Sample Skin Tone"
        
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.viewModel!.cameraState.captureSession)
        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer.frame = self.view.layer.bounds
        self.viewModel!.videoSize = videoPreviewLayer.bounds.size
        self.viewModel!.videoPreviewLayerStream.onNext(videoPreviewLayer)
        self.InteractionLayer.layer.insertSublayer(videoPreviewLayer, below: self.UILayer.layer)
        
        //Provide Access to video preview layer for converting between coordinate systems.... there might be a better way?
        self.cancelButton.rx.tap
            .single()
            .subscribe(onNext: { [unowned self] _ in self.viewModel!.cancel() })
            .disposed(by: self.disposeBag)
        
        self.helpButton.rx.tap
            .subscribe(onNext: { [unowned self] _ in self.viewModel!.showHelp() })
            .disposed(by: self.disposeBag)
    
        self.takeSampleButton.rx.tap
            .subscribe(onNext: { [unowned self] _ in self.viewModel!.takeSample() })
            .disposed(by: self.disposeBag)
        
        self.viewModel!.userFaceState
            .asDriver(onErrorJustReturn: .noFaceFound)
            .distinctUntilChanged()
            .throttle(DispatchTimeInterval.milliseconds(500))
            .drive(onNext:{ [unowned self] faceState in
                    self.userPrompt.text = faceState.prompt.message
            })
            .disposed(by: self.disposeBag)

        self.viewModel!.userFaceState
            .map { $0 == .ok }
            .bind(to: self.takeSampleButton.rx.isEnabled)
            .disposed(by: disposeBag)

        DispatchQueue.global(qos: .userInteractive).async {
            self.viewModel!.drawPointsStream
                .subscribe(onNext: { [weak self] points in
                    let size = 5
                    let halfSize = 2 //floor size/2
                    
                    let img = self?.viewModel!.videoOverlayRenderer.image { ctx in
                        for point in points {
                            ctx.cgContext.setFillColor(point.color)
                            ctx.cgContext.fill(CGRect(x: Int(point.x) - halfSize, y: Int(point.y) - halfSize, width: size, height: size))
                        }
                    }
                    DispatchQueue.main.async {
                        if let localSelf = self {
                            localSelf.OverlayLayer.image = img
                        }
                    }
                }).disposed(by: self.disposeBag)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.viewModel!.video.resumeProcessing()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if let viewModel = self.viewModel {
            viewModel.video.pauseProcessing()
        }
    }
}
