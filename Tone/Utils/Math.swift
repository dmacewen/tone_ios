//
//  math.swift
//  Tone
//
//  Created by Doug MacEwen on 5/23/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation

func median(_ array: [Float]) -> Float {
    let sorted = array.sorted()
    if sorted.count % 2 == 0 {
        return Float((sorted[(sorted.count / 2)] + sorted[(sorted.count / 2) - 1])) / 2
    } else {
        return Float(sorted[(sorted.count - 1) / 2])
    }
}

func average(_ array: [Float]) -> Float {
    return array.reduce(0, +) / Float(array.count)
}
