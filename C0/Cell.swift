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

import struct Foundation.Locale
import CoreGraphics

/**
 Issue: 複数セルの重なり判定（複数のセルの上からセルを追加するときにもcontains判定が有効なように修正）
 Issue: セルに文字を実装
 Issue: 文字から発音を生成して口のセルと同期
 Issue: セルの結合
 Issue: 自動回転補間
 Issue: アクションの保存（変形情報などをセルに埋め込む、セルへの操作の履歴を別のセルに適用するコマンド）
 */
struct Cell: Codable, Equatable, TreeNode {
    var geometry: Geometry, material: Material
    var isLocked: Bool, isHidden: Bool, isMainEdit: Bool
    var children: [Cell]
    
    var drawGeometry: Geometry, drawMaterial: Material
    var isInterpolated = false
    
    init(children: [Cell] = [], geometry: Geometry = Geometry(),
         material: Material = Material(),
         isLocked: Bool = false, isHidden: Bool = false, isMainEdit: Bool = false) {
        
        self.children = children
        self.geometry = geometry
        self.material = material
        self.drawGeometry = geometry
        self.drawMaterial = material
        self.isLocked = isLocked
        self.isHidden = isHidden
        self.isMainEdit = isMainEdit
    }
}
extension Cell {
    var isEmpty: Bool {
        return geometry.isEmpty
    }
    var allIsEmpty: Bool {
        for child in children {
            if !child.allIsEmpty {
                return false
            }
        }
        return isEmpty
    }
    var imageBounds: Rect {
        return geometry.path.isEmpty ?
            Rect.null : Line.visibleImageBoundsWith(imageBounds: geometry.path.boundingBoxOfPath,
                                                    lineWidth: material.lineWidth * 2)
    }
    var allImageBounds: Rect {
        return children.reduce(into: imageBounds) { $0.formUnion($1.imageBounds) }
    }
    var isEditable: Bool {
        return !isLocked && !isHidden
    }
    
    func at(_ p: Point) -> Cell? {
        let contains = self.contains(p)
        guard contains || geometry.isEmpty else {
            return nil
        }
        for child in children.reversed() {
            if let hitCell = child.at(p) {
                return hitCell
            }
        }
        return !geometry.isEmpty && contains ? self : nil
    }
    func at(_ p: Point, reciprocalScale: Real,
            maxArea: Real = 200.0, maxDistance: Real = 5.0) -> TreeReference<Cell>? {
        let reciprocalScale² = reciprocalScale * reciprocalScale
        let rsMaxArea = reciprocalScale² * maxArea
        let rsMaxDistance² = reciprocalScale² * maxDistance * maxDistance
        var minD² = Real.infinity, minReference: TreeReference<Cell>?
        
        func reversedReference(at point: Point,
                               with reference: TreeReference<Cell>) -> TreeReference<Cell>? {
            let cell = reference.value
            let contains = cell.contains(point)
            guard contains || cell.geometry.isEmpty else {
                let area = cell.imageBounds.width * cell.imageBounds.height
                if area < rsMaxArea && cell.imageBounds.distance²(point) <= rsMaxDistance² {
                    let newMinD² = cell.geometry.minDistance²(at: point, maxDistance²: rsMaxDistance²)
                    if newMinD² < minD² {
                        minD² = newMinD²
                        minReference = reference
                    }
                }
                return nil
            }
            for (i, child) in cell.children.enumerated().reversed() {
                let childIndexPath = reference.treeIndex.indexPath.appending(i)
                let childReference = TreeReference(child, TreeIndex(indexPath: childIndexPath))
                if let hitReference = reversedReference(at: point, with: childReference) {
                    return hitReference
                }
            }
            return !cell.geometry.isEmpty && contains ? reference : nil
        }
        let reference = reversedReference(at: p, with: TreeReference(self, TreeIndex()))
        if let minReference = minReference {
            return minReference.reversed()
        } else {
            return reference?.reversed()
        }
    }
    func treeIndex(at p: Point) -> TreeIndex<Cell>? {
        return reversedTreeIndex(at: p)?.reversed()
    }
    private func reversedTreeIndex(at p: Point) -> TreeIndex<Cell>? {
        let contains = self.contains(p)
        guard contains || geometry.isEmpty else {
            return nil
        }
        for (i, child) in children.enumerated().reversed() {
            if let treeIndex = child.treeIndex(at: p) {
                return TreeIndex(indexPath: treeIndex.indexPath.appending(i))
            }
        }
        return !geometry.isEmpty && contains ? TreeIndex() : nil
    }
    
