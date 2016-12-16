//
//  UIKit+reactive.swift
//  ChannelKit
//
//  Created by Marc Palluat de Besset on 14/12/2016.
//  Copyright © 2016 hibu. All rights reserved.
//

import UIKit
import ObjectiveC

private var inputKey = "inputkey"
private var enabledKey = "enabledKey"
private var textKey = "textKey"
private var animateKey = "animateKey"
private var progressKey = "progressKey"
private var imageKey = "imageKey"
private var hiddenKey = "hiddenKey"


extension UIView {
    
    public func isHidden(with channel: Channel<Bool>, initialState: Bool = false) {
        let output = channel.subscribe(initial: initialState) { [unowned self] (result) in
            if case let .success(value) = result {
                self.isHidden = value
            }
        }
        setOutput(output, for: self, key: &hiddenKey)
    }
}

extension UIControl {
    
    public func isEnabled(with channel: Channel<Bool>, initialState: Bool = false) {
        let output = channel.subscribe(initial: initialState) { [unowned self] (result) in
            if case let .success(value) = result {
                self.isEnabled = value
            }
        }
        setOutput(output, for: self, key: &enabledKey)
    }
}

extension UIButton {
    
    public var channel: Channel<Void> {
        get {
            let input: Input<Void> = getInput(for: self, key: &inputKey)
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
        let input: Input<Void> = getInput(for: self, key: &inputKey)
        input.send(value: ())
    }
    
}

extension UITextField {
    
    public var channel: Channel<String> {
        get {
            let input: Input<String> = getInput(for: self, key: &inputKey)
            if !input.hasChannel() {
                let channel = input.channel
                self.addTarget(self, action: #selector(textDidChange(_:)), for: .editingChanged)
                channel.setCleanup { [weak self] in
                    if let me = self {
                        me.removeTarget(me, action: #selector(me.textDidChange(_:)), for: .editingChanged)
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
}

extension UILabel {
    
    public func isEnabled(with channel: Channel<Bool>, initialState: Bool = false) {
        let output = channel.subscribe(initial: initialState) { (result) in
            if case let .success(value) = result {
                self.isEnabled = value
            }
        }
        setOutput(output, for: self, key: &enabledKey)
    }

    public func text(with channel: Channel<String>, initialState: String = "") {
        let output = channel.subscribe(initial: initialState) { (result) in
            if case let .success(value) = result {
                self.text = value
            }
        }
        setOutput(output, for: self, key: &textKey)
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
    
    public func animate(with channel: Channel<Bool>, initialState: Bool = false) {
        let output = channel.subscribe(initial: initialState) { [unowned self] (result) in
            if case let .success(value) = result {
                if value {
                    self.startAnimating()
                } else {
                    self.stopAnimating()
                }
            }
        }
        setOutput(output, for: self, key: &animateKey)
    }
}

extension UIProgressView {
    
    public func progress(with channel: Channel<Float>, initialState: Float = 0) {
        let output = channel.subscribe(initial: initialState) { [unowned self] (result) in
            if case let .success(value) = result {
                self.progress = value
            }
        }
        setOutput(output, for: self, key: &progressKey)
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
    
    public func image(with channel: Channel<UIImage?>, initialState: UIImage? = nil) {
        let output = channel.subscribe(initial: initialState) { [unowned self] (result) in
            if case let .success(value) = result {
                self.image = value
            }
        }
        setOutput(output, for: self, key: &imageKey)
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

fileprivate func setOutput<T>(_ output: Output<T>?, for view: UIView, key: UnsafeRawPointer) {
    objc_setAssociatedObject(view, key, output, .OBJC_ASSOCIATION_RETAIN)
}


