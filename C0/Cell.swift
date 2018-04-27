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
 Issue: 複数セルの重なり判定（複数のセルの上からセルを追加するときにもcontains判定が有効なように修正）
 Issue: セルに文字を実装
 Issue: 文字から口パク生成アクション
 Issue: セルの結合
 Issue: 自動回転補間
 Issue: アクションの保存（変形情報などをセルに埋め込む、セルへの操作の履歴を別のセルに適用するコマンド）
 Issue: 変更通知またはイミュータブル化またはstruct化
 */
final class Cell: NSObject, NSCoding {
    var children: [Cell], geometry: Geometry, material: Material
    var isLocked: Bool, isHidden: Bool, isMainEdit: Bool, id: UUID
    var drawGeometry: Geometry, drawMaterial: Material
    var isIndicated = false
    
    init(children: [Cell] = [], geometry: Geometry = Geometry(),
         material: Material = Material(color: Color.random()),
         isLocked: Bool = false, isHidden: Bool = false, isMainEdit: Bool = false,
         id: UUID = UUID()) {
        
        self.children = children
        self.geometry = geometry
        self.material = material
        self.drawGeometry = geometry
        self.drawMaterial = material
        self.isLocked = isLocked
        self.isHidden = isHidden
        self.isMainEdit = isMainEdit
        self.id = id
        super.init()
    }
    
    private enum CodingKeys: String, CodingKey {
        case
        children, geometry, material, drawGeometry, drawMaterial,
        isLocked, isHidden, isMainEdit, id
    }
    init?(coder: NSCoder) {
        children = coder.decodeObject(forKey: CodingKeys.children.rawValue) as? [Cell] ?? []
        geometry = coder.decodeObject(forKey: CodingKeys.geometry.rawValue) as? Geometry ?? Geometry()
        material = coder.decodeObject(forKey: CodingKeys.material.rawValue) as? Material ?? Material()
        drawGeometry = coder.decodeObject(forKey: CodingKeys.drawGeometry.rawValue)
            as? Geometry ?? Geometry()
        drawMaterial = coder.decodeObject(forKey: CodingKeys.drawMaterial.rawValue)
            as? Material ?? Material()
        isLocked = coder.decodeBool(forKey: CodingKeys.isLocked.rawValue)
        isHidden = coder.decodeBool(forKey: CodingKeys.isHidden.rawValue)
        isMainEdit = coder.decodeBool(forKey: CodingKeys.isMainEdit.rawValue)
        id = coder.decodeObject(forKey: CodingKeys.id.rawValue) as? UUID ?? UUID()
        super.init()
    }
    var isEncodeGeometry = true
    func encode(with coder: NSCoder) {
        coder.encode(children, forKey: CodingKeys.children.rawValue)
        if isEncodeGeometry {
            coder.encode(geometry, forKey: CodingKeys.geometry.rawValue)
            coder.encode(drawGeometry, forKey: CodingKeys.drawGeometry.rawValue)
        }
        coder.encode(material, forKey: CodingKeys.material.rawValue)
        coder.encode(drawMaterial, forKey: CodingKeys.drawMaterial.rawValue)
        coder.encode(isLocked, forKey: CodingKeys.isLocked.rawValue)
        coder.encode(isHidden, forKey: CodingKeys.isHidden.rawValue)
        coder.encode(isMainEdit, forKey: CodingKeys.isMainEdit.rawValue)
        coder.encode(id, forKey: CodingKeys.id.rawValue)
    }
    
    var isEmpty: Bool {
        for child in children {
            if !child.isEmpty {
                return false
            }
        }
        return geometry.isEmpty
    }
    var isEmptyGeometry: Bool {
        return geometry.isEmpty
    }
    var allImageBounds: Rect {
        var imageBounds = Rect()
        allCells { (cell, stop) in imageBounds = imageBounds.unionNoEmpty(cell.imageBounds) }
        return imageBounds
    }
    var imageBounds: Rect {
        return geometry.path.isEmpty ?
            Rect() : Line.visibleImageBoundsWith(imageBounds: geometry.path.boundingBoxOfPath,
                                                   lineWidth: material.lineWidth * 2)
    }
    var isEditable: Bool {
        return !isLocked && !isHidden
    }
    
