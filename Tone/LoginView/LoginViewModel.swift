//
//  LoginViewModel.swift
//  Tone
//
//  Created by Doug MacEwen on 10/29/18.
//  Copyright © 2018 Doug MacEwen. All rights reserved.
//
//Validation inspired by
//https://github.com/ReactiveX/RxSwift/blob/master/Documentation/Examples.md

import Foundation
import RxSwift
import RxRelay

class LoginViewModel: ViewModel {
   
    enum LoginEvent {
        case loggedIn(user: User)
    }
    
    let events = PublishSubject<LoginEvent>()

    //let email = Variable<String?>(nil)
    let email = BehaviorRelay<String?>(value: nil)
    //let password = Variable<String?>(nil)
    let password = BehaviorRelay<String?>(value: nil)
    
    override func afterLoad() {
        print("After Load Login!")
    }
    
    func login() -> Single<Bool> {
        guard let validatedEmail = email.value else { return Single.just(false) }
        guard let validatedPassword = password.value else { return Single.just(false)}
        
        return loginUser(email: validatedEmail, password: validatedPassword)
            .flatMap { user -> Single<User> in
                return user.fetchUserData()
            }
            .flatMap { user -> Single<User> in
                return user.getCaptureSession()
            }
            .map { [unowned self] user in
                self.events.onNext(.loggedIn(user: user))
                return true
            }
            .catchError { _ in Single.just(false) }

    }
}
