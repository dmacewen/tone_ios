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

    default:
        return nil
    }
}