    private var depthFirstSearched = false
    func depthFirstSearch(duplicate: Bool, closure: (_ parent: Cell, _ cell: Cell) -> Void) {
        if duplicate {
            depthFirstSearchDuplicateRecursion(closure)
        } else {
            depthFirstSearchRecursion(closure: closure)
            resetDepthFirstSearch()
        }
    }
    private func depthFirstSearchRecursion(closure: (_ parent: Cell, _ cell: Cell) -> Void) {
        for child in children {
            if !child.depthFirstSearched {
                child.depthFirstSearched = true
                closure(self, child)
                child.depthFirstSearchRecursion(closure: closure)
            }
        }
    }
    private func depthFirstSearchDuplicateRecursion(
        _ closure: (_ parent: Cell, _ cell: Cell) -> Void) {
        
        for child in children {
            closure(self, child)
            child.depthFirstSearchDuplicateRecursion(closure)
        }
    }
    private func resetDepthFirstSearch() {
        for child in children {
            if child.depthFirstSearched {
                child.depthFirstSearched = false
                child.resetDepthFirstSearch()
            }
        }
    }
    var allCells: [Cell] {
        var cells = [Cell]()
        depthFirstSearch(duplicate: false) {
            cells.append($1)
        }
        return cells
    }
    func allCells(isReversed: Bool = false, usingLock: Bool = false,
                  closure: (Cell, _ stop: inout Bool) -> Void) {
        var stop = false
        allCellsRecursion(&stop, isReversed: isReversed, usingLock: usingLock, closure: closure)
    }
    private func allCellsRecursion(_ aStop: inout Bool, isReversed: Bool, usingLock: Bool,
                                   closure: (Cell, _ stop: inout Bool) -> Void) {
        let children = isReversed ? self.children.reversed() : self.children
        for child in children {
            if usingLock ? child.isEditable : true {
                child.allCellsRecursion(&aStop, isReversed: isReversed, usingLock: usingLock,
                                        closure: closure)
                if aStop {
                    return
                }
                closure(child, &aStop)
                if aStop {
                    return
                }
            } else {
                child.allCellsRecursion(&aStop, isReversed: isReversed, usingLock: usingLock,
                                        closure: closure)
                if aStop {
                    return
                }
            }
        }
    }
    func parentCells(with cell: Cell) -> [Cell] {
        var parents = [Cell]()
        depthFirstSearch(duplicate: true) { parent, otherCell in
            if cell === otherCell {
                parents.append(otherCell)
            }
        }
        return parents
    }
    func parents(with cell: Cell) -> [(cell: Cell, index: Int)] {
        var parents = [(cell: Cell, index: Int)]()
        depthFirstSearch(duplicate: true) { parent, otherCell in
            if cell === otherCell {
                parents.append((parent, parent.children.index(of: otherCell)!))
            }
        }
        return parents
    }
    
