//
//  ViewController.swift
//  ChannelDemo
//
//  Created by Marc Palluat de Besset on 12/12/2016.
//  Copyright © 2016 hibu. All rights reserved.
//

import UIKit
import ChannelKit

class ViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet var email: UITextField!
    @IBOutlet var password: UITextField!
    @IBOutlet var login: UIButton!
    
    let emailInput = Input<String>()
    let passwordInput = Input<String>()
    let loginInput = Input<Void>()
    
    var logic: LoginLogic!
    var loginEnabledOutput: Output<Bool>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        logic = LoginLogic(email: emailInput.channel, password: passwordInput.channel, login: loginInput.channel)
        
        loginEnabledOutput = logic.loginEnabled.subscribe(initial: false) { [unowned self] result in
            if case let .success(enabled) = result {
                self.login.isEnabled = enabled
            }
        }
        
        email.delegate = self
        password.delegate = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func doLogin(_ sender: Any) {
        loginInput.send(value: ())
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let text = textField.text ?? ""
        let start = text.index(text.startIndex, offsetBy: range.location)
        let end = text.index(text.startIndex, offsetBy: range.location + range.length)
        let new = text.replacingCharacters(in: start..<end, with: string)
        
        if textField == email {
            emailInput.send(value: new)
        } else if textField == password {
            passwordInput.send(value: new)
        }
        
        return true
    }
}

