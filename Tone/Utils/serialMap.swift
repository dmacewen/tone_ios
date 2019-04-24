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
        print("New Serial Map!")
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
        
        let captureDispatchQueue = DispatchQueue.init(label: "CaptureDispatchQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .inherit)

        workerA.asObservable()
            //.observeOn(MainScheduler.instance)
            //.subscribeOn(MainScheduler.instance)
            .subscribe(onNext: { arg in
                //NSLog("Start")
                print("Starting Task on A!")
                captureDispatchQueue.async {
                    transform(arg)
                        //.observeOn(MainScheduler.instance)
                        //.subscribeOn(MainScheduler.instance)
                        .toArray()
                        .subscribe(
                            onNext: { value in
                                print("Done on A")
                                callbackQueue[0].onNext(value)
                            }, onCompleted: {
                                //NSLog("End")
                                print("Completed on A")
                                taskQueue.removeFirst()
                                let callback = callbackQueue.removeFirst()
                                if !taskQueue.isEmpty {
                                    workerB.onNext(taskQueue.first!)
                                }
                                callback.onCompleted()
                        }).disposed(by:disposeBag)
                }
            })
            .disposed(by: disposeBag)
        
        workerB.asObservable()
            //.observeOn(MainScheduler.instance)
            //.subscribeOn(MainScheduler.instance)
            .subscribe(onNext: { arg in
                //NSLog("Start")
                print("Starting Task on B!")
                captureDispatchQueue.async {
                    transform(arg)
                        //.observeOn(MainScheduler.instance)
                        //.subscribeOn(MainScheduler.instance)
                        .toArray()
                        .subscribe( onNext: { value in
                            print("Done on B")
                            callbackQueue[0].onNext(value)
                        }, onCompleted: {
                            //NSLog("End")
                            print("Completed on B")
                            taskQueue.removeFirst()
                            let callback = callbackQueue.removeFirst()
                            if !taskQueue.isEmpty {
                                workerA.onNext(taskQueue.first!)
                            }
                            callback.onCompleted()
                        }).disposed(by:disposeBag)
                }
            })
            .disposed(by: disposeBag)
        
        return Observable.create { observer in
            print("Serial Map -> new observable")
            let subscription = self
                .observeOn(MainScheduler.instance)
                .subscribeOn(MainScheduler.instance)
                .subscribe { e in
                switch e {
                case .next(let value):
                    print("Adding Task!")
                    addTask(task: value)
                        //.observeOn(MainScheduler.instance)
                        //.subscribeOn(MainScheduler.instance)
                        .subscribe(onNext: { result in
                            observer.on(.next(result[0]))
                            
                            if taskQueue.isEmpty {
                                completedCallback.onCompleted()
                            }
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
 
 
    /*
    func serialFlatMap<R>(_ transform: @escaping (E) -> Observable<R>) -> Observable<R> {
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
    /*
    func serialDo<R>(_ transform: @escaping (E) -> Observable<R>) -> Observable<E> {
        print("New Serial Do!")
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
    /*
    func serialMap2<R>(_ transform: @escaping (E) -> Observable<R>) -> Observable<R> {
        print("Setting Up SerialMap2!")
        
        return Observable.create { observer in
            let subscription =
                self.flatMap()
                subscribe(onNext: { args in
                    DispatchQueue.main.sync {
                        transform(args)
                            .subscribe(
                                onNext: {
                                    print("Test")
                                    observer.onNext($0)
                                    observer.onCompleted()
                            }, onCompleted: {
                                print("Completed Serial Map 2 task...")
                            })
                    }
                }, onError: { error in
                    observer.onError(error)
                }, onCompleted: {
                    observer.onCompleted()
                })
            
            return subscription
        }
    }
 
    func serialMap3<R>(_ transform: @escaping (E) -> Observable<R>) -> Observable<R> {
        print("Setting Up SerialMap3!")
        var taskQueue: [E] = []
        
        return Observable.create { observer in
            let subscription = self.subscribe { e in
                switch e {
                case .next(let value):
                    taskQueue.append(value)
                    
                    if taskQueue.isEmpty() {
                        
                    }
                    addTask(task: value)
                        .observeOn(MainScheduler.instance)
                        .subscribeOn(MainScheduler.instance)
                        .subscribe(onNext: { result in
                            observer.on(.next(result[0]))
                            
                            if taskQueue.isEmpty {
                                completedCallback.onCompleted()
                            }
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
 */
}
