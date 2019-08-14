//
//  HomeViewModel.swift
//  Tone
//
//  Created by Doug MacEwen on 10/30/18.
//  Copyright © 2018 Doug MacEwen. All rights reserved.
//

import Foundation
import RxSwift

class HomeViewModel: ViewModel {
    enum Event {
        case logOut
        case sampleSkinTone
        case openSample(sample: String)
        case openSettings
        case openNewCaptureSession(isCancelable: Bool)
    }
    
    let events = PublishSubject<Event>()
    let user: User
    let disposeBag = DisposeBag()
    
    init(user: User) {
        self.user = user
/*
        self.user.fetchUserData() //Display loading screen during this time?
            .do(onNext: { isSuccessful in
                if !isSuccessful { self.events.onNext(.logOut) }
            })
            .filter { $0 }
            .flatMap { _ in self.user.getAndCheckCaptureSession() }
            .do(onNext: { isCaptureSessionValid in
                if !isCaptureSessionValid { self.events.onNext(.openNewCaptureSession(isCancelable: false)) }
            })
            .filter { $0 }
            .subscribe(onNext: { _ in
                print("Done Fetching User Data :: \(user.settings) | \(user.captureSession)")
            }).disposed(by: disposeBag)
 */
    }
    /*
    func checkConditions() {
        if !self.user.isCaptureSessionValid() {
            self.events.onNext(.openNewCaptureSession(isCancelable: false))
        }
    }
    */
    override func afterLoad() {
        if !self.user.isCaptureSessionValid() {
            self.events.onNext(.openNewCaptureSession(isCancelable: false))
        }
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
    
    func updateCaptureSession() {
        print("Opening Update Capture Session")
        events.onNext(.openNewCaptureSession(isCancelable: true))
    }
    
    deinit {
        print("DESTROYING HOME CONTROLLER")
    }
}
