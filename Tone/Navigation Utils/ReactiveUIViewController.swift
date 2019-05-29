//
//  ReactiveUIViewController.swift
//  Tone
//
//  Created by Doug MacEwen on 4/22/19.
//  Copyright © 2019 Doug MacEwen. All rights reserved.
//

import Foundation
import UIKit

class ReactiveUIViewController: UIViewController {
    weak var viewModel: SampleSkinToneViewModel?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
