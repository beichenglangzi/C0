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

struct CellGroup: Codable, TreeNode, Equatable, Namable {
    var name: Text
    
    var children: [CellGroup]
    
    var isHidden: Bool
    
    var effect: Effect, transform: Transform
    var drawing: Drawing
    var rootCell: Cell
    var selectedCells: [Cell]
    
    init(name: Text = "",
         children: [CellGroup] = [CellGroup](),
         isHidden: Bool = false,
         effect: Effect = Effect(),
         transform: Transform = Transform(),
         drawing: Drawing = Drawing(),
         rootCell: Cell = Cell()) {
        
        self.name = name
        self.children = children
        self.isHidden = isHidden
        self.effect = effect
        self.transform = transform
        self.drawing = drawing
        self.rootCell = rootCell
        self.selectedCells = []
    }
    
    var imageBounds: Rect {
        return rootCell.allImageBounds.union(drawing.imageBounds)
    }
    var allImageBounds: Rect {
        return children.reduce(into: imageBounds) { $0.formUnion($1.imageBounds) }
    }
    
//    enum Indication {
//        struct DrawingItem {
//            var selectedLineIndexes: [Int]
//        }
//        case none
//        case indicated(DrawingItem)
//        case selected()
//    }
//    func indication(at p: Point, reciprocalScale: Real) -> Indication? {
//        let selectedCells = selectedCellsWithNotEmptyGeometry(at: p)
//        if !selectedCells.isEmpty {
//            return (sorted(selectedCells), [], .selected)
//        } else if let cell = rootCell.at(p, reciprocalScale: reciprocalScale) {
//            return ([cell], [], .indicated)
//        } else {
//            let lineIndexes = drawing.isNearestSelectedLineIndexes(at: p) ?
//                drawing.selectedLineIndexes : []
//            if lineIndexes.isEmpty {
//                return drawing.lines.count == 0 ?
//                    ([], [], .none) : ([], Array(0..<drawing.lines.count), .indicated)
//            } else {
//                return ([], lineIndexes, .selected)
//            }
//        }
//    }
    
    func selectedCells(with cell: Cell) -> [Cell] {
        let cells = selectedGeometryItemsWithNoEmptyGeometry.map { $0.cell }
        if cells.contains(cell) {
            return cells
        } else {
            return [cell]
        }
    }
//    var selectedTreeIndexesWithNotEmptyGeometry: [Cell] {
//        return selectedCells.filter { !$0.geometry.isEmpty }
//    }
//    func selectedCellsWithNoEmptyGeometry(at point: Point) -> [Cell] {
//        for cell in selectedCells {
//            if cell.contains(point) {
//                return selectedCells.filter { !$0.geometry.isEmpty }
//            }
//        }
//        return []
//    }
//    var allSelectedGeometryItemsWithNotEmptyGeometry: [GeometryItem] {
//        var selectedGeometryItems = [GeometryItem]()
//        tracks.forEach { selectedGeometryItems += $0.selectedGeometryItemsWithNoEmptyGeometry }
//        return selectedGeometryItems
//    }
//    func allSelectedGeometryItemsWithNotEmptyGeometry(at p: Point) -> [GeometryItem] {
//        for track in tracks {
//            let geometryItems = track.selectedGeometryItemsWithNoEmptyGeometry(at: p)
//            if !geometryItems.isEmpty {
//                var selectedGeometryItems = [GeometryItem]()
//                tracks.forEach { selectedGeometryItems += $0.selectedGeometryItemsWithNoEmptyGeometry }
//                return selectedGeometryItems
//            }
//        }
//        return []
//    }
    
//    enum Selection {
//        var cellTuples: [(track: MultipleTrack, geometryItem: GeometryItem, geometry: Geometry)] = []
//        var drawingTuple: (drawing: Drawing, lineIndexes: [Int], oldLines: [Line])? = nil
//        var isEmpty: Bool {
//            return (drawingTuple?.lineIndexes.isEmpty ?? true) && cellTuples.isEmpty
//        }
//    }
//    func selection(with point: Point, reciprocalScale: Real) -> Selection {
//        let ict = indicatedCellsTuple(with: point, reciprocalScale: reciprocalScale)
//        if !ict.geometryItems.isEmpty {
//            return Selection(cellTuples: ict.geometryItems.map { (track(with: $0), $0, $0.cell.geometry) },
//                             drawingTuple: nil)
//        } else if !ict.selectedLineIndexes.isEmpty {
//            return Selection(cellTuples: [],
//                             drawingTuple: (drawing, ict.selectedLineIndexes, drawing.lines))
//        } else {
//            return Selection()
//        }
//    }
    
//    func sorted(_ cells: [Cell]) -> [Cell] {
//        var sortedCells = [Cell]()
//        rootCell.allCells(isReversed: true) { (cell, stop) in
//            if cells.contains(cell) {
//                sortedCells.append(cell)
//            }
//        }
//        return sortedCells
//    }
    
