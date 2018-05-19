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
        ctx.concatenate(screenTransform)
        cut.draw(model: model, viewType: viewType, in: ctx)
        if viewType != .preview {
            drawEdit
            ctx.restoreGState()
            cut.drawCautionBorder(model: model, bounds: bounds, in: ctx)
        } else {
            ctx.restoreGState()
        }
    }
    func draw(viewType: ViewQuasimode, in ctx: CGContext) {
        if viewType == .preview {
            ctx.saveGState()
            rootCellGroup.draw(model: self, viewType: viewType,
                               scale: 1, rotation: 0,
                               viewScale: 1, viewRotation: 0,
                               in: ctx)
            if !isHiddenSubtitles {
                subtitleTrack.drawSubtitle.draw(bounds: model.frame, in: ctx)
            }
            ctx.restoreGState()
        } else {
            ctx.saveGState()
            ctx.concatenate(viewTransform.affineTransform)
            rootNode.draw(model: self, viewType: viewType,
                          scale: 1, rotation: 0,
                          viewScale: scale, viewRotation: viewTransform.rotation,
                          in: ctx)
            ctx.restoreGState()
        }
    }
    
    func drawCautionBorder(bounds: Rect, in ctx: CGContext) {
        func drawBorderWith(bounds: Rect, width: Real, color: Color, in ctx: CGContext) {
            ctx.setFillColor(color.cg)
            ctx.fill([Rect(x: bounds.minX, y: bounds.minY,
                           width: width, height: bounds.height),
                      Rect(x: bounds.minX + width, y: bounds.minY,
                           width: bounds.width - width * 2, height: width),
                      Rect(x: bounds.minX + width, y: bounds.maxY - width,
                           width: bounds.width - width * 2, height: width),
                      Rect(x: bounds.maxX - width, y: bounds.minY,
                           width: width, height: bounds.height)])
        }
        if transform.rotation > .pi / 2 || transform.rotation < -.pi / 2 {
            let borderWidth = 2.0.cg
            drawBorderWith(bounds: bounds, width: borderWidth * 2, color: .warning, in: ctx)
            let textFrame = TextFrame(string: "\(Int(transform.rotation * 180 / (.pi)))°",
                textMaterial: TextMaterial(font: .bold, color: .warning))
            let sb = textFrame.typographicBounds.insetBy(dx: -10, dy: -2).integral
            textFrame.draw(in: Rect(x: bounds.minX + (bounds.width - sb.width) / 2,
                                    y: bounds.minY + bounds.height - sb.height - borderWidth,
                                    width: sb.width, height: sb.height), in: ctx)
        }
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
                setNeedsDisplay()
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
    func setNeedsDisplay() {
        displayLinkDraw()
    }
    func setNeedsDisplay(inCurrentLocalBounds rect: Rect) {
        displayLinkDraw(convertFromCurrentLocal(rect))
    }
    
    private func addCellIndex(with cell: Cell, in parent: Cell) -> Int {
        let editCells = cut.currentNode.editTrack.cells
        for i in (0..<parent.children.count).reversed() {
            if editCells.contains(parent.children[i]) && parent.children[i].contains(cell) {
                return i + 1
            }
        }
        for i in 0..<parent.children.count {
            if editCells.contains(parent.children[i]) && parent.children[i].intersects(cell) {
                return i
            }
        }
        for i in 0..<parent.children.count {
            if editCells.contains(parent.children[i]) && !parent.children[i].isLocked {
                return i
            }
        }
        return cellIndex(withTrackIndex: cut.currentNode.editTrackIndex, in: parent)
    }
    
    func cellIndex(withTrackIndex trackIndex: Int, in parent: Cell) -> Int {
        for i in trackIndex + 1..<cut.currentNode.tracks.count {
            let track = cut.currentNode.tracks[i]
            var maxIndex = 0, isMax = false
            for geometryItem in track.geometryItems {
                if let j = parent.children.index(of: geometryItem.cell) {
                    isMax = true
                    maxIndex = max(maxIndex, j)
                }
            }
            if isMax {
                return maxIndex + 1
            }
        }
        return 0
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
        updateEditView(with: convertToCurrentLocal(p))
    }
    
    func zoom(at p: Point, closure: () -> ()) {
        let point = convertToCurrentLocal(p)
        closure()
        let newPoint = convertFromCurrentLocal(point)
        viewTransform.translation -= (newPoint - p)
    }
}
extension CanvasView: Selectable {
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
        func unionWithStrokeLine(with drawing: Drawing,
                                 _ track: MultipleTrack) -> (lineIndexes: [Int], geometryItems: [GeometryItem]) {
            func selected() -> (lineIndexes: [Int], geometryItems: [GeometryItem]) {
                let transform = currentTransform.inverted()
                let lines = [Line].rectangle(rect).map { $0.applying(transform) }
                let lasso = LineLasso(lines: lines)
                return (drawing.lines.enumerated().compactMap { lasso.intersects($1) ? $0 : nil },
                        track.geometryItems.filter { $0.cell.intersects(lasso) })
            }
            let s = selected()
            if isDeselect {
                return (Array(Set(selectOption.selectedLineIndexes).subtracting(Set(s.lineIndexes))),
                        Array(Set(selectOption.selectedGeometryItems).subtracting(Set(s.geometryItems))))
            } else {
                return (Array(Set(selectOption.selectedLineIndexes).union(Set(s.lineIndexes))),
                        Array(Set(selectOption.selectedGeometryItems).union(Set(s.geometryItems))))
            }
        }
        
