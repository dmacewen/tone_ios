//
//  ImageDataUpload.swift
//  Tone
//
//  Created by Doug MacEwen on 11/5/18.
//  Copyright © 2018 Doug MacEwen. All rights reserved.
//

import Foundation
import Alamofire
import RxSwift

func uploadImageData(imageData: [ImageData], progressBar: BehaviorSubject<Float>, user: User) -> Observable<Bool> {
    
    let userid = user.email
    let url = "http://macewen.io/users/\(userid)/selfie"
    
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
                        observable.onNext(true)
                        observable.onCompleted()
                    }
                    upload.uploadProgress { progress in
                        progressBar.onNext(Float(progress.fractionCompleted))
                        //self.taskProgress.setProgress(Float(progress.fractionCompleted), animated: true)
                    }
                case .failure(let error):
                    print("Error in upload: \(error.localizedDescription)")
                    observable.onError(error)
                }
            }
        )
        
        return Disposables.create()
    }
}


