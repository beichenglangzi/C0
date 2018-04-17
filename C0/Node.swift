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

final class NodeDifferential: NSObject, NSCoding {
    var trackDifferentials: [UUID: NodeTrackDifferential]
    init(trackDifferentials: [UUID: NodeTrackDifferential] = [:]) {
        self.trackDifferentials = trackDifferentials
    }
    private enum CodingKeys: String, CodingKey {
        case trackDifferentials
    }
    init?(coder: NSCoder) {
        trackDifferentials = coder.decodeObject(
            forKey: CodingKeys.trackDifferentials.rawValue) as? [UUID: NodeTrackDifferential] ?? [:]
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(trackDifferentials, forKey: CodingKeys.trackDifferentials.rawValue)
    }
}
final class NodeTrackDifferential: NSObject, NSCoding {
    var drawing: Drawing, keyDrawings: [Drawing]
    var cellDifferentials: [UUID: CellDifferential]
    private enum CodingKeys: String, CodingKey {
        case drawing, keyDrawings, cellDifferentials
    }
    init(drawing: Drawing = Drawing(), keyDrawings: [Drawing] = [],
         cellDifferentials: [UUID: CellDifferential] = [:]) {
        self.drawing = drawing
        self.keyDrawings = keyDrawings
        self.cellDifferentials = cellDifferentials
    }
    init?(coder: NSCoder) {
        drawing = coder.decodeObject(forKey: CodingKeys.drawing.rawValue) as? Drawing ?? Drawing()
        keyDrawings = coder.decodeObject(forKey: CodingKeys.keyDrawings.rawValue) as? [Drawing] ?? []
        cellDifferentials = coder.decodeObject(
            forKey: CodingKeys.cellDifferentials.rawValue) as? [UUID: CellDifferential] ?? [:]
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(drawing, forKey: CodingKeys.drawing.rawValue)
        coder.encode(keyDrawings, forKey: CodingKeys.keyDrawings.rawValue)
        coder.encode(cellDifferentials, forKey: CodingKeys.cellDifferentials.rawValue)
    }
}
final class CellDifferential: NSObject, NSCoding {
    var geometry: Geometry, keyGeometries: [Geometry]
    init(geometry: Geometry = Geometry(), keyGeometries: [Geometry] = []) {
        self.geometry = geometry
        self.keyGeometries = keyGeometries
    }
    private enum CodingKeys: String, CodingKey {
        case geometry, keyGeometries
    }
    init?(coder: NSCoder) {
        geometry = coder.decodeObject(forKey: CodingKeys.geometry.rawValue) as? Geometry ?? Geometry()
        keyGeometries = coder.decodeObject(
            forKey: CodingKeys.keyGeometries.rawValue) as? [Geometry] ?? []
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(geometry, forKey: CodingKeys.geometry.rawValue)
        coder.encode(keyGeometries, forKey: CodingKeys.keyGeometries.rawValue)
    }
}

/**
 Issue: 変更通知またはイミュータブル化またはstruct化
 */
final class Node: NSObject, NSCoding {
    var name: String
    
    let key: UUID
    var differentialDataModel: DataModel {
        didSet {
            differentialDataModel.dataClosure = { [unowned self] in self.differential.data }
        }
    }
    func read() {
        if !differentialDataModel.isRead,
            let differential: NodeDifferential = differentialDataModel.readObject() {
            
            self.differential = differential
        }
    }
    var differential: NodeDifferential {
        get {
            let nd = NodeDifferential(trackDifferentials: [:])
            tracks.forEach { (track) in
                let td = NodeTrackDifferential(drawing: track.drawingItem.drawing,
                                               keyDrawings: track.drawingItem.keyDrawings)
                td.drawing = track.drawingItem.drawing
                td.keyDrawings = track.drawingItem.keyDrawings
                track.cellItems.forEach { (cellItem) in
                    td.cellDifferentials[cellItem.id] =
                        CellDifferential(geometry: cellItem.cell.geometry,
                                         keyGeometries: cellItem.keyGeometries)
                }
                nd.trackDifferentials[track.id] = td
            }
            return nd
        }
        set {
            tracks.forEach { (track) in
                guard let td = newValue.trackDifferentials[track.id] else {
                    return
                }
                track.drawingItem.drawing = td.drawing
                if track.drawingItem.keyDrawings.count == td.keyDrawings.count {
                    track.set(td.keyDrawings)
                } else {
                    let count = min(track.drawingItem.keyDrawings.count, td.keyDrawings.count)
                    var keyDrawings = track.drawingItem.keyDrawings
                    (0..<count).forEach { keyDrawings[$0] = td.keyDrawings[$0] }
                    track.set(keyDrawings)
                }
                
                track.cellItems.forEach { (cellItem) in
                    guard let gs = td.cellDifferentials[cellItem.id] else {
                        return
                    }
                    cellItem.cell.geometry = gs.geometry
                    if cellItem.keyGeometries.count == gs.keyGeometries.count {
                        track.set(gs.keyGeometries, in: cellItem, isSetGeometryInCell: false)
                    } else {
                        let count = min(cellItem.keyGeometries.count, gs.keyGeometries.count)
                        var keyGeometries = cellItem.keyGeometries
                        (0..<count).forEach { keyGeometries[$0] = gs.keyGeometries[$0] }
                        track.set(keyGeometries, in: cellItem, isSetGeometryInCell: false)
                    }
                }
            }
        }
    }
    
    private(set) weak var parent: Node?
    var children: [Node] {
        didSet {
            oldValue.forEach { $0.parent = nil }
            children.forEach { $0.parent = self }
        }
    }
    func allChildren(_ closure: (Node) -> Void) {
        func allChildrenRecursion(_ node: Node, _ closure: (Node) -> Void) {
            node.children.forEach { allChildrenRecursion($0, closure) }
            closure(node)
        }
        children.forEach { allChildrenRecursion($0, closure) }
    }
    func allChildrenAndSelf(_ closure: (Node) -> Void) {
        func allChildrenRecursion(_ node: Node, _ closure: (Node) -> Void) {
            node.children.forEach { allChildrenRecursion($0, closure) }
            closure(node)
        }
        allChildrenRecursion(self, closure)
    }
    func allChildren(_ closure: (Node, inout Bool) -> ()) {
        var stop = false
        func allChildrenRecursion(_ node: Node, _ closure: (Node, inout Bool) -> ()) {
            for child in node.children {
                allChildrenRecursion(child, closure)
                if stop {
                    return
                }
            }
            closure(node, &stop)
            if stop {
                return
            }
        }
        for child in children {
            allChildrenRecursion(child, closure)
            if stop {
                return
            }
        }
    }
    func allParentsAndSelf(_ closure: ((Node) -> ())) {
        closure(self)
        parent?.allParentsAndSelf(closure)
    }
    func allParentsAndSelf(_ closure: ((Node) -> (Bool))) {
        if closure(self) {
            return
        }
        parent?.allParentsAndSelf(closure)
    }
    var treeNode: TreeNode<Node> {
        return TreeNode(self, children: children.map { $0.treeNode })
    }
    var treeNodeCount: Int {
        var count = 0
        func allChildrenRecursion(_ node: Node) {
            node.children.forEach { allChildrenRecursion($0) }
            count += node.children.count
        }
        allChildrenRecursion(self)
        return count
    }
    
    var time: Beat {
        didSet {
            tracks.forEach { $0.time = time }
            updateEffect()
            updateTransform()
            updateWiggle()
            children.forEach { $0.time = time }
        }
    }
    
    func updateEffect() {
        effect = Node.effectWith(time: time, tracks)
    }
    func updateTransform() {
        transform = Node.transformWith(time: time, tracks: tracks)
    }
    func updateWiggle() {
        (xWiggle, wigglePhase) = Node.wiggleAndPhaseWith(time: time, tracks: tracks)
    }
    
    var isEdited = false
    var isHidden: Bool
    
    var rootCell: Cell
    var tracks: [NodeTrack]
    var editTrackIndex: Int {
        didSet {
            tracks[oldValue].cellItems.forEach { $0.cell.isLocked = true }
            tracks[editTrackIndex].cellItems.forEach { $0.cell.isLocked = false }
        }
    }
    var editTrack: NodeTrack {
        return tracks[editTrackIndex]
    }
    var selectedTrackIndexes = [Int]()
    
