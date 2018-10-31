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
                case .loggedIn(let email):
                    self?.loadHome(withEmail: email)
                }
            }).disposed(by: disposeBag)
        
        return loginViewModel
    }
    
    private func loadHome(withEmail email: String) {
        print("Launching Tone for user \(email)")
        navigationStackActions.onNext(.set(viewModels: [self.createHomeViewModel()], animated: false))
    }
    
    private func createHomeViewModel() -> HomeViewModel {
        let homeViewModel = HomeViewModel()
        homeViewModel.events
            .subscribe(onNext: { [weak self] event in //Reference createLoginViewModel for how to reference Self
                switch event {
                case .logOut:
                    print("Logout")
                    self!.navigationStackActions.onNext(.set(viewModels: [self!.createLoginViewModel()], animated: false))
                case .sampleSkinTone:
                    print("Sample Skin Tone")
                    self!.navigationStackActions.onNext(.push(viewModel: self!.createSampleSkinToneViewModel(), animated: false))
                case .openSample(let sample):
                    print("Open Sample :: \(sample)")
                case .openSettings:
                    print("Open Settings")
                }
            }).disposed(by: disposeBag)
        
        return homeViewModel
    }
    
    private func createSampleSkinToneViewModel() -> SampleSkinToneViewModel {
        let sampleSkinToneViewModel = SampleSkinToneViewModel()
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
}
