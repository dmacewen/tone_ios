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

class LoginViewModel {
    enum Event {
        case loggedIn(user: User)
    }
    
    let events = PublishSubject<Event>()

    let email = Variable<String?>(nil)
    let password = Variable<String?>(nil)
    
    func login() -> Observable<Bool> {
        guard let validatedEmail = email.value else { return Observable.just(false) }
        guard let validatedPassword = password.value else { return Observable.just(false)}
        
        return loginUser(email: validatedEmail, password: validatedPassword)
            .map { loginResponse in
                guard let user = loginResponse else { return false }
                self.events.onNext(.loggedIn(user: user))
                return true
            }
    }
}
