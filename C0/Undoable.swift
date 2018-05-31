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

protocol Undoable {
    var version: Version { get }
}
struct UndoableActionManager: SubActionManagable {
    let undoAction = Action(name: Text(english: "Undo", japanese: "取り消す"),
                            quasimode: Quasimode(modifier: [.input(.command)],
                                                 [.input(.z)]))
    let redoAction = Action(name: Text(english: "Redo", japanese: "やり直す"),
                            quasimode: Quasimode(modifier: [.input(.shift),
                                                            .input(.command)],
                                                 [.input(.z)]))
    var actions: [Action] {
        return [undoAction, redoAction]
    }
}
extension UndoableActionManager: SubSendable {
    func makeSubSender() -> SubSender {
        return UndoableSender(actionManager: self)
    }
}

final class UndoableSender: SubSender {
    typealias Receiver = View & Undoable
    typealias ActionManager = UndoableActionManager
    
    var actionManager: ActionManager
    
    init(actionManager: ActionManager) {
        self.actionManager = actionManager
    }
    
    func send(_ actionMap: ActionMap, from sender: Sender) {
        switch actionMap.action {
        case actionManager.undoAction:
            guard actionMap.phase == .began else { break }
            sender.stopAllEvents()
            sender.indicatedVersionView.version.undo()
        case actionManager.redoAction:
            guard actionMap.phase == .began else { break }
            sender.stopAllEvents()
            sender.indicatedVersionView.version.redo()
        default: break
        }
    }
}
