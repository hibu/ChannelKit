//
//  LoginLogic.swift
//  ChannelDemo
//
//  Created by Marc Palluat de Besset on 12/12/2016.
//  Copyright © 2016 hibu. All rights reserved.
//

import Foundation
import ChannelKit

class LoginLogic {
    var email: Channel<String>
    var password: Channel<String>
    var login: Channel<Void>
    private var loginOutput: Output<Void>?
    private var loginActionInput: Input<(String,String)>?
    
    init(email: Channel<String>, password: Channel<String>, login: Channel<Void>) {
        self.email = email
        self.password = password
        self.login = login
    }
    
    var loginEnabled: Channel<Bool> {
        let emailValid = email.throttle(0.25).map { [unowned self] (email) -> Bool in
            return self.isEmailValid(email)
        }
        .distinct()
        
        let passwordValid = password.throttle(0.25).map { [unowned self] (password) -> Bool in
            return self.isPasswordValid(password)
        }
        .distinct()
        
        return emailValid.join(channel: passwordValid, onlyIfBothValuesAvailable: true, queue: .global(), transform: { (emailValid, passwordValid, completion) in
            if let emailValid = emailValid, let passwordValid = passwordValid {
                completion(emailValid && passwordValid)
            } else {
                completion(false)
            }
        })
    }
    
    var loginAction: Channel<(String, String)> {
        
        loginActionInput = Input<(String, String)>()
        
        loginOutput = login.subscribe(completion: { [unowned self] (result) in
            switch result {
            case .success(_):
                if let emailResult = self.email.last, let passwordResult = self.password.last {
                    if case let .success(email) = emailResult, case let .success(password) = passwordResult,
                        self.isEmailValid(email) && self.isPasswordValid(password) {
                        self.loginActionInput?.send(value: (email, password))
                    }
                }
            case .failure(_):
                break
            }
        })
        
        return loginActionInput!.channel
    }
    
    func isEmailValid(_ email: String) -> Bool {
        let emailRegex = "[a-zA-Z0-9\\+\\.\\_\\%\\-\\+]{1,256}" +
            "\\@" +
            "[a-zA-Z0-9][a-zA-Z0-9\\-]{0,64}" +
            "(" +
            "\\." +
            "[a-zA-Z0-9][a-zA-Z0-9\\-]{0,25}" +
        ")+"
        guard email.characters.count > 0 else { return false }
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
    
    func isPasswordValid(_ password: String) -> Bool {
        
        return password.characters.count > 7 &&
            password.rangeOfCharacter(from: .decimalDigits) != nil &&
            password.rangeOfCharacter(from: .uppercaseLetters) != nil &&
            password.rangeOfCharacter(from: .lowercaseLetters) != nil
    }
}