        switch phase {
        case .began:
            selectOption.node = cut.currentNode
            let drawing = cut.currentNode.editTrack.drawingItem.drawing, track = cut.currentNode.editTrack
            selectOption.drawing = drawing
            selectOption.track = track
            selectOption.selectedLineIndexes = drawing.selectedLineIndexes
            selectOption.selectedGeometryItems = track.selectedGeometryItems
        case .changed:
            guard let drawing = selectOption.drawing, let track = selectOption.track else { return }
            (drawing.selectedLineIndexes, track.selectedGeometryItems)
                = unionWithStrokeLine(with: drawing, track)
        case .ended:
            guard let drawing = selectOption.drawing,
                let track = selectOption.track, let node = selectOption.node else { return }
            let (selectedLineIndexes, selectedGeometryItems)
                = unionWithStrokeLine(with: drawing, track)
            if selectedLineIndexes != selectOption.selectedLineIndexes {
                setSelectedLineIndexes(selectedLineIndexes,
                                       oldLineIndexes: selectOption.selectedLineIndexes,
                                       in: drawing, node, time: time)
            }
            if selectedGeometryItems != selectOption.selectedGeometryItems {
                setSelectedGeometryItems(selectedGeometryItems,//sort
                    oldGeometryItems: selectOption.selectedGeometryItems,
                    in: track, time: time)
            }
            selectOption = SelectOption()
        }
        setNeedsDisplay()
    }
    func selectAll(isDeselect: Bool) {
        let inNode = cut.currentNode
        let track = inNode.editTrack
        let drawing = track.drawingItem.drawing
        let lineIndexes = isDeselect ? [] : Array(0..<drawing.lines.count)
        if Set(lineIndexes) != Set(drawing.selectedLineIndexes) {
            setSelectedLineIndexes(lineIndexes, oldLineIndexes: drawing.selectedLineIndexes,
                                   in: drawing, inNode, time: time)
        }
        let geometryItems = isDeselect ? [] : track.geometryItems
        if Set(geometryItems) != Set(track.selectedGeometryItems) {
            setSelectedGeometryItems(geometryItems, oldGeometryItems: track.selectedGeometryItems,
                                     in: track, time: time)
        }
    }
    
}
extension CanvasView: Zoomable {
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
}
extension CanvasView: Rotatable {
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
}
extension CanvasView: Queryable {
    static var referenceableType: Referenceable.Type {
        return Model.self
    }
}
extension CanvasView: Assignable {
    func reset(for point: Point) {
        let p = convertToCurrentLocal(point)
        if deleteCells(for: p) { return }
        if deleteSelectedDrawingLines(for: p) { return }
        if deleteDrawingLines(for: p) { return }
    }
    func deleteSelectedDrawingLines(for p: Point) -> Bool {
        let inNode = cut.currentNode
        let drawingItem = inNode.editTrack.drawingItem
        guard drawingItem.drawing.isNearestSelectedLineIndexes(at: p) else {
            return false
        }
        let unseletionLines = drawingItem.drawing.uneditLines
        setSelectedLineIndexes([], oldLineIndexes: drawingItem.drawing.selectedLineIndexes,
                               in: drawingItem.drawing, inNode, time: time)
        set(unseletionLines, old: drawingItem.drawing.lines,
            in: drawingItem.drawing, inNode, time: time)
        return true
    }
    func deleteDrawingLines(for p: Point) -> Bool {
        let inNode = cut.currentNode
        let drawingItem = inNode.editTrack.drawingItem
        guard !drawingItem.drawing.lines.isEmpty else {
            return false
        }
        setSelectedLineIndexes([], oldLineIndexes: drawingItem.drawing.selectedLineIndexes,
                               in: drawingItem.drawing, inNode, time: time)
        set([], old: drawingItem.drawing.lines, in: drawingItem.drawing, inNode, time: time)
        return true
    }
    func deleteCells(for point: Point) -> Bool {
        let inNode = cut.currentNode
        let ict = inNode.indicatedCellsTuple(with: point, reciprocalScale: model.reciprocalScale)
        switch ict.type {
        case .selected:
            var isChanged = false
            for track in inNode.tracks {
                let removeSelectedGeometryItems = ict.geometryItems.filter {
                    if !$0.cell.geometry.isEmpty {
                        set(Geometry(), old: $0.cell.geometry,
                            at: track.animation.editKeyframeIndex,
                            in: $0, track, inNode, time: time)
                        isChanged = true
                        if $0.isEmptyKeyGeometries {
                            return true
                        }
                    }
                    return false
                }
                if !removeSelectedGeometryItems.isEmpty {
                    removeGeometryItems(removeSelectedGeometryItems)
                }
            }
            if isChanged {
                return true
            }
        case .indicated:
            if let geometryItem = inNode.geometryItem(at: point,
                                                      reciprocalScale: model.reciprocalScale,
                                                      with: inNode.editTrack) {
                if !geometryItem.cell.geometry.isEmpty {
                    set(Geometry(), old: geometryItem.cell.geometry,
                        at: inNode.editTrack.animation.editKeyframeIndex,
                        in: geometryItem, inNode.editTrack, inNode, time: time)
                    if geometryItem.isEmptyKeyGeometries {
                        removeGeometryItems([geometryItem])
                    }
                    return true
                }
            }
        case .none:
            break
        }
        return false
    }
    
