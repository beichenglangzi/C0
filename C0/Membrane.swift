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

import CoreGraphics

struct Membrane: Codable, Equatable {
//    var lineIndexes: [Array<Line>.Index]
//    var colorIndex: Array<Color>.Index
}
//extension Membrane {
//    var imageBounds: Rect {
//        guard !geometry.isEmpty else {
//            return .null
//        }
//        return Line.visibleImageBoundsWith(imageBounds: geometry.path.boundingBoxOfPath,
//                                           lineWidth: material.lineWidth * 2)
//    }
//    var allImageBounds: Rect {
//        return children.reduce(into: imageBounds) { $0.formUnion($1.imageBounds) }
//    }
//
//    func at(_ p: Point) -> Membrane? {
//        let contains = self.contains(p)
//        guard contains || geometry.isEmpty else {
//            return nil
//        }
//        for child in children.reversed() {
//            if let hitCell = child.at(p) {
//                return hitCell
//            }
//        }
//        return !geometry.isEmpty && contains ? self : nil
//    }
//    func at(_ p: Point, reciprocalScale: Real,
//            maxArea: Real = 200.0, maxDistance: Real = 5.0) -> TreeReference<Membrane>? {
//        let reciprocalScale² = reciprocalScale * reciprocalScale
//        let rsMaxArea = reciprocalScale² * maxArea
//        let rsMaxDistance² = reciprocalScale² * maxDistance * maxDistance
//        var minD² = Real.infinity, minReference: TreeReference<Membrane>?
//
//        func reversedReference(at point: Point,
//                               with reference: TreeReference<Membrane>) -> TreeReference<Membrane>? {
//            let cell = reference.value
//            let contains = cell.contains(point)
//            guard contains || cell.geometry.isEmpty else {
//                let area = cell.imageBounds.width * cell.imageBounds.height
//                if area < rsMaxArea && cell.imageBounds.distance²(point) <= rsMaxDistance² {
//                    let newMinD² = cell.geometry.minDistance²(at: point,
//                                                              maxDistance²: rsMaxDistance²)
//                    if newMinD² < minD² {
//                        minD² = newMinD²
//                        minReference = reference
//                    }
//                }
//                return nil
//            }
//            for (i, child) in cell.children.enumerated().reversed() {
//                let childIndexPath = reference.treeIndex.indexPath.appending(i)
//                let childReference = TreeReference(child, TreeIndex(indexPath: childIndexPath))
//                if let hitReference = reversedReference(at: point, with: childReference) {
//                    return hitReference
//                }
//            }
//            return !cell.geometry.isEmpty && contains ? reference : nil
//        }
//        let reference = reversedReference(at: p, with: TreeReference(self, TreeIndex()))
//        if let minReference = minReference {
//            return minReference.reversed()
//        } else {
//            return reference?.reversed()
//        }
//    }
//    func treeIndex(at p: Point) -> TreeIndex<Membrane>? {
//        return reversedTreeIndex(at: p)?.reversed()
//    }
//    private func reversedTreeIndex(at p: Point) -> TreeIndex<Membrane>? {
//        let contains = self.contains(p)
//        guard contains || geometry.isEmpty else {
//            return nil
//        }
//        for (i, child) in children.enumerated().reversed() {
//            if let treeIndex = child.treeIndex(at: p) {
//                return TreeIndex(indexPath: treeIndex.indexPath.appending(i))
//            }
//        }
//        return !geometry.isEmpty && contains ? TreeIndex() : nil
//    }
//
//    func maxDistance²(at p: Point) -> Real {
//        return geometry.maxDistance²(at: p)
//    }
//
//    func contains(_ p: Point) -> Bool {
//        return isEditable && geometry.contains(p)
//    }
//    func contains(_ bounds: Rect) -> Bool {
//        return isEditable && geometry.contains(bounds)
//    }
//    func contains(_ other: Geometry) -> Bool {
//        return isEditable && geometry.contains(other)
//    }
//
//    func intersects(_ bounds: Rect) -> Bool {
//        return isEditable && geometry.intersects(bounds)
//    }
//    func intersects(_ geometry: Geometry) -> Bool {
//        return isEditable && geometry.intersects(geometry)
//    }
//    func intersects(_ lasso: GeometryLasso) -> Bool {
//        return isEditable && geometry.intersects(lasso)
//    }
//    func intersectsLines(_ bounds: Rect) -> Bool {
//        return isEditable && geometry.intersectsLines(bounds)
//    }
//    func intersectsClosePathLines(_ bounds: Rect) -> Bool {
//        return isEditable && geometry.intersectsClosePathLines(bounds)
//    }
//
//    func intersection(_ bounds: Rect) -> [TreeIndex<Membrane>] {
//        var treeIndexes = [TreeIndex<Membrane>]()
//        reversedIntersection(with: bounds, treeIndexes: &treeIndexes, with: TreeIndex())
//        return treeIndexes.map { $0.reversed() }
//    }
//    private func reversedIntersection(with bounds: Rect, treeIndexes: inout [TreeIndex<Membrane>],
//                                      with treeIndex: TreeIndex<Membrane>) {
//        for (i, child) in children.enumerated().reversed() {
//            let childIndexPath = treeIndex.indexPath.appending(i)
//            child.reversedIntersection(with: bounds, treeIndexes: &treeIndexes,
//                                       with: TreeIndex(indexPath: childIndexPath))
//        }
//        if intersects(bounds) {
//            treeIndexes.append(treeIndex)
//        }
//    }
//    func intersection(_ treeIndexes: [TreeIndex<Membrane>]) -> Membrane? {
//        let newIndexes = treeIndexes.filter { !$0.indexPath.isEmpty }
//        let firstIndexes = newIndexes.map { $0.indexPath[0] }
//        let lastIndexes = newIndexes.compactMap { $0.indexPath.count == 1 ? $0.indexPath[0] : nil }
//        let removedFirstIndexes: [TreeIndex<Membrane>] = newIndexes.map { $0.removedFirst }
//        var intersects = false
//        let children: [Membrane] = self.children.enumerated().compactMap { (i, child) in
//            guard firstIndexes.contains(i) else { return nil }
//            intersects = true
//            if lastIndexes.contains(i) {
//                return child.intersection(removedFirstIndexes) ?? child
//            } else {
//                let aNewIndexes = removedFirstIndexes.filter { !$0.indexPath.isEmpty }
//                let aRemovedFirstIndexes: [TreeIndex<Membrane>] = aNewIndexes.map {
//                    $0.removedFirst
//                }
//                return Membrane(children: child.children.compactMap {
//                    $0.intersection(aRemovedFirstIndexes)
//                })
//            }
//        }
//        if intersects {
//            var cell = self
//            cell.children = children
//            return cell
//        } else {
//            return nil
//        }
//    }
//
//    func isSnapped(_ other: Geometry) -> Bool {
//        return isEditable && geometry.isSnapped(other)
//    }
//}
//extension Membrane {
//    func eiditngColorAndLineColor(isIndicated: Bool,
//                                  isInterpolated: Bool) -> (color: Color, lineColor: Color) {
//        let mColor = isIndicated ?
//            Color.linear(material.color, .subIndicated, t: 0.5) :
//            material.color
//        let mLineColor = isIndicated ? Color.indicated : material.lineColor
//
//        let color = isInterpolated ? Color.linear(mColor, .red, t: 0.5) : mColor
//        let lineColor = isInterpolated ? Color.linear(mLineColor, .red, t: 0.5) : mLineColor
//
//        let aColor = material.type == .addition || material.type == .luster ?
//            color.multiply(alpha: 0.5) : color.multiply(white: 0.8)
//        let aLineColor = isLocked ?
//            lineColor.multiply(white: 0.5) : lineColor
//        if isLocked {
//            return (aColor.multiply(alpha: 0.2), aLineColor.multiply(alpha: 0.2))
//        } else {
//            return (aColor, aLineColor)
//        }
//    }
//
//    func view() -> View {
//        guard !isHidden, !geometry.isEmpty else {
//            let view = View()
//            view.isHidden = isHidden
//            return view
//        }
//        guard !children.isEmpty else {
//            return geometry.view(lineWidth: material.lineWidth,
//                                 lineColor: material.lineColor, fillColor: material.color)
//        }
//        let view = geometry.fillView(fillColor: material.color)
//        view.isHidden = isHidden
//        view.isClipped = true
//        let linesView = geometry.linesView(lineWidth: material.lineWidth,
//                                           fillColor: material.lineColor)
//        view.children = children.map { $0.view() } + [linesView]
//        return view
//    }
//
//    func indexViews() -> [View] {
//        var views = [View]()
//        indexViews(&views)
//        return views
//    }
//    private func indexViews(_ views: inout [View]) {
//        children.forEach {
//            $0.indexViews(&views)
//            let view = TextFormView(text: Text("\(views.count - 1)"), font: .small)
//            let bounds = Rect(origin: Point(), size: view.minSize)
//            view.bounds = bounds
//            view.position = (imageBounds.centerPoint - bounds.centerPoint).rounded()
//            views.append(view)
//        }
//    }
//}
//extension Membrane: Referenceable {
//    static let name = Text(english: "Membrane", japanese: "膜")
//}
//extension Membrane: ThumbnailViewable {
//    func thumbnailView(withFrame frame: Rect) -> View {
//        let thumbnailView = View(drawClosure: { self.draw(with: $2, in: $0) })
//        thumbnailView.frame = frame
//        return thumbnailView
//    }
//    func draw(with bounds: Rect, in ctx: CGContext) {
//        let c = AffineTransform.centering(from: allImageBounds, to: bounds.inset(by: 3))
//        let view = self.view()
//        view.transform = Transform(translation: Point(), scale: c.scale, rotation: 0)
//        return view
//    }
//}
//extension Membrane: AbstractViewable {
//    func abstractViewWith<T : BinderProtocol>(binder: T,
//                                              keyPath: ReferenceWritableKeyPath<T, Membrane>,
//                                              type: AbstractType) -> ModelView {
//        return MiniView(binder: binder, keyPath: keyPath)
//    }
//}
//extension Membrane: ObjectViewable {}
//
//
//struct MembraneFrame: Codable, Equatable {
//    var geometry: Geometry, material: Material
//
//    var drawGeometry: Geometry, drawMaterial: Material
//    var isInterpolated = false
//
//    init(children: [Membrane] = [], geometry: Geometry = Geometry(),
//         material: Material = Material(),
//         isLocked: Bool = false, isHidden: Bool = false, isMainEdit: Bool = false) {
//
//        self.geometry = geometry
//        self.material = material
//        self.drawGeometry = geometry
//        self.drawMaterial = material
//        self.isLocked = isLocked
//        self.isHidden = isHidden
//        self.isMainEdit = isMainEdit
//    }
//}
//extension MembraneFrame {
//    var isEmpty: Bool {
//        return geometry.isEmpty
//    }
//    var allIsEmpty: Bool {
//        for child in children {
//            if !child.allIsEmpty {
//                return false
//            }
//        }
//        return isEmpty
//    }
//    var imageBounds: Rect {
//        guard !geometry.isEmpty else {
//            return .null
//        }
//        return Line.visibleImageBoundsWith(imageBounds: geometry.path.boundingBoxOfPath,
//                                           lineWidth: material.lineWidth * 2)
//    }
//    var allImageBounds: Rect {
//        return children.reduce(into: imageBounds) { $0.formUnion($1.imageBounds) }
//    }
//    var isEditable: Bool {
//        return !isLocked && !isHidden
//    }
//
//    func at(_ p: Point) -> Membrane? {
//        let contains = self.contains(p)
//        guard contains || geometry.isEmpty else {
//            return nil
//        }
//        for child in children.reversed() {
//            if let hitCell = child.at(p) {
//                return hitCell
//            }
//        }
//        return !geometry.isEmpty && contains ? self : nil
//    }
//    func at(_ p: Point, reciprocalScale: Real,
//            maxArea: Real = 200.0, maxDistance: Real = 5.0) -> TreeReference<Membrane>? {
//        let reciprocalScale² = reciprocalScale * reciprocalScale
//        let rsMaxArea = reciprocalScale² * maxArea
//        let rsMaxDistance² = reciprocalScale² * maxDistance * maxDistance
//        var minD² = Real.infinity, minReference: TreeReference<Membrane>?
//
//        func reversedReference(at point: Point,
//                               with reference: TreeReference<Membrane>) -> TreeReference<Membrane>? {
//            let cell = reference.value
//            let contains = cell.contains(point)
//            guard contains || cell.geometry.isEmpty else {
//                let area = cell.imageBounds.width * cell.imageBounds.height
//                if area < rsMaxArea && cell.imageBounds.distance²(point) <= rsMaxDistance² {
//                    let newMinD² = cell.geometry.minDistance²(at: point,
//                                                                maxDistance²: rsMaxDistance²)
//                    if newMinD² < minD² {
//                        minD² = newMinD²
//                        minReference = reference
//                    }
//                }
//                return nil
//            }
//            for (i, child) in cell.children.enumerated().reversed() {
//                let childIndexPath = reference.treeIndex.indexPath.appending(i)
//                let childReference = TreeReference(child, TreeIndex(indexPath: childIndexPath))
//                if let hitReference = reversedReference(at: point, with: childReference) {
//                    return hitReference
//                }
//            }
//            return !cell.geometry.isEmpty && contains ? reference : nil
//        }
//        let reference = reversedReference(at: p, with: TreeReference(self, TreeIndex()))
//        if let minReference = minReference {
//            return minReference.reversed()
//        } else {
//            return reference?.reversed()
//        }
//    }
//    func treeIndex(at p: Point) -> TreeIndex<Membrane>? {
//        return reversedTreeIndex(at: p)?.reversed()
//    }
//    private func reversedTreeIndex(at p: Point) -> TreeIndex<Membrane>? {
//        let contains = self.contains(p)
//        guard contains || geometry.isEmpty else {
//            return nil
//        }
//        for (i, child) in children.enumerated().reversed() {
//            if let treeIndex = child.treeIndex(at: p) {
//                return TreeIndex(indexPath: treeIndex.indexPath.appending(i))
//            }
//        }
//        return !geometry.isEmpty && contains ? TreeIndex() : nil
//    }
//
//    func maxDistance²(at p: Point) -> Real {
//        return geometry.maxDistance²(at: p)
//    }
//
//    func contains(_ p: Point) -> Bool {
//        return isEditable && geometry.contains(p)
//    }
//    func contains(_ bounds: Rect) -> Bool {
//        return isEditable && geometry.contains(bounds)
//    }
//    func contains(_ other: Geometry) -> Bool {
//        return isEditable && geometry.contains(other)
//    }
//
//    func intersects(_ bounds: Rect) -> Bool {
//        return isEditable && geometry.intersects(bounds)
//    }
//    func intersects(_ geometry: Geometry) -> Bool {
//        return isEditable && geometry.intersects(geometry)
//    }
//    func intersects(_ lasso: GeometryLasso) -> Bool {
//        return isEditable && geometry.intersects(lasso)
//    }
//    func intersectsLines(_ bounds: Rect) -> Bool {
//        return isEditable && geometry.intersectsLines(bounds)
//    }
//    func intersectsClosePathLines(_ bounds: Rect) -> Bool {
//        return isEditable && geometry.intersectsClosePathLines(bounds)
//    }
//
//    func intersection(_ bounds: Rect) -> [TreeIndex<Membrane>] {
//        var treeIndexes = [TreeIndex<Membrane>]()
//        reversedIntersection(with: bounds, treeIndexes: &treeIndexes, with: TreeIndex())
//        return treeIndexes.map { $0.reversed() }
//    }
//    private func reversedIntersection(with bounds: Rect, treeIndexes: inout [TreeIndex<Membrane>],
//                                      with treeIndex: TreeIndex<Membrane>) {
//        for (i, child) in children.enumerated().reversed() {
//            let childIndexPath = treeIndex.indexPath.appending(i)
//            child.reversedIntersection(with: bounds, treeIndexes: &treeIndexes,
//                                       with: TreeIndex(indexPath: childIndexPath))
//        }
//        if intersects(bounds) {
//            treeIndexes.append(treeIndex)
//        }
//    }
//    func intersection(_ treeIndexes: [TreeIndex<Membrane>]) -> Membrane? {
//        let newIndexes = treeIndexes.filter { !$0.indexPath.isEmpty }
//        let firstIndexes = newIndexes.map { $0.indexPath[0] }
//        let lastIndexes = newIndexes.compactMap { $0.indexPath.count == 1 ? $0.indexPath[0] : nil }
//        let removedFirstIndexes: [TreeIndex<Membrane>] = newIndexes.map { $0.removedFirst }
//        var intersects = false
//        let children: [Membrane] = self.children.enumerated().compactMap { (i, child) in
//            guard firstIndexes.contains(i) else { return nil }
//            intersects = true
//            if lastIndexes.contains(i) {
//                return child.intersection(removedFirstIndexes) ?? child
//            } else {
//                let aNewIndexes = removedFirstIndexes.filter { !$0.indexPath.isEmpty }
//                let aRemovedFirstIndexes: [TreeIndex<Membrane>] = aNewIndexes.map {
//                    $0.removedFirst
//                }
//                return Membrane(children: child.children.compactMap {
//                    $0.intersection(aRemovedFirstIndexes)
//                })
//            }
//        }
//        if intersects {
//            var cell = self
//            cell.children = children
//            return cell
//        } else {
//            return nil
//        }
//    }
//
//    func isSnapped(_ other: Geometry) -> Bool {
//        return isEditable && geometry.isSnapped(other)
//    }
//}
//extension Membrane {
//    func eiditngColorAndLineColor(isIndicated: Bool,
//                                  isInterpolated: Bool) -> (color: Color, lineColor: Color) {
//        let mColor = isIndicated ?
//            Color.linear(material.color, .subIndicated, t: 0.5) :
//            material.color
//        let mLineColor = isIndicated ? Color.indicated : material.lineColor
//
//        let color = isInterpolated ? Color.linear(mColor, .red, t: 0.5) : mColor
//        let lineColor = isInterpolated ? Color.linear(mLineColor, .red, t: 0.5) : mLineColor
//
//        let aColor = material.type == .addition || material.type == .luster ?
//            color.multiply(alpha: 0.5) : color.multiply(white: 0.8)
//        let aLineColor = isLocked ?
//            lineColor.multiply(white: 0.5) : lineColor
//        if isLocked {
//            return (aColor.multiply(alpha: 0.2), aLineColor.multiply(alpha: 0.2))
//        } else {
//            return (aColor, aLineColor)
//        }
//    }
//
//    func view() -> View {
//        guard !isHidden, !geometry.isEmpty else {
//            let view = View()
//            view.isHidden = isHidden
//            return view
//        }
//        guard !children.isEmpty else {
//            return geometry.view(lineWidth: material.lineWidth,
//                                 lineColor: material.lineColor, fillColor: material.color)
//        }
//        let view = geometry.fillView(fillColor: material.color)
//        view.isHidden = isHidden
//        view.isClipped = true
//        let linesView = geometry.linesView(lineWidth: material.lineWidth,
//                                           fillColor: material.lineColor)
//        view.children = children.map { $0.view() } + [linesView]
//        return view
//    }
//
//    func indexViews() -> [View] {
//        var views = [View]()
//        indexViews(&views)
//        return views
//    }
//    private func indexViews(_ views: inout [View]) {
//        children.forEach {
//            $0.indexViews(&views)
//            let view = TextFormView(text: Text("\(views.count - 1)"), font: .small)
//            let bounds = Rect(origin: Point(), size: view.minSize)
//            view.bounds = bounds
//            view.position = (imageBounds.centerPoint - bounds.centerPoint).rounded()
//            views.append(view)
//        }
//    }
//}