    func worldAffineTransform(at treeIndex: TreeIndex<CellGroup>) -> CGAffineTransform {
        treeIndex.indexPath
        transform.affineTransform
    }
    private func worldAffineTransform(at treeIndex: TreeIndex<CellGroup>,
                                      index: Int) -> CGAffineTransform {
        treeIndex.indexPath
        transform.affineTransform
    }
    func worldScale(at treeIndex: TreeIndex<CellGroup>) -> Real {
        if let parentScale = parent?.worldScale {
            return transform.scale.x * parentScale
        } else {
            return transform.scale.x
        }
    }
//    var worldAffineTransform: CGAffineTransform {
//        if let parentAffine = parent?.worldAffineTransform {
//            return transform.affineTransform.concatenating(parentAffine)
//        } else {
//            return transform.affineTransform
//        }
//    }
//    var worldScale: Real {
//        if let parentScale = parent?.worldScale {
//            return transform.scale.x * parentScale
//        } else {
//            return transform.scale.x
//        }
//    }
    
//    struct LineCap {
//        var line: Line, lineIndex: Int, isFirst: Bool
//        var pointIndex: Int {
//            return isFirst ? 0 : line.controls.count - 1
//        }
//    }
//    struct Nearest {
//        enum Result {
//            struct DrawingItem {
//                var drawing: Drawing, line: Line, lineIndex: Int, pointIndex: Int
//            }
//            struct CellItem {
//                var cell: Cell, cellIndex: TreeIndex<Cell>
//                var geometry: Geometry, lineIndex: Int, pointIndex: Int
//            }
//            struct DrawingLineCapItem {
//                var drawing: Drawing, lines: [Line], drawingCaps: [LineCap]
//            }
//            struct CellLineCapsItem {
//                var cell: Cell, cellIndex: TreeIndex<Cell>, geometry: Geometry, caps: [LineCap]
//            }
//            case drawing(DrawingItem), cell(CellItem)
//            case drawingLineCap(DrawingLineCapItem), cellLineCaps(CellLineCapsItem)
//        }
//        var result: Result, point: Point
//
//        struct BezierSorted {
//            enum Result {
//                case drawing(Drawing), cell((cell: Cell, cellIndex: TreeIndex<Cell>))
//            }
//            var result: Result
//            var lineCap: LineCap, point: Point
//        }
//        func bezierSortedResult(at p: Point) -> BezierSortedResult? {
//            var minDrawing: Drawing?, minGeometryItem: GeometryItem?
//            var minLineCap: LineCap?, minD² = Real.infinity
//            func minNearest(with caps: [LineCap]) -> Bool {
//                var isMin = false
//                for cap in caps {
//                    let d² = (cap.isFirst ?
//                        cap.line.bezier(at: 0) :
//                        cap.line.bezier(at: cap.line.controls.count - 3)).minDistance²(at: p)
//                    if d² < minD² {
//                        minLineCap = cap
//                        minD² = d²
//                        isMin = true
//                    }
//                }
//                return isMin
//            }
//
//            if let e = drawingEditLineCap {
//                if minNearest(with: e.drawingCaps) {
//                    minDrawing = e.drawing
//                }
//            }
//            for e in geometryItemEditLineCaps {
//                if minNearest(with: e.caps) {
//                    minDrawing = nil
//                    minGeometryItem = e.geometryItem
//                }
//            }
//            if let drawing = minDrawing, let lineCap = minLineCap {
//                return BezierSortedResult(drawing: drawing, geometryItem: nil, geometry: nil,
//                                          lineCap: lineCap, point: point)
//            }
//            else if let geometryItem = minGeometryItem, let lineCap = minLineCap {
//                return BezierSortedResult(drawing: nil, geometryItem: geometryItem,
//                                          geometry: geometryItem.cell.geometry,
//                                          lineCap: lineCap, point: point)
//            }
//            return nil
//        }
//    }
//    func nearest(at point: Point, isVertex: Bool) -> Nearest? {
//        var minD = Real.infinity, minDrawing: Drawing?, minGeometryItem: GeometryItem?
//        var minLine: Line?, minLineIndex = 0, minPointIndex = 0, minPoint = Point()
//        func nearestEditPoint(from lines: [Line]) -> Bool {
//            var isNearest = false
//            for (j, line) in lines.enumerated() {
//                line.allEditPoints() { p, i in
//                    if !(isVertex && i != 0 && i != line.controls.count - 1) {
//                        let d = hypot²(point.x - p.x, point.y - p.y)
//                        if d < minD {
//                            minD = d
//                            minLine = line
//                            minLineIndex = j
//                            minPointIndex = i
//                            minPoint = p
//                            isNearest = true
//                        }
//                    }
//                }
//            }
//            return isNearest
//        }
//
//        if nearestEditPoint(from: drawing.lines) {
//            minDrawing = drawing
//        }
//        for geometryItem in editTrack.geometryItems {
//            if nearestEditPoint(from: geometryItem.cell.geometry.lines) {
//                minDrawing = nil
//                minGeometryItem = geometryItem
//            }
//        }
//
//        if let minLine = minLine {
//            if minPointIndex == 0 || minPointIndex == minLine.controls.count - 1 {
//                func caps(with point: Point, _ lines: [Line]) -> [LineCap] {
//                    return lines.enumerated().compactMap {
//                        if point == $0.element.firstPoint {
//                            return LineCap(line: $0.element, lineIndex: $0.offset, isFirst: true)
//                        }
//                        if point == $0.element.lastPoint {
//                            return LineCap(line: $0.element, lineIndex: $0.offset, isFirst: false)
//                        }
//                        return nil
//                    }
//                }
//                let drawingCaps = caps(with: minPoint, editTrack.drawing.lines)
//                let drawingResult: (drawing: Drawing, lines: [Line], drawingCaps: [LineCap])? =
//                    drawingCaps.isEmpty ? nil : (editTrack.drawing,
//                                                 editTrack.drawing.lines, drawingCaps)
//                let cellResults: [(geometryItem: GeometryItem, geometry: Geometry, caps: [LineCap])]
//                cellResults = editTrack.geometryItems.compactMap {
//                    let aCaps = caps(with: minPoint, $0.cell.geometry.lines)
//                    return aCaps.isEmpty ? nil : ($0, $0.cell.geometry, aCaps)
//                }
//                return Nearest(drawingEdit: nil, geometryItemEdit: nil,
//                               drawingEditLineCap: drawingResult,
//                               geometryItemEditLineCaps: cellResults, point: minPoint)
//            } else {
//                if let drawing = minDrawing {
//                    return Nearest(drawingEdit: (drawing, minLine, minLineIndex, minPointIndex),
//                                   geometryItemEdit: nil,
//                                   drawingEditLineCap: nil, geometryItemEditLineCaps: [],
//                                   point: minPoint)
//                } else if let geometryItem = minGeometryItem {
//                    return Nearest(drawingEdit: nil,
//                                   geometryItemEdit: (geometryItem, geometryItem.cell.geometry,
//                                                      minLineIndex, minPointIndex),
//                                   drawingEditLineCap: nil, geometryItemEditLineCaps: [],
//                                   point: minPoint)
//                }
//            }
//        }
//        return nil
//    }
//    func nearestLine(at point: Point
//        ) -> (drawing: Drawing?, geometryItem: GeometryItem?, line: Line, lineIndex: Int, pointIndex: Int)? {
//
//        guard let nearest = self.nearest(at: point, isVertex: false) else {
//            return nil
//        }
//        if let e = nearest.drawingEdit {
//            return (e.drawing, nil, e.line, e.lineIndex, e.pointIndex)
//        } else if let e = nearest.geometryItemEdit {
//            return (nil, e.geometryItem, e.geometry.lines[e.lineIndex], e.lineIndex, e.pointIndex)
//        } else if nearest.drawingEditLineCap != nil || !nearest.geometryItemEditLineCaps.isEmpty {
//            if let b = nearest.bezierSortedResult(at: point) {
//                return (b.drawing, b.geometryItem, b.lineCap.line, b.lineCap.lineIndex,
//                        b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1)
//            }
//        }
//        return nil
//    }
    
    func snappedCells(with cell: Cell) -> [Cell] {
        var cells = self.cells
        var snapedCells = cells.compactMap { $0 !== cell && $0.isSnaped(cell) ? $0 : nil }
        func snap(_ withCell: Cell) {
            var newSnapedCells = [Cell]()
            cells = cells.compactMap {
                if $0.isSnaped(withCell) {
                    newSnapedCells.append($0)
                    return nil
                } else {
                    return $0
                }
            }
            if !newSnapedCells.isEmpty {
                snapedCells += newSnapedCells
                for newCell in newSnapedCells { snap(newCell) }
            }
        }
        snap(cell)
        return snapedCells
    }
    
