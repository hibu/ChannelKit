//
//  Foundation+reactive.swift
//  ChannelKit
//
//  Created by Marc Palluat de Besset on 15/12/2016.
//  Copyright © 2016 hibu. All rights reserved.
//

import Foundation

extension NotificationCenter {
    
    
    /// registers a channel as an observer
    ///
    /// - Parameters:
    ///   - name: notification name
    ///   - object: object sending the notification
    /// - Returns: a channel. When that channel is released, it unregisters automatically from the notification center
    public func channel( forName name: Notification.Name, object: Any?) -> Channel<Notification> {
        
        let input = Input<Notification>()
        
        let obj = NotificationCenter.default.addObserver(forName: name, object: object, queue: OperationQueue.main) { (notification) in
            input.send(value: notification)
        }
        
        let channel = input.channel
        
        channel.setCleanup {
            NotificationCenter.default.removeObserver(obj)
        }
        
        return channel
    }
    
}


extension Channel {
    
    
    /// Posts a notification for each result
    ///
    /// - Parameters:
    ///   - name: notification name
    ///   - object: object
    /// - Returns: Output object
    public func postResult(name: Notification.Name, object: Any? = nil) -> Output<T> {
        return self.subscribe { (result) in
            NotificationCenter.default.post(name: name, object: object ?? self, userInfo: ["result": result])
        }
    }
    
    /// Posts a notification for each successful value
    ///
    /// - Parameters:
    ///   - name: notification name
    ///   - object: object
    /// - Returns: Output object
    public func postValue(name: Notification.Name, object: Any? = nil) -> Output<T> {
        return self.subscribe { (result) in
            
            switch result {
            case let .success(value):
                NotificationCenter.default.post(name: name, object: object ?? self, userInfo: ["value": value])
            case .failure(_):
                ()
            }
        }
    }

}


