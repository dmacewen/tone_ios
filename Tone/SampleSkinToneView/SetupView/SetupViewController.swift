//
//  SetupViewController.swift
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

class SetupViewController: ReactiveUIViewController<SampleSkinToneViewModel> {
    //var viewModel: SampleSkinToneViewModel!
    let disposeBag = DisposeBag()
    
    //@IBOutlet weak var PreppingLayer: UIView!
    @IBOutlet weak var setupSpinner: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Setup Sample Skin Tone"
        setupSpinner.startAnimating()
    }
}