    func snappedPoint(_ point: Point, with n: CellGroup.Nearest.BezierSortedResult,
                      snapDistance: Real, grid: Real?) -> Point {
        let p: Point
        if let grid = grid {
            p = Point(x: point.x.interval(scale: grid), y: point.y.interval(scale: grid))
        } else {
            p = point
        }
        var minD = Real.infinity, minP = p
        func updateMin(with ap: Point) {
            let d0 = p.distance(ap)
            if d0 < snapDistance && d0 < minD {
                minD = d0
                minP = ap
            }
        }
        func update(geometryItem: GeometryItem?) {
            for (i, line) in drawing.lines.enumerated() {
                if i == n.lineCap.lineIndex {
                    updateMin(with: n.lineCap.isFirst ? line.lastPoint : line.firstPoint)
                } else {
                    updateMin(with: line.firstPoint)
                    updateMin(with: line.lastPoint)
                }
            }
            for cell in rootCell {
                for (i, line) in cell.geometry.lines.enumerated() {
                    if aGeometryItem.id == geometryItem.id && i == n.lineCap.lineIndex {
                        updateMin(with: n.lineCap.isFirst ? line.lastPoint : line.firstPoint)
                    } else {
                        updateMin(with: line.firstPoint)
                        updateMin(with: line.lastPoint)
                    }
                }
            }
        }
        if n.drawing != nil {
            update(geometryItem: nil)
        } else if let geometryItem = n.geometryItem {
            update(geometryItem: geometryItem)
        }
        return minP
    }
    
    func snappedPoint(_ sp: Point, editLine: Line, editingMaxPointIndex empi: Int,
                      snapDistance: Real) -> Point {
        let p: Point, isFirst = empi == 1 || empi == editLine.controls.count - 1
        if isFirst {
            p = editLine.firstPoint
        } else if empi == editLine.controls.count - 2 || empi == 0 {
            p = editLine.lastPoint
        } else {
            fatalError()
        }
        var snapLines = [(ap: Point, bp: Point)](), lastSnapLines = [(ap: Point, bp: Point)]()
        func snap(with lines: [Line]) {
            for line in lines {
                if editLine.controls.count == 3 {
                    if line != editLine {
                        if line.firstPoint == editLine.firstPoint {
                            snapLines.append((line.controls[1].point, editLine.firstPoint))
                        } else if line.lastPoint == editLine.firstPoint {
                            snapLines.append((line.controls[line.controls.count - 2].point,
                                              editLine.firstPoint))
                        }
                        if line.firstPoint == editLine.lastPoint {
                            lastSnapLines.append((line.controls[1].point, editLine.lastPoint))
                        } else if line.lastPoint == editLine.lastPoint {
                            lastSnapLines.append((line.controls[line.controls.count - 2].point,
                                                  editLine.lastPoint))
                        }
                    }
                } else {
                    if line.firstPoint == p && !(line == editLine && isFirst) {
                        snapLines.append((line.controls[1].point, p))
                    } else if line.lastPoint == p && !(line == editLine && !isFirst) {
                        snapLines.append((line.controls[line.controls.count - 2].point, p))
                    }
                }
            }
        }
        snap(with: drawing.lines)
        for cell in rootCell {
            snap(with: cell.geometry.lines)
        }
        
        var minD = Real.infinity, minIntersectionPoint: Point?, minPoint = sp
        if !snapLines.isEmpty && !lastSnapLines.isEmpty {
            for sl in snapLines {
                for lsl in lastSnapLines {
                    if let ip = Point.intersectionLine(sl.ap, sl.bp, lsl.ap, lsl.bp) {
                        let d = ip.distance(sp)
                        if d < snapDistance && d < minD {
                            minD = d
                            minIntersectionPoint = ip
                        }
                    }
                }
            }
        }
        if let minPoint = minIntersectionPoint {
            return minPoint
        } else {
            let ss = snapLines + lastSnapLines
            for sl in ss {
                let np = sp.nearestWithLine(ap: sl.ap, bp: sl.bp)
                let d = np.distance(sp)
                if d < snapDistance && d < minD {
                    minD = d
                    minPoint = np
                }
            }
            return minPoint
        }
    }
    