    struct CellRemoveManager {
        let trackAndCellItems: [(track: NodeTrack, cellItems: [CellItem])]
        let rootCell: Cell
        let parents: [(cell: Cell, index: Int)]
        func contains(_ cellItem: CellItem) -> Bool {
            for tac in trackAndCellItems {
                if tac.cellItems.contains(cellItem) {
                    return true
                }
            }
            return false
        }
    }
    func cellRemoveManager(with cellItem: CellItem) -> CellRemoveManager {
        var cells = [cellItem.cell]
        cellItem.cell.depthFirstSearch(duplicate: false, closure: { parent, cell in
            let parents = rootCell.parents(with: cell)
            if parents.count == 1 {
                cells.append(cell)
            }
        })
        var trackAndCellItems = [(track: NodeTrack, cellItems: [CellItem])]()
        for track in tracks {
            var cellItems = [CellItem]()
            cells = cells.filter {
                if let removeCellItem = track.cellItem(with: $0) {
                    cellItems.append(removeCellItem)
                    return false
                }
                return true
            }
            if !cellItems.isEmpty {
                trackAndCellItems.append((track, cellItems))
            }
        }
        guard !trackAndCellItems.isEmpty else {
            fatalError()
        }
        return CellRemoveManager(trackAndCellItems: trackAndCellItems,
                                 rootCell: cellItem.cell,
                                 parents: rootCell.parents(with: cellItem.cell))
    }
    func insertCell(with crm: CellRemoveManager) {
        crm.parents.forEach { $0.cell.children.insert(crm.rootCell, at: $0.index) }
        for tac in crm.trackAndCellItems {
            for cellItem in tac.cellItems {
                guard cellItem.keyGeometries.count == tac.track.animation.keyframes.count else {
                    fatalError()
                }
                guard !tac.track.cellItems.contains(cellItem) else {
                    fatalError()
                }
                tac.track.append(cellItem)
            }
        }
    }
    func removeCell(with crm: CellRemoveManager) {
        crm.parents.forEach { $0.cell.children.remove(at: $0.index) }
        for tac in crm.trackAndCellItems {
            for cellItem in tac.cellItems {
                tac.track.remove(cellItem)
            }
        }
    }
    
    var effect: Effect, transform: Transform, xWiggle: Wiggle, wigglePhase: CGFloat = 0
    
    static func effectWith(time: Beat, _ tracks: [NodeTrack]) -> Effect {
        var effect = Effect()
        tracks.forEach {
            if let e = $0.effectItem?.drawEffect {
                effect.blurRadius += e.blurRadius
                effect.opacity *= e.opacity
                effect.blendType = e.blendType
            }
        }
        return effect
    }
    static func transformWith(time: Beat, tracks: [NodeTrack]) -> Transform {
        var translation = CGPoint(), scale = CGPoint(), rotation = 0.0.cf, count = 0
        tracks.forEach {
            if let t = $0.transformItem?.drawTransform {
                translation.x += t.translation.x
                translation.y += t.translation.y
                scale.x += t.scale.x
                scale.y += t.scale.y
                rotation += t.rotation
                count += 1
            }
        }
        return count > 0 ?
            Transform(translation: translation, scale: scale, rotation: rotation) : Transform()
    }
    static func wiggleAndPhaseWith(time: Beat,
                                   tracks: [NodeTrack]) -> (wiggle: Wiggle, wigglePhase: CGFloat) {
        var amplitude = 0.0.cf, frequency = 0.0.cf, phase = 0.0.cf, count = 0
        tracks.forEach {
            if let wiggle = $0.wiggleItem?.drawWiggle {
                amplitude += wiggle.amplitude
                frequency += wiggle.frequency
                phase += $0.wigglePhase(withBeatTime: time)
                count += 1
            }
        }
        if count > 0 {
            let reciprocalCount = 1 / count.cf
            let wiggle = Wiggle(amplitude: amplitude, frequency: frequency * reciprocalCount)
            return (wiggle, phase * reciprocalCount)
        } else {
            return (Wiggle(), 0)
        }
    }
    
    init(name: String = "", parent: Node? = nil, children: [Node] = [Node](),
         isHidden: Bool = false,
         rootCell: Cell = Cell(material: Material(color: .background)),
         effect: Effect = Effect(),
         transform: Transform = Transform(),
         wiggle: Wiggle = Wiggle(), wigglePhase: CGFloat = 0.0,
         tracks: [NodeTrack] = [NodeTrack()], editTrackIndex: Int = 0,
         time: Beat = 0, duration: Beat = 1) {
        
        guard !tracks.isEmpty else {
            fatalError()
        }
        key = UUID()
        differentialDataModel = DataModel(key: key.uuidString)
        self.name = name
        self.parent = parent
        self.children = children
        self.isHidden = isHidden
        self.rootCell = rootCell
        self.effect = effect
        self.transform = transform
        self.xWiggle = wiggle
        self.wigglePhase = wigglePhase
        self.tracks = tracks
        self.editTrackIndex = editTrackIndex
        self.time = time
        super.init()
        children.forEach { $0.parent = self }
        differentialDataModel.dataClosure = { [unowned self] in self.differential.data }
    }
    
    private enum CodingKeys: String, CodingKey {
        case
        name, key, children, isHidden, rootCell, effect, transform, wiggle, wigglePhase,
        material, tracks, editTrackIndex, selectedTrackIndexes, time
    }
    init?(coder: NSCoder) {
        name = coder.decodeObject(forKey: CodingKeys.name.rawValue) as? String ?? ""
        key = coder.decodeObject(forKey: CodingKeys.key.rawValue) as? UUID ?? UUID()
        differentialDataModel = DataModel(key: key.uuidString)
        parent = nil
        children = coder.decodeObject(forKey: CodingKeys.children.rawValue) as? [Node] ?? []
        isHidden = coder.decodeBool(forKey: CodingKeys.isHidden.rawValue)
        rootCell = coder.decodeObject(forKey: CodingKeys.rootCell.rawValue) as? Cell ?? Cell()
        effect = coder.decodeDecodable(Effect.self, forKey: CodingKeys.effect.rawValue) ?? Effect()
        transform = coder.decodeDecodable(
            Transform.self, forKey: CodingKeys.transform.rawValue) ?? Transform()
        xWiggle = coder.decodeDecodable(
            Wiggle.self, forKey: CodingKeys.wiggle.rawValue) ?? Wiggle()
        wigglePhase = coder.decodeDouble(forKey: CodingKeys.wigglePhase.rawValue).cf
        tracks = coder.decodeObject(forKey: CodingKeys.tracks.rawValue) as? [NodeTrack] ?? []
        editTrackIndex = coder.decodeInteger(forKey: CodingKeys.editTrackIndex.rawValue)
        selectedTrackIndexes = coder.decodeObject(forKey: CodingKeys.selectedTrackIndexes.rawValue)
            as? [Int] ?? []
        time = coder.decodeDecodable(Beat.self, forKey: CodingKeys.time.rawValue) ?? 0
        super.init()
        children.forEach { $0.parent = self }
    }
    func encode(with coder: NSCoder) {
        coder.encode(name, forKey: CodingKeys.name.rawValue)
        coder.encode(key, forKey: CodingKeys.key.rawValue)
        coder.encode(children, forKey: CodingKeys.children.rawValue)
        coder.encode(isHidden, forKey: CodingKeys.isHidden.rawValue)
        coder.encode(rootCell, forKey: CodingKeys.rootCell.rawValue)
        coder.encodeEncodable(effect, forKey: CodingKeys.effect.rawValue)
        coder.encodeEncodable(transform, forKey: CodingKeys.transform.rawValue)
        coder.encodeEncodable(xWiggle, forKey: CodingKeys.wiggle.rawValue)
        coder.encode(wigglePhase.d, forKey: CodingKeys.wigglePhase.rawValue)
        coder.encode(tracks, forKey: CodingKeys.tracks.rawValue)
        coder.encode(editTrackIndex, forKey: CodingKeys.editTrackIndex.rawValue)
        coder.encode(selectedTrackIndexes, forKey: CodingKeys.selectedTrackIndexes.rawValue)
        coder.encodeEncodable(time, forKey: CodingKeys.time.rawValue)
    }
    
    var imageBounds: CGRect {
        return tracks.reduce(rootCell.allImageBounds) { $0.unionNoEmpty($1.imageBounds) }
    }
    
