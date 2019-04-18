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
}

class RootNavigationViewModel {
    lazy private(set) var navigationStackActions = BehaviorSubject<NavigationStackAction>(value: .set(viewModels: [self.createLoginViewModel()], animated: false))

    private let disposeBag = DisposeBag()
    
    func createLoginViewModel() -> LoginViewModel {
        let loginViewModel = LoginViewModel()
        loginViewModel.events
            .subscribe(onNext: { [weak self] event in
                switch event {
                case .loggedIn(let user):
                    self?.loadHome(withUser: user)
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
                    self!.navigationStackActions.onNext(.push(viewModel: self!.createSampleSkinToneViewModel(withUser: user), animated: false))
                case .openSample(let sample):
                    print("Open Sample :: \(sample)")
                case .openSettings:
                    self!.navigationStackActions.onNext(.push(viewModel: self!.createSettingsViewModel(withSettings: Settings()), animated: false))

                }
            }).disposed(by: disposeBag)
        
        return homeViewModel
    }
    
    private func createSampleSkinToneViewModel(withUser user: User) -> SampleSkinToneViewModel {
        let sampleSkinToneViewModel = SampleSkinToneViewModel(user: user)
        sampleSkinToneViewModel.events
            .subscribe(onNext: { [weak self] event in //Reference createLoginViewModel for how to reference Self
                switch event {
                case .cancel:
                    print("Cancel")
                    self!.navigationStackActions.onNext(.pop(animated: false))
                }
            }).disposed(by: disposeBag)
        
        return sampleSkinToneViewModel
    }
    
    private func createSettingsViewModel(withSettings settings: Settings) -> SettingsViewModel {
        let settingsViewModel = SettingsViewModel(settings: settings)
        settingsViewModel.events
            .subscribe(onNext: { [weak self] event in //Reference createLoginViewModel for how to reference Self
                switch event {
                case .back:
                    self!.navigationStackActions.onNext(.pop(animated: false))
                }
            }).disposed(by: disposeBag)
        
        return settingsViewModel
    }
}
