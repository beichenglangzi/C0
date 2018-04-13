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
        indicatedResponder = rootView
    }
    
    var setEditTextView: (((sender: Sender, textView: TextView?, oldValue: TextView?)) -> ())?
    var indicatedResponder: Respondable {
        didSet {
            guard indicatedResponder !== oldValue else {
                return
            }
            var allParents = [Layer]()
            if let indicatedLayer = indicatedResponder as? Layer {
                indicatedLayer.allSubIndicatedParentsAndSelf { allParents.append($0) }
            }
            if let oldIndicatedLayer = oldValue as? Layer {
                oldIndicatedLayer.allSubIndicatedParentsAndSelf { responder in
                    if let index = allParents.index(where: { $0 === responder }) {
                        allParents.remove(at: index)
                    } else {
                        responder.isSubIndicated = false
                    }
                }
            }
            allParents.forEach { $0.isSubIndicated = true }
            oldValue.isIndicated = false
            indicatedResponder.isIndicated = true
            if indicatedResponder is TextView || oldValue is TextView {
                if let editTextView = oldValue as? TextView {
                    editTextView.unmarkText()
                }
                setEditTextView?((self, indicatedResponder as? TextView, oldValue as? TextView))
            }
        }
    }
    func setIndicatedResponder(at p: CGPoint) {
        let hitResponder = responder(with: indicatedLayer(at: p))
        if indicatedResponder !== hitResponder {
            indicatedResponder = hitResponder
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
    func responder(with beginLayer: Layer,
                   closure: (Respondable) -> (Bool) = { _ in true }) -> Respondable {
        var responder: Respondable?
        beginLayer.allParentsAndSelf { (layer, stop) in
            if let r = layer as? Respondable, closure(r) {
                responder = r
                stop = true
            }
        }
        return responder ?? rootView
    }
    
    var editTextView: TextView? {
        if let editTextView = indicatedResponder as? TextView {
            return editTextView.isLocked ? nil : editTextView
        } else {
            return nil
        }
    }
    
    private let defaultMoveCursorAction = Action(quasimode: Quasimode(gesture: .moveCursor),
                                                 moveCursor: { $0.moveCursor(with: $1) })
    func sendMoveCursor(with event: MoveCursorEvent) {
        rootView.rootCursorPoint = event.location
        let indicatedLayer = self.indicatedLayer(with: event)
        let indicatedResponder = responder(with: indicatedLayer)
        if indicatedResponder !== self.indicatedResponder {
            self.indicatedResponder = indicatedResponder
            cursor = indicatedResponder.cursor
        }
        _ = responder(with: indicatedLayer) { $0.moveCursor(with: event) }
    }
    
    var setCursorClosure: (((sender: Sender, cursor: Cursor, oldCursor: Cursor)) -> ())?
    var cursor = Cursor.arrow {
        didSet {
            setCursorClosure?((self, cursor, oldValue))
        }
    }
    
    private var oldViewQuasimodeAction = Action()
    private weak var oldViewQuasimodeResponder: Respondable?
    func sendViewQuasimode(with event: Event) {
        let viewQuasimodeAction = actionManager.actionWith(.drag, event) ?? Action()
        if dragAction == nil {
            if rootView.viewQuasimode != viewQuasimodeAction.viewQuasimode {
                rootView.viewQuasimode = viewQuasimodeAction.viewQuasimode
                cursor = indicatedResponder.cursor
            }
        }
        oldViewQuasimodeAction = viewQuasimodeAction
        oldViewQuasimodeResponder = indicatedResponder
    }
    
    private var isKey = false, keyAction = Action(), keyEvent: KeyInputEvent?
    private weak var keyTextView: TextView?
    func sendKeyInputIsEditText(with event: KeyInputEvent) -> Bool {
        switch event.sendType {
        case .begin:
            setIndicatedResponder(at: event.location)
            guard dragAction == nil else {
                keyEvent = event
                return false
            }
            isKey = true
            keyAction = actionManager.actionWith(.keyInput, event)
                ?? Action(quasimode: Quasimode([], event.key))
            if let editTextView = editTextView, keyAction.quasimode.canTextKeyInput() {
                self.keyTextView = editTextView
                _ = keyAction.keyInput?(editTextView, event)
                return true
            } else if keyAction != Action() {
                _ = responder(with: indicatedLayer(with: event)) {
                    keyAction.keyInput?($0, event) ?? false
                }
            }
            let indicatedResponder = responder(with: indicatedLayer(with: event))
            if self.indicatedResponder !== indicatedResponder {
                self.indicatedResponder = indicatedResponder
                cursor = indicatedResponder.cursor
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
                                            click: { $0.run(with: $1) })
    private let defaultDragAction = Action(quasimode: Quasimode(gesture: .drag),
                                           drag: { $0.move(with: $1) })
    private var dragAction: Action?, firstDragEvent: DragEvent?
    private weak var dragResponder: Respondable?
    func sendDrag(with event: DragEvent) {
        switch event.sendType {
        case .begin:
            setIndicatedResponder(at: event.location)
            firstDragEvent = event
            dragAction = actionManager.actionWith(.drag, event) ?? defaultDragAction
            dragResponder = nil
        case .sending:
            guard let dragAction = dragAction else {
                return
            }
            if let dragResponder = dragResponder {
                _ = dragAction.drag?(dragResponder, event)
            } else if let firstDragEvent = firstDragEvent {
                let dragResponder = responder(with: indicatedLayer(with: firstDragEvent)) {
                    dragAction.drag?($0, firstDragEvent) ?? false
                }
                self.firstDragEvent = nil
                self.dragResponder = dragResponder
                _ = dragAction.drag?(dragResponder, event)
            }
        case .end:
            guard let dragAction = dragAction else {
                return
            }
            if let dragResponder = dragResponder {
                _ = dragAction.drag?(dragResponder, event)
            } else {
                self.firstDragEvent = nil
                let clickAction = actionManager.actionWith(.click, event) ?? defaultClickAction
                _ = responder(with: indicatedLayer(with: event)) {
                    clickAction.click?($0, event) ?? false
                }
            }
            endAction(with: event, editAction: dragAction, editResponder: dragResponder)
            self.dragResponder = nil
            self.dragAction = nil
        }
    }
    
    private var subDragAction: Action?, firstSubDragEvent: DragEvent?
    private weak var subDragResponder: Respondable?
    func sendSubDrag(with event: SubDragEvent) {
        switch event.sendType {
        case .begin:
            setIndicatedResponder(at: event.location)
            firstSubDragEvent = event
            subDragAction = actionManager.actionWith(.subDrag, event)
            subDragResponder = nil
        case .sending:
            guard let subDragAction = subDragAction else {
                return
            }
            if let subDragResponder = subDragResponder {
                _ = subDragAction.drag?(subDragResponder, event)
            } else if let firstSubDragEvent = firstSubDragEvent {
                let subDragResponder = responder(with: indicatedLayer(with: firstSubDragEvent)) {
                    subDragAction.drag?($0, firstSubDragEvent) ?? false
                }
                self.firstDragEvent = nil
                self.subDragResponder = subDragResponder
                _ = subDragAction.drag?(subDragResponder, event)
            }
        case .end:
            guard let subDragAction = subDragAction else {
                return
            }
            if let subDragResponder = subDragResponder {
                _ = subDragAction.drag?(subDragResponder, event)
            } else {
                self.firstSubDragEvent = nil
                if let subClickAction = actionManager.actionWith(.subClick, event) {
                    _ = responder(with: indicatedLayer(with: event)) {
                        subClickAction.click?($0, event) ?? false
                    }
                }
            }
            endAction(with: event, editAction: subDragAction, editResponder: subDragResponder)
            self.subDragResponder = nil
            self.subDragAction = nil
        }
    }
    
    func endAction(with event: Event, editAction: Action, editResponder: Respondable?) {
        if let keyEvent = keyEvent {
            _ = sendKeyInputIsEditText(with: keyEvent.with(sendType: .begin))
            self.keyEvent = nil
        } else {
            let indicatedResponder = responder(with: indicatedLayer(with: event))
            if self.indicatedResponder !== indicatedResponder {
                self.indicatedResponder = indicatedResponder
                cursor = indicatedResponder.cursor
            }
        }
        if editAction != oldViewQuasimodeAction {
            if let editResponder = editResponder {
                if indicatedResponder !== editResponder {
                    editResponder.viewQuasimode = type(of: editResponder).defaultViewQuasimode
                }
            }
            rootView.viewQuasimode = oldViewQuasimodeAction.viewQuasimode
            indicatedResponder.viewQuasimode = oldViewQuasimodeAction.viewQuasimode
        }
    }
    
    private weak var momentumScrollResponder: Respondable?
    func sendScroll(with event: ScrollEvent, momentum: Bool) {
        if momentum, let momentumScrollResponder = momentumScrollResponder {
            _ = momentumScrollResponder.scroll(with: event)
        } else {
            momentumScrollResponder = responder(with: indicatedLayer(with: event)) {
                $0.scroll(with: event)
            }
        }
        setIndicatedResponder(at: event.location)
        cursor = indicatedResponder.cursor
    }
    func sendPinch(with event: PinchEvent) {
        _ = responder(with: indicatedLayer(with: event)) { $0.zoom(with: event) }
    }
    func sendRotate(with event: RotateEvent) {
        _ = responder(with: indicatedLayer(with: event)) { $0.rotate(with: event) }
    }
    
    func sendTap(with event: TapEvent) {
        guard let action = actionManager.actionWith(.tap, event) else {
            return
        }
        _ = responder(with: indicatedLayer(with: event)) { action.tap?($0, event) ?? false }
        setIndicatedResponder(at: event.location)
    }
    
    private let defaultDoubleTapAction = Action(quasimode: Quasimode(gesture: .doubleTap),
                                                doubleTap: { $0.resetView(with: $1) })
    func sendDoubleTap(with event: DoubleTapEvent) {
        let action = actionManager.actionWith(.doubleTap, event) ?? defaultDoubleTapAction
        _ = responder(with: indicatedLayer(with: event)) { action.doubleTap?($0, event) ?? false }
        setIndicatedResponder(at: event.location)
    }
}
