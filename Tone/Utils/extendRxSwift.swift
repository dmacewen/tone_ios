//
//  extendRxSwift.swift
//  Tone
//
//  Created by Doug MacEwen on 11/2/18.
//  Copyright © 2018 Doug MacEwen. All rights reserved.
//

import Foundation
import RxSwift

extension ObservableType {
    //Waits for each item to complete before running the next
    func serialMap<R>(waitFor: @escaping (E) -> R) -> Observable<R> {
        let subscription = self.subscribe { e in
            switch e {
            case .next(let value):
                waitFor(value)
                observer.on(.next(value))
            }
        }
    }
}
