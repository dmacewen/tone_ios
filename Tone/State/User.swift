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
    let settings: Settings
    
    init(email: String, settings: Settings = Settings()) {
        self.email = email
        self.settings = settings
    }
}