    enum IndicatedCellType {
        case none, indicated, selected
    }
    func indicatedCellsTuple(with  point: CGPoint, reciprocalScale: CGFloat
        ) -> (cellItems: [CellItem], selectedLineIndexes: [Int], type: IndicatedCellType) {
        
        let selectedCellItems = editTrack.selectedCellItemsWithNoEmptyGeometry(at: point)
        if !selectedCellItems.isEmpty {
            return (sort(selectedCellItems), [], .selected)
        } else if
            let cell = rootCell.at(point, reciprocalScale: reciprocalScale),
            let cellItem = editTrack.cellItem(with: cell) {
            return ([cellItem], [], .indicated)
        } else {
            let drawing = editTrack.drawingItem.drawing
            let lineIndexes = drawing.isNearestSelectedLineIndexes(at: point) ?
                drawing.selectedLineIndexes : []
            if lineIndexes.isEmpty {
                return drawing.lines.count == 0 ?
                    ([], [], .none) : ([], Array(0 ..< drawing.lines.count), .indicated)
            } else {
                return ([], lineIndexes, .selected)
            }
        }
    }
    var allSelectedCellItemsWithNoEmptyGeometry: [CellItem] {
        var selectedCellItems = [CellItem]()
        tracks.forEach { selectedCellItems += $0.selectedCellItemsWithNoEmptyGeometry }
        return selectedCellItems
    }
    func allSelectedCellItemsWithNoEmptyGeometry(at p: CGPoint) -> [CellItem] {
        for track in tracks {
            let cellItems = track.selectedCellItemsWithNoEmptyGeometry(at: p)
            if !cellItems.isEmpty {
                var selectedCellItems = [CellItem]()
                tracks.forEach { selectedCellItems += $0.selectedCellItemsWithNoEmptyGeometry }
                return selectedCellItems
            }
        }
        return []
    }
    struct Selection {
        var cellTuples: [(track: NodeTrack, cellItem: CellItem, geometry: Geometry)] = []
        var drawingTuple: (drawing: Drawing, lineIndexes: [Int], oldLines: [Line])? = nil
        var isEmpty: Bool {
            return (drawingTuple?.lineIndexes.isEmpty ?? true) && cellTuples.isEmpty
        }
    }
    func selection(with point: CGPoint, reciprocalScale: CGFloat) -> Selection {
        let ict = indicatedCellsTuple(with: point, reciprocalScale: reciprocalScale)
        if !ict.cellItems.isEmpty {
            return Selection(cellTuples: ict.cellItems.map { (track(with: $0), $0, $0.cell.geometry) },
                             drawingTuple: nil)
        } else if !ict.selectedLineIndexes.isEmpty {
            let drawing = editTrack.drawingItem.drawing
            return Selection(cellTuples: [],
                             drawingTuple: (drawing, ict.selectedLineIndexes, drawing.lines))
        } else {
            return Selection()
        }
    }
    
    func selectedCells(with cell: Cell) -> [Cell] {
        let cells = editTrack.selectedCellItemsWithNoEmptyGeometry.map { $0.cell }
        if cells.contains(cell) {
            return cells
        } else {
            return [cell]
        }
    }
    
    func sort(_ cellItems: [CellItem]) -> [CellItem] {
        let sortedCells = sort(cellItems.map { $0.cell })
        return sortedCells.map { cellItem(with: $0) }
    }
    func sort(_ cells: [Cell]) -> [Cell] {
        var sortedCells = [Cell]()
        rootCell.allCells(isReversed: true) { (cell, stop) in
            if cells.contains(cell) {
                sortedCells.append(cell)
            }
        }
        return sortedCells
    }
    
    func track(with cell: Cell) -> NodeTrack {
        for track in tracks {
            if track.contains(cell) {
                return track
            }
        }
        fatalError()
    }
    func trackAndCellItem(with cell: Cell) -> (track: NodeTrack, cellItem: CellItem) {
        for track in tracks {
            if let cellItem = track.cellItem(with: cell) {
                return (track, cellItem)
            }
        }
        fatalError()
    }
    func trackAndCellItem(withCellID id: UUID) -> (track: NodeTrack, cellItem: CellItem)? {
        for track in tracks {
            if let cellItem = track.cellItem(withCellID: id) {
                return (track, cellItem)
            }
        }
        return nil
    }
    func cellItem(with cell: Cell) -> CellItem {
        for track in tracks {
            if let cellItem = track.cellItem(with: cell) {
                return cellItem
            }
        }
        fatalError()
    }
    func track(with cellItem: CellItem) -> NodeTrack {
        for track in tracks {
            if track.contains(cellItem) {
                return track
            }
        }
        fatalError()
    }
    func isInterpolatedKeyframe(with animation: Animation) -> Bool {
        let lki = animation.loopedKeyframeIndex(withTime: time)
        return animation.editKeyframe.interpolation != .none && lki.interTime != 0
            && lki.keyframeIndex != animation.keyframes.count - 1
    }
    func isContainsKeyframe(with animation: Animation) -> Bool {
        let keyIndex = animation.loopedKeyframeIndex(withTime: time)
        return keyIndex.interTime == 0
    }
    var maxTime: Beat {
        return tracks.reduce(Beat(0)) { max($0, $1.animation.keyframes.last?.time ?? 0) }
    }
    func maxTime(withOtherTrack otherTrack: NodeTrack) -> Beat {
        return tracks.reduce(Beat(0)) { $1 != otherTrack ?
            max($0, $1.animation.keyframes.last?.time ?? 0) : $0 }
    }
    func cellItem(at point: CGPoint, reciprocalScale: CGFloat, with track: NodeTrack) -> CellItem? {
        if let cell = rootCell.at(point, reciprocalScale: reciprocalScale) {
            let gc = trackAndCellItem(with: cell)
            return gc.track == track ? gc.cellItem : nil
        } else {
            return nil
        }
    }
    
    var allCells: [Cell] {
        var allCells = [Cell]()
        allChildrenAndSelf { allCells += $0.rootCell.allCells }
        return allCells
    }
    
    var indexPath: IndexPath {
        guard let parent = parent else {
            return IndexPath()
        }
        return parent.indexPath.appending(parent.children.index(of: self)!)
    }
    
    var maxDuration: Beat {
        var maxDuration = editTrack.animation.duration
        children.forEach { node in
            node.tracks.forEach {
                let duration = $0.animation.duration
                if duration > maxDuration {
                    maxDuration = duration
                }
            }
        }
        return maxDuration
    }
    
    var worldAffineTransform: CGAffineTransform {
        if let parentAffine = parent?.worldAffineTransform {
            return transform.affineTransform.concatenating(parentAffine)
        } else {
            return transform.affineTransform
        }
    }
    var worldScale: CGFloat {
        if let parentScale = parent?.worldScale {
            return transform.scale.x * parentScale
        } else {
            return transform.scale.x
        }
    }
    
    struct LineCap {
        let line: Line, lineIndex: Int, isFirst: Bool
        var pointIndex: Int {
            return isFirst ? 0 : line.controls.count - 1
        }
    }
    struct Nearest {
        var drawingEdit: (drawing: Drawing, line: Line, lineIndex: Int, pointIndex: Int)?
        var cellItemEdit: (cellItem: CellItem, geometry: Geometry, lineIndex: Int, pointIndex: Int)?
        var drawingEditLineCap: (drawing: Drawing, lines: [Line], drawingCaps: [LineCap])?
        var cellItemEditLineCaps: [(cellItem: CellItem, geometry: Geometry, caps: [LineCap])]
        var point: CGPoint
        
