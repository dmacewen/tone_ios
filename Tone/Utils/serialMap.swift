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
    func serialMap<R>(transform: @escaping (E) -> PublishSubject<R>) -> Observable<R> {
        let disposeBag = DisposeBag()
        
        var taskQueue: [E] = []
        var callbackQueue: [PublishSubject<[R]>] = []
        var completedCallback = PublishSubject<Bool>()

        let workerA = PublishSubject<E>()
        let workerB = PublishSubject<E>()
        
        func addTask(task: E) -> PublishSubject<[R]> {
            taskQueue.append(task)
            let callback = PublishSubject<[R]>()
            callbackQueue.append(callback)
            
            //If there is nothing being processed, start process with current tast
            if taskQueue.count == 1 {
                workerA.onNext(taskQueue.first!)
            }
            
            return callback
        }
        
        workerA.asObservable()
            .subscribe(onNext: { arg in
                transform(arg)
                    .observeOn(MainScheduler.instance)
                    .subscribeOn(MainScheduler.instance)
                    .toArray()
                    .subscribe(
                        onNext: { value in
                            print("On Next A :: \(value)")
                            callbackQueue[0].onNext(value)
                        }, onCompleted: {
                            print("On Completed A")
                            taskQueue.removeFirst()
                            let callback = callbackQueue.removeFirst()
                            if !taskQueue.isEmpty {
                                workerB.onNext(taskQueue.first!)
                            } else {
                                completedCallback.onCompleted()
                            }
                            callback.onCompleted()
                    }).disposed(by:disposeBag)
            })
            .disposed(by: disposeBag)
        
        workerB.asObservable()
            .subscribe(onNext: { arg in
                transform(arg)
                    .observeOn(MainScheduler.instance)
                    .subscribeOn(MainScheduler.instance)
                    .toArray()
                    .subscribe( onNext: { value in
                        print("On Next B :: \(value)")
                        callbackQueue[0].onNext(value)
                    }, onCompleted: {
                        print("On Completed B")
                        taskQueue.removeFirst()
                        let callback = callbackQueue.removeFirst()
                        if !taskQueue.isEmpty {
                            workerA.onNext(taskQueue.first!)
                        } else {
                            completedCallback.onCompleted()
                        }
                        callback.onCompleted()
                    }).disposed(by:disposeBag)
            })
            .disposed(by: disposeBag)
        
        return Observable.create { observer in
            let subscription = self.subscribe { e in
                switch e {
                case .next(let value):
                    print("Adding New Task :: \(value)")
                    addTask(task: value)
                        .observeOn(MainScheduler.instance)
                        .subscribe(onNext: { result in
                            print("RESULT:: \(result)")
                            observer.on(.next(result[0]))
                        }).disposed(by: disposeBag)
                case .error(let error):
                    observer.on(.error(error))
                case .completed:
                    completedCallback.subscribe(onCompleted: { observer.on(.completed) }).disposed(by: disposeBag)
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
