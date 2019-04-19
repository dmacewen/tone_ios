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
        //return UINavigationController(rootViewController: viewController!)
        return viewController
        
    case let viewModel as SampleSkinToneViewModel:
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "sampleSkinToneViewController") as? SampleSkinToneViewController
        viewController?.viewModel = viewModel
        return viewController

    default:
        return nil
    }
}
