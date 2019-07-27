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
    case set(viewModels: [Any], animated: Bool)
    case push(viewModel: Any, animated: Bool)
    case pop(animated: Bool)
    case swap(viewModel: Any, animated: Bool)
}

class RootNavigationViewModel {
    lazy private(set) var navigationStackActions = BehaviorSubject<NavigationStackAction>(value: .set(viewModels: [self.createLoginViewModel()], animated: false))
    private var currentViewModelStack: [Any] = []
    private let disposeBag = DisposeBag()
    
    init() {
        self.navigationStackActions.subscribe(onNext: { action in
            switch action {
            case .set(let viewModels, _):
                self.currentViewModelStack = viewModels
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
                    self!.navigationStackActions.onNext(.push(viewModel: self!.createBetaAgreementViewModel(withUser: user), animated: false))
                }
            }).disposed(by: disposeBag)
        
        return loginViewModel
    }
    
    private func loadHome(withUser user: User) {
        print("Launching Tone for user \(user.email)")
        navigationStackActions.onNext(.set(viewModels: [self.createHomeViewModel(withUser: user)], animated: false))
    }
    
    private func createHomeViewModel(withUser user: User) -> HomeViewModel {
        let homeViewModel = HomeViewModel(user: user)
        homeViewModel.events
            .subscribe(onNext: { [weak self] event in //Reference createLoginViewModel for how to reference Self
                switch event {
                case .logOut:
                    print("Logout")
                    self!.navigationStackActions.onNext(.set(viewModels: [self!.createLoginViewModel()], animated: false))
                case .sampleSkinTone:
                    print("Sample Skin Tone")
                    self!.createSampleSkinToneViewModel(withUser: user) //Temporary... Fix! it sets its own controller
                    //self!.navigationStackActions.onNext(.push(viewModel: self!.createSampleSkinToneViewModel(withUser: user), animated: false))
                case .openSample(let sample):
                    print("Open Sample :: \(sample)")
                case .openSettings:
                    self!.navigationStackActions.onNext(.push(viewModel: self!.createSettingsViewModel(withUser: user), animated: false))
                case .openNewCaptureSession(let isCancelable):
                    print("Opening New Capture Session Page!")
                    self!.navigationStackActions.onNext(.push(viewModel: self!.createCaptureSessionViewModel(withUser: user, isCancelable: isCancelable), animated: false))
                }
            }).disposed(by: disposeBag)
        
        return homeViewModel
    }
    
    private func createSampleSkinToneViewModel(withUser user: User) { //} -> SampleSkinToneViewModel {
        var sampleSkinToneViewModel: SampleSkinToneViewModel? = SampleSkinToneViewModel(user: user)
        
        var isStillSampleSkinTone = true
        var savedNavigationStack: [Any]? = []
        
        sampleSkinToneViewModel!.events
            .takeWhile { _ in isStillSampleSkinTone }
            .subscribe(onNext: { [weak self] event in //Reference createLoginViewModel for how to reference Self
                print("EVENTS \(event)")
                switch event {
                case .cancel:
                    print("Cancel")
                    self!.navigationStackActions.onNext(.pop(animated: false))
                case .beginSetUp:
                    print("SETTING VIEW: Setting Up")
                    savedNavigationStack = self!.currentViewModelStack
                    self!.navigationStackActions.onNext(.push(viewModel: sampleSkinToneViewModel!, animated: false))
                case .beginPreview:
                    print("SETTING VIEW: Previewing")
                    self!.navigationStackActions.onNext(.swap(viewModel: sampleSkinToneViewModel!, animated: false))
                case .beginFlash:
                    print("SETTING VIEW: Flash")
                    self!.navigationStackActions.onNext(.set(viewModels: [sampleSkinToneViewModel!], animated: false))
                case .beginProcessing:
                    print("SETTING VIEW: Processing")
                    self!.navigationStackActions.onNext(.set(viewModels: [sampleSkinToneViewModel!], animated: false))
                case .beginUpload:
                    print("SETTING VIEW: Upload")
                    self!.navigationStackActions.onNext(.set(viewModels: [sampleSkinToneViewModel!], animated: false))
                case .endSample: //Rename...
                    print("SETTING VIEW: End Sample")
                    self!.navigationStackActions.onNext(.set(viewModels: savedNavigationStack!, animated: false))
                    isStillSampleSkinTone = false
                    sampleSkinToneViewModel = nil
                    savedNavigationStack = nil
                    //self!.navigationStackActions.onNext(.push(viewModel: sampleSkinToneViewModel, animated: false))
                }
            }).disposed(by: disposeBag)
        
        //return sampleSkinToneViewModel
    }
    
    private func createSettingsViewModel(withUser user: User) -> SettingsViewModel {
        let settingsViewModel = SettingsViewModel(user: user)
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
    
    private func createBetaAgreementViewModel(withUser user: User) -> BetaAgreementViewModel {
        let betaAgreementViewModel = BetaAgreementViewModel(user: user)
        betaAgreementViewModel.events
            .subscribe(onNext: { [weak self] event in //Reference createLoginViewModel for how to reference Self
                switch event {
                case .agree:
                    print("Loading Home!")
                    self!.loadHome(withUser: user)
                    //q self!.navigationStackActions.onNext(.pop(animated: false))
                case .disagree:
                    print("Exiting!")
                    self!.navigationStackActions.onNext(.pop(animated: false))
                }
            }).disposed(by: disposeBag)
        
        return betaAgreementViewModel
    }
    
    private func createCaptureSessionViewModel(withUser user: User, isCancelable: Bool) -> CaptureSessionViewModel {
        let captureSessionViewModel = CaptureSessionViewModel(user: user, isCancelable: isCancelable)
        captureSessionViewModel.events
            .subscribe(onNext: { [weak self] event in //Reference createLoginViewModel for how to reference Self
                switch event {
                case .updated:
                    print("Loading Home!")
                    self!.loadHome(withUser: user)
                //q self!.navigationStackActions.onNext(.pop(animated: false))
                case .cancel:
                    print("Exiting!")
                    self!.navigationStackActions.onNext(.pop(animated: false))
                }
            }).disposed(by: disposeBag)
        
        return captureSessionViewModel
    }
}
