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
    func reset(for p: Point, _ version: Version)
    func paste(_ objects: [Any], for p: Point, _ version: Version)
}
protocol CollectionAssignable: Assignable {
    func remove(for p: Point, _ version: Version)
    func add(_ objects: [Any], for p: Point, _ version: Version)
}
protocol Newable {
    func new(for p: Point, _ version: Version)
}

struct AssignableActionManager: SubActionManagable {
    let resetAction = Action(name: Text(english: "Reset", japanese: "リセット"),
                             quasimode: Quasimode(modifier: [InputEvent.EventType.shift,
                                                             InputEvent.EventType.command],
                                                  [InputEvent.EventType.x]))
    let cutAction = Action(name: Text(english: "Cut", japanese: "カット"),
                           quasimode: Quasimode(modifier: [InputEvent.EventType.command],
                                                [InputEvent.EventType.x]))
    let copyAction = Action(name: Text(english: "Copy", japanese: "コピー"),
                            quasimode: Quasimode(modifier: [InputEvent.EventType.command],
                                                 [InputEvent.EventType.c]))
    let pasteAction = Action(name: Text(english: "Paste", japanese: "ペースト"),
                             quasimode: Quasimode(modifier: [InputEvent.EventType.command],
                                                  [InputEvent.EventType.v]))
    let addAction = Action(name: Text(english: "Add", japanese: "加算"),
                           quasimode: Quasimode(modifier: [InputEvent.EventType.command],
                                                [InputEvent.EventType.d]))
    let newAction = Action(name: Text(english: "New", japanese: "新規"),
                           quasimode: Quasimode(modifier: [InputEvent.EventType.command],
                                                [InputEvent.EventType.e]))
    var actions: [Action] {
        return [resetAction, cutAction, copyAction, pasteAction, addAction, newAction]
    }
}
extension AssignableActionManager: SubSendable {
    func makeSubSender() -> SubSender {
        return AssignableSender(actionManager: self)
    }
}

final class AssignableSender: SubSender {
    typealias CopiedObjectViewer = View & CopiedObjectsViewer
    typealias Receiver = View & Assignable
    typealias CollectionReceiver = View & CollectionAssignable
    typealias CopiableReceiver = View & Copiable
    typealias NewableReceiver = View & Newable
    
    typealias ActionManager = AssignableActionManager
    var actionManager: ActionManager
    
    init(actionManager: ActionManager) {
        self.actionManager = actionManager
    }
    
    func send(_ actionMap: ActionMap, from sender: Sender) {
        switch actionMap.action {
        case actionManager.resetAction:
            if let eventValue = actionMap.eventValuesWith(InputEvent.self).first,
                let receiver = sender.mainIndicatedView as? Receiver {
                
                let p = receiver.convertFromRoot(eventValue.rootLocation)
                sender.stopEditableEvents()
                receiver.reset(for: p, sender.indicatedVersionView.version)
            }
        case actionManager.cutAction:
            if let eventValue = actionMap.eventValuesWith(InputEvent.self).first,
                let receiver = sender.mainIndicatedView as? CollectionReceiver,
                let viewer = receiver.withSelfAndAllParents(with: CopiedObjectViewer.self) {
                
                let p = receiver.convertFromRoot(eventValue.rootLocation)
                let copiedObjects = receiver.copiedObjects(at: p)
                if !copiedObjects.isEmpty {
                    sender.stopEditableEvents()
                    receiver.remove(for: p, sender.indicatedVersionView.version)
                    viewer.push(copiedObjects, to: sender.indicatedVersionView.version)
                }
            }
        case actionManager.copyAction:
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
        case actionManager.pasteAction:
            if let eventValue = actionMap.eventValuesWith(InputEvent.self).first,
                let receiver = sender.mainIndicatedView as? Receiver,
                let viewer = receiver.withSelfAndAllParents(with: CopiedObjectViewer.self) {
                
                let p = receiver.convertFromRoot(eventValue.rootLocation)
                sender.stopEditableEvents()
                receiver.paste(viewer.copiedObjects, for: p, sender.indicatedVersionView.version)
            }
        case actionManager.addAction:
            if let eventValue = actionMap.eventValuesWith(InputEvent.self).first,
                let receiver = sender.mainIndicatedView as? CollectionReceiver,
                let viewer = receiver.withSelfAndAllParents(with: CopiedObjectViewer.self) {
                
                let p = receiver.convertFromRoot(eventValue.rootLocation)
                sender.stopEditableEvents()
                receiver.add(viewer.copiedObjects, for: p, sender.indicatedVersionView.version)
            }
        case actionManager.newAction:
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
