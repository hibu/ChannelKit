//
//  Reactive.swift
//  ChannelKit
//
//  Created by Marc Palluat de Besset on 12/12/2016.
//  Copyright © 2016 hibu. All rights reserved.
//

import Foundation

public enum Result<T> {
    case success(T)
    case failure(Error)
    
    init(value: T) {
        self = .success(value)
    }
    
    init(error: Error) {
        self = .failure(error)
    }
}

enum ChannelError: Error {
    case cancelled
}

/// The 'WRITE' end of a channel
/// has a weak reference on the first channel object
public final class Input<T> {
    
    private weak var output: Channel<T>?
    private var cancelled = false
    private var lock: DispatchQueue!
    public var debug = false
    
    public init () {
        lock = DispatchQueue(label: "com.hibu.Channel.Input.\(Unmanaged.passUnretained(self).toOpaque())")
    }
    
    deinit {
        if debug {
            print("\(self) - deinit")
        }
    }
    
    
    /// get the current channel or return a new one if none exist.
    public var channel: Channel<T> {
        return lock.sync {
            assert(!cancelled, "Input was cancelled. Cannot be reused.")
            if let channel = output {
                channel.debug = debug
                return channel
            } else {
                let channel = Channel<T>(parent: self)
                output = channel
                channel.debug = debug
                return channel
            }
        }
    }
    
    public func hasChannel() -> Bool {
        return lock.sync { output != nil }
    }
    
    
    /// send a value through the channel
    ///
    /// - Parameter value: the value to be sent
    public func send(value: T) {
        if debug {
            print("\(self) - sending: \(value)")
        }
        lock.sync {
            assert(!self.cancelled, "Input was cancelled. Cannot be reused.")
            self.output?.send(result: Result(value: value))
        }
    }
    
    /// send values through the channel
    ///
    /// - Parameter value: the value to be sent
    public func send(values: [T]) {
        if debug {
            print("\(self) - sending: \(values)")
        }

        lock.sync {
            assert(!self.cancelled, "Input was cancelled. Cannot be reused.")
            for value in values {
                self.output?.send(result: Result(value: value))
            }
        }
    }
    
    /// send an error through the channel
    ///
    /// - Parameter error: the error to be sent
    public func send(error: Error) {
        if debug {
            print("\(self) - sending: \(error)")
        }

        lock.sync {
            assert(!self.cancelled, "Input was cancelled. Cannot be reused.")
            self.output?.send(result: Result(error: error))
        }
    }
    
    
    /// for the cases where releasing the output is not convenient
    public func cancel() {
        if debug {
            print("\(self) - cancelling")
        }

        lock.sync {
            self.output?.send(result: Result(error: ChannelError.cancelled))
            self.output = nil
            self.cancelled = true
        }
    }
}

// This is the 'read/notify' end of the channel
// Output has a strong reference to the last channel object.
public class Output<T> {
    
    private var parent: AnyObject?
    private var completion: ((Result<T>) -> Void)?
    private var queue: Queue
    public fileprivate(set) var last: Result<T>?
    public var debug = false
    
    deinit {
        if debug {
            print("\(self) - deinit")
        }
    }
    
    fileprivate init(parent: AnyObject, queue: Queue, completion: @escaping (Result<T>) -> Void) {
        self.parent = parent
        self.completion = completion
        self.queue = queue
    }
    
    fileprivate func send(result: Result<T>) {
        last = result
        if let completion = completion {
            queue.async {
                completion(result)
            }
        }
    }
    
    
    /// Sometimes, releasing the output is not practical, so instead you can just call cancel
    public func cancel() {
        parent = nil
        completion = nil
    }
    
}

// A simple channel is made of one or more objects of this class, plus one Input and one Output.
// Each channel object has a strong reference on the previous channel, but never retains the input.
// unless you specify a queue, all closures are executed on the same thread input.send() was called on.
public class Channel<T> {
    
    fileprivate var cancelled = false
    fileprivate var parent: Any?
    fileprivate var lock: DispatchQueue!
    fileprivate var queue: DispatchQueue!
    public private(set) var last: Result<T>?
    private var cleanup: (() -> Void)?
    public var debug = false
    private var subscribed = false
    private var split = false
    
    fileprivate var next: ((Result<T>) -> Void)? {
        willSet(new) {
            assert(!cancelled, "Input was cancelled. Cannot be reused.")
            assert(new == nil || next == nil, "bind, join, split, ... can only be called once")
        }
    }
    
    fileprivate init() {
        lock = DispatchQueue(label: "com.hibu.Channel.\(Unmanaged.passUnretained(self).toOpaque())")
    }
    
