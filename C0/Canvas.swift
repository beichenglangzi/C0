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
    var scale: Real {
        return transform.scale.x
    }
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
extension Canvas: AbstractViewable {
    func abstractViewWith<T : BinderProtocol>(binder: T,
                                              keyPath: ReferenceWritableKeyPath<T, Canvas>,
                                              frame: Rect, _ sizeType: SizeType,
                                              type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return CanvasView(binder: binder, keyPath: keyPath, frame: frame, sizeType: sizeType)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath, frame: frame, sizeType)
        }
    }
}
extension Canvas: ObjectViewable {}

/**
 Issue: Z移動を廃止してセルツリー表示を作成、セルクリップや全てのロック解除などを廃止
 Issue: スクロール後の元の位置までの距離を表示
 */
final class CanvasView<T: BinderProtocol>: View, BindableReceiver {
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
    
    init(binder: T, keyPath: BinderKeyPath,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        super.init()
        children = [model.view()]
//        super.init(drawClosure: { _, _ in }, isLocked: false)
//        drawClosure = { [unowned self] in self.model.draw(in: $0) }
    }
    
    var screenTransform = AffineTransform.identity
    override func updateLayout() {
        updateScreenTransform()
    }
    private func updateScreenTransform() {
        screenTransform = AffineTransform(translation: bounds.midPoint)
    }
    func updateWithModel() {
        
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
        get {
            return model.transform
        }
        set {
            model.transform = newValue
        }
    }
    var viewScale: Real {
        return model.scale
    }
    
    func resetView(for p: Point) {
        guard !viewTransform.isIdentity else { return }
        viewTransform = Transform()
    }
}
extension CanvasView: Selectable {
    func captureSelections(to version: Version) {
        version.registerUndo(withTarget: self) {
            [oldSelectedCellIndexes = model.editingCellGroup.selectedCellIndexes, unowned version] in
            
            $0.pushSelectedCellIndexes(oldSelectedCellIndexes, to: version)
        }
    }
    func pushSelectedCellIndexes(_ selectedCellIndexes: [Cell.Index],
                                 to version: Version) {
        version.registerUndo(withTarget: self) {
            [oldSelectedCellIndexes = model.editingCellGroup.selectedCellIndexes, unowned version] in
            
            $0.pushSelectedCellIndexes(oldSelectedCellIndexes, to: version)
        }
        model.editingCellGroup.selectedCellIndexes = selectedCellIndexes
        updateLayout()
    }
    
    func makeViewSelector() -> ViewSelector {
        return CanvasViewSelector<Binder>(canvasView: self)
    }
    
    func selectAll() {
        model.editingCellGroup.selectedCellIndexes = []
    }
    func deselectAll() {
        model.editingCellGroup.selectedCellIndexes = model.editingCellGroup.rootCell.treeIndexEnumerated().map { (index, _) in index }
    }
}
final class CanvasViewSelector<Binder: BinderProtocol>: ViewSelector {
    var canvasView: CanvasView<Binder>
    var cellGroup: CellGroup?, cellGroupIndex = CellGroup.Index()
    var selectedLineIndexes = [Int]()
    var drawing: Drawing?
    
    init(canvasView: CanvasView<Binder>) {
        self.canvasView = canvasView
    }
    
