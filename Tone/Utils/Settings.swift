//
//  Settings.swift
//  Tone
//
//  Created by Doug MacEwen on 4/17/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation

class RadioValue {
    private var isActive = false
    private let set: RadioSet
    
    var value: Bool {
        get {
            return self.isActive
        }
        set (isActive){
            self.set.clearAll()
            self.isActive = isActive
        }
    }
    
    func clear() {
        self.isActive = false
    }
    
    init(set: RadioSet) {
        self.set = set
    }
}

class RadioSet {
    var values = [RadioValue]()
    
    func clearAll() {
        for i in 0...values.count {
            values[i].clear()
        }
    }
    
    func newField() -> RadioValue {
        let newRadioValue = RadioValue.init(set: self)
        values.append(newRadioValue)
        return newRadioValue
    }
    
}

struct Settings {
    private let landmarkDisplayRadio = RadioSet()
    let showAllLandmarks: RadioValue
    let showExposureLandmarks: RadioValue
    let showBalanceLandmarks: RadioValue
    let showBrightnessLandmarks: RadioValue
    
    init() {
        showAllLandmarks = self.landmarkDisplayRadio.newField()
        showExposureLandmarks = self.landmarkDisplayRadio.newField()
        showBalanceLandmarks = self.landmarkDisplayRadio.newField()
        showBrightnessLandmarks = self.landmarkDisplayRadio.newField()
    }
}