    func copiedObjects(at point: Point) -> [Viewable] {
        let p = convertToCurrentLocal(point)
        let ict = cut.currentNode.indicatedCellsTuple(with: p, reciprocalScale: model.reciprocalScale)
        switch ict.type {
        case .none:
            let copySelectedLines = cut.currentNode.editTrack.drawingItem.drawing.editLines
            if !copySelectedLines.isEmpty {
                let drawing = Drawing(lines: copySelectedLines)
                return [drawing.copied]
            }
        case .indicated, .selected:
            if !ict.selectedLineIndexes.isEmpty {
                let copySelectedLines = cut.currentNode.editTrack.drawingItem.drawing.editLines
                let drawing = Drawing(lines: copySelectedLines)
                return [drawing.copied]
            } else {
                let cell = cut.currentNode.rootCell.intersection(ict.geometryItems.map { $0.cell },
                                                                 isNewID: false)
                let material = ict.geometryItems[0].cell.material
                return [JoiningCell(cell), material]
            }
        }
        return []
    }
    func copiedCells() -> [Cell] {
        guard let editCell = editCell else {
            return []
        }
        let cells = cut.currentNode.selectedCells(with: editCell)
        let cell = cut.currentNode.rootCell.intersection(cells, isNewID: true)
        return [cell]
    }
    func paste(_ objects: [Any], for point: Point) {
        for object in objects {
            if let color = object as? Color, paste(color, for: point) {
                return
            } else if let material = object as? Material, paste(material, for: point) {
                return
            } else if let drawing = object as? Drawing, paste(drawing, for: point) {
                return
            } else if let lines = object as? [Line], paste(lines, for: point) {
                return
            } else if !cut.currentNode.editTrack.animation.isInterpolated {
                if let joiningCell = object as? JoiningCell, paste(joiningCell.copied, for: point) {
                    return
                } else if let rootCell = object as? Cell, paste(rootCell.copied, for: point) {
                    return
                }
            }
        }
    }
    var pasteColorBinding: ((CanvasView, Color, [Cell]) -> ())?
    func paste(_ color: Color, for point: Point) -> Bool {
        let p = convertToCurrentLocal(point)
        let ict = cut.currentNode.indicatedCellsTuple(with: p, reciprocalScale: model.reciprocalScale)
        guard !ict.geometryItems.isEmpty else {
            return false
        }
        var isPaste = false
        for geometryItem in ict.geometryItems {
            if color != geometryItem.cell.material.color {
                isPaste = true
                break
            }
        }
        if isPaste {
            pasteColorBinding?(self, color, ict.geometryItems.map { $0.cell })
        }
        return true
    }
    var pasteMaterialBinding: ((CanvasView, Material, [Cell]) -> ())?
    func paste(_ material: Material, for point: Point) -> Bool {
        let p = convertToCurrentLocal(point)
        let ict = cut.currentNode.indicatedCellsTuple(with: p, reciprocalScale: model.reciprocalScale)
        guard !ict.geometryItems.isEmpty else {
            return false
        }
        pasteMaterialBinding?(self, material, ict.geometryItems.map { $0.cell })
        return true
    }
    func paste(_ copyJoiningCell: JoiningCell, for point: Point) -> Bool {
        let inNode = cut.currentNode
        let isEmptyCellsInEditTrack: Bool = {
            for copyCell in copyJoiningCell.cell.allCells {
                for geometryItem in inNode.editTrack.geometryItems {
                    if geometryItem.cell.id == copyCell.id {
                        return false
                    }
                }
            }
            return true
        } ()
        if isEmptyCellsInEditTrack {
            return paste(copyJoiningCell, in: inNode.editTrack, inNode, for: point)
        } else {
            var isChanged = false
            for copyCell in copyJoiningCell.cell.allCells {
                for track in inNode.tracks {
                    for ci in track.geometryItems {
                        if ci.cell.id == copyCell.id {
                            set(copyCell.geometry, old: ci.cell.geometry,
                                at: track.animation.editKeyframeIndex,
                                in: ci, track, inNode, time: time)
                            isChanged = true
                        }
                    }
                }
            }
            return isChanged
        }
    }
    func paste(_ copyJoiningCell: JoiningCell, in track: MultipleTrack, _ node: CellGroup,
               for point: Point) -> Bool {
        node.tracks.forEach { fromTrack in
            guard fromTrack != track else {
                return
            }
            let geometryItems: [GeometryItem] = fromTrack.geometryItems.compactMap { geometryItem in
                for copyCell in copyJoiningCell.cell.allCells {
                    if geometryItem.cell.id == copyCell.id {
                        let newKeyGeometries = track.alignedKeyGeometries(geometryItem.keyGeometries)
                        move(geometryItem, keyGeometries: newKeyGeometries,
                             oldKeyGeometries: geometryItem.keyGeometries,
                             from: fromTrack, to: track, in: node, time: time)
                        return geometryItem
                    }
                }
                return nil
            }
            if !fromTrack.selectedGeometryItems.isEmpty && !geometryItems.isEmpty {
                let selectedGeometryItems = Array(Set(fromTrack.selectedGeometryItems).subtracting(geometryItems))
                if selectedGeometryItems != fromTrack.selectedGeometryItems {
                    setSelectedGeometryItems(selectedGeometryItems,
                                             oldGeometryItems: fromTrack.selectedGeometryItems,
                                             in: fromTrack, time: time)
                }
            }
        }
        
        for copyCell in copyJoiningCell.cell.allCells {
            guard let (fromTrack, geometryItem) = node.trackAndGeometryItem(withGeometryItemID: copyCell.id) else {
                continue
            }
            let newKeyGeometries = track.alignedKeyGeometries(geometryItem.keyGeometries)
            move(geometryItem, keyGeometries: newKeyGeometries, oldKeyGeometries: geometryItem.keyGeometries,
                 from: fromTrack, to: track, in: node, time: time)
        }
        return true
    }
    func paste(_ copyRootCell: Cell, for point: Point) -> Bool {
        let inNode = cut.currentNode
        let lki = inNode.editTrack.animation.loopedKeyframeIndex(withTime: cut.currentTime)
        var newGeometryItems = [GeometryItem]()
        copyRootCell.depthFirstSearch(duplicate: false) { parent, cell in
            cell.id = UUID()
            let emptyKeyGeometries = inNode.editTrack.emptyKeyGeometries
            let keyGeometrys = emptyKeyGeometries.withReplaced(cell.geometry,
                                                               at: lki.keyframeIndex)
            newGeometryItems.append(GeometryItem(cell: cell, keyGeometries: keyGeometrys))
        }
        let index = cellIndex(withTrackIndex: inNode.editTrackIndex, in: cut.currentNode.rootCell)
        insertCells(newGeometryItems, rootCell: copyRootCell,
                    at: index, in: inNode.rootCell, inNode.editTrack, inNode, time: time)
        setSelectedGeometryItems(inNode.editTrack.selectedGeometryItems + newGeometryItems,
                                 oldGeometryItems: inNode.editTrack.selectedGeometryItems,
                                 in: inNode.editTrack, time: time)
        return true
    }
    func paste(_ copyDrawing: Drawing, for point: Point) -> Bool {
        return paste(copyDrawing.lines, for: point)
    }
    func paste(_ copyLines: [Line], for point: Point) -> Bool {
        let p = convertToCurrentLocal(point)
        let inNode = cut.currentNode
        let ict = inNode.indicatedCellsTuple(with : p, reciprocalScale: model.reciprocalScale)
        if !inNode.editTrack.animation.isInterpolated && ict.type != .none,
            let cell = inNode.rootCell.at(p),
            let geometryItem = inNode.editTrack.geometryItem(with: cell) {
            
            let nearestPathLineIndex = geometryItem.cell.geometry.nearestPathLineIndex(at: p)
            let previousLine = geometryItem.cell.geometry.lines[nearestPathLineIndex]
            let nextLineIndex = nearestPathLineIndex + 1 >=
                geometryItem.cell.geometry.lines.count ? 0 : nearestPathLineIndex + 1
            let nextLine = geometryItem.cell.geometry.lines[nextLineIndex]
            let unionSegmentLine = Line(controls: [Line.Control(point: nextLine.firstPoint,
                                                                pressure: 1),
                                                   Line.Control(point: previousLine.lastPoint,
                                                                pressure: 1)])
            let geometry = Geometry(lines: [unionSegmentLine] + copyLines,
                                    scale: model.scale)
            let lines = geometry.lines.withRemovedFirst()
            let geometris = Geometry.geometriesWithInserLines(with: geometryItem.keyGeometries,
                                                              lines: lines,
                                                              atLinePathIndex: nearestPathLineIndex)
            setGeometries(geometris,
                          oldKeyGeometries: geometryItem.keyGeometries,
                          in: geometryItem, inNode.editTrack, inNode, time: time)
        } else {
            let drawing = inNode.editTrack.drawingItem.drawing
            let oldCount = drawing.lines.count
            let lineIndexes = (0..<copyLines.count).map { $0 + oldCount }
            set(drawing.lines + copyLines,
                old: drawing.lines, in: drawing, inNode, time: time)
            setSelectedLineIndexes(drawing.selectedLineIndexes + lineIndexes,
                                   oldLineIndexes: drawing.selectedLineIndexes,
                                   in: drawing, inNode, time: time)
        }
        return true
    }
    
