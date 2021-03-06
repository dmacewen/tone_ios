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
    case gesturePop(animated: Bool)
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
            print("Got Navigation Action!")
            switch action {
            case .set(let viewModels, _):
                while self.currentViewModelStack.count > 0 {
                    _ = self.currentViewModelStack.popLast()
                }
                viewModels.forEach { viewModel in self.currentViewModelStack.append(viewModel) }
            case .push(let viewModel, _):
                self.currentViewModelStack.append(viewModel)
            case .pop(_), .gesturePop(_):
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
                    self!.navigationStackActions.onNext(.push(viewModel: self!.createSampleSkinToneHelpViewModel(isCancelable: false, isBeforeSampleSkinTone: true), animated: false))
                case .openSample(let sample):
                    print("Open Sample :: \(sample)")
                case .openSettings:
                    self!.navigationStackActions.onNext(.push(viewModel: self!.createSettingsViewModel(), animated: false))
                case .openNewCaptureSession(let isCancelable):
                    print("Opening New Capture Session Page!")
                    self!.navigationStackActions.onNext(.push(viewModel: self!.createCaptureSessionViewModel(isCancelable: isCancelable), animated: false))
                }
            }).disposed(by: disposeBag)
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
                    self!.savedNavigationStack = nil
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
                case .showHelp:
                    print("SETTING VIEW: Showing Sample Skin tone Help")
                    self!.navigationStackActions.onNext(.push(viewModel: self!.createSampleSkinToneHelpViewModel(isCancelable: true), animated: false))
                case .doneSample:
                    print("SETTING VIEW: Done Sample")
                    self!.navigationStackActions.onNext(.set(viewModels: [self!.createDoneSampleSkinToneViewModel()], animated: false))
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
        betaAgreementViewModel.isCancelable = false
        
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
                case .showHelp:
                    self!.navigationStackActions.onNext(.push(viewModel: self!.createCaptureSessionHelpViewModel(), animated: false))
                case .cancel:
                    print("Exiting!")
                    self!.navigationStackActions.onNext(.pop(animated: false))
                case .mirror:
                    self!.navigationStackActions.onNext(.push(viewModel: self!.createCaptureSessionMirrorViewModel(), animated: false))
                }
            }).disposed(by: disposeBag)
        
        return captureSessionViewModel
    }
    
    private func createCaptureSessionHelpViewModel() -> CaptureSessionHelpViewModel {
        let captureSessionHelpViewModel = CaptureSessionHelpViewModel(user: self.user!)
        
        captureSessionHelpViewModel.events
            .subscribe(onNext: { [weak self] event in
                switch event {
                case .cancel:
                    self!.navigationStackActions.onNext(.pop(animated: false))
                case .ok:
                    self!.navigationStackActions.onNext(.pop(animated: false))
                }
            }).disposed(by: disposeBag)
        
        return captureSessionHelpViewModel
    }
    
    private func createCaptureSessionMirrorViewModel() -> CaptureSessionMirrorViewModel {
        let captureSessionMirrorViewModel = CaptureSessionMirrorViewModel()
        
        captureSessionMirrorViewModel.events
            .subscribe(onNext: { [weak self] event in
                switch event {
                case .cancel:
                    self!.navigationStackActions.onNext(.pop(animated: false))
                case .done:
                    self!.navigationStackActions.onNext(.pop(animated: false))
                case .showHelp:
                    self!.navigationStackActions.onNext(.push(viewModel: self!.createCaptureSessionHelpViewModel(), animated: false))
                }
            }).disposed(by: disposeBag)
        
        return captureSessionMirrorViewModel
    }
    
    private func createSampleSkinToneHelpViewModel(isCancelable: Bool, isBeforeSampleSkinTone: Bool = false) -> SampleSkinToneHelpViewModel {
        let sampleSkinToneHelpViewModel = SampleSkinToneHelpViewModel(user: self.user!, isCancelable: isCancelable)
        
        if isBeforeSampleSkinTone {
            sampleSkinToneHelpViewModel.events
                .subscribe(onNext: { [weak self] event in
                    switch event {
                    default:
                        print("Cancel or OK")
                        print("Sample Skin Tone")
                        self!.savedNavigationStack = self!.currentViewModelStack
                        _ = self!.savedNavigationStack?.popLast()
                        self!.navigationStackActions.onNext(.swap(viewModel: self!.createSampleSkinToneViewModel(), animated: false))
                    }
                }).disposed(by: disposeBag)
        } else {
            sampleSkinToneHelpViewModel.events
                .subscribe(onNext: { [weak self] event in
                    switch event {
                    case .cancel:
                        print("Cancel!")
                        self!.navigationStackActions.onNext(.pop(animated: false))
                    case .ok:
                        print("OK!")
                        self!.navigationStackActions.onNext(.pop(animated: false))
                    }
                }).disposed(by: disposeBag)
        }
        
        return sampleSkinToneHelpViewModel
    }
    
    private func createDoneSampleSkinToneViewModel() -> DoneSampleSkinToneViewModel {
        let doneSampleSkinToneViewModel = DoneSampleSkinToneViewModel()
        
        doneSampleSkinToneViewModel.events
            .subscribe(onNext: { [weak self] event in
                switch event {
                case .ok:
                    print("OK!")
                    self!.navigationStackActions.onNext(.set(viewModels: self!.savedNavigationStack!, animated: false))
                    self!.savedNavigationStack = nil
                }
            }).disposed(by: disposeBag)
        
        return doneSampleSkinToneViewModel
    }
}
