//
//  CaptureSession.swift
//  Tone
//
//  Created by Doug MacEwen on 7/23/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation

struct CaptureSession: Codable {
    let out_of_date: Bool
    let session_id: Int32
    let skin_color_id: Int32
    let start_date: Date
    let now: Date?
}
