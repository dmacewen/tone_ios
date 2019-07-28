//
//  ViewModel.swift
//  Tone
//
//  Created by Doug MacEwen on 7/28/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation
//import RxSwift

//protocol Event {}
/*
protocol ViewModel {
    associatedtype Event
    var events: PublishSubject<Event> { get }
    func afterLoad()
}
*/

//protocol Event {}
class ViewModel {
    //enum event: Event {}
    //var events: PublishSubject<T>
    var alreadyLoaded = false
    func afterLoad() {}
}
