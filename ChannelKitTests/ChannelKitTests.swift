//
//  ChannelKitTests.swift
//  ChannelKitTests
//
//  Created by Marc Palluat de Besset on 14/12/2016.
//  Copyright © 2016 hibu. All rights reserved.
//

import XCTest
@testable import ChannelKit

class ChannelKitTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testSimpleChannelSuccess() {
        let input = Input<String>()
        _ = input.channel.subscribe { (result) in
            if case let .success(value) = result {
                XCTAssert(value == "test")
            } else {
                XCTAssert(false)
            }
        }
        
        input.send(value: "test")
    }
    
    func testSimpleChannelFailure() {
        enum Err: Error {
            case err
        }
        
        let input = Input<String>()
        _ = input.channel.subscribe { (result) in
            if case .failure(_) = result {
                XCTAssert(true)
            } else {
                XCTAssert(false)
            }
        }
        input.send(error: Err.err)
    }
    
    func testChannelSendsMultipleValues() {
        let expectation = self.expectation(description: #function)
        
        let values = [1,2,3,4,5]
        var results = [Int]()
        
        let input = Input<Int>()
        let output = input.channel.subscribe { (result) in
            if case let .success(value) = result {
                results.append(value)
            }
            if results.count == values.count {
                XCTAssert(values == results)
                expectation.fulfill()
            }
        }
        
        input.send(values: values)
        
        self.waitForExpectations(timeout: 10) { (error: Error?) -> Void in
            output.cancel()
        }
        
    }
    
    func testChannelMapValues() {
        let expectation = self.expectation(description: #function)
        
        let values = [1,2,3,4,5]
        var results = [Int]()
        
        let input = Input<Int>()
        
        let channel = input.channel.map { (val) in
            return val * 2
        }
        
        let output = channel.subscribe { (result) in
            if case let .success(value) = result {
                results.append(value)
            }
            if values.count == results.count {
                XCTAssert(values.map { $0 * 2 } == results)
                expectation.fulfill()
            }
        }
        
        input.send(values: values)
        
        self.waitForExpectations(timeout: 10) { (error: Error?) -> Void in
            output.cancel()
        }
    }
    
    func testChannelFilterValues() {
        let expectation = self.expectation(description: #function)
        
        let values = [1,2,3,4,5]
        let filteredValues = values.filter { $0 % 2 == 0 }
        var results = [Int]()
        
        let input = Input<Int>()
        
        let channel = input.channel.filter { (val) in
            return val % 2 == 0
        }
        
        let output = channel.subscribe { (result) in
            if case let .success(value) = result {
                results.append(value)
            }
            if filteredValues.count == results.count {
                XCTAssert(filteredValues == results)
                expectation.fulfill()
            }
        }
        
        input.send(values: values)
        
        self.waitForExpectations(timeout: 10) { (error: Error?) -> Void in
            output.cancel()
        }
        
    }
    
//    func testThreadSafe() {
//        let expectation = self.expectation(description: #function)
//        
//        let values = [1,2,3,4,5]
//        var results = [Int]()
//        let q = DispatchQueue(label: #function)
//        
//        let input = Input<Int>()
//        var output: Output<Int>?
//        
//        Queue.global().async {
//            let channel = input.channel.map { (val) in
//                return val * 2
//            }
//            
//            Queue.global().async {
//                output = channel.subscribe(queue: .global()) { (result) in
//                    if case let .success(value) = result {
//                        q.async {
//                            results.append(value)
//                        }
//                    }
//                    q.async {
//                        if values.count == results.count {
//                            XCTAssert(values.map { $0 * 2 } == results)
//                            expectation.fulfill()
//                        }
//                    }
//                }
//                
//                Queue.global().async {
//                    input.send(values: values)
//                }
//            }
//        }
//        
//        self.waitForExpectations(timeout: 10) { (error: Error?) -> Void in
//            output?.cancel()
//        }
//        
//    }
    
    func testChannelThrottle() {
        let expectation = self.expectation(description: #function)
        
        let values = [1,2,3,4,5,6,7,8,9,10]
        var results = [Int]()
        
        let input = Input<Int>()
        
        let output = input.channel.throttle(0.001).subscribe { (result) in
            if case let .success(value) = result {
                results.append(value)
            }
        }
        
        for value in values {
            input.send(value: value)
        }
        
        Queue.global().after(1.0) {
            XCTAssert(values.count > results.count)
            XCTAssert(results.count > 1)
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 10) { (error: Error?) -> Void in
            output.cancel()
        }
    }
    
    func testChannelGrouping() {
        let expectation = self.expectation(description: #function)
        
        let values = [1,2,3,4,5,6,7,8,9,10]
        var results = [[Int]]()
        
        let input = Input<Int>()
        
        let output = input.channel.group(0.001).subscribe { (result) in
            if case let .success(value) = result {
                results.append(value)
            }
        }
        
        for value in values {
            input.send(value: value)
        }
        
        Queue.global().after(1.0) {
            XCTAssert(values.count > results.count)
            XCTAssert(results.count > 1)
            let flatResults = results.flatMap { $0 }
            XCTAssert(values == flatResults)
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 10) { (error: Error?) -> Void in
            output.cancel()
        }
    }


    
}

