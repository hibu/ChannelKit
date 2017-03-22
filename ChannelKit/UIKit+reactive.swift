//
//  UIKit+reactive.swift
//  ChannelKit
//
//  Created by Marc Palluat de Besset on 14/12/2016.
//  Copyright © 2016 hibu. All rights reserved.
//

import UIKit
import ObjectiveC

fileprivate var inputKey = "inputkey"
fileprivate var enabledKey = "enabledKey"
fileprivate var textKey = "textKey"
fileprivate var animateKey = "animateKey"
fileprivate var progressKey = "progressKey"
fileprivate var imageKey = "imageKey"
fileprivate var hiddenKey = "hiddenKey"


extension UIView {
    
    public func isHidden(with channel: Channel<Bool>?, initialState: Bool = false) {
        if let channel = channel {
            let output = channel.subscribe(initial: initialState) { [unowned self] (result) in
                switch result {
                case let .success(value):
                    self.isHidden = value
                case .failure(_):
                    self.isHidden = false
                }
            }
            setOutput(output, for: self, key: &hiddenKey)
        } else {
            deleteOutput(for: self, key: &hiddenKey)
        }
    }
}

extension UIControl {
    
    public func isEnabled(with channel: Channel<Bool>?, initialState: Bool = false) {
        if let channel = channel {
            let output = channel.subscribe(initial: initialState) { [unowned self] (result) in
                
                switch result {
                case let .success(value):
                    self.isEnabled = value
                case .failure(_):
                    self.isEnabled = false
                }
            }
            setOutput(output, for: self, key: &enabledKey)
        } else {
            deleteOutput(for: self, key: &enabledKey)
        }
    }
}

extension UIButton {
    
