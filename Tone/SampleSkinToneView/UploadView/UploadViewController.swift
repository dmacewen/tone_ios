//
//  UploadViewController.swift
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

class UploadViewController: ReactiveUIViewController<SampleSkinToneViewModel> {
    //var viewModel: SampleSkinToneViewModel!
    let disposeBag = DisposeBag()
    
//    @IBOutlet weak var UploadProgessLayer: UIView! //Layer that holds Upload Progress Bar, Progress Spinner, and Prepping Spinner
//    @IBOutlet weak var UploadLayer: UIView!
    @IBOutlet weak var UploadBar: UIProgressView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Setup Sample Skin Tone"
        
        viewModel!.uploadProgress
            .bind(to: UploadBar.rx.progress)
            .disposed(by: disposeBag)
    }
}
