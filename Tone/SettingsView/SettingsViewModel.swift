//
//  SettingsViewModel.swift
//  Tone
//
//  Created by Doug MacEwen on 4/17/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation
import RxSwift

class SettingsViewModel: ViewModel {
    enum Event {
        case back
        case logOut
    }
    
    let events = PublishSubject<Event>()
    let settings: Settings
    let user: User
    let disposeBag = DisposeBag()
    
    init(user: User) {
        self.user = user
        self.settings = user.settings
    }
    
    override func afterLoad() {
        print("After Settings Load!")
    }
    
    func back() {
        print("Going Back")
        events.onNext(.back)
        user.updateUserData()
            .map { $0 != nil }
            .subscribe(onNext: { [unowned self] isSuccessful in
                print("Success?? \(isSuccessful)")
                if !isSuccessful {
                    self.events.onNext(.logOut)
                }
            }).disposed(by: disposeBag)
    }
}
