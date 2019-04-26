//
//  FlashUIImageView.swift
//  Tone
//
//  Created by Doug MacEwen on 4/24/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//
/*
import UIKit
import RxSwift

class FlashUIImageView: UIImageView {
    let isInSuperview = BehaviorSubject<Bool>(value: false)
    
    override func didMoveToSuperview() {
        //Just... gah... annoyingly cant sync the screen rendering and the camera flash
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        //DispatchQueue.main.async {
            print("In Superview!")
            self.isInSuperview.onNext(true)
        }
        super.didMoveToSuperview()
    }
    
    override func didMoveToWindow() {
        print("Moved to window...")
        super.didMoveToWindow()
    }
}
*/