        struct BezierSortedResult {
            let drawing: Drawing?, cellItem: CellItem?, geometry: Geometry?
            let lineCap: LineCap, point: CGPoint
        }
        func bezierSortedResult(at p: CGPoint) -> BezierSortedResult? {
            var minDrawing: Drawing?, minCellItem: CellItem?
            var minLineCap: LineCap?, minD² = CGFloat.infinity
            func minNearest(with caps: [LineCap]) -> Bool {
                var isMin = false
                for cap in caps {
                    let d² = (cap.isFirst ?
                        cap.line.bezier(at: 0) :
                        cap.line.bezier(at: cap.line.controls.count - 3)).minDistance²(at: p)
                    if d² < minD² {
                        minLineCap = cap
                        minD² = d²
                        isMin = true
                    }
                }
                return isMin
            }
            
            if let e = drawingEditLineCap {
                if minNearest(with: e.drawingCaps) {
                    minDrawing = e.drawing
                }
            }
            for e in cellItemEditLineCaps {
                if minNearest(with: e.caps) {
                    minDrawing = nil
                    minCellItem = e.cellItem
                }
            }
            if let drawing = minDrawing, let lineCap = minLineCap {
                return BezierSortedResult(drawing: drawing, cellItem: nil, geometry: nil,
                                          lineCap: lineCap, point: point)
            } else if let cellItem = minCellItem, let lineCap = minLineCap {
                return BezierSortedResult(drawing: nil, cellItem: cellItem,
                                          geometry: cellItem.cell.geometry,
                                          lineCap: lineCap, point: point)
            }
            return nil
        }
    }
    func nearest(at point: CGPoint, isVertex: Bool) -> Nearest? {
        var minD = CGFloat.infinity, minDrawing: Drawing?, minCellItem: CellItem?
        var minLine: Line?, minLineIndex = 0, minPointIndex = 0, minPoint = CGPoint()
        func nearestEditPoint(from lines: [Line]) -> Bool {
            var isNearest = false
            for (j, line) in lines.enumerated() {
                line.allEditPoints() { p, i in
                    if !(isVertex && i != 0 && i != line.controls.count - 1) {
                        let d = hypot²(point.x - p.x, point.y - p.y)
                        if d < minD {
                            minD = d
                            minLine = line
                            minLineIndex = j
                            minPointIndex = i
                            minPoint = p
                            isNearest = true
                        }
                    }
                }
            }
            return isNearest
        }
        
        if nearestEditPoint(from: editTrack.drawingItem.drawing.lines) {
            minDrawing = editTrack.drawingItem.drawing
        }
        for cellItem in editTrack.cellItems {
            if nearestEditPoint(from: cellItem.cell.geometry.lines) {
                minDrawing = nil
                minCellItem = cellItem
            }
        }
        
        if let minLine = minLine {
            if minPointIndex == 0 || minPointIndex == minLine.controls.count - 1 {
                func caps(with point: CGPoint, _ lines: [Line]) -> [LineCap] {
                    return lines.enumerated().compactMap {
                        if point == $0.element.firstPoint {
                            return LineCap(line: $0.element, lineIndex: $0.offset, isFirst: true)
                        }
                        if point == $0.element.lastPoint {
                            return LineCap(line: $0.element, lineIndex: $0.offset, isFirst: false)
                        }
                        return nil
                    }
                }
                let drawingCaps = caps(with: minPoint, editTrack.drawingItem.drawing.lines)
                let drawingResult: (drawing: Drawing, lines: [Line], drawingCaps: [LineCap])? =
                    drawingCaps.isEmpty ? nil : (editTrack.drawingItem.drawing,
                                                 editTrack.drawingItem.drawing.lines, drawingCaps)
                let cellResults: [(cellItem: CellItem, geometry: Geometry, caps: [LineCap])]
                cellResults = editTrack.cellItems.compactMap {
                    let aCaps = caps(with: minPoint, $0.cell.geometry.lines)
                    return aCaps.isEmpty ? nil : ($0, $0.cell.geometry, aCaps)
                }
                return Nearest(drawingEdit: nil, cellItemEdit: nil,
                               drawingEditLineCap: drawingResult,
                               cellItemEditLineCaps: cellResults, point: minPoint)
            } else {
                if let drawing = minDrawing {
                    return Nearest(drawingEdit: (drawing, minLine, minLineIndex, minPointIndex),
                                   cellItemEdit: nil,
                                   drawingEditLineCap: nil, cellItemEditLineCaps: [],
                                   point: minPoint)
                } else if let cellItem = minCellItem {
                    return Nearest(drawingEdit: nil,
                                   cellItemEdit: (cellItem, cellItem.cell.geometry,
                                                  minLineIndex, minPointIndex),
                                   drawingEditLineCap: nil, cellItemEditLineCaps: [],
                                   point: minPoint)
                }
            }
        }
        return nil
    }
    func nearestLine(at point: CGPoint
        ) -> (drawing: Drawing?, cellItem: CellItem?, line: Line, lineIndex: Int, pointIndex: Int)? {
        
        guard let nearest = self.nearest(at: point, isVertex: false) else {
            return nil
        }
        if let e = nearest.drawingEdit {
            return (e.drawing, nil, e.line, e.lineIndex, e.pointIndex)
        } else if let e = nearest.cellItemEdit {
            return (nil, e.cellItem, e.geometry.lines[e.lineIndex], e.lineIndex, e.pointIndex)
        } else if nearest.drawingEditLineCap != nil || !nearest.cellItemEditLineCaps.isEmpty {
            if let b = nearest.bezierSortedResult(at: point) {
                return (b.drawing, b.cellItem, b.lineCap.line, b.lineCap.lineIndex,
                        b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1)
            }
        }
        return nil
    }
    
    func draw(scene: Scene, viewType: Cut.ViewType,
              scale: CGFloat, rotation: CGFloat,
              viewScale: CGFloat, viewRotation: CGFloat,
              in ctx: CGContext) {
        let inScale = scale * transform.scale.x, inRotation = rotation + transform.rotation
        let inViewScale = viewScale * transform.scale.x
        let inViewRotation = viewRotation + transform.rotation
        let reciprocalScale = 1 / inScale, reciprocalAllScale = 1 / inViewScale
        
        ctx.concatenate(transform.affineTransform)
        
        if effect.opacity != 1 || effect.blendType != .normal || effect.blurRadius > 0 || !isEdited {
            ctx.saveGState()
            ctx.setAlpha(!isEdited ? 0.2 * effect.opacity : effect.opacity)
            ctx.setBlendMode(effect.blendType.blendMode)
            if effect.blurRadius > 0 {
                let invertCTM = ctx.ctm
                let bBounds = ctx.boundingBoxOfClipPath.inset(by: -effect.blurRadius).applying(invertCTM)
                if let bctx = CGContext.bitmap(with: bBounds.size) {
                    bctx.translateBy(x: -effect.blurRadius, y: -effect.blurRadius)
                    bctx.concatenate(ctx.ctm)
                    _draw(scene: scene, viewType: viewType,
                          reciprocalScale: reciprocalScale, reciprocalAllScale: reciprocalAllScale,
                          scale: inViewScale, rotation: inViewRotation, in: bctx)
                    children.forEach {
                        $0.draw(scene: scene, viewType: viewType,
                                scale: inScale, rotation: inRotation,
                                viewScale: inViewScale, viewRotation: inViewRotation,
                                in: bctx)
                    }
                    bctx.drawBlur(withBlurRadius: effect.blurRadius, to: ctx)
                }
            } else {
                ctx.beginTransparencyLayer(auxiliaryInfo: nil)
                _draw(scene: scene, viewType: viewType,
                      reciprocalScale: reciprocalScale, reciprocalAllScale: reciprocalAllScale,
                      scale: inViewScale, rotation: inViewRotation, in: ctx)
                children.forEach {
                    $0.draw(scene: scene, viewType: viewType,
                            scale: inScale, rotation: inRotation,
                            viewScale: inViewScale, viewRotation: inViewRotation,
                            in: ctx)
                }
                ctx.endTransparencyLayer()
            }
            ctx.restoreGState()
        } else {
            _draw(scene: scene, viewType: viewType,
                  reciprocalScale: reciprocalScale, reciprocalAllScale: reciprocalAllScale,
                  scale: inViewScale, rotation: inViewRotation, in: ctx)
            children.forEach {
                $0.draw(scene: scene, viewType: viewType,
                        scale: inScale, rotation: inRotation,
                        viewScale: inViewScale, viewRotation: inViewRotation,
                        in: ctx)
            }
        }
    }
    
