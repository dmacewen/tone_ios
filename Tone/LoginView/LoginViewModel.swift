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
    
    func isEmailValid() -> Bool {
        guard var email = email.value else { return false }
        //REMOVE! THIS IS JUST FOR TESTING CONVENIENCE
        if email == "D" {
            self.email.value = "Doug"
            email = "Doug"
        }
        
        if email == "H" {
            self.email.value = "Halyna"
            email = "Halyna"
        }
        
        if email == "J" {
            self.email.value = "Jenny"
            email = "Jenny"
        }
        
        return ["Doug", "Halyna", "Jenny"].contains(email)
        //return !email.isEmpty && email.contains("@")
    }
    
    func login() {
        print("Trying to log in with email \(email)!")
        guard let validatedEmail = email.value else { return }
        events.onNext(.loggedIn(user: User(email: validatedEmail)))
    }
}
