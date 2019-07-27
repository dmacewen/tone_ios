//
//  CaptureSession.swift
//  Tone
//
//  Created by Doug MacEwen on 7/23/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation

class CaptureSession: Codable {
    let out_of_date: Bool
    let session_id: Int32
    let skin_color_id: Int32
    let start_date: Date
    let now: Date?
    
    enum CodingKeys: String, CodingKey {
        case out_of_date
        case session_id
        case skin_color_id
        case start_date
        case now
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dateFormatter = ISO8601DateFormatter.init()
        dateFormatter.formatOptions = [
            .withFullDate,
            .withDashSeparatorInDate,
            .withTime,
            .withFractionalSeconds,
            .withSpaceBetweenDateAndTime,
            .withColonSeparatorInTime ]
        

        self.out_of_date = try container.decode(Bool.self, forKey: .out_of_date)
        self.session_id = try container.decode(Int32.self, forKey: .session_id)
        self.skin_color_id = try container.decode(Int32.self, forKey: .skin_color_id)
        
        let start_date_string = try container.decode(String.self, forKey: .start_date)
        self.start_date = dateFormatter.date(from: start_date_string)!
        
        let now_date_string = try container.decode(String.self, forKey: .now)
        self.now = dateFormatter.date(from: now_date_string)!
    }
    
    func isValid() -> Bool {
        if out_of_date {
            print("Capture Session Out Of Date (Set by server)")
            return false
        }
        
        let maximumSessionLength = TimeInterval.init(exactly: (60))!// * 60 * 24))! //One day. Interval measured in seconds.
        
        if now! > (start_date + maximumSessionLength) {
            print("Session Expired")
            return false
        }
        
        return true
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.out_of_date, forKey: .out_of_date)
        try container.encode(self.session_id, forKey: .session_id)
        try container.encode(self.skin_color_id, forKey: .skin_color_id)
        try container.encode(self.start_date, forKey: .start_date)
        //try container.encode(self.now!, forKey: .now) //I dont think this is necissary. Just needed to check if the session has expired
    }
}
