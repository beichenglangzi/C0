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
    func sendMoveCursor(with event: MoveEvent)
    func sendViewQuasimode(with event: Event)
    func sendKeyInputIsEditText(with event: KeyInputEvent) -> Bool
    func sendRightDrag(with event: DragEvent)
    func sendDrag(with event: DragEvent)
    func sendScroll(with event: ScrollEvent, momentum: Bool)
    func sendZoom(with event: PinchEvent)
    func sendRotate(with event: RotateEvent)
    func sendLookup(with event: TapEvent)
    func sendResetView(with event: DoubleTapEvent)
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
                   handler: (Respondable) -> (Bool) = { _ in true }) -> Respondable {
        var responder: Respondable?
        beginLayer.allParentsAndSelf { (layer, stop) in
            if let r = layer as? Respondable, handler(r) {
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
    
    func sendMoveCursor(with event: MoveEvent) {
        rootView.rootCursorPoint = event.location
        let indicatedLayer = self.indicatedLayer(with: event)
        let indicatedResponder = responder(with: indicatedLayer)
        if indicatedResponder !== self.indicatedResponder {
            self.indicatedResponder = indicatedResponder
            cursor = indicatedResponder.cursor
        }
        _ = responder(with: indicatedLayer) { $0.moveCursor(with: event) }
    }
    
    var setCursorHandler: (((sender: Sender, cursor: Cursor, oldCursor: Cursor)) -> ())?
    var cursor = Cursor.arrow {
        didSet {
            setCursorHandler?((self, cursor, oldValue))
        }
    }
    
    private var oldQuasimodeAction = Action()
    private weak var oldQuasimodeResponder: Respondable?
    func sendViewQuasimode(with event: Event) {
        let quasimodeAction = actionManager.actionWith(.drag, event) ?? Action()
        if !isDown {
            if rootView.viewQuasimode != quasimodeAction.viewQuasimode {
                rootView.viewQuasimode = quasimodeAction.viewQuasimode
                cursor = indicatedResponder.cursor
            }
        }
        oldQuasimodeAction = quasimodeAction
        oldQuasimodeResponder = indicatedResponder
    }
    
    private var isKey = false, keyAction = Action(), keyEvent: KeyInputEvent?
    private weak var keyTextView: TextView?
    func sendKeyInputIsEditText(with event: KeyInputEvent) -> Bool {
        switch event.sendType {
        case .begin:
            setIndicatedResponder(at: event.location)
            guard !isDown else {
                keyEvent = event
                return false
            }
            isKey = true
            keyAction = actionManager.actionWith(.keyInput, event)
                ?? Action(key: event.key)
            if let editTextView = editTextView, keyAction.canTextKeyInput() {
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
    
    func sendRightDrag(with event: DragEvent) {
        if event.sendType == .end {
            _ = responder(with: indicatedLayer(with: event)) { $0.bind(with: event) }
        }
    }
    
    private let defaultClickAction = Action(gesture: .click)
    private let defaultDragAction = Action(drag: { $0.move(with: $1) })
    private var isDown = false, isDrag = false, dragAction = Action()
    private weak var dragResponder: Respondable?
    func sendDrag(with event: DragEvent) {
        switch event.sendType {
        case .begin:
            setIndicatedResponder(at: event.location)
            isDown = true
            isDrag = false
            dragAction = actionManager.actionWith(.drag, event) ?? defaultDragAction
            dragResponder = responder(with: indicatedLayer(with: event)) {
                dragAction.drag?($0, event) ?? false
            }
        case .sending:
            isDrag = true
            if isDown, let dragResponder = dragResponder {
                _ = dragAction.drag?(dragResponder, event)
            }
        case .end:
            if isDown {
                if let dragResponder = dragResponder {
                    _ = dragAction.drag?(dragResponder, event)
                }
                if !isDrag {
                    _ = responder(with: indicatedLayer(with: event)) { $0.run(with: event) }
                }
                isDown = false
                
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
                isDrag = false
                
                if dragAction != oldQuasimodeAction {
                    if let dragResponder = dragResponder {
                        if indicatedResponder !== dragResponder {
                            dragResponder.viewQuasimode = .move
                        }
                    }
                    rootView.viewQuasimode = oldQuasimodeAction.viewQuasimode
                    indicatedResponder.viewQuasimode = oldQuasimodeAction.viewQuasimode
                }
            }
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
    func sendZoom(with event: PinchEvent) {
        _ = responder(with: indicatedLayer(with: event)) { $0.zoom(with: event) }
    }
    func sendRotate(with event: RotateEvent) {
        _ = responder(with: indicatedLayer(with: event)) { $0.rotate(with: event) }
    }
    
    func sendLookup(with event: TapEvent) {
        let p = event.location.integral
        let responder = self.responder(with: indicatedLayer(with: event))
        let referenceView = ReferenceView(reference: responder.lookUp(with: event))
        let panel = Panel(isUseHedding: true)
        panel.contents = [referenceView]
        panel.openPoint = p.integral
        panel.openViewPoint = rootView.point(from: event)
        panel.subIndicatedParent = rootView
    }
    
    func sendResetView(with event: DoubleTapEvent) {
        _ = responder(with: indicatedLayer(with: event)) { $0.resetView(with: event) }
        setIndicatedResponder(at: event.location)
    }
}
