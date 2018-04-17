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

import Foundation

protocol Sendable {
    func sendMoveCursor(with event: MoveCursorEvent)
    func sendViewQuasimode(with event: Event)
    func sendKeyInputIsEditText(with event: KeyInputEvent) -> Bool
    func sendSubDrag(with event: SubDragEvent)
    func sendDrag(with event: DragEvent)
    func sendScroll(with event: ScrollEvent, momentum: Bool)
    func sendPinch(with event: PinchEvent)
    func sendRotate(with event: RotateEvent)
    func sendTap(with event: TapEvent)
    func sendDoubleTap(with event: DoubleTapEvent)
}

final class Sender: Sendable {
    var rootView: RootView
    var actionManager: ActionManager
    
    init(rootView: RootView, actionManager: ActionManager) {
        self.rootView = rootView
        self.actionManager = actionManager
        indicatedResponders = [rootView]
    }
    
    var setEditTextView: (((sender: Sender, textView: TextView?, oldValue: TextView?)) -> ())?
    var indicatedResponders: [Respondable] {
        didSet {
            guard !indicatedResponders.elementsEqual(oldValue, by: { $0 === $1 }) else {
                return
            }
            let indicatedResponder = indicatedResponders[0], oldIndicatedResponder = oldValue[0]
            var allParents = [Layer]()
            if let indicatedLayer = indicatedResponder as? Layer {
                indicatedLayer.allSubIndicatedParentsAndSelf { allParents.append($0) }
            }
            if let oldIndicatedLayer = oldIndicatedResponder as? Layer {
                oldIndicatedLayer.allSubIndicatedParentsAndSelf { responder in
                    if let index = allParents.index(where: { $0 === responder }) {
                        allParents.remove(at: index)
                    } else {
                        responder.isSubIndicated = false
                    }
                }
            }
            allParents.forEach { $0.isSubIndicated = true }
            oldValue.forEach { $0.isIndicated = false }
            indicatedResponders.forEach { $0.isIndicated = true }
//            oldIndicatedResponder.isIndicated = false
//            indicatedResponder.isIndicated = true
            if indicatedResponder is TextView || oldIndicatedResponder is TextView {
                if let editTextView = oldIndicatedResponder as? TextView {
                    editTextView.unmarkText()
                }
                setEditTextView?((self, indicatedResponder as? TextView,
                                  oldIndicatedResponder as? TextView))
            }
        }
    }
    func setIndicatedResponders(at p: CGPoint) {
        let indicatedResponders = responder(with: indicatedLayer(at: p))
        if !indicatedResponders.elementsEqual(self.indicatedResponders) { $0 === $1 } {
            self.indicatedResponders = indicatedResponders
        }
    }
    func indicatedResponder(with event: Event) -> Respondable {
        return (rootView.at(event.location) as? Respondable) ?? rootView
    }
    func indicatedLayer(with event: Event) -> Layer {
        return rootView.at(event.location) ?? rootView
    }
    func indicatedLayer(at p: CGPoint) -> Layer {
        return rootView.at(p) ?? rootView
    }
//    func responder(with beginLayer: Layer,
//                   closure: (Respondable) -> (Bool) = { _ in true }) -> Respondable {
//        var responder: Respondable?
//        beginLayer.allParentsAndSelf { (layer, stop) in
//            if let r = layer as? Respondable, closure(r) {
//                responder = r
//                stop = true
//            }
//        }
//        return responder ?? rootView
//    }
    func responder(with beginLayer: Layer,
                   closure: ([Respondable]) -> (Bool) = { _ in true }) -> [Respondable] {
        var responders = [Respondable](), tempResponders = [Respondable]()
        beginLayer.allParentsAndSelf { (layer, stop) in
            if let r = layer as? Respondable {
                tempResponders.append(r)
                if !r.isForm {
                    let aResponders: [Respondable] = tempResponders.reversed()
                    if closure(aResponders) {
                        responders = aResponders
                        stop = true
                    }
                    tempResponders = []
                }
            }
        }
        return responders.isEmpty ? [rootView] : responders
    }
    
    var editTextView: TextView? {
        if let editTextView = indicatedResponders.first as? TextView {
            return editTextView.isLocked ? nil : editTextView
        } else {
            return nil
        }
    }
    
