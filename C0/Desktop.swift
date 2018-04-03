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

struct Desktop {
    var actionManager = ActionManager()
    var objects = [Any]()
    private enum CodingKeys: String, CodingKey {
        case isHiddenActions
    }
}
extension Desktop: Codable {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        actionManager.isHiddenActions = try values.decode(Bool.self, forKey: .isHiddenActions)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(actionManager.isHiddenActions, forKey: .isHiddenActions)
    }
}
extension Desktop: Referenceable {
    static let name = Localization(english: "Desktop", japanese: "デスクトップ")
}

/**
 # Issue
 - sceneViewを取り除く
 */
final class DesktopView: Layer, Respondable {
    static let name = Desktop.name
    
    var desktop = Desktop() {
        didSet {
            actionManagerView.actionManager = desktop.actionManager
            updateLayout()
        }
    }
    
    static let dataModelKey = "desktop"
    var dataModel: DataModel {
        didSet {
            if let objectsDataModel = dataModel.children[DesktopView.objectsDataModelKey] {
                self.objectsDataModel = objectsDataModel
            }
            if let dDesktopDataModel
                = dataModel.children[DesktopView.differentialDesktopDataModelKey] {
                
                self.differentialDesktopDataModel = dDesktopDataModel
                if let desktop: Desktop = dDesktopDataModel.readObject() {
                    self.desktop = desktop
                }
                dDesktopDataModel.dataHandler = { [unowned self] in self.desktop.jsonData }
            }
            if let sceneDataModel = objectsDataModel.children[SceneView.dataModelKey] {
                sceneView.dataModel = sceneDataModel
            } else {
                objectsDataModel.insert(sceneView.dataModel)
            }
        }
    }
    static let differentialDesktopDataModelKey = "differentialDesktop"
    var differentialDesktopDataModel = DataModel(key: differentialDesktopDataModelKey)
    static let objectsDataModelKey = "objects"
    var objectsDataModel: DataModel
    
    let copyManagerView = CopyManagerView(), actionManagerView = ActionManagerView()
    let objectsView = Box()
    let sceneView = SceneView()
    
    var editTextView: TextView? {
        if let editTextView = indicatedResponder as? TextView {
            return editTextView.isLocked ? nil : editTextView
        } else {
            return nil
        }
    }
    
    override init() {
        objectsDataModel = DataModel(key: DesktopView.objectsDataModelKey,
                                     directoryWith: [sceneView.dataModel])
        dataModel = DataModel(key: DesktopView.dataModelKey,
                              directoryWith: [differentialDesktopDataModel, objectsDataModel])
        
        objectsView.isClipped = true
        indicatedResponder = objectsView
        
        super.init()
        fillColor = .background
        
        objectsView.replace(children: [sceneView])
        replace(children: [copyManagerView, actionManagerView, objectsView])
        indicatedResponder = self
        
        actionManagerView.isHiddenActionsBinding = { [unowned self] in
            self.desktop.actionManager.isHiddenActions = $0
            self.actionManagerView.actionManager.isHiddenActions = $0
            self.updateLayout()
            self.differentialDesktopDataModel.isWrite = true
        }
        differentialDesktopDataModel.dataHandler = { [unowned self] in self.desktop.jsonData }
    }
    
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
    
    var rootCursorPoint = CGPoint()
    override var cursorPoint: CGPoint {
        return rootCursorPoint
    }
    
    override var locale: Locale {
        didSet {
            if locale.languageCode != oldValue.languageCode {
                allChildrenAndSelf { $0.locale = locale }
            }
        }
    }
    
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    private func updateLayout() {
        let padding = Layout.basicPadding
        let preferenceY = bounds.height - actionManagerView.frame.height - padding
        actionManagerView.frame = CGRect(x: padding,
                                         y: preferenceY,
                                         width: actionWidth,
                                         height: actionManagerView.frame.height)
        copyManagerView.frame = CGRect(x: padding + actionWidth,
                                       y: bounds.height - copyViewHeight - padding,
                                       width: bounds.width - actionWidth - padding * 2,
                                       height: copyViewHeight)
        if actionManagerView.actionManager.isHiddenActions {
            objectsView.frame = CGRect(x: padding,
                                       y: padding,
                                       width: bounds.width - padding * 2,
                                       height: bounds.height - copyViewHeight - padding * 2)
        } else {
            objectsView.frame = CGRect(x: padding + actionWidth,
                                       y: padding,
                                       width: bounds.width - (padding * 2 + actionWidth),
                                       height: bounds.height - copyViewHeight - padding * 2)
        }
        objectsView.bounds.origin = CGPoint(x: -round((objectsView.frame.width / 2)),
                                            y: -round((objectsView.frame.height / 2)))
        sceneView.frame.origin = CGPoint(x: -round(sceneView.frame.width / 2),
                                         y: -round(sceneView.frame.height / 2))
    }
    
    override var contentsScale: CGFloat {
        didSet {
            if contentsScale != oldValue {
                allChildrenAndSelf { $0.contentsScale = contentsScale }
            }
        }
    }
    
    var setEditTextView: (((view: DesktopView, textView: TextView?, oldValue: TextView?)) -> ())?
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
        return (at(event.location) as? Respondable) ?? self
    }
    func indicatedLayer(with event: Event) -> Layer {
        return at(event.location) ?? self
    }
    func indicatedLayer(at p: CGPoint) -> Layer {
        return at(p) ?? self
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
        return responder ?? self
    }
    
    func sendMoveCursor(with event: MoveEvent) {
        rootCursorPoint = event.location
        let indicatedLayer = self.indicatedLayer(with: event)
        let indicatedResponder = responder(with: indicatedLayer)
        if indicatedResponder !== self.indicatedResponder {
            self.indicatedResponder = indicatedResponder
            cursor = indicatedResponder.cursor
        }
        _ = responder(with: indicatedLayer) { $0.moveCursor(with: event) }
    }
    
    var setCursorHandler: (((view: DesktopView, cursor: Cursor, oldCursor: Cursor)) -> ())?
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
        panel.subIndicatedParent = self
    }
    
    func sendResetView(with event: DoubleTapEvent) {
        _ = responder(with: indicatedLayer(with: event)) { $0.resetView(with: event) }
        setIndicatedResponder(at: event.location)
    }
    
    func copy(with event: KeyInputEvent) -> CopyManager? {
        return copyManagerView.copyManager
    }
    func paste(_ copyManager: CopyManager, with event: KeyInputEvent) -> Bool {
        return copyManagerView.paste(copyManager, with: event)
    }
}