    public var channel: Channel<Bool> {
        get {
            let input: Input<Bool> = getInput(for: self, key: &inputKey)
            if !input.hasChannel() {
                let channel = input.channel
                self.addTarget(self, action: #selector(tap(_:)), for: .touchUpInside)
                channel.setCleanup { [weak self] in
                    if let me = self {
                        me.removeTarget(me, action: #selector(me.tap(_:)), for: .touchUpInside)
                        deleteInput(for: me, key: &inputKey)
                    }
                }
                return channel
            }
            return input.channel
        }
    }
    
    dynamic public func tap(_ sender: Any?) {
        let input: Input<Bool> = getInput(for: self, key: &inputKey)
        input.send(value: true)
        input.send(value: false)
    }
    
}

extension UITextField {
    
    public var channel: Channel<String> {
        get {
            let input: Input<String> = getInput(for: self, key: &inputKey)
            if !input.hasChannel() {
                let channel = input.channel
                self.addTarget(self, action: #selector(textDidChange(_:)), for: .editingChanged)
                self.addTarget(self, action: #selector(textDidChangeOnExit(_:)), for: .editingDidEndOnExit)
                channel.setCleanup { [weak self] in
                    if let me = self {
                        me.removeTarget(me, action: #selector(me.textDidChange(_:)), for: .editingChanged)
                        me.removeTarget(me, action: #selector(me.textDidChange(_:)), for: .editingDidEndOnExit)
                        deleteInput(for: me, key: &inputKey)
                    }
                }
                return channel
            }
            return input.channel
        }
    }
    
    public dynamic func textDidChange(_ sender: Any?) {
        let input: Input<String> = getInput(for: self, key: &inputKey)
        input.send(value: text ?? "")
    }
    
    public dynamic func textDidChangeOnExit(_ sender: Any?) {
        let input: Input<String> = getInput(for: self, key: &inputKey)
        if let text = text {
           input.send(value: text + "\n")
        } else {
            input.send(value: "\n")
        }
    }
}

extension UILabel {
    
    public func isEnabled(with channel: Channel<Bool>?, initialState: Bool = false) {
        if let channel = channel {
            let output = channel.subscribe(initial: initialState) { (result) in
                
                switch result {
                case let .success(value):
                    self.isEnabled = value
                case .failure(_):
                    self.isEnabled = false
                }
            }
            setOutput(output, for: self, key: &enabledKey)
        } else {
            deleteOutput(for: self, key: &enabledKey)
        }
    }

    public func text(with channel: Channel<String>?, initialState: String = "") {
        if let channel = channel {
            let output = channel.subscribe(initial: initialState) { (result) in

                switch result {
                case let .success(value):
                    self.text = value
                case .failure(_):
                    self.text = ""
                }
            }
            setOutput(output, for: self, key: &textKey)
        } else {
            deleteOutput(for: self, key: &textKey)
        }
    }

}

extension UISlider {
    
    public var channel: Channel<Float> {
        get {
            let input: Input<Float> = getInput(for: self, key: &inputKey)
            if !input.hasChannel() {
                let channel = input.channel
                self.addTarget(self, action: #selector(valueDidChange(_:)), for: .editingChanged)
                channel.setCleanup { [weak self] in
                    if let me = self {
                        me.removeTarget(me, action: #selector(me.valueDidChange(_:)), for: .editingChanged)
                        deleteInput(for: me, key: &inputKey)
                    }
                }
                return channel
            }
            return input.channel
        }
    }
    
    public dynamic func valueDidChange(_ sender: Any?) {
        let input: Input<Float> = getInput(for: self, key: &inputKey)
        input.send(value: value)
    }
    
}

extension UISwitch {
    
    public var channel: Channel<Bool> {
        get {
            let input: Input<Bool> = getInput(for: self, key: &inputKey)
            if !input.hasChannel() {
                let channel = input.channel
                self.addTarget(self, action: #selector(valueDidChange(_:)), for: .valueChanged)
                channel.setCleanup { [weak self] in
                    if let me = self {
                        me.removeTarget(me, action: #selector(me.valueDidChange(_:)), for: .valueChanged)
                        deleteInput(for: me, key: &inputKey)
                    }
                }
                return channel
            }
            return input.channel
        }
    }
    
    public dynamic func valueDidChange(_ sender: Any?) {
        let input: Input<Bool> = getInput(for: self, key: &inputKey)
        input.send(value: isOn)
    }
}

extension UIActivityIndicatorView {
    
    public func animate(with channel: Channel<Bool>?, initialState: Bool = false) {
        if let channel = channel {
            let output = channel.subscribe(initial: initialState) { [unowned self] (result) in
                
                switch result {
                case let .success(value):
                    if value {
                        self.startAnimating()
                    } else {
                        self.stopAnimating()
                    }
                case .failure(_):
                    self.stopAnimating()
                }
            }
            setOutput(output, for: self, key: &animateKey)
        } else {
            deleteOutput(for: self, key: &animateKey)
        }
    }
}

extension UIProgressView {
    
    public func progress(with channel: Channel<Float>?, initialState: Float = 0) {
        if let channel = channel {
            let output = channel.subscribe(initial: initialState) { [unowned self] (result) in
                if case let .success(value) = result {
                    self.progress = value
                }
            }
            setOutput(output, for: self, key: &progressKey)
        } else {
            deleteOutput(for: self, key: &progressKey)
        }
    }
}

extension UIStepper {
    
    public var channel: Channel<Double> {
        get {
            let input: Input<Double> = getInput(for: self, key: &inputKey)
            if !input.hasChannel() {
                let channel = input.channel
                self.addTarget(self, action: #selector(valueDidChange(_:)), for: .valueChanged)
                channel.setCleanup { [weak self] in
                    if let me = self {
                        me.removeTarget(me, action: #selector(me.valueDidChange(_:)), for: .valueChanged)
                        deleteInput(for: me, key: &inputKey)
                    }
                }
                return channel
            }
            return input.channel
        }
    }
    
    public dynamic func valueDidChange(_ sender: Any?) {
        let input: Input<Double> = getInput(for: self, key: &inputKey)
        input.send(value: value)
    }

}

extension UIImageView {
    
    public func image(with channel: Channel<UIImage?>?, initialState: UIImage? = nil) {
        if let channel = channel {
            let output = channel.subscribe(initial: initialState) { [unowned self] (result) in
                if case let .success(value) = result {
                    self.image = value
                }
            }
            setOutput(output, for: self, key: &imageKey)
        } else {
            deleteOutput(for: self, key: &imageKey)
        }
    }

}

extension Input {
    
    public func adapt(view: UIView) {
        
        switch view {
        case let textField as UITextField:
            let input: Input<T> = getInput(for: textField, key: &inputKey)
            input.deleteChannel()
            let channel = textField.channel
            channel.debug = input.debug // this is to quiet a warning
            adapt(channel: input.channel)
        case let button as UIButton:
            let input: Input<T> = getInput(for: button, key: &inputKey)
            input.deleteChannel()
            let channel = button.channel
            channel.debug = input.debug // this is to quiet a warning
            adapt(channel: input.channel)
        default:
            ()
        }
    }

}


fileprivate func getInput<T>(for view: UIView, key: UnsafeRawPointer) -> Input<T> {
    if let input = objc_getAssociatedObject(view, key) as? Input<T> {
        return input
    } else {
        let input = Input<T>()
        objc_setAssociatedObject(view, key, input, .OBJC_ASSOCIATION_RETAIN)
        return input
    }
}

fileprivate func deleteInput(for view: UIView, key: UnsafeRawPointer) {
    objc_setAssociatedObject(view, key, nil, .OBJC_ASSOCIATION_RETAIN)
}

fileprivate func setOutput<T>(_ output: Output<T>, for view: UIView, key: UnsafeRawPointer) {
    objc_setAssociatedObject(view, key, output, .OBJC_ASSOCIATION_RETAIN)
}

fileprivate func deleteOutput(for view: UIView, key: UnsafeRawPointer) {
    objc_setAssociatedObject(view, key, nil, .OBJC_ASSOCIATION_RETAIN)
}