    private let defaultMoveCursorAction = Action(quasimode: Quasimode(gesture: .moveCursor),
                                                 moveCursor: { $0[0].moveCursor(with: $1) })
    func sendMoveCursor(with event: MoveCursorEvent) {
        rootView.rootCursorPoint = event.location
        let indicatedLayer = self.indicatedLayer(with: event)
        let indicatedResponders = responder(with: indicatedLayer)
        if !indicatedResponders.elementsEqual(self.indicatedResponders) { $0 === $1 } {
            self.indicatedResponders = indicatedResponders
            cursor = indicatedResponders[0].cursor
        }
        _ = responder(with: indicatedLayer) { $0[0].moveCursor(with: event) }
    }
    
    var setCursorClosure: (((sender: Sender, cursor: Cursor, oldCursor: Cursor)) -> ())?
    var cursor = Cursor.arrow {
        didSet {
            setCursorClosure?((self, cursor, oldValue))
        }
    }
    
    private var oldViewQuasimodeAction = Action()
    private var oldViewQuasimodeResponders = [Respondable]()
    func sendViewQuasimode(with event: Event) {
        let viewQuasimodeAction = actionManager.actionWith(.drag, event) ?? Action()
        if dragAction == nil {
            if rootView.viewQuasimode != viewQuasimodeAction.viewQuasimode {
                rootView.viewQuasimode = viewQuasimodeAction.viewQuasimode
                cursor = indicatedResponders[0].cursor
            }
        }
        oldViewQuasimodeAction = viewQuasimodeAction
        oldViewQuasimodeResponders = indicatedResponders
    }
    
    private var isKey = false, keyAction = Action(), keyEvent: KeyInputEvent?
    private weak var keyTextView: TextView?
    func sendKeyInputIsEditText(with event: KeyInputEvent) -> Bool {
        switch event.sendType {
        case .begin:
            setIndicatedResponders(at: event.location)
            guard dragAction == nil else {
                keyEvent = event
                return false
            }
            isKey = true
            keyAction = actionManager.actionWith(.keyInput, event)
                ?? Action(quasimode: Quasimode([], event.key))
            if let editTextView = editTextView, keyAction.quasimode.canTextKeyInput() {
                self.keyTextView = editTextView
                _ = keyAction.keyInput?([editTextView], event)
                return true
            } else if keyAction != Action() {
                _ = responder(with: indicatedLayer(with: event)) {
                    keyAction.keyInput?($0, event) ?? false
                }
            }
            let indicatedResponders = responder(with: indicatedLayer(with: event))
            if !indicatedResponders.elementsEqual(self.indicatedResponders) { $0 === $1 } {
                self.indicatedResponders = indicatedResponders
                cursor = indicatedResponders[0].cursor
            }
        case .sending:
            break
        case .end:
            if keyTextView != nil, isKey {
                keyTextView = nil
                return false
            }
        }
        return false
    }
    
    private let defaultClickAction = Action(quasimode: Quasimode(gesture: .click),
                                            click: { $0[0].run(with: $1) })
    private let defaultDragAction = Action(quasimode: Quasimode(gesture: .drag),
                                           drag: { $0[0].move(with: $1) })
    private var dragAction: Action?, firstDragEvent: DragEvent?
    private var dragResponders = [Respondable]()
    func sendDrag(with event: DragEvent) {
        switch event.sendType {
        case .begin:
            setIndicatedResponders(at: event.location)
            firstDragEvent = event
            dragAction = actionManager.actionWith(.drag, event) ?? defaultDragAction
            dragResponders = []
        case .sending:
            guard let dragAction = dragAction else {
                return
            }
            if !dragResponders.isEmpty {
                _ = dragAction.drag?(dragResponders, event)
            } else if let firstDragEvent = firstDragEvent {
                let dragResponders = responder(with: indicatedLayer(with: firstDragEvent)) {
                    dragAction.drag?($0, firstDragEvent) ?? false
                }
                self.firstDragEvent = nil
                self.dragResponders = dragResponders
                _ = dragAction.drag?(dragResponders, event)
            }
        case .end:
            guard let dragAction = dragAction else {
                return
            }
            if !dragResponders.isEmpty {
                _ = dragAction.drag?(dragResponders, event)
            } else {
                self.firstDragEvent = nil
                let clickAction = actionManager.actionWith(.click, event) ?? defaultClickAction
                _ = responder(with: indicatedLayer(with: event)) {
                    clickAction.click?($0, event) ?? false
                }
            }
            endAction(with: event, editAction: dragAction, editResponders: dragResponders)
            self.dragResponders = []
            self.dragAction = nil
        }
    }
    
