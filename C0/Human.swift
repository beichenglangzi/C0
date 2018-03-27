/*
 Copyright 2017 S
 
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

/**
 # Issue
 - sceneViewを取り除く
 */
final class Human: Layer, Respondable, Localizable {
    static let name = Localization(english: "Human", japanese: "ヒューマン")
    
    var locale = Locale.current {
        didSet {
            if locale.languageCode != oldValue.languageCode {
                vision.allChildrenAndSelf { ($0 as? Localizable)?.locale = locale }
            }
        }
    }
    
    static let effectiveFieldOfView = tan(.pi * (30.0 / 2.0) / 180.0) / tan(.pi * (20.0 / 2.0) / 180.0)
    static let basicEffectiveFieldOfView = Q(152, 100)
    
    struct Preference: Codable {
        var isHiddenAction = false
    }
    var preference = Preference() {
        didSet {
            actionManagerView.isHiddenView.selectedIndex = preference.isHiddenAction ? 0 : 1
            actionManagerView.isHiddenActions = preference.isHiddenAction
            updateLayout()
        }
    }
    
    var worldDataModel: DataModel
    var preferenceDataModel = DataModel(key: preferenceDataModelKey)
    static let dataModelKey = "human"
    static let worldDataModelKey = "world", preferenceDataModelKey = "preference"
    override var dataModel: DataModel? {
        didSet {
            if let worldDataModel = dataModel?.children[Human.worldDataModelKey] {
                self.worldDataModel = worldDataModel
            }
            if let preferenceDataModel = dataModel?.children[Human.preferenceDataModelKey] {
                self.preferenceDataModel = preferenceDataModel
                if let preference: Preference = preferenceDataModel.readObject() {
                    self.preference = preference
                }
                preferenceDataModel.dataHandler = { [unowned self] in
                    return self.preference.jsonData
                }
            }
            if let sceneViewDataModel = worldDataModel.children[SceneView.sceneViewKey] {
                sceneView.dataModel = sceneViewDataModel
            } else if let sceneViewDataModel = sceneView.dataModel {
                worldDataModel.insert(sceneViewDataModel)
            }
        }
    }
    
    let vision = Vision()
    let copiedObjectView = CopiedObjectView(), actionManagerView = ActionManagerView()
    let world = Box()
    var editTextView: TextView? {
        if let editTextView = indicatedResponder as? TextView {
            return editTextView.isLocked ? nil : editTextView
        } else {
            return nil
        }
    }
    let sceneView = SceneView()
    
    var actionWidth = ActionManagerView.defaultWidth {
        didSet {
            updateLayout()
        }
    }
    var copyViewHeight = Layout.basicHeight + Layout.basicPadding * 2 {
        didSet {
            updateLayout()
        }
    }
    var fieldOfVision = CGSize() {
        didSet {
            vision.frame.size = fieldOfVision
            updateLayout()
        }
    }
    
    override init() {
        if let sceneViewDataModel = sceneView.dataModel {
            worldDataModel = DataModel(key: Human.worldDataModelKey,
                                       directoryWithDataModels: [sceneViewDataModel])
        } else {
            worldDataModel = DataModel(key: Human.worldDataModelKey, directoryWithDataModels: [])
        }
        world.isClipped = true
        world.replace(children: [sceneView])
        vision.replace(children: [copiedObjectView, actionManagerView, world])
        indicatedResponder = vision
        
        super.init()
        dataModel = DataModel(key: Human.dataModelKey,
                              directoryWithDataModels: [preferenceDataModel, worldDataModel])
        editQuasimode = EditQuasimode.move
        
        actionManagerView.isHiddenActionBinding = { [unowned self] in
            self.preference.isHiddenAction = $0
            self.updateLayout()
            self.preferenceDataModel.isWrite = true
        }
        preferenceDataModel.dataHandler = { [unowned self] in return self.preference.jsonData }
    }
    
    private func updateLayout() {
        let padding = Layout.basicPadding
        let preferenceY = fieldOfVision.height - actionManagerView.frame.height - padding
        actionManagerView.frame = CGRect(x: padding,
                                         y: preferenceY,
                                         width: actionWidth,
                                         height: actionManagerView.frame.height)
        copiedObjectView.frame = CGRect(x: padding + actionWidth,
                                        y: fieldOfVision.height - copyViewHeight - padding,
                                        width: fieldOfVision.width - actionWidth - padding * 2,
                                        height: copyViewHeight)
        if preference.isHiddenAction {
            world.frame = CGRect(x: padding,
                                 y: padding,
                                 width: vision.frame.width - padding * 2,
                                 height: vision.frame.height - copyViewHeight - padding * 2)
        } else {
            world.frame = CGRect(x: padding + actionWidth,
                                 y: padding,
                                 width: vision.frame.width - (padding * 2 + actionWidth),
                                 height: vision.frame.height - copyViewHeight - padding * 2)
        }
        world.bounds.origin = CGPoint(x: -round((world.frame.width / 2)),
                                      y: -round((world.frame.height / 2)))
        sceneView.frame.origin = CGPoint(x: -round(sceneView.frame.width / 2),
                                         y: -round(sceneView.frame.height / 2))
    }
    override var contentsScale: CGFloat {
        didSet {
            if contentsScale != oldValue {
                vision.allChildrenAndSelf { $0.contentsScale = contentsScale }
            }
        }
    }
    