    //view
    //    func draw(scene: Scene, viewType: Cut.ViewType,
    //              scale: Real, rotation: Real,
    //              viewScale: Real, viewRotation: Real,
    //              in ctx: CGContext) {
    //        let inScale = scale * transform.scale.x, inRotation = rotation + transform.rotation
    //        let inViewScale = viewScale * transform.scale.x
    //        let inViewRotation = viewRotation + transform.rotation
    //        let reciprocalScale = 1 / inScale, reciprocalAllScale = 1 / inViewScale
    //
    //        ctx.concatenate(transform.affineTransform)
    //
    //        if effect.opacity != 1 || effect.blendType != .normal || effect.blurRadius > 0 || !isEdited {
    //            ctx.saveGState()
    //            ctx.setAlpha(!isEdited ? 0.2 * effect.opacity : effect.opacity)
    //            ctx.setBlendMode(effect.blendType.blendMode)
    //            if effect.blurRadius > 0 {
    //                let invertCTM = ctx.ctm
    //                let bBounds = ctx.boundingBoxOfClipPath.inset(by: -effect.blurRadius).applying(invertCTM)
    //                if let bctx = CGContext.bitmap(with: bBounds.size) {
    //                    bctx.translateBy(x: -effect.blurRadius, y: -effect.blurRadius)
    //                    bctx.concatenate(ctx.ctm)
    //                    _draw(scene: scene, viewType: viewType,
    //                          reciprocalScale: reciprocalScale, reciprocalAllScale: reciprocalAllScale,
    //                          scale: inViewScale, rotation: inViewRotation, in: bctx)
    //                    children.forEach {
    //                        $0.draw(scene: scene, viewType: viewType,
    //                                scale: inScale, rotation: inRotation,
    //                                viewScale: inViewScale, viewRotation: inViewRotation,
    //                                in: bctx)
    //                    }
    //                    bctx.drawBlur(withBlurRadius: effect.blurRadius, to: ctx)
    //                }
    //            } else {
    //                ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    //                _draw(scene: scene, viewType: viewType,
    //                      reciprocalScale: reciprocalScale, reciprocalAllScale: reciprocalAllScale,
    //                      scale: inViewScale, rotation: inViewRotation, in: ctx)
    //                children.forEach {
    //                    $0.draw(scene: scene, viewType: viewType,
    //                            scale: inScale, rotation: inRotation,
    //                            viewScale: inViewScale, viewRotation: inViewRotation,
    //                            in: ctx)
    //                }
    //                ctx.endTransparencyLayer()
    //            }
    //            ctx.restoreGState()
    //        } else {
    //            _draw(scene: scene, viewType: viewType,
    //                  reciprocalScale: reciprocalScale, reciprocalAllScale: reciprocalAllScale,
    //                  scale: inViewScale, rotation: inViewRotation, in: ctx)
    //            children.forEach {
    //                $0.draw(scene: scene, viewType: viewType,
    //                        scale: inScale, rotation: inRotation,
    //                        viewScale: inViewScale, viewRotation: inViewRotation,
    //                        in: ctx)
    //            }
    //        }
    //    }
    //
    //    private func _draw(scene: Scene, viewType: Cut.ViewType,
    //                       reciprocalScale: Real, reciprocalAllScale: Real,
    //                       scale: Real, rotation: Real,
    //                       in ctx: CGContext) {
    //        let isEdit = !isEdited ? false :
    //            (viewType != .preview && viewType != .editMaterial && viewType != .changingMaterial)
    //        moveWithWiggle: if viewType == .preview && !xWiggle.isEmpty {
    //            let waveY = yWiggle.yWith(t: wiggleT)
    //            ctx.translateBy(x: waveY, y: 0)
    //        }
    //        guard !isHidden else {
    //            return
    //        }
    //        if isEdit {
    //            rootCell.children.forEach {
    //                $0.draw(isEdit: isEdit, isUseDraw: false,
    //                        reciprocalScale: reciprocalScale, reciprocalAllScale: reciprocalAllScale,
    //                        scale: scale, rotation: rotation,
    //                        in: ctx)
    //            }
    //
    //            ctx.saveGState()
    //            ctx.setAlpha(0.5)
    //            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    //            rootCell.children.forEach {
    //                $0.draw(isEdit: isEdit, isUseDraw: true,
    //                        reciprocalScale: reciprocalScale, reciprocalAllScale: reciprocalAllScale,
    //                        scale: scale, rotation: rotation,
    //                        in: ctx)
    //            }
    //            ctx.endTransparencyLayer()
    //            ctx.restoreGState()
    //        } else {
    //            rootCell.children.forEach {
    //                $0.draw(isEdit: isEdit, isUseDraw: true,
    //                        reciprocalScale: reciprocalScale, reciprocalAllScale: reciprocalAllScale,
    //                        scale: scale, rotation: rotation,
    //                        in: ctx)
    //            }
    //        }
    //
    //        drawAnimation: do {
    //            if isEdit {
    //                tracks.forEach {
    ////                    if !$0.isHidden {
    //                        if $0 === editTrack {
    //                            $0.drawing.drawEdit(withReciprocalScale: reciprocalScale, in: ctx)
    //                        } else {
    //                            ctx.setAlpha(0.5)
    //                            $0.drawing.drawEdit(withReciprocalScale: reciprocalScale, in: ctx)
    //                            ctx.setAlpha(1)
    //                        }
    ////                    }
    //                }
    //            } else {
    //                var alpha = 1.0.cg
    //                tracks.forEach {
    ////                    if !$0.isHidden {
    //                        ctx.setAlpha(alpha)
    //                        $0.drawing.draw(withReciprocalScale: reciprocalScale, in: ctx)
    ////                    }
    //                    alpha = max(alpha * 0.4, 0.25)
    //                }
    //                ctx.setAlpha(1)
    //            }
    //        }
    //    }
    //
    //    struct Edit {
    //        var indicatedGeometryItem: GeometryItem? = nil, editMaterial: Material? = nil, editZ: EditZ? = nil
    //        var editPoint: EditPoint? = nil, editTransform: EditTransform? = nil, point: Point?
    //    }
    //    func drawEdit(_ edit: Edit,
    //                  scene: Scene, viewType: Cut.ViewType,
    //                  strokeLine: Line?, strokeLineWidth: Real, strokeLineColor: Color,
    //                  reciprocalViewScale: Real, scale: Real, rotation: Real,
    //                  in ctx: CGContext) {
    //        let worldScale = self.worldScale
    //        let rScale = 1 / worldScale
    //        let rAllScale = reciprocalViewScale / worldScale
    //        let wat = worldAffineTransform
    //        ctx.saveGState()
    //        ctx.concatenate(wat)
    //
    //        if !wat.isIdentity {
    //            ctx.setStrokeColor(Color.locked.cg)
    //            ctx.move(to: Point(x: -10, y: 0))
    //            ctx.addLine(to: Point(x: 10, y: 0))
    //            ctx.move(to: Point(x: 0, y: -10))
    //            ctx.addLine(to: Point(x: 0, y: 10))
    //            ctx.strokePath()
    //        }
    //
    //        drawStroke: do {
    //            if let strokeLine = strokeLine {
    //                if viewType == .editSelected || viewType == .editDeselected {
    //                    let geometry = Geometry(lines: [strokeLine])
    //                    if viewType == .editSelected {
    //                        geometry.drawSkin(lineColor: .selectBorder, subColor: .select,
    //                                          reciprocalScale: rScale, reciprocalAllScale: rAllScale,
    //                                          in: ctx)
    //                    } else {
    //                        geometry.drawSkin(lineColor: .deselectBorder, subColor: .deselect,
    //                                          reciprocalScale: rScale, reciprocalAllScale: rAllScale,
    //                                          in: ctx)
    //                    }
    //                } else {
    //                    ctx.setFillColor(strokeLineColor.cg)
    //                    strokeLine.draw(size: strokeLineWidth * rScale, in: ctx)
    //                }
    //            }
    //        }
    //
    //        let isEdit = viewType != .preview && viewType != .changingMaterial
    //        if isEdit {
    ////            if !editTrack.isHidden {
    //                if viewType == .editPoint || viewType == .editVertex {
    //                    editTrack.drawTransparentCellLines(withReciprocalScale: rScale, in: ctx)
    //                }
    //                editTrack.drawPreviousNext(isHiddenPrevious: scene.isHiddenPrevious,
    //                                           isHiddenNext: scene.isHiddenNext,
    //                                           time: time, reciprocalScale: rScale, in: ctx)
    ////            }
    //
    //            for track in tracks {
    ////                if !track.isHidden {
    //                    track.drawSelectedCells(opacity: 0.75 * (track != editTrack ? 0.5 : 1),
    //                                            color: .selected,
    //                                            subColor: .subSelected,
    //                                            reciprocalScale: rScale,  in: ctx)
    ////                    let drawing = track.drawingItem.drawing
    //                    let selectedLineIndexes = track.drawing.selectedLineIndexes
    //                    if !selectedLineIndexes.isEmpty {
    //                        let imageBounds = selectedLineIndexes.reduce(into: Rect.null) {
    //                            $0.formUnion(track.drawing.lines[$1].imageBounds)
    //                        }
    //                        ctx.setStrokeColor(Color.selected.with(alpha: 0.8).cg)
    //                        ctx.setLineWidth(rScale)
    //                        ctx.stroke(imageBounds)
    //                    }
    ////                }
    //            }
    ////            if !editTrack.isHidden {
    //                let isMovePoint = viewType == .editPoint || viewType == .editVertex
    //
    ////                if viewType == .editMaterial {
    ////                    if let material = edit.editMaterial {
    ////                        drawMaterial: do {
    ////                            rootCell.allCells { cell, stop in
    ////                                if cell.material.id == material.id {
    ////                                    ctx.addPath(cell.geometry.path)
    ////                                }
    ////                            }
    ////                            ctx.setLineWidth(3 * rAllScale)
    ////                            ctx.setLineJoin(.round)
    ////                            ctx.setStrokeColor(Color.editMaterial.cg)
    ////                            ctx.strokePath()
    ////                            rootCell.allCells { cell, stop in
    ////                                if cell.material.color == material.color
    ////                                    && cell.material.id != material.id {
    ////
    ////                                    ctx.addPath(cell.geometry.path)
    ////                                }
    ////                            }
    ////                            ctx.setLineWidth(3 * rAllScale)
    ////                            ctx.setLineJoin(.round)
    ////                            ctx.setStrokeColor(Color.editMaterialColorOnly.cg)
    ////                            ctx.strokePath()
    ////                        }
    ////                    }
    ////                }
    //
    ////                if !isMovePoint,
    ////                    let indicatedGeometryItem = edit.indicatedGeometryItem,
    ////                    editTrack.geometryItems.contains(indicatedGeometryItem) {
    ////
    ////                    if editTrack.selectedGeometryItems.contains(indicatedGeometryItem), let p = edit.point {
    ////                        editTrack.selectedGeometryItems.forEach {
    ////                            drawNearestCellLine(for: p, cell: $0.cell, lineColor: .selected,
    ////                                                reciprocalAllScale: rAllScale, in: ctx)
    ////                        }
    ////                    }
    ////                }
    //                if let editZ = edit.editZ {
    //                    drawEditZ(editZ, in: ctx)
    //                }
    //                if isMovePoint {
    //                    drawEditPoints(with: edit.editPoint, isEditVertex: viewType == .editVertex,
    //                                   reciprocalAllScale: rAllScale, in: ctx)
    //                }
    //                if let editTransform = edit.editTransform {
    //                    if viewType == .editWarp {
    //                        drawWarp(with: editTransform, reciprocalAllScale: rAllScale, in: ctx)
    //                    } else if viewType == .editTransform {
    //                        drawTransform(with: editTransform, reciprocalAllScale: rAllScale, in: ctx)
    //                    }
    //                }
    ////            }
    //        }
    //        ctx.restoreGState()
    //        if viewType != .preview {
    //            drawTransform(scene.frame, in: ctx)
    //        }
    //    }
    //
    //    func drawTransform(_ cameraFrame: Rect, in ctx: CGContext) {
    //        func drawCameraBorder(bounds: Rect, inColor: Color, outColor: Color) {
    //            ctx.setStrokeColor(inColor.cg)
    //            ctx.stroke(bounds.insetBy(dx: -0.5, dy: -0.5))
    //            ctx.setStrokeColor(outColor.cg)
    //            ctx.stroke(bounds.insetBy(dx: -1.5, dy: -1.5))
    //        }
    //        ctx.setLineWidth(1)
    //        if !xWiggle.isEmpty {
    //            let amplitude = xWiggle.amplitude
    //            drawCameraBorder(bounds: cameraFrame.insetBy(dx: -amplitude, dy: 0),
    //                             inColor: Color.cameraBorder, outColor: Color.cutSubBorder)
    //        }
    //        let track = editTrack
    //        func drawPreviousNextCamera(t: Transform, color: Color) {
    //            let affine = transform.affineTransform.inverted().concatenating(t.affineTransform)
    //            ctx.saveGState()
    //            ctx.concatenate(affine)
    //            drawCameraBorder(bounds: cameraFrame, inColor: color, outColor: Color.cutSubBorder)
    //            ctx.restoreGState()
    //            func strokeBounds() {
    //                ctx.move(to: Point(x: cameraFrame.minX, y: cameraFrame.minY))
    //                ctx.addLine(to: Point(x: cameraFrame.minX, y: cameraFrame.minY).applying(affine))
    //                ctx.move(to: Point(x: cameraFrame.minX, y: cameraFrame.maxY))
    //                ctx.addLine(to: Point(x: cameraFrame.minX, y: cameraFrame.maxY).applying(affine))
    //                ctx.move(to: Point(x: cameraFrame.maxX, y: cameraFrame.minY))
    //                ctx.addLine(to: Point(x: cameraFrame.maxX, y: cameraFrame.minY).applying(affine))
    //                ctx.move(to: Point(x: cameraFrame.maxX, y: cameraFrame.maxY))
    //                ctx.addLine(to: Point(x: cameraFrame.maxX, y: cameraFrame.maxY).applying(affine))
    //            }
    //            ctx.setStrokeColor(color.cg)
    //            strokeBounds()
    //            ctx.strokePath()
    //            ctx.setStrokeColor(Color.cutSubBorder.cg)
    //            strokeBounds()
    //            ctx.strokePath()
    //        }
    //        let lki = track.animation.indexInfo(withTime: time)
    //        if lki.keyframeInternalTime == 0 && lki.keyframeIndex > 0 {
    //            if let t = track.transformItem?.keyTransforms[lki.keyframeIndex - 1], transform != t {
    //                drawPreviousNextCamera(t: t, color: .red)
    //            }
    //        }
    //        if let t = track.transformItem?.keyTransforms[lki.keyframeIndex], transform != t {
    //            drawPreviousNextCamera(t: t, color: .red)
    //        }
    //        if lki.keyframeIndex < track.animation.keyframes.count - 1 {
    //            if let t = track.transformItem?.keyTransforms[lki.keyframeIndex + 1], transform != t {
    //                drawPreviousNextCamera(t: t, color: .green)
    //            }
    //        }
    //        drawCameraBorder(bounds: cameraFrame, inColor: Color.locked, outColor: Color.cutSubBorder)
    //    }
    //
    //    struct EditPoint: Equatable {
    //        var nearestLine: Line, nearestPointIndex: Int, lines: [Line], point: Point, isSnap: Bool
    //
    //        func draw(withReciprocalAllScale reciprocalAllScale: Real,
    //                  lineColor: Color, in ctx: CGContext) {
    //            for line in lines {
    //                ctx.setFillColor((line == nearestLine ? lineColor : Color.subSelected).cg)
    //                line.draw(size: 2 * reciprocalAllScale, in: ctx)
    //            }
    //            point.draw(radius: 3 * reciprocalAllScale, lineWidth: reciprocalAllScale,
    //                       inColor: isSnap ? .snap : lineColor, outColor: .controlPointIn, in: ctx)
    //        }
    //    }
    //    private let editPointRadius = 0.5.cg, lineEditPointRadius = 1.5.cg, pointEditPointRadius = 3.0.cg
    //    func drawEditPoints(with editPoint: EditPoint?, isEditVertex: Bool,
    //                        reciprocalAllScale: Real, in ctx: CGContext) {
    //        if let ep = editPoint, ep.isSnap {
    //            let p: Point?, np: Point?
    //            if ep.nearestPointIndex == 1 {
    //                p = ep.nearestLine.firstPoint
    //                np = ep.nearestLine.controls.count == 2 ?
    //                    nil : ep.nearestLine.controls[2].point
    //            } else if ep.nearestPointIndex == ep.nearestLine.controls.count - 2 {
    //                p = ep.nearestLine.lastPoint
    //                np = ep.nearestLine.controls.count == 2 ?
    //                    nil :
    //                    ep.nearestLine.controls[ep.nearestLine.controls.count - 3].point
    //            } else {
    //                p = nil
    //                np = nil
    //            }
    //            if let p = p {
    //                func drawSnap(with point: Point, capPoint: Point) {
    //                    if let ps = Point.boundsPointWithLine(ap: point, bp: capPoint,
    //                                                            bounds: ctx.boundingBoxOfClipPath) {
    //                        ctx.move(to: ps.p0)
    //                        ctx.addLine(to: ps.p1)
    //                        ctx.setLineWidth(1 * reciprocalAllScale)
    //                        ctx.setStrokeColor(Color.selected.cg)
    //                        ctx.strokePath()
    //                    }
    //                    if let np = np, ep.nearestLine.controls.count > 2 {
    //                        let p1 = ep.nearestPointIndex == 1 ?
    //                            ep.nearestLine.controls[1].point :
    //                            ep.nearestLine.controls[ep.nearestLine.controls.count - 2].point
    //                        ctx.move(to: p1.mid(np))
    //                        ctx.addLine(to: p1)
    //                        ctx.addLine(to: capPoint)
    //                        ctx.setLineWidth(0.5 * reciprocalAllScale)
    //                        ctx.setStrokeColor(Color.selected.cg)
    //                        ctx.strokePath()
    //                        p1.draw(radius: 2 * reciprocalAllScale, lineWidth: reciprocalAllScale,
    //                                inColor: Color.selected, outColor: Color.controlPointIn, in: ctx)
    //                    }
    //                }
    //                func drawSnap(with lines: [Line]) {
    //                    for line in lines {
    //                        if line != ep.nearestLine {
    //                            if ep.nearestLine.controls.count == 3 {
    //                                if line.firstPoint == ep.nearestLine.firstPoint {
    //                                    drawSnap(with: line.controls[1].point,
    //                                             capPoint: ep.nearestLine.firstPoint)
    //                                } else if line.lastPoint == ep.nearestLine.firstPoint {
    //                                    drawSnap(with: line.controls[line.controls.count - 2].point,
    //                                             capPoint: ep.nearestLine.firstPoint)
    //                                }
    //                                if line.firstPoint == ep.nearestLine.lastPoint {
    //                                    drawSnap(with: line.controls[1].point,
    //                                             capPoint: ep.nearestLine.lastPoint)
    //                                } else if line.lastPoint == ep.nearestLine.lastPoint {
    //                                    drawSnap(with: line.controls[line.controls.count - 2].point,
    //                                             capPoint: ep.nearestLine.lastPoint)
    //                                }
    //                            } else {
    //                                if line.firstPoint == p {
    //                                    drawSnap(with: line.controls[1].point, capPoint: p)
    //                                } else if line.lastPoint == p {
    //                                    drawSnap(with: line.controls[line.controls.count - 2].point,
    //                                             capPoint: p)
    //                                }
    //                            }
    //                        } else if line.firstPoint == line.lastPoint {
    //                            if ep.nearestPointIndex == line.controls.count - 2 {
    //                                drawSnap(with: line.controls[1].point, capPoint: p)
    //                            } else if ep.nearestPointIndex == 1 && p == line.firstPoint {
    //                                drawSnap(with: line.controls[line.controls.count - 2].point,
    //                                         capPoint: p)
    //                            }
    //                        }
    //                    }
    //                }
    //                drawSnap(with: editTrack.drawing.lines)
    //                for cell in editTrack.cells {
    //                    drawSnap(with: cell.geometry.lines)
    //                }
    //            }
    //        }
    //        editPoint?.draw(withReciprocalAllScale: reciprocalAllScale,
    //                        lineColor: .selected,
    //                        in: ctx)
    //
    //        var capPointDic = [Point: Bool]()
    //        func updateCapPointDic(with lines: [Line]) {
    //            for line in lines {
    //                let fp = line.firstPoint, lp = line.lastPoint
    //                if capPointDic[fp] != nil {
    //                    capPointDic[fp] = true
    //                } else {
    //                    capPointDic[fp] = false
    //                }
    //                if capPointDic[lp] != nil {
    //                    capPointDic[lp] = true
    //                } else {
    //                    capPointDic[lp] = false
    //                }
    //            }
    //        }
    //        if !editTrack.geometryItems.isEmpty {
    //            for cell in editTrack.cells {
    //                if !cell.isLocked {
    //                    if !isEditVertex {
    //                        Line.drawEditPointsWith(lines: cell.geometry.lines,
    //                                                reciprocalScale: reciprocalAllScale, in: ctx)
    //                    }
    //                    updateCapPointDic(with: cell.geometry.lines)
    //                }
    //            }
    //        }
    //        if !isEditVertex {
    //            Line.drawEditPointsWith(lines: editTrack.drawing.lines,
    //                                    reciprocalScale: reciprocalAllScale, in: ctx)
    //        }
    //        updateCapPointDic(with: editTrack.drawing.lines)
    //
    //        let r = lineEditPointRadius * reciprocalAllScale, lw = 0.5 * reciprocalAllScale
    //        for v in capPointDic {
    //            v.key.draw(radius: r, lineWidth: lw,
    //                       inColor: v.value ? .controlPointJointIn : .controlPointCapIn,
    //                       outColor: .controlPointOut, in: ctx)
    //        }
    //    }
    //
    //    struct EditZ: Equatable {
    //        var cells: [Cell], point: Point, firstPoint: Point, firstY: Real
    //    }
    //    func drawEditZ(_ editZ: EditZ, in ctx: CGContext) {
    //        rootCell.depthFirstSearch(duplicate: true) { parent, cell in
    //            if editZ.cells.contains(cell), let index = parent.children.index(of: cell) {
    //                if !parent.geometry.isEmpty {
    //                    parent.geometry.clip(in: ctx) {
    //                        Cell.drawCellPaths(Array(parent.children[(index + 1)...]),
    //                                           Color.moveZ, in: ctx)
    //                    }
    //                } else {
    //                    Cell.drawCellPaths(Array(parent.children[(index + 1)...]),
    //                                       Color.moveZ, in: ctx)
    //                }
    //            }
    //        }
    //    }
    //    let editZHeight = 4.0.cg
    //    func drawEditZKnob(_ editZ: EditZ, at point: Point, in ctx: CGContext) {
    //        ctx.saveGState()
    //        ctx.setLineWidth(1)
    //        let editCellY = editZFirstY(with: editZ.cells)
    //        drawZ(withFillColor: .knob, lineColor: .getSetBorder,
    //              position: Point(x: point.x,
    //                                y: point.y - editZ.firstY + editCellY), in: ctx)
    //        var p = Point(x: point.x - editZHeight, y: point.y - editZ.firstY)
    //        rootCell.allCells { (cell, stop) in
    //            drawZ(withFillColor: cell.colorAndLineColor(withIsEdit: true, isInterpolated: false).color,
    //                  lineColor: .getSetBorder, position: p, in: ctx)
    //            p.y += editZHeight
    //        }
    //        ctx.restoreGState()
    //    }
    //    func drawZ(withFillColor fillColor: Color, lineColor: Color,
    //               position p: Point, in ctx: CGContext) {
    //        ctx.setFillColor(fillColor.cg)
    //        ctx.setStrokeColor(lineColor.cg)
    //        ctx.addRect(Rect(x: p.x - editZHeight / 2, y: p.y - editZHeight / 2,
    //                           width: editZHeight, height: editZHeight))
    //        ctx.drawPath(using: .fillStroke)
    //    }
    //    func editZFirstY(with cells: [Cell]) -> Real {
    //        guard let firstCell = cells.first else {
    //            return 0
    //        }
    //        var y = 0.0.cg
    //        rootCell.allCells { (cell, stop) in
    //            if cell == firstCell {
    //                stop = true
    //            } else {
    //                y += editZHeight
    //            }
    //        }
    //        return y
    //    }
    //    func drawNearestCellLine(for p: Point, cell: Cell, lineColor: Color,
    //                             reciprocalAllScale: Real, in ctx: CGContext) {
    //        if let n = cell.geometry.nearestBezier(with: p) {
    //            let np = cell.geometry.lines[n.lineIndex].bezier(at: n.bezierIndex).position(withT: n.t)
    //            ctx.setStrokeColor(Color.background.multiply(alpha: 0.75).cg)
    //            ctx.setLineWidth(3 * reciprocalAllScale)
    //            ctx.move(to: Point(x: p.x, y: p.y))
    //            ctx.addLine(to: Point(x: np.x, y: p.y))
    //            ctx.addLine(to: Point(x: np.x, y: np.y))
    //            ctx.strokePath()
    //            ctx.setStrokeColor(lineColor.cg)
    //            ctx.setLineWidth(reciprocalAllScale)
    //            ctx.move(to: Point(x: p.x, y: p.y))
    //            ctx.addLine(to: Point(x: np.x, y: p.y))
    //            ctx.addLine(to: Point(x: np.x, y: np.y))
    //            ctx.strokePath()
    //        }
    //    }
    //
    //    struct EditTransform: Equatable {
    //        static let centerRatio = 0.25.cg
    //        var rotatedRect: RotatedRect, anchorPoint: Point
    //        var point: Point, oldPoint: Point, isCenter: Bool
    //    }
    //    func warpAffineTransform(with et: EditTransform) -> CGAffineTransform {
    //        guard et.oldPoint != et.anchorPoint else {
    //            return CGAffineTransform.identity
    //        }
    //        let theta = et.oldPoint.tangential(et.anchorPoint)
    //        let angle = theta < 0 ? theta + .pi : theta - .pi
    //        var pAffine = CGAffineTransform(rotationAngle: -angle)
    //        pAffine = pAffine.translatedBy(x: -et.anchorPoint.x, y: -et.anchorPoint.y)
    //        let newOldP = et.oldPoint.applying(pAffine), newP = et.point.applying(pAffine)
    //        let scaleX = newP.x / newOldP.x, skewY = (newP.y - newOldP.y) / newOldP.x
    //        var affine = CGAffineTransform(translationX: et.anchorPoint.x, y: et.anchorPoint.y)
    //        affine = affine.rotated(by: angle)
    //        affine = affine.scaledBy(x: scaleX, y: 1)
    //        if skewY != 0 {
    //            affine = CGAffineTransform(a: 1, b: skewY, c: 0, d: 1, tx: 0, ty: 0).concatenating(affine)
    //        }
    //        affine = affine.rotated(by: -angle)
    //        return affine.translatedBy(x: -et.anchorPoint.x, y: -et.anchorPoint.y)
    //    }
    //    func transformAffineTransform(with et: EditTransform) -> CGAffineTransform {
    //        guard et.oldPoint != et.anchorPoint else {
    //            return CGAffineTransform.identity
    //        }
    //        let r = et.point.distance(et.anchorPoint), oldR = et.oldPoint.distance(et.anchorPoint)
    //        let angle = et.anchorPoint.tangential(et.point)
    //        let oldAngle = et.anchorPoint.tangential(et.oldPoint)
    //        let scale = r / oldR
    //        var affine = CGAffineTransform(translationX: et.anchorPoint.x, y: et.anchorPoint.y)
    //        affine = affine.rotated(by: angle.differenceRotation(oldAngle))
    //        affine = affine.scaledBy(x: scale, y: scale)
    //        affine = affine.translatedBy(x: -et.anchorPoint.x, y: -et.anchorPoint.y)
    //        return affine
    //    }
    //    func drawWarp(with et: EditTransform, reciprocalAllScale: Real, in ctx: CGContext) {
    //        if et.isCenter {
    //            drawLine(firstPoint: et.rotatedRect.midXMinYPoint,
    //                     lastPoint: et.rotatedRect.midXMaxYPoint,
    //                     reciprocalAllScale: reciprocalAllScale, in: ctx)
    //            drawLine(firstPoint: et.rotatedRect.minXMidYPoint,
    //                     lastPoint: et.rotatedRect.maxXMidYPoint,
    //                     reciprocalAllScale: reciprocalAllScale, in: ctx)
    //        } else {
    //            drawLine(firstPoint: et.anchorPoint, lastPoint: et.point,
    //                     reciprocalAllScale: reciprocalAllScale, in: ctx)
    //        }
    //
    //        drawRotatedRect(with: et, reciprocalAllScale: reciprocalAllScale, in: ctx)
    //        et.anchorPoint.draw(radius: lineEditPointRadius * reciprocalAllScale,
    //                            lineWidth: reciprocalAllScale, in: ctx)
    //    }
    //    func drawTransform(with et: EditTransform, reciprocalAllScale: Real, in ctx: CGContext) {
    //        ctx.setAlpha(0.5)
    //        drawLine(firstPoint: et.anchorPoint, lastPoint: et.oldPoint,
    //                 reciprocalAllScale: reciprocalAllScale, in: ctx)
    //        drawCircleWith(radius: et.oldPoint.distance(et.anchorPoint), anchorPoint: et.anchorPoint,
    //                       reciprocalAllScale: reciprocalAllScale, in: ctx)
    //        ctx.setAlpha(1)
    //        drawLine(firstPoint: et.anchorPoint, lastPoint: et.point,
    //                 reciprocalAllScale: reciprocalAllScale, in: ctx)
    //        drawCircleWith(radius: et.point.distance(et.anchorPoint), anchorPoint: et.anchorPoint,
    //                       reciprocalAllScale: reciprocalAllScale, in: ctx)
    //
    //        drawRotatedRect(with: et, reciprocalAllScale: reciprocalAllScale, in: ctx)
    //        et.anchorPoint.draw(radius: lineEditPointRadius * reciprocalAllScale,
    //                            lineWidth: reciprocalAllScale, in: ctx)
    //    }
    //    func drawRotatedRect(with et: EditTransform, reciprocalAllScale: Real, in ctx: CGContext) {
    //        ctx.setLineWidth(reciprocalAllScale)
    //        ctx.setStrokeColor(Color.camera.cg)
    //        ctx.saveGState()
    //        ctx.concatenate(et.rotatedRect.affineTransform)
    //        let w = et.rotatedRect.size.width * EditTransform.centerRatio
    //        let h = et.rotatedRect.size.height * EditTransform.centerRatio
    //        ctx.stroke(Rect(x: (et.rotatedRect.size.width - w) / 2,
    //                          y: (et.rotatedRect.size.height - h) / 2, width: w, height: h))
    //        ctx.stroke(Rect(x: 0, y: 0,
    //                          width: et.rotatedRect.size.width, height: et.rotatedRect.size.height))
    //        ctx.restoreGState()
    //    }
    //
    //    func drawCircleWith(radius r: Real, anchorPoint: Point,
    //                        reciprocalAllScale: Real, in ctx: CGContext) {
    //        let cb = Rect(x: anchorPoint.x - r, y: anchorPoint.y - r, width: r * 2, height: r * 2)
    //        let outLineWidth = 3 * reciprocalAllScale, inLineWidth = 1.5 * reciprocalAllScale
    //        ctx.setLineWidth(outLineWidth)
    //        ctx.setStrokeColor(Color.controlPointOut.cg)
    //        ctx.strokeEllipse(in: cb)
    //        ctx.setLineWidth(inLineWidth)
    //        ctx.setStrokeColor(Color.controlPointIn.cg)
    //        ctx.strokeEllipse(in: cb)
    //    }
    //    func drawLine(firstPoint: Point, lastPoint: Point,
    //                  reciprocalAllScale: Real, in ctx: CGContext) {
    //        let outLineWidth = 3 * reciprocalAllScale, inLineWidth = 1.5 * reciprocalAllScale
    //        ctx.setLineWidth(outLineWidth)
    //        ctx.setStrokeColor(Color.controlPointOut.cg)
    //        ctx.move(to: firstPoint)
    //        ctx.addLine(to: lastPoint)
    //        ctx.strokePath()
    //        ctx.setLineWidth(inLineWidth)
    //        ctx.setStrokeColor(Color.controlPointIn.cg)
    //        ctx.move(to: firstPoint)
    //        ctx.addLine(to: lastPoint)
    //        ctx.strokePath()
    //    }
    
