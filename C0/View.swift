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

protocol Undoable {
    var undoManager: UndoManager? { get }
    var registeringUndoManager: UndoManager? { get }
    var disabledRegisterUndo: Bool { get }
    func undo() -> Bool
    func redo() -> Bool
}
extension Undoable {
    var undoManager: UndoManager? {
        return nil
    }
    var registeringUndoManager: UndoManager? {
        return disabledRegisterUndo ? nil : undoManager
    }
    var disabledRegisterUndo: Bool {
        return false
    }
    func undo() -> Bool {
        guard let undoManger = registeringUndoManager else {
            return false
        }
        if undoManger.canUndo {
            undoManger.undo()
            return true
        } else {
            return false
        }
    }
    func redo() -> Bool {
        guard let undoManger = registeringUndoManager else {
            return false
        }
        if undoManger.canRedo {
            undoManger.redo()
            return true
        } else {
            return false
        }
    }
}

protocol Editable {
    func copiedObjects(with event: KeyInputEvent) -> [ViewExpression]?
    var topCopiedObjects: [ViewExpression] { get }
    func sendToTop(copiedObjects: [ViewExpression])
    func paste(_ objects: [Any], with event: KeyInputEvent) -> Bool
    func delete(with event: KeyInputEvent) -> Bool
    func new(with event: KeyInputEvent) -> Bool
    func moveCursor(with event: MoveCursorEvent) -> Bool
    func keyInput(with event: KeyInputEvent) -> Bool
    func run(with event: ClickEvent) -> Bool
    func bind(with event: SubClickEvent) -> Bool
    func reference(with event: TapEvent) -> Reference?
    func sendToTop(_ reference: Reference)
}
extension Editable {
    func copiedObjects(with event: KeyInputEvent) -> [ViewExpression]? {
        return nil
    }
    func paste(_ objects: [Any], with event: KeyInputEvent) -> Bool {
        return false
    }
    func delete(with event: KeyInputEvent) -> Bool {
        return false
    }
    func new(with event: KeyInputEvent) -> Bool {
        return false
    }
    func moveCursor(with event: MoveCursorEvent) -> Bool {
        return false
    }
    func keyInput(with event: KeyInputEvent) -> Bool {
        return false
    }
    func run(with event: ClickEvent) -> Bool {
        return false
    }
    func bind(with event: SubClickEvent) -> Bool {
        return false
    }
    func reference(with event: TapEvent) -> Reference? {
        return nil
    }
}

protocol Selectable {
    func select(with event: DragEvent) -> Bool
    func deselect(with event: DragEvent) -> Bool
    func selectAll(with event: KeyInputEvent) -> Bool
    func deselectAll(with event: KeyInputEvent) -> Bool
}
extension Selectable {
    func select(with event: DragEvent) -> Bool {
        return false
    }
    func deselect(with event: DragEvent) -> Bool {
        return false
    }
    func selectAll(with event: KeyInputEvent) -> Bool {
        return false
    }
    func deselectAll(with event: KeyInputEvent) -> Bool {
        return false
    }
}

protocol Transformable {
    func move(with event: DragEvent) -> Bool
    func moveZ(with event: DragEvent) -> Bool
    func warp(with event: DragEvent) -> Bool
    func transform(with event: DragEvent) -> Bool
}
extension Transformable {
    func move(with event: DragEvent) -> Bool {
        return false
    }
    func moveZ(with event: DragEvent) -> Bool {
        return false
    }
    func warp(with event: DragEvent) -> Bool {
        return false
    }
    func transform(with event: DragEvent) -> Bool {
        return false
    }
}

protocol ViewEditable {
    func scroll(with event: ScrollEvent) -> Bool
    func zoom(with event: PinchEvent) -> Bool
    func rotate(with event: RotateEvent) -> Bool
    func resetView(with event: DoubleTapEvent) -> Bool
}
extension ViewEditable {
    func scroll(with event: ScrollEvent) -> Bool {
        return false
    }
    func zoom(with event: PinchEvent) -> Bool {
        return false
    }
    func rotate(with event: RotateEvent) -> Bool {
        return false
    }
    func resetView(with event: DoubleTapEvent) -> Bool {
        return false
    }
}

protocol Strokable {
    func stroke(with event: DragEvent) -> Bool
    func lassoErase(with event: DragEvent) -> Bool
}
extension Strokable {
    func stroke(with event: DragEvent) -> Bool {
        return false
    }
    func lassoErase(with event: DragEvent) -> Bool {
        return false
    }
}

protocol PointEditable {
    func insertPoint(with event: KeyInputEvent) -> Bool
    func removePoint(with event: KeyInputEvent) -> Bool
    func movePoint(with event: DragEvent) -> Bool
    func moveVertex(with event: DragEvent) -> Bool
}
extension PointEditable {
    func insertPoint(with event: KeyInputEvent) -> Bool {
        return false
    }
    func removePoint(with event: KeyInputEvent) -> Bool {
        return false
    }
    func movePoint(with event: DragEvent) -> Bool {
        return false
    }
    func moveVertex(with event: DragEvent) -> Bool {
        return false
    }
}

