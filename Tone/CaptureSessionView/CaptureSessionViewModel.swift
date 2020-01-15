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
        case mirror
    }
    
    let events = PublishSubject<Event>()
    let user: User
    let skinColorIdOptional = BehaviorRelay<Int32?>(value: nil)
    let disposeBag = DisposeBag()
    
    init(user: User, isCancelable: Bool = true) {
        self.user = user
        super.init()
        super.isCancelable = isCancelable
    }
    
    func updateSkinColorId() {
        guard let skinColorId = skinColorIdOptional.value, (skinColorId > 0) && (skinColorId <= 40) else {
            print("Enter a valid skin color!")
            return
        }
        
        user.updateCaptureSession(skinColorId)
            .subscribe(onSuccess: { [unowned self] _ in
                self.events.onNext(.updated)
            }, onError: { error in
                print("Error updating capture session :: \(error)")
            }).disposed(by: disposeBag)
    }
    
    func cancel() {
        self.events.onNext(.cancel)
    }
    
    func mirror() {
        self.events.onNext(.mirror)
    }
    
    func showHelp() {
        self.events.onNext(.showHelp)
    }
}
