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
    
    var logic: LoginLogic!
    var loginEnabledOutput: Output<Bool>?
    var loginActionOutput: Output<(String,String)>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        logic = LoginLogic(email: email.channel, password: password.channel, login: login.channel)
        
        loginEnabledOutput = logic.loginEnabled.subscribe(initial: false) { [unowned self] result in
            if case let .success(enabled) = result {
                self.login.isEnabled = enabled
            }
        }
        
        loginActionOutput = logic.loginAction.subscribe { (result) in
            if case let .success((email, psw)) = result {
                print("action received with email: \(email) password: \(psw)")
            }
        }
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

