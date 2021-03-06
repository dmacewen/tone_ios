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

class FlashViewController: ReactiveUIViewController {
    let disposeBag = DisposeBag()

    @IBOutlet weak var FlashHostLayer: UIView!
    @IBOutlet weak var FlashProgressIndicator: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Flash Sample Skin Tone"
        
        let flashRenderer = UIGraphicsImageRenderer(size: FlashHostLayer.bounds.size)

        self.viewModel!.flashSettingsTaskStream
            .observeOn(MainScheduler.asyncInstance)
            .do(onNext: { _ in UIScreen.main.brightness = CGFloat(1.0) })
            .flatMap { [unowned self] flashSettingTask in self.getUILayer(for: flashSettingTask, renderer: flashRenderer) }
            .flatMap { [unowned self] (flashSettingTask, currentFlashLayer) in self.addToParent(flashSettingTask, currentFlashLayer) }
            .subscribe(onNext: { (flashSettingTask, currentFlashLayer) in
                flashSettingTask.isDone.onNext(true)
                flashSettingTask.isDone.onCompleted()
        }).disposed(by: self.disposeBag)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.viewModel!.didFlashViewLoad.onNext(true)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        UIScreen.main.brightness = self.viewModel!.originalScreenBrightness
    }
    
    private func getUILayer(for flashSettingTask: FlashSettingsTask, renderer: UIGraphicsImageRenderer) -> Observable<(FlashSettingsTask, UIImageView)> {
        return Observable<(FlashSettingsTask, UIImageView)>.create { observable in
            let img = self.getFlashImage(flashSetting: flashSettingTask.flashSettings, renderer: renderer)
            observable.onNext((flashSettingTask, UIImageView(image: img)))
            observable.onCompleted()
            return Disposables.create()
        }
    }
    
    private func addToParent(_ flashSettingTask: FlashSettingsTask, _ currentFlashLayer: UIImageView) -> Observable<(FlashSettingsTask, UIImageView)> {
        return Observable.create { observable in
            self.FlashHostLayer.layer.insertSublayer(currentFlashLayer.layer, above: self.FlashHostLayer.layer)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("Done adding to parent")
                observable.onNext((flashSettingTask, currentFlashLayer))
                observable.onCompleted()
            }

            return Disposables.create()
        }
    }
    
    private func getFlashImage(flashSetting: FlashSettings, renderer: UIGraphicsImageRenderer) -> UIImage {
        let area = flashSetting.area
        let areas = flashSetting.areas
        
        FlashProgressIndicator.text = "\(15 - area) / 8"
        
        let checkerSize = 10
        let width = self.FlashHostLayer.bounds.size.width
        let columns = Int((width / CGFloat(checkerSize)))
        
        let height = self.FlashHostLayer.bounds.size.height
        let rows = Int((height / CGFloat(checkerSize)))
        
        let img = renderer.image { ctx in
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            ctx.cgContext.fill(CGRect(x: 0, y: 0, width: width, height: height))
            
            ctx.cgContext.setFillColor(UIColor.black.cgColor)
            
            let whiteRatio = area
            let blackRatio = areas - area
            let numLocations = rows * columns
            
            var location = 0
            var white = whiteRatio
            var black = blackRatio
            
            while location <= numLocations {
                
                if white > 0 {
                    location += 1
                    white -= 1
                }
                
                if black > 0 {
                    let row = location / columns
                    let column = location % columns
                    ctx.cgContext.fill(CGRect(x: (column * checkerSize), y: (row * checkerSize), width: checkerSize, height: checkerSize))
                    
                    location += 1
                    black -= 1
                }
                
                if (white == 0) && (black == 0) {
                    white = whiteRatio
                    black = blackRatio
                }
            }
            
            ctx.cgContext.setFillColor(UIColor.black.cgColor)
            print("Done Rendering Flash \(flashSetting.area) / \(flashSetting.areas)")
        }
        
        return img
    }
}
