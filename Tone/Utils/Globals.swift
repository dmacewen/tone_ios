//
//  Globals.swift
//  Tone
//
//  Created by Doug MacEwen on 10/29/18.
//  Copyright © 2018 Doug MacEwen. All rights reserved.
//

import Foundation
import UIKit

func viewController(forViewModel viewModel: Any) -> UIViewController? {
    switch viewModel {
    case let viewModel as RootNavigationViewModel:
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "rootNavigationViewController") as? RootNavigationViewController
        viewController?.viewModel = viewModel
        return viewController
        
    case let viewModel as LoginViewModel:
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "loginViewController") as? LoginViewController
        viewController?.viewModel = viewModel
        return viewController
        
    case let viewModel as HomeViewModel:
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "homeViewController") as? HomeViewController
        viewController?.viewModel = viewModel
        return viewController
        
    case let viewModel as SettingsViewModel:
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "settingsViewController") as? SettingsViewController
        viewController?.viewModel = viewModel
        return viewController
        
    case let viewModel as SampleSkinToneViewModel:
        let viewController: ReactiveUIViewController<SampleSkinToneViewModel>?
        print("VIEW MODEL STATE VALUE :: \(try! viewModel.sampleState.value())")
        switch try! viewModel.sampleState.value() {
        case .setup:
            viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "setupViewController") as? SetupViewController
        case .previewUser:
            viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "previewViewController") as? PreviewViewController
        case .flash:
            viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "flashViewController") as? FlashViewController
        case .process:
            viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "processViewController") as? ProcessViewController
        case .upload:
            viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "uploadViewController") as? UploadViewController
        }
        //let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "sampleSkinToneViewController") as? SampleSkinToneViewController
        viewController?.viewModel = viewModel
        return viewController

    default:
        return nil
    }
}
