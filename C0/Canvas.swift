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

struct Canvas: Codable {
    var frame: Rect
    var transform: Transform {
        didSet {
            reciprocalScale = 1 / transform.scale.x
        }
    }
    var scale: Real { return transform.scale.x }
    private(set) var reciprocalScale: Real
    var currentReciprocalScale: Real {
        return reciprocalScale / editingCellGroup.worldScale(at: editingCellGroupTreeIndex)
    }
    
    var rootCellGroup: CellGroup
    var editingCellGroupTreeIndex: TreeIndex<CellGroup> {
        didSet {
            editingWorldAffieTransform
                = rootCellGroup.worldAffineTransform(at: editingCellGroupTreeIndex)
        }
    }
    var editingCellGroup: CellGroup {
        get { return rootCellGroup[editingCellGroupTreeIndex] }
        set { rootCellGroup[editingCellGroupTreeIndex] = newValue }
    }
    private(set) var editingWorldAffieTransform: AffineTransform
    
    init(frame: Rect = Rect(x: -288, y: -162, width: 576, height: 324),
         transform: Transform = Transform(), rootCellGroup: CellGroup = CellGroup(),
         editingCellGroupTreeIndex: TreeIndex<CellGroup> = TreeIndex()) {
        
        self.frame = frame
        self.transform = transform
        self.rootCellGroup = rootCellGroup
        self.editingCellGroupTreeIndex = editingCellGroupTreeIndex
        reciprocalScale = 1 / transform.scale.x
        editingWorldAffieTransform
            = rootCellGroup.worldAffineTransform(at: editingCellGroupTreeIndex)
    }
}
extension Canvas {
    func view() -> View {
        return View()
    }
    //view
//    func draw(in ctx: CGContext) {
//        ctx.saveGState()
//        ctx.concatenate(transform.affineTransform)
//        rootCellGroup.draw
//        ctx.restoreGState()
//    }
}
extension Canvas: Referenceable {
    static let name = Text(english: "Canvas", japanese: "キャンバス")
}
extension Canvas: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect) -> View {
        return View(frame: frame)
    }
}
extension Canvas: AbstractViewable {
    func abstractViewWith<T : BinderProtocol>(binder: T,
                                              keyPath: ReferenceWritableKeyPath<T, Canvas>,
                                              type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return CanvasView(binder: binder, keyPath: keyPath)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath)
        }
    }
}
extension Canvas: ObjectViewable {}

/**
 Issue: Z移動を廃止してセルツリー表示を作成、セルクリップや全てのロック解除などを廃止
 Issue: スクロール後の元の位置までの距離を表示
 */
final class CanvasView<T: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = Canvas
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((CanvasView<Binder>, BasicNotification) -> ())]()
    
    var defaultModel = Model()
    
    init(binder: T, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        super.init(isLocked: false)
        children = [model.view()]
//        super.init(drawClosure: { _, _, _ in }, isLocked: false)
//        drawClosure = { [unowned self] in self.model.draw(in: $0) }
    }
    
    var screenTransform = AffineTransform.identity
    
    var minSize: Size {
        return Size(square: Layouter.defaultMinWidth)
    }
    override func updateLayout() {
        updateScreenTransform()
    }
    private func updateScreenTransform() {
//        screenTransform = AffineTransform(translation: bounds.centerPoint)
    }
    
    func updateEditPoint(with point: Point) {
        
    }
    var screenToEditingCellGroupTransform: AffineTransform {
        var affine = AffineTransform.identity
        affine *= model.editingWorldAffieTransform
        affine *= model.transform.affineTransform
        affine *= screenTransform
        return affine
    }
    func convertToCurrentLocal(_ r: Rect) -> Rect {
        let transform = screenToEditingCellGroupTransform
        return transform.isIdentity ? r : r * transform.inverted()
    }
    func convertFromCurrentLocal(_ r: Rect) -> Rect {
        let transform = screenToEditingCellGroupTransform
        return transform.isIdentity ? r : r * transform
    }
    func convertToCurrentLocal(_ p: Point) -> Point {
        let transform = screenToEditingCellGroupTransform
        return transform.isIdentity ? p : p * transform.inverted()
    }
    func convertFromCurrentLocal(_ p: Point) -> Point {
        let transform = screenToEditingCellGroupTransform
        return transform.isIdentity ? p : p * transform
    }
    func displayLinkDraw(inCurrentLocalBounds rect: Rect) {
        displayLinkDraw(convertFromCurrentLocal(rect))
    }
    
    var viewTransform: Transform {
        get { return model.transform }
        set { model.transform = newValue }
    }
    var viewScale: Real { return model.scale }
    
    func resetView(for p: Point) {
        guard !viewTransform.isIdentity else { return }
        viewTransform = Transform()
    }
}
extension CanvasView: Newable {
    func new(for p: Point, _ version: Version) {
        let editingCellGroup = model.editingCellGroup
        let geometry = Geometry(lines: editingCellGroup.drawing.editLines, scale: model.scale)
        guard !geometry.isEmpty else { return }
        let isDrawingSelectedLines = !editingCellGroup.drawing.selectedLineIndexes.isEmpty
        let unselectedLines = editingCellGroup.drawing.uneditLines
        //remove Lines
        //insertCell
    }
}
extension CanvasView: Strokable, ZoomableStrokable {
    func insertWillStorkeObject(at p: Point, to version: Version) {
        
    }
    
    func captureWillEraseObject(at p: Point, to version: Version) {
        
    }
    
    func makeViewStroker() -> ViewStroker {
        return BasicViewStroker(zoomableSstokableView: self)
    }
}
