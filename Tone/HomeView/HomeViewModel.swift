//
//  HomeViewModel.swift
//  Tone
//
//  Created by Doug MacEwen on 10/30/18.
//  Copyright © 2018 Doug MacEwen. All rights reserved.
//

import Foundation
import RxSwift

class HomeViewModel {
    enum Event {
        case logOut
        case sampleSkinTone
        case openSample(sample: String)
        case openSettings
    }
    
    let events = PublishSubject<Event>()
    
    func logout() {
        events.onNext(.logOut)
    }
    
    func sampleSkinTone() {
        print("Starting Sample Skin Tone")
        events.onNext(.sampleSkinTone)
    }
}
