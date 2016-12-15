//
//  Reactive.swift
//  ChannelDemo
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
    
    private weak var _channel: Channel<T>?
    private var cancelled = false
    private var lock: DispatchQueue!
    
    public init () {
        lock = DispatchQueue(label: "com.hibu.Channel.Input.\(Unmanaged.passUnretained(self).toOpaque())")
    }
    
    deinit {
        print("\(self) - deinit")
    }
    
    
    /// get the current channel or return a new one if none exist.
    public var channel: Channel<T> {
        return lock.sync {
            assert(!cancelled, "Input was cancelled. Cannot be reused.")
            if let channel = _channel {
                return channel
            } else {
                let channel = Channel<T>(parent: self)
                _channel = channel
                return channel
            }
        }
    }
    
    
    /// send a value through the channel
    ///
    /// - Parameter value: the value to be sent
    public func send(value: T) {
        lock.sync {
            assert(!self.cancelled, "Input was cancelled. Cannot be reused.")
            self._channel?.send(result: Result(value: value))
        }
    }
    
    /// send values through the channel
    ///
    /// - Parameter value: the value to be sent
    public func send(values: [T]) {
        lock.sync {
            assert(!self.cancelled, "Input was cancelled. Cannot be reused.")
            for value in values {
                self._channel?.send(result: Result(value: value))
            }
        }
    }
    
    /// send an error through the channel
    ///
    /// - Parameter error: the error to be sent
    public func send(error: Error) {
        lock.sync {
            assert(!self.cancelled, "Input was cancelled. Cannot be reused.")
            self._channel?.send(result: Result(error: error))
        }
    }
    
    
    /// for the cases where releasing the output is not convenient
    public func cancel() {
        lock.sync {
            self._channel?.send(result: Result(error: ChannelError.cancelled))
            self._channel = nil
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
    
    deinit {
        print("\(self) - deinit")
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

public class Channel<T> {
    
    fileprivate var cancelled = false
    fileprivate var parent: Any?
    fileprivate var lock: DispatchQueue!
    fileprivate var queue: DispatchQueue!
    public private(set) var last: Result<T>?
    private var cleanup: (() -> Void)?
    
    fileprivate init() {
        lock = DispatchQueue(label: "com.hibu.Channel.\(Unmanaged.passUnretained(self).toOpaque())")
    }
    
    fileprivate init(parent: Any) {
        self.parent = parent
        self.lock = DispatchQueue(label: "com.hibu.Channel.\(Unmanaged.passUnretained(self).toOpaque())")
    }
    
    deinit {
        print("\(self) - deinit")
        if let cleanup = cleanup {
            Queue.main.async {
                cleanup()
            }
        }
    }
    
    fileprivate func send(result: Result<T>) {
        if lock.isCurrent {
            _send(result: result)
        }
        lock.sync {
            _send(result: result)
        }
    }

    private func _send(result: Result<T>) {
        assert(!cancelled, "Input was cancelled. Cannot be reused.")
        
        if case let .failure(error) = result {
            do {
                throw error
            } catch ChannelError.cancelled  {
                cancel()
            } catch {
                self.runNext(result)
            }
        } else {
            self.runNext(result)
        }
        
        last = result
    }
    
    private func runNext(_ result: Result<T>) {
        assert(lock.isCurrent)
        if let next = next {
            next(result)
        }
    }
    
    fileprivate var next: ((Result<T>) -> Void)? {
        willSet(new) {
            assert(!cancelled, "Input was cancelled. Cannot be reused.")
            assert(new == nil || next == nil, "bind, join, split, ... can only be called once")
        }
    }
    
    public func setCleanup(closure: @escaping () -> Void) {
        lock.sync {
            cleanup = closure
        }
    }
    
    /// creates a new Channel object and gives a way to map the result
    ///
    /// - Parameter transform: Defines how to map the result
    /// - Returns: returns a new Channel of potentially a different type
    fileprivate func bind<U>(transform: @escaping (Result<T>) -> Result<U>?) -> Channel<U> {
        return lock.sync {
            assert(!cancelled, "Input was cancelled. Cannot be reused.")
            let channel = Channel<U>(parent: self)
            next = { [weak channel] result in
                if let new = transform(result) {
                    channel?.send(result: new)
                }
            }
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
    public func join(channel: Channel<T>, onlyIfBothResultsAvailable: Bool = false, queue: DispatchQueue = .global(), transform: @escaping (Result<T>?, Result<T>?, @escaping (Result<T>?) -> Void) -> Void) -> Channel<T> {
        return lock.sync {
            assert(!cancelled, "Input was cancelled. Cannot be reused.")
            let outChannel = Channel<T>()
            
            let output = channel.subscribe(queue: lock) { [weak outChannel, unowned self] (result) in
                if onlyIfBothResultsAvailable {
                    if let last = self.last, let outChannel = outChannel {
                        queue.async {
                            transform(last, result) { value in
                                if let value = value {
                                    outChannel.send(result: value)
                                }
                            }
                        }
                    }
                } else {
                    queue.async {
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
                        queue.async {
                            transform(result, last) { value in
                                if let value = value {
                                    outChannel?.send(result: value)
                                }
                            }
                        }
                    }
                } else {
                    queue.async {
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
    public func split(queue: DispatchQueue = .main, transform: ((Result<T>, (Result<T>?, Result<T>?) -> Void) -> Void)? = nil) -> (Channel<T>, Channel<T>) {
        return lock.sync {
            assert(!cancelled, "Input was cancelled. Cannot be reused.")
            let a = Channel(parent: self)
            let b = Channel(parent: self)
            
            next = { [weak a, weak b] result in
                
                if let transform = transform {
                    queue.async {
                        transform(result) { (r1, r2) in
                            if let r = r1 {
                                a?.send(result: r)
                            }
                            if let r = r2 {
                                b?.send(result: r)
                            }
                        }
                    }
                } else {
                    a?.send(result: result)
                    b?.send(result: result)
                }
            }
            
            return (a, b)
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
            let output = Output(parent: self, queue: queue, completion: completion)
            output.last = self.last
            next = { [weak output] result in
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
        lock.sync {
            parent = nil
            runNext(Result(error: ChannelError.cancelled))
            next = nil
            cancelled = true
        }
    }
    
}

extension Channel {
    
    /// creates a new Channel object and gives a way to map the value
    ///
    /// - Parameter transform: Defines how to map the values
    /// - Returns: returns a new Channel of potentially a different type
    public func map<U>(transform: @escaping (T) -> U) -> Channel<U> {
        return bind { result in
            switch result {
            case let .success(value):
                return Result(value: transform(value))
            case let .failure(error):
                return Result(error: error)
            }
        }
    }
    
    /// filtering function
    ///
    /// - Parameter isIncluded: A closure that takes a value and decides if it should be sent or not.
    /// - Returns: returns a new channel of the same type.
    public func filter(isIncluded: @escaping (T) -> Bool) -> Channel<T> {
        return bind { result in
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
    
    
    /// Reduce function
    ///
    /// - Parameters:
    ///   - initialResult: could be an empty collection or string or 0
    ///   - nextPartialResult: a closure that returns a partial result
    /// - Returns: a new channel of the type of the initial result
    public func reduce<U>(initialResult: U, nextPartialResult: @escaping (U, T) -> U) -> Channel<U> {
        var currentResult = initialResult // this mutable variable should really be protected by the lock

        return bind { result in
            switch result {
            case let .success(value):
                currentResult = nextPartialResult(currentResult, value)
                return Result(value: currentResult)
            case let .failure(error):
                return Result(error: error)
            }
        }
    }

}

extension Channel where T: Equatable {
    
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
    
    public func flatBind<U, V>(transform: @escaping (Result<U>) -> Result<V>?) -> Channel<V> {
        return lock.sync {
            assert(!cancelled, "Input was cancelled. Cannot be reused.")
            let retains: [Any] = [self]
            let channel = Channel<V>(parent: retains)
            next = { [weak channel] result in
                if let channel = channel {
                    switch result {
                    case let .success(value):
                        let output = (value as! Channel<U>).subscribe(completion: { (subResult) in
                            if let new = transform(subResult) {
                                channel.send(result: new)
                            }
                        })
                        var retains = channel.parent as! [Any]
                        retains.append(output)
                        channel.parent = retains
                    case let .failure(error):
                        if let new = transform(Result<U>(error: error)) {
                            channel.send(result: new)
                        }
                    }
                }
            }
            return channel
        }
    }
    
    
    public func flatMap<U,V>(transform: @escaping (U) -> V? ) -> Channel<V> {
        return flatBind { (result: Result<U>) -> Result<V>? in
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

// ideas for extending:

// - throttling (only forward values after a timeout: )
// - grouping
// - debugging (log of events)
// - integration with textFields, buttons, ...
// - integration with NetKit
// - integration with TableViewManager

// https://gist.github.com/staltz/868e7e9bc2a7b8c1f754



