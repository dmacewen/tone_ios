//
//  LoginViewController.swift
//  Tone
//
//  Created by Doug MacEwen on 10/29/18.
//  Copyright © 2018 Doug MacEwen. All rights reserved.
//

import Foundation
import UIKit
import RxSwift
import RxCocoa

class LoginViewController: UIViewController {
    var viewModel: LoginViewModel!
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!

    @IBOutlet weak var emailText: UITextField!
    @IBOutlet weak var passwordText: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var loginFields: UIView!
    
    @IBOutlet weak var constraintContentHeight: NSLayoutConstraint!
    
    private let disposeBag = DisposeBag()
    private let backgroundRed = UIColor.init(red: 248/255, green: 131/255, blue: 121/255, alpha: 1)
    private let backgroundWhite = UIColor.white

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Log In"
        
        keyboardHeight()
            .subscribe(onNext: { height in
                self.constraintContentHeight.constant = height * 1.1
            }).disposed(by: disposeBag)
        
        let tapGesture = UITapGestureRecognizer()
        contentView.addGestureRecognizer(tapGesture)
        
        tapGesture.rx.event
            .bind(onNext: { recognizer in
                self.emailText.resignFirstResponder()
                self.passwordText.resignFirstResponder()
            }).disposed(by: disposeBag)
        
        emailText.rx.text
            .bind(to: viewModel.email)
            .disposed(by: disposeBag)
 
        passwordText.rx.text
            .bind(to: viewModel.password)
            .disposed(by: disposeBag)
        
        let validLogin = loginButton.rx.tap.single(viewModel.isEmailValid)
        
        validLogin.subscribe(onNext: { _ in
                self.emailText.backgroundColor = self.backgroundWhite
                self.viewModel.login()
            }).disposed(by: disposeBag)
        
        loginButton.rx.tap
            .takeUntil(validLogin)
            .bind(onNext: {
                self.emailText.backgroundColor = self.backgroundRed
            }).disposed(by: disposeBag)
    }
}