    //    func drawPreviousNext(isHiddenPrevious: Bool, isHiddenNext: Bool,
    //                          time: Beat, reciprocalScale: Real, in ctx: CGContext) {
    //        let index = animation.indexInfo(withTime: time).keyframeIndex
    //        drawingItem.drawPreviousNext(isHiddenPrevious: isHiddenPrevious, isHiddenNext: isHiddenNext,
    //                                     index: index, reciprocalScale: reciprocalScale, in: ctx)
    //        geometryItems.enumerated().forEach { (i, geometryItem) in
    //            geometryItem.drawPreviousNext(lineWidth: cells[i].material.lineWidth * reciprocalScale,
    //                                          isHiddenPrevious: isHiddenPrevious,
    //                                          isHiddenNext: isHiddenNext,
    //                                          index: index, in: ctx)
    //        }
    //    }
    //    func drawSelectedCells(opacity: Real, color: Color, subColor: Color,
    //                           reciprocalScale: Real, in ctx: CGContext) {
    //        guard !selectedGeometryItems.isEmpty else {
    //            return
    //        }
    //        ctx.setAlpha(opacity)
    //        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    //        var geometrys = [Geometry]()
    //        ctx.setFillColor(subColor.with(alpha: 1).cg)
    //        func setPaths(with geometryItem: GeometryItem) {
    //            let cell = geometryItem.cell
    //            if !cell.geometry.isEmpty {
    //                cell.geometry.addPath(in: ctx)
    //                ctx.fillPath()
    //                geometrys.append(cell.geometry)
    //            }
    //        }
    //        selectedGeometryItems.forEach { setPaths(with: $0) }
    //        ctx.endTransparencyLayer()
    //        ctx.setAlpha(1)
    //
    //        ctx.setFillColor(color.with(alpha: 1).cg)
    //        geometrys.forEach { $0.draw(withLineWidth: 1.5 * reciprocalScale, in: ctx) }
    //    }
    //    func drawTransparentCellLines(withReciprocalScale reciprocalScale: Real, in ctx: CGContext) {
    //        cells.forEach {
    //            $0.geometry.drawLines(withColor: .getSetBorder, reciprocalScale: reciprocalScale, in: ctx)
    //            $0.geometry.drawPathLine(withReciprocalScale: reciprocalScale, in: ctx)
    //        }
    //    }
    //    func drawSkinGeometryItem(_ geometryItem: GeometryItem,
    //                              reciprocalScale: Real, reciprocalAllScale: Real, in ctx: CGContext) {
    //        geometryItem.geometry.drawSkin(lineColor: .indicated,
    //                                       subColor: Color.subIndicated.multiply(alpha: 0.2),
    //                                       skinLineWidth: animation.isInterpolated ? 3 : 1,
    //                                       reciprocalScale: reciprocalScale,
    //                                       reciprocalAllScale: reciprocalAllScale, in: ctx)
    //    }
}
extension CellGroup: Referenceable {
    static let name = Text(english: "CellGroup", japanese: "ノード")
}
extension CellGroup: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return name.view(withFrame: frame, sizeType)
    }
}