    private func _draw(scene: Scene, viewType: Cut.ViewType,
                       reciprocalScale: CGFloat, reciprocalAllScale: CGFloat,
                       scale: CGFloat, rotation: CGFloat,
                       in ctx: CGContext) {
        let isEdit = !isEdited ? false :
            (viewType != .preview && viewType != .editMaterial && viewType != .changingMaterial)
        moveWithWiggle: if viewType == .preview && !xWiggle.isEmpty {
            let phase = xWiggle.phase(with: 0.0, phase: wigglePhase)
            ctx.translateBy(x: phase, y: 0)
        }
        guard !isHidden else {
            return
        }
        if isEdit {
            rootCell.children.forEach {
                $0.draw(isEdit: isEdit, isUseDraw: false,
                        reciprocalScale: reciprocalScale, reciprocalAllScale: reciprocalAllScale,
                        scale: scale, rotation: rotation,
                        in: ctx)
            }
            
            ctx.saveGState()
            ctx.setAlpha(0.5)
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            rootCell.children.forEach {
                $0.draw(isEdit: isEdit, isUseDraw: true,
                        reciprocalScale: reciprocalScale, reciprocalAllScale: reciprocalAllScale,
                        scale: scale, rotation: rotation,
                        in: ctx)
            }
            ctx.endTransparencyLayer()
            ctx.restoreGState()
        } else {
            rootCell.children.forEach {
                $0.draw(isEdit: isEdit, isUseDraw: true,
                        reciprocalScale: reciprocalScale, reciprocalAllScale: reciprocalAllScale,
                        scale: scale, rotation: rotation,
                        in: ctx)
            }
        }
        
        drawAnimation: do {
            if isEdit {
                tracks.forEach {
                    if !$0.isHidden {
                        if $0 === editTrack {
                            $0.drawingItem.drawEdit(withReciprocalScale: reciprocalScale, in: ctx)
                        } else {
                            ctx.setAlpha(0.5)
                            $0.drawingItem.drawEdit(withReciprocalScale: reciprocalScale, in: ctx)
                            ctx.setAlpha(1)
                        }
                    }
                }
            } else {
                var alpha = 1.0.cf
                tracks.forEach {
                    if !$0.isHidden {
                        ctx.setAlpha(alpha)
                        $0.drawingItem.draw(withReciprocalScale: reciprocalScale, in: ctx)
                    }
                    alpha = max(alpha * 0.4, 0.25)
                }
                ctx.setAlpha(1)
            }
        }
    }
    
    struct Edit {
        var indicatedCellItem: CellItem? = nil, editMaterial: Material? = nil, editZ: EditZ? = nil
        var editPoint: EditPoint? = nil, editTransform: EditTransform? = nil, point: CGPoint?
    }
    func drawEdit(_ edit: Edit,
                  scene: Scene, viewType: Cut.ViewType,
                  strokeLine: Line?, strokeLineWidth: CGFloat, strokeLineColor: Color,
                  reciprocalViewScale: CGFloat, scale: CGFloat, rotation: CGFloat,
                  in ctx: CGContext) {
        let worldScale = self.worldScale
        let rScale = 1 / worldScale
        let rAllScale = reciprocalViewScale / worldScale
        let wat = worldAffineTransform
        ctx.saveGState()
        ctx.concatenate(wat)
        
        if !wat.isIdentity {
            ctx.setStrokeColor(Color.locked.cgColor)
            ctx.move(to: CGPoint(x: -10, y: 0))
            ctx.addLine(to: CGPoint(x: 10, y: 0))
            ctx.move(to: CGPoint(x: 0, y: -10))
            ctx.addLine(to: CGPoint(x: 0, y: 10))
            ctx.strokePath()
        }
        
        drawStroke: do {
            if let strokeLine = strokeLine {
                if viewType == .editSelected || viewType == .editDeselected {
                    let geometry = Geometry(lines: [strokeLine])
                    if viewType == .editSelected {
                        geometry.drawSkin(lineColor: .selectBorder, subColor: .select,
                                          reciprocalScale: rScale, reciprocalAllScale: rAllScale,
                                          in: ctx)
                    } else {
                        geometry.drawSkin(lineColor: .deselectBorder, subColor: .deselect,
                                          reciprocalScale: rScale, reciprocalAllScale: rAllScale,
                                          in: ctx)
                    }
                } else {
                    ctx.setFillColor(strokeLineColor.cgColor)
                    strokeLine.draw(size: strokeLineWidth * rScale, in: ctx)
                }
            }
        }
        
        let isEdit = viewType != .preview && viewType != .changingMaterial
        if isEdit {
            if !editTrack.isHidden {
                if viewType == .editPoint || viewType == .editVertex {
                    editTrack.drawTransparentCellLines(withReciprocalScale: rScale, in: ctx)
                }
                editTrack.drawPreviousNext(isHiddenPrevious: scene.isHiddenPrevious,
                                           isHiddenNext: scene.isHiddenNext,
                                           time: time, reciprocalScale: rScale, in: ctx)
            }
            
            for track in tracks {
                if !track.isHidden {
                    track.drawSelectedCells(opacity: 0.75 * (track != editTrack ? 0.5 : 1),
                                            color: .selected,
                                            subColor: .subSelected,
                                            reciprocalScale: rScale,  in: ctx)
                    let drawing = track.drawingItem.drawing
                    let selectedLineIndexes = drawing.selectedLineIndexes
                    if !selectedLineIndexes.isEmpty {
                        let imageBounds = selectedLineIndexes.reduce(CGRect()) {
                            $0.unionNoEmpty(drawing.lines[$1].imageBounds)
                        }
                        ctx.setStrokeColor(Color.selected.with(alpha: 0.8).cgColor)
                        ctx.setLineWidth(rScale)
                        ctx.stroke(imageBounds)
                    }
                }
            }
            if !editTrack.isHidden {
                let isMovePoint = viewType == .editPoint || viewType == .editVertex
                
                if viewType == .editMaterial {
                    if let material = edit.editMaterial {
                        drawMaterial: do {
                            rootCell.allCells { cell, stop in
                                if cell.material.id == material.id {
                                    ctx.addPath(cell.geometry.path)
                                }
                            }
                            ctx.setLineWidth(3 * rAllScale)
                            ctx.setLineJoin(.round)
                            ctx.setStrokeColor(Color.editMaterial.cgColor)
                            ctx.strokePath()
                            rootCell.allCells { cell, stop in
                                if cell.material.color == material.color
                                    && cell.material.id != material.id {
                                    
                                    ctx.addPath(cell.geometry.path)
                                }
                            }
                            ctx.setLineWidth(3 * rAllScale)
                            ctx.setLineJoin(.round)
                            ctx.setStrokeColor(Color.editMaterialColorOnly.cgColor)
                            ctx.strokePath()
                        }
                    }
                }
                
                if !isMovePoint,
                    let indicatedCellItem = edit.indicatedCellItem,
                    editTrack.cellItems.contains(indicatedCellItem) {
                    
                    if editTrack.selectedCellItems.contains(indicatedCellItem), let p = edit.point {
                        editTrack.selectedCellItems.forEach {
                            drawNearestCellLine(for: p, cell: $0.cell, lineColor: .selected,
                                                reciprocalAllScale: rAllScale, in: ctx)
                        }
                    }
                }
                if let editZ = edit.editZ {
                    drawEditZ(editZ, in: ctx)
                }
                if isMovePoint {
                    drawEditPoints(with: edit.editPoint, isEditVertex: viewType == .editVertex,
                                   reciprocalAllScale: rAllScale, in: ctx)
                }
                if let editTransform = edit.editTransform {
                    if viewType == .editWarp {
                        drawWarp(with: editTransform, reciprocalAllScale: rAllScale, in: ctx)
                    } else if viewType == .editTransform {
                        drawTransform(with: editTransform, reciprocalAllScale: rAllScale, in: ctx)
                    }
                }
            }
        }
        ctx.restoreGState()
        if viewType != .preview {
            drawTransform(scene.frame, in: ctx)
        }
    }
    
