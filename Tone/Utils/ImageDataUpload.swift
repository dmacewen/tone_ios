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

func uploadImageData(imageData: [ImageData], progressBar: BehaviorSubject<Float>) -> Observable<Bool> {
    
    let url = "http://macewen.io/users/doug/selfie"
    
    let headers: HTTPHeaders = [
        /* "Authorization": "your_access_token",  in case you need authorization header */
        "Content-type": "multipart/form-data"
    ]
    
    return Observable.create { observable in
        
        Alamofire.upload(
            multipartFormData: { multipartFormData in
                let metaData: [MetaData] = imageData.map { $0.metaData }
                for (index, imageDatum) in imageData.enumerated() {
                    //let pngData = imageDatum.image.pngData()
                    let pngData = imageDatum.imageData
                    let imageName = String(index + 1)
                    multipartFormData.append(pngData, withName: imageName, fileName: "\(imageName).png", mimeType: "image/png")
                }
                
                do {
                    let jsonData = try JSONEncoder().encode(metaData)
                    let jsonString = String(data: jsonData, encoding: .utf8)!
                    //print("METADATA JSON :: \(jsonString)")
                    
                    //let decodedSentences = try JSONDecoder().decode([MetaData].self, from: jsonData)
                    //print(decodedSentences)
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