    func at(_ p: Point, reciprocalScale: CGFloat,
            maxArea: CGFloat = 200.0, maxDistance: CGFloat = 5.0) -> Cell? {
        
        let scaleMaxArea = reciprocalScale * reciprocalScale * maxArea
        let scaleMaxDistance = reciprocalScale * maxDistance
        var minD² = CGFloat.infinity, minCell: Cell? = nil
        var scaleMaxDistance² = scaleMaxDistance * scaleMaxDistance
        func at(_ point: Point, with cell: Cell) -> Cell? {
            if cell.contains(point) || cell.geometry.isEmpty {
                for child in cell.children.reversed() {
                    if let hitCell = at(point, with: child) {
                        return hitCell
                    }
                }
                return !cell.isLocked && !cell.geometry.isEmpty && cell.contains(point) ? cell : nil
            } else {
                let area = cell.imageBounds.width * cell.imageBounds.height
                if area < scaleMaxArea && cell.imageBounds.distance²(point) <= scaleMaxDistance² {
                    for (i, line) in cell.geometry.lines.enumerated() {
                        let d² = line.minDistance²(at: point)
                        if d² < minD² && d² < scaleMaxDistance² {
                            minD² = d²
                            minCell = cell
                        }
                        let nextIndex = i + 1 >= cell.geometry.lines.count ? 0 : i + 1
                        let nextLine = cell.geometry.lines[nextIndex]
                        let lld = point.distanceWithLineSegment(ap: line.lastPoint,
                                                                bp: nextLine.firstPoint)
                        let ld² = lld * lld
                        if ld² < minD² && ld² < scaleMaxDistance² {
                            minD² = ld²
                            minCell = cell
                        }
                    }
                }
            }
            return nil
        }
        let cell = at(p, with: self)
        if let minCell = minCell {
            return minCell
        } else {
            return cell
        }
    }
    func at(_ p: Point) -> Cell? {
        let contains = self.contains(p)
        if contains || geometry.isEmpty {
            for child in children.reversed() {
                if let cell = child.at(p) {
                    return cell
                }
            }
            return !geometry.isEmpty && contains ? self : nil
        } else {
            return nil
        }
    }
    
    func cells(at point: Point, usingLock: Bool = true) -> [Cell] {
        var cells = [Cell]()
        cellsRecursion(at: point, cells: &cells, usingLock: usingLock)
        return cells
    }
    private func cellsRecursion(at point: Point, cells: inout [Cell], usingLock: Bool = true) {
        if contains(point) || geometry.isEmpty {
            for child in children.reversed() {
                child.cellsRecursion(at: point, cells: &cells, usingLock: usingLock)
            }
            if (usingLock ? !isLocked : true) && !geometry.isEmpty
                && contains(point) && !cells.contains(self) {
                
                cells.append(self)
            }
        }
    }
    func cells(at line: Line, duplicate: Bool, usingLock: Bool = true) -> [Cell] {
        var cells = [Cell]()
        let fp = line.firstPoint
        allCells(isReversed: true, usingLock: usingLock) { (cell: Cell, stop: inout Bool) in
            if cell.contains(fp) {
                if duplicate || !cells.contains(cell) {
                    cells.append(cell)
                }
                stop = true
            }
        }
        line.allBeziers { b, index, stop2 in
            let nb = b.midSplit()
            allCells(isReversed: true, usingLock: usingLock) { (cell: Cell, stop: inout Bool) in
                if cell.contains(nb.b0.p1) || cell.contains(nb.b1.p1) {
                    if duplicate || !cells.contains(cell) {
                        cells.append(cell)
                    }
                    stop = true
                }
            }
        }
        return cells
    }
    
    func isSnaped(_ other: Cell) -> Bool {
        for line in geometry.lines {
            for otherLine in other.geometry.lines {
                if line.firstPoint == otherLine.firstPoint ||
                    line.firstPoint == otherLine.lastPoint ||
                    line.lastPoint == otherLine.firstPoint ||
                    line.lastPoint == otherLine.lastPoint {
                    return true
                }
            }
        }
        return false
    }
    
    func maxDistance²(at p: Point) -> CGFloat {
        return Line.maxDistance²(at: p, with: geometry.lines)
    }
    
    func contains(_ p: Point) -> Bool {
        return isEditable && (imageBounds.contains(p) ? geometry.path.contains(p) : false)
    }
    func contains(_ cell: Cell) -> Bool {
        if !geometry.isEmpty && !cell.geometry.isEmpty && isEditable
            && cell.isEditable && imageBounds.contains(cell.imageBounds) {
            
            for line in geometry.lines {
                for aLine in cell.geometry.lines {
                    if line.intersects(aLine) {
                        return false
                    }
                }
            }
            for aLine in cell.geometry.lines {
                if !contains(aLine.firstPoint) || !contains(aLine.lastPoint) {
                    return false
                }
            }
            return true
        } else {
            return false
        }
    }
    func contains(_ bounds: Rect) -> Bool {
        if isEditable && imageBounds.intersects(bounds) {
            let x0y0 = bounds.origin
            let x1y0 = Point(x: bounds.maxX, y: bounds.minY)
            let x0y1 = Point(x: bounds.minX, y: bounds.maxY)
            let x1y1 = Point(x: bounds.maxX, y: bounds.maxY)
            if contains(x0y0) || contains(x1y0) || contains(x0y1) || contains(x1y1) {
                return true
            }
            return  intersects(bounds)
        } else {
            return false
        }
    }
    
