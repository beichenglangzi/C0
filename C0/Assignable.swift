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

protocol CopiedObjectsViewer: class {
    var copiedObjects: [Object] { get }
    func push(_ copiedObjects: [Object], to version: Version)
}
protocol Copiable {
    func copiedObjects(at p: Point) -> [Object]
}
protocol Assignable: Copiable {
    func paste(_ objects: [Any], for p: Point, _ version: Version)
}
protocol CollectionAssignable: Assignable {
    func remove(for p: Point, _ version: Version)
}

struct AssignableActionList: SubActionList {
    let cutAction = Action(name: Text(english: "Cut", japanese: "カット"),
                           quasimode: Quasimode(modifier: [.input(.command)],
                                                [.input(.x)]))
    let copyAction = Action(name: Text(english: "Copy", japanese: "コピー"),
                            quasimode: Quasimode(modifier: [.input(.command)],
                                                 [.input(.c)]))
    let pasteAction = Action(name: Text(english: "Paste", japanese: "ペースト"),
                             quasimode: Quasimode(modifier: [.input(.command)],
                                                  [.input(.v)]))
    var actions: [Action] {
        return [cutAction, copyAction, pasteAction]
    }
}
extension AssignableActionList: SubSendable {
    func makeSubSender() -> SubSender {
        return AssignableSender(actionList: self)
    }
}

final class AssignableSender: SubSender {
    typealias CopiedObjectViewer = View & CopiedObjectsViewer
    typealias Receiver = View & Assignable
    typealias CollectionReceiver = View & CollectionAssignable
    typealias CopiableReceiver = View & Copiable
    
    typealias ActionList = AssignableActionList
    var actionList: ActionList
    
    init(actionList: ActionList) {
        self.actionList = actionList
    }
    
    func send(_ actionMap: ActionMap, from sender: Sender) {
        switch actionMap.action {
        case actionList.cutAction:
            guard actionMap.phase == .began else { break }
            if let eventValue = actionMap.eventValuesWith(InputEvent.self).first,
                let receiver = sender.mainIndicatedView
                    .withSelfAndAllParents(with: CollectionReceiver.self),
                let viewer = receiver.withSelfAndAllParents(with: CopiedObjectViewer.self) {
                
                let p = receiver.convertFromRoot(eventValue.rootLocation)
                let copiedObjects = receiver.copiedObjects(at: p)
                if !copiedObjects.isEmpty {
                    sender.stopEditableEvents()
                    receiver.remove(for: p, sender.indicatedVersionView.version)
                    viewer.push(copiedObjects, to: sender.indicatedVersionView.version)
                }
            }
        case actionList.copyAction:
            guard actionMap.phase == .began else { break }
            if let eventValue = actionMap.eventValuesWith(InputEvent.self).first,
                let receiver = sender.mainIndicatedView as? CopiableReceiver,
                let viewer = receiver.withSelfAndAllParents(with: CopiedObjectViewer.self) {
                
                let p = receiver.convertFromRoot(eventValue.rootLocation)
                let copiedObjects = receiver.copiedObjects(at: p)
                if !copiedObjects.isEmpty {
                    sender.stopEditableEvents()
                    viewer.push(copiedObjects, to: sender.indicatedVersionView.version)
                }
            }
        case actionList.pasteAction:
            guard actionMap.phase == .began else { break }
            if let eventValue = actionMap.eventValuesWith(InputEvent.self).first,
                let receiver = sender.mainIndicatedView as? Receiver,
                let viewer = receiver.withSelfAndAllParents(with: CopiedObjectViewer.self) {
                
                let p = receiver.convertFromRoot(eventValue.rootLocation)
                sender.stopEditableEvents()
                receiver.paste(viewer.copiedObjects, for: p, sender.indicatedVersionView.version)
            }
        default: break
        }
    }
}
