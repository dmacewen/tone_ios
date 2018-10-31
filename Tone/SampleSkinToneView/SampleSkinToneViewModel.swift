//
//  SampleSkinToneViewModel.swift
//  Tone
//
//  Created by Doug MacEwen on 10/30/18.
//  Copyright © 2018 Doug MacEwen. All rights reserved.
//

import Foundation
import RxSwift

class SampleSkinToneViewModel {
    enum Event {
        case cancel
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
            case .tooDark: return "It's A Little Too Dark Here... Lets try again in a room with a bit more light"
            case .tooBright: return "It's A Little Too Bright Here... Try facing away from the brightest light in the room or moving to a darker area"
            case .faceTooFar: return "You're Too Far Away! Bring me closer to your face!"
            case .faceGradient: return "You're Too Unevenly Lit! Try and face away from the brightest light in the room"
            }
        }
    }
    
    //let userPrompt = Variable<String?>(nil)
    let userFaceState = BehaviorSubject<UserFaceStates>(value: .noFaceFound)
    
    let events = PublishSubject<Event>()
        
    func cancel() {
        events.onNext(.cancel)
    }
    
    func sample() {
        print("Gettin that sample")
    }
}