    fileprivate init(parent: Any) {
        self.parent = parent
        self.lock = DispatchQueue(label: "com.hibu.Channel.\(Unmanaged.passUnretained(self).toOpaque())")
    }
    
    deinit {
        if debug {
            print("\(self) - deinit")
        }
        if let cleanup = cleanup {
            Queue.main.async {
                cleanup()
            }
        }
    }
    
    fileprivate func send(result: Result<T>) {
        assert(!lock.isCurrent)
        assert(!cancelled, "Input was cancelled. Cannot be reused.")
        
        if debug {
            print("\(self) - received \(result)")
        }
        
        let next = lock.sync {
            return self.next
        }
        
        if case let .failure(error) = result {
            do {
                throw error
            } catch ChannelError.cancelled  {
                cancel()
            } catch {}
        }
        
        if let next = next {
            next(result)
        }
        last = result
    }
    
    
    /// cleans up on the main thread
    ///
    /// - Parameter closure: contains the cleanup code
    public func setCleanup(closure: @escaping () -> Void) {
        lock.sync {
            cleanup = closure
        }
    }
    
    
    /// creates a new Channel object and gives a way to map the result
    ///
    /// - Parameter transform: Defines how to map the result
    /// - Returns: returns a new Channel of potentially a different type
    fileprivate func bind<U>(queue: DispatchQueue? = nil, transform: @escaping (Result<T>) -> Result<U>?) -> Channel<U> {
        return lock.sync {
            assert(!cancelled, "Input was cancelled. Cannot be reused.")
            let channel = Channel<U>(parent: self)
            next = { [weak channel] result in
                execute(async: queue) {
                    if let new = transform(result) {
                        channel?.send(result: new)
                    }
                }
            }
            channel.debug = self.debug
            return channel
        }
    }
    
    /// creates a new Channel object and gives a way to map the result. This is the promise version
    ///
    /// - Parameter transform: Defines how to map the result
    /// - Returns: returns a new Channel of potentially a different type
    fileprivate func bind<U>(queue: DispatchQueue? = nil, transform: @escaping (Result<T>, @escaping (Result<U>?) -> Void) -> Void) -> Channel<U> {
        return lock.sync {
            assert(!cancelled, "Input was cancelled. Cannot be reused.")
            let channel = Channel<U>(parent: self)
            next = { [weak channel] result in
                execute(async: queue) {
                    transform(result) { new in
                        if let new = new {
                            channel?.send(result: new)
                        }
                    }
                }
            }
            channel.debug = self.debug
            return channel
        }
    }


    /// Merges the current channel with another specified as a parameter
    ///
    /// - Parameters:
    ///   - channel: A channel to be merged with the receiver
    ///   - onlyIfBothResultsAvailable: Optional flag. When set, transform will only be called when the two results are available.
    ///   - transform: A closure that allows to specify how to 'mix' the values
    /// - Returns: A new channel of the same type
    public func join(channel: Channel<T>, onlyIfBothResultsAvailable: Bool = false, queue: DispatchQueue? = nil, transform: @escaping (Result<T>?, Result<T>?, @escaping (Result<T>?) -> Void) -> Void) -> Channel<T> {
        return lock.sync {
            assert(!cancelled, "Input was cancelled. Cannot be reused.")
            let outChannel = Channel<T>()
            outChannel.debug = self.debug || channel.debug
            
            let output = channel.subscribe(queue: lock) { [weak outChannel, unowned self] (result) in
                if onlyIfBothResultsAvailable {
                    if let last = self.last, let outChannel = outChannel {
                        execute(async: queue) {
                            transform(last, result) { value in
                                if let value = value {
                                    outChannel.send(result: value)
                                }
                            }
                        }
                    }
                } else {
                    execute(async: queue) {
                        transform(nil, result) { value in
                            if let value = value {
                                outChannel?.send(result: value)
                            }
                        }
                    }
                }
            }
            
            next = { [weak outChannel, weak output] result in
                if onlyIfBothResultsAvailable {
                    if let last = output?.last {
                        execute(async: queue) {
                            transform(result, last) { value in
                                if let value = value {
                                    outChannel?.send(result: value)
                                }
                            }
                        }
                    }
                } else {
                    execute(async: queue) {
                        transform(result, nil) { value in
                            if let value = value {
                                outChannel?.send(result: value)
                            }
                        }
                    }
                }
            }
            
            outChannel.parent = [self, output]
            return outChannel
        }
    }
    
