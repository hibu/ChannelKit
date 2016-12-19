

import UIKit
import ChannelKit
import PlaygroundSupport


var str = "anticonstitutionnellement"
let input = Input<String>()

let channel = input.channel.map { (str) in
    return str.uppercased()
}

let channels = channel.split()

let output = channels.first?.subscribe { (result) in
    switch result {
    case let .success(value):
        print(value)
    case let .failure(error):
        print(error)
    }
}

let end = channels.last?.map { (str) -> Int in
    return str.characters.count
}

end?.subscribe { (result) in
    switch result {
    case let .success(value):
        print(value)
    case let .failure(error):
        print(error)
    }
    
    Queue.main.after(5) {
        PlaygroundPage.current.finishExecution()
    }
}

input.send(value: str)

PlaygroundPage.current.needsIndefiniteExecution = true