    private var subDragAction: Action?, firstSubDragEvent: DragEvent?
    private var subDragResponders = [Respondable]()
    func sendSubDrag(with event: SubDragEvent) {
        switch event.sendType {
        case .begin:
            setIndicatedResponders(at: event.location)
            firstSubDragEvent = event
            subDragAction = actionManager.actionWith(.subDrag, event)
            subDragResponders = []
        case .sending:
            guard let subDragAction = subDragAction else {
                return
            }
            if !subDragResponders.isEmpty {
                _ = subDragAction.drag?(subDragResponders, event)
            } else if let firstSubDragEvent = firstSubDragEvent {
                let subDragResponders = responder(with: indicatedLayer(with: firstSubDragEvent)) {
                    subDragAction.drag?($0, firstSubDragEvent) ?? false
                }
                self.firstDragEvent = nil
                self.subDragResponders = subDragResponders
                _ = subDragAction.drag?(subDragResponders, event)
            }
        case .end:
            guard let subDragAction = subDragAction else {
                return
            }
            if !subDragResponders.isEmpty {
                _ = subDragAction.drag?(subDragResponders, event)
            } else {
                self.firstSubDragEvent = nil
                if let subClickAction = actionManager.actionWith(.subClick, event) {
                    _ = responder(with: indicatedLayer(with: event)) {
                        subClickAction.click?($0, event) ?? false
                    }
                }
            }
            endAction(with: event, editAction: subDragAction, editResponders: subDragResponders)
            self.subDragResponders = []
            self.subDragAction = nil
        }
    }
    
    func endAction(with event: Event, editAction: Action, editResponders: [Respondable]) {
        if var keyEvent = keyEvent {
            keyEvent.sendType = .begin
            _ = sendKeyInputIsEditText(with: keyEvent)
            self.keyEvent = nil
        } else {
            let indicatedResponders = responder(with: indicatedLayer(with: event))
            if !indicatedResponders.elementsEqual(self.indicatedResponders) { $0 === $1 } {
                self.indicatedResponders = indicatedResponders
                cursor = indicatedResponders[0].cursor
            }
        }
        if editAction != oldViewQuasimodeAction {
            if !editResponders.isEmpty {
                if !editResponders.elementsEqual(indicatedResponders) { $0 === $1 } {
                    editResponders[0].viewQuasimode = type(of: editResponders[0]).defaultViewQuasimode
                }
            }
            rootView.viewQuasimode = oldViewQuasimodeAction.viewQuasimode
            indicatedResponders[0].viewQuasimode = oldViewQuasimodeAction.viewQuasimode
        }
    }
    
    private var momentumScrollResponders = [Respondable]()
    func sendScroll(with event: ScrollEvent, momentum: Bool) {
        if momentum, !momentumScrollResponders.isEmpty {
            _ = momentumScrollResponders[0].scroll(with: event)
        } else {
            momentumScrollResponders = responder(with: indicatedLayer(with: event)) {
                $0[0].scroll(with: event)
            }
        }
        setIndicatedResponders(at: event.location)
        cursor = indicatedResponders[0].cursor
    }
    func sendPinch(with event: PinchEvent) {
        _ = responder(with: indicatedLayer(with: event)) { $0[0].zoom(with: event) }
    }
    func sendRotate(with event: RotateEvent) {
        _ = responder(with: indicatedLayer(with: event)) { $0[0].rotate(with: event) }
    }
    
    func sendTap(with event: TapEvent) {
        guard let action = actionManager.actionWith(.tap, event) else {
            return
        }
        _ = responder(with: indicatedLayer(with: event)) { action.tap?($0, event) ?? false }
        setIndicatedResponders(at: event.location)
    }
    
    private let defaultDoubleTapAction = Action(quasimode: Quasimode(gesture: .doubleTap),
                                                doubleTap: { $0[0].resetView(with: $1) })
    func sendDoubleTap(with event: DoubleTapEvent) {
        let action = actionManager.actionWith(.doubleTap, event) ?? defaultDoubleTapAction
        _ = responder(with: indicatedLayer(with: event)) { action.doubleTap?($0, event) ?? false }
        setIndicatedResponders(at: event.location)
    }
}
