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
                    self?.launchTone(withEmail: email)
                }
            })
            .disposed(by: disposeBag)
        
        return loginViewModel
    }
    
    private func launchTone(withEmail email: String) {
        print("Launching Tone for user \(email)")
    }

}
