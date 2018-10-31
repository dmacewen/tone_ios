//
//  SampleSkinToneViewModel.swift
//  Tone
//
//  Created by Doug MacEwen on 10/30/18.
//  Copyright © 2018 Doug MacEwen. All rights reserved.
//

import Foundation
import RxSwift

class SampleSkinToneViewModel {
    enum Event {
        case cancel
    }
    
    let events = PublishSubject<Event>()
    
    func cancel() {
        events.onNext(.cancel)
    }
}
