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
    @IBOutlet weak var takeSampleButton: UIButton!
    
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
        
        viewModel.userFaceState.asObserver()
            .map { $0 == .ok }
            .bind(to: takeSampleButton.rx.isEnabled)
            .disposed(by: disposeBag)
        
        takeSampleButton.rx.tap
            .subscribe(onNext: { _ in
                self.viewModel.sample()
            }).disposed(by: disposeBag)
    }
}
