//
//  RootViewModel.swift
//  Tone
//
//  Created by Doug MacEwen on 10/29/18.
//  Copyright © 2018 Doug MacEwen. All rights reserved.
//

import Foundation
import RxSwift

enum NavigationStackAction {
    case set(viewModels: [ViewModel], animated: Bool)
    case push(viewModel: ViewModel, animated: Bool)
    case pop(animated: Bool)
    case swap(viewModel: ViewModel, animated: Bool)
}

class RootNavigationViewModel {
    lazy private(set) var navigationStackActions = BehaviorSubject<NavigationStackAction>(value: .set(viewModels: [createLoginViewModel()], animated: false))
    private var currentViewModelStack: [ViewModel] = []
    private var savedNavigationStack: [ViewModel]? = nil
    private let disposeBag = DisposeBag()
    private var user: User? = nil
    
    init() {
        self.navigationStackActions.subscribe(onNext: { [unowned self] action in
            switch action {
            case .set(let viewModels, _):
                while self.currentViewModelStack.count > 0 {
                    _ = self.currentViewModelStack.popLast()
                }
                viewModels.forEach { viewModel in self.currentViewModelStack.append(viewModel) }
                //self.currentViewModelStack = viewModels
            case .push(let viewModel, _):
                self.currentViewModelStack.append(viewModel)
            case .pop(_):
                _ = self.currentViewModelStack.popLast()
            case .swap(let viewModel, _):
                _ = self.currentViewModelStack.popLast()
                self.currentViewModelStack.append(viewModel)
            }
        }).disposed(by: disposeBag)
    }

    func createLoginViewModel() -> LoginViewModel {
        let loginViewModel = LoginViewModel()
        loginViewModel.events
            .subscribe(onNext: { [weak self] event in
                switch event {
                case .loggedIn(let user):
                    //self?.loadHome(withUser: user)
                    self!.user = user
                    self!.navigationStackActions.onNext(.push(viewModel: self!.createBetaAgreementViewModel(), animated: false))
                }
            }).disposed(by: disposeBag)
        
        return loginViewModel
    }
    
    private func loadHome() {
        print("Launching Tone for user \(self.user!.email)")
        navigationStackActions
            .onNext(.set(viewModels: [self.createHomeViewModel()], animated: false))
    }
    
    private func createHomeViewModel() -> HomeViewModel {
        let homeViewModel = HomeViewModel(user: self.user!)
        homeViewModel.events
            .subscribe(onNext: { [weak self] event in //Reference createLoginViewModel for how to reference Self
                switch event {
                case .logOut:
                    print("Logout")
                    self!.navigationStackActions.onNext(.set(viewModels: [self!.createLoginViewModel()], animated: false))
                case .sampleSkinTone:
                    print("Sample Skin Tone")
                    self!.savedNavigationStack = self!.currentViewModelStack
                    self!.navigationStackActions.onNext(.push(viewModel: self!.createSampleSkinToneViewModel(), animated: false))                    
                case .openSample(let sample):
                    print("Open Sample :: \(sample)")
                case .openSettings:
                    self!.navigationStackActions.onNext(.push(viewModel: self!.createSettingsViewModel(), animated: false))
                case .openNewCaptureSession(let isCancelable):
                    print("Opening New Capture Session Page!")
                    self!.navigationStackActions.onNext(.push(viewModel: self!.createCaptureSessionViewModel(isCancelable: isCancelable), animated: false))
                }
            }).disposed(by: disposeBag)
        //homeViewModel.checkConditions()
        return homeViewModel
    }
    
    private func createSampleSkinToneViewModel() -> SampleSkinToneViewModel {
        let sampleSkinToneViewModel: SampleSkinToneViewModel = SampleSkinToneViewModel(user: self.user!)
        
        sampleSkinToneViewModel.events
            .subscribe(onNext: { [weak self] event in //Reference createLoginViewModel for how to reference Self
                print("EVENTS \(event)")
                switch event {
                case .cancel:
                    print("Cancel")
                    self!.navigationStackActions.onNext(.pop(animated: false))
                case .beginSetUp:
                    print("SETTING VIEW: Setting Up")
                case .beginPreview:
                    print("SETTING VIEW: Previewing")
                    self!.navigationStackActions.onNext(.swap(viewModel: self!.currentViewModelStack.last!, animated: false))
                case .beginFlash:
                    print("SETTING VIEW: Flash")
                    self!.navigationStackActions.onNext(.set(viewModels: [self!.currentViewModelStack.last!], animated: false))
                case .beginProcessing:
                    print("SETTING VIEW: Processing")
                    self!.navigationStackActions.onNext(.set(viewModels: [self!.currentViewModelStack.last!], animated: false))
                case .beginUpload:
                    print("SETTING VIEW: Upload")
                    self!.navigationStackActions.onNext(.set(viewModels: [self!.currentViewModelStack.last!], animated: false))
                case .endSample: //Rename...
                    print("SETTING VIEW: End Sample")
                    self!.navigationStackActions.onNext(.set(viewModels: self!.savedNavigationStack!, animated: false))
                    self!.savedNavigationStack = nil
                    //self!.navigationStackActions.onNext(.push(viewModel: sampleSkinToneViewModel, animated: false))
                }
            }).disposed(by: disposeBag)
        
        return sampleSkinToneViewModel
    }
    
    private func createSettingsViewModel() -> SettingsViewModel {
        let settingsViewModel = SettingsViewModel(user: self.user!)
        settingsViewModel.events
            .subscribe(onNext: { [weak self] event in //Reference createLoginViewModel for how to reference Self
                switch event {
                case .back:
                    self!.navigationStackActions.onNext(.pop(animated: false))
                case .logOut:
                    self!.navigationStackActions.onNext(.set(viewModels: [self!.createLoginViewModel()], animated: false))
                }
            }).disposed(by: disposeBag)
        
        return settingsViewModel
    }
    
    private func createBetaAgreementViewModel() -> BetaAgreementViewModel {
        let betaAgreementViewModel = BetaAgreementViewModel(user: self.user!)
        betaAgreementViewModel.events
            .subscribe(onNext: { [weak self] event in //Reference createLoginViewModel for how to reference Self
                switch event {
                case .agree:
                    print("Loading Home!")
                    self!.loadHome()
                    //q self!.navigationStackActions.onNext(.pop(animated: false))
                case .disagree:
                    print("Exiting!")
                    self!.navigationStackActions.onNext(.pop(animated: false))
                }
            }).disposed(by: disposeBag)
        
        return betaAgreementViewModel
    }
    
    private func createCaptureSessionViewModel(isCancelable: Bool) -> CaptureSessionViewModel {
        let captureSessionViewModel = CaptureSessionViewModel(user: self.user!, isCancelable: isCancelable)
        captureSessionViewModel.events
            .subscribe(onNext: { [weak self] event in //Reference createLoginViewModel for how to reference Self
                switch event {
                case .updated:
                    print("Loading Home!")
                    self!.loadHome()
                //q self!.navigationStackActions.onNext(.pop(animated: false))
                case .cancel:
                    print("Exiting!")
                    self!.navigationStackActions.onNext(.pop(animated: false))
                }
            }).disposed(by: disposeBag)
        
        return captureSessionViewModel
    }
}