    func drawTransform(_ cameraFrame: CGRect, in ctx: CGContext) {
        func drawCameraBorder(bounds: CGRect, inColor: Color, outColor: Color) {
            ctx.setStrokeColor(inColor.cgColor)
            ctx.stroke(bounds.insetBy(dx: -0.5, dy: -0.5))
            ctx.setStrokeColor(outColor.cgColor)
            ctx.stroke(bounds.insetBy(dx: -1.5, dy: -1.5))
        }
        ctx.setLineWidth(1)
        if !xWiggle.isEmpty {
            let amplitude = xWiggle.amplitude
            drawCameraBorder(bounds: cameraFrame.insetBy(dx: -amplitude, dy: 0),
                             inColor: Color.cameraBorder, outColor: Color.cutSubBorder)
        }
        let track = editTrack
        func drawPreviousNextCamera(t: Transform, color: Color) {
            let affine = transform.affineTransform.inverted().concatenating(t.affineTransform)
            ctx.saveGState()
            ctx.concatenate(affine)
            drawCameraBorder(bounds: cameraFrame, inColor: color, outColor: Color.cutSubBorder)
            ctx.restoreGState()
            func strokeBounds() {
                ctx.move(to: CGPoint(x: cameraFrame.minX, y: cameraFrame.minY))
                ctx.addLine(to: CGPoint(x: cameraFrame.minX, y: cameraFrame.minY).applying(affine))
                ctx.move(to: CGPoint(x: cameraFrame.minX, y: cameraFrame.maxY))
                ctx.addLine(to: CGPoint(x: cameraFrame.minX, y: cameraFrame.maxY).applying(affine))
                ctx.move(to: CGPoint(x: cameraFrame.maxX, y: cameraFrame.minY))
                ctx.addLine(to: CGPoint(x: cameraFrame.maxX, y: cameraFrame.minY).applying(affine))
                ctx.move(to: CGPoint(x: cameraFrame.maxX, y: cameraFrame.maxY))
                ctx.addLine(to: CGPoint(x: cameraFrame.maxX, y: cameraFrame.maxY).applying(affine))
            }
            ctx.setStrokeColor(color.cgColor)
            strokeBounds()
            ctx.strokePath()
            ctx.setStrokeColor(Color.cutSubBorder.cgColor)
            strokeBounds()
            ctx.strokePath()
        }
        let lki = track.animation.loopedKeyframeIndex(withTime: time)
        if lki.interTime == 0 && lki.keyframeIndex > 0 {
            if let t = track.transformItem?.keyTransforms[lki.keyframeIndex - 1], transform != t {
                drawPreviousNextCamera(t: t, color: .red)
            }
        }
        if let t = track.transformItem?.keyTransforms[lki.keyframeIndex], transform != t {
            drawPreviousNextCamera(t: t, color: .red)
        }
        if lki.keyframeIndex < track.animation.keyframes.count - 1 {
            if let t = track.transformItem?.keyTransforms[lki.keyframeIndex + 1], transform != t {
                drawPreviousNextCamera(t: t, color: .green)
            }
        }
        drawCameraBorder(bounds: cameraFrame, inColor: Color.locked, outColor: Color.cutSubBorder)
    }
    
    struct EditPoint: Equatable {
        let nearestLine: Line, nearestPointIndex: Int, lines: [Line], point: CGPoint, isSnap: Bool
        
        func draw(withReciprocalAllScale reciprocalAllScale: CGFloat,
                  lineColor: Color, in ctx: CGContext) {
            for line in lines {
                ctx.setFillColor((line == nearestLine ? lineColor : Color.subSelected).cgColor)
                line.draw(size: 2 * reciprocalAllScale, in: ctx)
            }
            point.draw(radius: 3 * reciprocalAllScale, lineWidth: reciprocalAllScale,
                       inColor: isSnap ? .snap : lineColor, outColor: .controlPointIn, in: ctx)
        }
    }
    private let editPointRadius = 0.5.cf, lineEditPointRadius = 1.5.cf, pointEditPointRadius = 3.0.cf
    func drawEditPoints(with editPoint: EditPoint?, isEditVertex: Bool,
                        reciprocalAllScale: CGFloat, in ctx: CGContext) {
        if let ep = editPoint, ep.isSnap {
            let p: CGPoint?, np: CGPoint?
            if ep.nearestPointIndex == 1 {
                p = ep.nearestLine.firstPoint
                np = ep.nearestLine.controls.count == 2 ?
                    nil : ep.nearestLine.controls[2].point
            } else if ep.nearestPointIndex == ep.nearestLine.controls.count - 2 {
                p = ep.nearestLine.lastPoint
                np = ep.nearestLine.controls.count == 2 ?
                    nil :
                    ep.nearestLine.controls[ep.nearestLine.controls.count - 3].point
            } else {
                p = nil
                np = nil
            }
            if let p = p {
                func drawSnap(with point: CGPoint, capPoint: CGPoint) {
                    if let ps = CGPoint.boundsPointWithLine(ap: point, bp: capPoint,
                                                            bounds: ctx.boundingBoxOfClipPath) {
                        ctx.move(to: ps.p0)
                        ctx.addLine(to: ps.p1)
                        ctx.setLineWidth(1 * reciprocalAllScale)
                        ctx.setStrokeColor(Color.selected.cgColor)
                        ctx.strokePath()
                    }
                    if let np = np, ep.nearestLine.controls.count > 2 {
                        let p1 = ep.nearestPointIndex == 1 ?
                            ep.nearestLine.controls[1].point :
                            ep.nearestLine.controls[ep.nearestLine.controls.count - 2].point
                        ctx.move(to: p1.mid(np))
                        ctx.addLine(to: p1)
                        ctx.addLine(to: capPoint)
                        ctx.setLineWidth(0.5 * reciprocalAllScale)
                        ctx.setStrokeColor(Color.selected.cgColor)
                        ctx.strokePath()
                        p1.draw(radius: 2 * reciprocalAllScale, lineWidth: reciprocalAllScale,
                                inColor: Color.selected, outColor: Color.controlPointIn, in: ctx)
                    }
                }
                func drawSnap(with lines: [Line]) {
                    for line in lines {
                        if line != ep.nearestLine {
                            if ep.nearestLine.controls.count == 3 {
                                if line.firstPoint == ep.nearestLine.firstPoint {
                                    drawSnap(with: line.controls[1].point,
                                             capPoint: ep.nearestLine.firstPoint)
                                } else if line.lastPoint == ep.nearestLine.firstPoint {
                                    drawSnap(with: line.controls[line.controls.count - 2].point,
                                             capPoint: ep.nearestLine.firstPoint)
                                }
                                if line.firstPoint == ep.nearestLine.lastPoint {
                                    drawSnap(with: line.controls[1].point,
                                             capPoint: ep.nearestLine.lastPoint)
                                } else if line.lastPoint == ep.nearestLine.lastPoint {
                                    drawSnap(with: line.controls[line.controls.count - 2].point,
                                             capPoint: ep.nearestLine.lastPoint)
                                }
                            } else {
                                if line.firstPoint == p {
                                    drawSnap(with: line.controls[1].point, capPoint: p)
                                } else if line.lastPoint == p {
                                    drawSnap(with: line.controls[line.controls.count - 2].point,
                                             capPoint: p)
                                }
                            }
                        } else if line.firstPoint == line.lastPoint {
                            if ep.nearestPointIndex == line.controls.count - 2 {
                                drawSnap(with: line.controls[1].point, capPoint: p)
                            } else if ep.nearestPointIndex == 1 && p == line.firstPoint {
                                drawSnap(with: line.controls[line.controls.count - 2].point,
                                         capPoint: p)
                            }
                        }
                    }
                }
                drawSnap(with: editTrack.drawingItem.drawing.lines)
                for cellItem in editTrack.cellItems {
                    drawSnap(with: cellItem.cell.geometry.lines)
                }
            }
        }
        editPoint?.draw(withReciprocalAllScale: reciprocalAllScale,
                        lineColor: .selected,
                        in: ctx)
        
        var capPointDic = [CGPoint: Bool]()
        func updateCapPointDic(with lines: [Line]) {
            for line in lines {
                let fp = line.firstPoint, lp = line.lastPoint
                if capPointDic[fp] != nil {
                    capPointDic[fp] = true
                } else {
                    capPointDic[fp] = false
                }
                if capPointDic[lp] != nil {
                    capPointDic[lp] = true
                } else {
                    capPointDic[lp] = false
                }
            }
        }
        if !editTrack.cellItems.isEmpty {
            for cellItem in editTrack.cellItems {
                if !cellItem.cell.isLocked {
                    if !isEditVertex {
                        Line.drawEditPointsWith(lines: cellItem.cell.geometry.lines,
                                                reciprocalScale: reciprocalAllScale, in: ctx)
                    }
                    updateCapPointDic(with: cellItem.cell.geometry.lines)
                }
            }
        }
        if !isEditVertex {
            Line.drawEditPointsWith(lines: editTrack.drawingItem.drawing.lines,
                                    reciprocalScale: reciprocalAllScale, in: ctx)
        }
        updateCapPointDic(with: editTrack.drawingItem.drawing.lines)
        
        let r = lineEditPointRadius * reciprocalAllScale, lw = 0.5 * reciprocalAllScale
        for v in capPointDic {
            v.key.draw(radius: r, lineWidth: lw,
                       inColor: v.value ? .controlPointJointIn : .controlPointCapIn,
                       outColor: .controlPointOut, in: ctx)
        }
    }
    