struct CellGroupChildrenKeyframeValue: KeyframeValue {
    var children = [CellGroup]()
    var editingTreeIndex = TreeIndex<CellGroup>()
    
    static func linear(_ f0: CellGroupChildrenKeyframeValue, _ f1: CellGroupChildrenKeyframeValue,
                       t: Real) -> CellGroupChildrenKeyframeValue {
        return f0
    }
    static func firstMonospline(_ f1: CellGroupChildrenKeyframeValue,
                                _ f2: CellGroupChildrenKeyframeValue,
                                _ f3: CellGroupChildrenKeyframeValue,
                                with ms: Monospline) -> CellGroupChildrenKeyframeValue {
        return f1
    }
    static func monospline(_ f0: CellGroupChildrenKeyframeValue,
                           _ f1: CellGroupChildrenKeyframeValue,
                           _ f2: CellGroupChildrenKeyframeValue,
                           _ f3: CellGroupChildrenKeyframeValue,
                           with ms: Monospline) -> CellGroupChildrenKeyframeValue {
        return f1
    }
    static func lastMonospline(_ f0: CellGroupChildrenKeyframeValue,
                               _ f1: CellGroupChildrenKeyframeValue,
                               _ f2: CellGroupChildrenKeyframeValue,
                               with ms: Monospline) -> CellGroupChildrenKeyframeValue {
        return f1
    }
}
extension CellGroupChildrenKeyframeValue: Referenceable {
    static let name = Text(english: "Cell Node Children Keyframe Value",
                           japanese: "セルノード子キーフレーム値")
}

