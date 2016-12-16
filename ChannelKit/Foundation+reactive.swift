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