    struct EditZ: Equatable {
        var cells: [Cell], point: CGPoint, firstPoint: CGPoint, firstY: CGFloat
    }
    func drawEditZ(_ editZ: EditZ, in ctx: CGContext) {
        rootCell.depthFirstSearch(duplicate: true) { parent, cell in
            if editZ.cells.contains(cell), let index = parent.children.index(of: cell) {
                if !parent.isEmptyGeometry {
                    parent.geometry.clip(in: ctx) {
                        Cell.drawCellPaths(Array(parent.children[(index + 1)...]),
                                           Color.moveZ, in: ctx)
                    }
                } else {
                    Cell.drawCellPaths(Array(parent.children[(index + 1)...]),
                                       Color.moveZ, in: ctx)
                }
            }
        }
    }
    let editZHeight = 4.0.cf
    func drawEditZKnob(_ editZ: EditZ, at point: CGPoint, in ctx: CGContext) {
        ctx.saveGState()
        ctx.setLineWidth(1)
        let editCellY = editZFirstY(with: editZ.cells)
        drawZ(withFillColor: .knob, lineColor: .getSetBorder,
              position: CGPoint(x: point.x,
                                y: point.y - editZ.firstY + editCellY), in: ctx)
        var p = CGPoint(x: point.x - editZHeight, y: point.y - editZ.firstY)
        rootCell.allCells { (cell, stop) in
            drawZ(withFillColor: cell.colorAndLineColor(withIsEdit: true, isInterpolated: false).color,
                  lineColor: .getSetBorder, position: p, in: ctx)
            p.y += editZHeight
        }
        ctx.restoreGState()
    }
    func drawZ(withFillColor fillColor: Color, lineColor: Color,
               position p: CGPoint, in ctx: CGContext) {
        ctx.setFillColor(fillColor.cgColor)
        ctx.setStrokeColor(lineColor.cgColor)
        ctx.addRect(CGRect(x: p.x - editZHeight / 2, y: p.y - editZHeight / 2,
                           width: editZHeight, height: editZHeight))
        ctx.drawPath(using: .fillStroke)
    }
    func editZFirstY(with cells: [Cell]) -> CGFloat {
        guard let firstCell = cells.first else {
            return 0
        }
        var y = 0.0.cf
        rootCell.allCells { (cell, stop) in
            if cell == firstCell {
                stop = true
            } else {
                y += editZHeight
            }
        }
        return y
    }
    func drawNearestCellLine(for p: CGPoint, cell: Cell, lineColor: Color,
                             reciprocalAllScale: CGFloat, in ctx: CGContext) {
        if let n = cell.geometry.nearestBezier(with: p) {
            let np = cell.geometry.lines[n.lineIndex].bezier(at: n.bezierIndex).position(withT: n.t)
            ctx.setStrokeColor(Color.background.multiply(alpha: 0.75).cgColor)
            ctx.setLineWidth(3 * reciprocalAllScale)
            ctx.move(to: CGPoint(x: p.x, y: p.y))
            ctx.addLine(to: CGPoint(x: np.x, y: p.y))
            ctx.addLine(to: CGPoint(x: np.x, y: np.y))
            ctx.strokePath()
            ctx.setStrokeColor(lineColor.cgColor)
            ctx.setLineWidth(reciprocalAllScale)
            ctx.move(to: CGPoint(x: p.x, y: p.y))
            ctx.addLine(to: CGPoint(x: np.x, y: p.y))
            ctx.addLine(to: CGPoint(x: np.x, y: np.y))
            ctx.strokePath()
        }
    }
    
    struct EditTransform: Equatable {
        static let centerRatio = 0.25.cf
        let rotatedRect: RotatedRect, anchorPoint: CGPoint
        let point: CGPoint, oldPoint: CGPoint, isCenter: Bool
        
        func with(_ point: CGPoint) -> EditTransform {
            return EditTransform(rotatedRect: rotatedRect, anchorPoint: anchorPoint,
                                 point: point, oldPoint: oldPoint, isCenter: isCenter)
        }
    }
    func warpAffineTransform(with et: EditTransform) -> CGAffineTransform {
        guard et.oldPoint != et.anchorPoint else {
            return CGAffineTransform.identity
        }
        let theta = et.oldPoint.tangential(et.anchorPoint)
        let angle = theta < 0 ? theta + .pi : theta - .pi
        var pAffine = CGAffineTransform(rotationAngle: -angle)
        pAffine = pAffine.translatedBy(x: -et.anchorPoint.x, y: -et.anchorPoint.y)
        let newOldP = et.oldPoint.applying(pAffine), newP = et.point.applying(pAffine)
        let scaleX = newP.x / newOldP.x, skewY = (newP.y - newOldP.y) / newOldP.x
        var affine = CGAffineTransform(translationX: et.anchorPoint.x, y: et.anchorPoint.y)
        affine = affine.rotated(by: angle)
        affine = affine.scaledBy(x: scaleX, y: 1)
        if skewY != 0 {
            affine = CGAffineTransform(a: 1, b: skewY, c: 0, d: 1, tx: 0, ty: 0).concatenating(affine)
        }
        affine = affine.rotated(by: -angle)
        return affine.translatedBy(x: -et.anchorPoint.x, y: -et.anchorPoint.y)
    }
    func transformAffineTransform(with et: EditTransform) -> CGAffineTransform {
        guard et.oldPoint != et.anchorPoint else {
            return CGAffineTransform.identity
        }
        let r = et.point.distance(et.anchorPoint), oldR = et.oldPoint.distance(et.anchorPoint)
        let angle = et.anchorPoint.tangential(et.point)
        let oldAngle = et.anchorPoint.tangential(et.oldPoint)
        let scale = r / oldR
        var affine = CGAffineTransform(translationX: et.anchorPoint.x, y: et.anchorPoint.y)
        affine = affine.rotated(by: angle.differenceRotation(oldAngle))
        affine = affine.scaledBy(x: scale, y: scale)
        affine = affine.translatedBy(x: -et.anchorPoint.x, y: -et.anchorPoint.y)
        return affine
    }
    func drawWarp(with et: EditTransform, reciprocalAllScale: CGFloat, in ctx: CGContext) {
        if et.isCenter {
            drawLine(firstPoint: et.rotatedRect.midXMinYPoint,
                     lastPoint: et.rotatedRect.midXMaxYPoint,
                     reciprocalAllScale: reciprocalAllScale, in: ctx)
            drawLine(firstPoint: et.rotatedRect.minXMidYPoint,
                     lastPoint: et.rotatedRect.maxXMidYPoint,
                     reciprocalAllScale: reciprocalAllScale, in: ctx)
        } else {
            drawLine(firstPoint: et.anchorPoint, lastPoint: et.point,
                     reciprocalAllScale: reciprocalAllScale, in: ctx)
        }
        
        drawRotatedRect(with: et, reciprocalAllScale: reciprocalAllScale, in: ctx)
        et.anchorPoint.draw(radius: lineEditPointRadius * reciprocalAllScale,
                            lineWidth: reciprocalAllScale, in: ctx)
    }
    func drawTransform(with et: EditTransform, reciprocalAllScale: CGFloat, in ctx: CGContext) {
        ctx.setAlpha(0.5)
        drawLine(firstPoint: et.anchorPoint, lastPoint: et.oldPoint,
                 reciprocalAllScale: reciprocalAllScale, in: ctx)
        drawCircleWith(radius: et.oldPoint.distance(et.anchorPoint), anchorPoint: et.anchorPoint,
                       reciprocalAllScale: reciprocalAllScale, in: ctx)
        ctx.setAlpha(1)
        drawLine(firstPoint: et.anchorPoint, lastPoint: et.point,
                 reciprocalAllScale: reciprocalAllScale, in: ctx)
        drawCircleWith(radius: et.point.distance(et.anchorPoint), anchorPoint: et.anchorPoint,
                       reciprocalAllScale: reciprocalAllScale, in: ctx)
        
        drawRotatedRect(with: et, reciprocalAllScale: reciprocalAllScale, in: ctx)
        et.anchorPoint.draw(radius: lineEditPointRadius * reciprocalAllScale,
                            lineWidth: reciprocalAllScale, in: ctx)
    }
    func drawRotatedRect(with et: EditTransform, reciprocalAllScale: CGFloat, in ctx: CGContext) {
        ctx.setLineWidth(reciprocalAllScale)
        ctx.setStrokeColor(Color.camera.cgColor)
        ctx.saveGState()
        ctx.concatenate(et.rotatedRect.affineTransform)
        let w = et.rotatedRect.size.width * EditTransform.centerRatio
        let h = et.rotatedRect.size.height * EditTransform.centerRatio
        ctx.stroke(CGRect(x: (et.rotatedRect.size.width - w) / 2,
                          y: (et.rotatedRect.size.height - h) / 2, width: w, height: h))
        ctx.stroke(CGRect(x: 0, y: 0,
                          width: et.rotatedRect.size.width, height: et.rotatedRect.size.height))
        ctx.restoreGState()
    }
    
