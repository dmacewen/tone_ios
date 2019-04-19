//
//  Settings.swift
//  Tone
//
//  Created by Doug MacEwen on 4/17/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation
import RxSwift

class RadioSet {
    var values = [BehaviorSubject<Bool>]()
    private let disposeBag = DisposeBag()
    
    func newField() -> BehaviorSubject<Bool> {
        let id = values.count
        let newRadioValue = BehaviorSubject<Bool>(value: false)
        values.append(newRadioValue)
        
        self.values[id]
            .filter { $0 }
            .subscribe(onNext: { _ in
                for i in 0..<self.values.count {
                    if i != id {
                        self.values[i].onNext(false)
                    }
                }
            })
            .disposed(by: disposeBag)
        
        return newRadioValue
    }
}

class Settings {
    private let landmarkDisplayRadio = RadioSet()
    private let disposeBag = DisposeBag()
    
    let showAllLandmarks: BehaviorSubject<Bool>
    let showExposureLandmarks: BehaviorSubject<Bool>
    let showBalanceLandmarks: BehaviorSubject<Bool>
    let showBrightnessLandmarks: BehaviorSubject<Bool>
    let showFacingCameraLandmarks: BehaviorSubject<Bool>
    
    init() {
        showAllLandmarks = self.landmarkDisplayRadio.newField()
        showExposureLandmarks = self.landmarkDisplayRadio.newField()
        showBalanceLandmarks = self.landmarkDisplayRadio.newField()
        showBrightnessLandmarks = self.landmarkDisplayRadio.newField()
        showFacingCameraLandmarks = self.landmarkDisplayRadio.newField()
    }
}