    func maxDistance²(at p: Point) -> Real {
        return geometry.maxDistance²(at: p)
    }
    
    func contains(_ p: Point) -> Bool {
        return isEditable && geometry.contains(p)
    }
    func contains(_ bounds: Rect) -> Bool {
        return isEditable && geometry.contains(bounds)
    }
    func contains(_ other: Geometry) -> Bool {
        return isEditable && geometry.contains(other)
    }
    
    func intersects(_ bounds: Rect) -> Bool {
        return isEditable && geometry.intersects(bounds)
    }
    func intersects(_ geometry: Geometry) -> Bool {
        return isEditable && geometry.intersects(geometry)
    }
    func intersects(_ lasso: GeometryLasso) -> Bool {
        return isEditable && geometry.intersects(lasso)
    }
    func intersectsLines(_ bounds: Rect) -> Bool {
        return isEditable && geometry.intersectsLines(bounds)
    }
    func intersectsClosePathLines(_ bounds: Rect) -> Bool {
        return isEditable && geometry.intersectsClosePathLines(bounds)
    }
    
    func intersection(_ bounds: Rect) -> [TreeIndex<Cell>] {
        var treeIndexes = [TreeIndex<Cell>]()
        reversedIntersection(with: bounds, treeIndexes: &treeIndexes, with: TreeIndex())
        return treeIndexes.map { $0.reversed() }
    }
    private func reversedIntersection(with bounds: Rect, treeIndexes: inout [TreeIndex<Cell>],
                                      with treeIndex: TreeIndex<Cell>) {
        for (i, child) in children.enumerated().reversed() {
            let childIndexPath = treeIndex.indexPath.appending(i)
            child.reversedIntersection(with: bounds, treeIndexes: &treeIndexes,
                                       with: TreeIndex(indexPath: childIndexPath))
        }
        if intersects(bounds) {
            treeIndexes.append(treeIndex)
        }
    }
    func intersection(_ treeIndexes: [TreeIndex<Cell>]) -> Cell? {
        let newIndexes = treeIndexes.filter { !$0.indexPath.isEmpty }
        let firstIndexes = newIndexes.map { $0.indexPath[0] }
        let lastIndexes = newIndexes.compactMap { $0.indexPath.count == 1 ? $0.indexPath[0] : nil }
        let removedFirstIndexes: [TreeIndex<Cell>] = newIndexes.map { $0.removedFirst }
        var intersects = false
        let children: [Cell] = self.children.enumerated().compactMap { (i, child) in
            guard firstIndexes.contains(i) else { return nil }
            intersects = true
            if lastIndexes.contains(i) {
                return child.intersection(removedFirstIndexes) ?? child
            } else {
                let aNewIndexes = removedFirstIndexes.filter { !$0.indexPath.isEmpty }
                let aRemovedFirstIndexes: [TreeIndex<Cell>] = aNewIndexes.map {
                    $0.removedFirst
                }
                return Cell(children: child.children.compactMap {
                    $0.intersection(aRemovedFirstIndexes)
                })
            }
        }
        if intersects {
            var cell = self
            cell.children = children
            return cell
        } else {
            return nil
        }
    }
    
