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
 Issue: Z移動を廃止してセルツリー表示を作成、セルクリップや全てのロック解除などを廃止
 Issue: スクロール後の元の位置までの距離を表示
 Issue: sceneを取り除く
 */
final class Canvas: DrawView {
    let player = Player()
    
    var scene = Scene() {
        didSet {
            player.updateChildren()
            cut = scene.editCut
            player.scene = scene
            materialView.material = scene.editMaterial
            updateScreenTransform()
            updateEditCellBindingLine()
        }
    }
    var sceneDataModel: DataModel?
    var cut = Cut() {
        didSet {
            cut.read()
            setNeedsDisplay()
        }
    }
    
    var setContentsScaleClosure: ((Canvas, CGFloat) -> ())?
    override var contentsScale: CGFloat {
        didSet {
            player.contentsScale = contentsScale
            setContentsScaleClosure?(self, contentsScale)
        }
    }
    
    override init() {
        super.init()
        drawBlock = { [unowned self] in self.draw(in: $0) }
        player.endPlayClosure = { [unowned self] _ in self.isOpenedPlayer = false }
        cellView.copiedObjectsClosure = { [unowned self] _, _ in self.copiedCells() }
    }
    
    var cursor = Cursor.arrow
    
    override var bounds: CGRect {
        didSet {
            player.frame = bounds
            updateScreenTransform()
        }
    }
    
    var isOpenedPlayer = false {
        didSet {
            guard isOpenedPlayer != oldValue else {
                return
            }
            if isOpenedPlayer {
                append(child: player)
            } else {
                player.removeFromParent()
            }
        }
    }
    
    enum MaterialViewType {
        case none, selected, preview
    }
    var materialViewType = MaterialViewType.none {
        didSet {
            updateViewType()
            editCellLineLayer.isHidden = materialViewType == .preview
        }
    }
    
    override var viewQuasimode: ViewQuasimode {
        didSet {
//            switch viewQuasimode {
//            case .move, .stroke, .lassoErase, .select, .deselect:
//                cursor = .stroke
//            default:
//                cursor = .arrow
//            }
            updateViewType()
            updateEditView(with: convertToCurrentLocal(cursorPoint))
        }
    }
    private func updateViewType() {
        if materialViewType == .selected {
            viewType = .editMaterial
        } else if materialViewType == .preview {
            viewType = .changingMaterial
        } else {
            switch viewQuasimode {
            case .stroke:
                viewType = .edit
            case .movePoint:
                viewType = .editPoint
            case .moveVertex:
                viewType = .editVertex
            case .moveZ:
                viewType = .editMoveZ
            case .move:
                viewType = .edit
            case .warp:
                viewType = .editWarp
            case .transform:
                viewType = .editTransform
            case .select:
                viewType = .editSelected
            case .deselect:
                viewType = .editDeselected
            case .lassoErase:
                viewType = .editDeselected
            }
        }
    }
    var viewType = Cut.ViewType.edit {
        didSet {
            if viewType != oldValue {
                setNeedsDisplay()
            }
        }
    }
    func updateEditView(with p: CGPoint) {
        switch viewType {
        case .edit, .editMaterial, .changingMaterial,
             .preview, .editSelected, .editDeselected:
            editZ = nil
            editPoint = nil
            editTransform = nil
        case .editPoint, .editVertex:
            editZ = nil
            updateEditPoint(with: p)
            editTransform = nil
        case .editMoveZ:
            updateEditZ(with: p)
            editPoint = nil
            editTransform = nil
        case .editWarp:
            editZ = nil
            editPoint = nil
            updateEditTransform(with: p)
        case .editTransform:
            editZ = nil
            editPoint = nil
            updateEditTransform(with: p)
        }
        let cellsTuple = cut.editNode.indicatedCellsTuple(with: p,
                                                          reciprocalScale: scene.reciprocalScale)
        indicatedCellItem = cellsTuple.cellItems.first
        if indicatedCellItem != nil && cut.editNode.editTrack.selectedCellItems.count > 1 {
            indicatedPoint = p
            setNeedsDisplay()
        }
    }
    var screenTransform = CGAffineTransform.identity
    func updateScreenTransform() {
        screenTransform = CGAffineTransform(translationX: bounds.midX, y: bounds.midY)
    }
    
