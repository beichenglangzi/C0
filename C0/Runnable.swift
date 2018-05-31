/*
 Copyright 2018 S
 
 This file is part of C0.
 
 C0 is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 C0 is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with C0.  If not, see <http://www.gnu.org/licenses/>.
 */

protocol Runnable {
    func run(for p: Point, _ version: Version)
}

struct RunnableActionManager: SubActionManagable {
    let runAction = Action(name: Text(english: "Run", japanese: "実行"),
                           quasimode: Quasimode([.input(.click)]))
    var actions: [Action] {
        return [runAction]
    }
}
extension RunnableActionManager: SubSendable {
    func makeSubSender() -> SubSender {
        return RunnableSender(actionManager: self)
    }
}

final class RunnableSender: SubSender {
    typealias Receiver = View & Runnable
    
    typealias ActionManager = RunnableActionManager
    var actionManager: ActionManager
    
    init(actionManager: ActionManager) {
        self.actionManager = actionManager
    }
    
    func send(_ actionMap: ActionMap, from sender: Sender) {
        switch actionMap.action {
        case actionManager.runAction:
            guard actionMap.phase == .began else { break }
            if let eventValue = actionMap.eventValuesWith(InputEvent.self).first,
                let receiver = sender.mainIndicatedView as? Receiver {
                
                sender.stopAllEvents()
                let p = receiver.convertFromRoot(eventValue.rootLocation)
                receiver.run(for: p, sender.indicatedVersionView.version)
            }
        default: break
        }
    }
}
