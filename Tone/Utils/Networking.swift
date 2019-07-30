//
//  networking.swift
//  Tone
//
//  Created by Doug MacEwen on 7/19/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation
import Alamofire
import RxSwift

let rootURL = URL(string: "https://macewen.io")!
let apiURL = rootURL.appendingPathComponent("users")

struct UploadStatus {
    let doneUpload: Bool
    let responseRecieved: Bool
    
    init(_ doneUpload: Bool, _ responseRecieved: Bool) {
        self.doneUpload = doneUpload
        self.responseRecieved = responseRecieved
    }
}

private struct LoginResponse: Codable {
    let token: Int32
    let user_id: Int32
}

func loginUser(email: String, password: String) -> Observable<User?> {
    return Observable.create { observable in
        let parameters = ["email": email, "password": password]
        print("Requesting \(parameters)")
        Alamofire
            .request(apiURL, method: .post, parameters: parameters, encoding: URLEncoding.default)
            .validate(statusCode: 200..<300)
            .responseData { response in
                defer { observable.onCompleted() }
                switch response.result {
                case .success:
                    guard let json = response.result.value, let userData = try? JSONDecoder().decode(LoginResponse.self, from: json) else {
                        print("COULD NOT DECODE USER DATA")
                        observable.onNext(nil)
                        return
                    }
    
                    print("USER DATA \(userData)")
                    observable.onNext(User(email: email, user_id: userData.user_id, token: userData.token))
                case .failure(let error):
                    print("Login Error :: \(error)")
                    observable.onNext(nil)
                }
            }
            return Disposables.create()
    }
}

private func buildUserURL(_ user_id: Int32, _ token: Int32) -> URL? {
    let url = apiURL.appendingPathComponent(String(user_id))
    let urlRequest = URLRequest(url: url)
    let tokenParameters = ["token": token]
    
    guard let encodedURLRequest = try? URLEncoding.queryString.encode(urlRequest, with: tokenParameters) else {
        print("Could not encode user URL")
        return nil
    }
    
    return encodedURLRequest.url
}

func getUserSettings(user_id: Int32, token: Int32) -> Observable<Settings?> {
    return Observable.create { observable in
        guard var url = buildUserURL(user_id, token) else {
            observable.onNext(nil)
            observable.onCompleted()
            return Disposables.create()
        }

        print("Requesting URL \(url.absoluteString)")
        Alamofire
            .request(url, method: .get, parameters: [:], encoding: URLEncoding.default)
            .validate(statusCode: 200..<300)
            .responseData { response in
                defer { observable.onCompleted() }
                switch response.result {
                case .success:
                    guard let json = response.result.value, let settings = try? JSONDecoder().decode(Settings.self, from: json) else {
                        print("COULD NOT DECODE SETTINGS")
                        observable.onNext(Settings())
                        return
                    }
                    
                    observable.onNext(settings)
                case .failure(let error):
                    print("Settings Error :: \(error)")
                    observable.onNext(nil)
                }
        }
        return Disposables.create()
    }
}

func updateUserSettings(user_id: Int32, token: Int32, settings: Settings) -> Observable<Bool> {
    return Observable.create { observable in
        guard var url = buildUserURL(user_id, token) else {
            observable.onNext(false)
            observable.onCompleted()
            return Disposables.create()
        }
        
        guard let settingsData = try? JSONEncoder().encode(settings), let settingsString = String(data: settingsData, encoding: .utf8) else {
            print("Could Not Encode Settings")
            observable.onNext(false)
            observable.onCompleted()
            return Disposables.create()
        }
        
        let settingsParameters = ["settings": settingsString]
        
        Alamofire
            .request(url, method: .post, parameters: settingsParameters, encoding: URLEncoding.default)
            .validate(statusCode: 200..<300)
            .responseString { response in
                defer { observable.onCompleted() }
                switch response.result {
                case .success:
                    guard let _ = response.data else {
                        print("COULD NOT UPDATE USER SETTINGS")
                        observable.onNext(false)
                        return
                    }
                    observable.onNext(true)
                case .failure(let error):
                    print("Updated Settings Error :: \(error)")
                    observable.onNext(false)
                }
        }
 
        return Disposables.create()
    }
}

func updateUserAcknowledgementAgreement(user_id: Int32, token: Int32, didAgree: Bool) -> Observable<Bool> {
    return Observable.create { observable in
        guard var url = buildUserURL(user_id, token) else {
            observable.onNext(false)
            observable.onCompleted()
            return Disposables.create()
        }
        
        url.appendPathComponent("agree")
        let agreeParameters = ["agree": didAgree]
        
        Alamofire
            .request(url, method: .put, parameters: agreeParameters, encoding: URLEncoding.default)
            .validate(statusCode: 200..<300)
            .responseString { response in
                defer { observable.onCompleted() }
                switch response.result {
                case .success:
                    guard let _ = response.data else {
                        print("AGREEMENT FALSE")
                        observable.onNext(false)
                        return
                    }
                    
                    observable.onNext(true)
                case .failure(let error):
                    print("Update User acknowledgement Error :: \(error)")
                    observable.onNext(false)
                }
        }
 
        return Disposables.create()
    }
}