enum ViewQuasimode {
    case select, deselect, move, moveZ, transform, warp, movePoint, moveVertex, stroke, lassoErase
}

/**
 # Issue
 - コピー・ペーストなどのアクション対応を拡大
 - Eventを使用しないアクション設計
 */
protocol Respondable: class, Undoable, Editable, Selectable,
PointEditable, Transformable, ViewEditable, Strokable, Localizable {
    var cursor: Cursor { get }
    var cursorPoint: CGPoint { get }
    var isIndicated: Bool { get set }
    var isSubIndicated: Bool  { get set }
    static var defaultViewQuasimode: ViewQuasimode { get }
    var viewQuasimode: ViewQuasimode { get set }
}
extension Respondable {
    var cursor: Cursor {
        return .arrow
    }
    static var defaultViewQuasimode: ViewQuasimode {
        return .move
    }
}

protocol RootRespondable: Respondable {
    var rootCursorPoint: CGPoint { get set }
}

typealias View = Layer & Respondable
typealias PathView = PathLayer & Respondable
typealias DrawView = DrawLayer & Respondable
typealias RootView = Layer & RootRespondable

enum SizeType {
    case small, regular
}

protocol ViewExpression {
    func view(withBounds bounds: CGRect, sizeType: SizeType) -> View
}
protocol Thumbnailable {
    func thumbnail(withBounds bounds: CGRect, sizeType: SizeType) -> Layer
}
protocol ObjectViewExpression: ViewExpression, Thumbnailable, Referenceable, Copiable {
}
extension ObjectViewExpression {
    func view(withBounds bounds: CGRect, sizeType: SizeType) -> View {
        return ObjectView(object: self,
                          thumbnailView: thumbnail(withBounds: bounds, sizeType: sizeType),
                          minFrame: bounds, sizeType: sizeType)
    }
}
protocol ObjectViewExpressionWithDisplayText: ObjectViewExpression {
    var displayText: Localization { get }
}
extension ObjectViewExpressionWithDisplayText {
    func thumbnail(withBounds bounds: CGRect, sizeType: SizeType) -> Layer {
        return displayText.thumbnail(withBounds: bounds, sizeType: sizeType)
    }
}

final class ObjectView<T: Copiable & ViewExpression & Referenceable>: View {
    let object: T
    
    var sizeType: SizeType
    let classNameView: TextView, thumbnailView: Layer
    init(object: T, thumbnailView: Layer?, minFrame: CGRect, thumbnailWidth: CGFloat = 40.0,
         sizeType: SizeType = .regular) {
        self.object = object
        classNameView = TextView(text: type(of: object).name, font: Font.bold(with: sizeType))
        self.thumbnailView = thumbnailView ?? Layer()
        self.sizeType = sizeType
        
        super.init()
        let width = max(minFrame.width, classNameView.frame.width + thumbnailWidth)
        self.frame = CGRect(origin: minFrame.origin,
                            size: CGSize(width: width, height: minFrame.height))
        replace(children: [classNameView, self.thumbnailView])
        updateLayout()
    }
    
    override var locale: Locale {
        didSet {
            updateLayout()
        }
    }
    
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    func updateLayout() {
        let padding = Layout.padding(with: sizeType)
        classNameView.frame.origin = CGPoint(x: padding,
                                              y: bounds.height - classNameView.frame.height - padding)
        thumbnailView.frame = CGRect(x: classNameView.frame.maxX + padding,
                                     y: padding,
                                     width: bounds.width - classNameView.frame.width - padding * 3,
                                     height: bounds.height - padding * 2)
    }
    
    func copiedObjects(with event: KeyInputEvent) -> [ViewExpression]? {
        return  [object.copied]
    }
    
    func reference(with event: TapEvent) -> Reference? {
        return object.reference
    }
}

final class Drager {
    private var downPosition = CGPoint(), oldFrame = CGRect()
    func drag(with event: DragEvent, _ layer: Layer, in parent: Layer) {
        let p = parent.point(from: event)
        switch event.sendType {
        case .begin:
            downPosition = p
            oldFrame = layer.frame
        case .sending:
            let dp =  p - downPosition
            layer.frame.origin = CGPoint(x: oldFrame.origin.x + dp.x,
                                         y: oldFrame.origin.y + dp.y)
        case .end:
            let dp =  p - downPosition
            layer.frame.origin = CGPoint(x: round(oldFrame.origin.x + dp.x),
                                         y: round(oldFrame.origin.y + dp.y))
        }
    }
}
final class Scroller {
    func scroll(with event: ScrollEvent, layer: Layer) {
        layer.frame.origin += event.scrollDeltaPoint
    }
}