    /// Merges the current channel with another specified as a parameter
    ///
    /// - Parameters:
    ///   - channel: A channel to be merged with the receiver
    ///   - onlyIfBothValuesAvailable: Optional flag. When set, transform will only be called when the two values are available
    ///   - transform: A closure that allows to specify how to 'mix' the values
    /// - Returns: A new channel of the same type
    public func join(channel: Channel<T>, onlyIfBothValuesAvailable: Bool = false, queue: DispatchQueue = .global(), transform: @escaping (T?, T?, @escaping (T?) -> Void) -> Void) -> Channel<T> {
        
        return join(channel: channel, onlyIfBothResultsAvailable: onlyIfBothValuesAvailable, queue: queue) { (result1, result2, completion) in
            
            let asyncCompletion = { (value: T?) in
                if let value = value {
                    completion(Result(value: value))
                }
            }
            
            switch (result1, result2) {
            case (let .some(.success(value1)), let .some(.success(value2))):
                transform(value1, value2, asyncCompletion)
            case (let .some(.success(value1)), .none):
                transform(value1, nil, asyncCompletion)
            case (.none, let .some(.success(value2))):
                transform(nil, value2, asyncCompletion)
            case (let .some(.failure(error)), _):
                completion(Result(error: error))
            case (_, let .some(.failure(error))):
                completion(Result(error: error))
            default:
                completion(nil)
            }
        }
    }

    /// Allows a channel to be split into two channels of the same type.
    /// - Parameter transform: Optional transform closure lets you specify what happens to the values
    /// - Returns: a couple of channels of the same type.
    public func split(count: Int = 2, queue: DispatchQueue? = nil, transform: ((Result<T>, ([Result<T>?]) -> Void) -> Void)? = nil) -> [Channel<T>] {
        return lock.sync {
            assert(!cancelled, "Input was cancelled. Cannot be reused.")
            assert((self.next == nil || split) && !subscribed, "This channel node cannot be split")
            
            let channels = Array(1...count).map { (_) -> Channel<T> in
                let c = Channel(parent: self)
                c.debug = self.debug
                return c
            }
            
            let weakChannels = channels.map { c in
                return Weak(value: c)
            }
            
            let next = self.next
            self.next = nil
            split = true
            self.next = { result in
                next?(result)
                
                if let transform = transform {
                    execute(async: queue) {
                        transform(result) { (results) in
                            assert(results.count == weakChannels.count)
                            
                            for (index, c) in weakChannels.enumerated() {
                                if let r = results[index] {
                                    c.value?.send(result: r)
                                }
                            }
                        }
                    }
                } else {
                    for c in weakChannels {
                        c.value?.send(result: result)
                    }
                }
            }
            return channels
        }
    }
    
    /// Subscribe to get an output object and get notified once per value sent
    ///
    /// - Parameters:
    ///   - initial: get notified when a value is available
    ///   - completion: switch on the result to find out if you have a value or an error
    /// - Returns: an Output object
    public func subscribe(initial: T? = nil, queue: DispatchQueue = .main, completion: @escaping (Result<T>) -> Void) -> Output<T> {
        return lock.sync {
            assert(!cancelled, "Input was cancelled. Cannot be reused.")
            assert((self.next == nil || subscribed) && !split, "This channel node can not be used for subscribing.")
            
            let output = Output(parent: self, queue: queue, completion: completion)
            output.debug = self.debug
            output.last = self.last
            let next = self.next
            self.next = nil
            subscribed = true
            self.next = { [weak output] result in
                next?(result)
                output?.send(result: result)
            }
            if let initial = initial {
                output.send(result: Result<T>(value: initial))
            }
            return output
        }
    }
    
    /// sometimes, releasing the output is not practical, so instead you can just call cancel
    func cancel() {
        
        let next: ((Result<T>) -> Void)? = lock.sync {
            parent = nil
            cancelled = true
            let n = self.next
            self.next = nil
            return n
        }
        
        if let next = next {
            next(Result(error: ChannelError.cancelled))
        }
    }
    
}

extension Channel {
    
