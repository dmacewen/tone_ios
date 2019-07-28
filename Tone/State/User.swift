//
//  User.swift
//  Tone
//
//  Created by Doug MacEwen on 3/26/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation
import RxSwift

class User {
    let email: String
    var settings: Settings
    let user_id: Int32
    let token: Int32
    var captureSession: CaptureSession?
    //let disposeBag = DisposeBag()
    
    init(email: String, user_id: Int32, token: Int32, settings: Settings = Settings(), captureSession: CaptureSession? = nil) {
        self.email = email
        self.settings = settings
        self.user_id = user_id
        self.token = token
        self.captureSession = captureSession
    }
    
    func fetchUserData() -> Observable<User?> {
        return getUserSettings(user_id: self.user_id, token: self.token)
            .map { settingsOptional in
                guard let settings = settingsOptional else {
                    return nil
                }
                self.settings = settings
                return self
            }
    }
    
    func updateUserData() -> Observable<User?> {
        return updateUserSettings(user_id: self.user_id, token: self.token, settings: self.settings).map { $0 ? self : nil }
    }
    
    func agreeToAcknowledgement(_ didAgree: Bool) -> Observable<User?> {
        return updateUserAcknowledgementAgreement(user_id: self.user_id, token: self.token, didAgree: didAgree).map { $0 ? self : nil }
    }
    
    func getCaptureSession() -> Observable<User?> {
        return Tone.getCaptureSession(user_id: self.user_id, token: self.token)
            .map { captureSessionOptional in
                self.captureSession = captureSessionOptional
                /*
                guard let captureSession = captureSessionOptional else {
                    return nil
                }
                */
                return self
        }
    }
    
    func isCaptureSessionValid() -> Bool {
        guard let captureSession = self.captureSession else {
            return false
        }
        
        return captureSession.isValid()
    }
    
    func updateCaptureSession(_ skinColorId: Int32) -> Observable<User?> {
        //print("Updating Capture Session with skin color id :: \(skinColorId)")
        return getNewCaptureSession(user_id: self.user_id, token: self.token, skinColorId: skinColorId)
            .map { captureSessionOptional in
                self.captureSession = captureSessionOptional
                
                //print("New Capture Session :: \(String(describing: self.captureSession))")

                guard let captureSession = captureSessionOptional else {
                    return nil
                }
                
                return captureSession.isValid() ? self : nil
        }
    }
    
    func getCalibratedSkinColorWithProgressIndicator(imageData: [ImageData]) -> (Observable<Int32?>, BehaviorSubject<Double>) {
        let publicVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        let appVersion = "\(publicVersion!).\(buildVersion!)"
        print("App Version! :: \(appVersion)")
        return (Observable.just(nil), BehaviorSubject.init(value: 0.0))
    }
}
