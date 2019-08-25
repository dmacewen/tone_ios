//
//  CaptureSessionHelpViewModel.swift
//  Tone
//
//  Created by Doug MacEwen on 8/22/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation
import RxSwift
import RxRelay

class CaptureSessionHelpViewModel: ViewModel {
    enum Event {
        case ok
        case cancel
    }
    
    let events = PublishSubject<Event>()
    let user: User
    let skinColorIdOptional = BehaviorRelay<Int32?>(value: nil)
    let disposeBag = DisposeBag()
    
    init(user: User) {
        self.user = user
        super.init()
    }
    
    override func afterLoad() {
        print("After Capture Session Help View Model Loads")
    }
    
    func cancel() {
        self.events.onNext(.cancel)
    }
    
    func ok() {
        self.events.onNext(.ok)
    }
}
