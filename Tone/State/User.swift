//
//  User.swift
//  Tone
//
//  Created by Doug MacEwen on 3/26/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation
import RxSwift

class User {
    let email: String
    var settings: Settings
    let user_id: Int32
    let token: Int32
    let disposeBag = DisposeBag()
    
    init(email: String, user_id: Int32, token: Int32, settings: Settings = Settings()) {
        self.email = email
        self.settings = settings
        self.user_id = user_id
        self.token = token
    }
    
    func fetchUserData() -> Observable<User> {
        return getUserSettings(user_id: self.user_id, token: self.token)
            .map { settingsOptional in
                self.settings = settingsOptional ?? Settings()
                return self
            }
    }
    
    func updateUserData() -> Observable<Bool> {
        return updateUserSettings(user_id: self.user_id, token: self.token, settings: self.settings)
    }
    
    func agreeToAcknowledgement(_ didAgree: Bool) -> Observable<Bool> {
            return updateUserAcknowledgementAgreement(user_id: self.user_id, token: self.token, didAgree: didAgree)
    }
}
