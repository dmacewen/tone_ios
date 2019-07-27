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
    
    func fetchUserData() -> Observable<Bool> {
        return getUserSettings(user_id: self.user_id, token: self.token)
            .map { settingsOptional in
                guard let settings = settingsOptional else {
                    return false
                }
                self.settings = settings
                return true
            }
    }
    
    func updateUserData() -> Observable<Bool> {
        return updateUserSettings(user_id: self.user_id, token: self.token, settings: self.settings)
    }
    
    func agreeToAcknowledgement(_ didAgree: Bool) -> Observable<Bool> {
            return updateUserAcknowledgementAgreement(user_id: self.user_id, token: self.token, didAgree: didAgree)
    }
    
    func getAndCheckCaptureSession() -> Observable<Bool> {
            return getCaptureSession(user_id: self.user_id, token: self.token)
                .map { captureSessionOptional in
                    self.captureSession = captureSessionOptional
                    
                    guard let captureSession = captureSessionOptional else {
                        return false
                    }
                    
                    return captureSession.isValid()
                    
        }
    }
    
    func updateCaptureSession(_ skinColorId: Int32) -> Observable<Bool> {
        //print("Updating Capture Session with skin color id :: \(skinColorId)")
        return getNewCaptureSession(user_id: self.user_id, token: self.token, skinColorId: skinColorId)
            .map { captureSessionOptional in
                self.captureSession = captureSessionOptional
                
                //print("New Capture Session :: \(String(describing: self.captureSession))")

                guard let captureSession = captureSessionOptional else {
                    return false
                }
                
                return captureSession.isValid()
        }
    }
}
