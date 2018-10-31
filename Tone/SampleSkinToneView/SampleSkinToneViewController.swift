//
//  SampleSkinToneViewController.swift
//  Tone
//
//  Created by Doug MacEwen on 10/30/18.
//  Copyright © 2018 Doug MacEwen. All rights reserved.
//

import Foundation
import UIKit
import RxSwift
import RxCocoa

class SampleSkinToneViewController: UIViewController {
    var viewModel: SampleSkinToneViewModel!
    
    @IBOutlet weak var cancelButton: UIButton!
    
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Sample Skin Tone"
        
        cancelButton.rx.tap
            .single()
            .subscribe(onNext: { _ in self.viewModel.cancel() })
            .disposed(by: disposeBag)
    }
}
