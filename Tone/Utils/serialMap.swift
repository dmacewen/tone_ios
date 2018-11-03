//
//  bufferedComplete.swift
//  Tone
//
//  Created by Doug MacEwen on 11/2/18.
//  Copyright © 2018 Doug MacEwen. All rights reserved.
//

import Foundation
import RxSwift

extension ObservableType {
    //Takes a function that returns an observable
    //Waits for the observable of that function to complete, emitting the result, before processing the next
    func serialMap<R>(transform: @escaping (E) -> R) -> Observable<R> {
        let disposeBag = DisposeBag()
        var taskQueue: [PublishSubject<E>] = []
        let workerA = PublishSubject<PublishSubject<E>>()
        let workerB = PublishSubject<PublishSubject<E>>()
        let results = PublishSubject<E>()
        
        workerA.asObservable()
            .subscribe(onNext: {
                $0.subscribe(
                    onNext: { value in
                        results.onNext(value)
                }, onCompleted: {
                    taskQueue.removeFirst()
                    if !taskQueue.isEmpty {
                        workerB.onNext(taskQueue.first!)
                    }
                }).disposed(by:disposeBag)
            })
            .disposed(by: disposeBag)
        
        workerB.asObservable()
            .subscribe(onNext: {
                $0.subscribe(
                    onNext: { value in
                        results.onNext(value)
                }, onCompleted: {
                    taskQueue.removeFirst()
                    if !taskQueue.isEmpty {
                        workerA.onNext(taskQueue.first!)
                    }
                }).disposed(by:disposeBag)
            })
            .disposed(by: disposeBag)
        
        return Observable.create { observer in
            var workQueue:[E] = []
            let subscription = self.subscribe { e in
                switch e {
                case .next(let value):
                    let result = transform(value) //Returns observable
                    
                    observer.on(.next(result))
                case .error(let error):
                    observer.on(.error(error))
                case .completed:
                    observer.on(.completed)
                }
            }
            
            return subscription
        }
    }

    func myMap<R>(transform: @escaping (E) -> R) -> Observable<R> {
        return Observable.create { observer in
            let subscription = self.subscribe { e in
                switch e {
                case .next(let value):
                    let result = transform(value)
                    observer.on(.next(result))
                case .error(let error):
                    observer.on(.error(error))
                case .completed:
                    observer.on(.completed)
                }
            }
            
            return subscription
        }
    }
}
