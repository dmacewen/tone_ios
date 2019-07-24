//
//  CaptureSessionViewController.swift
//  Tone
//
//  Created by Doug MacEwen on 7/23/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation
import UIKit
import RxSwift
import RxCocoa

class CaptureSessionViewController: UIViewController {
    weak var viewModel: CaptureSessionViewModel!
    
    @IBOutlet weak var updateButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var skinColorId: UITextField!
    
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "CaptureSession"
        
        skinColorId.rx.text
            .map { textOptional -> Int32? in
                guard let text = textOptional else { return nil }
                return Int32(text)
            }
            .bind(to: viewModel.skinColorIdOptional)
            .disposed(by: disposeBag)
        
        updateButton.rx.tap
            .subscribe(onNext: { _ in self.viewModel.updateSkinColorId() })
            .disposed(by: disposeBag)
        
        cancelButton.rx.tap
            .subscribe(onNext: { _ in self.viewModel.cancel() })
            .disposed(by: disposeBag)
        
    }
}
