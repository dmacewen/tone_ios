//
//  CaptureSessionViewModel.swift
//  Tone
//
//  Created by Doug MacEwen on 7/23/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation
import RxSwift
import RxRelay

class CaptureSessionViewModel: ViewModel {
    enum Event {
        case updated
        case cancel
        case showHelp
    }
    
    let events = PublishSubject<Event>()
    let user: User
    //let isCancelable: Bool
    //let skinColorIdOptional = Variable<Int32?>(nil)
    let skinColorIdOptional = BehaviorRelay<Int32?>(value: nil)
    let disposeBag = DisposeBag()
    
    init(user: User, isCancelable: Bool = true) {
        self.user = user
        super.init()
        super.isCancelable = isCancelable
    }
    
    override func afterLoad() {
        print("After Capture Session View Model Loads")
    }
    
    func updateSkinColorId() {
        guard let skinColorId = skinColorIdOptional.value, (skinColorId > 0) && (skinColorId <= 40) else {
            print("Enter a valid skin color!")
            return
        }
        
        user.updateCaptureSession(skinColorId)
            .map { $0 != nil }
            .subscribe(onNext: { [unowned self] isSuccessful in
                print("Is Successful?? \(isSuccessful)")
                if isSuccessful {
                    self.events.onNext(.updated)
                    return
                }
            }).disposed(by: disposeBag)
        
    }
    
    func cancel() {
        self.events.onNext(.cancel)
    }
    
    func showHelp() {
        self.events.onNext(.showHelp)
    }
}