    func intersects(_ cell: Cell, usingLock: Bool = true) -> Bool {
        if !geometry.isEmpty && !cell.geometry.isEmpty
            && (usingLock ? isEditable && cell.isEditable : true)
            && imageBounds.intersects(cell.imageBounds) {
            
            for line in geometry.lines {
                for aLine in cell.geometry.lines {
                    if line.intersects(aLine) {
                        return true
                    }
                }
            }
            for aLine in cell.geometry.lines {
                if contains(aLine.firstPoint) || contains(aLine.lastPoint) {
                    return true
                }
            }
            for line in geometry.lines {
                if cell.contains(line.firstPoint) || cell.contains(line.lastPoint) {
                    return true
                }
            }
        }
        return false
    }
    func intersects(_ lasso: LineLasso) -> Bool {
        if isEditable && imageBounds.intersects(lasso.imageBounds) {
            for line in geometry.lines {
                for aLine in lasso.lines {
                    if aLine.intersects(line) {
                        return true
                    }
                }
            }
            for line in geometry.lines {
                if lasso.contains(line.firstPoint) || lasso.contains(line.lastPoint) {
                    return true
                }
            }
        }
        return false
    }
    func intersects(_ bounds: Rect) -> Bool {
        if imageBounds.intersects(bounds) {
            let path = geometry.path
            if !path.isEmpty {
                if path.contains(bounds.origin) ||
                    path.contains(Point(x: bounds.maxX, y: bounds.minY)) ||
                    path.contains(Point(x: bounds.minX, y: bounds.maxY)) ||
                    path.contains(Point(x: bounds.maxX, y: bounds.maxY)) {
                    return true
                }
            }
            for line in geometry.lines {
                if line.intersects(bounds) {
                    return true
                }
            }
        }
        return false
    }
    func intersectsLines(_ bounds: Rect) -> Bool {
        if imageBounds.intersects(bounds) {
            for line in geometry.lines {
                if line.intersects(bounds) {
                    return true
                }
            }
            if intersectsClosePathLines(bounds) {
                return true
            }
        }
        return false
    }
    func intersectsClosePathLines(_ bounds: Rect) -> Bool {
        if var lp = geometry.lines.last?.lastPoint {
            for line in geometry.lines {
                let fp = line.firstPoint
                let x0y0 = bounds.origin, x1y0 = Point(x: bounds.maxX, y: bounds.minY)
                let x0y1 = Point(x: bounds.minX, y: bounds.maxY)
                let x1y1 = Point(x: bounds.maxX, y: bounds.maxY)
                if Point.intersection(p0: lp, p1: fp, q0: x0y0, q1: x1y0)
                    || Point.intersection(p0: lp, p1: fp, q0: x1y0, q1: x1y1)
                    || Point.intersection(p0: lp, p1: fp, q0: x1y1, q1: x0y1)
                    || Point.intersection(p0: lp, p1: fp, q0: x0y1, q1: x0y0) {
                    
                    return true
                }
                lp = line.lastPoint
            }
        }
        return false
    }
    func intersectsCells(with bounds: Rect) -> [Cell] {
        var cells = [Cell]()
        intersectsCellsRecursion(with: bounds, cells: &cells)
        return cells
    }
    private func intersectsCellsRecursion(with bounds: Rect, cells: inout [Cell]) {
        if contains(bounds) {
            for child in children.reversed() {
                child.intersectsCellsRecursion(with: bounds, cells: &cells)
            }
            if !isLocked && !geometry.isEmpty && intersects(bounds) && !cells.contains(self) {
                cells.append(self)
            }
        }
    }
    
