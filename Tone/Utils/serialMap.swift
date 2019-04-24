//
//  serialMap.swift
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
    func serialMap<R>(_ transform: @escaping (E) -> Observable<R>) -> Observable<R> {
        let disposeBag = DisposeBag()
        
        var taskQueue: [E] = []
        var callbackQueue: [PublishSubject<R>] = []
        var completedCallback = BehaviorSubject<Bool>(value: false)

        let workerA = PublishSubject<E>()
        let workerB = PublishSubject<E>()
        
        func addTask(task: E) -> PublishSubject<R> {
            taskQueue.append(task)
            let callback = PublishSubject<R>()
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
                        .single()
                        .subscribe(
                            onNext: { value in
                                callbackQueue[0].onNext(value)
                            }, onCompleted: {
                                taskQueue.removeFirst()
                                let callback = callbackQueue.removeFirst()
                                callback.onCompleted()
                                if !taskQueue.isEmpty {
                                    workerB.onNext(taskQueue.first!)
                                } else {
                                    if try! completedCallback.value() {
                                        completedCallback.onCompleted()
                                    }
                                }
                        }).disposed(by:disposeBag)
            })
            .disposed(by: disposeBag)
        
        workerB.asObservable()
            .subscribe(onNext: { arg in
                    transform(arg)
                        .single()
                        .subscribe( onNext: { value in
                            callbackQueue[0].onNext(value)
                        }, onCompleted: {
                            taskQueue.removeFirst()
                            let callback = callbackQueue.removeFirst()
                            callback.onCompleted()
                            if !taskQueue.isEmpty {
                                workerA.onNext(taskQueue.first!)
                            } else {
                                if try! completedCallback.value() {
                                    completedCallback.onCompleted()
                                }
                            }
                        }).disposed(by:disposeBag)
            })
            .disposed(by: disposeBag)
        
        return Observable.create { observer in
            let subscription = self
                .subscribe { e in
                switch e {
                case .next(let value):
                    print("Adding Task!")
                    addTask(task: value)
                        .subscribe(onNext: { result in
                            observer.on(.next(result))

                            /*
                            if taskQueue.isEmpty {
                                if try! completedCallback.value() {
                                    completedCallback.onCompleted()
                                }
                                //completedCallback.onCompleted()
                            }
 */
                        }).disposed(by: disposeBag)
                case .error(let error):
                    observer.on(.error(error))
                case .completed:
                    print("Received Completed Call in Serial Map")
                    completedCallback.onNext(true)
                    if taskQueue.isEmpty {
                        observer.onCompleted()
                    } else {
                        completedCallback
                            .subscribe(onCompleted: { observer.on(.completed) })
                            .disposed(by: disposeBag)
                    }
                }
            }
            
            return subscription
        }
    }
 
   /*
    func serialMap<R>(_ transform: @escaping (E) -> Observable<R>) -> Observable<R> {
        print("New Serial Map!")
        let disposeBag = DisposeBag()
        
        let captureDispatchQueue = DispatchQueue.init(label: "CaptureDispatchQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .inherit)

        return Observable.create { observer in
            print("Serial Flat Map -> new observable")
            let subscription = self.subscribe { e in
                switch e {
                case .next(let value):
                    captureDispatchQueue.async {
                        transform(value)
                            .single()
                            .subscribe(onNext: { result in observer.on(.next(result)) })
                            .disposed(by: disposeBag)
                    }
                case .error(let error):
                    observer.on(.error(error))
                case .completed:
                    captureDispatchQueue.async {
                        observer.on(.completed) }
                    }
                }
            return subscription
        }
    }
 */
}