    func select(from rect: Rect, _ phase: Phase) {
        select(from: rect, phase, isDeselect: false)
    }
    func deselect(from rect: Rect, _ phase: Phase) {
        select(from: rect, phase, isDeselect: true)
    }
    func select(from rect: Rect, _ phase: Phase, isDeselect: Bool) {
        func unionWithStrokeLine(with drawing: Drawing) -> [Array<Line>.Index] {
            let affine = canvasView.screenToEditingCellGroupTransform.inverted()
            let lines = [Line].rectangle(rect).map { $0 * affine }
            let geometry = Geometry(lines: lines)
            let lineIndexes = drawing.lines.enumerated().compactMap {
                geometry.intersects($1) ? $0 : nil
            }
            if isDeselect {
                return Array(Set(selectedLineIndexes).subtracting(Set(lineIndexes)))
            } else {
                return Array(Set(selectedLineIndexes).union(Set(lineIndexes)))
            }
        }
        
        switch phase {
        case .began:
            cellGroup = canvasView.model.editingCellGroup
            cellGroupIndex = canvasView.model.editingCellGroupTreeIndex
            drawing = canvasView.model.editingCellGroup.drawing
            selectedLineIndexes = canvasView.model.editingCellGroup.drawing.selectedLineIndexes
        case .changed, .ended:
            guard let drawing = drawing else { return }
//            drawing?.selectedLineIndexes = unionWithStrokeLine(with: drawing)
        }
    }
}
extension CanvasView: Assignable {
    func reset(for p: Point, _ version: Version) {
        push(defaultModel, to: version)
    }
    func copiedObjects(at p: Point) -> [Object] {
        return [Object(model)]
    }
    func paste(_ objects: [Any], for p: Point, _ version: Version) {
        for object in objects {
            if let model = object as? Model {
                push(model, to: version)
                return
            }
        }
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
extension CanvasView: Transformable {
    func captureWillMoveObject(at p: Point, to version: Version) {
        
    }
    
    func makeViewTransformer() -> ViewTransformer {
        return CanvasViewTransformer(canvasView: self)
    }
    
    func makeViewMover() -> ViewMover {
        return CanvasViewTransformer(canvasView: self)
    }
}
final class CanvasViewTransformer<Binder: BinderProtocol>: ViewTransformer, ViewMover {
    var transformableView: View & Transformable {
        return canvasView
    }
    var movableView: View & Movable {
        return canvasView
    }
    
    var canvasView: CanvasView<Binder>
    
    init(canvasView: CanvasView<Binder>) {
        self.canvasView = canvasView
    }
    
    var transformBounds = Rect.null, beginPoint = Point(), anchorPoint = Point()
    enum TransformEditType {
        case move, transform, warp
    }
    func move(for p: Point, first fp: Point, pressure: Real, time: Second, _ phase: Phase) {
        move(for: p, pressure: pressure, time: time, phase, type: .move)
    }
    func transform(for p: Point, first fp: Point, pressure: Real, time: Second, _ phase: Phase) {
        move(for: p, pressure: pressure, time: time, phase, type: .transform)
    }
    func warp(for p: Point, first fp: Point, pressure: Real, time: Second, _ phase: Phase) {
        move(for: p, pressure: pressure, time: time, phase, type: .warp)
    }
    let transformAngleTime = Second(0.1)
    var transformAngleOldTime = Second(0.0)
    var transformAnglePoint = Point(), transformAngleOldPoint = Point()
    var isTransformAngle = false
    var cellGroup: CellGroup?
    func move(for point: Point, pressure: Real, time: Second, _ phase: Phase,
              type: TransformEditType) {
        let p = canvasView.convertToCurrentLocal(point)
        
        func transformAffineTransformWith(point: Point, oldPoint: Point,
                                          anchorPoint: Point) -> AffineTransform {
            guard oldPoint != anchorPoint else {
                return AffineTransform.identity
            }
            let r = point.distance(anchorPoint), oldR = oldPoint.distance(anchorPoint)
            let angle = anchorPoint.tangential(point)
            let oldAngle = anchorPoint.tangential(oldPoint)
            let scale = r / oldR
            var affine = AffineTransform(translation: anchorPoint)
            affine.rotate(by: angle.differenceRotation(oldAngle))
            affine.scale(by: scale)
            affine.translate(by: -anchorPoint)
            return affine
        }
        func warpAffineTransformWith(point: Point, oldPoint: Point,
                                     anchorPoint: Point) -> AffineTransform {
            guard oldPoint != anchorPoint else {
                return AffineTransform.identity
            }
            let theta = oldPoint.tangential(anchorPoint)
            let angle = theta < 0 ? theta + .pi : theta - .pi
            var pAffine = AffineTransform(rotationAngle: -angle)
            pAffine.translate(by: -anchorPoint)
            let newOldP = oldPoint * pAffine, newP = point * pAffine
            let scaleX = newP.x / newOldP.x, skewY = (newP.y - newOldP.y) / newOldP.x
            var affine = AffineTransform(translation: anchorPoint)
            affine.rotate(by: angle)
            affine.scale(by: Point(x: scaleX, y: 1))
            if skewY != 0 {
                let skewAffine = AffineTransform(a: 1, b: skewY,
                                                 c: 0, d: 1,
                                                 tx: 0, ty: 0)
                affine = skewAffine * affine
            }
            affine.rotate(by: -angle)
            affine.translate(by: -anchorPoint)
            return affine
        }
        
        func affineTransform(with cellGroup: CellGroup) -> AffineTransform {
            switch type {
            case .move:
                return AffineTransform(translation: p - beginPoint)
            case .transform:
                return transformAffineTransformWith(point: p, oldPoint: beginPoint,
                                                    anchorPoint: anchorPoint)
            case .warp:
                return warpAffineTransformWith(point: p, oldPoint: beginPoint,
                                               anchorPoint: anchorPoint)
            }
        }
        switch phase {
        case .began:
            //selectedLines
            if type != .move {
                self.transformAngleOldTime = time
                self.transformAngleOldPoint = p
                self.isTransformAngle = false
            }
            cellGroup = canvasView.model.editingCellGroup
            beginPoint = p
        case .changed, .ended:
            guard let cellGroup = cellGroup else { return }
            let affine = affineTransform(with: cellGroup)
        }
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

extension CanvasView: VertexMovable {
    func captureWillMovePoint(at p: Point, to version: Version) {
        
    }
    
    func insert(_ point: Point) {
        let p = convertToCurrentLocal(point), inNode = model.editingCellGroup
        guard let nearest = inNode.nearestLineItem(at: p) else { return }
        
    }
    func removeNearestPoint(for point: Point) {
        let p = convertToCurrentLocal(point), inNode = model.editingCellGroup
        guard let nearest = inNode.nearestLineItem(at: p) else { return }
        if nearest.linePoint.line.controls.count > 2 {
            model.editingCellGroup.drawing.lines[nearest.linePoint.lineIndex]
                .controls.remove(at: nearest.linePoint.pointIndex)
        } else {
            model.editingCellGroup.drawing.lines.remove(at: nearest.linePoint.lineIndex)
        }
    }
    
    func makeViewPointMover() -> ViewPointMover {
        return CanvasViewPointMover(canvasView: self)
    }
    func makeViewVertexMover() -> ViewVertexMover {
        return CanvasViewPointMover(canvasView: self)
    }
}

final class CanvasViewPointMover<Binder: BinderProtocol>: ViewPointMover, ViewVertexMover {
    var canvasView: CanvasView<Binder>
    
    var pointMovableView: View & PointMovable {
        return canvasView
    }
    var vertexMovableView: View & VertexMovable {
        return canvasView
    }
    
    init(canvasView: CanvasView<Binder>) {
        self.canvasView = canvasView
    }
    
    private var nearest: CellGroup.Nearest?
    private var oldPoint = Point(), isSnap = false
    private var cellGroup: CellGroup?
    private let snapDistance = 8.0.cg
    
    func movePoint(for p: Point, first fp: Point, pressure: Real, time: Second, _ phase: Phase) {
        movePoint(for: p, first: fp, pressure: pressure, time: time, phase, isVertex: false)
    }
    func moveVertex(for p: Point, first fp: Point, pressure: Real, time: Second, _ phase: Phase) {
        movePoint(for: p, first: fp, pressure: pressure, time: time, phase, isVertex: true)
    }
    func movePoint(for point: Point, first fp: Point, pressure: Real,
                   time: Second, _ phase: Phase, isVertex: Bool) {
        let p = canvasView.convertToCurrentLocal(point)
        switch phase {
        case .began:
            let cellGroup = canvasView.model.editingCellGroup
            guard let nearest = cellGroup.nearest(at: p, isVertex: isVertex) else { return }
            self.nearest = nearest
            isSnap = false
            self.cellGroup = cellGroup
            oldPoint = p
        case .changed, .ended:
            guard let nearest = nearest else { return }
            let dp = p - oldPoint
            
            isSnap = isSnap ? true : pressure == 1//speed
            
            switch nearest.result {
            case .lineItem(let lineItem):
                movingPoint(with: lineItem, fp: nearest.point, dp: dp)
            case .lineCapResult(let lineCapResult):
                if isSnap {
                    movingPoint(with: lineCapResult,
                                fp: nearest.point, dp: dp, isVertex: isVertex)
                } else {
                    movingLineCap(with: lineCapResult,
                                  fp: nearest.point, dp: dp, isVertex: isVertex)
                }
            }
        }
    }
    private func movingPoint(with lineItem: CellGroup.LineItem, fp: Point, dp: Point) {
        let snapD = snapDistance / canvasView.model.scale
        let e = lineItem.linePoint
        switch lineItem.drawingOrCell {
        case .drawing(let drawing):
            var control = e.line.controls[e.pointIndex]
            control.point = e.line.mainPoint(withMainCenterPoint: fp + dp,
                                             at: e.pointIndex)
            if isSnap && (e.pointIndex == 1 || e.pointIndex == e.line.controls.count - 2) {
                let cellGroup = canvasView.model.editingCellGroup
                control.point = cellGroup.snappedPoint(control.point,
                                                       editLine: drawing.lines[e.lineIndex],
                                                       editingMaxPointIndex: e.pointIndex,
                                                       snapDistance: snapD)
            }
//            drawing.lines[e.lineIndex].controls[e.pointIndex] = control
        default: break
        }
    }
    private func movingPoint(with lcr: CellGroup.Nearest.Result.LineCapResult,
                             fp: Point, dp: Point, isVertex: Bool) {
        let snapD = snapDistance * canvasView.model.reciprocalScale
        let grid = 5 * canvasView.model.reciprocalScale
        
        let b = lcr.bezierSortedLineCapItem
        let cellGroup = canvasView.model.editingCellGroup
        var np = cellGroup.snappedPoint(fp + dp, with: b,
                                        snapDistance: snapD, grid: grid)
        switch b.drawingOrCell {
        case .drawing(let drawing):
            var newLines = drawing.lines
            if b.lineCap.line.controls.count == 2 {
                let pointIndex = b.lineCap.pointIndex
                var control = b.lineCap.line.controls[pointIndex]
                control.point = cellGroup.snappedPoint(np,
                                                       editLine: drawing.lines[b.lineCap.lineIndex],
                                                       editingMaxPointIndex: pointIndex,
                                                       snapDistance: snapD)
                newLines[b.lineCap.lineIndex].controls[pointIndex] = control
                np = control.point
            } else if isVertex {
                newLines[b.lineCap.lineIndex]
                    = b.lineCap.line.warpedWith(deltaPoint: np - fp,
                                                isFirst: b.lineCap.orientation == .first)
            } else {
                let pointIndex = b.lineCap.pointIndex
                var control = b.lineCap.line.controls[pointIndex]
                control.point = np
                newLines[b.lineCap.lineIndex].controls[b.lineCap.pointIndex] = control
            }
        //            drawing.lines = newLines
        default: break
        }
    }
    func movingLineCap(with lcr: CellGroup.Nearest.Result.LineCapResult,
                       fp: Point, dp: Point, isVertex: Bool) {
        let np = fp + dp
        
        if let dc = lcr.lineCapsItem.drawingCap {
            var newLines = dc.drawing.lines
            if isVertex {
                dc.drawingLineCaps.forEach {
                    newLines[$0.lineIndex] = $0.line.warpedWith(deltaPoint: dp,
                                                                isFirst: $0.orientation == .first)
                }
            } else {
                for cap in dc.drawingLineCaps {
                    var control = cap.orientation == .first ?
                        cap.line.controls[0] : cap.line.controls[cap.line.controls.count - 1]
                    control.point = np
                    switch cap.orientation {
                    case .first:
                        newLines[cap.lineIndex].controls[0] = control
                    case .last:
                        newLines[cap.lineIndex].controls[cap.line.controls.count - 1] = control
                    }
                }
            }
            //            e.drawing.lines = newLines
        }
    }
}
