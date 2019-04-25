//
//  FlashViewController.swift
//  Tone
//
//  Created by Doug MacEwen on 4/22/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit
import RxSwift
import RxCocoa

class FlashViewController: ReactiveUIViewController<SampleSkinToneViewModel> {
    //var viewModel: SampleSkinToneViewModel!
    let disposeBag = DisposeBag()

    @IBOutlet weak var ParentLayer: UIView!
    @IBOutlet weak var FlashHostLayer: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Flash Sample Skin Tone"
        
        let flashRenderer = UIGraphicsImageRenderer(size: FlashHostLayer.bounds.size)
      
        self.viewModel!.originalScreenBrightness = UIScreen.main.brightness
        print("Maxing Screen Brightness!")
        UIScreen.main.brightness = CGFloat(1.0)
        
        self.viewModel!.flashSettingsTaskStream
            .subscribe(onNext: { flashSettingTask in
                
                print("Received Flash Task!")
      
                self.getUILayer(for: flashSettingTask.flashSettings, renderer: flashRenderer)
                    .flatMap { currentFlashLayer in self.addToParent(currentFlashLayer) }
                    //.flatMap { currentFlashLayer in currentFlashLayer.isInSuperview }
                    //.do(onNext: { isInSuperview in print("Is in superview??? :: \(isInSuperview)")})
                    //.filter { $0 }
                    //.take(1)
                    .single()
                    .subscribe(onNext: { isVisible in
                        flashSettingTask.isDone.onNext(true)
                        flashSettingTask.isDone.onCompleted()
                }).disposed(by: self.disposeBag)
                
            }).disposed(by: self.disposeBag)
    }
    
    private func getUILayer(for flashSetting: FlashSettings, renderer: UIGraphicsImageRenderer) -> Observable<UIImageView> {
        return Observable<UIImageView>.create { observable in
            DispatchQueue.main.async {
                let img = getFlashImage(flashSetting: flashSetting, size: self.FlashHostLayer.bounds.size, renderer: renderer)
                //observable.onNext(FlashUIImageView(image: img))
                observable.onNext(UIImageView(image: img))
                observable.onCompleted()
            }
            return Disposables.create()
        }
    }
    
    private func addToParent(_ currentFlashLayer: UIImageView) -> Observable<UIImageView> {
        return Observable.create { observable in
            DispatchQueue.main.async {
                CATransaction.begin()
                CATransaction.setCompletionBlock( {
                    //Really just gross.. having a hard time syncing the screen flash with the camera
                    //DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        //currentFlashLayer.didMoveToSuperview()
                        observable.onNext(currentFlashLayer)
                        observable.onCompleted()
                    //}
                })
                self.ParentLayer.layer.insertSublayer(currentFlashLayer.layer, above: self.ParentLayer.layer)
                self.ParentLayer.layer.setNeedsDisplay()
                //currentFlashLayer.layer.setNeedsDisplay()
                CATransaction.commit()
                CATransaction.flush()
                
                //self.ParentLayer.bringSubviewToFront(currentFlashLayer)
                
            }
            return Disposables.create()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("View Appeared!")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        UIScreen.main.brightness = self.viewModel!.originalScreenBrightness
    }
}
