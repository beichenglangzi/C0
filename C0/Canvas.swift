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
        get {
            return rootCellGroup[editingCellGroupTreeIndex]
        }
        set {
            rootCellGroup[editingCellGroupTreeIndex] = newValue
        }
    }
    private(set) var editingWorldAffieTransform: CGAffineTransform
    
    init(frame: Rect = Rect(x: -288, y: -162, width: 576, height: 324),
         transform: Transform = Transform(), rootCellGroup: CellGroup = CellGroup(),
         editingCellGroupTreeIndex: TreeIndex<CellGroup> = TreeIndex()) {
        
        self.frame = frame
        self.transform = transform
        self.rootCellGroup = rootCellGroup
        self.editingCellGroupTreeIndex = editingCellGroupTreeIndex
        reciprocalScale = 1 / transform.scale.x
    }
}
extension Canvas {
    func image(with size: Size) -> Image? {
        guard let ctx = CGContext.bitmap(with: size, CGColorSpace.default) else {
            return nil
        }
        let scale = size.width / frame.size.width
        let viewTransform = Transform(translation: Point(x: size.width / 2, y: size.height / 2),
                                      scale: Point(x: scale, y: scale),
                                      rotation: 0)
        let drawView = View(drawClosure: { ctx, _ in
            ctx.concatenate(viewTransform.affineTransform)
            self.draw(in: ctx)
        })
        drawView.render(in: ctx)
        return ctx.renderImage
    }
}
extension Canvas {
    //view
    func draw(in ctx: CGContext) {
        ctx.saveGState()
        ctx.concatenate(transform.affineTransform)
        rootCellGroup.draw
        ctx.restoreGState()
    }
}
extension Canvas: Referenceable {
    static let name = Text(english: "Canvas", japanese: "キャンバス")
}

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
    var defaultModel = Model()
    
    init(binder: T, keyPath: BinderKeyPath,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        super.init(drawClosure: { $1.draw(in: $0) }, isLocked: false)
        
    }
    
    var screenTransform = CGAffineTransform.identity
    override func updateLayout() {
        updateScreenTransform()
    }
    private func updateScreenTransform() {
        screenTransform = CGAffineTransform(translationX: bounds.midX, y: bounds.midY)
    }
    func updateWithModel() {
        
    }
    var editPoint: CellGroup.EditPoint? {
        didSet {
            if editPoint != oldValue {
                displayLinkDraw()
            }
        }
    }
    func updateEditPoint(with point: Point) {
        if let n = cut.currentNode.nearest(at: point, isVertex: viewType == .editVertex) {
            if let e = n.drawingEdit {
                editPoint = CellGroup.EditPoint(nearestLine: e.line, nearestPointIndex: e.pointIndex,
                                                lines: [e.line],
                                                point: n.point, isSnap: movePointIsSnap)
            } else if let e = n.geometryItemEdit {
                editPoint = CellGroup.EditPoint(nearestLine: e.geometry.lines[e.lineIndex],
                                                nearestPointIndex: e.pointIndex,
                                                lines: [e.geometry.lines[e.lineIndex]],
                                                point: n.point, isSnap: movePointIsSnap)
            } else if n.drawingEditLineCap != nil || !n.geometryItemEditLineCaps.isEmpty {
                if let nlc = n.bezierSortedResult(at: point) {
                    if let e = n.drawingEditLineCap {
                        let drawingLines = e.drawingCaps.map { $0.line }
                        let geometryItemLines = n.geometryItemEditLineCaps.reduce(into: [Line]()) {
                            $0 += $1.caps.map { $0.line }
                        }
                        editPoint = CellGroup.EditPoint(nearestLine: nlc.lineCap.line,
                                                        nearestPointIndex: nlc.lineCap.pointIndex,
                                                        lines: drawingLines + geometryItemLines,
                                                        point: n.point,
                                                        isSnap: movePointIsSnap)
                    } else {
                        let geometryItemLines = n.geometryItemEditLineCaps.reduce(into: [Line]()) {
                            $0 += $1.caps.map { $0.line }
                        }
                        editPoint = CellGroup.EditPoint(nearestLine: nlc.lineCap.line,
                                                        nearestPointIndex: nlc.lineCap.pointIndex,
                                                        lines: geometryItemLines,
                                                        point: n.point,
                                                        isSnap: movePointIsSnap)
                    }
                } else {
                    editPoint = nil
                }
            }
        } else {
            editPoint = nil
        }
    }
    var currentTransform: CGAffineTransform {
        var affine = CGAffineTransform.identity
        affine = affine.concatenating(model.editingWorldAffieTransform)
        affine = affine.concatenating(model.transform.affineTransform)
        affine = affine.concatenating(screenTransform)
        return affine
    }
    func convertToCurrentLocal(_ r: Rect) -> Rect {
        let transform = currentTransform
        return transform.isIdentity ? r : r.applying(transform.inverted())
    }
    func convertFromCurrentLocal(_ r: Rect) -> Rect {
        let transform = currentTransform
        return transform.isIdentity ? r : r.applying(transform)
    }
    func convertToCurrentLocal(_ p: Point) -> Point {
        let transform = currentTransform
        return transform.isIdentity ? p : p.applying(transform.inverted())
    }
    func convertFromCurrentLocal(_ p: Point) -> Point {
        let transform = currentTransform
        return transform.isIdentity ? p : p.applying(transform)
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
            
        }
    }
    func set(_ selection: ) {
        model.editingCellGroup.selectedCellIndexes
    }
    
    func makeViewSelector() -> ViewSelector {
        return CanvasViewSelector<Binder>(canvasView: self)
    }
    
    func selectAll() {
        model.editingCellGroup.selectedCellIndexes = []
    }
    func deselectAll() {
        model.editingCellGroup.selectedCellIndexes = model.editingCellGroup.rootCell.enumerated().map { $0.offset }
    }
}
final class CanvasViewSelector<Binder: BinderProtocol>: ViewSelector {
    var canvasView: CanvasView<Binder>
    var cellGroup: CellGroup?, cellGroupIndex: CellGroup.Index
    var selectedLineIndexes = [Int]()
    var drawing: Drawing?
    
