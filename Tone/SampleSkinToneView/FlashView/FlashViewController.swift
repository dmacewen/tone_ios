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

    @IBOutlet weak var FlashLayer: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Flash Sample Skin Tone"

        self.viewModel!.originalScreenBrightness = UIScreen.main.brightness
        print("Maxing Screen Brightness!")
        UIScreen.main.brightness = CGFloat(1.0)
        
        viewModel!.flashSettingsTaskStream
            .observeOn(MainScheduler.instance)
            .subscribeOn(MainScheduler.instance)
            .subscribe(onNext: { flashSettingTask in
                flashSettingTask.isDone.onNext(false)
                let flashSetting = flashSettingTask.flashSettings
                if flashSetting.areas == 0 {
                    //Return Early if Areas is 0
                    print("Zero Areas Returning Early")
                    return
                }
                let area = flashSetting.area
                let areas = flashSetting.areas
                let screenSize = UIScreen.main.bounds
                
                let checkerSize = 10
                let width = screenSize.width
                let columns = Int((width / CGFloat(checkerSize)))
                
                let height = screenSize.height
                let rows = Int((height / CGFloat(checkerSize)))
                
                print("Setting Flash! Area: \(area) Areas: \(areas)")
                
                //let renderer = UIGraphicsImageRenderer(size: CGSize(width: (columns * checkerSize), height: (rows * checkerSize)))
                //Replace with Checkerboard CIFilter?
                let img = self.viewModel!.renderer.image { ctx in
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
                    print("Done Rendering!")
                }
                
                self.FlashLayer.image = img
                self.FlashLayer.setNeedsDisplay()
                print("Animating?? :: \(self.FlashLayer.isAnimating)")
                print("Done Drawing!")
                flashSettingTask.isDone.onNext(true)
                
                /*
                 DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                 flashSettingTask.isDone.onNext(true)
                 }
                 */
                
                //flashSettingTask.isDone.onCompleted()
            }).disposed(by: disposeBag)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        UIScreen.main.brightness = self.viewModel!.originalScreenBrightness
    }
}
