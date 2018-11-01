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
    @IBOutlet weak var UILayer: UIView!

    
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
                self.viewModel.sampleState.onNext(.referenceSample(photoSettings: nil))
            }).disposed(by: disposeBag)
        
        viewModel.sampleState
            .map { if case .previewUser = $0 { return false } else { return true }}
            .bind(to: UILayer.rx.isHidden )
            .disposed(by: disposeBag)
        
        viewModel.sampleState
            .subscribe(onNext: { sampleState in
                switch(sampleState) {
                case .previewUser: do {
                    print("PREVIEW!!!")
                    return
                    }
                case .referenceSample(photoSettings: let photoSettings): do {
                    print("REFERENCE PHOTOS!!!")
                    return
                    }
                case .sample(photoSettings: let photoSettings): do {
                    print("SAMPLE PHOTOS!!!")
                    return
                    }
                case .upload:
                    print("UPLOADS!!!")
                    return
                }
                
            }).disposed(by: disposeBag)
        
    }    
}
