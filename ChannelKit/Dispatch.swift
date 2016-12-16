//
//  Dispatch.swift
//  YellMerchants
//
//  Created by Marc Palluat de Besset on 07/01/2016.
//  Copyright © 2016 hibu. All rights reserved.
//

import Foundation

public typealias Queue = DispatchQueue

/*
 Typical usage :
 
 Queue.main.async { ... }
 Queue.userInitiated.async { ... }
 
 methods : sync, async, asap, after
 
 Queue.main.after(when: .now() + 0.3) {
 
 
 let mySerialQueue = Queue( "my.serial.queue")
 
 mySerialQueue.asap { ... }
 mySerialQueue.sync { ... }
 
 
 
 let group = DispatchGroup()
 
 mySerialQueue.after(when: .now() + 5, group: group) { ... }
 Queue.background.async(group: group) { ... }
 
 group.wait()
 
 
 
 
 let concurrentQueue = ConcurrentQueue("my.concurrent.queue", attributes: .concurrent)
 
 concurrentQueue.async { /* read */ }
 concurrentQueue.async{ /* read */ }
 concurrentQueue.async { /* read */ }
 
 */


extension DispatchQueue {
    
    public var isCurrent: Bool {
        if let specific = DispatchQueue.getSpecific(key: key),
            let specific2 = self.getSpecific(key: key) {
            return specific == specific2
        } else {
            setSpecific(key: key, value: label)
            if let specific = DispatchQueue.getSpecific(key: key),
                let specific2 = self.getSpecific(key: key) {
                return specific == specific2
            }
            return false
        }
    }
    
    public func ssync<T>(execute work: () throws -> T) rethrows -> T {
        if isCurrent {
            return try work()
        } else {
            return try sync(execute: work)
        }
    }
    
    public func asap(group: DispatchGroup? = nil, execute work: @escaping @convention(block) () -> Swift.Void) {
        if configureDispatchQueue {
            
            var specific: String? = getSpecific(key: key)
            
            if specific == nil {
                setSpecific(key: key, value: label)
                specific = label
            }
            
            if let specific = specific,
                let specific2 = DispatchQueue.getSpecific(key: key), specific == specific2 {
                
                if #available(iOS 10.0, *) {
                    dispatchPrecondition(condition: .onQueue(self))
                } else {
                    // Fallback on earlier versions
                }
                
                if let group = group {
                    group.enter()
                    work()
                    group.leave()
                } else {
                    work()
                }
            } else {
                async(group: group, execute: work)
            }
        }
    }
    
    func after(_ delay: TimeInterval, execute closure: @escaping () -> Void) {
        asyncAfter(deadline: .now() + delay, execute: closure)
    }
    
}

extension DispatchQueue {
    
    public static var userInteractive: DispatchQueue {
        get { return DispatchQueue.global(qos: .userInteractive) }
    }
    
    public static var userInitiated: DispatchQueue {
        get { return DispatchQueue.global(qos: .userInitiated) }
    }
    
    public static var `default`: DispatchQueue {
        get { return DispatchQueue.global(qos: .default) }
    }
    
    public static var utility: DispatchQueue {
        get { return DispatchQueue.global(qos: .utility) }
    }
    
    public static var background: DispatchQueue {
        get { return DispatchQueue.global(qos: .background) }
    }
    
}

private let key = DispatchSpecificKey<String>()

private let configureDispatchQueue: Bool = {
    DispatchQueue.main.setSpecific(key: key, value: "main")
    DispatchQueue.global(qos: .userInteractive).setSpecific(key: key, value: "userInteractive")
    DispatchQueue.global(qos: .userInitiated).setSpecific(key: key, value: "userInitiated")
    DispatchQueue.global(qos: .default).setSpecific(key: key, value: "default")
    DispatchQueue.global(qos: .utility).setSpecific(key: key, value: "utility")
    DispatchQueue.global(qos: .background).setSpecific(key: key, value: "background")
    return true
}()

/**
 DispatchOnce
 
 Implementation of dispatch_once in a way that can be more useful than just using static variables
 
 *example:*
 
 ```
 static let dispatchOnce = DispatchOnce()
 ...
 
 dispatchOnce.once {
    // this will only get executed once, even if called from multiple threads at the same time.
 }

 ```
 
 
 */

public class DispatchOnce {
    private var done = false
    
    public func once(queue: DispatchQueue? = nil, _ closure: @escaping () -> Void) {
        objc_sync_enter(self); defer { objc_sync_exit(self) }

        if !done {
            done = true
            if let queue = queue {
                queue.asap(execute: closure)
            } else {
                closure()
            }
        }
    }
}

/**
 Funnels the calls to a closure.
 
 A closure (once) contains an **expensive piece of work** that needs to be done async, but only once.
 Any subsequent calls to this method will block and get the result of the work when unblocked after the work has completed.
 
 Once a piece of work is completed, any call to the async() method will work as described above.
 
 *example:*
 
 ```
 funnel.async(once: { (done) in
 // work for 5 seconds
 Queue.main.after(5) {
 done("done")
 }
 }, completion: { (worker, result) in
 ...
 })
 ```
 
 
 */

class DispatchFunnel<T> {
    private let semaphore = DispatchSemaphore(value: 1)
    private var seed: Int = 0
    private var val: T?
    
    func async(once: @escaping (@escaping (T?) -> Void) -> Void, completionQueue: DispatchQueue = DispatchQueue.main, completion: ((Bool, T?) -> Void)?) {
        
        DispatchQueue.global(qos: .userInitiated).async {
            
            let localSeed = self.seed
            self.semaphore.wait()
            
            if localSeed == self.seed {
                self.seed = 0
                self.val = nil
                
                once { (val) in
                    self.val = val
                    self.seed = Int(arc4random())
                    if let completion = completion {
                        completionQueue.async {
                            completion(true, val)
                        }
                    }
                    self.semaphore.signal()
                }
            } else {
                if let completion = completion {
                    completionQueue.async {
                        completion(false, self.val)
                    }
                }
                self.semaphore.signal()
            }
        }
    }
    
}

/**
 This class provides a way to abort blocks after they have been dispatched
 
 *example:*
 ```
 let generator = DispatchCancellableBlockGenerator()
 
 func cancellableTextFieldCheck(field: UITextField) {
 let generation = generator.generate()
 let text = field.text
 
 Queue.UserInitiated.async {
 if generation.shouldCancel() {
 return
 }
 
 // do work with text
 
 if generation.shouldCancel() {
 return
 }
 
 // do more work with text
 }
 }
 
 ```
 
 */
class DispatchCancellableBlockGenerator {
    fileprivate var _seed: UInt32 = 0
    
    /// returns a generation that cancels any previous ones
    func generate() -> DispatchCancellableBlockGeneration {
        _seed = arc4random()
        return DispatchCancellableBlockGeneration(seed: _seed, generator: self)
    }
}

/// This struct has an shouldCancel() method that tells a block if it should cancel its work
struct DispatchCancellableBlockGeneration {
    private let seed: UInt32
    private let generator: DispatchCancellableBlockGenerator
    
    fileprivate init(seed: UInt32, generator: DispatchCancellableBlockGenerator) {
        self.seed = seed
        self.generator = generator
    }
    
    /// if shouldCancel() return true, you should return from the current block
    func shouldCancel() -> Bool {
        return generator._seed != seed
    }
}

