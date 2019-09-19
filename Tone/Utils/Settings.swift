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
    
    func newField(_ startingValue: Bool = false) -> BehaviorSubject<Bool> {
        let id = values.count
        let newRadioValue = BehaviorSubject<Bool>(value: startingValue)
        values.append(newRadioValue)
        
        self.values[id]
            .filter { $0 }
            .subscribe(onNext: { [unowned self] _ in
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

//USE ENUM IN SETTINGS? -- Maybe an improvement for later...
class Settings: Codable {
    private let landmarkDisplayRadio = RadioSet()
    private let disposeBag = DisposeBag()
    
    let showAllLandmarks: BehaviorSubject<Bool>
    let showExposureLandmarks: BehaviorSubject<Bool>
    let showBalanceLandmarks: BehaviorSubject<Bool>
    let showBrightnessLandmarks: BehaviorSubject<Bool>
    let showFacingCameraLandmarks: BehaviorSubject<Bool>
    let showEyeExposureLandmarks: BehaviorSubject<Bool>
    
    enum CodingKeys: String, CodingKey {
        case showAllLandmarks
        case showExposureLandmarks
        case showBalanceLandmarks
        case showBrightnessLandmarks
        case showFacingCameraLandmarks
        case showEyeExposureLandmarks
    }
    
    init() {
        showAllLandmarks = self.landmarkDisplayRadio.newField()
        showExposureLandmarks = self.landmarkDisplayRadio.newField()
        showBalanceLandmarks = self.landmarkDisplayRadio.newField()
        showBrightnessLandmarks = self.landmarkDisplayRadio.newField()
        showFacingCameraLandmarks = self.landmarkDisplayRadio.newField()
        showEyeExposureLandmarks = self.landmarkDisplayRadio.newField()
    }
    
    //Decode all settings values. If a value is missing, default to false
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let showAllLandmarksBool = try? container.decode(Bool.self, forKey: .showAllLandmarks) {
            showAllLandmarks = self.landmarkDisplayRadio.newField(showAllLandmarksBool)
        } else {
            showAllLandmarks = self.landmarkDisplayRadio.newField(false)
        }
        
        if let showExposureLandmarksBool = try? container.decode(Bool.self, forKey: .showExposureLandmarks) {
            showExposureLandmarks = self.landmarkDisplayRadio.newField(showExposureLandmarksBool)
        } else {
            showExposureLandmarks = self.landmarkDisplayRadio.newField(false)
        }
        
        if let showBalanceLandmarksBool = try? container.decode(Bool.self, forKey: .showBalanceLandmarks) {
            showBalanceLandmarks = self.landmarkDisplayRadio.newField(showBalanceLandmarksBool)
        } else {
            showBalanceLandmarks = self.landmarkDisplayRadio.newField(false)
        }
        
        if let showBrightnessLandmarksBool = try? container.decode(Bool.self, forKey: .showBrightnessLandmarks) {
            showBrightnessLandmarks = self.landmarkDisplayRadio.newField(showBrightnessLandmarksBool)
        } else {
            showBrightnessLandmarks = self.landmarkDisplayRadio.newField(false)
        }
        
        if let showFacingCameraLandmarksBool = try? container.decode(Bool.self, forKey: .showFacingCameraLandmarks) {
            showFacingCameraLandmarks = self.landmarkDisplayRadio.newField(showFacingCameraLandmarksBool)
        } else {
            showFacingCameraLandmarks = self.landmarkDisplayRadio.newField(false)
        }
        
        if let showEyeExposureLandmarksBool = try? container.decode(Bool.self, forKey: .showEyeExposureLandmarks) {
            showEyeExposureLandmarks = self.landmarkDisplayRadio.newField(showEyeExposureLandmarksBool)
        } else {
            showEyeExposureLandmarks = self.landmarkDisplayRadio.newField(false)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.showAllLandmarks.value(), forKey: .showAllLandmarks)
        try container.encode(self.showExposureLandmarks.value(), forKey: .showExposureLandmarks)
        try container.encode(self.showBalanceLandmarks.value(), forKey: .showBalanceLandmarks)
        try container.encode(self.showBrightnessLandmarks.value(), forKey: .showBrightnessLandmarks)
        try container.encode(self.showFacingCameraLandmarks.value(), forKey: .showFacingCameraLandmarks)
    }
}
