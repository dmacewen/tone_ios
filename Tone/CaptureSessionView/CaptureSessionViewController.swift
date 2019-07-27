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
    @IBOutlet weak var backgroundView: UIView!
    
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "CaptureSession"
        
        //Dont show the cancel button if the user has to update their session...
        cancelButton.isHidden = !viewModel.isCancelable
        
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
