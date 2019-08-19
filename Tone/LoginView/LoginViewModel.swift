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
    
    func login() -> Observable<Bool> {
        guard let validatedEmail = email.value else { return Observable.just(false) }
        guard let validatedPassword = password.value else { return Observable.just(false)}
        
        return loginUser(email: validatedEmail, password: validatedPassword)
            .flatMap { userOptional -> Observable<User?> in
                guard let user = userOptional else { return Observable.just(nil) }
                return user.fetchUserData()
            }
            .flatMap { userOptional -> Observable<User?> in
                guard let user = userOptional else { return Observable.just(nil) }
                return user.getCaptureSession()
            }
            .map { [unowned self] userOptional in
                guard let user = userOptional else { return false }
                self.events.onNext(.loggedIn(user: user))
                return true
            }
    }
}
