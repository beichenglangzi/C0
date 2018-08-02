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
import struct Foundation.URL

struct Drawing: Codable, Equatable {
    var lines = [Line]()
    var surfaces = [Surface]()
}
extension Drawing {
    var imageBounds: Rect {
        return imageBounds(withLineWidth: 1)
    }
    func imageBounds(withLineWidth lineWidth: Real) -> Rect {
        return Line.imageBounds(with: lines, lineWidth: lineWidth)
    }
    var isEmpty: Bool {
        return lines.isEmpty
    }
    
    func nearestLine(at p: Point) -> Line? {
        var minD² = Real.infinity, minLine: Line?
        lines.forEach {
            let d² = $0.minDistance²(at: p)
            if d² < minD² {
                minD² = d²
                minLine = $0
            }
        }
        return minLine
    }
    
    func intersects(_ otherLines: [Line]) -> Bool {
        for otherLine in otherLines {
            if lines.contains(where: { $0 == otherLine }) {
                return true
            }
        }
        return false
    }
    
    enum Indication {
        struct DrawingItem {
            var lineIndexes: [Int]
        }
        struct LineItem {
            var pointIndexes: [Int]
        }
        
        case drawing(DrawingItem)
        case line(LineItem)
    }
    func indication(at p: Point, reciprocalScale: Real) -> Indication? {
        fatalError()
    }
    
    struct LinePoint {
        var line: Line, lineIndex: Int, pointIndex: Int
        var isFirst: Bool {
            return pointIndex == 0
        }
        var isLast: Bool {
            return  pointIndex == line.controls.count - 1
        }
    }
    struct LineCap {
        enum Orientation {
            case first, last
        }
        
        var line: Line, lineIndex: Int, orientation: Orientation
        
        init(line: Line, lineIndex: Int, orientation: Orientation) {
            self.line = line
            self.lineIndex = lineIndex
            self.orientation = orientation
        }
        init?(line: Line, lineIndex i: Int, at p: Point) {
            if p == line.firstPoint {
                self = LineCap(line: line, lineIndex: i, orientation: .first)
            } else if p == line.lastPoint {
                self = LineCap(line: line, lineIndex: i, orientation: .last)
            } else {
                return nil
            }
        }
        
        var pointIndex: Int {
            return orientation == .first ? 0 : line.controls.count - 1
        }
        var linePoint: LinePoint {
            return LinePoint(line: line, lineIndex: lineIndex, pointIndex: pointIndex)
        }
        var point: Point {
            return orientation == .first ? line.firstPoint : line.lastPoint
        }
        var reversedPoint: Point {
            return orientation == .first ? line.lastPoint : line.firstPoint
        }
    }
    struct LineCapsItem {
        var lineCaps: [LineCap]
        
