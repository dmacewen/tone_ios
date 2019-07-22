//
//  SettingsViewModel.swift
//  Tone
//
//  Created by Doug MacEwen on 4/17/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation
import RxSwift

class SettingsViewModel {
    enum Event {
        case back
    }
    
    let events = PublishSubject<Event>()
    let settings: Settings
    let user: User
    let disposeBag = DisposeBag()
    
    init(user: User) {
        self.user = user
        self.settings = user.settings
    }
    
    func back() {
        print("Going Back")
        events.onNext(.back)
        user.updateUserData()
            .subscribe(onNext: { isSuccessful in
                print("Success?? \(isSuccessful)")
            }).disposed(by: disposeBag)
        
    }
}