    func intersection(_ cells: [Cell], isNewID: Bool) -> Cell {
        let newCell = copied
        _ = newCell.intersectionRecursion(cells)
        if isNewID {
            newCell.allCells { (cell, stop) in
                cell.id = UUID()
            }
        }
        return newCell
    }
    private func intersectionRecursion(_ cells: [Cell]) -> Bool {
        children = children.reduce(into: [Cell]()) {
            $0 += (!$1.intersectionRecursion(cells) ? $1.children : [$1])
        }
        for cell in cells {
            if cell.id == id {
                return true
            }
        }
        return false
    }
    
    func colorAndLineColor(withIsEdit isEdit: Bool,
                           isInterpolated: Bool) -> (color: Color, lineColor: Color) {
        guard isEdit else {
            return (material.color, material.lineColor)
        }
        let mColor = isIndicated ?
            Color.linear(material.color, .subIndicated, t: 0.5) :
            material.color
        let mLineColor = isIndicated ? Color.indicated : material.lineColor
        
        let color = isInterpolated ? Color.linear(mColor, .red, t: 0.5) : mColor
        let lineColor = isInterpolated ? Color.linear(mLineColor, .red, t: 0.5) : mLineColor
        
        let aColor = material.type == .add || material.type == .luster ?
            color.multiply(alpha: 0.5) : color.multiply(white: 0.8)
        let aLineColor = isLocked ?
            lineColor.multiply(white: 0.5) : lineColor
        if isLocked {
            return (aColor.multiply(alpha: 0.2), aLineColor.multiply(alpha: 0.2))
        } else {
            return (aColor, aLineColor)
        }
    }
    func draw(isEdit: Bool = false, isUseDraw: Bool = false,
              reciprocalScale: CGFloat, reciprocalAllScale: CGFloat,
              scale: CGFloat, rotation: CGFloat, in ctx: CGContext) {
        let isEditAndUseDraw = isEdit && isUseDraw
        if isEditAndUseDraw && self.geometry == drawGeometry {
            children.forEach {
                $0.draw(isEdit: isEdit, isUseDraw: isUseDraw,
                        reciprocalScale: reciprocalScale,
                        reciprocalAllScale: reciprocalAllScale,
                        scale: scale, rotation: rotation,
                        in: ctx)
            }
            return
        }
        let geometry = !isEdit || isEditAndUseDraw ? drawGeometry : self.geometry
        let isInterpolated = isEditAndUseDraw && self.geometry != drawGeometry
        guard !isHidden, !geometry.isEmpty else {
            return
        }
        let isEditUnlocked = isEdit && !isLocked
        if material.opacity < 1 {
            ctx.saveGState()
            ctx.setAlpha(material.opacity)
        }
        let (color, lineColor) = colorAndLineColor(withIsEdit: isEdit, isInterpolated: isInterpolated)
        let path = geometry.path
        if material.type == .normal || material.type == .lineless {
            if children.isEmpty {
                geometry.fillPath(with: color, path, in: ctx)
            } else {
                func clipFillPath(color: Color, path: CGPath,
                                  in ctx: CGContext, clipping: () -> Void) {
                    ctx.saveGState()
                    ctx.addPath(path)
                    ctx.clip()
                    let b = ctx.boundingBoxOfClipPath.intersection(imageBounds)
                    ctx.beginTransparencyLayer(in: b, auxiliaryInfo: nil)
                    ctx.setFillColor(color.cg)
                    ctx.fill(imageBounds)
                    clipping()
                    ctx.endTransparencyLayer()
                    ctx.restoreGState()
                }
                clipFillPath(color: color, path: path, in: ctx) {
                    children.forEach {
                        $0.draw(isEdit: isEdit, isUseDraw: isUseDraw,
                                reciprocalScale: reciprocalScale,
                                reciprocalAllScale: reciprocalAllScale,
                                scale: scale, rotation: rotation,
                                in: ctx)
                    }
                }
            }
            if material.type == .normal {
                ctx.setFillColor(lineColor.cg)
                geometry.draw(withLineWidth: material.lineWidth * reciprocalScale, in: ctx)
            } else if material.lineWidth > Material.defaultLineWidth {
                func drawStrokePath(path: CGPath, lineWidth: CGFloat, color: Color) {
                    ctx.setLineWidth(lineWidth)
                    ctx.setStrokeColor(color.cg)
                    ctx.setLineJoin(.round)
                    ctx.addPath(path)
                    ctx.strokePath()
                }
                drawStrokePath(path: path, lineWidth: material.lineWidth, color: lineColor)
            }
        } else {
            ctx.saveGState()
            ctx.setBlendMode(material.type.blendMode)
            ctx.drawBlurWith(color: color, width: material.lineWidth,
                             strength: 1,
                             isLuster: material.type == .luster, path: path,
                             scale: scale, rotation: rotation)
            if !children.isEmpty {
                ctx.addPath(path)
                ctx.clip()
                children.forEach {
                    $0.draw(isEdit: isEdit, isUseDraw: isUseDraw,
                            reciprocalScale: reciprocalScale,
                            reciprocalAllScale: reciprocalAllScale,
                            scale: scale, rotation: rotation,
                            in: ctx)
                }
            }
            ctx.restoreGState()
        }
        if isEditUnlocked {
            ctx.setFillColor(Color.getSetBorder.cg)
            if material.type != .normal {
                geometry.draw(withLineWidth: 0.5 * reciprocalScale, in: ctx)
            }
            geometry.drawPathLine(withReciprocalScale: reciprocalScale, in: ctx)
        }
        if material.opacity < 1 {
            ctx.restoreGState()
        }
    }
    
