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
    var editingCellGroupTreeIndex: TreeIndex<CellGroup>
    var editingCellGroup: CellGroup {
        get {
            return rootCellGroup[editingCellGroupTreeIndex]
        }
        set {
            rootCellGroup[editingCellGroupTreeIndex] = newValue
        }
    }
    
    init(frame: Rect = Rect(x: -288, y: -162, width: 576, height: 324),
         transform: Transform = Transform(), rootCellGroup: CellGroup = CellGroup(),
         editingCellGroupTreeIndex: TreeIndex<CellGroup> = TreeIndex()) {
        
        self.frame = frame
        self.transform = transform
        self.rootCellGroup = rootCellGroup
        self.editingCellGroupTreeIndex = editingCellGroupTreeIndex
        reciprocalScale = 1 / transform.scale.x
    }
    
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
        //        ctx.saveGState()
        //        ctx.concatenate(screenTransform)
        //        cut.draw(scene: scene, viewType: viewType, in: ctx)
        //        if viewType != .preview {
        //            let edit = CellGroup.Edit(indicatedGeometryItem: indicatedGeometryItem,
        //                                 editMaterial: materialView.material,
        //                                 editZ: editZ, editPoint: editPoint,
        //                                 editTransform: editTransform, point: indicatedPoint)
        //            ctx.concatenate(scene.viewTransform.affineTransform)
        //            cut.currentNode.drawEdit(edit, scene: scene, viewType: viewType,
        //                                  strokeLine: stroker.line,
        //                                  strokeLineWidth: stroker.lineWidth,
        //                                  strokeLineColor: stroker.lineColor,
        //                                  reciprocalViewScale: scene.reciprocalViewScale,
        //                                  scale: scene.scale, rotation: scene.viewTransform.rotation,
        //                                  in: ctx)
        //            ctx.restoreGState()
        //            if let editZ = editZ {
        //                let p = convertFromCurrentLocal(editZ.firstPoint)
        //                cut.currentNode.drawEditZKnob(editZ, at: p, in: ctx)
        //            }
        //            cut.drawCautionBorder(scene: scene, bounds: bounds, in: ctx)
        //        } else {
        //            ctx.restoreGState()
        //        }
    }
    //    func draw(viewType: ViewQuasimode, in ctx: CGContext) {
    //        if viewType == .preview {
    //            ctx.saveGState()
    //            rootCellGroup.draw(scene: self, viewType: viewType,
    //                              scale: 1, rotation: 0,
    //                              viewScale: 1, viewRotation: 0,
    //                              in: ctx)
    //            if !isHiddenSubtitles {
    //                subtitleTrack.drawSubtitle.draw(bounds: scene.frame, in: ctx)
    //            }
    //            ctx.restoreGState()
    //        } else {
    //            ctx.saveGState()
    //            ctx.concatenate(viewTransform.affineTransform)
    //            rootNode.draw(scene: self, viewType: viewType,
    //                          scale: 1, rotation: 0,
    //                          viewScale: scale, viewRotation: viewTransform.rotation,
    //                          in: ctx)
    //            ctx.restoreGState()
    //        }
    //    }
    //
    //    func drawCautionBorder(bounds: Rect, in ctx: CGContext) {
    //        func drawBorderWith(bounds: Rect, width: Real, color: Color, in ctx: CGContext) {
    //            ctx.setFillColor(color.cg)
    //            ctx.fill([Rect(x: bounds.minX, y: bounds.minY,
    //                           width: width, height: bounds.height),
    //                      Rect(x: bounds.minX + width, y: bounds.minY,
    //                           width: bounds.width - width * 2, height: width),
    //                      Rect(x: bounds.minX + width, y: bounds.maxY - width,
    //                           width: bounds.width - width * 2, height: width),
    //                      Rect(x: bounds.maxX - width, y: bounds.minY,
    //                           width: width, height: bounds.height)])
    //        }
    //        if viewTransform.rotation > .pi / 2 || viewTransform.rotation < -.pi / 2 {
    //            let borderWidth = 2.0.cg
    //            drawBorderWith(bounds: bounds, width: borderWidth * 2, color: .warning, in: ctx)
    //            let textLine = TextFrame(string: "\(Int(viewTransform.rotation * 180 / (.pi)))°",
    //                font: .bold, color: .warning)
    //            let sb = textLine.typographicBounds.insetBy(dx: -10, dy: -2).integral
    //            textLine.draw(in: Rect(x: bounds.minX + (bounds.width - sb.width) / 2,
    //                                   y: bounds.minY + bounds.height - sb.height - borderWidth,
    //                                   width: sb.width, height: sb.height), baseFont: .bold,
    //                                                                        in: ctx)
    //        }
    //    }
}
extension Canvas: Referenceable {
    static let name = Text(english: "Canvas", japanese: "キャンバス")
}

/**
 Issue: Z移動を廃止してセルツリー表示を作成、セルクリップや全てのロック解除などを廃止
 Issue: スクロール後の元の位置までの距離を表示
 */
final class CanvasView: View, Indicatable, Selectable, Zoomable, Rotatable, Strokable, Transformable, PointEditable {
    var canvas: Canvas
    
    init(canvas: Canvas = Canvas()) {
        self.canvas = canvas
        
        super.init(drawClosure: { $1.draw(in: $0) }, isLocked: false)
    }

