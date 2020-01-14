//
//  CaptureSessionMirrorViewController.swift
//  Tone
//
//  Created by Doug MacEwen on 8/26/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit
import RxSwift
import RxCocoa

class CaptureSessionMirrorViewController: UIViewController {
    let disposeBag = DisposeBag()
    weak var viewModel: CaptureSessionMirrorViewModel!

    @IBOutlet weak var rootView: UIView!
    @IBOutlet weak var UILayer: UIView!
    @IBOutlet weak var InteractionLayer: UIView!
    
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var helpButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Preview Sample Skin Tone"
        
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.viewModel!.cameraState.captureSession)
        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer.frame = self.view.layer.bounds
        self.viewModel!.videoSize = videoPreviewLayer.bounds.size
        self.InteractionLayer.layer.insertSublayer(videoPreviewLayer, below: self.UILayer.layer)
        
        self.cancelButton.rx.tap
            .single()
            .subscribe(onNext: { [unowned self] _ in self.viewModel!.cancel() })
            .disposed(by: self.disposeBag)
        
        self.doneButton.rx.tap
            .single()
            .subscribe(onNext: { [unowned self] _ in self.viewModel!.done() })
            .disposed(by: self.disposeBag)
        
        self.helpButton.rx.tap
            .subscribe(onNext: { [unowned self] _ in self.viewModel!.showHelp() })
            .disposed(by: self.disposeBag)
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