    static func drawCellPaths(_ cells: [Cell], _ color: Color,
                              alpha: CGFloat = 0.3, in ctx: CGContext) {
        ctx.setAlpha(alpha)
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        ctx.setFillColor(color.cg)
        cells.forEach {
            if !$0.isHidden {
                $0.geometry.fillPath(in: ctx)
            }
        }
        ctx.endTransparencyLayer()
        ctx.setAlpha(1)
    }
    
    func drawMaterialID(in ctx: CGContext) {
        guard !imageBounds.isEmpty else {
            return
        }
        let mus = material.id.uuidString, cus = material.color.id.uuidString
        let materialString = mus[mus.index(mus.endIndex, offsetBy: -6)...]
        let colorString = cus[cus.index(cus.endIndex, offsetBy: -6)...]
        let textFrame = TextFrame(string: "M: \(materialString)\nC: \(colorString)", font: .small)
        textFrame.drawWithCenterOfImageBounds(in: imageBounds, in: ctx)
    }
}
extension Cell: ClassDeepCopiable {
    func copied(from deepCopier: DeepCopier) -> Cell {
        return Cell(children: children.map { deepCopier.copied($0) },
                    geometry: geometry, material: material,
                    isLocked: isLocked, isHidden: isHidden,
                    isMainEdit: isMainEdit, id: id)
    }
}
extension Cell: Referenceable {
    static let name = Localization(english: "Cell", japanese: "セル")
}
extension Cell: Viewable {
    func view(withBounds bounds: Rect, _ sizeType: SizeType) -> View {
        let thumbnailView = View(drawClosure: { [unowned self] in self.draw(with: $1.bounds, in: $0) })
        thumbnailView.bounds = bounds
        return ObjectView(object: self, thumbnailView: thumbnailView, minFrame: bounds, sizeType)
    }
    func draw(with bounds: Rect, in ctx: CGContext) {
        var imageBounds = Rect()
        allCells { cell, stop in
            imageBounds = imageBounds.unionNoEmpty(cell.imageBounds)
        }
        let c = CGAffineTransform.centering(from: imageBounds, to: bounds.inset(by: 3))
        ctx.concatenate(c.affine)
        let scale = 3 * c.scale, rotation = 0.0.cg
        if geometry.isEmpty {
            children.forEach {
                $0.draw(reciprocalScale: 1 / scale, reciprocalAllScale: 1 / scale,
                        scale: scale, rotation: rotation,
                        in: ctx)
            }
        } else {
            draw(reciprocalScale: 1 / scale, reciprocalAllScale: 1 / scale,
                 scale: scale, rotation: rotation,
                 in: ctx)
        }
    }
}