    /// creates a new Channel object and gives a way to map the value
    ///
    /// - Parameter transform: Defines how to map the values
    /// - Returns: returns a new Channel of potentially a different type
    public func map<U>(queue: DispatchQueue? = nil, transform: @escaping (T) -> U) -> Channel<U> {
        return bind(queue: queue) { result in
            switch result {
            case let .success(value):
                return Result(value: transform(value))
            case let .failure(error):
                return Result(error: error)
            }
        }
    }
    
    
    /// creates a new Channel object and gives a way to map the value. This is the promise version
    ///
    /// - Parameter transform: Defines how to map the values
    /// - Returns: returns a new Channel of potentially a different type
    public func map<U>(queue: DispatchQueue? = nil, transform: @escaping (T, @escaping (U?) -> Void) -> Void) -> Channel<U> {
        return bind(queue: queue) { result, completion in
            switch result {
            case let .success(value):
                transform(value) { new in
                    if let new = new {
                        completion(Result(value: new))
                    } else {
                        completion(nil)
                    }
                }
            case let .failure(error):
                completion(Result(error: error))
            }
        }
    }

    
    /// filtering function
    ///
    /// - Parameter isIncluded: A closure that takes a value and decides if it should be sent or not.
    /// - Returns: returns a new channel of the same type.
    public func filter(queue: DispatchQueue? = nil, isIncluded: @escaping (T) -> Bool) -> Channel<T> {
        return bind(queue: queue) { result in
            switch result {
            case let .success(value):
                if isIncluded(value) {
                    return result
                }
            case let .failure(error):
                return Result(error: error)
            }
            return nil
        }
    }
    
    /// filtering function. Promise version
    ///
    /// - Parameter isIncluded: A closure that takes a value and decides if it should be sent or not.
    /// - Returns: returns a new channel of the same type.
    public func filter(queue: DispatchQueue? = nil, isIncluded: @escaping (T, (Bool) -> Void) -> Void) -> Channel<T> {
        return bind(queue: queue) { result, completion in
            switch result {
            case let .success(value):
                isIncluded(value) { flag in
                    if flag {
                        completion(result)
                    } else {
                        completion(nil)
                    }
                }
            case let .failure(error):
                completion(Result(error: error))
            }
        }
    }
    
    
    /// Reduce function
    ///
    /// - Parameters:
    ///   - initialResult: could be an empty collection or string or 0
    ///   - nextPartialResult: a closure that returns a partial result
    /// - Returns: a new channel of the type of the initial result
    public func reduce<U>(queue: DispatchQueue? = nil, initialResult: U, nextPartialResult: @escaping (U, T) -> U) -> Channel<U> {
        var currentResult = initialResult // this mutable variable should really be protected by the lock

        return bind(queue: queue) { result in
            switch result {
            case let .success(value):
                currentResult = nextPartialResult(currentResult, value)
                return Result(value: currentResult)
            case let .failure(error):
                return Result(error: error)
            }
        }
    }
    
    /// Reduce function. Promise version.
    ///
    /// - Parameters:
    ///   - initialResult: could be an empty collection or string or 0
    ///   - nextPartialResult: a closure that returns a partial result
    /// - Returns: a new channel of the type of the initial result
    public func reduce<U>(queue: DispatchQueue? = nil, initialResult: U, nextPartialResult: @escaping (U, T, (U) -> Void) -> Void) -> Channel<U> {
        var currentResult = initialResult // this mutable variable should really be protected by the lock
        
        return bind(queue: queue) { result, completion in
            switch result {
            case let .success(value):
                nextPartialResult(currentResult, value) { new in
                    currentResult = new
                    completion(Result(value: currentResult))
                }
                
            case let .failure(error):
                completion(Result(error: error))
            }
        }
    }


}

extension Channel where T: Equatable {
    
    
    /// forwards distinct consecutive values
    ///
    /// - Returns: returns a channel which consecutive values are distinct.
    public func distinct() -> Channel<T> {
        return bind { [unowned self] result -> Result<T>? in
            
            switch (result, self.last) {
            case (let .success(value1), let .some(.success(value2))) where value1 != value2:
                return result
            case (.success(_), .none):
                return result
            case (let .failure(error), .none):
                return Result(error: error)
            default:
                return nil
            }
        }
    }
    
}

public protocol Stream {}
extension Channel: Stream {}

extension Channel where T: Stream {
    
    
    /// given a channel of channels, flattens and returns a channel of results
    ///
    /// - Parameter transform: a closure that converts results
    /// - Returns: a new channel
    public func flatBind<U, V>(queue: DispatchQueue? = nil, transform: @escaping (Result<U>) -> Result<V>?) -> Channel<V> {
        return lock.sync {
            assert(!cancelled, "Input was cancelled. Cannot be reused.")
            let retains: [Any] = [self]
            let channel = Channel<V>(parent: retains)
            channel.debug = self.debug
            next = { [weak channel] result in
                if let channel = channel {
                    switch result {
                    case let .success(value):
                        let output = (value as! Channel<U>).subscribe(completion: { (subResult) in
                            execute(async: queue) {
                                if let new = transform(subResult) {
                                    channel.send(result: new)
                                }
                            }
                        })
                        var retains = channel.parent as! [Any]
                        retains.append(output)
                        channel.parent = retains
                    case let .failure(error):
                        execute(async: queue) {
                            if let new = transform(Result<U>(error: error)) {
                                channel.send(result: new)
                            }
                        }
                    }
                }
            }
            return channel
        }
    }
    