    override var editQuasimode: EditQuasimode {
        didSet {
            vision.editQuasimode = editQuasimode
        }
    }
    
    var setEditTextView: (((human: Human, textView: TextView?, oldValue: TextView?)) -> ())?
    var indicatedResponder: Respondable {
        didSet {
            if indicatedResponder !== oldValue {
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
                    setEditTextView?((self,
                                      indicatedResponder as? TextView,
                                      oldValue as? TextView))
                }
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
        return (vision.at(event.location) as? Respondable) ?? vision
    }
    func indicatedLayer(with event: Event) -> Layer {
        return vision.at(event.location) ?? vision
    }
    func indicatedLayer(at p: CGPoint) -> Layer {
        return vision.at(p) ?? vision
    }
    func responder(with beginLayer: Layer,
                   handler: (Respondable) -> (Bool) = { _ in true }) -> Respondable {
        var responder: Respondable?
        beginLayer.allParentsAndSelf { (layer, stop) in
            if let r = layer as? Respondable {
                if handler(r) {
                    responder = r
                    stop = true
                }
            }
        }
        return responder ?? vision
    }
    
    func sendMoveCursor(with event: MoveEvent) {
        vision.rootCursorPoint = event.location
        let indicatedLayer = self.indicatedLayer(with: event)
        let indicatedResponder = responder(with: indicatedLayer)
        if indicatedResponder !== self.indicatedResponder {
            self.indicatedResponder = indicatedResponder
            cursor = indicatedResponder.cursor
        }
        _ = responder(with: indicatedLayer) { $0.moveCursor(with: event) }
    }
    
    var setCursorHandler: (((human: Human, cursor: Cursor, oldCursor: Cursor)) -> ())?
    var cursor = Cursor.arrow {
        didSet {
            setCursorHandler?((self, cursor, oldValue))
        }
    }
    
    private var oldQuasimodeAction = Action()
    private weak var oldQuasimodeResponder: Respondable?
    func sendEditQuasimode(with event: Event) {
        let quasimodeAction = actionManagerView.actionManager.actionWith(.drag, event) ?? Action()
        if !isDown {
            if editQuasimode != quasimodeAction.editQuasimode {
                editQuasimode = quasimodeAction.editQuasimode
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
            keyAction = actionManagerView.actionManager.actionWith(.keyInput, event) ?? Action()
            if let editTextView = editTextView, keyAction.canTextKeyInput() {
                self.keyTextView = editTextView
                _ = keyAction.keyInput?(self, editTextView, event)
                return true
            } else if keyAction != Action() {
                _ = responder(with: indicatedLayer(with: event)) {
                    keyAction.keyInput?(self, $0, event) ?? false
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
    private let defaultDragAction = Action(drag: { $1.move(with: $2) })
    private var isDown = false, isDrag = false, dragAction = Action()
    private weak var dragResponder: Respondable?
    func sendDrag(with event: DragEvent) {
        switch event.sendType {
        case .begin:
            setIndicatedResponder(at: event.location)
            isDown = true
            isDrag = false
            dragAction = actionManagerView.actionManager.actionWith(.drag, event) ?? defaultDragAction
            dragResponder = responder(with: indicatedLayer(with: event)) {
                dragAction.drag?(self, $0, event) ?? false
            }
        case .sending:
            isDrag = true
            if isDown, let dragResponder = dragResponder {
                _ = dragAction.drag?(self, dragResponder, event)
            }
        case .end:
            if isDown {
                if let dragResponder = dragResponder {
                    _ = dragAction.drag?(self, dragResponder, event)
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
                            dragResponder.editQuasimode = .move
                        }
                    }
                    editQuasimode = oldQuasimodeAction.editQuasimode
                    indicatedResponder.editQuasimode = oldQuasimodeAction.editQuasimode
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
        panel.openViewPoint = point(from: event)
        panel.subIndicatedParent = vision
    }
    
    func sendResetView(with event: DoubleTapEvent) {
        _ = responder(with: indicatedLayer(with: event)) { $0.resetView(with: event) }
        setIndicatedResponder(at: event.location)
    }
    
    func copy(with event: KeyInputEvent) -> CopiedObject? {
        return copiedObjectView.copiedObject
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) -> Bool {
        return copiedObjectView.paste(copiedObject, with: event)
    }
}

final class Vision: Layer, Respondable {
    static let name = Localization(english: "Vision", japanese: "ビジョン")
    var rootCursorPoint = CGPoint()
    override var cursorPoint: CGPoint {
        return rootCursorPoint
    }
    override init() {
        super.init()
        fillColor = .background
    }
}
