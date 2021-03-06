//
//  Globals.swift
//  Tone
//
//  Created by Doug MacEwen on 10/29/18.
//  Copyright © 2018 Doug MacEwen. All rights reserved.
//

import Foundation
import UIKit

//For any given view model, return the view controller
func viewController(forViewModel viewModel: Any) -> UIViewController? {
    print("Get View Controller Called!")
    switch viewModel {
    case let viewModel as RootNavigationViewModel:
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "rootNavigationViewController") as? RootNavigationViewController
        viewController?.rootViewModel = viewModel
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
        
    case let viewModel as BetaAgreementViewModel:
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "betaAgreementViewController") as? BetaAgreementViewController
        viewController?.viewModel = viewModel
        return viewController
        
    case let viewModel as CaptureSessionViewModel:
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "captureSessionViewController") as? CaptureSessionViewController
        viewController?.viewModel = viewModel
        return viewController
        
    case let viewModel as CaptureSessionHelpViewModel:
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "captureSessionHelpViewController") as? CaptureSessionHelpViewController
        viewController?.viewModel = viewModel
        return viewController
        
    case let viewModel as CaptureSessionMirrorViewModel:
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "captureSessionMirrorViewController") as? CaptureSessionMirrorViewController
        viewController?.viewModel = viewModel
        return viewController
        
    case let viewModel as SampleSkinToneViewModel:
        let viewController: ReactiveUIViewController?
        print("VIEW MODEL STATE VALUE :: \(try! viewModel.events.value())")

        //Do not love having to reach into the view model. Is there a better way?
        switch try! viewModel.events.value() {
        case .cancel:
            viewController = nil
        case .beginSetUp:
            viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "setupViewController") as? SetupViewController
        case .beginPreview:
            viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "previewViewController") as? PreviewViewController
        case .beginFlash:
            viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "flashViewController") as? FlashViewController
        case .beginProcessing:
            viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "processViewController") as? ProcessViewController
        case .beginUpload:
            viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "uploadViewController") as? UploadViewController
        case .doneSample:
            print("Should not reach this.")
            viewController = nil
        case .showHelp:
            print("Should not reach this.")
            viewController = nil
        }

        viewController?.viewModel = viewModel
        return viewController
        
    case let viewModel as SampleSkinToneHelpViewModel:
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "sampleSkinToneHelpViewController") as? SampleSkinToneHelpViewController
        viewController?.viewModel = viewModel
        return viewController
        
    case let viewModel as DoneSampleSkinToneViewModel:
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "doneSampleSkinToneViewController") as? DoneSampleSkinToneViewController
        viewController?.viewModel = viewModel
        return viewController

    default:
        return nil
    }
}
