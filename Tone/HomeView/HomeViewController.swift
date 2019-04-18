//
//  HomeViewController.swift
//  Tone
//
//  Created by Doug MacEwen on 10/30/18.
//  Copyright © 2018 Doug MacEwen. All rights reserved.
//

import Foundation
import UIKit
import RxSwift
import RxCocoa

class HomeViewController: UIViewController {
    var viewModel: HomeViewModel!
    
    @IBOutlet weak var logoutButton: UIButton!
    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var sampleSkinToneButton: UIButton!
    
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Home"
        
        sampleSkinToneButton.rx.tap
            //.single()
            .subscribe(onNext: { _ in self.viewModel.sampleSkinTone() })
            .disposed(by: disposeBag)
        
        logoutButton.rx.tap
            .single()
            .subscribe(onNext: { _ in self.viewModel.logout() })
            .disposed(by: disposeBag)
        
        settingsButton.rx.tap
            //.single()
            .subscribe(onNext: { _ in self.viewModel.openSettings() })
            .disposed(by: disposeBag)
    }
}
