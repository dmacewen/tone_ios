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
    var flashRenderer: UIGraphicsImageRenderer?
    var flashSize: CGSize?
    @IBOutlet weak var FlashHostLayer: UIView!

    
    override func viewDidLoad() {
        print("VIEW LOADED!")
        super.viewDidLoad()
        title = "Flash Sample Skin Tone"
        
        self.flashSize = FlashHostLayer.bounds.size
        self.flashRenderer = UIGraphicsImageRenderer(size: self.flashSize!)
      
        self.viewModel!.originalScreenBrightness = UIScreen.main.brightness
        print("Maxing Screen Brightness!")
        UIScreen.main.brightness = CGFloat(1.0)
        
        self.viewModel!.flashSettingsTaskStream
            .flatMap { flashSettingTask -> Observable<FlashSettingsTask> in
                
                print("Received Flash Task!")
      
                return self.getUILayer(for: flashSettingTask.flashSettings)
                    .flatMap { currentFlashLayer in self.addToParent(currentFlashLayer) }
                    .single()
                    .map { _ in flashSettingTask }
            }
            .subscribe(onNext: { flashSettingTask in
                flashSettingTask.isDone.onNext(true)
                flashSettingTask.isDone.onCompleted()
            }).disposed(by: self.disposeBag)
    }
    
    private func getUILayer(for flashSetting: FlashSettings) -> Observable<UIImageView> {
        return Observable<UIImageView>.create { observable in
            let img = self.getFlashImage(flashSetting: flashSetting)
            //DispatchQueue.main.async {
                observable.onNext(UIImageView(image: img))
                observable.onCompleted()
            //}
            return Disposables.create()
        }
    }
    
    private func addToParent(_ currentFlashLayer: UIImageView) -> Observable<UIImageView> {
        return Observable.create { observable in
            //DispatchQueue.main.async {
                CATransaction.begin()
                CATransaction.setCompletionBlock( {
                    //Really just gross.. having a hard time syncing the screen flash with the camera
                    //DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        observable.onNext(currentFlashLayer)
                        observable.onCompleted()
                    //}
                })
                self.FlashHostLayer.layer.insertSublayer(currentFlashLayer.layer, above: self.FlashHostLayer.layer)
                self.FlashHostLayer.layer.setNeedsDisplay()
                CATransaction.commit()
                CATransaction.flush()
            //}
            return Disposables.create()
        }
    }
    
    private func getFlashImage(flashSetting: FlashSettings) -> UIImage {
        let area = flashSetting.area
        let areas = flashSetting.areas
        
        let checkerSize = 10
        let width = self.flashSize!.width
        let columns = Int((width / CGFloat(checkerSize)))
        
        let height = self.flashSize!.height
        let rows = Int((height / CGFloat(checkerSize)))
        
        //Replace with Checkerboard CIFilter?
        let img = self.flashRenderer!.image { ctx in
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
            //Draw Focus Point where we want users to look
            let focusPointY = Int(round(height * 0.2)) - 3
            let focusPointX = Int(width * 0.5) - 3
            ctx.cgContext.setFillColor(UIColor.blue.cgColor)
            ctx.cgContext.fill(CGRect(x: focusPointX, y: focusPointY, width: 7, height: 7))
            
            ctx.cgContext.setFillColor(UIColor.black.cgColor)
            print("Done Rendering Flash \(flashSetting.area) / \(flashSetting.areas)")
        }
        
        return img
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("View Appeared!")
        self.viewModel!.didFlashViewModelAppear.onNext(true)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        UIScreen.main.brightness = self.viewModel!.originalScreenBrightness
    }
}
