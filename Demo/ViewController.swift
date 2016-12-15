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
    var outputs = [Any]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        logic = LoginLogic(email: email.channel, password: password.channel, login: login.channel)
        
        login.setEnabled(with: logic.loginEnabled)
        
        let loginActionOutput = logic.loginAction.subscribe { (result) in
            if case let .success((email, psw)) = result {
                print("action received with email: \(email) password: \(psw)")
            }
        }
        outputs = [loginActionOutput]
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

