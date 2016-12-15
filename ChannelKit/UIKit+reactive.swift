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
    
    public func setHidden(with channel: Channel<Bool>, initialState: Bool = false) {
        let output = channel.subscribe(initial: initialState) { [unowned self] (result) in
            if case let .success(value) = result {
                self.isHidden = value
            }
        }
        objc_setAssociatedObject(self, &hiddenKey, output, .OBJC_ASSOCIATION_RETAIN)
    }
}

extension UIControl {
    
    public func setEnabled(with channel: Channel<Bool>, initialState: Bool = false) {
        let output = channel.subscribe(initial: initialState) { [unowned self] (result) in
            if case let .success(value) = result {
                self.isEnabled = value
            }
        }
        objc_setAssociatedObject(self, &enabledKey, output, .OBJC_ASSOCIATION_RETAIN)
    }
}

extension UIButton {
    
    private var input: Input<Void> {
        get {
            if let input = objc_getAssociatedObject(self, &inputKey) as? Input<Void> {
                return input
            } else {
                let input = Input<Void>()
                objc_setAssociatedObject(self, &inputKey, input, .OBJC_ASSOCIATION_RETAIN)
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
        input.send(value: ())
    }
    
    
}

extension UITextField {
    
    private var input: Input<String> {
        get {
            if let input = objc_getAssociatedObject(self, &inputKey) as? Input<String> {
                return input
            } else {
                let input = Input<String>()
                objc_setAssociatedObject(self, &inputKey, input, .OBJC_ASSOCIATION_RETAIN)
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
        input.send(value: text ?? "")
    }
    
}

extension UILabel {
    
    public func setEnabled(with channel: Channel<Bool>, initialState: Bool = false) {
        let output = channel.subscribe(initial: initialState) { (result) in
            if case let .success(value) = result {
                self.isEnabled = value
            }
        }
        objc_setAssociatedObject(self, &enabledKey, output, .OBJC_ASSOCIATION_RETAIN)
    }

    public func setText(with channel: Channel<String>, initialState: String = "") {
        let output = channel.subscribe(initial: initialState) { (result) in
            if case let .success(value) = result {
                self.text = value
            }
        }
        objc_setAssociatedObject(self, &textKey, output, .OBJC_ASSOCIATION_RETAIN)
    }

}

extension UISlider {
    
    private var input: Input<Float> {
        get {
            if let input = objc_getAssociatedObject(self, &inputKey) as? Input<Float> {
                return input
            } else {
                let input = Input<Float>()
                objc_setAssociatedObject(self, &inputKey, input, .OBJC_ASSOCIATION_RETAIN)
                return input
            }
        }
    }
    
    public var channel: Channel<Float> {
        get {
            startSending()
            return input.channel
        }
    }
    
    private func startSending() {
        self.addTarget(self, action: #selector(valueDidChange(_:)), for: .valueChanged)
    }

    public dynamic func valueDidChange(_ sender: Any?) {
        input.send(value: value)
    }
    
}

extension UISwitch {
    
    private var input: Input<Bool> {
        get {
            if let input = objc_getAssociatedObject(self, &inputKey) as? Input<Bool> {
                return input
            } else {
                let input = Input<Bool>()
                objc_setAssociatedObject(self, &inputKey, input, .OBJC_ASSOCIATION_RETAIN)
                return input
            }
        }
    }
    
    public var channel: Channel<Bool> {
        get {
            startSending()
            return input.channel
        }
    }
    
    private func startSending() {
        self.addTarget(self, action: #selector(valueDidChange(_:)), for: .valueChanged)
    }
    
    public dynamic func valueDidChange(_ sender: Any?) {
        input.send(value: isOn)
    }
}

extension UIActivityIndicatorView {
    
    public func setAnimate(with channel: Channel<Bool>, initialState: Bool = false) {
        let output = channel.subscribe(initial: initialState) { [unowned self] (result) in
            if case let .success(value) = result {
                if value {
                    self.startAnimating()
                } else {
                    self.stopAnimating()
                }
            }
        }
        objc_setAssociatedObject(self, &animateKey, output, .OBJC_ASSOCIATION_RETAIN)
    }
}

extension UIProgressView {
    
    public func setProgress(with channel: Channel<Float>, initialState: Float = 0) {
        let output = channel.subscribe(initial: initialState) { [unowned self] (result) in
            if case let .success(value) = result {
                self.progress = value
            }
        }
        objc_setAssociatedObject(self, &progressKey, output, .OBJC_ASSOCIATION_RETAIN)
    }
}

extension UIStepper {
    
    private var input: Input<Double> {
        get {
            if let input = objc_getAssociatedObject(self, &inputKey) as? Input<Double> {
                return input
            } else {
                let input = Input<Double>()
                objc_setAssociatedObject(self, &inputKey, input, .OBJC_ASSOCIATION_RETAIN)
                return input
            }
        }
    }
    
    public var channel: Channel<Double> {
        get {
            startSending()
            return input.channel
        }
    }
    
    private func startSending() {
        self.addTarget(self, action: #selector(valueDidChange(_:)), for: .valueChanged)
    }
    
    public dynamic func valueDidChange(_ sender: Any?) {
        input.send(value: value)
    }

}

extension UIImageView {
    
    public func setImage(with channel: Channel<UIImage?>, initialState: UIImage? = nil) {
        let output = channel.subscribe(initial: initialState) { [unowned self] (result) in
            if case let .success(value) = result {
                self.image = value
            }
        }
        objc_setAssociatedObject(self, &imageKey, output, .OBJC_ASSOCIATION_RETAIN)
    }

}