    func select(from rect: Rect, _ phase: Phase) {
        select(from: rect, phase, isDeselect: false)
    }
    func deselect(from rect: Rect, _ phase: Phase) {
        select(from: rect, phase, isDeselect: true)
    }
    func select(from rect: Rect, _ phase: Phase, isDeselect: Bool) {
        func unionWithStrokeLine(with drawing: Drawing) -> [Array<Line>.Index] {
            func selected() -> (lineIndexes: [Int], geometryItems: [GeometryItem]) {
                let transform = currentTransform.inverted()
                let lines = [Line].rectangle(rect).map { $0.applying(transform) }
                let lasso = LineLasso(lines: lines)
                return (drawing.lines.enumerated().compactMap { lasso.intersects($1) ? $0 : nil },
                        track.geometryItems.filter { $0.cell.intersects(lasso) })
            }
            let s = selected()
            if isDeselect {
                return Array(Set(selectedLineIndexes).subtracting(Set(s.lineIndexes)))
            } else {
                return Array(Set(selectedLineIndexes).union(Set(s.lineIndexes)))
            }
        }
        
        switch phase {
        case .began:
            cellGroupIndex = canvasView.model.editingCellGroupTreeIndex
            selectedLineIndexes = canvasView.model.editingCellGroup.selectedCellIndexes
        case .changed, .ended:
            guard let drawing = selectOption.drawing, let track = selectOption.track else { return }
            canvasView.model.rootCellGroup[selectedLineIndexes]
            (drawing.selectedLineIndexes, track.selectedGeometryItems)
                = unionWithStrokeLine(with: drawing, track)
        }
    }
}
extension CanvasView: Queryable {
    static var referenceableType: Referenceable.Type {
        return Model.self
    }
}
extension CanvasView: Assignable {
    func reset(for p: Point, _ version: Version) {
        <#code#>
    }
    
