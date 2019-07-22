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

let rootURL = URL(string: "http://macewen.io")!
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
                guard let json = response.result.value, let userData = try? JSONDecoder().decode(LoginResponse.self, from: json) else {
                    print("COULD NOT DECODE USER DATA")
                    observable.onNext(nil)
                    return
                }
                
                print("USER DATA \(userData)")
                observable.onNext(User(email: email, user_id: userData.user_id, token: userData.token))
                
            }
            return Disposables.create()
    }
}

func getUserSettings(user_id: Int32, token: Int32) -> Observable<Settings?> {
    return Observable.create { observable in
        let url = apiURL.appendingPathComponent(String(user_id))
        let parameters = ["token": token]
        print("Requesting \(parameters) at \(url)")
        Alamofire
            .request(url, method: .get, parameters: parameters, encoding: URLEncoding.default)
            .validate(statusCode: 200..<300)
            .responseData { response in
                defer { observable.onCompleted() }
                guard let json = response.result.value, let settings = try? JSONDecoder().decode(Settings.self, from: json) else {
                    print("COULD NOT DECODE SETTINGS")
                    observable.onNext(nil)
                    return
                }
                
                observable.onNext(settings)
        }
        
        return Disposables.create()
    }
}

func updateUserSettings(user_id: Int32, token: Int32, settings: Settings) -> Observable<Bool> {
    return Observable.create { observable in
        let url = apiURL.appendingPathComponent(String(user_id))
        let urlRequest = URLRequest(url: url)
        let parameters = ["token": token]
        
        guard let settingsData = try? JSONEncoder().encode(settings), let settingsString = String(data: settingsData, encoding: .utf8) else {
            print("Could Not Encode Settings")
            observable.onNext(false)
            observable.onCompleted()
            return Disposables.create()
        }
        
        let settingsParameters = ["settings": settingsString]
        
        guard let encodedURL = try? URLEncoding.queryString.encode(urlRequest, with: parameters) else {
            print("Could not encode URL for Settings")
            return Disposables.create()
        }
        
        print("Encoded URL :: \(encodedURL.url!.absoluteString)")
        Alamofire
            .request(encodedURL.url!, method: .post, parameters: settingsParameters, encoding: URLEncoding.default)
            .validate(statusCode: 200..<300)
            .responseString { response in
                defer { observable.onCompleted() }
                guard let isSuccessful = response.data else {
                    print("COULD NOT UPDATE USER SETTINGS")
                    observable.onNext(false)
                    return
                }
                print("IS SUCCESSFUL ?? \(String(data:isSuccessful, encoding: .utf8)!)")
                observable.onNext(true)
        }
 
        return Disposables.create()
    }
}

func uploadImageData(imageData: [ImageData], progressBar: BehaviorSubject<Float>, user: User) -> Observable<UploadStatus> {
    
    let userid = user.email
    //let url = rootURL + "/\(userid)/selfie"
    var url = apiURL.appendingPathComponent(userid)
    url.appendPathComponent("selfie")
    
    let headers: HTTPHeaders = [
        /* "Authorization": "your_access_token",  in case you need authorization header */
        "Content-type": "multipart/form-data"
    ]
    
    return Observable.create { observable in
        
        Alamofire.upload(
            multipartFormData: { multipartFormData in
                let metaData: [SetMetadata] = imageData.map { $0.setMetadata }
                for (index, imageDatum) in imageData.enumerated() {
                    //let pngData = imageDatum.image.pngData()
                    let pngDataFace = imageDatum.faceData
                    let pngDataLeftEye = imageDatum.leftEyeData
                    let pngDataRightEye = imageDatum.rightEyeData
                    
                    let imageName = String(index + 1)
                    multipartFormData.append(pngDataFace, withName: imageName, fileName: "\(imageName).png", mimeType: "image/png")
                    multipartFormData.append(pngDataLeftEye, withName: "\(imageName)_leftEye", fileName: "\(imageName)_leftEye.png", mimeType: "image/png")
                    multipartFormData.append(pngDataRightEye, withName: "\(imageName)_rightEye", fileName: "\(imageName)_rightEye.png", mimeType: "image/png")
                }
                
                do {
                    let jsonData = try JSONEncoder().encode(metaData)
                    let jsonString = String(data: jsonData, encoding: .utf8)!
                    
                    //multipartFormData.append(jsonData, withName: "metadata", fileName: "metadata.txt", mimeType: "application/json")
                    multipartFormData.append(jsonString.data(using: String.Encoding.utf8, allowLossyConversion: false)!, withName: "metadata", fileName: "metadata.txt", mimeType: "text/plain")
                } catch {
                    print(error)
                    fatalError("Failed To Upload")
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
        
        observable.onNext(UploadStatus.init(false, false))
        return Disposables.create()
    }
}


/*
 let jsonTestResponse = """
 {
 "showAllLandmarks": true,
 "showExposureLandmarks": false,
 "showBrightnessLandmarks": false,
 "showBalanceLandmarks": false,
 "showFacingCameraLandmarks": true
 }
 """.data(using: .utf8)
 
 
 let settings = try! JSONDecoder().decode(Settings.self, from: jsonTestResponse!)
 observable.onNext(settings)
 */
