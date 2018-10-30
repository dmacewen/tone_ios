//
//  LoginViewController.swift
//  Tone
//
//  Created by Doug MacEwen on 10/29/18.
//  Copyright © 2018 Doug MacEwen. All rights reserved.
//

import Foundation
import UIKit
//import RxSwift

class LoginViewController: UIViewController {
    var viewModel: LoginViewModel!
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!

    @IBOutlet weak var emailText: UITextField!
    @IBOutlet weak var passwordText: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    
    @IBOutlet weak var constraintContentHeight: NSLayoutConstraint!
    
    var activeField: UITextField?
    var lastOffset: CGPoint!
    var currentKeyboardHeight: CGFloat!
    /*
    var activeTextField = BehaviorSubject<UITextField?>(value: nil)
    var isFocusedTextView = BehaviorSubject<Bool>(value: false)
 */
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Log In"
        
        emailText.delegate = self as UITextFieldDelegate
        passwordText.delegate = self as UITextFieldDelegate
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        self.contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(setIsFocusTextView(gesture:))))
 
        /*
        let disposeBag = DisposeBag()

        emailText.rx.controlEvent(.editingDidBegin)
            .subscribe({_ in self.activeTextField.onNext(self.emailText)})
            .disposed(by: disposeBag)
        
        passwordText.rx.controlEvent(.editingDidBegin)
            .subscribe({_ in self.activeTextField.onNext(self.passwordText)})
            .disposed(by: disposeBag)
        
        contentView.
        
        Observable
            .from([emailText.rx.controlEvent(.editingDidEnd), passwordText.rx.controlEvent(.editingDidEnd)])
            .merge()
            .subscribe({_ in self.activeTextField.onNext(nil)})
            .disposed(by: disposeBag)
        
        keyboardHeight()
            .subscribe({height in
                print("Height :: \(height)")
            })
            .disposed(by: disposeBag)
 */
        
    }
    
    @objc func setIsFocusTextView(gesture: UIGestureRecognizer) {
        //isFocusedTextView.onNext(false)
        guard activeField != nil else {
            return
        }
        
        activeField?.resignFirstResponder()
        activeField = nil
    }
}

extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        activeField = textField
        lastOffset = self.scrollView.contentOffset
        return true
    }
    
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        activeField?.resignFirstResponder()
        activeField = nil
        return true
    }
}

extension LoginViewController {
    @objc func keyboardWillShow(notification: NSNotification) {
        
        if currentKeyboardHeight != nil {
            return
        }
        
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            currentKeyboardHeight = keyboardSize.height
            
            UIView.animate(withDuration: 0.3, animations: {
                self.constraintContentHeight.constant += self.currentKeyboardHeight
            })
            
            let distanceToBottom = self.scrollView.frame.size.height - (activeField?.frame.origin.y)! - (activeField?.frame.size.height)!
            let collapseSpace = currentKeyboardHeight - distanceToBottom
            
            if collapseSpace < 0 {
                return
            }
            
            UIView.animate(withDuration: 0.3, animations: {
                self.scrollView.contentOffset = CGPoint(x: self.lastOffset.x, y: collapseSpace + 10)
            })
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        
        UIView.animate(withDuration: 0.3) {
            self.constraintContentHeight.constant -= self.currentKeyboardHeight
            self.scrollView.contentOffset = self.lastOffset
        }
        
        currentKeyboardHeight = nil
    }
}