final class CellGroupView<T: BinderProtocol>: View, BindableReceiver {
    typealias Model = CellGroup
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    
    var sizeType: SizeType {
        didSet { updateLayout() }
    }
    private let classNameView: TextFormView
    private let isHiddenView: BoolView<Binder>
    init(binder: T, keyPath: BinderKeyPath, frame: Rect = Rect(), sizeType: SizeType = .regular) {
        self.binder = binder
        self.keyPath = keyPath
        
        self.sizeType = sizeType
        classNameView = TextFormView(text: CellGroup.name, font: Font.bold(with: sizeType))
        isHiddenView = BoolView(binder: binder, keyPath: keyPath.appending(path: \Model.isHidden),
                                option: BoolOption(defaultModel: false, cationModel: true,
                                                   name: "", info: .hidden),
                                sizeType: sizeType)
        
        super.init()
        children = [classNameView, isHiddenView]
        self.frame = frame
    }
    
    override func updateLayout() {
        let padding = Layout.padding(with: sizeType)
        classNameView.frame.origin = Point(x: padding,
                                           y: bounds.height - classNameView.frame.height - padding)
        isHiddenView.frame = Rect(x: classNameView.frame.maxX + padding, y: padding,
                                  width: bounds.width - classNameView.frame.width - padding * 3,
                                  height: Layout.height(with: sizeType))
    }
    func updateWithModel() {
        isHiddenView.updateWithModel()
    }
}
extension CellGroupView: Localizable {
    func update(with locale: Locale) {
        updateLayout()
    }
}
extension CellGroupView: Queryable {
    static var referenceableType: Referenceable.Type {
        return Model.self
    }
}
extension CellGroupView: Copiable {
    func copiedObjects(at p: Point) -> [Object] {
        return [Object(model)]
    }
}
