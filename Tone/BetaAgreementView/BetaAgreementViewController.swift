//
//  BetaAgreementViewController.swift
//  Tone
//
//  Created by Doug MacEwen on 7/22/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation
import UIKit
import RxSwift
import RxCocoa

class BetaAgreementViewController: UIViewController {
    weak var viewModel: BetaAgreementViewModel!
    
    @IBOutlet weak var agreeButton: UIButton!
    @IBOutlet weak var disagreeButton: UIButton!
    
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "BetaAgreement"
        
        agreeButton.rx.tap
            .subscribe(onNext: { [weak self] _ in self!.viewModel.agree(true) })
            .disposed(by: disposeBag)
        
        disagreeButton.rx.tap
            .subscribe(onNext: { [weak self] _ in self!.viewModel.agree(false) })
            .disposed(by: disposeBag)
        
    }
}
