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
    
    init(settings: Settings) {
        self.settings = settings
    }
    
    func back() {
        print("Going Back")
        events.onNext(.back)
    }
}
