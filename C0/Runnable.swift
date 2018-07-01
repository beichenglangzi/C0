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
protocol Newable {
    func new(for p: Point, _ version: Version)
}

struct RunnableActionList: SubActionList {
//    let runAction = Action(name: Text(english: "Run", japanese: "実行"),
//                           quasimode: Quasimode([.input(.click)]))
    let newAction = Action(name: Text(english: "New", japanese: "新規"),
                           quasimode: Quasimode(modifier: [.input(.command)],
                                                [.input(.d)]))
    let exportAction = Action(name: Text(english: "Export", japanese: "書き出す"),
                              quasimode: Quasimode(modifier: [.input(.command)],
                                                   [.input(.e)]))
    
    var actions: [Action] {
        return [newAction, exportAction]
    }
}
extension RunnableActionList: SubSendable {
    func makeSubSender() -> SubSender {
        return RunnableSender(actionList: self)
    }
}

final class RunnableSender: SubSender {
    typealias Receiver = View & Runnable
    typealias NewableReceiver = View & Newable
    
    typealias ActionList = RunnableActionList
    var actionList: ActionList
    
    init(actionList: ActionList) {
        self.actionList = actionList
    }
    
    func send(_ actionMap: ActionMap, from sender: Sender) {
        switch actionMap.action {
//        case actionList.runAction:
//            guard actionMap.phase == .began else { break }
//            if let eventValue = actionMap.eventValuesWith(InputEvent.self).first,
//                let receiver = sender.mainIndicatedView as? Receiver {
//
//                sender.stopAllEvents()
//                let p = receiver.convertFromRoot(eventValue.rootLocation)
//                receiver.run(for: p, sender.indicatedVersionView.version)
//            }
        case actionList.newAction:
            guard actionMap.phase == .began else { break }
            if let eventValue = actionMap.eventValuesWith(InputEvent.self).first,
                let receiver = sender.mainIndicatedView as? NewableReceiver {
                
                let p = receiver.convertFromRoot(eventValue.rootLocation)
                sender.stopEditableEvents()
                receiver.new(for: p, sender.indicatedVersionView.version)
            }
        default: break
        }
    }
}
