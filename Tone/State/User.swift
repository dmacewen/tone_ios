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
    
    init(email: String, user_id: Int32, token: Int32, settings: Settings = Settings(), captureSession: CaptureSession? = nil) {
        self.email = email
        self.settings = settings
        self.user_id = user_id
        self.token = token
        self.captureSession = captureSession
    }
    
    func fetchUserData() -> Single<User> {
        return getUserSettings(user_id: self.user_id, token: self.token)
            .map { settings in
                self.settings = settings
                return self
            }
    }
    
    func updateUserData() -> Single<User> {
        return Single.create { single in
            updateUserSettings(user_id: self.user_id, token: self.token, settings: self.settings).subscribe(onCompleted: { single(.success(self)) }, onError: { error in single(.error(error)) })
        }
    }
    
    func agreeToAcknowledgement(_ didAgree: Bool) -> Single<User> {
        return Single.create { single in
            updateUserAcknowledgementAgreement(user_id: self.user_id, token: self.token, didAgree: didAgree).subscribe(onCompleted: { single(.success(self)) }, onError: { error in single(.error(error)) })
        }
    }
    
    func getCaptureSession() -> Single<User> {
        return Tone.getCaptureSession(user_id: self.user_id, token: self.token)
            .map { captureSession in
                self.captureSession = captureSession
                return self
        }
    }
    
    func isCaptureSessionValid() -> Bool {
        guard let captureSession = self.captureSession else {
            return false
        }
        
        return captureSession.isValid()
    }
    
    func updateCaptureSession(_ skinColorId: Int32) -> Single<User> {
        return getNewCaptureSession(user_id: self.user_id, token: self.token, skinColorId: skinColorId)
            .do(onSuccess: { self.captureSession = $0 })
            .flatMap { $0.isValid() ? Single.just(self) : Single.error(CaptureSessionError.invalid) }
    }
    
    func uploadNewCapture(imageData: [ImageData], progressBar: BehaviorSubject<Float>) -> Observable<UploadStatus> {
        let publicVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        let appVersion = "\(publicVersion!).\(buildVersion!)"
        let deviceInfo = getDeviceInfo()

        return uploadImageData(user_id: user_id, token: token, session_id: captureSession!.session_id, app_version: appVersion, device_info: deviceInfo, imageData: imageData, progressBar: progressBar)
    }
    
}