    func drawCircleWith(radius r: CGFloat, anchorPoint: CGPoint,
                        reciprocalAllScale: CGFloat, in ctx: CGContext) {
        let cb = CGRect(x: anchorPoint.x - r, y: anchorPoint.y - r, width: r * 2, height: r * 2)
        let outLineWidth = 3 * reciprocalAllScale, inLineWidth = 1.5 * reciprocalAllScale
        ctx.setLineWidth(outLineWidth)
        ctx.setStrokeColor(Color.controlPointOut.cgColor)
        ctx.strokeEllipse(in: cb)
        ctx.setLineWidth(inLineWidth)
        ctx.setStrokeColor(Color.controlPointIn.cgColor)
        ctx.strokeEllipse(in: cb)
    }
    func drawLine(firstPoint: CGPoint, lastPoint: CGPoint,
                  reciprocalAllScale: CGFloat, in ctx: CGContext) {
        let outLineWidth = 3 * reciprocalAllScale, inLineWidth = 1.5 * reciprocalAllScale
        ctx.setLineWidth(outLineWidth)
        ctx.setStrokeColor(Color.controlPointOut.cgColor)
        ctx.move(to: firstPoint)
        ctx.addLine(to: lastPoint)
        ctx.strokePath()
        ctx.setLineWidth(inLineWidth)
        ctx.setStrokeColor(Color.controlPointIn.cgColor)
        ctx.move(to: firstPoint)
        ctx.addLine(to: lastPoint)
        ctx.strokePath()
    }
}
extension Node: ClassCopiable {
    func copied(from copier: Copier) -> Node {
        let node = Node(name: name,
                        parent: nil, children: children.map { copier.copied($0) },
                        rootCell: copier.copied(rootCell),
                        effect: effect,
                        transform: transform,
                        wiggle: xWiggle, wigglePhase: wigglePhase,
                        tracks: tracks.map { copier.copied($0) },
                        editTrackIndex: editTrackIndex,
                        time: time)
        node.children.forEach { $0.parent = node }
        return node
    }
}
extension Node: Referenceable {
    static let name = Localization(english: "Node", japanese: "ノード")
}
extension Node: ObjectViewExpression {
    func thumbnail(withBounds bounds: CGRect, sizeType: SizeType) -> Layer {
        return name.view(withBounds: bounds, sizeType: sizeType)
    }
}

final class NodeView: View {
    var node = Node() {
        didSet {
            isHiddenView.bool = node.isHidden
        }
    }
    
    var sizeType: SizeType
    private let classNameView: TextView
    private let isHiddenView: BoolView
    init(sizeType: SizeType = .regular) {
        self.sizeType = sizeType
        classNameView = TextView(text: Node.name, font: Font.bold(with: sizeType))
        isHiddenView = BoolView(cationBool: true,
                                boolInfo: BoolInfo.hidden,
                                sizeType: sizeType)
        
        super.init()
        replace(children: [classNameView, isHiddenView])
        
        isHiddenView.binding = { [unowned self] in self.setIsHidden(with: $0) }
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
    private func updateLayout() {
        let padding = Layout.padding(with: sizeType)
        classNameView.frame.origin = CGPoint(x: padding,
                                              y: bounds.height - classNameView.frame.height - padding)
        isHiddenView.frame = CGRect(x: classNameView.frame.maxX + padding, y: padding,
                                    width: bounds.width - classNameView.frame.width - padding * 3,
                                    height: Layout.height(with: sizeType))
    }
    func updateWithNode() {
        isHiddenView.bool = node.isHidden
    }
    
    var disabledRegisterUndo = true
    
    struct Binding {
        let nodeView: NodeView, isHidden: Bool, oldIsHidden: Bool
        let inNode: Node, type: Action.SendType
    }
    var setIsHiddenClosure: ((Binding) -> ())?
    
    private var oldNode = Node()
    
    private func setIsHidden(with binding: BoolView.Binding) {
        if binding.type == .begin {
            oldNode = node
        } else {
            node.isHidden = binding.bool
        }
        setIsHiddenClosure?(Binding(nodeView: self, isHidden: binding.bool,
                                    oldIsHidden: binding.oldBool, inNode: oldNode,
                                    type: binding.type))
    }
    
    func copiedObjects(with event: KeyInputEvent) -> [ViewExpression]? {
        return [node.copied]
    }
    
    func reference(with event: TapEvent) -> Reference? {
        return node.reference
    }
}

/**
 Issue: 木構造の修正
 */
final class NodeTreeManager {
    init() {
        nodesView.nameClosure = { [unowned self] in
            return Localization(self.cut.node(atTreeNodeIndex: $0).name)
        }
        nodesView.treeLevelClosure = { [unowned self] in
            var i = 0
            self.cut.node(atTreeNodeIndex: $0).allParentsAndSelf { _ in i += 1 }
            return i - 2
        }
        nodesView.copiedObjectsClosure = { [unowned self] _, _ in [self.cut.editNode.copied] }
        nodesView.moveClosure = { [unowned self] in return self.moveNode(with: $1) }
    }
    
    var cut = Cut() {
        didSet {
            if cut != oldValue {
                updateWithNodes(isAlwaysUpdate: true)
            }
        }
    }
    
    let nodesView = ListArrayView()

    func updateWithNodes(isAlwaysUpdate: Bool = false) {
        nodesView.set(selectedIndex: cut.editTreeNodeIndex, count: cut.maxTreeNodeIndex + 1)
        if isAlwaysUpdate {
            nodesView.updateLayout()
        }
    }
    
    var disabledRegisterUndo = true
    
    struct NodesBinding {
        let nodeTreeView: NodeTreeManager
        let node: Node, index: Int, oldIndex: Int, beginIndex: Int
        let toNode: Node, fromNode: Node, beginNode: Node
        let type: Action.SendType
    }
    var setNodesClosure: ((NodesBinding) -> ())?
    
    let moveHeight = 8.0.cf
    
    private var oldIndex = 0, beginIndex = 0, oldP = CGPoint()
    private var treeNodeIndex = 0, oldMovableNodeIndex = 0, beginMovableNodeIndex = 0
    private weak var editTrack: NodeTrack?
    private var oldParent = Node(), beginParent = Node()
    private var maxMovableNodeIndex = 0, beginTreeNode: TreeNode<Node>?
    func moveNode(with event: DragEvent) -> Bool {
        let p = nodesView.point(from: event)
        switch event.sendType {
        case .begin:
            let beginTreeNode = cut.rootNode.treeNode
            beginMovableNodeIndex = beginTreeNode.movableIndex(with: cut.editNode)
            beginTreeNode.remove(atAllIndex: beginTreeNode.allIndex(with: cut.editNode))
            self.beginTreeNode = beginTreeNode
            
            oldParent = cut.editNode.parent!
            oldIndex = oldParent.children.index(of: cut.editNode)!
            beginParent = oldParent
            beginIndex = oldIndex
            maxMovableNodeIndex = beginTreeNode.movableCount - 1
            
            oldP = p
            setNodesClosure?(NodesBinding(nodeTreeView: self,
                                          node: cut.editNode,
                                          index: oldIndex, oldIndex: oldIndex, beginIndex: beginIndex,
                                          toNode: oldParent, fromNode: oldParent, beginNode: oldParent,
                                          type: .begin))
        case .sending, .end:
            guard let beginTreeNode = beginTreeNode else {
                return true
            }
            let d = p.y - oldP.y
            let ini = (beginMovableNodeIndex + Int(d / moveHeight)).clip(min: 0,
                                                                         max: maxMovableNodeIndex)
            let tuple = beginTreeNode.movableIndexTuple(atMovableIndex: ini)
            if ini != oldMovableNodeIndex
                || (event.sendType == .end && ini != beginMovableNodeIndex) {
                
                let parent = tuple.parent.object
                setNodesClosure?(NodesBinding(nodeTreeView: self,
                                              node: cut.editNode,
                                              index: tuple.insertIndex, oldIndex: oldIndex,
                                              beginIndex: beginIndex,
                                              toNode: parent, fromNode: oldParent,
                                              beginNode: beginParent,
                                              type: event.sendType))
                oldIndex = tuple.insertIndex
                oldParent = parent
                oldMovableNodeIndex = ini
            }
            if event.sendType == .end {
                self.beginTreeNode = nil
            }
        }
        return true
    }
}
