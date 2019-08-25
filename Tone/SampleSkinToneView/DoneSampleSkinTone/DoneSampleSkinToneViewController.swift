//
//  DoneSampleSkinToneViewController.swift
//  Tone
//
//  Created by Doug MacEwen on 8/24/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation
import UIKit
import RxSwift
import RxCocoa

class DoneSampleSkinToneViewController: UIViewController {
    weak var viewModel: DoneSampleSkinToneViewModel!
    
    @IBOutlet weak var okButton: UIButton!
    
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "DoneSampleSkinTone"
        
        okButton.rx.tap
            .subscribe(onNext: { _ in self.viewModel.ok() })
            .disposed(by: disposeBag)
    }
}
