//
//  RootViewController.swift
//  Tone
//
//  Created by Doug MacEwen on 10/29/18.
//  Copyright © 2018 Doug MacEwen. All rights reserved.
//

import Foundation
import UIKit
import RxSwift

class RootNavigationViewController: UINavigationController {
    
    var viewModel: RootNavigationViewModel!
    
    private let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Observe navigation actions and adjust the nav stack appropriately
        viewModel.navigationStackActions
            .subscribe(onNext: { [weak self] navigationStackAction in
                switch navigationStackAction {
                case .set(let viewModels, let animated):
                    let viewControllers = viewModels.compactMap { viewController(forViewModel: $0) }
                    print("Setting View Controllers!")
                    DispatchQueue.main.async {
                        self?.setViewControllers(viewControllers, animated: animated)
                    }
                    
                case .push(let viewModel, let animated):
                    guard let viewController = viewController(forViewModel: viewModel) else { return }
                    DispatchQueue.main.async {
                        self?.pushViewController(viewController, animated: animated)
                    }
                
                case .pop(let animated):
                    DispatchQueue.main.async {
                        _ = self?.popViewController(animated: animated)
                    }
                    
                case .swap(let viewModel, _):
                    //Maybe just:
                    //self?.popViewController(animated: animated)
                    guard let viewController = viewController(forViewModel: viewModel) else { return }
                    DispatchQueue.main.async {
                        self?.viewControllers[self!.viewControllers.count - 1] = viewController
                    }

                        //self?.pushViewController(viewController, animated: animated)
                    //}
                }
            })
            .disposed(by: disposeBag)
    }
    
}
