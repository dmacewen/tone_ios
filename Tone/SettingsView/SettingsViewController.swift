//
//  SettingsViewController.swift
//  Tone
//
//  Created by Doug MacEwen on 4/17/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation
import UIKit
import RxSwift
import RxCocoa

class SettingsViewController: UIViewController {
    var viewModel: SettingsViewModel!
    
    @IBOutlet weak var backButton: UIButton!
    
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        
        backButton.rx.tap
            .subscribe(onNext: { _ in self.viewModel.back() })
            .disposed(by: disposeBag)
    }
}
