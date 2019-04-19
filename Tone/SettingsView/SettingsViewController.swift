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
    
    @IBOutlet weak var allLandmarks: UISwitch!
    @IBOutlet weak var exposureLandmarks: UISwitch!
    @IBOutlet weak var balanceLandmarks: UISwitch!
    @IBOutlet weak var brightnessLandmarks: UISwitch!

    
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        
        self.viewModel.settings.showAllLandmarks
            .bind(to: self.allLandmarks.rx.isOn)
            .disposed(by: disposeBag)
        
        self.viewModel.settings.showExposureLandmarks
            .bind(to: self.exposureLandmarks.rx.isOn)
            .disposed(by: disposeBag)
        
        self.viewModel.settings.showBalanceLandmarks
            .bind(to: self.balanceLandmarks.rx.isOn)
            .disposed(by: disposeBag)
        
        self.viewModel.settings.showBrightnessLandmarks
            .bind(to: self.brightnessLandmarks.rx.isOn)
            .disposed(by: disposeBag)
        
        
        self.allLandmarks.rx.isOn
            .bind(to: self.viewModel.settings.showAllLandmarks)
            .disposed(by: disposeBag)
        
        self.exposureLandmarks.rx.isOn
            .bind(to: self.viewModel.settings.showExposureLandmarks)
            .disposed(by: disposeBag)
        
        self.balanceLandmarks.rx.isOn
            .bind(to: self.viewModel.settings.showBalanceLandmarks)
            .disposed(by: disposeBag)
        
        self.brightnessLandmarks.rx.isOn
            .bind(to: self.viewModel.settings.showBrightnessLandmarks)
            .disposed(by: disposeBag)
        
        backButton.rx.tap
            .subscribe(onNext: { _ in self.viewModel.back() })
            .disposed(by: disposeBag)
 
    }
}
