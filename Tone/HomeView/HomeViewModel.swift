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
        case openNewCaptureSession
    }
    
    let events = PublishSubject<Event>()
    let user: User
    let disposeBag = DisposeBag()
    
    init(user: User) {
        self.user = user

        self.user.fetchUserData() //Display loading screen during this time?
            .do(onNext: { isSuccessful in
                if !isSuccessful { self.events.onNext(.logOut) }
            })
            .filter { $0 }
            .flatMap { _ in self.user.getAndCheckCaptureSession() }
            .do(onNext: { isCaptureSessionValid in
                if !isCaptureSessionValid { self.events.onNext(.openNewCaptureSession) }
            })
            .filter { $0 }
            .subscribe(onNext: { _ in
                print("Done Fetching User Data :: \(user.settings) | \(user.captureSession)")
            }).disposed(by: disposeBag)
    }
    
    func logout() {
        events.onNext(.logOut)
    }
    
    func openSettings() {
        print("Opening Settings")
        events.onNext(.openSettings)
    }
    
    func sampleSkinTone() {
        print("Starting Sample Skin Tone for \(user.email)")
        events.onNext(.sampleSkinTone)
    }
    
    deinit {
        print("DESTROYING HOME CONTROLLER")
    }
}
