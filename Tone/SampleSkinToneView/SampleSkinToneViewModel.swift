//
//  SampleSkinToneViewModel.swift
//  Tone
//
//  Created by Doug MacEwen on 10/30/18.
//  Copyright © 2018 Doug MacEwen. All rights reserved.
//

import Foundation
//import Foundation.NSTimer

import RxSwift

import AVFoundation
import UIKit
//import Alamofire
//import RxAlamofire
//import Compression

class SampleSkinToneViewModel {
    enum Event {
        case cancel
    }
    
    enum SampleStates {
        case previewUser
        case referenceSample
        case sample
        case upload
    }
    
    enum UserFaceStates {
        case ok
        case noFaceFound
        case tooDark
        case tooBright
        case faceGradient
        case faceTooFar
        
        var message: String {
            switch self {
            case .ok: return "Looking Good!"
            case .noFaceFound: return "Looking For You..."
            case .tooDark: return "It's A Little Too Dark Here..."// Lets try again in a room with a bit more light"
            case .tooBright: return "It's A Little Too Bright Here..."// Try facing away from the brightest light in the room or moving to a darker area"
            case .faceTooFar: return "You're Too Far Away!"// Bring me closer to your face!"
            case .faceGradient: return "You're Too Unevenly Lit!"// Try and face away from the brightest light in the room"
            }
        }
    }
    
    let userFaceState = BehaviorSubject<UserFaceStates>(value: .ok/*.noFaceFound*/)
    let sampleState = BehaviorSubject<SampleStates>(value: .previewUser)
    
    let referencePhotos = PublishSubject<AVCapturePhoto>()
    let samplePhotos = PublishSubject<AVCapturePhoto>()
    
    let flashSettings = PublishSubject<FlashSettings>()
    
    let events = PublishSubject<Event>()
    
    var originalScreenBrightness: CGFloat = 0.0
    var camera: Camera
        
    init() {
        camera = Camera(flashStream: flashSettings)
        print("finished setup")
    }
    
    func cancel() {
        events.onNext(.cancel)
    }
}


