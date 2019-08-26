//
//  CaptureSessionHelpViewController.swift
//  Tone
//
//  Created by Doug MacEwen on 8/22/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation
import UIKit
import RxSwift
import RxCocoa

class CaptureSessionHelpViewController: UIViewController {
    weak var viewModel: CaptureSessionHelpViewModel!
    
    @IBOutlet weak var okButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "CaptureSessionHelp"
        
        okButton.rx.tap
            .subscribe(onNext: { [unowned self] _ in self.viewModel.ok() })
            .disposed(by: disposeBag)
        
        cancelButton.rx.tap
            .subscribe(onNext: { [unowned self] _ in self.viewModel.cancel() })
            .disposed(by: disposeBag)
        
    }
}