final class JoiningCell: NSObject, NSCoding {
    let cell: Cell
    init(_ cell: Cell) {
        self.cell = cell
        super.init()
    }
    
    private enum CodingKeys: String, CodingKey {
        case cell
    }
    init?(coder: NSCoder) {
        cell = coder.decodeObject(forKey: CodingKeys.cell.rawValue) as? Cell ?? Cell()
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(cell, forKey: CodingKeys.cell.rawValue)
    }
}
extension JoiningCell: Referenceable {
    static let name = Localization(english: "Joining Cell", japanese: "接続セル")
}
extension JoiningCell: ClassDeepCopiable {
}
extension JoiningCell: ObjectViewExpression {
    func thumbnail(withBounds bounds: Rect, _ sizeType: SizeType) -> View {
        let thumbnailView = View(drawClosure: { [unowned cell] in cell.draw(with: $1.bounds, in: $0) })
        thumbnailView.bounds = bounds
        return thumbnailView
    }
}

final class CellView: View, Copiable {
    var cell = Cell() {
        didSet {
            isLockedView.bool = cell.isLocked
        }
    }
    
    var sizeType: SizeType
    private let classNameView: TextView
    private let isLockedView: BoolView
    
    init(sizeType: SizeType = .regular) {
        self.sizeType = sizeType
        classNameView = TextView(text: Cell.name, font: Font.bold(with: sizeType))
        isLockedView = BoolView(cationBool: true,
                                boolInfo: BoolInfo.locked,
                                sizeType: sizeType)
        super.init()
        children = [classNameView, isLockedView]
        
        isLockedView.binding = { [unowned self] in self.setIsLocked(with: $0) }
    }
    
    override var locale: Locale {
        didSet {
            updateLayout()
        }
    }
    
    override var defaultBounds: Rect {
        let padding = Layout.padding(with: sizeType), h = Layout.height(with: sizeType)
        let tlw = classNameView.frame.width + isLockedView.frame.width + padding * 3
        return Rect(x: 0, y: 0, width: tlw, height: h + padding * 2)
    }
    override var bounds: Rect {
        didSet {
            updateLayout()
        }
    }
    private func updateLayout() {
        let padding = Layout.padding(with: sizeType), h = Layout.height(with: sizeType)
        let tlw = bounds.width - classNameView.frame.width - padding * 3
        classNameView.frame.origin = Point(x: padding,
                                              y: bounds.height - classNameView.frame.height - padding)
        isLockedView.frame = Rect(x: classNameView.frame.maxX + padding, y: padding,
                                    width: tlw, height: h)
    }
    func updateWithCell() {
        isLockedView.bool = !cell.isLocked
    }
    
    var disabledRegisterUndo = true
    
    struct Binding {
        let cellView: CellView
        let isLocked: Bool, oldIsLocked: Bool
        let inCell: Cell, phase: Phase
    }
    var setIsLockedClosure: ((Binding) -> ())?
    
    private var oldCell = Cell()
    
    private func setIsLocked(with binding: BoolView.Binding) {
        if binding.phase == .began {
            oldCell = cell
        } else {
            cell.isLocked = binding.bool
        }
        setIsLockedClosure?(Binding(cellView: self,
                                    isLocked: binding.bool,
                                    oldIsLocked: binding.oldBool,
                                    inCell: oldCell,
                                    phase: binding.phase))
    }
    
    var copiedViewablesClosure: ((CellView, Point) -> [Viewable])?
    func copiedViewables(at p: Point) -> [Viewable] {
        if let copiedViewablesClosure = copiedViewablesClosure {
            return copiedViewablesClosure(self, p)
        } else {
            return [cell.copied]
        }
    }
    
    func reference(at p: Point) -> Reference {
        return Cell.reference
    }
}
