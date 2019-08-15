//
//  BetaAgreementViewModel.swift
//  Tone
//
//  Created by Doug MacEwen on 7/22/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation
import RxSwift

class BetaAgreementViewModel: ViewModel {
    enum Event {
        case agree
        case disagree
    }
    
    let events = PublishSubject<Event>()
    let user: User
    let disposeBag = DisposeBag()
    
    init(user: User) {
        self.user = user
    }
    
    override func afterLoad() {
        print("After Beta Agreement View Model Loads")
    }
    
    func agree(_ didAgree: Bool) {
         user.agreeToAcknowledgement(didAgree)
            .map { $0 != nil }
            .subscribe(onNext: { [unowned self] loginResponse in
                if loginResponse && didAgree {
                    self.events.onNext(.agree)
                } else {
                    self.events.onNext(.disagree)
                }
        }).disposed(by: disposeBag)
    }
}
