//
//  CaptureSessionMirrorViewModel.swift
//  Tone
//
//  Created by Doug MacEwen on 8/26/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation
import RxSwift
import AVFoundation
import Alamofire
import Vision
import UIKit

class CaptureSessionMirrorViewModel: ViewModel {
    enum Event {
        case cancel
        case showHelp
        case done
    }
    
    let events = PublishSubject<Event>()

    var videoSize = CGSize.init(width: 0, height: 0)
    lazy var cameraState: CameraState = CameraState(flashTaskStream: nil)
    lazy var video: Video = Video(cameraState: self.cameraState, shouldProcessRealtime: BehaviorSubject<ProcessRealtime>(value: .no))
    
    var disposeBag = DisposeBag()
    
    //Shared Between Flash and Draw Overlay
    let videoOverlayRenderer = UIGraphicsImageRenderer(size: UIScreen.main.bounds.size)
    
    override func afterLoad() {
        print("After Capture Session Mirror View Model Loads")
    }
    
    func cancel() {
        events.onNext(.cancel)
    }
    
    func done() {
        events.onNext(.done)
    }
    
    func showHelp() {
        events.onNext(.showHelp)
    }
    
    deinit {
        print("DESTROYING apture Session Mirror View Model")
    }
}