    private func removeGeometryItems(_ geometryItems: [GeometryItem]) {
        let inNode = cut.currentNode
        var geometryItems = geometryItems
        while !geometryItems.isEmpty {
            let cellRemoveManager = inNode.cellRemoveManager(with: geometryItems[0])
            for trackAndGeometryItems in cellRemoveManager.trackAndGeometryItems {
                let track = trackAndGeometryItems.track, geometryItems = trackAndGeometryItems.geometryItems
                let removeSelectedGeometryItems
                    = Array(Set(track.selectedGeometryItems).subtracting(geometryItems))
                if removeSelectedGeometryItems.count != track.selectedGeometryItems.count {
                    setSelectedGeometryItems(removeSelectedGeometryItems,
                                             oldGeometryItems: track.selectedGeometryItems,
                                             in: track, time: time)
                }
            }
            removeCell(with: cellRemoveManager, in: inNode, time: time)
            geometryItems = geometryItems.filter { !cellRemoveManager.contains($0) }
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
        if isDrawingSelectedLines {
            setSelectedLineIndexes([], oldLineIndexes: editingCellGroup.drawing.selectedLineIndexes,
                                   in: editingCellGroup.drawing, inNode, time: time)
        }
        set(unselectedLines, old: editingCellGroup.drawing.lines,
            in: editingCellGroup.drawing, inNode, time: time)
        let newMaterial = Material(color: Color.random())
        let ict = inNode.indicatedCellsTuple(with: convertToCurrentLocal(p),
                                             reciprocalScale: model.reciprocalScale)
        if ict.type == .selected {
            let newGeometryItems = ict.geometryItems.map {
                ($0.cell, addCellIndex(with: newGeometryItem.cell, in: $0.cell))
            }
            insertCell(newGeometryItem, in: newGeometryItems, inNode.editTrack, inNode, time: time)
        } else {
            let newGeometryItems = [(rootCell, addCellIndex(with: newGeometryItem.cell, in: rootCell))]
            insertCell(newGeometryItem, in: newGeometryItems, inNode.editTrack, inNode, time: time)
        }
        
    }
}
extension CanvasView: Transformable {
    private var moveSelected = CellGroup.Selection()
    private var transformBounds = Rect.null, moveOldPoint = Point(), moveTransformOldPoint = Point()
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
    let moveTransformAngleTime = Second(0.1)
    var moveEditTransform: CellGroup.EditTransform?, moveTransformAngleOldTime = Second(0.0)
    var moveTransformAnglePoint = Point(), moveTransformAngleOldPoint = Point()
    var isMoveTransformAngle = false
    private weak var moveNode: CellGroup?
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
        case .changed:
            if type != .move {
                if var editTransform = moveEditTransform {
                    
                    func newEditTransform(with lines: [Line]) -> CellGroup.EditTransform {
                        var ps = [Point]()
                        for line in lines {
                            line.allEditPoints({ (p, _) in
                                ps.append(p)
                            })
                            line.allEditPoints { (p, i) in ps.append(p) }
                        }
                        let rb = RotatedRect(convexHullPoints: ps.convexHull)
                        let np = rb.convertToLocal(p: p)
                        let tx = np.x / rb.size.width, ty = np.y / rb.size.height
                        if ty < tx {
                            if ty < 1 - tx {
                                let ap = editTransform.isCenter ? rb.midXMidYPoint : rb.midXMaxYPoint
                                return CellGroup.EditTransform(rotatedRect: rb,
                                                               anchorPoint: ap,
                                                               point: rb.midXMinYPoint,
                                                               oldPoint: rb.midXMinYPoint,
                                                               isCenter: editTransform.isCenter)
                            } else {
                                let ap = editTransform.isCenter ? rb.midXMidYPoint : rb.minXMidYPoint
                                return CellGroup.EditTransform(rotatedRect: rb,
                                                               anchorPoint: ap,
                                                               point: rb.maxXMidYPoint,
                                                               oldPoint: rb.maxXMidYPoint,
                                                               isCenter: editTransform.isCenter)
                            }
                        } else {
                            if ty < 1 - tx {
                                let ap = editTransform.isCenter ? rb.midXMidYPoint : rb.maxXMidYPoint
                                return CellGroup.EditTransform(rotatedRect: rb,
                                                               anchorPoint: ap,
                                                               point: rb.minXMidYPoint,
                                                               oldPoint: rb.minXMidYPoint,
                                                               isCenter: editTransform.isCenter)
                            } else {
                                let ap = editTransform.isCenter ? rb.midXMidYPoint : rb.midXMinYPoint
                                return CellGroup.EditTransform(rotatedRect: rb,
                                                               anchorPoint: ap,
                                                               point: rb.midXMaxYPoint,
                                                               oldPoint: rb.midXMaxYPoint,
                                                               isCenter: editTransform.isCenter)
                            }
                        }
                    }
                    if moveSelected.cellTuples.isEmpty {
                        if moveSelected.drawingTuple?.lineIndexes.isEmpty ?? true {
                        } else if let moveDrawingTuple = moveSelected.drawingTuple {
                            let net = newEditTransform(with: moveDrawingTuple.lineIndexes.map {
                                moveDrawingTuple.drawing.lines[$0]
                            })
                            let ap = editTransform.isCenter ?
                                net.anchorPoint : editTransform.anchorPoint
                            editTransform = CellGroup.EditTransform(rotatedRect: net.rotatedRect,
                                                                    anchorPoint: ap,
                                                                    point: editTransform.point,
                                                                    oldPoint: editTransform.oldPoint,
                                                                    isCenter: editTransform.isCenter)
                        }
                    } else {
                        let lines = moveSelected.cellTuples.reduce(into: [Line]()) {
                            $0 += $1.geometryItem.cell.geometry.lines
                        }
                        let net = newEditTransform(with: lines)
                        let ap = editTransform.isCenter ? net.anchorPoint : editTransform.anchorPoint
                        editTransform = CellGroup.EditTransform(rotatedRect: net.rotatedRect,
                                                                anchorPoint: ap,
                                                                point: editTransform.point,
                                                                oldPoint: editTransform.oldPoint,
                                                                isCenter: editTransform.isCenter)
                    }
                    
                    self.moveEditTransform?.point = p - moveTransformOldPoint + editTransform.oldPoint
                    self.editTransform = moveEditTransform
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
                cut.updateWithCurrentTime()
            }
        case .ended:
            if type == .warp {
                if editTransform?.isCenter ?? false {
                    distanceWarp(for: p, pressure: pressure, time: time, phase)
                    moveEditTransform = nil
                    editTransform = nil
                    return
                }
            }
            if !moveSelected.isEmpty, let node = moveNode {
                let affine = affineTransform(with: node)
                if let mdp = moveSelected.drawingTuple {
                    var newLines = mdp.oldLines
                    for index in mdp.lineIndexes {
                        newLines[index] = mdp.oldLines[index].applying(affine)
                    }
                    set(newLines, old: mdp.oldLines, in: mdp.drawing, node, time: self.time)
                }
                for mcp in moveSelected.cellTuples {
                    set(mcp.geometry.applying(affine),
                        old: mcp.geometry,
                        at: mcp.track.animation.editKeyframeIndex,
                        in:mcp.geometryItem, mcp.track, node, time: self.time)
                }
                cut.updateWithCurrentTime()
                moveSelected = CellGroup.Selection()
            }
            self.moveEditTransform = nil
            editTransform = nil
        }
        setNeedsDisplay()
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
        if let drawing = nearest.drawing {
            if nearest.line.controls.count > 2 {
                replaceLine(nearest.line.removedControl(at: nearest.pointIndex),
                            oldLine: nearest.line,
                            at: nearest.lineIndex, in: drawing, in: inNode, time: time)
            } else {
                removeLine(at: nearest.lineIndex, in: drawing, inNode, time: time)
            }
            cut.updateWithCurrentTime()
            updateEditView(with: p)
        } else if let geometryItem = nearest.geometryItem {
            setGeometries(Geometry.geometriesWithRemovedControl(with: geometryItem.keyGeometries,
                                                                atLineIndex: nearest.lineIndex,
                                                                index: nearest.pointIndex),
                          oldKeyGeometries: geometryItem.keyGeometries,
                          in: geometryItem, inNode.editTrack, inNode, time: time)
            if geometryItem.isEmptyKeyGeometries {
                removeGeometryItems([geometryItem])
            }
            cut.updateWithCurrentTime()
            updateEditView(with: p)
        }
    }
    
