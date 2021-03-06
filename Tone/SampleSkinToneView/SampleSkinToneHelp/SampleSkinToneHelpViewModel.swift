//
//  SampleSkinToneHelpViewModel.swift
//  Tone
//
//  Created by Doug MacEwen on 8/22/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation
import RxSwift
import RxRelay

class SampleSkinToneHelpViewModel: ViewModel {
    enum Event {
        case ok
        case cancel
    }
    
    let events = PublishSubject<Event>()
    let user: User
    let skinColorIdOptional = BehaviorRelay<Int32?>(value: nil)
    
    init(user: User, isCancelable: Bool) {
        self.user = user
        super.init()
        self.isCancelable = isCancelable
    }
    
    func cancel() {
        self.events.onNext(.cancel)
    }
    
    func ok() {
        self.events.onNext(.ok)
    }
}
