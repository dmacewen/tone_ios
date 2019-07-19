//
//  User.swift
//  Tone
//
//  Created by Doug MacEwen on 3/26/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation

class User {
    let email: String
    var settings: Settings
    let user_id: Int32
    let token: Int32
    
    init(email: String, user_id: Int32, token: Int32, settings: Settings = Settings()) {
        self.email = email
        self.settings = settings
        self.user_id = user_id
        self.token = token
    }
}