    private var movePointNearest: CellGroup.Nearest?, movePointOldPoint = Point(), movePointIsSnap = false
    private var movePointNode: CellGroup?
    private let snapPointSnapDistance = 8.0.cg
    private var bezierSortedResult: CellGroup.Nearest.BezierSortedResult?
    func movePoint(for p: Point, pressure: Real, time: Second, _ phase: Phase, _ version: Version) {
        movePoint(for: p, pressure: pressure, time: time, phase, isVertex: false)
    }
    func moveVertex(for p: Point, pressure: Real, time: Second, _ phase: Phase, _ version: Version) {
        movePoint(for: p, pressure: pressure, time: time, phase, isVertex: true)
    }
    func movePoint(for point: Point, pressure: Real, time: Second, _ phase: Phase,
                   isVertex: Bool) {
        let p = convertToCurrentLocal(point)
        switch phase {
        case .began:
            if let nearest = cut.currentNode.nearest(at: p, isVertex: isVertex) {
                bezierSortedResult = nearest.bezierSortedResult(at: p)
                movePointNearest = nearest
                movePointNode = cut.currentNode
                movePointIsSnap = false
            }
            updateEditView(with: p)
            movePointNode = cut.currentNode
            movePointOldPoint = p
        case .changed:
            let dp = p - movePointOldPoint
            movePointIsSnap = movePointIsSnap ? true : pressure == 1
            
            if let nearest = movePointNearest {
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
        case .ended:
            let dp = p - movePointOldPoint
            if let nearest = movePointNearest, let node = movePointNode {
                if nearest.drawingEdit != nil || nearest.geometryItemEdit != nil {
                    movedPoint(with: nearest, dp: dp, in: node.editTrack, node)
                } else {
                    if movePointIsSnap, let b = bezierSortedResult {
                        movedPoint(with: nearest, bezierSortedResult: b, dp: dp,
                                   isVertex: isVertex, in: node.editTrack, node)
                    } else {
                        movedLineCap(with: nearest, dp: dp,
                                     isVertex: isVertex, in: node.editTrack, node)
                    }
                }
                movePointNode = nil
                movePointIsSnap = false
                movePointNearest = nil
                bezierSortedResult = nil
                updateEditView(with: p)
            }
        }
        setNeedsDisplay()
    }
    private func movingPoint(with nearest: CellGroup.Nearest, dp: Point, in track: MultipleTrack) {
        let snapD = snapPointSnapDistance / model.scale
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
        } else if let e = nearest.geometryItemEdit {
            let line = e.geometry.lines[e.lineIndex]
            var control = line.controls[e.pointIndex]
            control.point = line.editPoint(withEditCenterPoint: nearest.point + dp, at: e.pointIndex)
            if movePointIsSnap && (e.pointIndex == 1 || e.pointIndex == line.controls.count - 2) {
                control.point = track.snapPoint(control.point,
                                                editLine: e.geometryItem.cell.geometry.lines[e.lineIndex],
                                                editPointIndex: e.pointIndex,
                                                snapDistance: snapD)
            }
            let newLine = line.withReplaced(control, at: e.pointIndex).autoPressure()
            
            let i = cut.currentNode.editTrack.animation.editKeyframeIndex
            //track.replace
            //            e.geometryItem.replace(Geometry(lines: e.geometry.lines.withReplaced(newLine,
            //                                                                             at: e.lineIndex)), at: i)
            track.updateInterpolation()
            
            let np = e.geometryItem.cell.geometry.lines[e.lineIndex].editCenterPoint(at: e.pointIndex)
            editPoint = CellGroup.EditPoint(nearestLine: e.geometryItem.cell.geometry.lines[e.lineIndex],
                                            nearestPointIndex: e.pointIndex,
                                            lines: [e.geometryItem.cell.geometry.lines[e.lineIndex]],
                                            point: np, isSnap: movePointIsSnap)
            
        }
    }
    private func movingPoint(with nearest: CellGroup.Nearest,
                             bezierSortedResult b: CellGroup.Nearest.BezierSortedResult,
                             dp: Point, isVertex: Bool, in track: MultipleTrack) {
        let snapD = snapPointSnapDistance * model.reciprocalScale
        let grid = 5 * model.reciprocalScale
        var np = track.snapPoint(nearest.point + dp, with: b, snapDistance: snapD, grid: grid)
        if let e = nearest.drawingEditLineCap, let drawing = b.drawing {
            var newLines = e.lines
            if b.lineCap.line.controls.count == 2 {
                let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                var control = b.lineCap.line.controls[pointIndex]
                control.point = track.snapPoint(np, editLine: drawing.lines[b.lineCap.lineIndex],
                                                editPointIndex: pointIndex, snapDistance: snapD)
                newLines[b.lineCap.lineIndex] = b.lineCap.line.withReplaced(control, at: pointIndex)
                np = control.point
            } else if isVertex {
                newLines[b.lineCap.lineIndex] = b.lineCap.line.warpedWith(
                    deltaPoint: np - nearest.point, isFirst: b.lineCap.isFirst)
            } else {
                let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                var control = b.lineCap.line.controls[pointIndex]
                control.point = np
                newLines[b.lineCap.lineIndex] = newLines[b.lineCap.lineIndex].withReplaced(
                    control, at: b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1)
            }
            //            drawing.lines = newLines
            editPoint = CellGroup.EditPoint(nearestLine: drawing.lines[b.lineCap.lineIndex],
                                            nearestPointIndex: b.lineCap.pointIndex,
                                            lines: e.drawingCaps.map { drawing.lines[$0.lineIndex] },
                                            point: np,
                                            isSnap: movePointIsSnap)
        } else if let geometryItem = b.geometryItem, let geometry = b.geometry {
            for editLineCap in nearest.geometryItemEditLineCaps {
                if editLineCap.geometryItem == geometryItem {
                    if b.lineCap.line.controls.count == 2 {
                        let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                        var control = b.lineCap.line.controls[pointIndex]
                        let line = geometryItem.cell.geometry.lines[b.lineCap.lineIndex]
                        control.point = track.snapPoint(np,
                                                        editLine: line,
                                                        editPointIndex: pointIndex,
                                                        snapDistance: snapD)
                        let newBLine = b.lineCap.line.withReplaced(control,
                                                                   at: pointIndex).autoPressure()
                        let newLines = geometry.lines.withReplaced(newBLine,
                                                                   at: b.lineCap.lineIndex)
                        let i = cut.currentNode.editTrack.animation.editKeyframeIndex
                        //                        track.replace
                        //                        geometryItem.replace(Geometry(lines: newLines), at: i)
                        np = control.point
                    } else if isVertex {
                        let warpedLine = b.lineCap.line.warpedWith(deltaPoint: np - nearest.point,
                                                                   isFirst: b.lineCap.isFirst)
                        let newLine = warpedLine.autoPressure()
                        let newLines = geometry.lines.withReplaced(newLine, at: b.lineCap.lineIndex)
                        let i = cut.currentNode.editTrack.animation.editKeyframeIndex
                        //track.replace
                        //                        geometryItem.replace(Geometry(lines: newLines), at: i)
                    } else {
                        let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                        var control = geometry.lines[b.lineCap.lineIndex].controls[pointIndex]
                        control.point = np
                        let newLine = b.lineCap.line.withReplaced(control,
                                                                  at: pointIndex).autoPressure()
                        let newLines = geometry.lines.withReplaced(newLine, at: b.lineCap.lineIndex)
                        
                        let i = cut.currentNode.editTrack.animation.editKeyframeIndex
                        //                        track.replace
                        //                        geometryItem.replace(Geometry(lines: newLines), at: i)
                    }
                } else {
                    editLineCap.geometryItem.cell.geometry = editLineCap.geometry
                }
            }
            track.updateInterpolation()
            
            let newLines = nearest.geometryItemEditLineCaps.reduce(into: [Line]()) {
                $0 += $1.caps.map { geometryItem.cell.geometry.lines[$0.lineIndex] }
            }
            editPoint = CellGroup.EditPoint(nearestLine: geometryItem.cell.geometry.lines[b.lineCap.lineIndex],
                                            nearestPointIndex: b.lineCap.pointIndex,
                                            lines: newLines,
                                            point: np,
                                            isSnap: movePointIsSnap)
        }
    }
    func movingLineCap(with nearest: CellGroup.Nearest, dp: Point,
                       isVertex: Bool, in track: MultipleTrack) {
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
        
        for editLineCap in nearest.geometryItemEditLineCaps {
            var newLines = editLineCap.geometry.lines
            if isVertex {
                for cap in editLineCap.caps {
                    newLines[cap.lineIndex] = cap.line.warpedWith(deltaPoint: dp,
                                                                  isFirst: cap.isFirst).autoPressure()
                }
            } else {
                for cap in editLineCap.caps {
                    var control = cap.isFirst ?
                        cap.line.controls[0] : cap.line.controls[cap.line.controls.count - 1]
                    control.point = np
                    newLines[cap.lineIndex] = newLines[cap.lineIndex]
                        .withReplaced(control, at: cap.isFirst ?
                            0 : cap.line.controls.count - 1).autoPressure()
                }
            }
            
            let i = cut.currentNode.editTrack.animation.editKeyframeIndex
            //track.replace
            //            editLineCap.geometryItem.replace(Geometry(lines: newLines), at: i)
            
            editPointLines += editLineCap.caps.map { newLines[$0.lineIndex] }
        }
        
        track.updateInterpolation()
        
        if let b = bezierSortedResult {
            if let geometryItem = b.geometryItem {
                let newLine = geometryItem.cell.geometry.lines[b.lineCap.lineIndex]
                editPoint = CellGroup.EditPoint(nearestLine: newLine,
                                                nearestPointIndex: b.lineCap.pointIndex,
                                                lines: Array(Set(editPointLines)),
                                                point: np, isSnap: movePointIsSnap)
            } else if let drawing = b.drawing {
                let newLine = drawing.lines[b.lineCap.lineIndex]
                editPoint = CellGroup.EditPoint(nearestLine: newLine,
                                                nearestPointIndex: b.lineCap.pointIndex,
                                                lines: Array(Set(editPointLines)),
                                                point: np, isSnap: movePointIsSnap)
            }
        }
    }
}
