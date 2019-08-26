//
//  serialMap.swift
//  Tone
//
//  Created by Doug MacEwen on 11/2/18.
//  Copyright © 2018 Doug MacEwen. All rights reserved.
//
/*

import Foundation
import RxSwift
import RxRelay
import RxAtomic
import RxBlocking

struct Task<E, R> {
    let task: E
    let callback = PublishSubject<R>()
}

extension ObservableType {
    //Takes a function that returns an observable
    //Waits for the observable of that function to complete, emitting the result, before processing the next
    func serialMap<R>(_ transform: @escaping (E) -> Observable<R>) -> Observable<R> {
        let disposeBag = DisposeBag()
        
        //var taskQueue: [Task<E, R>] = []
        var taskQueue: [E] = []

        //var completedCallback = BehaviorSubject<Bool>(value: false)
        //let worker = PublishSubject<Task<E, R>>()
        let worker = PublishSubject<E>()
        
        func addTask(task: E) {
            DispatchQueue.main.async {
                taskQueue.append(task)
                //If there is nothing being processed, start process with current tast
                if taskQueue.count == 1 {
                    worker.onNext(taskQueue.first!)
                }
            }
        }
        
        /*
        func addTask(task: E) -> PublishSubject<R> {
            return DispatchQueue.main.async {
                let newTask = Task<E, R>(task: task)
                taskQueue.append(newTask)
                
                //If there is nothing being processed, start process with current tast
                if taskQueue.count == 1 {
                    worker.onNext(taskQueue.first!)
                }
                
                return newTask.callback
            }
        }
        
        worker.asObservable()
            .subscribe(onNext: { task in
                    transform(task.task)
                        .single()
                        .subscribe(
                            onNext: { value in
                                taskQueue.first!.callback.onNext(value)
                                //callbackQueue[0].onNext(value)
                            }, onCompleted: {
                                let task = taskQueue.removeFirst()
                                task.callback.onCompleted()
                                if !taskQueue.isEmpty {
                                    worker.onNext(taskQueue.first!)
                                } else {
                                    if try! completedCallback.value() {
                                        completedCallback.onCompleted()
                                    }
                                }
                        }).disposed(by:disposeBag)
            })
            .disposed(by: disposeBag)
        */
        /*
        worker.asObservable()
            .flatMap { task in transform(task) }
            .concatMap(<#T##selector: (R) throws -> ObservableConvertibleType##(R) throws -> ObservableConvertibleType#>)
            .do(onNext: { _ in
                DispatchQueue.main.async {
                    taskQueue.removeFirst()
                    guard let nextTask = taskQueue.first else {
                        return
                    }
                    worker.onNext(nextTask)
                }
            }).share()
 */
/*
        return Observable.create { observer in
            let subscription = self
                //.observeOn(MainScheduler.instance)
                //.subscribeOn(MainScheduler.instance)
                .subscribe { e in
                switch e {
                case .next(let value):
                    print("Adding Task!")
                    addTask(task: value)
                        .subscribe(onNext: { result in
                            observer.on(.next(result))
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
        */
        /*
        return Observable.create { observer in
            let subscription = self
                //.observeOn(MainScheduler.instance)
                //.subscribeOn(MainScheduler.instance)
                .subscribe { e in
                    switch e {
                    case .next(let value):
                        print("Adding Task!")
                        addTask(task: value)
                        worker
                            .subscribe(onNext: { result in
                                observer.on(.next(result))
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
 */
}
extension ObservableType {
    func toArrayOfSize(_ size: Int) -> Single<[Element]> {
        return PrimitiveSequence(raw: ToArray(source: self.asObservable()))
    }
}

final private class ToArraySink<SourceType, Observer: ObserverType>: Sink<Observer>, ObserverType where Observer.Element == [SourceType] {
    typealias Parent = ToArray<SourceType>
    
    let _parent: Parent
    var _list = [SourceType]()
    
    init(parent: Parent, observer: Observer, cancel: Cancelable) {
        self._parent = parent
        
        super.init(observer: observer, cancel: cancel)
    }
    
    func on(_ event: Event<SourceType>) {
        switch event {
        case .next(let value):
            self._list.append(value)
        case .error(let e):
            self.forwardOn(.error(e))
            self.dispose()
        case .completed:
            self.forwardOn(.next(self._list))
            self.forwardOn(.completed)
            self.dispose()
        }
    }
}

final private class ToArray<SourceType>: Producer<[SourceType]> {
    let _source: Observable<SourceType>
    
    init(source: Observable<SourceType>) {
        self._source = source
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == [SourceType] {
        let sink = ToArraySink(parent: self, observer: observer, cancel: cancel)
        let subscription = self._source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
 */