    func paste(_ objects: [Any], for p: Point, _ version: Version) {
        <#code#>
    }
    
    func copiedObjects(at p: Point) -> [Object] {
        <#code#>
    }
}
extension CanvasView: Newable {
    func new(for p: Point, _ version: Version) {
        let editingCellGroup = model.editingCellGroup
        let geometry = Geometry(lines: editingCellGroup.drawing.editLines, scale: model.scale)
        guard !geometry.isEmpty else { return }
        let isDrawingSelectedLines = !editingCellGroup.drawing.selectedLineIndexes.isEmpty
        let unselectedLines = editingCellGroup.drawing.uneditLines
        set(unselectedLines, old: editingCellGroup.drawing.lines,
            in: editingCellGroup.drawing, inNode, time: time)
        //insertCell
    }
}
extension CanvasView: Transformable {
    
}
final class CanvasViewTransformer<Binder: BinderProtocol>: ViewSelector {
    var canvasView: CanvasView<Binder>
    var transformBounds = Rect.null, moveOldPoint = Point(), moveTransformOldPoint = Point()
    enum TransformEditType {
        case move, transform, warp
    }
    func move(for p: Point, pressure: Real, time: Second, _ phase: Phase, _ version: Version) {
        move(for: p, pressure: pressure, time: time, phase, type: .move)
    }
    func transform(for p: Point, pressure: Real, time: Second, _ phase: Phase, _ version: Version) {
        move(for: p, pressure: pressure, time: time, phase, type: .transform)
    }
    func warp(for p: Point, pressure: Real, time: Second, _ phase: Phase, _ version: Version) {
        move(for: p, pressure: pressure, time: time, phase, type: .warp)
    }
    let moveTransformAngleTime = Second(0.1)
    var moveEditTransform: CellGroup.EditTransform?, moveTransformAngleOldTime = Second(0.0)
    var moveTransformAnglePoint = Point(), moveTransformAngleOldPoint = Point()
    var isMoveTransformAngle = false
    var moveNode: CellGroup?
    func move(for point: Point, pressure: Real, time: Second, _ phase: Phase,
              type: TransformEditType) {
        let p = convertToCurrentLocal(point)
        func affineTransform(with node: CellGroup) -> CGAffineTransform {
            switch type {
            case .move:
                return CGAffineTransform(translationX: p.x - moveOldPoint.x, y: p.y - moveOldPoint.y)
            case .warp:
                if let editTransform = moveEditTransform {
                    return node.warpAffineTransform(with: editTransform)
                } else {
                    return CGAffineTransform.identity
                }
            case .transform:
                if let editTransform = moveEditTransform {
                    return node.transformAffineTransform(with: editTransform)
                } else {
                    return CGAffineTransform.identity
                }
            }
        }
        switch phase {
        case .began:
            moveSelected = cut.currentNode.selection(with: p, reciprocalScale: model.reciprocalScale)
            if type != .move {
                self.moveEditTransform = editTransform(at: p)
                editTransform = moveEditTransform
                self.moveTransformAngleOldTime = time
                self.moveTransformAngleOldPoint = p
                self.isMoveTransformAngle = false
                self.moveTransformOldPoint = p
                
                if type == .warp {
                    let mm = minMaxPointFrom(p)
                    self.minWarpDistance = mm.minDistance
                    self.maxWarpDistance = mm.maxDistance
                }
            }
            moveNode = cut.currentNode
            moveOldPoint = p
        case .changed, .ended:
            if type != .move {
                if var editTransform = moveEditTransform {
                }
            }
            if type == .warp {
                if let editTransform = moveEditTransform, editTransform.isCenter {
                    distanceWarp(for: p, pressure: pressure, time: time, phase)
                    return
                }
            }
            if !moveSelected.isEmpty, let node = moveNode {
                let affine = affineTransform(with: node)
                if let mdp = moveSelected.drawingTuple {
                    var newLines = mdp.oldLines
                    for index in mdp.lineIndexes {
                        newLines.remove(at: index)
                        newLines.insert(mdp.oldLines[index].applying(affine), at: index)
                    }
                    //                    mdp.drawing.lines = newLines
                }
                for mcp in moveSelected.cellTuples {
                    //track.replace
                    //                    mcp.geometryItem.replace(mcp.geometry.applying(affine),
                    //                                         at: mcp.track.animation.editKeyframeIndex)
                }
            }
        }
    }
}

