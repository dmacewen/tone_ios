//
//  ProcessViewController.swift
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

class ProcessViewController: ReactiveUIViewController<SampleSkinToneViewModel> {
    @IBOutlet weak var processSpinner: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Process Sample Skin Tone"
        self.processSpinner.startAnimating()
    }
}