        func bezierSortedLineCapItem(at p: Point) -> LineCap? {
            var minLineCap: LineCap?, minD² = Real.infinity
            func minNearest(with caps: [LineCap]) -> Bool {
                var isMin = false
                for cap in caps {
                    let d² = (cap.orientation == .first ?
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
            
            _ = minNearest(with: lineCaps)
            
            return minLineCap
        }
    }
    struct Nearest {
        enum Result {
            struct LineCapResult {
                var bezierSortedLineCap: LineCap, lineCapsItem: LineCapsItem
            }
            
            case linePoint(LinePoint), lineCapResult(LineCapResult)
        }
        
        var result: Result, minDistance²: Real, point: Point
    }
    func nearest(at point: Point, isVertex: Bool) -> Nearest? {
        var minD² = Real.infinity, minLinePoint: LinePoint?, minPoint = Point()
        func nearestLinePoint(from lines: [Line]) -> Bool {
            var isNearest = false
            for (j, line) in lines.enumerated() {
                for (i, mp) in line.controls.enumerated() {
                    guard !(isVertex && i != 0 && i != line.controls.count - 1) else { continue }
                    let d² = hypot²(point.x - mp.point.x, point.y - mp.point.y)
                    if d² < minD² {
                        minD² = d²
                        minLinePoint = LinePoint(line: line, lineIndex: j, pointIndex: i)
                        minPoint = mp.point
                        isNearest = true
                    }
                }
            }
            return isNearest
        }
        
        _ = nearestLinePoint(from: lines)
        
        guard let linePoint = minLinePoint else { return nil }
        if linePoint.isFirst || linePoint.isLast {
            func lineCaps(with lines: [Line]) -> [LineCap] {
                return lines.enumerated().compactMap { (i, line) in
                    LineCap(line: line, lineIndex: i, at: minPoint)
                }
            }
            let lineCapsItem = LineCapsItem(lineCaps: lineCaps(with: lines))
            let bslci = lineCapsItem.bezierSortedLineCapItem(at: minPoint)!
            let result = Nearest.Result.LineCapResult(bezierSortedLineCap: bslci,
                                                      lineCapsItem: lineCapsItem)
            return Nearest(result: .lineCapResult(result), minDistance²: minD², point: minPoint)
        } else {
            return Nearest(result: .linePoint(linePoint), minDistance²: minD², point: minPoint)
        }
    }
    
    func nearestLinePoint(at p: Point) -> LinePoint? {
        guard let nearest = self.nearest(at: p, isVertex: false) else {
            return nil
        }
        switch nearest.result {
        case .linePoint(let result): return result
        case .lineCapResult(let result): return result.bezierSortedLineCap.linePoint
        }
    }
    
    func snappedPoint(_ point: Point, with lineCap: LineCap,
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
        func update() {
            for (i, line) in lines.enumerated() {
                if i == lineCap.lineIndex {
                    updateMin(with: lineCap.reversedPoint)
                } else {
                    updateMin(with: line.firstPoint)
                    updateMin(with: line.lastPoint)
                }
            }
        }
        
        update()
        
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
        
        snap(with: lines)
        
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
}
extension Drawing {
    private typealias LineUInt = UInt8
    private typealias FilledUInt = UInt16
    func surfacesRenderingViewWith(lineWidth: Real) -> View {
        let view = View()
        view.children = lines.compactMap { $0.view(lineWidth: lineWidth, fillColor: .white) }
        return view
    }
    func surfacesWith(inFrame bounds: Rect, old oldSurfaces: [Surface]) -> [Surface] {
        let grayColorSpace = CGColorSpaceCreateDeviceGray()
        let scale = 2.0.cg
        let size = Size(width: bounds.width * scale, height: bounds.height * scale)
        let w = Int(size.width), h = Int(size.height)
        guard let lineCTX = CGContext(data: nil, width: w, height: h,
                                      bitsPerComponent: MemoryLayout<LineUInt>.size * 8,
                                      bytesPerRow: 0, space: grayColorSpace,
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
                                        return []
        }
        guard let filledCTX = CGContext(data: nil, width: w, height: h,
                                        bitsPerComponent: MemoryLayout<FilledUInt>.size * 8,
                                        bytesPerRow: 0, space: grayColorSpace,
                                        bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
                                            return []
        }
        
        let translation = Point(x: -bounds.centerPoint.x * scale + size.width / 2,
                                y: -bounds.centerPoint.y * scale + size.height / 2)
        let viewTransform = Transform(translation: translation,
                                      scale: Point(x: scale, y: scale),
                                      rotation: 0)
        lineCTX.concatenate(viewTransform.affineTransform)
        
        let view = surfacesRenderingViewWith(lineWidth: 1)
        view.bounds = bounds
        view.render(in: lineCTX)
        let surfaces = autoFill(in: filledCTX, from: lineCTX)
        let invertedAffine = viewTransform.affineTransform.inverted()
        
        var isFilleds = Array(repeating: false, count: oldSurfaces.count)
        return surfaces.map {
            var surface = $0 * invertedAffine
            
            if !oldSurfaces.isEmpty {
                var minColor = surface.uuColor, minD = Real.infinity, maxArea = 0.0.cg, minIndex = 0
                let newArea = surface.path.boundingBoxOfPath.size.area
                for (i, oldSurface) in oldSurfaces.enumerated() {
                    let r = oldSurface.path.boundingBoxOfPath
                        .intersection(surface.path.boundingBoxOfPath)
                    let area = r.size.area
                    let d = abs(newArea - oldSurface.path.boundingBoxOfPath.size.area)
                    if !r.isEmpty && d <= minD && area >= maxArea {
                        minColor = oldSurface.uuColor
                        minD = d
                        maxArea = area
                        minIndex = i
                    }
                }
                if isFilleds[minIndex] {
                    surface.uuColor = UU(Color.random())
                } else {
                    surface.uuColor = minColor
                    isFilleds[minIndex] = true
                }
            }
            return surface
        }
    }
    private func autoFill(in filledCTX: CGContext, from lineCTX: CGContext,
                          threshold: Real = 0.25) -> [Surface] {
        guard let lineData = lineCTX.data?.assumingMemoryBound(to: LineUInt.self),
            let filledData = filledCTX.data?.assumingMemoryBound(to: FilledUInt.self) else {
                return []
        }
        let t = UInt8(threshold * Real(LineUInt.max))
        let lineOffsetPerRow = lineCTX.bytesPerRow / (lineCTX.bitsPerComponent / 8)
        let lineOffsetPerPixel = lineCTX.bitsPerPixel / lineCTX.bitsPerComponent
        let filledOffsetPerRow = filledCTX.bytesPerRow / (filledCTX.bitsPerComponent / 8)
        let filledOffsetPerPixel = filledCTX.bitsPerPixel / filledCTX.bitsPerComponent
        let w = lineCTX.width, h = lineCTX.height
        
        func lineValueAt(x: Int, y: Int) -> LineUInt {
            return lineData[lineOffsetPerRow * y + x * lineOffsetPerPixel]
        }
        func isLine(x: Int, y: Int) -> Bool {
            return lineValueAt(x: x, y: y) > t
        }
        func filledValueAt(x: Int, y: Int) -> FilledUInt {
            return filledData[filledOffsetPerRow * y + x * filledOffsetPerPixel]
        }
        func isFilledEquale(_ value: FilledUInt, x: Int, y: Int) -> Bool {
            return filledValueAt(x: x, y: y) == value
        }
        func fill(_ value: FilledUInt, atX x: Int, y: Int) {
            filledData[filledOffsetPerRow * y + x * filledOffsetPerPixel] = value
        }
        func isGap4Way(_ value: FilledUInt, x: Int, y: Int) -> Bool {
            return !(x > 0 && isFilledEquale(value, x: x - 1, y: y))
                || !(x < w - 1 && isFilledEquale(value, x: x + 1, y: y))
                || !(y > 0 && isFilledEquale(value, x: x, y: y - 1))
                || !(y < h - 1 && isFilledEquale(value, x: x, y: y + 1))
        }
        func floodFill(_ value: FilledUInt, atX x: Int, y: Int) {
            let inValue = filledValueAt(x: x, y: y)
            
            func leftDownFillAt(x: Int, y: Int) {
                var x = x, y = y
                while true {
                    let ax = x, ay = y
                    while x > 0 && isFilledEquale(inValue, x: x - 1, y: y) { x -= 1 }
                    while y > 0 && isFilledEquale(inValue, x: x, y: y - 1) { y -= 1 }
                    if x == ax && y == ay { break }
                }
                fillAt(x: x, y: y)
            }
            func fillAt(x: Int, y: Int) {
                var lastRowLength = 0, x = x, y = y
                repeat {
                    var rowLength = 0, sx = x
                    if lastRowLength != 0 && !isFilledEquale(inValue, x: x, y: y) {
                        repeat {
                            lastRowLength -= 1
                            if lastRowLength == 0 { return }
                            x += 1
                        } while !isFilledEquale(inValue, x: x, y: y)
                        sx = x
                    } else {
                        while x != 0 && isFilledEquale(inValue, x: x - 1, y: y) {
                            x -= 1
                            fill(value, atX: x, y: y)
                            if y != 0 && isFilledEquale(inValue, x: x, y: y - 1) {
                                leftDownFillAt(x: x, y: y - 1)
                            }
                            rowLength += 1
                            lastRowLength += 1
                        }
                    }
                    
                    while sx < w && isFilledEquale(inValue, x: sx, y: y) {
                        fill(value, atX: sx, y: y)
                        rowLength += 1
                        sx += 1
                    }
                    if rowLength < lastRowLength {
                        let end = x + lastRowLength
                        sx += 1
                        while sx < end {
                            if isFilledEquale(inValue, x: sx, y: y) {
                                fillAt(x: sx, y: y)
                            }
                            sx += 1
                        }
                    } else if rowLength > lastRowLength && y != 0 {
                        var ux = x + lastRowLength
                        ux += 1
                        while ux < sx {
                            if isFilledEquale(inValue, x: ux, y: y - 1) {
                                leftDownFillAt(x: ux, y: y - 1)
                            }
                            ux += 1
                        }
                    }
                    lastRowLength = rowLength
                    y += 1
                } while lastRowLength != 0 && y < h
            }
            
            fillAt(x: x, y: y)
        }
        
        func nearestFill() {
            func nearestValueAt(x: Int, y: Int, maxRadius r: Int) -> FilledUInt? {
                let minX = max(x - r, 0), maxX = min(x + r, w - 1)
                let minY = max(y - r, 0), maxY = min(y + r, h - 1)
                guard minX <= maxX && minY <= maxY else {
                    return nil
                }
                let r² = r * r
                var minValue: FilledUInt?, minD² = Int.max
                for iy in minY...maxY {
                    for ix in minX...maxX {
                        if !isLine(x: ix, y: iy) && !isFilledEquale(0, x: ix, y: iy) {
                            let dx = ix - x, dy = iy - y
                            let d² = dx * dx + dy * dy
                            if d² < r² {
                                let value = filledValueAt(x: ix, y: iy)
                                if d² < minD² {
                                    minD² = d²
                                    minValue = value
                                }
                            }
                        }
                    }
                }
                return minValue
            }
            for y in 0..<h {
                for x in 0..<w {
                    if isLine(x: x, y: y) || isFilledEquale(0, x: x, y: y) {
                        if let v = nearestValueAt(x: x, y: y, maxRadius: 3) {
                            fill(v, atX: x, y: y)
                        } else if let v = nearestValueAt(x: x, y: y, maxRadius: 10) {
                            fill(v, atX: x, y: y)
                        }
                    }
                }
            }
        }
        
        func surfaces() -> [Surface] {
            func aroundSurface(with value: FilledUInt, atX fx: Int, y fy: Int) -> Surface {
                var points = [Point]()
                func pointAt(x: Int, y: Int) -> Point {
                    return Point(x: x, y: h - y)
                }
                var x = fx, y = fy
                func update(x nx: Int, y ny: Int) -> Bool {
                    if nx >= 0 && nx < w && ny >= 0 && ny < h
                        && filledValueAt(x: nx, y: ny) == value {
                        
                        x = nx
                        y = ny
                        return true
                    } else {
                        return false
                    }
                }
                func update(at index: Int) -> Bool {
                    if index == 0 {
                        return update(x: x - 1, y: y)
                    } else if index == 1 {
                        return update(x: x - 1, y: y + 1)
                    } else if index == 2 {
                        return update(x: x, y: y + 1)
                    } else if index == 3 {
                        return update(x: x + 1, y: y + 1)
                    } else if index == 4 {
                        return update(x: x + 1, y: y)
                    } else if index == 5 {
                        return update(x: x + 1, y: y - 1)
                    } else if index == 6 {
                        return update(x: x, y: y - 1)
                    } else if index == 7 {
                        return update(x: x - 1, y: y - 1)
                    } else {
                        return false
                    }
                }
                func point(at index: Int) -> Point? {
                    if index == 0 {
                        return pointAt(x: x, y: y)
                    } else if index == 2 {
                        return pointAt(x: x, y: y + 1)
                    } else if index == 4 {
                        return pointAt(x: x + 1, y: y + 1)
                    } else if index == 6 {
                        return pointAt(x: x + 1, y: y)
                    } else {
                        return nil
                    }
                }
                var lastPoint = pointAt(x: x, y: y)
                var oldPoint = lastPoint
                points.append(lastPoint)
                func append(_ p: Point) {
                    if lastPoint.x != p.x || lastPoint.y != p.y {
                        points.append(oldPoint)
                        lastPoint = p
                    }
                    oldPoint = p
                }
                
                var index = 0, firstIndexes = Array(repeating: false, count: 8)
                while true {
                    let isFirstPoint = x == fx && y == fy
                    var firstIndex = index
                    for _ in 0..<7 {
                        index = index + 1 > 7 ? 0 : index + 1
                        firstIndex = index
                        if update(at: index) {
                            index = index + 4 > 7 ? index - 4 : index + 4
                            break
                        } else {
                            if let point = point(at: index) {
                                append(point)
                            }
                        }
                    }
                    if isFirstPoint {
                        if firstIndexes[firstIndex] {
                            break
                        } else {
                            firstIndexes[firstIndex] = true
                        }
                    }
                }
                
                var oldP = points.first!, oldIndex = 0
                var previousP = oldP
                var nPoints = [Point]()
                nPoints.reserveCapacity(points.count)
                nPoints.append(oldP)
                let maxD = 0.25.cg
                for i in 1..<points.count {
                    let p = points[i]
                    for j in oldIndex..<i {
                        let d = points[j].distanceWithLine(ap: oldP, bp: p)
                        if d > maxD {
                            nPoints.append(previousP)
                            oldIndex = i
                            oldP = p
                        }
                    }
                    previousP = p
                }
                
                return Surface(points: nPoints, uuColor: UU(Color.random()))
            }
            
            var surfaces = [Surface]()
            for y in 0..<h {
                for x in 0..<w {
                    let v = filledValueAt(x: x, y: y)
                    if v != FilledUInt.max {
                        surfaces.append(aroundSurface(with: v, atX: x, y: y))
                        floodFill(FilledUInt.max, atX: x, y: y)
                    }
                }
            }
            return surfaces.sorted(by: {
                $0.path.boundingBoxOfPath.size < $1.path.boundingBoxOfPath.size
            }).reversed()
        }
        
        let lineValue: FilledUInt = 1
        for y in 0..<h {
            for x in 0..<w {
                if isLine(x: x, y: y) {
                    fill(lineValue, atX: x, y: y)
                }
            }
        }

        var value: FilledUInt = 2
        for y in 0..<h {
            for x in 0..<w {
                if isFilledEquale(0, x: x, y: y) && isGap4Way(1, x: x, y: y) {
                    floodFill(value, atX: x, y: y)
                    value = value + 1 <= FilledUInt.max ? value + 1 : 2
                }
            }
        }
        nearestFill()
        
        return surfaces()
    }
}
extension Drawing {
    static func +(lhs: Drawing, rhs: Drawing) -> Drawing {
        return Drawing(lines: lhs.lines + rhs.lines, surfaces: lhs.surfaces + rhs.surfaces)
    }
}
extension Drawing {
    func jointedPointViews() -> [View] {
        var capPointDic = [Point: Bool]()
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
        func jointedView(for p: Point) -> View {
            let view = View.knob
            view.fillColor = .red
            view.position = p
            return view
        }
        
        return capPointDic.compactMap { $0.value ? jointedView(for: $0.key) : nil }
    }
}
extension Drawing: Viewable {
    func viewWith<T: BinderProtocol>
        (binder: T, keyPath: ReferenceWritableKeyPath<T, Drawing>) -> ModelView {
        
        return DrawingView(binder: binder, keyPath: keyPath)
    }
}
extension Drawing: ObjectViewable {}

final class DrawingView<T: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = Drawing
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet {
            linesView.keyPath = keyPath.appending(path: \Model.lines)
            surfacesView.keyPath = keyPath.appending(path: \Model.surfaces)
        }
    }
    var notifications = [((DrawingView<Binder>, BasicNotification) -> ())]()
    
    let linesView: ArrayView<LineView<Binder>>
    let surfacesView: ArrayView<SurfaceView<Binder>>
    
    init(binder: T, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        linesView = ArrayView(binder: binder, keyPath: keyPath.appending(path: \Model.lines))
        surfacesView = ArrayView(binder: binder, keyPath: keyPath.appending(path: \Model.surfaces))
        
        super.init(isLocked: false)
        updateLinesColor()
        let view = View()
        view.children = [linesView]
        children = [surfacesView, view]
        updateWithModel()
    }
    
    var linesColor: Color? {
        didSet { updateLinesColor() }
    }
    func updateLinesColor() {
        if let linesColor = linesColor {
            linesView.elementViews.forEach { $0.fillColor = linesColor }
        } else {
            linesView.elementViews.forEach { $0.updateColor() }
        }
    }
    
    var viewScale = 1.0.cg {
        didSet {
            lassoPathView?.lineWidth = 1 / viewScale
        }
    }
    
    private(set) var lassoPathView: View?
    var lassoPathViewColor = Color.warning {
        didSet { lassoPathView?.fillColor = lassoPathViewColor }
    }
    var lassoPathViewFillColorComposition = Composition.anti {
        didSet { lassoPathView?.fillColorComposition = lassoPathViewFillColorComposition }
    }
    var lassoLine: Line? {
        didSet {
            if let lassoLine = lassoLine {
                if lassoPathView != nil {
                    lassoPathView?.path = lassoLine.fillPath()
                } else {
                    let lassoPathView = View(path: lassoLine.fillPath())
                    lassoPathView.lineColor = lassoPathViewColor
                    lassoPathView.fillColorComposition = lassoPathViewFillColorComposition
                    lassoPathView.lineWidth = 1 / viewScale
                    append(child: lassoPathView)
                    self.lassoPathView = lassoPathView
                }
            } else {
                if lassoPathView != nil {
                    lassoPathView?.removeFromParent()
                    lassoPathView = nil
                }
            }
        }
    }
    
    var minSize: Size {
        return model.imageBounds.size
    }
    func updateWithModel() {
        surfacesView.updateWithModel()
        linesView.updateWithModel()
        updateLinesColor()
    }
    override var isEmpty: Bool {
        return false
    }
    override func containsPath(_ p: Point) -> Bool {
        return true
    }
}
extension DrawingView: Movable {
    func move(with eventValue: DragEvent.Value, _ phase: Phase, _ version: Version) {
        
    }
    var movingOrigin: Point {
        get { return model.imageBounds.origin }
        set {
            let dp = newValue - binder[keyPath: keyPath].imageBounds.origin
            let affineTransform = Transform(translation: dp, z: 0, rotation: 0).affineTransform
            for (i, _) in model.lines.enumerated() {
                model.lines[i] = model.lines[i] * affineTransform
            }
            for (i, _) in model.surfaces.enumerated() {
                model.surfaces[i] = model.surfaces[i] * affineTransform
            }
            updateWithModel()
        }
    }
}
//extension DrawingView: CollectionAssignable {
//    func remove(with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version) {
//        push(Drawing(), to: version)
//    }
//}