    /// given a channel of channels, flattens and returns a channel of values
    ///
    /// - Parameter transform: a closure that converts values
    /// - Returns: a new channel
    public func flatMap<U,V>(queue: DispatchQueue? = nil, transform: @escaping (U) -> V? ) -> Channel<V> {
        return flatBind(queue: queue) { (result: Result<U>) -> Result<V>? in
            switch result {
            case let .success(value):
                if let new = transform(value) {
                    return Result(value: new)
                }
                return nil
            case let .failure(error):
                return Result(error: error)
            }
        }
    }


}

extension Channel {
    
    
    /// sends values every time interval or more. Drops values sent too frequently.
    ///
    /// - Parameter interval: Time interval in seconds
    /// - Returns: returns a new channel
    public func throttle(_ interval: TimeInterval) -> Channel<T> {
        var waitUntilDate: Date = Date()
        var timer: DispatchSourceTimer?
        var channel: Channel<T>?

        func scheduleTimer(_ interval: TimeInterval, handler: @escaping () -> Void) -> DispatchSourceTimer {
            let timer = DispatchSource.makeTimerSource(queue: Queue.main)
            timer.setEventHandler(handler: handler)
            timer.scheduleOneshot(deadline: .now() + interval, leeway: .milliseconds(20))
            timer.resume()
            return timer
        }
        
        channel = bind { result -> (Result<T>?) in
            
            if waitUntilDate.timeIntervalSinceNow < 0 {
                waitUntilDate = Date(timeIntervalSinceNow: interval)
                timer?.cancel()
                timer = nil
                return result
            } else {
                let newInterval = waitUntilDate.timeIntervalSinceNow
                timer?.cancel()
                timer = nil
                
                timer = scheduleTimer(newInterval) { [weak channel] in
                    if let channel = channel {
                        timer = nil
                        waitUntilDate = Date(timeIntervalSinceNow: interval)
                        channel.send(result: result)
                    }
                }
                return nil
            }
        }
        
        return channel!
    }
    
    
    /// groups values and sends them (in an array) at every interval
    ///
    /// - Parameter interval: time interval in seconds
    /// - Returns: returns a new channel
    public func group(_ interval: TimeInterval) -> Channel<[T]> {
        var waitUntilDate: Date = Date()
        var timer: DispatchSourceTimer?
        var channel: Channel<[T]>?
        var group = [T]()
        
        func scheduleTimer(_ interval: TimeInterval, handler: @escaping () -> Void) -> DispatchSourceTimer {
            let timer = DispatchSource.makeTimerSource(queue: Queue.main)
            timer.setEventHandler(handler: handler)
            timer.scheduleOneshot(deadline: .now() + interval, leeway: .milliseconds(20))
            timer.resume()
            return timer
        }
        
        channel = bind { result -> Result<[T]>? in
            
            if waitUntilDate.timeIntervalSinceNow < 0 {
                timer?.cancel()
                timer = nil
                
                waitUntilDate = Date(timeIntervalSinceNow: interval)

                switch result {
                case let .success(value):
                    group.append(value)
                    let result = Result(value: group)
                    group = []
                    return result
                case let .failure(error):
                    group = []
                    return Result(error: error)
                }
                
            } else {
                let newInterval = waitUntilDate.timeIntervalSinceNow
                timer?.cancel()
                timer = nil
                
                switch result {
                case let .success(value):
                    group.append(value)
                case let .failure(error):
                    group = []
                    return Result(error: error)
                }
                
                timer = scheduleTimer(newInterval) { [weak channel] in
                    if let channel = channel {
                        timer = nil
                        waitUntilDate = Date(timeIntervalSinceNow: interval)
                        channel.send(result: Result(value: group))
                        group = []
                    }
                }
                return nil
            }
        }
        
        return channel!
    }

    
}

private class Weak<T: AnyObject> {
    weak var value : T?
    init (value: T) {
        self.value = value
    }
}



private func execute(async queue: DispatchQueue? = nil, work: @escaping () -> Void) {
    if let queue = queue {
        queue.async(execute: work)
    } else {
        work()
    }
}

// ideas for extending:

// - integration with NetKit
// - integration with TableViewManager

// https://gist.github.com/staltz/868e7e9bc2a7b8c1f754



