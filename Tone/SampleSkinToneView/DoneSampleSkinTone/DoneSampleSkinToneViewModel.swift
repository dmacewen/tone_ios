//
//  DoneSampleSkinToneViewModel.swift
//  Tone
//
//  Created by Doug MacEwen on 8/24/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation
import RxSwift
import RxRelay

class DoneSampleSkinToneViewModel: ViewModel {
    enum Event {
        case ok
    }
    
    let events = PublishSubject<Event>()
    
    override func afterLoad() {
        print("After Done Sample Skin Tone View Model Loads")
    }
    
    func ok() {
        self.events.onNext(.ok)
    }
}