    var editPoint: Node.EditPoint? {
        didSet {
            if editPoint != oldValue {
                setNeedsDisplay()
            }
        }
    }
    func updateEditPoint(with point: CGPoint) {
        if let n = cut.editNode.nearest(at: point, isVertex: viewType == .editVertex) {
            if let e = n.drawingEdit {
                editPoint = Node.EditPoint(nearestLine: e.line, nearestPointIndex: e.pointIndex,
                                           lines: [e.line],
                                           point: n.point, isSnap: movePointIsSnap)
            } else if let e = n.cellItemEdit {
                editPoint = Node.EditPoint(nearestLine: e.geometry.lines[e.lineIndex],
                                           nearestPointIndex: e.pointIndex,
                                           lines: [e.geometry.lines[e.lineIndex]],
                                           point: n.point, isSnap: movePointIsSnap)
            } else if n.drawingEditLineCap != nil || !n.cellItemEditLineCaps.isEmpty {
                if let nlc = n.bezierSortedResult(at: point) {
                    if let e = n.drawingEditLineCap {
                        let drawingLines = e.drawingCaps.map { $0.line }
                        let cellItemLines = n.cellItemEditLineCaps.reduce(into: [Line]()) {
                            $0 += $1.caps.map { $0.line }
                        }
                        editPoint = Node.EditPoint(nearestLine: nlc.lineCap.line,
                                                   nearestPointIndex: nlc.lineCap.pointIndex,
                                                   lines: drawingLines + cellItemLines,
                                                   point: n.point,
                                                   isSnap: movePointIsSnap)
                    } else {
                        let cellItemLines = n.cellItemEditLineCaps.reduce(into: [Line]()) {
                            $0 += $1.caps.map { $0.line }
                        }
                        editPoint = Node.EditPoint(nearestLine: nlc.lineCap.line,
                                                   nearestPointIndex: nlc.lineCap.pointIndex,
                                                   lines: cellItemLines,
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
    
    var editZ: Node.EditZ? {
        didSet {
            if editZ != oldValue {
                setNeedsDisplay()
            }
        }
    }
    func updateEditZ(with point: CGPoint) {
        let ict = cut.editNode.indicatedCellsTuple(with: point,
                                                   reciprocalScale: scene.reciprocalScale)
        if ict.type == .none {
            self.editZ = nil
        } else {
            let cells = ict.cellItems.map { $0.cell }
            let firstY = cut.editNode.editZFirstY(with: cells)
            self.editZ = Node.EditZ(cells: cells,
                                    point: point, firstPoint: point, firstY: firstY)
        }
    }
    
    var editTransform: Node.EditTransform? {
        didSet {
            if editTransform != oldValue {
                setNeedsDisplay()
            }
        }
    }
    private func editTransform(with lines: [Line], at p: CGPoint) -> Node.EditTransform {
        var ps = [CGPoint]()
        for line in lines {
            line.allEditPoints { (ep, i) in ps.append(ep) }
        }
        let rb = RotatedRect(convexHullPoints: CGPoint.convexHullPoints(with: ps))
        let w = rb.size.width * Node.EditTransform.centerRatio
        let h = rb.size.height * Node.EditTransform.centerRatio
        let centerBounds = CGRect(x: (rb.size.width - w) / 2,
                                  y: (rb.size.height - h) / 2, width: w, height: h)
        let np = rb.convertToLocal(p: p)
        let isCenter = centerBounds.contains(np)
        let tx = np.x / rb.size.width, ty = np.y / rb.size.height
        if ty < tx {
            if ty < 1 - tx {
                return Node.EditTransform(rotatedRect: rb,
                                          anchorPoint: isCenter ? rb.midXMidYPoint : rb.midXMaxYPoint,
                                          point: rb.midXMinYPoint,
                                          oldPoint: rb.midXMinYPoint, isCenter: isCenter)
            } else {
                return Node.EditTransform(rotatedRect: rb,
                                          anchorPoint: isCenter ? rb.midXMidYPoint : rb.minXMidYPoint,
                                          point: rb.maxXMidYPoint,
                                          oldPoint: rb.maxXMidYPoint, isCenter: isCenter)
            }
        } else {
            if ty < 1 - tx {
                return Node.EditTransform(rotatedRect: rb,
                                          anchorPoint: isCenter ? rb.midXMidYPoint : rb.maxXMidYPoint,
                                          point: rb.minXMidYPoint,
                                          oldPoint: rb.minXMidYPoint, isCenter: isCenter)
            } else {
                return Node.EditTransform(rotatedRect: rb,
                                          anchorPoint: isCenter ? rb.midXMidYPoint : rb.midXMinYPoint,
                                          point: rb.midXMaxYPoint,
                                          oldPoint: rb.midXMaxYPoint, isCenter: isCenter)
            }
        }
    }
    func editTransform(at p: CGPoint) -> Node.EditTransform? {
        let selection = cut.editNode.selection(with: p, reciprocalScale: scene.reciprocalScale)
        if selection.cellTuples.isEmpty {
            if let drawingTuple = selection.drawingTuple {
                if drawingTuple.lineIndexes.isEmpty {
                    return nil
                } else {
                    let lines = drawingTuple.lineIndexes.map { drawingTuple.drawing.lines[$0] }
                    return editTransform(with: lines, at: p)
                }
            } else {
                return nil
            }
        } else {
            let lines = selection.cellTuples.reduce(into: [Line]()) {
                $0 += $1.cellItem.cell.geometry.lines
            }
            return editTransform(with: lines, at: p)
        }
    }
    func updateEditTransform(with p: CGPoint) {
        self.editTransform = editTransform(at: p)
    }
    
    var cameraFrame: CGRect {
        get {
            return scene.frame
        }
        set {
            scene.frame = newValue
            player.updateChildren()
            updateWithScene()
        }
    }
    
    var setTimeClosure: ((Canvas, Beat) -> ())?
    var time: Beat {
        get {
            return scene.time
        }
        set {
            setTimeClosure?(self, newValue)
        }
    }
    var isHiddenPrevious: Bool {
        get {
            return scene.isHiddenPrevious
        }
        set {
            scene.isHiddenPrevious = newValue
            updateWithScene()
        }
    }
    var isHiddenNext: Bool {
        get {
            return scene.isHiddenNext
        }
        set {
            scene.isHiddenNext = newValue
            updateWithScene()
        }
    }
    var viewTransform: Transform {
        get {
            return scene.viewTransform
        }
        set {
            scene.viewTransform = newValue
            updateWithScene()
            updateEditCellBindingLine()
        }
    }
    private func updateWithScene() {
        updateSceneClosure?(self)
        setNeedsDisplay()
    }
    var updateSceneClosure: ((Canvas) -> ())?
    
    var currentTransform: CGAffineTransform {
        var affine = CGAffineTransform.identity
        affine = affine.concatenating(cut.editNode.worldAffineTransform)
        affine = affine.concatenating(scene.viewTransform.affineTransform)
        affine = affine.concatenating(screenTransform)
        return affine
    }
    func convertToCurrentLocal(_ r: CGRect) -> CGRect {
        let transform = currentTransform
        return transform.isIdentity ? r : r.applying(transform.inverted())
    }
    func convertFromCurrentLocal(_ r: CGRect) -> CGRect {
        let transform = currentTransform
        return transform.isIdentity ? r : r.applying(transform)
    }
    func convertToCurrentLocal(_ p: CGPoint) -> CGPoint {
        let transform = currentTransform
        return transform.isIdentity ? p : p.applying(transform.inverted())
    }
    func convertFromCurrentLocal(_ p: CGPoint) -> CGPoint {
        let transform = currentTransform
        return transform.isIdentity ? p : p.applying(transform)
    }
    
    override var isIndicated: Bool {
        didSet {
            if !isIndicated {
                indicatedCellItem = nil
            }
        }
    }
    var indicatedPoint: CGPoint?
    var indicatedCellItem: CellItem? {
        didSet {
            if indicatedCellItem != oldValue {
                oldValue?.cell.isIndicated = false
                indicatedCellItem?.cell.isIndicated = true
                setNeedsDisplay()
            }
        }
    }
    
    func setNeedsDisplay() {
        draw()
    }
    func setNeedsDisplay(inCurrentLocalBounds rect: CGRect) {
        draw(convertFromCurrentLocal(rect))
    }
    
    func draw(in ctx: CGContext) {
        ctx.saveGState()
        ctx.concatenate(screenTransform)
        cut.draw(scene: scene, viewType: viewType, in: ctx)
        if viewType != .preview {
            let edit = Node.Edit(indicatedCellItem: indicatedCellItem,
                                 editMaterial: materialView.material,
                                 editZ: editZ, editPoint: editPoint,
                                 editTransform: editTransform, point: indicatedPoint)
            ctx.concatenate(scene.viewTransform.affineTransform)
            cut.editNode.drawEdit(edit, scene: scene, viewType: viewType,
                                  strokeLine: stroker.line,
                                  strokeLineWidth: stroker.lineWidth,
                                  strokeLineColor: stroker.lineColor,
                                  reciprocalViewScale: scene.reciprocalViewScale,
                                  scale: scene.scale, rotation: scene.viewTransform.rotation,
                                  in: ctx)
            ctx.restoreGState()
            if let editZ = editZ {
                let p = convertFromCurrentLocal(editZ.firstPoint)
                cut.editNode.drawEditZKnob(editZ, at: p, in: ctx)
            }
            cut.drawCautionBorder(scene: scene, bounds: bounds, in: ctx)
        } else {
            ctx.restoreGState()
        }
    }
    
    private func registerUndo(_ closure: @escaping (Canvas, Beat) -> Void) {
        undoManager?.registerUndo(withTarget: self) { [oldTime = time] in closure($0, oldTime) }
    }
    
    func delete(with event: KeyInputEvent) -> Bool {
        let point = convertToCurrentLocal(self.point(from: event))
        if deleteCells(for: point) {
            return true
        }
        if deleteSelectedDrawingLines(for: point) {
            return true
        }
        if deleteDrawingLines(for: point) {
            return true
        }
        return false
    }
    func deleteSelectedDrawingLines(for p: CGPoint) -> Bool {
        let inNode = cut.editNode
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
    func deleteDrawingLines(for p: CGPoint) -> Bool {
        let inNode = cut.editNode
        let drawingItem = inNode.editTrack.drawingItem
        guard !drawingItem.drawing.lines.isEmpty else {
            return false
        }
        setSelectedLineIndexes([], oldLineIndexes: drawingItem.drawing.selectedLineIndexes,
                               in: drawingItem.drawing, inNode, time: time)
        set([], old: drawingItem.drawing.lines, in: drawingItem.drawing, inNode, time: time)
        return true
    }
    func deleteCells(for point: CGPoint) -> Bool {
        let inNode = cut.editNode
        let ict = inNode.indicatedCellsTuple(with: point, reciprocalScale: scene.reciprocalScale)
        switch ict.type {
        case .selected:
            var isChanged = false
            for track in inNode.tracks {
                let removeSelectedCellItems = ict.cellItems.filter {
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
                if !removeSelectedCellItems.isEmpty {
                    removeCellItems(removeSelectedCellItems)
                }
            }
            if isChanged {
                return true
            }
        case .indicated:
            if let cellItem = inNode.cellItem(at: point,
                                              reciprocalScale: scene.reciprocalScale,
                                              with: inNode.editTrack) {
                if !cellItem.cell.geometry.isEmpty {
                    set(Geometry(), old: cellItem.cell.geometry,
                        at: inNode.editTrack.animation.editKeyframeIndex,
                        in: cellItem, inNode.editTrack, inNode, time: time)
                    if cellItem.isEmptyKeyGeometries {
                        removeCellItems([cellItem])
                    }
                    return true
                }
            }
        case .none:
            break
        }
        return false
    }
    
    func copiedObjects(with event: KeyInputEvent) -> [ViewExpression]? {
        let p = convertToCurrentLocal(point(from: event))
        let ict = cut.editNode.indicatedCellsTuple(with: p, reciprocalScale: scene.reciprocalScale)
        switch ict.type {
        case .none:
            let copySelectedLines = cut.editNode.editTrack.drawingItem.drawing.editLines
            if !copySelectedLines.isEmpty {
                let drawing = Drawing(lines: copySelectedLines)
                return [drawing.copied]
            }
        case .indicated, .selected:
            if !ict.selectedLineIndexes.isEmpty {
                let copySelectedLines = cut.editNode.editTrack.drawingItem.drawing.editLines
                let drawing = Drawing(lines: copySelectedLines)
                return [drawing.copied]
            } else {
                let cell = cut.editNode.rootCell.intersection(ict.cellItems.map { $0.cell },
                                                              isNewID: false)
                let material = ict.cellItems[0].cell.material
                return [JoiningCell(cell), material]
            }
        }
        return []
    }
    func copiedCells() -> [Cell]? {
        guard let editCell = editCell else {
            return nil
        }
        let cells = cut.editNode.selectedCells(with: editCell)
        let cell = cut.editNode.rootCell.intersection(cells, isNewID: true)
        return [cell]
    }
    func paste(_ objects: [Any], with event: KeyInputEvent) -> Bool {
        for object in objects {
            if let color = object as? Color, paste(color, with: event) {
                return true
            } else if let material = object as? Material, paste(material, with: event) {
                return true
            } else if let drawing = object as? Drawing, paste(drawing.copied, with: event) {
                return true
            } else if let lines = object as? [Line], paste(lines, with: event) {
                return true
            } else if !cut.editNode.editTrack.animation.isInterpolated {
                if let joiningCell = object as? JoiningCell, paste(joiningCell.copied, with: event) {
                    return true
                } else if let rootCell = object as? Cell, paste(rootCell.copied, with: event) {
                    return true
                }
            }
        }
        return false
    }
    var pasteColorBinding: ((Canvas, Color, [Cell]) -> ())?
    func paste(_ color: Color, with event: KeyInputEvent) -> Bool {
        let p = convertToCurrentLocal(point(from: event))
        let ict = cut.editNode.indicatedCellsTuple(with: p, reciprocalScale: scene.reciprocalScale)
        guard !ict.cellItems.isEmpty else {
            return false
        }
        var isPaste = false
        for cellItem in ict.cellItems {
            if color != cellItem.cell.material.color {
                isPaste = true
                break
            }
        }
        if isPaste {
            pasteColorBinding?(self, color, ict.cellItems.map { $0.cell })
        }
        return true
    }
    var pasteMaterialBinding: ((Canvas, Material, [Cell]) -> ())?
    func paste(_ material: Material, with event: KeyInputEvent) -> Bool {
        let p = convertToCurrentLocal(point(from: event))
        let ict = cut.editNode.indicatedCellsTuple(with: p, reciprocalScale: scene.reciprocalScale)
        guard !ict.cellItems.isEmpty else {
            return false
        }
        var isPaste = false
        for cellItem in ict.cellItems {
            if material.id != cellItem.cell.material.id {
                isPaste = true
                break
            }
        }
        if isPaste {
            pasteMaterialBinding?(self, material, ict.cellItems.map { $0.cell })
        }
        return isPaste
    }
    func paste(_ copyJoiningCell: JoiningCell, with event: KeyInputEvent) -> Bool {
        let inNode = cut.editNode
        let isEmptyCellsInEditTrack: Bool = {
            for copyCell in copyJoiningCell.cell.allCells {
                for cellItem in inNode.editTrack.cellItems {
                    if cellItem.cell.id == copyCell.id {
                        return false
                    }
                }
            }
            return true
        } ()
        if isEmptyCellsInEditTrack {
            return paste(copyJoiningCell, in: inNode.editTrack, inNode, with: event)
        } else {
            var isChanged = false
            for copyCell in copyJoiningCell.cell.allCells {
                for track in inNode.tracks {
                    for ci in track.cellItems {
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
    func paste(_ copyJoiningCell: JoiningCell, in track: NodeTrack, _ node: Node,
               with event: KeyInputEvent) -> Bool {
        node.tracks.forEach { fromTrack in
            guard fromTrack != track else {
                return
            }
            let cellItems: [CellItem] = fromTrack.cellItems.compactMap { cellItem in
                for copyCell in copyJoiningCell.cell.allCells {
                    if cellItem.cell.id == copyCell.id {
                        let newKeyGeometries = track.alignedKeyGeometries(cellItem.keyGeometries)
                        move(cellItem, keyGeometries: newKeyGeometries,
                             oldKeyGeometries: cellItem.keyGeometries,
                             from: fromTrack, to: track, in: node, time: time)
                        return cellItem
                    }
                }
                return nil
            }
            if !fromTrack.selectedCellItems.isEmpty && !cellItems.isEmpty {
                let selectedCellItems = Array(Set(fromTrack.selectedCellItems).subtracting(cellItems))
                if selectedCellItems != fromTrack.selectedCellItems {
                    setSelectedCellItems(selectedCellItems,
                                         oldCellItems: fromTrack.selectedCellItems,
                                         in: fromTrack, time: time)
                }
            }
        }
        
        for copyCell in copyJoiningCell.cell.allCells {
            guard let (fromTrack, cellItem) = node.trackAndCellItem(withCellID: copyCell.id) else {
                continue
            }
            let newKeyGeometries = track.alignedKeyGeometries(cellItem.keyGeometries)
            move(cellItem, keyGeometries: newKeyGeometries, oldKeyGeometries: cellItem.keyGeometries,
                 from: fromTrack, to: track, in: node, time: time)
        }
        return true
    }
    func move(_ cellItem: CellItem, keyGeometries: [Geometry], oldKeyGeometries: [Geometry],
              from fromTrack: NodeTrack, to toTrack: NodeTrack, in node: Node, time: Beat) {
        registerUndo {
            $0.move(cellItem, keyGeometries: oldKeyGeometries, oldKeyGeometries: keyGeometries,
                    from: toTrack, to: fromTrack, in: node, time: $1)
        }
        self.time = time
        toTrack.move(cellItem, keyGeometries: keyGeometries, from: fromTrack)
        if node.editTrack == fromTrack {
            cellItem.cell.isLocked = true
        }
        if node.editTrack == toTrack {
            cellItem.cell.isLocked = false
        }
        node.differentialDataModel.isWrite = true
        sceneDataModel?.isWrite = true
        setNeedsDisplay()
    }
    func paste(_ copyRootCell: Cell, with event: KeyInputEvent) -> Bool {
        let inNode = cut.editNode
        let lki = inNode.editTrack.animation.loopedKeyframeIndex(withTime: cut.currentTime)
        var newCellItems = [CellItem]()
        copyRootCell.depthFirstSearch(duplicate: false) { parent, cell in
            cell.id = UUID()
            let emptyKeyGeometries = inNode.editTrack.emptyKeyGeometries
            let keyGeometrys = emptyKeyGeometries.withReplaced(cell.geometry,
                                                               at: lki.keyframeIndex)
            newCellItems.append(CellItem(cell: cell, keyGeometries: keyGeometrys))
        }
        let index = cellIndex(withTrackIndex: inNode.editTrackIndex, in: cut.editNode.rootCell)
        insertCells(newCellItems, rootCell: copyRootCell,
                    at: index, in: inNode.rootCell, inNode.editTrack, inNode, time: time)
        setSelectedCellItems(inNode.editTrack.selectedCellItems + newCellItems,
                              oldCellItems: inNode.editTrack.selectedCellItems,
                              in: inNode.editTrack, time: time)
        return true
    }
    func paste(_ copyDrawing: Drawing, with event: KeyInputEvent) -> Bool {
        return paste(copyDrawing.lines, with: event)
    }
    func paste(_ copyLines: [Line], with event: KeyInputEvent) -> Bool {
        let p = convertToCurrentLocal(point(from: event))
        let inNode = cut.editNode
        let ict = inNode.indicatedCellsTuple(with : p, reciprocalScale: scene.reciprocalScale)
        if !inNode.editTrack.animation.isInterpolated && ict.type != .none,
            let cell = inNode.rootCell.at(p),
            let cellItem = inNode.editTrack.cellItem(with: cell) {
            
            let nearestPathLineIndex = cellItem.cell.geometry.nearestPathLineIndex(at: p)
            let previousLine = cellItem.cell.geometry.lines[nearestPathLineIndex]
            let nextLineIndex = nearestPathLineIndex + 1 >=
                cellItem.cell.geometry.lines.count ? 0 : nearestPathLineIndex + 1
            let nextLine = cellItem.cell.geometry.lines[nextLineIndex]
            let unionSegmentLine = Line(controls: [Line.Control(point: nextLine.firstPoint,
                                                                pressure: 1),
                                                   Line.Control(point: previousLine.lastPoint,
                                                                pressure: 1)])
            let geometry = Geometry(lines: [unionSegmentLine] + copyLines,
                                    scale: scene.scale)
            let lines = geometry.lines.withRemovedFirst()
            let geometris = Geometry.geometriesWithInserLines(with: cellItem.keyGeometries,
                                                              lines: lines,
                                                              atLinePathIndex: nearestPathLineIndex)
            setGeometries(geometris,
                          oldKeyGeometries: cellItem.keyGeometries,
                          in: cellItem, inNode.editTrack, inNode, time: time)
        } else {
            let drawing = inNode.editTrack.drawingItem.drawing
            let oldCount = drawing.lines.count
            let lineIndexes = (0 ..< copyLines.count).map { $0 + oldCount }
            set(drawing.lines + copyLines,
                     old: drawing.lines, in: drawing, inNode, time: time)
            setSelectedLineIndexes(drawing.selectedLineIndexes + lineIndexes,
                                    oldLineIndexes: drawing.selectedLineIndexes,
                                    in: drawing, inNode, time: time)
        }
        return true
    }
    
    private func removeCellItems(_ cellItems: [CellItem]) {
        let inNode = cut.editNode
        var cellItems = cellItems
        while !cellItems.isEmpty {
            let cellRemoveManager = inNode.cellRemoveManager(with: cellItems[0])
            for trackAndCellItems in cellRemoveManager.trackAndCellItems {
                let track = trackAndCellItems.track, cellItems = trackAndCellItems.cellItems
                let removeSelectedCellItems
                    = Array(Set(track.selectedCellItems).subtracting(cellItems))
                if removeSelectedCellItems.count != track.selectedCellItems.count {
                    setSelectedCellItems(removeSelectedCellItems,
                                          oldCellItems: track.selectedCellItems,
                                          in: track, time: time)
                }
            }
            removeCell(with: cellRemoveManager, in: inNode, time: time)
            cellItems = cellItems.filter { !cellRemoveManager.contains($0) }
        }
    }
    private func insertCell(with cellRemoveManager: Node.CellRemoveManager,
                            in node: Node, time: Beat) {
        registerUndo { $0.removeCell(with: cellRemoveManager, in: node, time: $1) }
        self.time = time
        node.insertCell(with: cellRemoveManager)
        node.differentialDataModel.isWrite = true
        sceneDataModel?.isWrite = true
        setNeedsDisplay()
    }
    private func removeCell(with cellRemoveManager: Node.CellRemoveManager,
                            in node: Node, time: Beat) {
        registerUndo { $0.insertCell(with: cellRemoveManager, in: node, time: $1) }
        self.time = time
        node.removeCell(with: cellRemoveManager)
        node.differentialDataModel.isWrite = true
        sceneDataModel?.isWrite = true
        setNeedsDisplay()
    }
    
    private func setGeometries(_ keyGeometries: [Geometry], oldKeyGeometries: [Geometry],
                               in cellItem: CellItem, _ track: NodeTrack, _ node: Node, time: Beat) {
        registerUndo {
            $0.setGeometries(oldKeyGeometries, oldKeyGeometries: keyGeometries,
                             in: cellItem, track, node, time: $1)
        }
        self.time = time
        track.set(keyGeometries, in: cellItem)
        node.differentialDataModel.isWrite = true
        setNeedsDisplay()
    }
    private func set(_ geometry: Geometry, old oldGeometry: Geometry,
                     at i: Int, in cellItem: CellItem, _ track: NodeTrack, _ node: Node, time: Beat) {
        registerUndo { $0.set(oldGeometry, old: geometry, at: i, in: cellItem, track, node, time: $1) }
        self.time = time
        cellItem.replace(geometry, at: i)
        track.updateInterpolation()
        node.differentialDataModel.isWrite = true
        setNeedsDisplay()
    }
    
    func selectAll(with event: KeyInputEvent) -> Bool {
        let inNode = cut.editNode
        let track = inNode.editTrack
        let drawing = track.drawingItem.drawing
        let lineIndexes = Array(0 ..< drawing.lines.count)
        if Set(drawing.selectedLineIndexes) != Set(lineIndexes) {
            setSelectedLineIndexes(lineIndexes, oldLineIndexes: drawing.selectedLineIndexes,
                                    in: drawing, inNode, time: time)
        }
        if Set(track.selectedCellItems) != Set(track.cellItems) {
            setSelectedCellItems(track.cellItems, oldCellItems: track.selectedCellItems,
                                  in: track, time: time)
        }
        return true
    }
    func deselectAll(with event: KeyInputEvent) -> Bool {
        let inNode = cut.editNode
        let track = inNode.editTrack
        let drawing = track.drawingItem.drawing
        if !drawing.selectedLineIndexes.isEmpty {
            setSelectedLineIndexes([], oldLineIndexes: drawing.selectedLineIndexes,
                                    in: drawing, inNode, time: time)
        }
        if !track.selectedCellItems.isEmpty {
            setSelectedCellItems([], oldCellItems: track.selectedCellItems,
                                  in: track, time: time)
        }
        return true
    }
    
    func play(with event: KeyInputEvent) {
        play()
    }
    func play() {
        isOpenedPlayer = true
        player.play()
    }
    
    func new(with event: KeyInputEvent) -> Bool {
        let inNode = cut.editNode
        let track = inNode.editTrack
        let drawingItem = track.drawingItem, rootCell = inNode.rootCell
        let geometry = Geometry(lines: drawingItem.drawing.editLines, scale: scene.scale)
        guard !geometry.isEmpty else {
            return false
        }
        let isDrawingSelectedLines = !drawingItem.drawing.selectedLineIndexes.isEmpty
        let unselectedLines = drawingItem.drawing.uneditLines
        if isDrawingSelectedLines {
            setSelectedLineIndexes([], oldLineIndexes: drawingItem.drawing.selectedLineIndexes,
                                    in: drawingItem.drawing, inNode, time: time)
        }
        set(unselectedLines, old: drawingItem.drawing.lines,
            in: drawingItem.drawing, inNode, time: time)
        let lki = track.animation.loopedKeyframeIndex(withTime: cut.currentTime)
        let keyGeometries = track.emptyKeyGeometries.withReplaced(geometry, at: lki.keyframeIndex)
        
        let newMaterial = Material(color: Color.random())
        let newCellItem = CellItem(cell: Cell(geometry: geometry, material: newMaterial),
                                   keyGeometries: keyGeometries)
        
        let p = point(from: event)
        let ict = inNode.indicatedCellsTuple(with: convertToCurrentLocal(p),
                                             reciprocalScale: scene.reciprocalScale)
        if ict.type == .selected {
            let newCellItems = ict.cellItems.map {
                ($0.cell, addCellIndex(with: newCellItem.cell, in: $0.cell))
            }
            insertCell(newCellItem, in: newCellItems, inNode.editTrack, inNode, time: time)
        } else {
            let newCellItems = [(rootCell, addCellIndex(with: newCellItem.cell, in: rootCell))]
            insertCell(newCellItem, in: newCellItems, inNode.editTrack, inNode, time: time)
        }
        return true
    }
    
    private func addCellIndex(with cell: Cell, in parent: Cell) -> Int {
        let editCells = cut.editNode.editTrack.cells
        for i in (0 ..< parent.children.count).reversed() {
            if editCells.contains(parent.children[i]) && parent.children[i].contains(cell) {
                return i + 1
            }
        }
        for i in 0 ..< parent.children.count {
            if editCells.contains(parent.children[i]) && parent.children[i].intersects(cell) {
                return i
            }
        }
        for i in 0 ..< parent.children.count {
            if editCells.contains(parent.children[i]) && !parent.children[i].isLocked {
                return i
            }
        }
        return cellIndex(withTrackIndex: cut.editNode.editTrackIndex, in: parent)
    }
    
    func cellIndex(withTrackIndex trackIndex: Int, in parent: Cell) -> Int {
        for i in trackIndex + 1 ..< cut.editNode.tracks.count {
            let track = cut.editNode.tracks[i]
            var maxIndex = 0, isMax = false
            for cellItem in track.cellItems {
                if let j = parent.children.index(of: cellItem.cell) {
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
    
    func moveCell(_ cell: Cell, from fromParents: [(cell: Cell, index: Int)],
                  to toParents: [(cell: Cell, index: Int)], in node: Node, time: Beat) {
        registerUndo { $0.moveCell(cell, from: toParents, to: fromParents, in: node, time: $1) }
        self.time = time
        for fromParent in fromParents {
            fromParent.cell.children.remove(at: fromParent.index)
        }
        for toParent in toParents {
            toParent.cell.children.insert(cell, at: toParent.index)
        }
        node.differentialDataModel.isWrite = true
        sceneDataModel?.isWrite = true
        setNeedsDisplay()
    }
    
    func lassoErase(with event: DragEvent) -> Bool {
        _ = stroke(with: event, isAppendLine: false)
        switch event.sendType {
        case .begin:
            break
        case .sending:
            if let line = stroker.line {
                let b = line.visibleImageBounds(withLineWidth: stroker.lineWidth)
                setNeedsDisplay(inCurrentLocalBounds: b)
            }
        case .end:
            if let line = stroker.line {
                lassoErase(with: line)
                stroker.line = nil
            }
        }
        return true
    }
    func lassoErase(with line: Line) {
        let inNode = cut.editNode
        let drawing = inNode.editTrack.drawingItem.drawing, track = inNode.editTrack
        if let index = drawing.lines.index(of: line) {
            removeLine(at: index, in: drawing, inNode, time: time)
        }
        if !drawing.selectedLineIndexes.isEmpty {
            setSelectedLineIndexes([], oldLineIndexes: drawing.selectedLineIndexes,
                                    in: drawing, inNode, time: time)
        }
        var isRemoveLineInDrawing = false, isRemoveLineInCell = false
        let lasso = LineLasso(lines: [line])
        let newDrawingLines = drawing.lines.reduce(into: [Line]()) {
            if let splitLines = lasso.split($1) {
                isRemoveLineInDrawing = true
                $0 += splitLines
            } else {
                $0.append($1)
            }
        }
        if isRemoveLineInDrawing {
            set(newDrawingLines, old: drawing.lines, in: drawing, inNode, time: time)
        }
        var removeCellItems = [CellItem]()
        removeCellItems = track.cellItems.filter { cellItem in
            if cellItem.cell.intersects(lasso) {
                set(Geometry(), old: cellItem.cell.geometry,
                    at: track.animation.editKeyframeIndex, in: cellItem, track, inNode, time: time)
                if cellItem.isEmptyKeyGeometries {
                    return true
                }
                isRemoveLineInCell = true
            }
            return false
        }
        if !isRemoveLineInDrawing && !isRemoveLineInCell {
            if let hitCellItem = inNode.cellItem(at: line.firstPoint,
                                                 reciprocalScale: scene.reciprocalScale,
                                                 with: track) {
                let lines = hitCellItem.cell.geometry.lines
                set(Geometry(), old: hitCellItem.cell.geometry,
                    at: track.animation.editKeyframeIndex,
                    in: hitCellItem, track, inNode, time: time)
                if hitCellItem.isEmptyKeyGeometries {
                    removeCellItems.append(hitCellItem)
                }
                set(drawing.lines + lines, old: drawing.lines,
                         in: drawing, inNode, time: time)
            }
        }
        if !removeCellItems.isEmpty {
            self.removeCellItems(removeCellItems)
        }
    }
    
    private func insertCell(_ cellItem: CellItem,
                            in parents: [(cell: Cell, index: Int)],
                            _ track: NodeTrack, _ node: Node, time: Beat) {
        registerUndo { $0.removeCell(cellItem, in: parents, track, node, time: $1) }
        self.time = time
        track.insertCell(cellItem, in: parents)
        node.differentialDataModel.isWrite = true
        sceneDataModel?.isWrite = true
        setNeedsDisplay()
    }
    private func removeCell(_ cellItem: CellItem,
                            in parents: [(cell: Cell, index: Int)],
                            _ track: NodeTrack, _ node: Node, time: Beat) {
        registerUndo { $0.insertCell(cellItem, in: parents, track, node, time: $1) }
        self.time = time
        track.removeCell(cellItem, in: parents)
        node.differentialDataModel.isWrite = true
        sceneDataModel?.isWrite = true
        setNeedsDisplay()
    }
    private func insertCells(_ cellItems: [CellItem], rootCell: Cell,
                             at index: Int, in parent: Cell,
                             _ track: NodeTrack, _ node: Node, time: Beat) {
        registerUndo {
            $0.removeCells(cellItems, rootCell: rootCell, at: index, in: parent, track, node, time: $1)
        }
        self.time = time
        track.insertCells(cellItems, rootCell: rootCell, at: index, in: parent)
        node.differentialDataModel.isWrite = true
        sceneDataModel?.isWrite = true
        setNeedsDisplay()
    }
    private func removeCells(_ cellItems: [CellItem], rootCell: Cell,
                             at index: Int, in parent: Cell,
                             _ track: NodeTrack, _ node: Node, time: Beat) {
        registerUndo {
            $0.insertCells(cellItems, rootCell: rootCell, at: index, in: parent, track, node, time: $1)
        }
        self.time = time
        track.removeCells(cellItems, rootCell: rootCell, in: parent)
        node.differentialDataModel.isWrite = true
        sceneDataModel?.isWrite = true
        setNeedsDisplay()
    }
    
    func translucentLockCell(at point: CGPoint) {
        let seletionCells = cut.editNode.indicatedCellsTuple(with: convertToCurrentLocal(point),
                                                             reciprocalScale: scene.reciprocalScale)
        for cellItem in seletionCells.cellItems {
            if !cellItem.cell.isLocked {
                setIsLocked(true, in: cellItem.cell, time: time)
            }
        }
    }
    func unlockAllCells() {
        cut.editNode.rootCell.allCells { cell, stop in
            if cell.isLocked {
                setIsLocked(false, in: cell, time: time)
            }
        }
    }
    func setIsLocked(_ isLocked: Bool, in cell: Cell, time: Beat) {
        registerUndo { [oldIsLocked = cell.isLocked] in
            $0.setIsLocked(oldIsLocked, in: cell, time: $1)
        }
        self.time = time
        cell.isLocked = isLocked
        sceneDataModel?.isWrite = true
        setNeedsDisplay()
        if cell == cellView.cell {
            cellView.updateWithCell()
        }
    }
    
    func changeToDraft() {
        let inNode = cut.editNode
        let indexes = inNode.editTrack.animation.selectedKeyframeIndexes.sorted()
        let i = inNode.editTrack.animation.editKeyframeIndex
        (indexes.contains(i) ? indexes : [i]).forEach {
            let drawing = inNode.editTrack.drawingItem.keyDrawings[$0]
            if !drawing.draftLines.isEmpty || !drawing.lines.isEmpty {
                setDraftLines(drawing.editLines, old: drawing.draftLines,
                              in: drawing, inNode, time: time)
                set(drawing.uneditLines, old: drawing.lines, in: drawing, inNode, time: time)
                if !drawing.selectedLineIndexes.isEmpty {
                    setSelectedLineIndexes([], oldLineIndexes: drawing.selectedLineIndexes,
                                            in: drawing, inNode, time: time)
                }
            }
        }
    }
    func removeDraft() {
        let inNode = cut.editNode
        let indexes = inNode.editTrack.animation.selectedKeyframeIndexes.sorted()
        let i = inNode.editTrack.animation.editKeyframeIndex
        (indexes.contains(i) ? indexes : [i]).forEach {
            let drawing = inNode.editTrack.drawingItem.keyDrawings[$0]
            if !drawing.draftLines.isEmpty {
                setDraftLines([], old: drawing.draftLines, in: drawing, inNode, time: time)
            }
        }
    }
    func exchangeWithDraft() {
        let inNode = cut.editNode
        let indexes = inNode.editTrack.animation.selectedKeyframeIndexes.sorted()
        let i = inNode.editTrack.animation.editKeyframeIndex
        (indexes.contains(i) ? indexes : [i]).forEach {
            let drawing = inNode.editTrack.drawingItem.keyDrawings[$0]
            if !drawing.draftLines.isEmpty || !drawing.lines.isEmpty {
                if !drawing.selectedLineIndexes.isEmpty {
                    setSelectedLineIndexes([], oldLineIndexes: drawing.selectedLineIndexes,
                                            in: drawing, inNode, time: time)
                }
                let newLines = drawing.draftLines, newDraftLines = drawing.lines
                setDraftLines(newDraftLines, old: drawing.draftLines,
                              in: drawing, inNode, time: time)
                set(newLines, old: drawing.lines, in: drawing, inNode, time: time)
            }
        }
    }
    var setDraftLinesClosure: ((Canvas, Drawing) -> ())? = nil
    private func setDraftLines(_ lines: [Line], old oldLines: [Line],
                               in drawing: Drawing, _ node: Node, time: Beat) {
        registerUndo { $0.setDraftLines(oldLines, old: lines, in: drawing, node, time: $1) }
        self.time = time
        drawing.draftLines = lines
        node.differentialDataModel.isWrite = true
        setNeedsDisplay()
        setDraftLinesClosure?(self, drawing)
    }
    private func set(_ lines: [Line], old oldLines: [Line],
                          in drawing: Drawing, _ node: Node, time: Beat) {
        registerUndo { $0.set(oldLines, old: lines, in: drawing, node, time: $1) }
        self.time = time
        drawing.lines = lines
        node.differentialDataModel.isWrite = true
        setNeedsDisplay()
    }
    
    private let polygonRadius = 50.0.cf
    func appendTriangleLines() {
        let lines = regularPolygonLinesWith(centerPosition: CGPoint(x: bounds.midX, y: bounds.midY),
                                            radius: polygonRadius, count: 3)
        append(lines, duplicatedTranslation: CGPoint(x: polygonRadius * 2 + Layout.basicPadding, y: 0))
    }
    func appendSquareLines() -> Bool {
        let r = polygonRadius
        let cp = CGPoint(x: bounds.midX, y: bounds.midY)
        let p0 = CGPoint(x: cp.x - r, y: cp.y - r), p1 = CGPoint(x: cp.x + r, y: cp.y - r)
        let p2 = CGPoint(x: cp.x - r, y: cp.y + r), p3 = CGPoint(x: cp.x + r, y: cp.y + r)
        let l0 = Line(controls: [Line.Control(point: p0, pressure: 1),
                                 Line.Control(point: p1, pressure: 1)])
        let l1 = Line(controls: [Line.Control(point: p1, pressure: 1),
                                 Line.Control(point: p3, pressure: 1)])
        let l2 = Line(controls: [Line.Control(point: p3, pressure: 1),
                                 Line.Control(point: p2, pressure: 1)])
        let l3 = Line(controls: [Line.Control(point: p2, pressure: 1),
                                 Line.Control(point: p0, pressure: 1)])
        append([l0, l1, l2, l3], duplicatedTranslation: CGPoint(x: r * 2 + Layout.basicPadding, y: 0))
        return true
    }
    func appendPentagonLines() -> Bool {
        let lines = regularPolygonLinesWith(centerPosition: CGPoint(x: bounds.midX, y: bounds.midY),
                                            radius: polygonRadius, count: 5)
        append(lines, duplicatedTranslation: CGPoint(x: polygonRadius * 2 + Layout.basicPadding, y: 0))
        return true
    }
    func appendHexagonLines() -> Bool {
        let lines = regularPolygonLinesWith(centerPosition: CGPoint(x: bounds.midX, y: bounds.midY),
                                            radius: polygonRadius, count: 6)
        append(lines, duplicatedTranslation: CGPoint(x: polygonRadius * 2 + Layout.basicPadding, y: 0))
        return true
    }
    func appendCircleLines() -> Bool {
        let count = 8, r = polygonRadius
        let theta = .pi / count.cf
        let cp = CGPoint(x: bounds.midX, y: bounds.midY)
        let fp = CGPoint(x: cp.x, y: cp.y + polygonRadius)
        let points = circlePointsWith(centerPosition: cp,
                                      radius: r / cos(theta),
                                      firstAngle: .pi / 2 + theta,
                                      count: count)
        let newPoints = [fp] + points + [fp]
        let line = Line(controls: newPoints.map { Line.Control(point: $0, pressure: 1) })
        append([line],
               duplicatedTranslation: CGPoint(x: polygonRadius * 2 + Layout.basicPadding, y: 0))
        return true
    }
    func regularPolygonLinesWith(centerPosition cp: CGPoint, radius r: CGFloat,
                                 firstAngle: CGFloat = .pi / 2, count: Int) -> [Line] {
        let points = circlePointsWith(centerPosition: cp, radius: r,
                                      firstAngle: firstAngle, count: count)
        return points.enumerated().map {
            let p0 = $0.element, i = $0.offset
            let p1 = i + 1 < points.count ? points[i + 1] : points[0]
            return Line(controls: [Line.Control(point: p0, pressure: 1),
                                   Line.Control(point: p1, pressure: 1)])
        }
    }
    func circlePointsWith(centerPosition cp: CGPoint, radius r: CGFloat,
                          firstAngle: CGFloat = .pi / 2, count: Int) -> [CGPoint] {
        var angle = firstAngle, theta = (2 * .pi) / count.cf
        return (0 ..< count).map { _ in
            let p = CGPoint(x: cp.x + r * cos(angle), y: cp.y + r * sin(angle))
            angle += theta
            return p
        }
    }
    func append(_ lines: [Line], duplicatedTranslation dtp: CGPoint) {
        let inNode = cut.editNode
        let affineTransform = currentTransform.inverted()
        let transformedLines = affineTransform.isIdentity ?
            lines : lines.map { $0.applying(affineTransform) }
        let drawing = inNode.editTrack.drawingItem.drawing
        let newLines: [Line] = {
            if drawing.intersects(transformedLines) {
                var p = dtp, moveLines = lines
                repeat {
                    let moveAffine = CGAffineTransform(translationX: p.x, y: p.y)
                    moveLines = lines.map { $0.applying(moveAffine).applying(affineTransform) }
                    p += dtp
                } while drawing.intersects(moveLines)
                return drawing.lines + moveLines
            } else {
                return drawing.lines + transformedLines
            }
        } ()
        set(newLines, old: drawing.lines, in: drawing, inNode, time: time)
    }
    
    func moveCursor(with event: MoveCursorEvent) -> Bool {
        updateEditView(with: convertToCurrentLocal(point(from: event)))
        return true
    }
    
    var editCell: Cell?
    var (editCellLineLayer, subEditCellLineLayer): (PathLayer, PathLayer) = {
        let layer = PathLayer()
        layer.lineColor = .subSelected
        layer.lineWidth = 3
        let sublayer = PathLayer()
        sublayer.lineColor = .selected
        sublayer.lineWidth = 1
        layer.append(child: sublayer)
        return (layer, sublayer)
    } ()
    private let bindingLineHeight = 5.0.cf
    let editCellBindingLineLayer: PathLayer = {
        let layer = PathLayer()
        layer.fillColor = .bindingBorder
        return layer
    } ()
    
    func isVisible(_ cell: Cell) -> Bool {
        return cell.intersects(bounds.applying(currentTransform.inverted()))
    }
    
    let materialView = MaterialView(), cellView = CellView(sizeType: .small)
    func bind(with event: SubClickEvent) -> Bool {
        let p = convertToCurrentLocal(point(from: event))
        let ict = cut.editNode.indicatedCellsTuple(with: p, reciprocalScale: scene.reciprocalScale)
        if let cell = ict.cellItems.first?.cell {
            bind(cut.editNode.editTrack.keyMaterial(with: cell), cell, time: time)
        } else {
            bind(materialView.defaultMaterial, nil, time: time)
        }
        return true
    }
    var bindClosure: ((Canvas, Material, Cell?) -> ())?
    func bind(_ material: Material, _ editCell: Cell?, time: Beat) {
        registerUndo { [oec = editCell] in $0.bind($0.materialView.material, oec, time: $1) }
        self.time = time
        materialView.material = material
        cellView.cell = editCell ?? Cell()
        self.editCell = editCell
        updateEditCellBindingLine()
        bindClosure?(self, material, editCell)
    }
    
    func updateEditCellBindingLine() {
        let maxX = materialView.frame.minX
        let width = maxX - frame.maxX, midY = frame.midY
        if let editCell = editCell, !editCell.isEmpty && isVisible(editCell) {
            let path = CGPath(rect: CGRect(x: frame.maxX,
                                           y: midY - bindingLineHeight / 2,
                                           width: width,
                                           height: bindingLineHeight), transform: nil)
            editCellBindingLineLayer.fillColor = .bindingBorder
            editCellBindingLineLayer.path = path
            
            let fp = CGPoint(x: bounds.maxX, y: bounds.midY)
            if let n = editCell.geometry.nearestBezier(with: fp) {
                let np = editCell.geometry.lines[n.lineIndex]
                    .bezier(at: n.bezierIndex).position(withT: n.t)
                let p = np.applying(currentTransform)
                if bounds.contains(p) {
                    if editCellLineLayer.parent == nil {
                        append(child: editCellLineLayer)
                    }
                    let path = CGMutablePath()
                    path.move(to: fp)
                    path.addLine(to: CGPoint(x: p.x, y: bounds.midY))
                    path.addLine(to: p)
                    editCellLineLayer.path = path
                    subEditCellLineLayer.path = path
                } else {
                    editCellLineLayer.removeFromParent()
                }
            }
        } else {
            editCellBindingLineLayer.fillColor = .warning
            let path = CGMutablePath()
            path.move(to: CGPoint(x: frame.maxX, y: midY))
            path.addLine(to: CGPoint(x: maxX, y: midY - bindingLineHeight / 2))
            path.addLine(to: CGPoint(x: maxX, y: midY + bindingLineHeight / 2))
            path.closeSubpath()
            editCellBindingLineLayer.path = path
            
            editCellLineLayer.removeFromParent()
        }
    }
    
    private struct SelectOption {
        var selectedLineIndexes = [Int](), selectedCellItems = [CellItem]()
        var node: Node?, drawing: Drawing?, track: NodeTrack?
    }
    private var selectOption = SelectOption()
    func select(with event: DragEvent) -> Bool {
        return select(with: event, isDeselect: false)
    }
    func deselect(with event: DragEvent) -> Bool {
        return select(with: event, isDeselect: true)
    }
    func select(with event: DragEvent, isDeselect: Bool) -> Bool {
        _ = stroke(with: event, isAppendLine: false)
        
        func unionWithStrokeLine(with drawing: Drawing,
                                 _ track: NodeTrack) -> (lineIndexes: [Int], cellItems: [CellItem]) {
            func selected() -> (lineIndexes: [Int], cellItems: [CellItem]) {
                guard let line = stroker.line else {
                    return ([], [])
                }
                let lasso = LineLasso(lines: [line])
                return (drawing.lines.enumerated().compactMap { lasso.intersects($1) ? $0 : nil },
                        track.cellItems.filter { $0.cell.intersects(lasso) })
            }
            let s = selected()
            if isDeselect {
                return (Array(Set(selectOption.selectedLineIndexes).subtracting(Set(s.lineIndexes))),
                        Array(Set(selectOption.selectedCellItems).subtracting(Set(s.cellItems))))
            } else {
                return (Array(Set(selectOption.selectedLineIndexes).union(Set(s.lineIndexes))),
                        Array(Set(selectOption.selectedCellItems).union(Set(s.cellItems))))
            }
        }
        
        switch event.sendType {
        case .begin:
            selectOption.node = cut.editNode
            let drawing = cut.editNode.editTrack.drawingItem.drawing, track = cut.editNode.editTrack
            selectOption.drawing = drawing
            selectOption.track = track
            selectOption.selectedLineIndexes = drawing.selectedLineIndexes
            selectOption.selectedCellItems = track.selectedCellItems
        case .sending:
            guard let drawing = selectOption.drawing, let track = selectOption.track else {
                return true
            }
            (drawing.selectedLineIndexes, track.selectedCellItems)
                = unionWithStrokeLine(with: drawing, track)
        case .end:
            guard let drawing = selectOption.drawing,
                let track = selectOption.track, let node = selectOption.node else {
                    return true
            }
            let (selectedLineIndexes, selectedCellItems)
                = unionWithStrokeLine(with: drawing, track)
            if selectedLineIndexes != selectOption.selectedLineIndexes {
                setSelectedLineIndexes(selectedLineIndexes,
                                        oldLineIndexes: selectOption.selectedLineIndexes,
                                        in: drawing, node, time: time)
            }
            if selectedCellItems != selectOption.selectedCellItems {
                setSelectedCellItems(selectedCellItems,
                                      oldCellItems: selectOption.selectedCellItems,
                                      in: track, time: time)
            }
            self.selectOption = SelectOption()
            self.stroker.line = nil
        }
        setNeedsDisplay()
        return true
    }
    
    private struct Stroker {
        var line: Line?
        var lineWidth = DrawingItem.defaultLineWidth, lineColor = Color.strokeLine
        
        struct Temp {
            var control: Line.Control, speed: CGFloat
        }
        var temps: [Temp] = []
        var oldPoint = CGPoint(), tempDistance = 0.0.cf, oldLastBounds = CGRect()
        var beginTime = 0.0, oldTime = 0.0, oldTempTime = 0.0
        
        var join = Join()
        struct Join {
            var lowAngle = 0.8 * (.pi / 2.0).cf, angle = 1.5 * (.pi / 2.0).cf
            func joinControlWith(_ line: Line, lastControl lc: Line.Control) -> Line.Control? {
                guard line.controls.count >= 4 else {
                    return nil
                }
                let c0 = line.controls[line.controls.count - 4]
                let c1 = line.controls[line.controls.count - 3], c2 = lc
                guard c0.point != c1.point && c1.point != c2.point else {
                    return nil
                }
                let dr = abs(CGPoint.differenceAngle(p0: c0.point, p1: c1.point, p2: c2.point))
                if dr > angle {
                    return c1
                } else if dr > lowAngle {
                    let t = 1 - (dr - lowAngle) / (angle - lowAngle)
                    return Line.Control(point: CGPoint.linear(c1.point, c2.point, t: t),
                                        pressure: CGFloat.linear(c1.pressure, c2.pressure, t: t))
                } else {
                    return nil
                }
            }
        }
        
        var interval = Interval()
        struct Interval {
            var minSpeed = 100.0.cf, maxSpeed = 1500.0.cf, exp = 2.0.cf, minTime = 0.1, maxTime = 0.03
            var minDistance = 1.45.cf, maxDistance = 1.5.cf
            func speedTWith(distance: CGFloat, deltaTime: Double, scale: CGFloat) -> CGFloat {
                let speed = ((distance / scale) / deltaTime.cf).clip(min: minSpeed, max: maxSpeed)
                return pow((speed - minSpeed) / (maxSpeed - minSpeed), 1 / exp)
            }
            func isAppendPointWith(distance: CGFloat, deltaTime: Double,
                                   _ temps: [Temp], scale: CGFloat) -> Bool {
                guard deltaTime > 0 else {
                    return false
                }
                let t = speedTWith(distance: distance, deltaTime: deltaTime, scale: scale)
                let time = minTime + (maxTime - minTime) * t.d
                return deltaTime > time || isAppendPointWith(temps, scale: scale)
            }
            private func isAppendPointWith(_ temps: [Temp], scale: CGFloat) -> Bool {
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
            var minTime = 0.1, linearMaxDistance = 1.5.cf
            func shortedLineWith(_ line: Line, deltaTime: Double, scale: CGFloat) -> Line {
                guard deltaTime < minTime && line.controls.count > 3 else {
                    return line
                }
                
                var maxD = 0.0.cf, maxControl = line.controls[0]
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
                line.allEditPoints { p, i in
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
//    func move(with event: DragEvent) -> Bool {
//        return stroke(with: event)
//    }
    func stroke(with event: DragEvent) -> Bool {
        return stroke(with: event, isAppendLine: true)
    }
    func stroke(with event: DragEvent, isAppendLine: Bool) -> Bool {
        let p = convertToCurrentLocal(point(from: event)), scale = scene.scale
        switch event.sendType {
        case .begin:
            let fc = Line.Control(point: p, pressure: event.pressure)
            stroker.line = Line(controls: [fc, fc, fc])
            stroker.oldPoint = p
            stroker.oldTime = event.time
            stroker.oldTempTime = event.time
            stroker.tempDistance = 0
            stroker.temps = [Stroker.Temp(control: fc, speed: 0)]
            stroker.beginTime = event.time
        case .sending:
            guard var line = stroker.line, p != stroker.oldPoint else {
                return true
            }
            let d = p.distance(stroker.oldPoint)
            stroker.tempDistance += d
            
            let pressure = (stroker.temps.first!.control.pressure + event.pressure) / 2
            let rc = Line.Control(point: line.controls[line.controls.count - 3].point,
                                  pressure: pressure)
            line = line.withReplaced(rc, at: line.controls.count - 3)
            set(line)
            
            let speed = d / (event.time - stroker.oldTime).cf
            stroker.temps.append(Stroker.Temp(control: Line.Control(point: p,
                                                                    pressure: event.pressure),
                                              speed: speed))
            let lPressure = stroker.temps.reduce(0.0.cf) { $0 + $1.control.pressure }
                / stroker.temps.count.cf
            let lc = Line.Control(point: p, pressure: lPressure)
            
            let mlc = lc.mid(stroker.temps[stroker.temps.count - 2].control)
            if let jc = stroker.join.joinControlWith(line, lastControl: mlc) {
                line = line.withInsert(jc, at: line.controls.count - 2)
                set(line, updateBounds: line.strokeLastBoundingBox)
                stroker.temps = [Stroker.Temp(control: lc, speed: speed)]
                stroker.oldTempTime = event.time
                stroker.tempDistance = 0
            } else if stroker.interval.isAppendPointWith(distance: stroker.tempDistance / scale,
                                                         deltaTime: event.time - stroker.oldTempTime,
                                                         stroker.temps,
                                                         scale: scale) {
                line = line.withInsert(lc, at: line.controls.count - 2)
                set(line, updateBounds: line.strokeLastBoundingBox)
                stroker.temps = [Stroker.Temp(control: lc, speed: speed)]
                stroker.oldTempTime = event.time
                stroker.tempDistance = 0
            }
            
            line = line.withReplaced(lc, at: line.controls.count - 2)
            line = line.withReplaced(lc, at: line.controls.count - 1)
            set(line, updateBounds: line.strokeLastBoundingBox)
            
            stroker.oldTime = event.time
            stroker.oldPoint = p
        case .end:
            guard var line = stroker.line else {
                return true
            }
            if !stroker.interval.isAppendPointWith(distance: stroker.tempDistance / scale,
                                                   deltaTime: event.time - stroker.oldTempTime,
                                                   stroker.temps,
                                                   scale: scale) {
                line = line.withRemoveControl(at: line.controls.count - 2)
            }
            line = line.withReplaced(Line.Control(point: p, pressure: line.controls.last!.pressure),
                                     at: line.controls.count - 1)
            line = stroker.short.shortedLineWith(line, deltaTime: event.time - stroker.beginTime,
                                                 scale: scale)
            if isAppendLine {
                let node = cut.editNode
                addLine(line, in: node.editTrack.drawingItem.drawing, node, time: time)
                stroker.line = nil
            } else {
                stroker.line = line
            }
        }
        return true
    }
    private func set(_ line: Line) {
        stroker.line = line
        let lastBounds = line.visibleImageBounds(withLineWidth: stroker.lineWidth)
        let ub = lastBounds.union(stroker.oldLastBounds)
        let b = Line.visibleImageBoundsWith(imageBounds: ub, lineWidth: stroker.lineWidth)
        setNeedsDisplay(inCurrentLocalBounds: b)
        stroker.oldLastBounds = lastBounds
    }
    private func set(_ line: Line, updateBounds lastBounds: CGRect) {
        stroker.line = line
        let ub = lastBounds.union(stroker.oldLastBounds)
        let b = Line.visibleImageBoundsWith(imageBounds: ub, lineWidth: stroker.lineWidth)
        setNeedsDisplay(inCurrentLocalBounds: b)
        stroker.oldLastBounds = lastBounds
    }
    
    private func addLine(_ line: Line, in drawing: Drawing, _ node: Node, time: Beat) {
        registerUndo { $0.removeLastLine(in: drawing, node, time: $1) }
        self.time = time
        drawing.lines.append(line)
        node.differentialDataModel.isWrite = true
        setNeedsDisplay()
    }
    private func removeLastLine(in drawing: Drawing, _ node: Node, time: Beat) {
        registerUndo { [lastLine = drawing.lines.last!] in
            $0.addLine(lastLine, in: drawing, node, time: $1)
        }
        self.time = time
        drawing.lines.removeLast()
        node.differentialDataModel.isWrite = true
        setNeedsDisplay()
    }
    private func insertLine(_ line: Line, at i: Int, in drawing: Drawing, _ node: Node, time: Beat) {
        registerUndo { $0.removeLine(at: i, in: drawing, node, time: $1) }
        self.time = time
        drawing.lines.insert(line, at: i)
        node.differentialDataModel.isWrite = true
        setNeedsDisplay()
    }
    private func removeLine(at i: Int, in drawing: Drawing, _ node: Node, time: Beat) {
        let oldLine = drawing.lines[i]
        registerUndo { $0.insertLine(oldLine, at: i, in: drawing, node, time: $1) }
        self.time = time
        drawing.lines.remove(at: i)
        node.differentialDataModel.isWrite = true
        setNeedsDisplay()
    }
    private func setSelectedLineIndexes(_ lineIndexes: [Int], oldLineIndexes: [Int],
                                         in drawing: Drawing, _ node: Node, time: Beat) {
        registerUndo {
            $0.setSelectedLineIndexes(oldLineIndexes, oldLineIndexes: lineIndexes,
                                      in: drawing, node, time: $1)
        }
        self.time = time
        drawing.selectedLineIndexes = lineIndexes
        node.differentialDataModel.isWrite = true
        setNeedsDisplay()
    }
    
    func selectCell(at point: CGPoint) {
        let p = convertToCurrentLocal(point)
        let selectedCell = cut.editNode.rootCell.at(p, reciprocalScale: scene.reciprocalScale)
        if let selectedCell = selectedCell {
            if selectedCell.material.id != materialView.material.id {
                setMaterial(selectedCell.material, time: time)
            }
        } else {
            if materialView.defaultMaterial != materialView.material {
                setMaterial(materialView.defaultMaterial, time: time)
            }
        }
    }
    private func setMaterial(_ material: Material, time: Beat) {
        registerUndo { [om = materialView.material] in $0.setMaterial(om, time: $1) }
        self.time = time
        materialView.material = material
    }
    private func setSelectedCellItems(_ cellItems: [CellItem], oldCellItems: [CellItem],
                                       in track: NodeTrack, time: Beat) {
        registerUndo {
            $0.setSelectedCellItems(oldCellItems, oldCellItems: cellItems, in: track, time: $1)
        }
        self.time = time
        track.selectedCellItems = cellItems
        setNeedsDisplay()
        sceneDataModel?.isWrite = true
        setNeedsDisplay()
    }
    
    func insertPoint(with event: KeyInputEvent) -> Bool {
        let p = convertToCurrentLocal(point(from: event)), inNode = cut.editNode
        guard let nearest = inNode.nearestLine(at: p) else {
            return true
        }
        if let drawing = nearest.drawing {
            replaceLine(nearest.line.splited(at: nearest.pointIndex), oldLine: nearest.line,
                        at: nearest.lineIndex, in: drawing, in: inNode, time: time)
            cut.updateWithCurrentTime()
            updateEditView(with: p)
        } else if let cellItem = nearest.cellItem {
            let newGeometries = Geometry.geometriesWithSplitedControl(with: cellItem.keyGeometries,
                                                                      at: nearest.lineIndex,
                                                                      pointIndex: nearest.pointIndex)
            setGeometries(newGeometries, oldKeyGeometries: cellItem.keyGeometries,
                          in: cellItem, inNode.editTrack, inNode, time: time)
            cut.updateWithCurrentTime()
            updateEditView(with: p)
        }
        return true
    }
    func removePoint(with event: KeyInputEvent) -> Bool {
        let p = convertToCurrentLocal(point(from: event)), inNode = cut.editNode
        guard let nearest = inNode.nearestLine(at: p) else {
            return true
        }
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
        } else if let cellItem = nearest.cellItem {
            setGeometries(Geometry.geometriesWithRemovedControl(with: cellItem.keyGeometries,
                                                                atLineIndex: nearest.lineIndex,
                                                                index: nearest.pointIndex),
                          oldKeyGeometries: cellItem.keyGeometries,
                          in: cellItem, inNode.editTrack, inNode, time: time)
            if cellItem.isEmptyKeyGeometries {
                removeCellItems([cellItem])
            }
            cut.updateWithCurrentTime()
            updateEditView(with: p)
        }
        return true
    }
    private func insert(_ control: Line.Control, at index: Int,
                        in drawing: Drawing, atLineIndex li: Int, _ node: Node, time: Beat) {
        registerUndo { $0.removeControl(at: index, in: drawing, atLineIndex: li, node, time: $1) }
        self.time = time
        drawing.lines[li] = drawing.lines[li].withInsert(control, at: index)
        node.differentialDataModel.isWrite = true
        setNeedsDisplay()
    }
    private func removeControl(at index: Int,
                               in drawing: Drawing, atLineIndex li: Int, _ node: Node, time: Beat) {
        let line = drawing.lines[li]
        registerUndo { [oc = line.controls[index]] in
            $0.insert(oc, at: index, in: drawing, atLineIndex: li, node, time: $1)
        }
        self.time = time
        drawing.lines[li] = line.withRemoveControl(at: index)
        node.differentialDataModel.isWrite = true
        setNeedsDisplay()
    }
    
    private var movePointNearest: Node.Nearest?, movePointOldPoint = CGPoint(), movePointIsSnap = false
    private weak var movePointNode: Node?
    private let snapPointSnapDistance = 8.0.cf
    private var bezierSortedResult: Node.Nearest.BezierSortedResult?
    func movePoint(with event: DragEvent) -> Bool {
        return movePoint(with: event, isVertex: false)
    }
    func moveVertex(with event: DragEvent) -> Bool {
        return movePoint(with: event, isVertex: true)
    }
    func movePoint(with event: DragEvent, isVertex: Bool) -> Bool {
        let p = convertToCurrentLocal(point(from: event))
        switch event.sendType {
        case .begin:
            if let nearest = cut.editNode.nearest(at: p, isVertex: isVertex) {
                bezierSortedResult = nearest.bezierSortedResult(at: p)
                movePointNearest = nearest
                movePointNode = cut.editNode
                movePointIsSnap = false
            }
            updateEditView(with: p)
            movePointNode = cut.editNode
            movePointOldPoint = p
        case .sending:
            let dp = p - movePointOldPoint
            movePointIsSnap = movePointIsSnap ? true : event.pressure == 1
            
            if let nearest = movePointNearest {
                if nearest.drawingEdit != nil || nearest.cellItemEdit != nil {
                    movingPoint(with: nearest, dp: dp, in: cut.editNode.editTrack)
                } else {
                    if movePointIsSnap, let b = bezierSortedResult {
                        movingPoint(with: nearest, bezierSortedResult: b, dp: dp,
                                    isVertex: isVertex, in: cut.editNode.editTrack)
                    } else {
                        movingLineCap(with: nearest, dp: dp,
                                      isVertex: isVertex, in: cut.editNode.editTrack)
                    }
                }
            }
        case .end:
            let dp = p - movePointOldPoint
            if let nearest = movePointNearest, let node = movePointNode {
                if nearest.drawingEdit != nil || nearest.cellItemEdit != nil {
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
        return true
    }
    private func movingPoint(with nearest: Node.Nearest, dp: CGPoint, in track: NodeTrack) {
        let snapD = snapPointSnapDistance / scene.scale
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
            e.drawing.lines[e.lineIndex] = e.line.withReplaced(control, at: e.pointIndex)
            let np = e.drawing.lines[e.lineIndex].editCenterPoint(at: e.pointIndex)
            editPoint = Node.EditPoint(nearestLine: e.drawing.lines[e.lineIndex],
                                       nearestPointIndex: e.pointIndex,
                                       lines: [e.drawing.lines[e.lineIndex]],
                                       point: np,
                                       isSnap: movePointIsSnap)
        } else if let e = nearest.cellItemEdit {
            let line = e.geometry.lines[e.lineIndex]
            var control = line.controls[e.pointIndex]
            control.point = line.editPoint(withEditCenterPoint: nearest.point + dp, at: e.pointIndex)
            if movePointIsSnap && (e.pointIndex == 1 || e.pointIndex == line.controls.count - 2) {
                control.point = track.snapPoint(control.point,
                                                editLine: e.cellItem.cell.geometry.lines[e.lineIndex],
                                                editPointIndex: e.pointIndex,
                                                snapDistance: snapD)
            }
            let newLine = line.withReplaced(control, at: e.pointIndex).autoPressure()
            
            let i = cut.editNode.editTrack.animation.editKeyframeIndex
            e.cellItem.replace(Geometry(lines: e.geometry.lines.withReplaced(newLine,
                                                                             at: e.lineIndex)), at: i)
            track.updateInterpolation()
            
            let np = e.cellItem.cell.geometry.lines[e.lineIndex].editCenterPoint(at: e.pointIndex)
            editPoint = Node.EditPoint(nearestLine: e.cellItem.cell.geometry.lines[e.lineIndex],
                                       nearestPointIndex: e.pointIndex,
                                       lines: [e.cellItem.cell.geometry.lines[e.lineIndex]],
                                       point: np, isSnap: movePointIsSnap)
            
        }
    }
    private func movedPoint(with nearest: Node.Nearest, dp: CGPoint,
                            in track: NodeTrack, _ node: Node) {
        let snapD = snapPointSnapDistance / scene.scale
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
            replaceLine(e.line.withReplaced(control, at: e.pointIndex), oldLine: e.line,
                        at: e.lineIndex, in: e.drawing, in: node, time: time)
        } else if let e = nearest.cellItemEdit {
            let line = e.geometry.lines[e.lineIndex]
            var control = line.controls[e.pointIndex]
            control.point = line.editPoint(withEditCenterPoint: nearest.point + dp,
                                           at: e.pointIndex)
            if movePointIsSnap && (e.pointIndex == 1 || e.pointIndex == line.controls.count - 2) {
                control.point = track.snapPoint(control.point,
                                                editLine: e.cellItem.cell.geometry.lines[e.lineIndex],
                                                editPointIndex: e.pointIndex,
                                                snapDistance: snapD)
            }
            let newLine = line.withReplaced(control, at: e.pointIndex).autoPressure()
            set(Geometry(lines: e.geometry.lines.withReplaced(newLine, at: e.lineIndex)),
                old: e.geometry,
                at: track.animation.editKeyframeIndex,
                in: e.cellItem, track, node,
                time: time)
        }
    }
    
    private func movingPoint(with nearest: Node.Nearest,
                             bezierSortedResult b: Node.Nearest.BezierSortedResult,
                             dp: CGPoint, isVertex: Bool, in track: NodeTrack) {
        let snapD = snapPointSnapDistance * scene.reciprocalScale
        let grid = 5 * scene.reciprocalScale
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
            drawing.lines = newLines
            editPoint = Node.EditPoint(nearestLine: drawing.lines[b.lineCap.lineIndex],
                                       nearestPointIndex: b.lineCap.pointIndex,
                                       lines: e.drawingCaps.map { drawing.lines[$0.lineIndex] },
                                       point: np,
                                       isSnap: movePointIsSnap)
        } else if let cellItem = b.cellItem, let geometry = b.geometry {
            for editLineCap in nearest.cellItemEditLineCaps {
                if editLineCap.cellItem == cellItem {
                    if b.lineCap.line.controls.count == 2 {
                        let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                        var control = b.lineCap.line.controls[pointIndex]
                        let line = cellItem.cell.geometry.lines[b.lineCap.lineIndex]
                        control.point = track.snapPoint(np,
                                                        editLine: line,
                                                        editPointIndex: pointIndex,
                                                        snapDistance: snapD)
                        let newBLine = b.lineCap.line.withReplaced(control,
                                                                   at: pointIndex).autoPressure()
                        let newLines = geometry.lines.withReplaced(newBLine,
                                                                   at: b.lineCap.lineIndex)
                        cellItem.cell.geometry = Geometry(lines: newLines)
                        np = control.point
                    } else if isVertex {
                        let warpedLine = b.lineCap.line.warpedWith(deltaPoint: np - nearest.point,
                                                                   isFirst: b.lineCap.isFirst)
                        let newLine = warpedLine.autoPressure()
                        let lines = geometry.lines.withReplaced(newLine, at: b.lineCap.lineIndex)
                        cellItem.cell.geometry = Geometry(lines: lines)
                    } else {
                        let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                        var control = geometry.lines[b.lineCap.lineIndex].controls[pointIndex]
                        control.point = np
                        let newLine = b.lineCap.line.withReplaced(control,
                                                                  at: pointIndex).autoPressure()
                        let newLines = geometry.lines.withReplaced(newLine, at: b.lineCap.lineIndex)
                        
                        let i = cut.editNode.editTrack.animation.editKeyframeIndex
                        cellItem.replace(Geometry(lines: newLines), at: i)
                    }
                } else {
                    editLineCap.cellItem.cell.geometry = editLineCap.geometry
                }
            }
            track.updateInterpolation()
            
            let newLines = nearest.cellItemEditLineCaps.reduce(into: [Line]()) {
                $0 += $1.caps.map { cellItem.cell.geometry.lines[$0.lineIndex] }
            }
            editPoint = Node.EditPoint(nearestLine: cellItem.cell.geometry.lines[b.lineCap.lineIndex],
                                       nearestPointIndex: b.lineCap.pointIndex,
                                       lines: newLines,
                                       point: np,
                                       isSnap: movePointIsSnap)
        }
    }
    private func movedPoint(with nearest: Node.Nearest,
                            bezierSortedResult b: Node.Nearest.BezierSortedResult,
                            dp: CGPoint, isVertex: Bool, in track: NodeTrack, _ node: Node) {
        let snapD = snapPointSnapDistance * scene.reciprocalScale
        let grid = 5 * scene.reciprocalScale
        let np = track.snapPoint(nearest.point + dp, with: b, snapDistance: snapD, grid: grid)
        if let e = nearest.drawingEditLineCap, let drawing = b.drawing {
            var newLines = e.lines
            if b.lineCap.line.controls.count == 2 {
                let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                var control = b.lineCap.line.controls[pointIndex]
                control.point = track.snapPoint(np,
                                                editLine: drawing.lines[b.lineCap.lineIndex],
                                                editPointIndex: pointIndex,
                                                snapDistance: snapD)
                newLines[b.lineCap.lineIndex] = b.lineCap.line.withReplaced(control, at: pointIndex)
            } else if isVertex {
                let newLine = b.lineCap.line.warpedWith(deltaPoint: np - nearest.point,
                                                        isFirst: b.lineCap.isFirst)
                newLines[b.lineCap.lineIndex] = newLine
            } else {
                let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                var control = b.lineCap.line.controls[pointIndex]
                control.point = np
                let newLine = newLines[b.lineCap.lineIndex].withReplaced(control, at: pointIndex)
                newLines[b.lineCap.lineIndex] = newLine
            }
            set(newLines, old: e.lines, in: drawing, node, time: time)
        } else if let cellItem = b.cellItem, let geometry = b.geometry {
            for editLineCap in nearest.cellItemEditLineCaps {
                guard editLineCap.cellItem == cellItem else {
                    editLineCap.cellItem.cell.geometry = editLineCap.geometry
                    continue
                }
                if b.lineCap.line.controls.count == 2 {
                    let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                    var control = b.lineCap.line.controls[pointIndex]
                    let editLine = cellItem.cell.geometry.lines[b.lineCap.lineIndex]
                    control.point = track.snapPoint(np,
                                                    editLine: editLine,
                                                    editPointIndex: pointIndex,
                                                    snapDistance: snapD)
                    let newLine = b.lineCap.line.withReplaced(control,
                                                              at: pointIndex).autoPressure()
                    let newLines = geometry.lines.withReplaced(newLine, at: b.lineCap.lineIndex)
                    set(Geometry(lines: newLines),
                        old: geometry,
                        at: track.animation.editKeyframeIndex,
                        in: cellItem, track, node, time: time)
                } else if isVertex {
                    let newLine = b.lineCap.line.warpedWith(deltaPoint: np - nearest.point,
                                                            isFirst: b.lineCap.isFirst).autoPressure()
                    let bLines = geometry.lines.withReplaced(newLine, at: b.lineCap.lineIndex)
                    set(Geometry(lines: bLines),
                        old: geometry,
                        at: track.animation.editKeyframeIndex,
                        in: cellItem, track, node, time: time)
                } else {
                    let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                    var control = geometry.lines[b.lineCap.lineIndex].controls[pointIndex]
                    control.point = np
                    let newLine = b.lineCap.line.withReplaced(control, at: pointIndex).autoPressure()
                    let newLines = geometry.lines.withReplaced(newLine, at: b.lineCap.lineIndex)
                    set(Geometry(lines: newLines),
                        old: geometry,
                        at: track.animation.editKeyframeIndex,
                        in: cellItem, track, node, time: time)
                }
            }
        }
        bezierSortedResult = nil
    }
    
    func movingLineCap(with nearest: Node.Nearest, dp: CGPoint,
                       isVertex: Bool, in track: NodeTrack) {
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
            e.drawing.lines = newLines
            editPointLines = e.drawingCaps.map { newLines[$0.lineIndex] }
        }
        
        for editLineCap in nearest.cellItemEditLineCaps {
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
            
            let i = cut.editNode.editTrack.animation.editKeyframeIndex
            editLineCap.cellItem.replace(Geometry(lines: newLines), at: i)
            
            editPointLines += editLineCap.caps.map { newLines[$0.lineIndex] }
        }
        
        track.updateInterpolation()
        
        if let b = bezierSortedResult {
            if let cellItem = b.cellItem {
                let newLine = cellItem.cell.geometry.lines[b.lineCap.lineIndex]
                editPoint = Node.EditPoint(nearestLine: newLine,
                                           nearestPointIndex: b.lineCap.pointIndex,
                                           lines: Array(Set(editPointLines)),
                                           point: np, isSnap: movePointIsSnap)
            } else if let drawing = b.drawing {
                let newLine = drawing.lines[b.lineCap.lineIndex]
                editPoint = Node.EditPoint(nearestLine: newLine,
                                           nearestPointIndex: b.lineCap.pointIndex,
                                           lines: Array(Set(editPointLines)),
                                           point: np, isSnap: movePointIsSnap)
            }
        }
    }
    func movedLineCap(with nearest: Node.Nearest, dp: CGPoint, isVertex: Bool,
                      in track: NodeTrack, _ node: Node) {
        let np = nearest.point + dp
        if let e = nearest.drawingEditLineCap {
            var newLines = e.drawing.lines
            if isVertex {
                for cap in e.drawingCaps {
                    newLines[cap.lineIndex] = cap.line.warpedWith(deltaPoint: dp,
                                                                  isFirst: cap.isFirst)
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
            set(newLines, old: e.lines, in: e.drawing, node, time: time)
        }
        for editLineCap in nearest.cellItemEditLineCaps {
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
            set(Geometry(lines: newLines),
                old: editLineCap.geometry,
                at: track.animation.editKeyframeIndex,
                in: editLineCap.cellItem, track, node, time: time)
        }
    }
    
    private func replaceLine(_ line: Line, oldLine: Line, at i: Int,
                             in drawing: Drawing, in node: Node, time: Beat) {
        registerUndo {
            $0.replaceLine(oldLine, oldLine: line, at: i, in: drawing, in: node, time: $1)
        }
        self.time = time
        drawing.lines[i] = line
        node.differentialDataModel.isWrite = true
        setNeedsDisplay()
    }
    
    func clipCellInSelected(with event: KeyInputEvent) {
        clipCellInSelected()
    }
    func clipCellInSelected() {
        guard let fromCell = editCell else {
            return
        }
        let node = cut.editNode
        let selectedCells = node.allSelectedCellItemsWithNoEmptyGeometry.map { $0.cell }
        if selectedCells.isEmpty {
            if !node.rootCell.children.contains(fromCell) {
                let fromParents = node.rootCell.parents(with: fromCell)
                moveCell(fromCell,
                         from: fromParents,
                         to: [(node.rootCell, node.rootCell.children.count)], in: node,
                         time: time)
            }
        } else if !selectedCells.contains(fromCell) {
            let fromChildrens = fromCell.allCells
            var newFromParents = node.rootCell.parents(with: fromCell)
            let newToParents: [(cell: Cell, index: Int)] = selectedCells.compactMap { toCell in
                for fromChild in fromChildrens {
                    if fromChild == toCell {
                        return nil
                    }
                }
                for (i, newFromParent) in newFromParents.enumerated() {
                    if toCell == newFromParent.cell {
                        newFromParents.remove(at: i)
                        return nil
                    }
                }
                return (toCell, toCell.children.count)
            }
            if !(newToParents.isEmpty && newFromParents.isEmpty) {
                moveCell(fromCell, from: newFromParents, to: newToParents, in: node, time: time)
            }
        }
    }
    
    private var moveZOldPoint = CGPoint()
    private var moveZCellTuple: (indexes: [Int], parent: Cell, oldChildren: [Cell])?
    private var moveZMinDeltaIndex = 0, moveZMaxDeltaIndex = 0
    private weak var moveZOldCell: Cell?, moveZNode: Node?
    func moveZ(with event: DragEvent) -> Bool {
        let p = point(from: event), cp = convertToCurrentLocal(point(from: event))
        switch event.sendType {
        case .begin:
            let ict = cut.editNode.indicatedCellsTuple(with : cp,
                                                       reciprocalScale: scene.reciprocalScale)
            guard !ict.cellItems.isEmpty else {
                return true
            }
            switch ict.type {
            case .none:
                break
            case .indicated:
                let cell = ict.cellItems.first!.cell
                cut.editNode.rootCell.depthFirstSearch(duplicate: false) { parent, aCell in
                    if cell === aCell, let index = parent.children.index(of: cell) {
                        moveZCellTuple = ([index], parent, parent.children)
                        moveZMinDeltaIndex = -index
                        moveZMaxDeltaIndex = parent.children.count - 1 - index
                    }
                }
            case .selected:
                let firstCell = ict.cellItems[0].cell
                let cutAllSelectedCells
                    = cut.editNode.allSelectedCellItemsWithNoEmptyGeometry.map { $0.cell }
                var firstParent: Cell?
                cut.editNode.rootCell.depthFirstSearch(duplicate: false) { parent, cell in
                    if cell === firstCell {
                        firstParent = parent
                    }
                }
                
                if let firstParent = firstParent {
                    var indexes = [Int]()
                    cut.editNode.rootCell.depthFirstSearch(duplicate: false) { parent, cell in
                        if cutAllSelectedCells.contains(cell) && firstParent === parent,
                            let index = parent.children.index(of: cell) {
                            
                            indexes.append(index)
                        }
                    }
                    moveZCellTuple = (indexes, firstParent, firstParent.children)
                    moveZMinDeltaIndex = -(indexes.min() ?? 0)
                    moveZMaxDeltaIndex = firstParent.children.count - 1 - (indexes.max() ?? 0)
                } else {
                    moveZCellTuple = nil
                }
            }
            moveZNode = cut.editNode
            moveZOldPoint = p
        case .sending:
            self.editZ?.point = cp
            if let moveZCellTuple = moveZCellTuple, let node = moveZNode {
                let deltaIndex = Int((p.y - moveZOldPoint.y) / node.editZHeight)
                var children = moveZCellTuple.oldChildren
                let indexes = moveZCellTuple.indexes.sorted {
                    deltaIndex < 0 ? $0 < $1 : $0 > $1
                }
                for i in indexes {
                    let cell = children[i]
                    children.remove(at: i)
                    children.insert(cell, at: (i + deltaIndex)
                        .clip(min: 0, max: moveZCellTuple.oldChildren.count - 1))
                }
                moveZCellTuple.parent.children = children
            }
        case .end:
            if let moveZCellTuple = moveZCellTuple, let node = moveZNode {
                let deltaIndex = Int((p.y - moveZOldPoint.y) / node.editZHeight)
                var children = moveZCellTuple.oldChildren
                let indexes = moveZCellTuple.indexes.sorted {
                    deltaIndex < 0 ? $0 < $1 : $0 > $1
                }
                for i in indexes {
                    let cell = children[i]
                    children.remove(at: i)
                    children.insert(cell, at: (i + deltaIndex)
                        .clip(min: 0, max: moveZCellTuple.oldChildren.count - 1))
                }
                setChildren(children, oldChildren: moveZCellTuple.oldChildren,
                            inParent: moveZCellTuple.parent, in: node, time: time)
                self.moveZCellTuple = nil
                moveZNode = nil
            }
        }
        setNeedsDisplay()
        return true
    }
    private func setChildren(_ children: [Cell], oldChildren: [Cell],
                             inParent parent: Cell, in node: Node, time: Beat) {
        registerUndo {
            $0.setChildren(oldChildren, oldChildren: children, inParent: parent, in: node, time: $1)
        }
        self.time = time
        parent.children = children
        node.differentialDataModel.isWrite = true
        sceneDataModel?.isWrite = true
        setNeedsDisplay()
    }
    
    private var moveSelected = Node.Selection()
    private var transformBounds = CGRect(), moveOldPoint = CGPoint(), moveTransformOldPoint = CGPoint()
    enum TransformEditType {
        case move, warp, transform
    }
//    func moveInStrokable(with event: DragEvent) -> Bool {
//        return move(with: event, type: .move)
//    }
    func move(with event: DragEvent) -> Bool {
        return move(with: event, type: .move)
    }
    func transform(with event: DragEvent) -> Bool {
        return move(with: event, type: .transform)
    }
    func warp(with event: DragEvent) -> Bool {
        return move(with: event, type: .warp)
    }
    let moveTransformAngleTime = 0.1
    var moveTransformAngleOldTime = 0.0
    var moveTransformAnglePoint = CGPoint(), moveTransformAngleOldPoint = CGPoint()
    var isMoveTransformAngle = false
    private weak var moveNode: Node?
    func move(with event: DragEvent, type: TransformEditType) -> Bool {
        let viewP = point(from: event)
        let p = convertToCurrentLocal(viewP)
        func affineTransform(with node: Node) -> CGAffineTransform {
            switch type {
            case .move:
                return CGAffineTransform(translationX: p.x - moveOldPoint.x, y: p.y - moveOldPoint.y)
            case .warp:
                if let editTransform = editTransform {
                    return node.warpAffineTransform(with: editTransform)
                } else {
                    return CGAffineTransform.identity
                }
            case .transform:
                if let editTransform = editTransform {
                    return node.transformAffineTransform(with: editTransform)
                } else {
                    return CGAffineTransform.identity
                }
            }
        }
        switch event.sendType {
        case .begin:
            moveSelected = cut.editNode.selection(with: p, reciprocalScale: scene.reciprocalScale)
            if type != .move {
                self.editTransform = editTransform(at: p)
                self.moveTransformAngleOldTime = event.time
                self.moveTransformAngleOldPoint = p
                self.isMoveTransformAngle = false
                self.moveTransformOldPoint = p
                
                if type == .warp {
                    let mm = minMaxPointFrom(p)
                    self.minWarpDistance = mm.minDistance
                    self.maxWarpDistance = mm.maxDistance
                }
            }
            moveNode = cut.editNode
            moveOldPoint = p
        case .sending:
            if type != .move {
                if var editTransform = editTransform {
                    
                    func newEditTransform(with lines: [Line]) -> Node.EditTransform {
                        var ps = [CGPoint]()
                        for line in lines {
                            line.allEditPoints({ (p, _) in
                                ps.append(p)
                            })
                            line.allEditPoints { (p, i) in ps.append(p) }
                        }
                        let rb = RotatedRect(convexHullPoints: CGPoint.convexHullPoints(with: ps))
                        let np = rb.convertToLocal(p: p)
                        let tx = np.x / rb.size.width, ty = np.y / rb.size.height
                        if ty < tx {
                            if ty < 1 - tx {
                                let ap = editTransform.isCenter ? rb.midXMidYPoint : rb.midXMaxYPoint
                                return Node.EditTransform(rotatedRect: rb,
                                                          anchorPoint: ap,
                                                          point: rb.midXMinYPoint,
                                                          oldPoint: rb.midXMinYPoint,
                                                          isCenter: editTransform.isCenter)
                            } else {
                                let ap = editTransform.isCenter ? rb.midXMidYPoint : rb.minXMidYPoint
                                return Node.EditTransform(rotatedRect: rb,
                                                          anchorPoint: ap,
                                                          point: rb.maxXMidYPoint,
                                                          oldPoint: rb.maxXMidYPoint,
                                                          isCenter: editTransform.isCenter)
                            }
                        } else {
                            if ty < 1 - tx {
                                let ap = editTransform.isCenter ? rb.midXMidYPoint : rb.maxXMidYPoint
                                return Node.EditTransform(rotatedRect: rb,
                                                          anchorPoint: ap,
                                                          point: rb.minXMidYPoint,
                                                          oldPoint: rb.minXMidYPoint,
                                                          isCenter: editTransform.isCenter)
                            } else {
                                let ap = editTransform.isCenter ? rb.midXMidYPoint : rb.midXMinYPoint
                                return Node.EditTransform(rotatedRect: rb,
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
                            editTransform = Node.EditTransform(rotatedRect: net.rotatedRect,
                                                               anchorPoint: ap,
                                                               point: editTransform.point,
                                                               oldPoint: editTransform.oldPoint,
                                                               isCenter: editTransform.isCenter)
                        }
                    } else {
                        let lines = moveSelected.cellTuples.reduce(into: [Line]()) {
                            $0 += $1.cellItem.cell.geometry.lines
                        }
                        let net = newEditTransform(with: lines)
                        let ap = editTransform.isCenter ? net.anchorPoint : editTransform.anchorPoint
                        editTransform = Node.EditTransform(rotatedRect: net.rotatedRect,
                                                           anchorPoint: ap,
                                                           point: editTransform.point,
                                                           oldPoint: editTransform.oldPoint,
                                                           isCenter: editTransform.isCenter)
                    }
                    
                    let ep = p - moveTransformOldPoint + editTransform.oldPoint
                    self.editTransform = editTransform.with(ep)
                }
            }
            if type == .warp {
                if let editTransform = editTransform, editTransform.isCenter {
                    distanceWarp(with: event)
                    return true
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
                    mdp.drawing.lines = newLines
                }
                for mcp in moveSelected.cellTuples {
                    mcp.cellItem.replace(mcp.geometry.applying(affine),
                                         at: mcp.track.animation.editKeyframeIndex)
                }
                cut.updateWithCurrentTime()
            }
        case .end:
            if type == .warp {
                if editTransform?.isCenter ?? false {
                    distanceWarp(with: event)
                    editTransform = nil
                    return true
                }
            }
            if !moveSelected.isEmpty, let node = moveNode {
                let affine = affineTransform(with: node)
                if let mdp = moveSelected.drawingTuple {
                    var newLines = mdp.oldLines
                    for index in mdp.lineIndexes {
                        newLines[index] = mdp.oldLines[index].applying(affine)
                    }
                    set(newLines, old: mdp.oldLines, in: mdp.drawing, node, time: time)
                }
                for mcp in moveSelected.cellTuples {
                    set(mcp.geometry.applying(affine),
                        old: mcp.geometry,
                        at: mcp.track.animation.editKeyframeIndex,
                        in:mcp.cellItem, mcp.track, node, time: time)
                }
                cut.updateWithCurrentTime()
                moveSelected = Node.Selection()
            }
            self.editTransform = nil
        }
        setNeedsDisplay()
        return true
    }
    
    private var minWarpDistance = 0.0.cf, maxWarpDistance = 0.0.cf
    func distanceWarp(with event: DragEvent) {
        let p = convertToCurrentLocal(point(from: event))
        switch event.sendType {
        case .begin:
            moveSelected = cut.editNode.selection(with: p, reciprocalScale: scene.reciprocalScale)
            let mm = minMaxPointFrom(p)
            moveNode = cut.editNode
            moveOldPoint = p
            minWarpDistance = mm.minDistance
            maxWarpDistance = mm.maxDistance
        case .sending:
            if !moveSelected.isEmpty {
                let dp = p - moveOldPoint
                if let wdp = moveSelected.drawingTuple {
                    var newLines = wdp.oldLines
                    for i in wdp.lineIndexes {
                        newLines[i] = wdp.oldLines[i].warpedWith(deltaPoint: dp,
                                                                 editPoint: moveOldPoint,
                                                                 minDistance: minWarpDistance,
                                                                 maxDistance: maxWarpDistance)
                    }
                    wdp.drawing.lines = newLines
                }
                for wcp in moveSelected.cellTuples {
                    wcp.cellItem.replace(wcp.geometry.warpedWith(deltaPoint: dp,
                                                                 editPoint: moveOldPoint,
                                                                 minDistance: minWarpDistance,
                                                                 maxDistance: maxWarpDistance),
                                         at: wcp.track.animation.editKeyframeIndex)
                }
            }
        case .end:
            if !moveSelected.isEmpty, let node = moveNode {
                let dp = p - moveOldPoint
                if let wdp = moveSelected.drawingTuple {
                    var newLines = wdp.oldLines
                    for i in wdp.lineIndexes {
                        newLines[i] = wdp.oldLines[i].warpedWith(deltaPoint: dp,
                                                                 editPoint: moveOldPoint,
                                                                 minDistance: minWarpDistance,
                                                                 maxDistance: maxWarpDistance)
                    }
                    set(newLines, old: wdp.oldLines, in: wdp.drawing, node, time: time)
                }
                for wcp in moveSelected.cellTuples {
                    set(wcp.geometry.warpedWith(deltaPoint: dp, editPoint: moveOldPoint,
                                                minDistance: minWarpDistance,
                                                maxDistance: maxWarpDistance),
                        old: wcp.geometry,
                        at: wcp.track.animation.editKeyframeIndex,
                        in: wcp.cellItem, wcp.track, node, time: time)
                }
                moveSelected = Node.Selection()
            }
        }
        setNeedsDisplay()
    }
    func minMaxPointFrom(_ p: CGPoint
        ) -> (minDistance: CGFloat, maxDistance: CGFloat, minPoint: CGPoint, maxPoint: CGPoint) {
        
        var minDistance = CGFloat.infinity, maxDistance = 0.0.cf
        var minPoint = CGPoint(), maxPoint = CGPoint()
        func minMaxPointFrom(_ line: Line) {
            for control in line.controls {
                let d = hypot²(p.x - control.point.x, p.y - control.point.y)
                if d < minDistance {
                    minDistance = d
                    minPoint = control.point
                }
                if d > maxDistance {
                    maxDistance = d
                    maxPoint = control.point
                }
            }
        }
        if let wdp = moveSelected.drawingTuple {
            for lineIndex in wdp.lineIndexes {
                minMaxPointFrom(wdp.drawing.lines[lineIndex])
            }
        }
        for wcp in moveSelected.cellTuples {
            for line in wcp.cellItem.cell.geometry.lines {
                minMaxPointFrom(line)
            }
        }
        return (sqrt(minDistance), sqrt(maxDistance), minPoint, maxPoint)
    }
    
    var isUseScrollView = false
    func scroll(with event: ScrollEvent) -> Bool {
        guard isUseScrollView else {
            return false
        }
        viewTransform.translation += event.scrollDeltaPoint
        updateEditView(with: convertToCurrentLocal(point(from: event)))
        return true
    }
    
    var minScale = 0.00001.cf, blockScale = 1.0.cf, maxScale = 64.0.cf
    var correctionScale = 1.28.cf, correctionRotation = 1.0.cf / (4.2 * (.pi))
    private var isBlockScale = false, oldScale = 0.0.cf
    func zoom(with event: PinchEvent) -> Bool {
        let scale = viewTransform.scale.x
        switch event.sendType {
        case .begin:
            oldScale = scale
            isBlockScale = false
        case .sending:
            if !isBlockScale {
                zoom(at: point(from: event)) {
                    let newScale = (scale * pow(event.magnification * correctionScale + 1, 2))
                        .clip(min: minScale, max: maxScale)
                    if blockScale.isOver(old: scale, new: newScale) {
                        isBlockScale = true
                    }
                    viewTransform.scale = CGPoint(x: newScale, y: newScale)
                }
            }
        case .end:
            if isBlockScale {
                zoom(at: point(from: event)) {
                    viewTransform.scale = CGPoint(x: blockScale, y: blockScale)
                }
            }
        }
        return true
    }
    var blockRotations: [CGFloat] = [-.pi, 0.0, .pi]
    private var isBlockRotation = false, blockRotation = 0.0.cf, oldRotation = 0.0.cf
    func rotate(with event: RotateEvent) -> Bool {
        let rotation = viewTransform.rotation
        switch event.sendType {
        case .begin:
            oldRotation = rotation
            isBlockRotation = false
        case .sending:
            if !isBlockRotation {
                zoom(at: point(from: event)) {
                    let oldRotation = rotation
                    let newRotation = rotation + event.rotation * correctionRotation
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
        case .end:
            if isBlockRotation {
                zoom(at: point(from: event)) {
                    viewTransform.rotation = blockRotation
                }
            }
        }
        return true
    }
    func resetView(with event: DoubleTapEvent) -> Bool {
        guard !viewTransform.isIdentity else {
            return false
        }
        viewTransform = Transform()
        updateEditView(with: convertToCurrentLocal(point(from: event)))
        return true
    }
    func zoom(at p: CGPoint, closure: () -> ()) {
        let point = convertToCurrentLocal(p)
        closure()
        let newPoint = convertFromCurrentLocal(point)
        viewTransform.translation -= (newPoint - p)
    }
    
    func reference(with event: TapEvent) -> Reference? {
        let ict = cut.editNode.indicatedCellsTuple(with: convertToCurrentLocal(point(from: event)),
                                                   reciprocalScale: scene.reciprocalScale)
        if let cellItem = ict.cellItems.first {
            return cellItem.cell.reference
        } else {
            return reference
        }
    }
}
extension Canvas: Referenceable {
    static let name = Localization(english: "Canvas", japanese: "キャンバス")
}
