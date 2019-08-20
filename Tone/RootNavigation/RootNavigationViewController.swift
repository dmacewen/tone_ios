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
    
    var rootViewModel: RootNavigationViewModel!
    
    private let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Observe navigation actions and adjust the nav stack appropriately
        rootViewModel.navigationStackActions
            .subscribe(onNext: { [weak self] navigationStackAction in
                switch navigationStackAction {
                case .set(let viewModels, let animated):
                    let viewControllers = viewModels.compactMap { viewController(forViewModel: $0) }
                    print("Setting View Controllers!")
                    DispatchQueue.main.async {
                        self?.setViewControllers(viewControllers, animated: animated)
                        DispatchQueue.main.async {
                            viewModels.forEach { viewModel in viewModel.afterLoadHelper() }
                        }
                    }
                    
                case .push(let viewModel, let animated):
                    guard let viewController = viewController(forViewModel: viewModel) else { return }
                    DispatchQueue.main.async { [weak self, weak viewModel] in
                        self?.interactivePopGestureRecognizer?.isEnabled = viewModel!.isCancelable
                        self?.pushViewController(viewController, animated: animated)
                        DispatchQueue.main.async {
                            viewModel!.afterLoadHelper()
                        }
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
                        DispatchQueue.main.async {
                            viewModel.afterLoadHelper()
                        }
                    }
                }
            })
            .disposed(by: disposeBag)
    }
    
}
