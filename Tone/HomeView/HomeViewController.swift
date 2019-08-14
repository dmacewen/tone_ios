//
//  HomeViewController.swift
//  Tone
//
//  Created by Doug MacEwen on 10/30/18.
//  Copyright © 2018 Doug MacEwen. All rights reserved.
//

import Foundation
import UIKit
import RxSwift
import RxCocoa

class HomeViewController: UIViewController {
    weak var viewModel: HomeViewModel!
    
    @IBOutlet weak var logoutButton: UIButton!
    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var sampleSkinToneButton: UIButton!
    @IBOutlet weak var updateCaptureSession: UIButton!
    @IBOutlet weak var currentCaptureSession: UITextField!

    
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Home"
        
        if let captureSession = self.viewModel.user.captureSession {
            currentCaptureSession.text = String(captureSession.skin_color_id)
        }
        
        sampleSkinToneButton.rx.tap
            //.single()
            .subscribe(onNext: { _ in self.viewModel.sampleSkinTone() })
            .disposed(by: disposeBag)
        
        logoutButton.rx.tap
            .single()
            .subscribe(onNext: { _ in self.viewModel.logout() })
            .disposed(by: disposeBag)
        
        settingsButton.rx.tap
            //.single()
            .subscribe(onNext: { _ in self.viewModel.openSettings() })
            .disposed(by: disposeBag)
        
        updateCaptureSession.rx.tap
            //.single()
            .subscribe(onNext: { _ in self.viewModel.updateCaptureSession() })
            .disposed(by: disposeBag)
    }
}