extension CanvasView: PointMovable {
    func captureWillMovePoint(at p: Point, to version: Version) {
        
    }
    func movePoint(for p: Point, first fp: Point, pressure: Real, time: Second, _ phase: Phase) {
        
    }
    
    
    func insert(_ point: Point) {
        let p = convertToCurrentLocal(point), inNode = model.editingCellGroup
        guard let nearest = inNode.nearestLineItem(at: p) else { return }
        
    }
    func removeNearestPoint(for point: Point) {
        let p = convertToCurrentLocal(point), inNode = model.editingCellGroup
        guard let nearest = inNode.nearestLineItem(at: p) else { return }
        if nearest.line.controls.count > 2 {
            replaceLine(nearest.line.removedControl(at: nearest.pointIndex),
                        oldLine: nearest.line,
                        at: nearest.lineIndex, in: drawing, in: inNode, time: time)
        } else {
            removeLine(at: nearest.lineIndex, in: drawing, inNode, time: time)
        }
    }
}
final class CanvasViewPointMover<Binder: BinderProtocol>: ViewSelector {
    var canvasView: CanvasView<Binder>
    
    private var movePointNearest: CellGroup.Nearest?, movePointOldPoint = Point(), movePointIsSnap = false
    private var movePointNode: CellGroup?
    private let snapPointSnapDistance = 8.0.cg
    func movePoint(for p: Point, pressure: Real, time: Second, _ phase: Phase) {
        movePoint(for: p, pressure: pressure, time: time, phase, isVertex: false)
    }
    func moveVertex(for p: Point, pressure: Real, time: Second, _ phase: Phase) {
        movePoint(for: p, pressure: pressure, time: time, phase, isVertex: true)
    }
    func movePoint(for point: Point, pressure: Real, time: Second, _ phase: Phase,
                   isVertex: Bool) {
        let p = canvasView.convertToCurrentLocal(point)
        switch phase {
        case .began:
            let cellGroup = canvasView.model.editingCellGroup
            guard let nearest = cellGroup.nearest(at: p, isVertex: isVertex) else { return }
            movePointNearest = nearest
            movePointIsSnap = false
            movePointNode = cellGroup
            movePointOldPoint = p
        case .changed, .ended:
            guard let nearest = movePointNearest else { return }
            let dp = p - movePointOldPoint
            
            movePointIsSnap = movePointIsSnap ? true : pressure == 1//speed
            
            if nearest.drawingEdit != nil || nearest.geometryItemEdit != nil {
                movingPoint(with: nearest, dp: dp, in: cut.currentNode.editTrack)
            } else {
                if movePointIsSnap, let b = bezierSortedResult {
                    movingPoint(with: nearest, bezierSortedResult: b, dp: dp,
                                isVertex: isVertex, in: cut.currentNode.editTrack)
                } else {
                    movingLineCap(with: nearest, dp: dp,
                                  isVertex: isVertex, in: cut.currentNode.editTrack)
                }
            }
        }
    }
    private func movingPoint(with nearest: CellGroup.Nearest, dp: Point) {
        let snapD = snapPointSnapDistance / canvasView.model.scale
        if let e = nearest.drawingEdit {
            var control = e.line.controls[e.pointIndex]
            control.point = e.line.editPoint(withEditCenterPoint: nearest.point + dp,
                                             at: e.pointIndex)
            if movePointIsSnap && (e.pointIndex == 1 || e.pointIndex == e.line.controls.count - 2) {
                control.point = track.snapPoint(control.point,
                                                editLine: e.drawing.lines[e.lineIndex],
                                                editPointIndex: e.pointIndex,
                                                snapDistance: snapD)
            }
            //            e.drawing.lines[e.lineIndex] = e.line.withReplaced(control, at: e.pointIndex)
            let np = e.drawing.lines[e.lineIndex].editCenterPoint(at: e.pointIndex)
            editPoint = CellGroup.EditPoint(nearestLine: e.drawing.lines[e.lineIndex],
                                            nearestPointIndex: e.pointIndex,
                                            lines: [e.drawing.lines[e.lineIndex]],
                                            point: np,
                                            isSnap: movePointIsSnap)
        }
    }
    private func movingBezierSortedPoint(with nearest: CellGroup.Nearest, dp: Point, isVertex: Bool) {
        let snapD = snapPointSnapDistance * canvasView.model.reciprocalScale
        let grid = 5 * canvasView.model.reciprocalScale
        
        let bs: CellGroup.LineCapItem?
        switch nearest.result {
        case .lineCapResult(let result): bs = result.bezierSortedLineCapItem
        default: bs = nil
        }
        guard let b = bs else { return }
        
        var np = track.snapPoint(nearest.point + dp, with: b, snapDistance: snapD, grid: grid)
        if let e = nearest.drawingEditLineCap, let drawing = b.drawing {
            var newLines = e.lines
            if b.lineCap.line.controls.count == 2 {
                let pointIndex = b.lineCap.pointIndex
                var control = b.lineCap.line.controls[pointIndex]
                control.point = track.snapPoint(np, editLine: drawing.lines[b.lineCap.lineIndex],
                                                editPointIndex: pointIndex, snapDistance: snapD)
                newLines[b.lineCap.lineIndex] = b.lineCap.line.withReplaced(control, at: pointIndex)
                np = control.point
            } else if isVertex {
                newLines[b.lineCap.lineIndex] = b.lineCap.line.warpedWith(
                    deltaPoint: np - nearest.point, isFirst: b.lineCap.isFirst)
            } else {
                let pointIndex = b.lineCap.pointIndex
                var control = b.lineCap.line.controls[pointIndex]
                control.point = np
                newLines[b.lineCap.lineIndex] = newLines[b.lineCap.lineIndex].withReplaced(
                    control, at: b.lineCap.pointIndex)
            }
            //            drawing.lines = newLines
            editPoint = CellGroup.EditPoint(nearestLine: drawing.lines[b.lineCap.lineIndex],
                                            nearestPointIndex: b.lineCap.pointIndex,
                                            lines: e.drawingCaps.map { drawing.lines[$0.lineIndex] },
                                            point: np,
                                            isSnap: movePointIsSnap)
        }
    }
    func movingLineCap(with nearest: CellGroup.Nearest, dp: Point, isVertex: Bool) {
        let np = nearest.point + dp
        var editPointLines = [Line]()
        if let e = nearest.drawingEditLineCap {
            var newLines = e.drawing.lines
            if isVertex {
                e.drawingCaps.forEach {
                    newLines[$0.lineIndex] = $0.line.warpedWith(deltaPoint: dp,
                                                                isFirst: $0.isFirst)
                }
            } else {
                for cap in e.drawingCaps {
                    var control = cap.isFirst ?
                        cap.line.controls[0] : cap.line.controls[cap.line.controls.count - 1]
                    control.point = np
                    newLines[cap.lineIndex] = newLines[cap.lineIndex]
                        .withReplaced(control, at: cap.isFirst ? 0 : cap.line.controls.count - 1)
                }
            }
            //            e.drawing.lines = newLines
            editPointLines = e.drawingCaps.map { newLines[$0.lineIndex] }
        }
        
        track.updateInterpolation()
        
        if let b = bezierSortedResult {
            if let drawing = b.drawing {
                let newLine = drawing.lines[b.lineCap.lineIndex]
                editPoint = CellGroup.EditPoint(nearestLine: newLine,
                                                nearestPointIndex: b.lineCap.pointIndex,
                                                lines: Array(Set(editPointLines)),
                                                point: np, isSnap: movePointIsSnap)
            }
        }
    }
}