    var screenTransform = CGAffineTransform.identity
    override func updateLayout() {
        updateScreenTransform()
    }
    private func updateScreenTransform() {
        screenTransform = CGAffineTransform(translationX: bounds.midX, y: bounds.midY)
    }
//    var editPoint: CellGroup.EditPoint? {
//        didSet {
//            if editPoint != oldValue {
//                setNeedsDisplay()
//            }
//        }
//    }
//    func updateEditPoint(with point: Point) {
//        if let n = cut.currentNode.nearest(at: point, isVertex: viewType == .editVertex) {
//            if let e = n.drawingEdit {
//                editPoint = CellGroup.EditPoint(nearestLine: e.line, nearestPointIndex: e.pointIndex,
//                                           lines: [e.line],
//                                           point: n.point, isSnap: movePointIsSnap)
//            } else if let e = n.geometryItemEdit {
//                editPoint = CellGroup.EditPoint(nearestLine: e.geometry.lines[e.lineIndex],
//                                           nearestPointIndex: e.pointIndex,
//                                           lines: [e.geometry.lines[e.lineIndex]],
//                                           point: n.point, isSnap: movePointIsSnap)
//            } else if n.drawingEditLineCap != nil || !n.geometryItemEditLineCaps.isEmpty {
//                if let nlc = n.bezierSortedResult(at: point) {
//                    if let e = n.drawingEditLineCap {
//                        let drawingLines = e.drawingCaps.map { $0.line }
//                        let geometryItemLines = n.geometryItemEditLineCaps.reduce(into: [Line]()) {
//                            $0 += $1.caps.map { $0.line }
//                        }
//                        editPoint = CellGroup.EditPoint(nearestLine: nlc.lineCap.line,
//                                                   nearestPointIndex: nlc.lineCap.pointIndex,
//                                                   lines: drawingLines + geometryItemLines,
//                                                   point: n.point,
//                                                   isSnap: movePointIsSnap)
//                    } else {
//                        let geometryItemLines = n.geometryItemEditLineCaps.reduce(into: [Line]()) {
//                            $0 += $1.caps.map { $0.line }
//                        }
//                        editPoint = CellGroup.EditPoint(nearestLine: nlc.lineCap.line,
//                                                   nearestPointIndex: nlc.lineCap.pointIndex,
//                                                   lines: geometryItemLines,
//                                                   point: n.point,
//                                                   isSnap: movePointIsSnap)
//                    }
//                } else {
//                    editPoint = nil
//                }
//            }
//        } else {
//            editPoint = nil
//        }
//    }
//    var editTransform: CellGroup.EditTransform? {
//        didSet {
//            if editTransform != oldValue {
//                setNeedsDisplay()
//            }
//        }
//    }
//    private func editTransform(with lines: [Line], at p: Point) -> CellGroup.EditTransform {
//        var ps = [Point]()
//        for line in lines {
//            line.allEditPoints { (ep, i) in ps.append(ep) }
//        }
//        let rb = RotatedRect(convexHullPoints: ps.convexHull)
//        let w = rb.size.width * CellGroup.EditTransform.centerRatio
//        let h = rb.size.height * CellGroup.EditTransform.centerRatio
//        let centerBounds = Rect(x: (rb.size.width - w) / 2,
//                                  y: (rb.size.height - h) / 2, width: w, height: h)
//        let np = rb.convertToLocal(p: p)
//        let isCenter = centerBounds.contains(np)
//        let tx = np.x / rb.size.width, ty = np.y / rb.size.height
//        if ty < tx {
//            if ty < 1 - tx {
//                return CellGroup.EditTransform(rotatedRect: rb,
//                                          anchorPoint: isCenter ? rb.midXMidYPoint : rb.midXMaxYPoint,
//                                          point: rb.midXMinYPoint,
//                                          oldPoint: rb.midXMinYPoint, isCenter: isCenter)
//            } else {
//                return CellGroup.EditTransform(rotatedRect: rb,
//                                          anchorPoint: isCenter ? rb.midXMidYPoint : rb.minXMidYPoint,
//                                          point: rb.maxXMidYPoint,
//                                          oldPoint: rb.maxXMidYPoint, isCenter: isCenter)
//            }
//        } else {
//            if ty < 1 - tx {
//                return CellGroup.EditTransform(rotatedRect: rb,
//                                          anchorPoint: isCenter ? rb.midXMidYPoint : rb.maxXMidYPoint,
//                                          point: rb.minXMidYPoint,
//                                          oldPoint: rb.minXMidYPoint, isCenter: isCenter)
//            } else {
//                return CellGroup.EditTransform(rotatedRect: rb,
//                                          anchorPoint: isCenter ? rb.midXMidYPoint : rb.midXMinYPoint,
//                                          point: rb.midXMaxYPoint,
//                                          oldPoint: rb.midXMaxYPoint, isCenter: isCenter)
//            }
//        }
//    }
//    func editTransform(at p: Point) -> CellGroup.EditTransform? {
//        let selection = cut.currentNode.selection(with: p, reciprocalScale: scene.reciprocalScale)
//        if selection.cellTuples.isEmpty {
//            if let drawingTuple = selection.drawingTuple {
//                if drawingTuple.lineIndexes.isEmpty {
//                    return nil
//                } else {
//                    let lines = drawingTuple.lineIndexes.map { drawingTuple.drawing.lines[$0] }
//                    return editTransform(with: lines, at: p)
//                }
//            } else {
//                return nil
//            }
//        } else {
//            let lines = selection.cellTuples.reduce(into: [Line]()) {
//                $0 += $1.geometryItem.cell.geometry.lines
//            }
//            return editTransform(with: lines, at: p)
//        }
//    }
//    func updateEditTransform(with p: Point) {
//        self.editTransform = editTransform(at: p)
//    }
    var currentTransform: CGAffineTransform {
        var affine = CGAffineTransform.identity
        affine = affine.concatenating(cut.currentNode.worldAffineTransform)
        affine = affine.concatenating(canvas.transform.affineTransform)
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
    func setNeedsDisplay() {
        displayLinkDraw()
    }
    func setNeedsDisplay(inCurrentLocalBounds rect: Rect) {
        displayLinkDraw(convertFromCurrentLocal(rect))
    }
    
    func indicate(at point: Point) {
        updateEditView(with: convertToCurrentLocal(point))
    }

    func select(from rect: Rect, _ phase: Phase, _ version: Version) {
        select(from: rect, phase, isDeselect: false)
    }
    func selectAll(_ version: Version) {
        selectAll(isDeselect: false)
    }
    func deselect(from rect: Rect, _ phase: Phase, _ version: Version) {
        select(from: rect, phase, isDeselect: true)
    }
    func deselectAll(_ version: Version) {
        selectAll(isDeselect: true)
    }
    private struct SelectOption {
        var selectedLineIndexes = [Int](), selectedGeometryItems = [GeometryItem]()
        var node: CellGroup?, drawing: Drawing?, track: MultipleTrack?
    }
    private var selectOption = SelectOption()
    func select(from rect: Rect, _ phase: Phase, isDeselect: Bool) {
//        func unionWithStrokeLine(with drawing: Drawing,
//                                 _ track: MultipleTrack) -> (lineIndexes: [Int], geometryItems: [GeometryItem]) {
//            func selected() -> (lineIndexes: [Int], geometryItems: [GeometryItem]) {
//                let transform = currentTransform.inverted()
//                let lines = [Line].rectangle(rect).map { $0.applying(transform) }
//                let lasso = LineLasso(lines: lines)
//                return (drawing.lines.enumerated().compactMap { lasso.intersects($1) ? $0 : nil },
//                        track.geometryItems.filter { $0.cell.intersects(lasso) })
//            }
//            let s = selected()
//            if isDeselect {
//                return (Array(Set(selectOption.selectedLineIndexes).subtracting(Set(s.lineIndexes))),
//                    Array(Set(selectOption.selectedGeometryItems).subtracting(Set(s.geometryItems))))
//            } else {
//                return (Array(Set(selectOption.selectedLineIndexes).union(Set(s.lineIndexes))),
//                        Array(Set(selectOption.selectedGeometryItems).union(Set(s.geometryItems))))
//            }
//        }
//
//        switch phase {
//        case .began:
//            selectOption.node = cut.currentNode
//            let drawing = cut.currentNode.editTrack.drawingItem.drawing, track = cut.currentNode.editTrack
//            selectOption.drawing = drawing
//            selectOption.track = track
//            selectOption.selectedLineIndexes = drawing.selectedLineIndexes
//            selectOption.selectedGeometryItems = track.selectedGeometryItems
//        case .changed:
//            guard let drawing = selectOption.drawing, let track = selectOption.track else { return }
////            (drawing.selectedLineIndexes, track.selectedGeometryItems)
////                = unionWithStrokeLine(with: drawing, track)
//        case .ended:
//            guard let drawing = selectOption.drawing,
//                let track = selectOption.track, let node = selectOption.node else {
//                    return
//            }
//            let (selectedLineIndexes, selectedGeometryItems)
//                = unionWithStrokeLine(with: drawing, track)
//            if selectedLineIndexes != selectOption.selectedLineIndexes {
//                setSelectedLineIndexes(selectedLineIndexes,
//                                       oldLineIndexes: selectOption.selectedLineIndexes,
//                                       in: drawing, node, time: time)
//            }
//            if selectedGeometryItems != selectOption.selectedGeometryItems {
//                setSelectedGeometryItems(selectedGeometryItems,//sort
//                                     oldGeometryItems: selectOption.selectedGeometryItems,
//                                     in: track, time: time)
//            }
//            selectOption = SelectOption()
//            stroker.line = nil
//        }
//        setNeedsDisplay()
    }
    func selectAll(isDeselect: Bool) {
//        let inNode = cut.currentNode
//        let track = inNode.editTrack
//        let drawing = track.drawingItem.drawing
//        let lineIndexes = isDeselect ? [] : Array(0..<drawing.lines.count)
//        if Set(lineIndexes) != Set(drawing.selectedLineIndexes) {
//            setSelectedLineIndexes(lineIndexes, oldLineIndexes: drawing.selectedLineIndexes,
//                                   in: drawing, inNode, time: time)
//        }
//        let geometryItems = isDeselect ? [] : track.geometryItems
//        if Set(geometryItems) != Set(track.selectedGeometryItems) {
//            setSelectedGeometryItems(geometryItems, oldGeometryItems: track.selectedGeometryItems,
//                                 in: track, time: time)
//        }
    }

//    private func addCellIndex(with cell: Cell, in parent: Cell) -> Int {
//        let editCells = cut.currentNode.editTrack.cells
//        for i in (0..<parent.children.count).reversed() {
//            if editCells.contains(parent.children[i]) && parent.children[i].contains(cell) {
//                return i + 1
//            }
//        }
//        for i in 0..<parent.children.count {
//            if editCells.contains(parent.children[i]) && parent.children[i].intersects(cell) {
//                return i
//            }
//        }
//        for i in 0..<parent.children.count {
//            if editCells.contains(parent.children[i]) && !parent.children[i].isLocked {
//                return i
//            }
//        }
//        return cellIndex(withTrackIndex: cut.currentNode.editTrackIndex, in: parent)
//    }

//    func cellIndex(withTrackIndex trackIndex: Int, in parent: Cell) -> Int {
//        for i in trackIndex + 1..<cut.currentNode.tracks.count {
//            let track = cut.currentNode.tracks[i]
//            var maxIndex = 0, isMax = false
//            for geometryItem in track.geometryItems {
//                if let j = parent.children.index(of: geometryItem.cell) {
//                    isMax = true
//                    maxIndex = max(maxIndex, j)
//                }
//            }
//            if isMax {
//                return maxIndex + 1
//            }
//        }
//        return 0
//    }
//
//    func moveCell(_ cell: Cell, from fromParents: [(cell: Cell, index: Int)],
//                  to toParents: [(cell: Cell, index: Int)], in node: CellGroup, time: Beat) {
//        registerUndo { $0.moveCell(cell, from: toParents, to: fromParents, in: node, time: $1) }
//        self.time = time
//        for fromParent in fromParents {
//            fromParent.cell.children.remove(at: fromParent.index)
//        }
//        for toParent in toParents {
//            toParent.cell.children.insert(cell, at: toParent.index)
//        }
//        node.diffDataModel.isWrite = true
//        sceneDataModel?.isWrite = true
//        setNeedsDisplay()
//    }
//
//    private func insertCell(_ geometryItem: GeometryItem,
//                            in parents: [(cell: Cell, index: Int)],
//                            _ track: MultipleTrack, _ node: CellGroup, time: Beat) {
//        registerUndo { $0.removeCell(geometryItem, in: parents, track, node, time: $1) }
//        self.time = time
//        track.insertCell(geometryItem, in: parents)
//        node.diffDataModel.isWrite = true
//        sceneDataModel?.isWrite = true
//        setNeedsDisplay()
//    }
//    private func removeCell(_ geometryItem: GeometryItem,
//                            in parents: [(cell: Cell, index: Int)],
//                            _ track: MultipleTrack, _ node: CellGroup, time: Beat) {
//        registerUndo { $0.insertCell(geometryItem, in: parents, track, node, time: $1) }
//        self.time = time
//        track.removeCell(geometryItem, in: parents)
//        node.diffDataModel.isWrite = true
//        sceneDataModel?.isWrite = true
//        setNeedsDisplay()
//    }
//    private func insertCells(_ geometryItems: [GeometryItem], rootCell: Cell,
//                             at index: Int, in parent: Cell,
//                             _ track: MultipleTrack, _ node: CellGroup, time: Beat) {
//        registerUndo {
//            $0.removeCells(geometryItems, rootCell: rootCell, at: index, in: parent, track, node, time: $1)
//        }
//        self.time = time
//        track.insertCells(geometryItems, rootCell: rootCell, at: index, in: parent)
//        node.diffDataModel.isWrite = true
//        sceneDataModel?.isWrite = true
//        setNeedsDisplay()
//    }
//    private func removeCells(_ geometryItems: [GeometryItem], rootCell: Cell,
//                             at index: Int, in parent: Cell,
//                             _ track: MultipleTrack, _ node: CellGroup, time: Beat) {
//        registerUndo {
//            $0.insertCells(geometryItems, rootCell: rootCell, at: index, in: parent, track, node, time: $1)
//        }
//        self.time = time
//        track.removeCells(geometryItems, rootCell: rootCell, in: parent)
//        node.diffDataModel.isWrite = true
//        sceneDataModel?.isWrite = true
//        setNeedsDisplay()
//    }
    
    private struct Stroker {
        static let defaultLineWidth = 1.0.cg
        var line: Line?
        var lineWidth = Stroker.defaultLineWidth, lineColor = Color.strokeLine

        struct Temp {
            var control: Line.Control, speed: Real
        }
        var temps: [Temp] = []
        var oldPoint = Point(), tempDistance = 0.0.cg, oldLastBounds = Rect.null
        var beginTime = Second(0.0), oldTime = Second(0.0), oldTempTime = Second(0.0)

        var join = Join()
        struct Join {
            var lowAngle = 0.8.cg * (.pi / 2), angle = 1.5.cg * (.pi / 2)
            func joinControlWith(_ line: Line, lastControl lc: Line.Control) -> Line.Control? {
                guard line.controls.count >= 4 else {
                    return nil
                }
                let c0 = line.controls[line.controls.count - 4]
                let c1 = line.controls[line.controls.count - 3], c2 = lc
                guard c0.point != c1.point && c1.point != c2.point else {
                    return nil
                }
                let dr = abs(Point.differenceAngle(p0: c0.point, p1: c1.point, p2: c2.point))
                if dr > angle {
                    return c1
                } else if dr > lowAngle {
                    let t = 1 - (dr - lowAngle) / (angle - lowAngle)
                    return Line.Control(point: Point.linear(c1.point, c2.point, t: t),
                                        pressure: Real.linear(c1.pressure, c2.pressure, t: t))
                } else {
                    return nil
                }
            }
        }

        var interval = Interval()
        struct Interval {
            var minSpeed = 100.0.cg, maxSpeed = 1500.0.cg, exp = 2.0.cg
            var minTime = Second(0.1), maxTime = Second(0.03)
            var minDistance = 1.45.cg, maxDistance = 1.5.cg
            func speedTWith(distance: Real, deltaTime: Second, scale: Real) -> Real {
                let speed = ((distance / scale) / deltaTime).clip(min: minSpeed, max: maxSpeed)
                return pow((speed - minSpeed) / (maxSpeed - minSpeed), 1 / exp)
            }
            func isAppendPointWith(distance: Real, deltaTime: Second,
                                   _ temps: [Temp], scale: Real) -> Bool {
                guard deltaTime > 0 else {
                    return false
                }
                let t = speedTWith(distance: distance, deltaTime: deltaTime, scale: scale)
                let time = minTime + (maxTime - minTime) * t
                return deltaTime > time || isAppendPointWith(temps, scale: scale)
            }
            private func isAppendPointWith(_ temps: [Temp], scale: Real) -> Bool {
                let ap = temps.first!.control.point, bp = temps.last!.control.point
                for tc in temps {
                    let speed = tc.speed.clip(min: minSpeed, max: maxSpeed)
                    let t = pow((speed - minSpeed) / (maxSpeed - minSpeed), 1 / exp)
                    let maxD = minDistance + (maxDistance - minDistance) * t
                    if tc.control.point.distanceWithLine(ap: ap, bp: bp) > maxD / scale {
                        return true
                    }
                }
                return false
            }
        }

        var short = Short()
        struct Short {
            var minTime = Second(0.1), linearMaxDistance = 1.5.cg
            func shortedLineWith(_ line: Line, deltaTime: Second, scale: Real) -> Line {
                guard deltaTime < minTime && line.controls.count > 3 else {
                    return line
                }

                var maxD = 0.0.cg, maxControl = line.controls[0]
                line.controls.forEach { control in
                    let d = control.point.distanceWithLine(ap: line.firstPoint, bp: line.lastPoint)
                    if d > maxD {
                        maxD = d
                        maxControl = control
                    }
                }
                let mcp = maxControl.point.nearestWithLine(ap: line.firstPoint, bp: line.lastPoint)
                let cp = 2 * maxControl.point - mcp
                let b = Bezier2(p0: line.firstPoint, cp: cp, p1: line.lastPoint)

                let linearMaxDistance = self.linearMaxDistance / scale
                var isShorted = true
                for p in line.mainPointSequence {
                    let nd = sqrt(b.minDistance²(at: p))
                    if nd > linearMaxDistance {
                        isShorted = false
                    }
                }
                return isShorted ?
                    line :
                    Line(controls: [line.controls[0],
                                    Line.Control(point: cp, pressure: maxControl.pressure),
                                    line.controls[line.controls.count - 1]])
            }
        }
    }
    private var stroker = Stroker()
    func stroke(for p: Point, pressure: Real, time: Second, _ phase: Phase, _ version: Version) {
        stroke(for: p, pressure: pressure, time: time, phase, isAppendLine: true)
    }
    func stroke(for point: Point, pressure: Real, time: Second, _ phase: Phase,
                isAppendLine: Bool) {
        let p = convertToCurrentLocal(point)
        switch phase {
        case .began:
            let fc = Line.Control(point: p, pressure: pressure)
            stroker.line = Line(controls: [fc, fc, fc])
            stroker.oldPoint = p
            stroker.oldTime = time
            stroker.oldTempTime = time
            stroker.tempDistance = 0
            stroker.temps = [Stroker.Temp(control: fc, speed: 0)]
            stroker.beginTime = time
        case .changed:
            guard var line = stroker.line, p != stroker.oldPoint else {
                return
            }
            let d = p.distance(stroker.oldPoint)
            stroker.tempDistance += d

            let pressure = (stroker.temps.first!.control.pressure + pressure) / 2
            let rc = Line.Control(point: line.controls[line.controls.count - 3].point,
                                  pressure: pressure)
            line = line.withReplaced(rc, at: line.controls.count - 3)
            set(line)

            let speed = d / (time - stroker.oldTime)
            stroker.temps.append(Stroker.Temp(control: Line.Control(point: p, pressure: pressure),
                                              speed: speed))
            let lPressure = stroker.temps.reduce(0.0.cg) { $0 + $1.control.pressure }
                / Real(stroker.temps.count)
            let lc = Line.Control(point: p, pressure: lPressure)

            let mlc = lc.mid(stroker.temps[stroker.temps.count - 2].control)
            if let jc = stroker.join.joinControlWith(line, lastControl: mlc) {
                line = line.withInsert(jc, at: line.controls.count - 2)
                set(line, updateBounds: line.strokeLastBoundingBox)
                stroker.temps = [Stroker.Temp(control: lc, speed: speed)]
                stroker.oldTempTime = time
                stroker.tempDistance = 0
            } else if stroker.interval.isAppendPointWith(distance: stroker.tempDistance / viewScale,
                                                         deltaTime: time - stroker.oldTempTime,
                                                         stroker.temps,
                                                         scale: viewScale) {
                line = line.withInsert(lc, at: line.controls.count - 2)
                set(line, updateBounds: line.strokeLastBoundingBox)
                stroker.temps = [Stroker.Temp(control: lc, speed: speed)]
                stroker.oldTempTime = time
                stroker.tempDistance = 0
            }

            line = line.withReplaced(lc, at: line.controls.count - 2)
            line = line.withReplaced(lc, at: line.controls.count - 1)
            set(line, updateBounds: line.strokeLastBoundingBox)

            stroker.oldTime = time
            stroker.oldPoint = p
        case .ended:
            guard var line = stroker.line else {
                return
            }
            if !stroker.interval.isAppendPointWith(distance: stroker.tempDistance / viewScale,
                                                   deltaTime: time - stroker.oldTempTime,
                                                   stroker.temps,
                                                   scale: viewScale) {
                line = line.withRemoveControl(at: line.controls.count - 2)
            }
            line = line.withReplaced(Line.Control(point: p, pressure: line.controls.last!.pressure),
                                     at: line.controls.count - 1)
            line = stroker.short.shortedLineWith(line, deltaTime: time - stroker.beginTime,
                                                 scale: viewScale)
            if isAppendLine {
                addLine(line, in: node.editTrack.drawingItem.drawing, node, time: self.time)
                stroker.line = nil
            } else {
                stroker.line = line
            }
        }
    }
    private func set(_ line: Line) {
        stroker.line = line
        let lastBounds = line.visibleImageBounds(withLineWidth: stroker.lineWidth)
        let ub = lastBounds.union(stroker.oldLastBounds)
        let b = Line.visibleImageBoundsWith(imageBounds: ub, lineWidth: stroker.lineWidth)
        setNeedsDisplay(inCurrentLocalBounds: b)
        stroker.oldLastBounds = lastBounds
    }
    private func set(_ line: Line, updateBounds lastBounds: Rect) {
        stroker.line = line
        let ub = lastBounds.union(stroker.oldLastBounds)
        let b = Line.visibleImageBoundsWith(imageBounds: ub, lineWidth: stroker.lineWidth)
        setNeedsDisplay(inCurrentLocalBounds: b)
        stroker.oldLastBounds = lastBounds
    }

    func lassoErase(for p: Point, pressure: Real, time: Second, _ phase: Phase, _ version: Version) {
        _ = stroke(for: p, pressure: pressure, time: time, phase, isAppendLine: false)
        switch phase {
        case .began:
            break
        case .changed:
            if let line = stroker.line {
                let b = line.visibleImageBounds(withLineWidth: stroker.lineWidth)
                setNeedsDisplay(inCurrentLocalBounds: b)
            }
        case .ended:
            if let line = stroker.line {
                lassoErase(with: line)
                stroker.line = nil
            }
        }
    }
    func lassoErase(with line: Line) {
//        let inNode = cut.currentNode
//        let drawing = inNode.editTrack.drawingItem.drawing, track = inNode.editTrack
//        if let index = drawing.lines.index(of: line) {
//            removeLine(at: index, in: drawing, inNode, time: time)
//        }
//        if !drawing.selectedLineIndexes.isEmpty {
//            setSelectedLineIndexes([], oldLineIndexes: drawing.selectedLineIndexes,
//                                   in: drawing, inNode, time: time)
//        }
//        var isRemoveLineInDrawing = false, isRemoveLineInCell = false
//        let lasso = LineLasso(lines: [line])
//        let newDrawingLines = drawing.lines.reduce(into: [Line]()) {
//            let split = lasso.split(with: $1)
//            if split.isSplited {
//                isRemoveLineInDrawing = true
//                $0 += split.lines
//            } else {
//                $0.append($1)
//            }
//        }
//        if isRemoveLineInDrawing {
//            set(newDrawingLines, old: drawing.lines, in: drawing, inNode, time: time)
//        }
//        var removeGeometryItems = [GeometryItem]()
//        removeGeometryItems = track.geometryItems.filter { geometryItem in
//            if geometryItem.cell.intersects(lasso) {
//                set(Geometry(), old: geometryItem.cell.geometry,
//                    at: track.animation.editKeyframeIndex, in: geometryItem, track, inNode, time: time)
//                if geometryItem.isEmptyKeyGeometries {
//                    return true
//                }
//                isRemoveLineInCell = true
//            }
//            return false
//        }
//        if !isRemoveLineInDrawing && !isRemoveLineInCell {
//            if let hitGeometryItem = inNode.geometryItem(at: line.firstPoint,
//                                                 reciprocalScale: scene.reciprocalScale,
//                                                 with: track) {
//                let lines = hitGeometryItem.cell.geometry.lines
//                set(Geometry(), old: hitGeometryItem.cell.geometry,
//                    at: track.animation.editKeyframeIndex,
//                    in: hitGeometryItem, track, inNode, time: time)
//                if hitGeometryItem.isEmptyKeyGeometries {
//                    removeGeometryItems.append(hitGeometryItem)
//                }
//                set(drawing.lines + lines, old: drawing.lines,
//                    in: drawing, inNode, time: time)
//            }
//        }
//        if !removeGeometryItems.isEmpty {
//            self.removeGeometryItems(removeGeometryItems)
//        }
    }

//    private func addLine(_ line: Line, in drawing: Drawing, _ node: CellGroup, time: Beat) {
//        registerUndo { $0.removeLastLine(in: drawing, node, time: $1) }
//        self.time = time
////        drawing.lines.append(line)
//        node.diffDataModel.isWrite = true
//        setNeedsDisplay()
//    }
//    private func removeLastLine(in drawing: Drawing, _ node: CellGroup, time: Beat) {
//        registerUndo { [lastLine = drawing.lines.last!] in
//            $0.addLine(lastLine, in: drawing, node, time: $1)
//        }
//        self.time = time
////        drawing.lines.removeLast()
//        node.diffDataModel.isWrite = true
//        setNeedsDisplay()
//    }
//    private func insertLine(_ line: Line, at i: Int, in drawing: Drawing, _ node: CellGroup, time: Beat) {
//        registerUndo { $0.removeLine(at: i, in: drawing, node, time: $1) }
//        self.time = time
////        drawing.lines.insert(line, at: i)
//        node.diffDataModel.isWrite = true
//        setNeedsDisplay()
//    }
//    private func removeLine(at i: Int, in drawing: Drawing, _ node: CellGroup, time: Beat) {
//        let oldLine = drawing.lines[i]
//        registerUndo { $0.insertLine(oldLine, at: i, in: drawing, node, time: $1) }
//        self.time = time
////        drawing.lines.remove(at: i)
//        node.diffDataModel.isWrite = true
//        setNeedsDisplay()
//    }
//    private func setSelectedLineIndexes(_ lineIndexes: [Int], oldLineIndexes: [Int],
//                                         in drawing: Drawing, _ node: CellGroup, time: Beat) {
//        registerUndo {
//            $0.setSelectedLineIndexes(oldLineIndexes, oldLineIndexes: lineIndexes,
//                                      in: drawing, node, time: $1)
//        }
//        self.time = time
////        drawing.selectedLineIndexes = lineIndexes
//        node.diffDataModel.isWrite = true
//        setNeedsDisplay()
//    }

//    func selectCell(at point: Point) {
//        let p = convertToCurrentLocal(point)
//        let selectedCell = cut.currentNode.rootCell.at(p, reciprocalScale: scene.reciprocalScale)
//        if let selectedCell = selectedCell {
//            setMaterial(selectedCell.material, time: time)
//        } else {
//            setMaterial(materialView.defaultMaterial, time: time)
//        }
//    }
//    private func setMaterial(_ material: Material, time: Beat) {
//        registerUndo { [om = materialView.material] in $0.setMaterial(om, time: $1) }
//        self.time = time
//        materialView.material = material
//    }
//    private func setSelectedGeometryItems(_ geometryItems: [GeometryItem], oldGeometryItems: [GeometryItem],
//                                       in track: MultipleTrack, time: Beat) {
//        registerUndo {
//            $0.setSelectedGeometryItems(oldGeometryItems, oldGeometryItems: geometryItems, in: track, time: $1)
//        }
//        self.time = time
//        track.selectedGeometryItems = geometryItems
//        setNeedsDisplay()
//        sceneDataModel?.isWrite = true
//        setNeedsDisplay()
//    }

    func insert(_ point: Point) {
//        let p = convertToCurrentLocal(point), inNode = cut.currentNode
//        guard let nearest = inNode.nearestLine(at: p) else {
//            return
//        }
//        if let drawing = nearest.drawing {
//            replaceLine(nearest.line.splited(at: nearest.pointIndex), oldLine: nearest.line,
//                        at: nearest.lineIndex, in: drawing, in: inNode, time: time)
//            cut.updateWithCurrentTime()
//            updateEditView(with: p)
//        } else if let geometryItem = nearest.geometryItem {
//            let newGeometries = Geometry.geometriesWithSplitedControl(with: geometryItem.keyGeometries,
//                                                                      at: nearest.lineIndex,
//                                                                      pointIndex: nearest.pointIndex)
//            setGeometries(newGeometries, oldKeyGeometries: geometryItem.keyGeometries,
//                          in: geometryItem, inNode.editTrack, inNode, time: time)
//            cut.updateWithCurrentTime()
//            updateEditView(with: p)
//        }
    }
    func removeNearestPoint(for point: Point) {
//        let p = convertToCurrentLocal(point), inNode = cut.currentNode
//        guard let nearest = inNode.nearestLine(at: p) else {
//            return
//        }
//        if let drawing = nearest.drawing {
//            if nearest.line.controls.count > 2 {
//                replaceLine(nearest.line.removedControl(at: nearest.pointIndex),
//                            oldLine: nearest.line,
//                            at: nearest.lineIndex, in: drawing, in: inNode, time: time)
//            } else {
//                removeLine(at: nearest.lineIndex, in: drawing, inNode, time: time)
//            }
//            cut.updateWithCurrentTime()
//            updateEditView(with: p)
//        } else if let geometryItem = nearest.geometryItem {
//            setGeometries(Geometry.geometriesWithRemovedControl(with: geometryItem.keyGeometries,
//                                                                atLineIndex: nearest.lineIndex,
//                                                                index: nearest.pointIndex),
//                          oldKeyGeometries: geometryItem.keyGeometries,
//                          in: geometryItem, inNode.editTrack, inNode, time: time)
//            if geometryItem.isEmptyKeyGeometries {
//                removeGeometryItems([geometryItem])
//            }
//            cut.updateWithCurrentTime()
//            updateEditView(with: p)
//        }
    }
//    private func insert(_ control: Line.Control, at index: Int,
//                        in drawing: Drawing, atLineIndex li: Int, _ node: CellGroup, time: Beat) {
//        registerUndo { $0.removeControl(at: index, in: drawing, atLineIndex: li, node, time: $1) }
//        self.time = time
////        drawing.lines[li] = drawing.lines[li].withInsert(control, at: index)
//        node.diffDataModel.isWrite = true
//        setNeedsDisplay()
//    }
//    private func removeControl(at index: Int,
//                               in drawing: Drawing, atLineIndex li: Int, _ node: CellGroup, time: Beat) {
//        let line = drawing.lines[li]
//        registerUndo { [oc = line.controls[index]] in
//            $0.insert(oc, at: index, in: drawing, atLineIndex: li, node, time: $1)
//        }
//        self.time = time
////        drawing.lines[li] = line.withRemoveControl(at: index)
//        node.diffDataModel.isWrite = true
//        setNeedsDisplay()
//    }

//    private var movePointNearest: CellGroup.Nearest?, movePointOldPoint = Point(), movePointIsSnap = false
//    private weak var movePointNode: CellGroup?
//    private let snapPointSnapDistance = 8.0.cg
//    private var bezierSortedResult: CellGroup.Nearest.BezierSortedResult?
    func movePoint(for p: Point, pressure: Real, time: Second, _ phase: Phase, _ version: Version) {
        movePoint(for: p, pressure: pressure, time: time, phase, isVertex: false)
    }
    func moveVertex(for p: Point, pressure: Real, time: Second, _ phase: Phase, _ version: Version) {
        movePoint(for: p, pressure: pressure, time: time, phase, isVertex: true)
    }
    func movePoint(for point: Point, pressure: Real, time: Second, _ phase: Phase,
                   isVertex: Bool) {
//        let p = convertToCurrentLocal(point)
//        switch phase {
//        case .began:
//            if let nearest = cut.currentNode.nearest(at: p, isVertex: isVertex) {
//                bezierSortedResult = nearest.bezierSortedResult(at: p)
//                movePointNearest = nearest
//                movePointNode = cut.currentNode
//                movePointIsSnap = false
//            }
//            updateEditView(with: p)
//            movePointNode = cut.currentNode
//            movePointOldPoint = p
//        case .changed:
//            let dp = p - movePointOldPoint
//            movePointIsSnap = movePointIsSnap ? true : pressure == 1
//
//            if let nearest = movePointNearest {
//                if nearest.drawingEdit != nil || nearest.geometryItemEdit != nil {
//                    movingPoint(with: nearest, dp: dp, in: cut.currentNode.editTrack)
//                } else {
//                    if movePointIsSnap, let b = bezierSortedResult {
//                        movingPoint(with: nearest, bezierSortedResult: b, dp: dp,
//                                    isVertex: isVertex, in: cut.currentNode.editTrack)
//                    } else {
//                        movingLineCap(with: nearest, dp: dp,
//                                      isVertex: isVertex, in: cut.currentNode.editTrack)
//                    }
//                }
//            }
//        case .ended:
//            let dp = p - movePointOldPoint
//            if let nearest = movePointNearest, let node = movePointNode {
//                if nearest.drawingEdit != nil || nearest.geometryItemEdit != nil {
//                    movedPoint(with: nearest, dp: dp, in: node.editTrack, node)
//                } else {
//                    if movePointIsSnap, let b = bezierSortedResult {
//                        movedPoint(with: nearest, bezierSortedResult: b, dp: dp,
//                                   isVertex: isVertex, in: node.editTrack, node)
//                    } else {
//                        movedLineCap(with: nearest, dp: dp,
//                                     isVertex: isVertex, in: node.editTrack, node)
//                    }
//                }
//                movePointNode = nil
//                movePointIsSnap = false
//                movePointNearest = nil
//                bezierSortedResult = nil
//                updateEditView(with: p)
//            }
//        }
//        setNeedsDisplay()
    }
//    private func movingPoint(with nearest: CellGroup.Nearest, dp: Point, in track: MultipleTrack) {
//        let snapD = snapPointSnapDistance / scene.scale
//        if let e = nearest.drawingEdit {
//            var control = e.line.controls[e.pointIndex]
//            control.point = e.line.editPoint(withEditCenterPoint: nearest.point + dp,
//                                             at: e.pointIndex)
//            if movePointIsSnap && (e.pointIndex == 1 || e.pointIndex == e.line.controls.count - 2) {
//                control.point = track.snapPoint(control.point,
//                                                editLine: e.drawing.lines[e.lineIndex],
//                                                editPointIndex: e.pointIndex,
//                                                snapDistance: snapD)
//            }
////            e.drawing.lines[e.lineIndex] = e.line.withReplaced(control, at: e.pointIndex)
//            let np = e.drawing.lines[e.lineIndex].editCenterPoint(at: e.pointIndex)
//            editPoint = CellGroup.EditPoint(nearestLine: e.drawing.lines[e.lineIndex],
//                                       nearestPointIndex: e.pointIndex,
//                                       lines: [e.drawing.lines[e.lineIndex]],
//                                       point: np,
//                                       isSnap: movePointIsSnap)
//        } else if let e = nearest.geometryItemEdit {
//            let line = e.geometry.lines[e.lineIndex]
//            var control = line.controls[e.pointIndex]
//            control.point = line.editPoint(withEditCenterPoint: nearest.point + dp, at: e.pointIndex)
//            if movePointIsSnap && (e.pointIndex == 1 || e.pointIndex == line.controls.count - 2) {
//                control.point = track.snapPoint(control.point,
//                                                editLine: e.geometryItem.cell.geometry.lines[e.lineIndex],
//                                                editPointIndex: e.pointIndex,
//                                                snapDistance: snapD)
//            }
//            let newLine = line.withReplaced(control, at: e.pointIndex).autoPressure()
//
//            let i = cut.currentNode.editTrack.animation.editKeyframeIndex
//            //track.replace
////            e.geometryItem.replace(Geometry(lines: e.geometry.lines.withReplaced(newLine,
////                                                                             at: e.lineIndex)), at: i)
//            track.updateInterpolation()
//
//            let np = e.geometryItem.cell.geometry.lines[e.lineIndex].editCenterPoint(at: e.pointIndex)
//            editPoint = CellGroup.EditPoint(nearestLine: e.geometryItem.cell.geometry.lines[e.lineIndex],
//                                       nearestPointIndex: e.pointIndex,
//                                       lines: [e.geometryItem.cell.geometry.lines[e.lineIndex]],
//                                       point: np, isSnap: movePointIsSnap)
//
//        }
//    }
//    private func movedPoint(with nearest: CellGroup.Nearest, dp: Point,
//                            in track: MultipleTrack, _ node: CellGroup) {
//        let snapD = snapPointSnapDistance / scene.scale
//        if let e = nearest.drawingEdit {
//            var control = e.line.controls[e.pointIndex]
//            control.point = e.line.editPoint(withEditCenterPoint: nearest.point + dp,
//                                             at: e.pointIndex)
//            if movePointIsSnap && (e.pointIndex == 1 || e.pointIndex == e.line.controls.count - 2) {
//                control.point = track.snapPoint(control.point,
//                                                editLine: e.drawing.lines[e.lineIndex],
//                                                editPointIndex: e.pointIndex,
//                                                snapDistance: snapD)
//            }
//            replaceLine(e.line.withReplaced(control, at: e.pointIndex), oldLine: e.line,
//                        at: e.lineIndex, in: e.drawing, in: node, time: time)
//        } else if let e = nearest.geometryItemEdit {
//            let line = e.geometry.lines[e.lineIndex]
//            var control = line.controls[e.pointIndex]
//            control.point = line.editPoint(withEditCenterPoint: nearest.point + dp,
//                                           at: e.pointIndex)
//            if movePointIsSnap && (e.pointIndex == 1 || e.pointIndex == line.controls.count - 2) {
//                control.point = track.snapPoint(control.point,
//                                                editLine: e.geometryItem.cell.geometry.lines[e.lineIndex],
//                                                editPointIndex: e.pointIndex,
//                                                snapDistance: snapD)
//            }
//            let newLine = line.withReplaced(control, at: e.pointIndex).autoPressure()
//            set(Geometry(lines: e.geometry.lines.withReplaced(newLine, at: e.lineIndex)),
//                old: e.geometry,
//                at: track.animation.editKeyframeIndex,
//                in: e.geometryItem, track, node,
//                time: time)
//        }
//    }
//    private func movingPoint(with nearest: CellGroup.Nearest,
//                             bezierSortedResult b: CellGroup.Nearest.BezierSortedResult,
//                             dp: Point, isVertex: Bool, in track: MultipleTrack) {
//        let snapD = snapPointSnapDistance * scene.reciprocalScale
//        let grid = 5 * scene.reciprocalScale
//        var np = track.snapPoint(nearest.point + dp, with: b, snapDistance: snapD, grid: grid)
//        if let e = nearest.drawingEditLineCap, let drawing = b.drawing {
//            var newLines = e.lines
//            if b.lineCap.line.controls.count == 2 {
//                let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
//                var control = b.lineCap.line.controls[pointIndex]
//                control.point = track.snapPoint(np, editLine: drawing.lines[b.lineCap.lineIndex],
//                                                editPointIndex: pointIndex, snapDistance: snapD)
//                newLines[b.lineCap.lineIndex] = b.lineCap.line.withReplaced(control, at: pointIndex)
//                np = control.point
//            } else if isVertex {
//                newLines[b.lineCap.lineIndex] = b.lineCap.line.warpedWith(
//                    deltaPoint: np - nearest.point, isFirst: b.lineCap.isFirst)
//            } else {
//                let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
//                var control = b.lineCap.line.controls[pointIndex]
//                control.point = np
//                newLines[b.lineCap.lineIndex] = newLines[b.lineCap.lineIndex].withReplaced(
//                    control, at: b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1)
//            }
////            drawing.lines = newLines
//            editPoint = CellGroup.EditPoint(nearestLine: drawing.lines[b.lineCap.lineIndex],
//                                       nearestPointIndex: b.lineCap.pointIndex,
//                                       lines: e.drawingCaps.map { drawing.lines[$0.lineIndex] },
//                                       point: np,
//                                       isSnap: movePointIsSnap)
//        } else if let geometryItem = b.geometryItem, let geometry = b.geometry {
//            for editLineCap in nearest.geometryItemEditLineCaps {
//                if editLineCap.geometryItem == geometryItem {
//                    if b.lineCap.line.controls.count == 2 {
//                        let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
//                        var control = b.lineCap.line.controls[pointIndex]
//                        let line = geometryItem.cell.geometry.lines[b.lineCap.lineIndex]
//                        control.point = track.snapPoint(np,
//                                                        editLine: line,
//                                                        editPointIndex: pointIndex,
//                                                        snapDistance: snapD)
//                        let newBLine = b.lineCap.line.withReplaced(control,
//                                                                   at: pointIndex).autoPressure()
//                        let newLines = geometry.lines.withReplaced(newBLine,
//                                                                   at: b.lineCap.lineIndex)
//                        let i = cut.currentNode.editTrack.animation.editKeyframeIndex
////                        track.replace
////                        geometryItem.replace(Geometry(lines: newLines), at: i)
//                        np = control.point
//                    } else if isVertex {
//                        let warpedLine = b.lineCap.line.warpedWith(deltaPoint: np - nearest.point,
//                                                                   isFirst: b.lineCap.isFirst)
//                        let newLine = warpedLine.autoPressure()
//                        let newLines = geometry.lines.withReplaced(newLine, at: b.lineCap.lineIndex)
//                        let i = cut.currentNode.editTrack.animation.editKeyframeIndex
//                        //track.replace
////                        geometryItem.replace(Geometry(lines: newLines), at: i)
//                    } else {
//                        let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
//                        var control = geometry.lines[b.lineCap.lineIndex].controls[pointIndex]
//                        control.point = np
//                        let newLine = b.lineCap.line.withReplaced(control,
//                                                                  at: pointIndex).autoPressure()
//                        let newLines = geometry.lines.withReplaced(newLine, at: b.lineCap.lineIndex)
//
//                        let i = cut.currentNode.editTrack.animation.editKeyframeIndex
////                        track.replace
////                        geometryItem.replace(Geometry(lines: newLines), at: i)
//                    }
//                } else {
//                    editLineCap.geometryItem.cell.geometry = editLineCap.geometry
//                }
//            }
//            track.updateInterpolation()
//
//            let newLines = nearest.geometryItemEditLineCaps.reduce(into: [Line]()) {
//                $0 += $1.caps.map { geometryItem.cell.geometry.lines[$0.lineIndex] }
//            }
//            editPoint = CellGroup.EditPoint(nearestLine: geometryItem.cell.geometry.lines[b.lineCap.lineIndex],
//                                       nearestPointIndex: b.lineCap.pointIndex,
//                                       lines: newLines,
//                                       point: np,
//                                       isSnap: movePointIsSnap)
//        }
//    }
//    private func movedPoint(with nearest: CellGroup.Nearest,
//                            bezierSortedResult b: CellGroup.Nearest.BezierSortedResult,
//                            dp: Point, isVertex: Bool, in track: MultipleTrack, _ node: CellGroup) {
//        let snapD = snapPointSnapDistance * scene.reciprocalScale
//        let grid = 5 * scene.reciprocalScale
//        let np = track.snapPoint(nearest.point + dp, with: b, snapDistance: snapD, grid: grid)
//        if let e = nearest.drawingEditLineCap, let drawing = b.drawing {
//            var newLines = e.lines
//            if b.lineCap.line.controls.count == 2 {
//                let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
//                var control = b.lineCap.line.controls[pointIndex]
//                control.point = track.snapPoint(np,
//                                                editLine: drawing.lines[b.lineCap.lineIndex],
//                                                editPointIndex: pointIndex,
//                                                snapDistance: snapD)
//                newLines[b.lineCap.lineIndex] = b.lineCap.line.withReplaced(control, at: pointIndex)
//            } else if isVertex {
//                let newLine = b.lineCap.line.warpedWith(deltaPoint: np - nearest.point,
//                                                        isFirst: b.lineCap.isFirst)
//                newLines[b.lineCap.lineIndex] = newLine
//            } else {
//                let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
//                var control = b.lineCap.line.controls[pointIndex]
//                control.point = np
//                let newLine = newLines[b.lineCap.lineIndex].withReplaced(control, at: pointIndex)
//                newLines[b.lineCap.lineIndex] = newLine
//            }
//            set(newLines, old: e.lines, in: drawing, node, time: time)
//        } else if let geometryItem = b.geometryItem, let geometry = b.geometry {
//            for editLineCap in nearest.geometryItemEditLineCaps {
//                guard editLineCap.geometryItem == geometryItem else {
//                    editLineCap.geometryItem.cell.geometry = editLineCap.geometry
//                    continue
//                }
//                if b.lineCap.line.controls.count == 2 {
//                    let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
//                    var control = b.lineCap.line.controls[pointIndex]
//                    let editLine = geometryItem.cell.geometry.lines[b.lineCap.lineIndex]
//                    control.point = track.snapPoint(np,
//                                                    editLine: editLine,
//                                                    editPointIndex: pointIndex,
//                                                    snapDistance: snapD)
//                    let newLine = b.lineCap.line.withReplaced(control,
//                                                              at: pointIndex).autoPressure()
//                    let newLines = geometry.lines.withReplaced(newLine, at: b.lineCap.lineIndex)
//                    set(Geometry(lines: newLines),
//                        old: geometry,
//                        at: track.animation.editKeyframeIndex,
//                        in: geometryItem, track, node, time: time)
//                } else if isVertex {
//                    let newLine = b.lineCap.line.warpedWith(deltaPoint: np - nearest.point,
//                                                            isFirst: b.lineCap.isFirst).autoPressure()
//                    let bLines = geometry.lines.withReplaced(newLine, at: b.lineCap.lineIndex)
//                    set(Geometry(lines: bLines),
//                        old: geometry,
//                        at: track.animation.editKeyframeIndex,
//                        in: geometryItem, track, node, time: time)
//                } else {
//                    let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
//                    var control = geometry.lines[b.lineCap.lineIndex].controls[pointIndex]
//                    control.point = np
//                    let newLine = b.lineCap.line.withReplaced(control, at: pointIndex).autoPressure()
//                    let newLines = geometry.lines.withReplaced(newLine, at: b.lineCap.lineIndex)
//                    set(Geometry(lines: newLines),
//                        old: geometry,
//                        at: track.animation.editKeyframeIndex,
//                        in: geometryItem, track, node, time: time)
//                }
//            }
//        }
//        bezierSortedResult = nil
//    }
//    func movingLineCap(with nearest: CellGroup.Nearest, dp: Point,
//                       isVertex: Bool, in track: MultipleTrack) {
//        let np = nearest.point + dp
//        var editPointLines = [Line]()
//        if let e = nearest.drawingEditLineCap {
//            var newLines = e.drawing.lines
//            if isVertex {
//                e.drawingCaps.forEach {
//                    newLines[$0.lineIndex] = $0.line.warpedWith(deltaPoint: dp,
//                                                                isFirst: $0.isFirst)
//                }
//            } else {
//                for cap in e.drawingCaps {
//                    var control = cap.isFirst ?
//                        cap.line.controls[0] : cap.line.controls[cap.line.controls.count - 1]
//                    control.point = np
//                    newLines[cap.lineIndex] = newLines[cap.lineIndex]
//                        .withReplaced(control, at: cap.isFirst ? 0 : cap.line.controls.count - 1)
//                }
//            }
////            e.drawing.lines = newLines
//            editPointLines = e.drawingCaps.map { newLines[$0.lineIndex] }
//        }
//
//        for editLineCap in nearest.geometryItemEditLineCaps {
//            var newLines = editLineCap.geometry.lines
//            if isVertex {
//                for cap in editLineCap.caps {
//                    newLines[cap.lineIndex] = cap.line.warpedWith(deltaPoint: dp,
//                                                                  isFirst: cap.isFirst).autoPressure()
//                }
//            } else {
//                for cap in editLineCap.caps {
//                    var control = cap.isFirst ?
//                        cap.line.controls[0] : cap.line.controls[cap.line.controls.count - 1]
//                    control.point = np
//                    newLines[cap.lineIndex] = newLines[cap.lineIndex]
//                        .withReplaced(control, at: cap.isFirst ?
//                            0 : cap.line.controls.count - 1).autoPressure()
//                }
//            }
//
//            let i = cut.currentNode.editTrack.animation.editKeyframeIndex
//            //track.replace
////            editLineCap.geometryItem.replace(Geometry(lines: newLines), at: i)
//
//            editPointLines += editLineCap.caps.map { newLines[$0.lineIndex] }
//        }
//
//        track.updateInterpolation()
//
//        if let b = bezierSortedResult {
//            if let geometryItem = b.geometryItem {
//                let newLine = geometryItem.cell.geometry.lines[b.lineCap.lineIndex]
//                editPoint = CellGroup.EditPoint(nearestLine: newLine,
//                                           nearestPointIndex: b.lineCap.pointIndex,
//                                           lines: Array(Set(editPointLines)),
//                                           point: np, isSnap: movePointIsSnap)
//            } else if let drawing = b.drawing {
//                let newLine = drawing.lines[b.lineCap.lineIndex]
//                editPoint = CellGroup.EditPoint(nearestLine: newLine,
//                                           nearestPointIndex: b.lineCap.pointIndex,
//                                           lines: Array(Set(editPointLines)),
//                                           point: np, isSnap: movePointIsSnap)
//            }
//        }
//    }
//    func movedLineCap(with nearest: CellGroup.Nearest, dp: Point, isVertex: Bool,
//                      in track: MultipleTrack, _ node: CellGroup) {
//        let np = nearest.point + dp
//        if let e = nearest.drawingEditLineCap {
//            var newLines = e.drawing.lines
//            if isVertex {
//                for cap in e.drawingCaps {
//                    newLines[cap.lineIndex] = cap.line.warpedWith(deltaPoint: dp,
//                                                                  isFirst: cap.isFirst)
//                }
//            } else {
//                for cap in e.drawingCaps {
//                    var control = cap.isFirst ?
//                        cap.line.controls[0] : cap.line.controls[cap.line.controls.count - 1]
//                    control.point = np
//                    newLines[cap.lineIndex] = newLines[cap.lineIndex]
//                        .withReplaced(control, at: cap.isFirst ? 0 : cap.line.controls.count - 1)
//                }
//            }
//            set(newLines, old: e.lines, in: e.drawing, node, time: time)
//        }
//        for editLineCap in nearest.geometryItemEditLineCaps {
//            var newLines = editLineCap.geometry.lines
//            if isVertex {
//                for cap in editLineCap.caps {
//                    newLines[cap.lineIndex] = cap.line.warpedWith(deltaPoint: dp,
//                                                                  isFirst: cap.isFirst).autoPressure()
//                }
//            } else {
//                for cap in editLineCap.caps {
//                    var control = cap.isFirst ?
//                        cap.line.controls[0] : cap.line.controls[cap.line.controls.count - 1]
//                    control.point = np
//                    newLines[cap.lineIndex] = newLines[cap.lineIndex]
//                        .withReplaced(control, at: cap.isFirst ?
//                            0 : cap.line.controls.count - 1).autoPressure()
//                }
//            }
//            set(Geometry(lines: newLines),
//                old: editLineCap.geometry,
//                at: track.animation.editKeyframeIndex,
//                in: editLineCap.geometryItem, track, node, time: time)
//        }
//    }
//
//    private func replaceLine(_ line: Line, oldLine: Line, at i: Int,
//                             in drawing: Drawing, in node: CellGroup, time: Beat) {
//        registerUndo {
//            $0.replaceLine(oldLine, oldLine: line, at: i, in: drawing, in: node, time: $1)
//        }
//        self.time = time
////        drawing.lines[i] = line
//        node.diffDataModel.isWrite = true
//        setNeedsDisplay()
//    }
//
//    func clipCellInSelected() {
//        guard let fromCell = editCell else {
//            return
//        }
//        let node = cut.currentNode
//        let selectedCells = node.allSelectedGeometryItemsWithNoEmptyGeometry.map { $0.cell }
//        if selectedCells.isEmpty {
//            if !node.rootCell.children.contains(fromCell) {
//                let fromParents = node.rootCell.parents(with: fromCell)
//                moveCell(fromCell,
//                         from: fromParents,
//                         to: [(node.rootCell, node.rootCell.children.count)], in: node,
//                         time: time)
//            }
//        } else if !selectedCells.contains(fromCell) {
//            let fromChildrens = fromCell.allCells
//            var newFromParents = node.rootCell.parents(with: fromCell)
//            let newToParents: [(cell: Cell, index: Int)] = selectedCells.compactMap { toCell in
//                for fromChild in fromChildrens {
//                    if fromChild == toCell {
//                        return nil
//                    }
//                }
//                for (i, newFromParent) in newFromParents.enumerated() {
//                    if toCell == newFromParent.cell {
//                        newFromParents.remove(at: i)
//                        return nil
//                    }
//                }
//                return (toCell, toCell.children.count)
//            }
//            if !(newToParents.isEmpty && newFromParents.isEmpty) {
//                moveCell(fromCell, from: newFromParents, to: newToParents, in: node, time: time)
//            }
//        }
//    }
//
//    private var moveZOldPoint = Point()
//    private var moveZCellTuple: (indexes: [Int], parent: Cell, oldChildren: [Cell])?
//    private var moveZMinDeltaIndex = 0, moveZMaxDeltaIndex = 0
//    private weak var moveZOldCell: Cell?, moveZNode: CellGroup?
//    func moveZ(for point: Point, pressure: Real, time: Second, _ phase: Phase, _ version: Version) {
//        let p = convertToCurrentLocal(point)
//        switch phase {
//        case .began:
//            let ict = cut.currentNode.indicatedCellsTuple(with: p, reciprocalScale: scene.reciprocalScale)
//            guard !ict.geometryItems.isEmpty else {
//                return
//            }
//            switch ict.type {
//            case .none:
//                break
//            case .indicated:
//                let cell = ict.geometryItems.first!.cell
//                cut.currentNode.rootCell.depthFirstSearch(duplicate: false) { parent, aCell in
//                    if cell === aCell, let index = parent.children.index(of: cell) {
//                        moveZCellTuple = ([index], parent, parent.children)
//                        moveZMinDeltaIndex = -index
//                        moveZMaxDeltaIndex = parent.children.count - 1 - index
//                    }
//                }
//            case .selected:
//                let firstCell = ict.geometryItems[0].cell
//                let cutAllSelectedCells
//                    = cut.currentNode.allSelectedGeometryItemsWithNoEmptyGeometry.map { $0.cell }
//                var firstParent: Cell?
//                cut.currentNode.rootCell.depthFirstSearch(duplicate: false) { parent, cell in
//                    if cell === firstCell {
//                        firstParent = parent
//                    }
//                }
//
//                if let firstParent = firstParent {
//                    var indexes = [Int]()
//                    cut.currentNode.rootCell.depthFirstSearch(duplicate: false) { parent, cell in
//                        if cutAllSelectedCells.contains(cell) && firstParent === parent,
//                            let index = parent.children.index(of: cell) {
//
//                            indexes.append(index)
//                        }
//                    }
//                    moveZCellTuple = (indexes, firstParent, firstParent.children)
//                    moveZMinDeltaIndex = -(indexes.min() ?? 0)
//                    moveZMaxDeltaIndex = firstParent.children.count - 1 - (indexes.max() ?? 0)
//                } else {
//                    moveZCellTuple = nil
//                }
//            }
//            moveZNode = cut.currentNode
//            moveZOldPoint = p
//        case .changed:
//            self.editZ?.point = p
//            if let moveZCellTuple = moveZCellTuple, let node = moveZNode {
//                let deltaIndex = Int((p.y - moveZOldPoint.y) / node.editZHeight)
//                var children = moveZCellTuple.oldChildren
//                let indexes = moveZCellTuple.indexes.sorted {
//                    deltaIndex < 0 ? $0 < $1 : $0 > $1
//                }
//                for i in indexes {
//                    let cell = children[i]
//                    children.remove(at: i)
//                    children.insert(cell, at: (i + deltaIndex)
//                        .clip(min: 0, max: moveZCellTuple.oldChildren.count - 1))
//                }
//                moveZCellTuple.parent.children = children
//            }
//        case .ended:
//            if let moveZCellTuple = moveZCellTuple, let node = moveZNode {
//                let deltaIndex = Int((p.y - moveZOldPoint.y) / node.editZHeight)
//                var children = moveZCellTuple.oldChildren
//                let indexes = moveZCellTuple.indexes.sorted {
//                    deltaIndex < 0 ? $0 < $1 : $0 > $1
//                }
//                for i in indexes {
//                    let cell = children[i]
//                    children.remove(at: i)
//                    children.insert(cell, at: (i + deltaIndex)
//                        .clip(min: 0, max: moveZCellTuple.oldChildren.count - 1))
//                }
//                setChildren(children, oldChildren: moveZCellTuple.oldChildren,
//                            inParent: moveZCellTuple.parent, in: node, time: self.time)
//                self.moveZCellTuple = nil
//                moveZNode = nil
//            }
//        }
//        setNeedsDisplay()
//    }
//    private func setChildren(_ children: [Cell], oldChildren: [Cell],
//                             inParent parent: Cell, in node: CellGroup, time: Beat) {
//        registerUndo {
//            $0.setChildren(oldChildren, oldChildren: children, inParent: parent, in: node, time: $1)
//        }
//        self.time = time
//        parent.children = children
//        node.diffDataModel.isWrite = true
//        sceneDataModel?.isWrite = true
//        setNeedsDisplay()
//    }

//    private var moveSelected = CellGroup.Selection()
//    private var transformBounds = Rect.null, moveOldPoint = Point(), moveTransformOldPoint = Point()
    enum TransformEditType {
        case move, warp, transform
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
//    let moveTransformAngleTime = Second(0.1)
//    var moveEditTransform: CellGroup.EditTransform?, moveTransformAngleOldTime = Second(0.0)
//    var moveTransformAnglePoint = Point(), moveTransformAngleOldPoint = Point()
//    var isMoveTransformAngle = false
//    private weak var moveNode: CellGroup?
    func move(for point: Point, pressure: Real, time: Second, _ phase: Phase,
              type: TransformEditType) {
//        let p = convertToCurrentLocal(point)
//        func affineTransform(with node: CellGroup) -> CGAffineTransform {
//            switch type {
//            case .move:
//                return CGAffineTransform(translationX: p.x - moveOldPoint.x, y: p.y - moveOldPoint.y)
//            case .warp:
//                if let editTransform = moveEditTransform {
//                    return node.warpAffineTransform(with: editTransform)
//                } else {
//                    return CGAffineTransform.identity
//                }
//            case .transform:
//                if let editTransform = moveEditTransform {
//                    return node.transformAffineTransform(with: editTransform)
//                } else {
//                    return CGAffineTransform.identity
//                }
//            }
//        }
//        switch phase {
//        case .began:
//            moveSelected = cut.currentNode.selection(with: p, reciprocalScale: scene.reciprocalScale)
//            if type != .move {
//                self.moveEditTransform = editTransform(at: p)
//                editTransform = moveEditTransform
//                self.moveTransformAngleOldTime = time
//                self.moveTransformAngleOldPoint = p
//                self.isMoveTransformAngle = false
//                self.moveTransformOldPoint = p
//
//                if type == .warp {
//                    let mm = minMaxPointFrom(p)
//                    self.minWarpDistance = mm.minDistance
//                    self.maxWarpDistance = mm.maxDistance
//                }
//            }
//            moveNode = cut.currentNode
//            moveOldPoint = p
//        case .changed:
//            if type != .move {
//                if var editTransform = moveEditTransform {
//
//                    func newEditTransform(with lines: [Line]) -> CellGroup.EditTransform {
//                        var ps = [Point]()
//                        for line in lines {
//                            line.allEditPoints({ (p, _) in
//                                ps.append(p)
//                            })
//                            line.allEditPoints { (p, i) in ps.append(p) }
//                        }
//                        let rb = RotatedRect(convexHullPoints: ps.convexHull)
//                        let np = rb.convertToLocal(p: p)
//                        let tx = np.x / rb.size.width, ty = np.y / rb.size.height
//                        if ty < tx {
//                            if ty < 1 - tx {
//                                let ap = editTransform.isCenter ? rb.midXMidYPoint : rb.midXMaxYPoint
//                                return CellGroup.EditTransform(rotatedRect: rb,
//                                                          anchorPoint: ap,
//                                                          point: rb.midXMinYPoint,
//                                                          oldPoint: rb.midXMinYPoint,
//                                                          isCenter: editTransform.isCenter)
//                            } else {
//                                let ap = editTransform.isCenter ? rb.midXMidYPoint : rb.minXMidYPoint
//                                return CellGroup.EditTransform(rotatedRect: rb,
//                                                          anchorPoint: ap,
//                                                          point: rb.maxXMidYPoint,
//                                                          oldPoint: rb.maxXMidYPoint,
//                                                          isCenter: editTransform.isCenter)
//                            }
//                        } else {
//                            if ty < 1 - tx {
//                                let ap = editTransform.isCenter ? rb.midXMidYPoint : rb.maxXMidYPoint
//                                return CellGroup.EditTransform(rotatedRect: rb,
//                                                          anchorPoint: ap,
//                                                          point: rb.minXMidYPoint,
//                                                          oldPoint: rb.minXMidYPoint,
//                                                          isCenter: editTransform.isCenter)
//                            } else {
//                                let ap = editTransform.isCenter ? rb.midXMidYPoint : rb.midXMinYPoint
//                                return CellGroup.EditTransform(rotatedRect: rb,
//                                                          anchorPoint: ap,
//                                                          point: rb.midXMaxYPoint,
//                                                          oldPoint: rb.midXMaxYPoint,
//                                                          isCenter: editTransform.isCenter)
//                            }
//                        }
//                    }
//                    if moveSelected.cellTuples.isEmpty {
//                        if moveSelected.drawingTuple?.lineIndexes.isEmpty ?? true {
//                        } else if let moveDrawingTuple = moveSelected.drawingTuple {
//                            let net = newEditTransform(with: moveDrawingTuple.lineIndexes.map {
//                                moveDrawingTuple.drawing.lines[$0]
//                            })
//                            let ap = editTransform.isCenter ?
//                                net.anchorPoint : editTransform.anchorPoint
//                            editTransform = CellGroup.EditTransform(rotatedRect: net.rotatedRect,
//                                                               anchorPoint: ap,
//                                                               point: editTransform.point,
//                                                               oldPoint: editTransform.oldPoint,
//                                                               isCenter: editTransform.isCenter)
//                        }
//                    } else {
//                        let lines = moveSelected.cellTuples.reduce(into: [Line]()) {
//                            $0 += $1.geometryItem.cell.geometry.lines
//                        }
//                        let net = newEditTransform(with: lines)
//                        let ap = editTransform.isCenter ? net.anchorPoint : editTransform.anchorPoint
//                        editTransform = CellGroup.EditTransform(rotatedRect: net.rotatedRect,
//                                                           anchorPoint: ap,
//                                                           point: editTransform.point,
//                                                           oldPoint: editTransform.oldPoint,
//                                                           isCenter: editTransform.isCenter)
//                    }
//
//                    self.moveEditTransform?.point = p - moveTransformOldPoint + editTransform.oldPoint
//                    self.editTransform = moveEditTransform
//                }
//            }
//            if type == .warp {
//                if let editTransform = moveEditTransform, editTransform.isCenter {
//                    distanceWarp(for: p, pressure: pressure, time: time, phase)
//                    return
//                }
//            }
//            if !moveSelected.isEmpty, let node = moveNode {
//                let affine = affineTransform(with: node)
//                if let mdp = moveSelected.drawingTuple {
//                    var newLines = mdp.oldLines
//                    for index in mdp.lineIndexes {
//                        newLines.remove(at: index)
//                        newLines.insert(mdp.oldLines[index].applying(affine), at: index)
//                    }
////                    mdp.drawing.lines = newLines
//                }
//                for mcp in moveSelected.cellTuples {
//                    //track.replace
////                    mcp.geometryItem.replace(mcp.geometry.applying(affine),
////                                         at: mcp.track.animation.editKeyframeIndex)
//                }
//                cut.updateWithCurrentTime()
//            }
//        case .ended:
//            if type == .warp {
//                if editTransform?.isCenter ?? false {
//                    distanceWarp(for: p, pressure: pressure, time: time, phase)
//                    moveEditTransform = nil
//                    editTransform = nil
//                    return
//                }
//            }
//            if !moveSelected.isEmpty, let node = moveNode {
//                let affine = affineTransform(with: node)
//                if let mdp = moveSelected.drawingTuple {
//                    var newLines = mdp.oldLines
//                    for index in mdp.lineIndexes {
//                        newLines[index] = mdp.oldLines[index].applying(affine)
//                    }
//                    set(newLines, old: mdp.oldLines, in: mdp.drawing, node, time: self.time)
//                }
//                for mcp in moveSelected.cellTuples {
//                    set(mcp.geometry.applying(affine),
//                        old: mcp.geometry,
//                        at: mcp.track.animation.editKeyframeIndex,
//                        in:mcp.geometryItem, mcp.track, node, time: self.time)
//                }
//                cut.updateWithCurrentTime()
//                moveSelected = CellGroup.Selection()
//            }
//            self.moveEditTransform = nil
//            editTransform = nil
//        }
//        setNeedsDisplay()
    }

//    private var minWarpDistance = 0.0.cg, maxWarpDistance = 0.0.cg
//    func distanceWarp(for point: Point, pressure: Real, time: Second, _ phase: Phase, _ version: Version) {
//        let p = convertToCurrentLocal(point)
//        switch phase {
//        case .began:
//            moveSelected = cut.currentNode.selection(with: p, reciprocalScale: scene.reciprocalScale)
//            let mm = minMaxPointFrom(p)
//            moveNode = cut.currentNode
//            moveOldPoint = p
//            minWarpDistance = mm.minDistance
//            maxWarpDistance = mm.maxDistance
//        case .changed:
//            if !moveSelected.isEmpty {
//                let dp = p - moveOldPoint
//                if let wdp = moveSelected.drawingTuple {
//                    var newLines = wdp.oldLines
//                    for i in wdp.lineIndexes {
//                        newLines[i] = wdp.oldLines[i].warpedWith(deltaPoint: dp,
//                                                                 editPoint: moveOldPoint,
//                                                                 minDistance: minWarpDistance,
//                                                                 maxDistance: maxWarpDistance)
//                    }
////                    wdp.drawing.lines = newLines
//                }
//                for wcp in moveSelected.cellTuples {
//                    //track.replace
////                    wcp.geometryItem.replace(wcp.geometry.warpedWith(deltaPoint: dp,
////                                                                 editPoint: moveOldPoint,
////                                                                 minDistance: minWarpDistance,
////                                                                 maxDistance: maxWarpDistance),
////                                         at: wcp.track.animation.editKeyframeIndex)
//                }
//            }
//        case .ended:
//            if !moveSelected.isEmpty, let node = moveNode {
//                let dp = p - moveOldPoint
//                if let wdp = moveSelected.drawingTuple {
//                    var newLines = wdp.oldLines
//                    for i in wdp.lineIndexes {
//                        newLines[i] = wdp.oldLines[i].warpedWith(deltaPoint: dp,
//                                                                 editPoint: moveOldPoint,
//                                                                 minDistance: minWarpDistance,
//                                                                 maxDistance: maxWarpDistance)
//                    }
//                    set(newLines, old: wdp.oldLines, in: wdp.drawing, node, time: self.time)
//                }
//                for wcp in moveSelected.cellTuples {
//                    set(wcp.geometry.warpedWith(deltaPoint: dp, editPoint: moveOldPoint,
//                                                minDistance: minWarpDistance,
//                                                maxDistance: maxWarpDistance),
//                        old: wcp.geometry,
//                        at: wcp.track.animation.editKeyframeIndex,
//                        in: wcp.geometryItem, wcp.track, node, time: self.time)
//                }
//                moveSelected = CellGroup.Selection()
//            }
//        }
//        setNeedsDisplay()
//    }
//    func minMaxPointFrom(_ p: Point
//        ) -> (minDistance: Real, maxDistance: Real, minPoint: Point, maxPoint: Point) {
//
//        var minDistance = Real.infinity, maxDistance = 0.0.cg
//        var minPoint = Point(), maxPoint = Point()
//        func minMaxPointFrom(_ line: Line) {
//            for control in line.controls {
//                let d = hypot²(p.x - control.point.x, p.y - control.point.y)
//                if d < minDistance {
//                    minDistance = d
//                    minPoint = control.point
//                }
//                if d > maxDistance {
//                    maxDistance = d
//                    maxPoint = control.point
//                }
//            }
//        }
//        if let wdp = moveSelected.drawingTuple {
//            for lineIndex in wdp.lineIndexes {
//                minMaxPointFrom(wdp.drawing.lines[lineIndex])
//            }
//        }
//        for wcp in moveSelected.cellTuples {
//            for line in wcp.geometryItem.cell.geometry.lines {
//                minMaxPointFrom(line)
//            }
//        }
//        return (sqrt(minDistance), sqrt(maxDistance), minPoint, maxPoint)
//    }

//    func scroll(for p: Point, time: Second, scrollDeltaPoint: Point,
//                phase: Phase, momentumPhase: Phase?) {
//        viewTransform.translation += scrollDeltaPoint
//        updateEditView(with: convertToCurrentLocal(p))
//    }
    
    var viewTransform: Transform {
        get {
            return canvas.transform
        }
        set {
            canvas.transform = newValue
        }
    }
    var viewScale: Real {
        return canvas.scale
    }

    var minScale = 0.00001.cg, blockScale = 1.0.cg, maxScale = 64.0.cg
    var correctionScale = 1.28.cg, correctionRotation = 1.0.cg / (4.2 * .pi)
    private var isBlockScale = false, oldScale = 0.0.cg
    func zoom(for p: Point, time: Second, magnification: Real, _ phase: Phase, _ version: Version) {
        let scale = viewTransform.scale.x
        switch phase {
        case .began:
            oldScale = scale
            isBlockScale = false
        case .changed:
            if !isBlockScale {
                zoom(at: p) {
                    let newScale = (scale * pow(magnification * correctionScale + 1, 2))
                        .clip(min: minScale, max: maxScale)
                    if blockScale.isOver(old: scale, new: newScale) {
                        isBlockScale = true
                    }
                    viewTransform.scale = Point(x: newScale, y: newScale)
                }
            }
        case .ended:
            if isBlockScale {
                zoom(at: p) {
                    viewTransform.scale = Point(x: blockScale, y: blockScale)
                }
            }
        }
    }
    var blockRotations: [Real] = [-.pi, 0.0, .pi]
    private var isBlockRotation = false, blockRotation = 0.0.cg, oldRotation = 0.0.cg
    func rotate(for p: Point, time: Second, rotationQuantity: Real, _ phase: Phase, _ version: Version) {
        let rotation = viewTransform.rotation
        switch phase {
        case .began:
            oldRotation = rotation
            isBlockRotation = false
        case .changed:
            if !isBlockRotation {
                zoom(at: p) {
                    let oldRotation = rotation
                    let newRotation = rotation + rotationQuantity * correctionRotation
                    for br in blockRotations {
                        if br.isOver(old: oldRotation, new: newRotation) {
                            isBlockRotation = true
                            blockRotation = br
                            break
                        }
                    }
                    viewTransform.rotation = newRotation.clipRotation
                }
            }
        case .ended:
            if isBlockRotation {
                zoom(at: p) {
                    viewTransform.rotation = blockRotation
                }
            }
        }
    }

    func resetView(for p: Point) {
        guard !viewTransform.isIdentity else {
            return
        }
        viewTransform = Transform()
        updateEditView(with: convertToCurrentLocal(p))
    }

    func zoom(at p: Point, closure: () -> ()) {
        let point = convertToCurrentLocal(p)
        closure()
        let newPoint = convertFromCurrentLocal(point)
        viewTransform.translation -= (newPoint - p)
    }
}
extension CanvasView: Queryable {
    static let referenceableType: Referenceable.Type = Canvas.self
}
extension CanvasView: Bindable {
    func bind(for point: Point) {
        //        let p = convertToCurrentLocal(point)
        //        let ict = cut.currentNode.indicatedCellsTuple(with: p, reciprocalScale: scene.reciprocalScale)
        //        if let cell = ict.geometryItems.first?.cell {
        //            bind(cut.currentNode.editTrack.keyMaterial(with: cell), cell, time: time)
        //        } else {
        //            bind(materialView.defaultMaterial, nil, time: time)
        //        }
        //    }
        //    var bindClosure: ((CanvasView, Material, Cell?) -> ())?
        //    func bind(_ material: Material, _ editCell: Cell?, time: Beat) {
        //        registerUndo { [oec = editCell] in $0.bind($0.materialView.material, oec, time: $1) }
        //        self.time = time
        //        materialView.material = material
        //        cellView.cell = editCell ?? Cell()
        //        self.editCell = editCell
        //        updateEditCellBindingLine()
        //        bindClosure?(self, material, editCell)
    }
}
extension CanvasView: Assignable {
    func reset(for point: Point) {
        //        let p = convertToCurrentLocal(point)
        //        if deleteCells(for: p) {
        //            return
        //        }
        //        if deleteSelectedDrawingLines(for: p) {
        //            return
        //        }
        //        if deleteDrawingLines(for: p) {
        //            return
        //        }
    }
    //    func deleteSelectedDrawingLines(for p: Point) -> Bool {
    //        let inNode = cut.currentNode
    //        let drawingItem = inNode.editTrack.drawingItem
    //        guard drawingItem.drawing.isNearestSelectedLineIndexes(at: p) else {
    //            return false
    //        }
    //        let unseletionLines = drawingItem.drawing.uneditLines
    //        setSelectedLineIndexes([], oldLineIndexes: drawingItem.drawing.selectedLineIndexes,
    //                               in: drawingItem.drawing, inNode, time: time)
    //        set(unseletionLines, old: drawingItem.drawing.lines,
    //            in: drawingItem.drawing, inNode, time: time)
    //        return true
    //    }
    //    func deleteDrawingLines(for p: Point) -> Bool {
    //        let inNode = cut.currentNode
    //        let drawingItem = inNode.editTrack.drawingItem
    //        guard !drawingItem.drawing.lines.isEmpty else {
    //            return false
    //        }
    //        setSelectedLineIndexes([], oldLineIndexes: drawingItem.drawing.selectedLineIndexes,
    //                               in: drawingItem.drawing, inNode, time: time)
    //        set([], old: drawingItem.drawing.lines, in: drawingItem.drawing, inNode, time: time)
    //        return true
    //    }
    //    func deleteCells(for point: Point) -> Bool {
    //        let inNode = cut.currentNode
    //        let ict = inNode.indicatedCellsTuple(with: point, reciprocalScale: scene.reciprocalScale)
    //        switch ict.type {
    //        case .selected:
    //            var isChanged = false
    //            for track in inNode.tracks {
    //                let removeSelectedGeometryItems = ict.geometryItems.filter {
    //                    if !$0.cell.geometry.isEmpty {
    //                        set(Geometry(), old: $0.cell.geometry,
    //                            at: track.animation.editKeyframeIndex,
    //                            in: $0, track, inNode, time: time)
    //                        isChanged = true
    //                        if $0.isEmptyKeyGeometries {
    //                            return true
    //                        }
    //                    }
    //                    return false
    //                }
    //                if !removeSelectedGeometryItems.isEmpty {
    //                    removeGeometryItems(removeSelectedGeometryItems)
    //                }
    //            }
    //            if isChanged {
    //                return true
    //            }
    //        case .indicated:
    //            if let geometryItem = inNode.geometryItem(at: point,
    //                                              reciprocalScale: scene.reciprocalScale,
    //                                              with: inNode.editTrack) {
    //                if !geometryItem.cell.geometry.isEmpty {
    //                    set(Geometry(), old: geometryItem.cell.geometry,
    //                        at: inNode.editTrack.animation.editKeyframeIndex,
    //                        in: geometryItem, inNode.editTrack, inNode, time: time)
    //                    if geometryItem.isEmptyKeyGeometries {
    //                        removeGeometryItems([geometryItem])
    //                    }
    //                    return true
    //                }
    //            }
    //        case .none:
    //            break
    //        }
    //        return false
    //    }
    //
    func copiedObjects(at point: Point) -> [Viewable] {
        //        let p = convertToCurrentLocal(point)
        //        let ict = cut.currentNode.indicatedCellsTuple(with: p, reciprocalScale: scene.reciprocalScale)
        //        switch ict.type {
        //        case .none:
        //            let copySelectedLines = cut.currentNode.editTrack.drawingItem.drawing.editLines
        //            if !copySelectedLines.isEmpty {
        //                let drawing = Drawing(lines: copySelectedLines)
        //                return [drawing.copied]
        //            }
        //        case .indicated, .selected:
        //            if !ict.selectedLineIndexes.isEmpty {
        //                let copySelectedLines = cut.currentNode.editTrack.drawingItem.drawing.editLines
        //                let drawing = Drawing(lines: copySelectedLines)
        //                return [drawing.copied]
        //            } else {
        //                let cell = cut.currentNode.rootCell.intersection(ict.geometryItems.map { $0.cell },
        //                                                              isNewID: false)
        //                let material = ict.geometryItems[0].cell.material
        //                return [JoiningCell(cell), material]
        //            }
        //        }
        //        return []
    }
    //    func copiedCells() -> [Cell] {
    //        guard let editCell = editCell else {
    //            return []
    //        }
    //        let cells = cut.currentNode.selectedCells(with: editCell)
    //        let cell = cut.currentNode.rootCell.intersection(cells, isNewID: true)
    //        return [cell]
    //    }
    func paste(_ objects: [Any], for point: Point) {
        //        for object in objects {
        //            if let color = object as? Color, paste(color, for: point) {
        //                return
        //            } else if let material = object as? Material, paste(material, for: point) {
        //                return
        //            } else if let drawing = object as? Drawing, paste(drawing, for: point) {
        //                return
        //            } else if let lines = object as? [Line], paste(lines, for: point) {
        //                return
        //            } else if !cut.currentNode.editTrack.animation.isInterpolated {
        //                if let joiningCell = object as? JoiningCell, paste(joiningCell.copied, for: point) {
        //                    return
        //                } else if let rootCell = object as? Cell, paste(rootCell.copied, for: point) {
        //                    return
        //                }
        //            }
        //        }
    }
    //    var pasteColorBinding: ((CanvasView, Color, [Cell]) -> ())?
    //    func paste(_ color: Color, for point: Point) -> Bool {
    //        let p = convertToCurrentLocal(point)
    //        let ict = cut.currentNode.indicatedCellsTuple(with: p, reciprocalScale: scene.reciprocalScale)
    //        guard !ict.geometryItems.isEmpty else {
    //            return false
    //        }
    //        var isPaste = false
    //        for geometryItem in ict.geometryItems {
    //            if color != geometryItem.cell.material.color {
    //                isPaste = true
    //                break
    //            }
    //        }
    //        if isPaste {
    //            pasteColorBinding?(self, color, ict.geometryItems.map { $0.cell })
    //        }
    //        return true
    //    }
    //    var pasteMaterialBinding: ((CanvasView, Material, [Cell]) -> ())?
    //    func paste(_ material: Material, for point: Point) -> Bool {
    //        let p = convertToCurrentLocal(point)
    //        let ict = cut.currentNode.indicatedCellsTuple(with: p, reciprocalScale: scene.reciprocalScale)
    //        guard !ict.geometryItems.isEmpty else {
    //            return false
    //        }
    //        pasteMaterialBinding?(self, material, ict.geometryItems.map { $0.cell })
    //        return true
    //    }
    //    func paste(_ copyJoiningCell: JoiningCell, for point: Point) -> Bool {
    //        let inNode = cut.currentNode
    //        let isEmptyCellsInEditTrack: Bool = {
    //            for copyCell in copyJoiningCell.cell.allCells {
    //                for geometryItem in inNode.editTrack.geometryItems {
    //                    if geometryItem.cell.id == copyCell.id {
    //                        return false
    //                    }
    //                }
    //            }
    //            return true
    //        } ()
    //        if isEmptyCellsInEditTrack {
    //            return paste(copyJoiningCell, in: inNode.editTrack, inNode, for: point)
    //        } else {
    //            var isChanged = false
    //            for copyCell in copyJoiningCell.cell.allCells {
    //                for track in inNode.tracks {
    //                    for ci in track.geometryItems {
    //                        if ci.cell.id == copyCell.id {
    //                            set(copyCell.geometry, old: ci.cell.geometry,
    //                                at: track.animation.editKeyframeIndex,
    //                                in: ci, track, inNode, time: time)
    //                            isChanged = true
    //                        }
    //                    }
    //                }
    //            }
    //            return isChanged
    //        }
    //    }
    //    func paste(_ copyJoiningCell: JoiningCell, in track: MultipleTrack, _ node: CellGroup,
    //               for point: Point) -> Bool {
    //        node.tracks.forEach { fromTrack in
    //            guard fromTrack != track else {
    //                return
    //            }
    //            let geometryItems: [GeometryItem] = fromTrack.geometryItems.compactMap { geometryItem in
    //                for copyCell in copyJoiningCell.cell.allCells {
    //                    if geometryItem.cell.id == copyCell.id {
    //                        let newKeyGeometries = track.alignedKeyGeometries(geometryItem.keyGeometries)
    //                        move(geometryItem, keyGeometries: newKeyGeometries,
    //                             oldKeyGeometries: geometryItem.keyGeometries,
    //                             from: fromTrack, to: track, in: node, time: time)
    //                        return geometryItem
    //                    }
    //                }
    //                return nil
    //            }
    //            if !fromTrack.selectedGeometryItems.isEmpty && !geometryItems.isEmpty {
    //                let selectedGeometryItems = Array(Set(fromTrack.selectedGeometryItems).subtracting(geometryItems))
    //                if selectedGeometryItems != fromTrack.selectedGeometryItems {
    //                    setSelectedGeometryItems(selectedGeometryItems,
    //                                         oldGeometryItems: fromTrack.selectedGeometryItems,
    //                                         in: fromTrack, time: time)
    //                }
    //            }
    //        }
    //
    //        for copyCell in copyJoiningCell.cell.allCells {
    //            guard let (fromTrack, geometryItem) = node.trackAndGeometryItem(withGeometryItemID: copyCell.id) else {
    //                continue
    //            }
    //            let newKeyGeometries = track.alignedKeyGeometries(geometryItem.keyGeometries)
    //            move(geometryItem, keyGeometries: newKeyGeometries, oldKeyGeometries: geometryItem.keyGeometries,
    //                 from: fromTrack, to: track, in: node, time: time)
    //        }
    //        return true
    //    }
    //    func move(_ geometryItem: GeometryItem, keyGeometries: [Geometry], oldKeyGeometries: [Geometry],
    //              from fromTrack: MultipleTrack, to toTrack: MultipleTrack, in node: CellGroup, time: Beat) {
    //        registerUndo {
    //            $0.move(geometryItem, keyGeometries: oldKeyGeometries, oldKeyGeometries: keyGeometries,
    //                    from: toTrack, to: fromTrack, in: node, time: $1)
    //        }
    //        self.time = time
    //        toTrack.move(geometryItem, keyGeometries: keyGeometries, from: fromTrack)
    //        if node.editTrack == fromTrack {
    //            geometryItem.cell.isLocked = true
    //        }
    //        if node.editTrack == toTrack {
    //            geometryItem.cell.isLocked = false
    //        }
    //        node.diffDataModel.isWrite = true
    //        sceneDataModel?.isWrite = true
    //        setNeedsDisplay()
    //    }
    //    func paste(_ copyRootCell: Cell, for point: Point) -> Bool {
    //        let inNode = cut.currentNode
    //        let lki = inNode.editTrack.animation.loopedKeyframeIndex(withTime: cut.currentTime)
    //        var newGeometryItems = [GeometryItem]()
    //        copyRootCell.depthFirstSearch(duplicate: false) { parent, cell in
    //            cell.id = UUID()
    //            let emptyKeyGeometries = inNode.editTrack.emptyKeyGeometries
    //            let keyGeometrys = emptyKeyGeometries.withReplaced(cell.geometry,
    //                                                               at: lki.keyframeIndex)
    //            newGeometryItems.append(GeometryItem(cell: cell, keyGeometries: keyGeometrys))
    //        }
    //        let index = cellIndex(withTrackIndex: inNode.editTrackIndex, in: cut.currentNode.rootCell)
    //        insertCells(newGeometryItems, rootCell: copyRootCell,
    //                    at: index, in: inNode.rootCell, inNode.editTrack, inNode, time: time)
    //        setSelectedGeometryItems(inNode.editTrack.selectedGeometryItems + newGeometryItems,
    //                              oldGeometryItems: inNode.editTrack.selectedGeometryItems,
    //                              in: inNode.editTrack, time: time)
    //        return true
    //    }
    //    func paste(_ copyDrawing: Drawing, for point: Point) -> Bool {
    //        return paste(copyDrawing.lines, for: point)
    //    }
    //    func paste(_ copyLines: [Line], for point: Point) -> Bool {
    //        let p = convertToCurrentLocal(point)
    //        let inNode = cut.currentNode
    //        let ict = inNode.indicatedCellsTuple(with : p, reciprocalScale: scene.reciprocalScale)
    //        if !inNode.editTrack.animation.isInterpolated && ict.type != .none,
    //            let cell = inNode.rootCell.at(p),
    //            let geometryItem = inNode.editTrack.geometryItem(with: cell) {
    //
    //            let nearestPathLineIndex = geometryItem.cell.geometry.nearestPathLineIndex(at: p)
    //            let previousLine = geometryItem.cell.geometry.lines[nearestPathLineIndex]
    //            let nextLineIndex = nearestPathLineIndex + 1 >=
    //                geometryItem.cell.geometry.lines.count ? 0 : nearestPathLineIndex + 1
    //            let nextLine = geometryItem.cell.geometry.lines[nextLineIndex]
    //            let unionSegmentLine = Line(controls: [Line.Control(point: nextLine.firstPoint,
    //                                                                pressure: 1),
    //                                                   Line.Control(point: previousLine.lastPoint,
    //                                                                pressure: 1)])
    //            let geometry = Geometry(lines: [unionSegmentLine] + copyLines,
    //                                    scale: scene.scale)
    //            let lines = geometry.lines.withRemovedFirst()
    //            let geometris = Geometry.geometriesWithInserLines(with: geometryItem.keyGeometries,
    //                                                              lines: lines,
    //                                                              atLinePathIndex: nearestPathLineIndex)
    //            setGeometries(geometris,
    //                          oldKeyGeometries: geometryItem.keyGeometries,
    //                          in: geometryItem, inNode.editTrack, inNode, time: time)
    //        } else {
    //            let drawing = inNode.editTrack.drawingItem.drawing
    //            let oldCount = drawing.lines.count
    //            let lineIndexes = (0..<copyLines.count).map { $0 + oldCount }
    //            set(drawing.lines + copyLines,
    //                     old: drawing.lines, in: drawing, inNode, time: time)
    //            setSelectedLineIndexes(drawing.selectedLineIndexes + lineIndexes,
    //                                    oldLineIndexes: drawing.selectedLineIndexes,
    //                                    in: drawing, inNode, time: time)
    //        }
    //        return true
    //    }
    
    //    private func removeGeometryItems(_ geometryItems: [GeometryItem]) {
    //        let inNode = cut.currentNode
    //        var geometryItems = geometryItems
    //        while !geometryItems.isEmpty {
    //            let cellRemoveManager = inNode.cellRemoveManager(with: geometryItems[0])
    //            for trackAndGeometryItems in cellRemoveManager.trackAndGeometryItems {
    //                let track = trackAndGeometryItems.track, geometryItems = trackAndGeometryItems.geometryItems
    //                let removeSelectedGeometryItems
    //                    = Array(Set(track.selectedGeometryItems).subtracting(geometryItems))
    //                if removeSelectedGeometryItems.count != track.selectedGeometryItems.count {
    //                    setSelectedGeometryItems(removeSelectedGeometryItems,
    //                                          oldGeometryItems: track.selectedGeometryItems,
    //                                          in: track, time: time)
    //                }
    //            }
    //            removeCell(with: cellRemoveManager, in: inNode, time: time)
    //            geometryItems = geometryItems.filter { !cellRemoveManager.contains($0) }
    //        }
    //    }
    //    private func insertCell(with cellRemoveManager: CellGroup.CellRemoveManager,
    //                            in node: CellGroup, time: Beat) {
    //        registerUndo { $0.removeCell(with: cellRemoveManager, in: node, time: $1) }
    //        self.time = time
    //        node.insertCell(with: cellRemoveManager)
    //        node.diffDataModel.isWrite = true
    //        sceneDataModel?.isWrite = true
    //        setNeedsDisplay()
    //    }
    //    private func removeCell(with cellRemoveManager: CellGroup.CellRemoveManager,
    //                            in node: CellGroup, time: Beat) {
    //        registerUndo { $0.insertCell(with: cellRemoveManager, in: node, time: $1) }
    //        self.time = time
    //        node.removeCell(with: cellRemoveManager)
    //        node.diffDataModel.isWrite = true
    //        sceneDataModel?.isWrite = true
    //        setNeedsDisplay()
    //    }
    //
    //    private func setGeometries(_ keyGeometries: [Geometry], oldKeyGeometries: [Geometry],
    //                               in geometryItem: GeometryItem, _ track: MultipleTrack, _ node: CellGroup, time: Beat) {
    //        registerUndo {
    //            $0.setGeometries(oldKeyGeometries, oldKeyGeometries: keyGeometries,
    //                             in: geometryItem, track, node, time: $1)
    //        }
    //        self.time = time
    //        track.set(keyGeometries, in: geometryItem)
    //        node.diffDataModel.isWrite = true
    //        setNeedsDisplay()
    //    }
    //    private func set(_ geometry: Geometry, old oldGeometry: Geometry,
    //                     at i: Int, in geometryItem: GeometryItem, _ track: MultipleTrack, _ node: CellGroup, time: Beat) {
    //        registerUndo { $0.set(oldGeometry, old: geometry, at: i, in: geometryItem, track, node, time: $1) }
    //        self.time = time
    //        //        track.replace(geometry, at: i)
    //        track.updateInterpolation()
    //        node.diffDataModel.isWrite = true
    //        setNeedsDisplay()
    //    }
}
extension CanvasView: Newable {
    func new(for p: Point) {
        //        let inNode = cut.currentNode
        //        let track = inNode.editTrack
        //        let drawingItem = track.drawingItem, rootCell = inNode.rootCell
        //        let geometry = Geometry(lines: drawingItem.drawing.editLines, scale: scene.scale)
        //        guard !geometry.isEmpty else {
        //            return
        //        }
        //        let isDrawingSelectedLines = !drawingItem.drawing.selectedLineIndexes.isEmpty
        //        let unselectedLines = drawingItem.drawing.uneditLines
        //        if isDrawingSelectedLines {
        //            setSelectedLineIndexes([], oldLineIndexes: drawingItem.drawing.selectedLineIndexes,
        //                                    in: drawingItem.drawing, inNode, time: time)
        //        }
        //        set(unselectedLines, old: drawingItem.drawing.lines,
        //            in: drawingItem.drawing, inNode, time: time)
        //        let lki = track.animation.loopedKeyframeIndex(withTime: cut.currentTime)
        //        let keyGeometries = track.emptyKeyGeometries.withReplaced(geometry, at: lki.keyframeIndex)
        //
        //        let newMaterial = Material(color: Color.random())
        //        let newGeometryItem = GeometryItem(cell: Cell(geometry: geometry, material: newMaterial),
        //                                   keyGeometries: keyGeometries)
        //
        //        let ict = inNode.indicatedCellsTuple(with: convertToCurrentLocal(p),
        //                                             reciprocalScale: scene.reciprocalScale)
        //        if ict.type == .selected {
        //            let newGeometryItems = ict.geometryItems.map {
        //                ($0.cell, addCellIndex(with: newGeometryItem.cell, in: $0.cell))
        //            }
        //            insertCell(newGeometryItem, in: newGeometryItems, inNode.editTrack, inNode, time: time)
        //        } else {
        //            let newGeometryItems = [(rootCell, addCellIndex(with: newGeometryItem.cell, in: rootCell))]
        //            insertCell(newGeometryItem, in: newGeometryItems, inNode.editTrack, inNode, time: time)
        //        }
    }
}
