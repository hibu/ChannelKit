//
//  UIKit+reactive.swift
//  ChannelKit
//
//  Created by Marc Palluat de Besset on 14/12/2016.
//  Copyright © 2016 hibu. All rights reserved.
//

import UIKit
import ObjectiveC

private var key = "key"

extension UIButton {
    
    private var input: Input<Void> {
        get {
            if let input = objc_getAssociatedObject(self, &key) as? Input<Void> {
                return input
            } else {
                let input = Input<Void>()
                objc_setAssociatedObject(self, &key, input, .OBJC_ASSOCIATION_RETAIN)
                return input
            }
        }
    }
    
    public var channel: Channel<Void> {
        get {
            startSending()
            return input.channel
        }
    }
    
    private func startSending() {
        self.addTarget(self, action: #selector(tap(_:)), for: .touchUpInside)
    }
    
    dynamic public func tap(_ sender: Any?) {
        self.input.send(value: ())
    }
    
}

extension UITextField {
    
    private var input: Input<String> {
        get {
            if let input = objc_getAssociatedObject(self, &key) as? Input<String> {
                return input
            } else {
                let input = Input<String>()
                objc_setAssociatedObject(self, &key, input, .OBJC_ASSOCIATION_RETAIN)
                return input
            }
        }
    }
    
    public var channel: Channel<String> {
        get {
            startSending()
            return input.channel
        }
    }
    
    private func startSending() {
        self.addTarget(self, action: #selector(textDidChange(_:)), for: .editingChanged)
    }
    
    public dynamic func textDidChange(_ sender: Any?) {
        self.input.send(value: self.text ?? "")
    }

}
