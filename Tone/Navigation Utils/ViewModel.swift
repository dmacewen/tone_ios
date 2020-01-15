//
//  ViewModel.swift
//  Tone
//
//  Created by Doug MacEwen on 7/28/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation

class ViewModel {

    var alreadyLoaded = false
    var isCancelable = true
    
    func afterLoadHelper() {
        if !alreadyLoaded {
            self.afterLoad()
        }
        
        alreadyLoaded = true
    }
    
    func afterLoad() {}
}
