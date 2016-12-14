//
//  DemoTests.swift
//  DemoTests
//
//  Created by Marc Palluat de Besset on 14/12/2016.
//  Copyright © 2016 hibu. All rights reserved.
//

import XCTest
import ChannelKit
@testable import Demo

class DemoTests: XCTestCase {
    
    var logic: LoginLogic!
    var email = Input<String>()
    var password = Input<String>()
    var login = Input<Void>()
    
    override func setUp() {
        super.setUp()
        
        logic = LoginLogic(email: email.channel, password: password.channel, login: login.channel)
    }
    
    override func tearDown() {
        logic = nil
        super.tearDown()
    }
    
    func testLoginEnabled() {
        let expectation = self.expectation(description: #function)
        
        let output1 = logic.loginEnabled.subscribe { (result) in
            if case let .success(value) = result {
                XCTAssert(value)
            } else {
                XCTFail()
            }
        }
        
        let output2 = logic.loginAction.subscribe(completion: { (result) in
            if case .success(_) = result {
                XCTAssert(true)
            } else {
                XCTFail()
            }
            expectation.fulfill()
        })
        
        email.send(value: "test@yell.com")
        password.send(value: "abc123ABC")
        login.send(value: ())
        
        self.waitForExpectations(timeout: 10) { (error: Error?) -> Void in
            output1.cancel()
            output2.cancel()
        }
    }
    
    func testLoginDisabled() {
        let expectation = self.expectation(description: #function)
        
        let output1 = logic.loginEnabled.subscribe { (result) in
            if case let .success(value) = result {
                XCTAssertFalse(value)
            } else {
                XCTFail()
            }
            expectation.fulfill()
        }
        
        
        email.send(value: "test")
        password.send(value: "abc123ABC")
        
        self.waitForExpectations(timeout: 10) { (error: Error?) -> Void in
            output1.cancel()
        }
        
    }
    
    func testLoginDisabled_invalidPassword() {
        let expectation = self.expectation(description: #function)
        
        let output1 = logic.loginEnabled.subscribe { (result) in
            if case let .success(value) = result {
                XCTAssertFalse(value)
            } else {
                XCTFail()
            }
            expectation.fulfill()
        }
        
        email.send(value: "test@yell.com")
        password.send(value: "abc")
        
        self.waitForExpectations(timeout: 10) { (error: Error?) -> Void in
            output1.cancel()
        }
        
    }
    
    
}