    func isSnapped(_ other: Geometry) -> Bool {
        return isEditable && geometry.isSnapped(other)
    }
}
extension Cell {
    //view
    func colorAndLineColor(withIsEdit isEdit: Bool,
                           isIndicated: Bool,
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
        
        let aColor = material.type == .addition || material.type == .luster ?
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
              reciprocalScale: Real, reciprocalAllScale: Real,
              scale: Real, rotation: Real, in ctx: CGContext) {
        let isEditAndUseDraw = isEdit && isUseDraw
        if isEditAndUseDraw && !self.isInterpolated {
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
        let isInterpolated = isEditAndUseDraw
        guard !isHidden, !geometry.isEmpty else { return }
        let isEditUnlocked = isEdit && !isLocked
        if material.opacity < 1 {
            ctx.saveGState()
            ctx.setAlpha(material.opacity)
        }
        let (color, lineColor) = colorAndLineColor(withIsEdit: isEdit, isIndicated: false,
                                                   isInterpolated: isInterpolated)
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
                func drawStrokePath(path: CGPath, lineWidth: Real, color: Color) {
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
//            ctx.setBlendMode(material.type.blendType.blendMode)
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
    
    func indexViews() -> [View] {
        var views = [View]()
        indexViews(&views)
        return views
    }
    private func indexViews(_ views: inout [View]) {
        children.forEach {
            $0.indexViews(&views)
            let view = TextFormView(text: Text("\(views.count - 1)"), font: .small)
            view.frame.origin = (imageBounds.midPoint - view.bounds.midPoint).rounded()
            views.append(view)
        }
    }
}
extension Cell: Referenceable {
    static let name = Text(english: "Cell", japanese: "セル")
}
extension Cell: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        let thumbnailView = View(drawClosure: { self.draw(with: $1.bounds, in: $0) })
        thumbnailView.frame = frame
        return thumbnailView
    }
    func draw(with bounds: Rect, in ctx: CGContext) {
        let c = CGAffineTransform.centering(from: allImageBounds, to: bounds.inset(by: 3))
        ctx.concatenate(c.affine)
        let scale = 3 * c.scale, rotation = 0.0.cg
        let reciprocalScale = 1 / scale
        if geometry.isEmpty {
            children.forEach {
                $0.draw(reciprocalScale: reciprocalScale, reciprocalAllScale: reciprocalScale,
                        scale: scale, rotation: rotation,
                        in: ctx)
            }
        } else {
            draw(reciprocalScale: reciprocalScale, reciprocalAllScale: reciprocalScale,
                 scale: scale, rotation: rotation,
                 in: ctx)
        }
    }
}

final class CellView<T: BinderProtocol>: View, BindableReceiver {
    typealias Model = Cell
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((CellView<Binder>) -> ())]()
    
    private let isLockedView: BoolView<Binder>
    
    var sizeType: SizeType {
        didSet { updateLayout() }
    }
    private let classNameView: TextFormView
    
    init(binder: T, keyPath: BinderKeyPath,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        isLockedView = BoolView(binder: binder,
                                keyPath: keyPath.appending(path: \Model.isLocked),
                                option: BoolOption(defaultModel: false, cationModel: true,
                                                   name: "", info: .locked),
                                sizeType: sizeType)
        
        self.sizeType = sizeType
        classNameView = TextFormView(text: Cell.name, font: Font.bold(with: sizeType))
        
        super.init()
        children = [classNameView, isLockedView]
        self.frame = frame
    }
    
    override var defaultBounds: Rect {
        let padding = Layout.padding(with: sizeType), h = Layout.height(with: sizeType)
        let tlw = classNameView.frame.width + isLockedView.frame.width + padding * 3
        return Rect(x: 0, y: 0, width: tlw, height: h + padding * 2)
    }
    override func updateLayout() {
        let padding = Layout.padding(with: sizeType), h = Layout.height(with: sizeType)
        let tlw = bounds.width - classNameView.frame.width - padding * 3
        classNameView.frame.origin = Point(x: padding,
                                           y: bounds.height - classNameView.frame.height - padding)
        isLockedView.frame = Rect(x: classNameView.frame.maxX + padding, y: padding,
                                  width: tlw, height: h)
    }
    func updateWithModel() {
        isLockedView.updateWithModel()
    }
}
extension CellView: Localizable {
    func update(with locale: Locale) {
        updateLayout()
    }
}
extension CellView: Copiable {
    func copiedObjects(at p: Point) -> [Object] {
        return [Object(model)]
    }
}
extension CellView: Queryable {
    static var referenceableType: Referenceable.Type {
        return Model.self
    }
}