func getCaptureSession(user_id: Int32, token: Int32) -> Observable<CaptureSession?> {
    return Observable.create { observable in
        guard var url = buildUserURL(user_id, token) else {
            observable.onNext(nil)
            observable.onCompleted()
            return Disposables.create()
        }
        
        url.appendPathComponent("session")
        
        print("Getting Capture Session At :: \(url.absoluteString)")
        Alamofire
            .request(url, method: .get, parameters: [:], encoding: URLEncoding.default)
            .validate(statusCode: 200..<300)
            .responseData { response in
                defer { observable.onCompleted() }
                print("Response :: \(String(data: response.data!, encoding: .utf8)!)")
                switch response.result {
                case .success:
                    guard let json = response.result.value, let captureSession = try? JSONDecoder().decode(CaptureSession.self, from: json) else {
                        print("COULD NOT DECODE CAPTURE SESSION")
                        observable.onNext(nil)
                        return
                    }
                    
                    print("Capture Session :: \(captureSession)")
                    observable.onNext(captureSession)
                case .failure(let error):
                    print("Capture Session Error :: \(error)")
                    observable.onNext(nil)
                }
        }
        
        return Disposables.create()
    }
}

func getNewCaptureSession(user_id: Int32, token: Int32, skinColorId: Int32) -> Observable<CaptureSession?> {
    return Observable.create { observable in
        guard var url = buildUserURL(user_id, token) else {
            observable.onNext(nil)
            observable.onCompleted()
            return Disposables.create()
        }
        
        url.appendPathComponent("session")
        let captureSessionParameters = ["skin_color_id": skinColorId]
        
        print("Getting Capture Session At :: \(url.absoluteString)")
        Alamofire
            .request(url, method: .post, parameters: captureSessionParameters, encoding: URLEncoding.default)
            .validate(statusCode: 200..<300)
            .responseData { response in
                defer { observable.onCompleted() }
                print("Response :: \(String(data: response.data!, encoding: .utf8)!)")
                switch response.result {
                case .success:
                    guard let json = response.result.value, let captureSession = try? JSONDecoder().decode(CaptureSession.self, from: json) else {
                        print("COULD NOT DECODE CAPTURE SESSION")
                        observable.onNext(nil)
                        return
                    }
                    
                    print("Capture Session :: \(captureSession)")
                    observable.onNext(captureSession)
                case .failure(let error):
                    print("Capture Session Error :: \(error)")
                    observable.onNext(nil)
                }
        }
        
        return Disposables.create()
    }
}

func uploadImageData(user_id: Int32, token: Int32, session_id: Int32, app_version: String, device_info: DeviceInfo, imageData: [ImageData], progressBar: BehaviorSubject<Float>) -> Observable<UploadStatus> {
    
    return Observable.create { observable in
        guard var url = buildUserURL(user_id, token) else {
            print("Could Not Build URL")
            observable.onNext(UploadStatus(false, false))
            observable.onCompleted()
            return Disposables.create()
        }
    
        url.appendPathComponent("capture")
        
        guard let device_info_data = try? JSONEncoder().encode(device_info), let device_info_string = String(data: device_info_data, encoding: .utf8) else {
            print("Could Not Encode Device Info!")
            observable.onNext(UploadStatus(false, false))
            observable.onCompleted()
            return Disposables.create()
        }
        
        let metaData = imageData.map { $0.setMetadata }
        
        guard let metaData_data = try? JSONEncoder().encode(metaData), let metaData_string = String(data: metaData_data, encoding: .utf8) else {
            print("Could Not Encode Metadata!")
            observable.onNext(UploadStatus(false, false))
            observable.onCompleted()
            return Disposables.create()
        }
        
        let captureParameters = [
            "session_id": session_id,
            "app_version": app_version,
            "device_info": device_info_string,
            "metadata": metaData_string
            ] as [String : Any]
        
        guard let captureParametersJSON = try? JSONSerialization.data(withJSONObject: captureParameters) else {
            print("Could Not Encode Parameters!")
            observable.onNext(UploadStatus(false, false))
            observable.onCompleted()
            return Disposables.create()
        }
    
        let headers: HTTPHeaders = [
            "Content-type": "multipart/form-data"
        ]
        
        Alamofire.upload(
            multipartFormData: { multipartFormData in
                //Upload parameters as part of file data because I guess multipart forms dont support parameters?
                multipartFormData.append(captureParametersJSON, withName: "parameters", fileName: "parameters.json", mimeType: "application/json")
                for (index, imageDatum) in imageData.enumerated() {
                    let pngDataFace = imageDatum.faceData
                    let pngDataLeftEye = imageDatum.leftEyeData
                    let pngDataRightEye = imageDatum.rightEyeData
                    
                    let imageName = String(index + 1)
                    multipartFormData.append(pngDataFace, withName: imageName, fileName: "\(imageName).png", mimeType: "image/png")
                    multipartFormData.append(pngDataLeftEye, withName: "\(imageName)_leftEye", fileName: "\(imageName)_leftEye.png", mimeType: "image/png")
                    multipartFormData.append(pngDataRightEye, withName: "\(imageName)_rightEye", fileName: "\(imageName)_rightEye.png", mimeType: "image/png")
                }
            },
            to: url,
            method: .post,
            headers: headers,
            encodingCompletion: { result in
                switch result {
                case .success(let upload, _, _):
                    upload.response { response in
                        if let err = response.error{
                            print("Error :: \(err)")
                            return
                        }
                        print("Succesfully Uploaded")
                        if let responseString = String(data: response.data!, encoding: .utf8) {
                            print("Server Response :: \(responseString)")
                        } else {
                            print("Server Response not a valid UTF-8 sequence")
                        }
                        observable.onNext(UploadStatus.init(true, true))
                        observable.onCompleted()
                    }
                    upload.uploadProgress { progress in
                        progressBar.onNext(Float(progress.fractionCompleted))
                        if progress.isFinished {
                            observable.onNext(UploadStatus(true, false))
                        }
                    }
                case .failure(let error):
                    print("Error in upload: \(error.localizedDescription)")
                    observable.onError(error)
                }
            }
        )
        
        observable.onNext(UploadStatus(false, false))
        return Disposables.create()
    }
}
