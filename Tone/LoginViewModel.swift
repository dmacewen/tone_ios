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
        case loggedIn(email: String)
    }
    
    let email = Variable<String?>(nil)
    let password = Variable<String?>(nil)
    
    let events = PublishSubject<Event>()
    
    func isEmailValid() -> Bool {
        guard let email = email.value else { return false }
        return !email.isEmpty && email.contains("@")
    }
    
    func login() {
        print("Trying to log in with email \(email)!")
        guard let validatedEmail = email.value else { return }
        events.onNext(.loggedIn(email: validatedEmail))
    }
}
