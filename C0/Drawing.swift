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
        view.children = lines.compactMap { $0.view(lineWidth: lineWidth, fillColor: .black) }
        return view
    }
    func surfacesWith(inFrame: Rect) -> [Surface] {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return []
        }
        let grayColorSpace = CGColorSpaceCreateDeviceGray()
        let size = inFrame.size
        guard let lineCTX = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                                      bitsPerComponent: MemoryLayout<LineUInt>.size * 8,
                                      bytesPerRow: 0, space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else {
                                        return []
        }
        guard let filledCTX = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                                        bitsPerComponent: MemoryLayout<FilledUInt>.size * 8,
                                        bytesPerRow: 0, space: grayColorSpace,
                                        bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
                                            return []
        }
        let view = surfacesRenderingViewWith(lineWidth: 1)
        view.bounds = inFrame
        view.render(in: lineCTX)
        return autoFill(in: filledCTX, from: lineCTX)
    }
    private func autoFill(in filledCTX: CGContext, from lineCTX: CGContext,
                          threshold: Real = 0) -> [Surface] {
        guard let lineData = lineCTX.data?.assumingMemoryBound(to: LineUInt.self),
            let filledData = filledCTX.data?.assumingMemoryBound(to: FilledUInt.self) else {
            return []
        }
        let t = UInt8(threshold * Real(UInt8.max))
        let lineBytesPerPixel = lineCTX.bitsPerPixel / lineCTX.bitsPerComponent
        let filledBytesPerPixel = filledCTX.bitsPerPixel / filledCTX.bitsPerComponent
        let w = lineCTX.width, h = lineCTX.height
        
        func alphaAt(x: Int, y: Int) -> LineUInt {
            let lineOffset = lineCTX.bytesPerRow * y + x * lineBytesPerPixel
            return lineData[lineOffset]
//            return lineData.load(fromByteOffset: lineOffset, as: LineUInt.self)
        }
        func isFill(x: Int, y: Int) -> Bool {
            return alphaAt(x: x, y: y) <= t
        }
        func filledValueAt(x: Int, y: Int) -> FilledUInt {
            let filledOffset = filledCTX.bytesPerRow * y + x * filledBytesPerPixel
            return filledData[filledOffset]
//            return filledData.load(fromByteOffset: filledOffset, as: FilledUInt.self)
        }
        func fill(_ value: FilledUInt, atX x: Int, y: Int) {
            let filledOffset = filledCTX.bytesPerRow * y + x * filledBytesPerPixel
            return filledData[filledOffset] = value
//            filledData.storeBytes(of: value, toByteOffset: filledOffset, as: FilledUInt.self)
        }
        func floodFill(_ value: FilledUInt, atX x: Int, y: Int) {
            enum DownUp {
                case down, up, none
            }
            struct Range {
                var minX: Int, maxX: Int, y: Int, downUp: DownUp
                var isExtendLeft: Bool, isExtendRight: Bool
            }
            
            var ranges = [Range(minX: x, maxX: x, y: y, downUp: .none,
                                isExtendLeft: true, isExtendRight: true)]
            fill(value, atX: x, y: y)
            
            while let range = ranges.last {
                ranges.removeLast()
                
                var minX = range.minX, maxX = range.maxX
                let ry = range.y
                if range.isExtendLeft {
                    while minX > 0 && isFill(x: minX - 1, y: ry) {
                        minX -= 1
                        fill(value, atX: minX, y: ry)
                    }
                }
                if range.isExtendRight {
                    while maxX < w - 1 && isFill(x: maxX + 1, y: ry) {
                        maxX += 1
                        fill(value, atX: maxX, y: ry)
                    }
                }
                let rMinX = range.minX - 1, rMaxX = range.maxX + 1
                
                func appendNextLineWith(y ny: Int, isNext: Bool, downUp: DownUp) {
                    var nrMinX = minX, isInRange = false
                    for var nx in minX...maxX {
                        let isEmpty = (isNext || (nx < rMinX || nx > rMaxX)) && isFill(x: nx, y: ny)
                        if !isInRange && isEmpty {
                            nrMinX = nx
                            isInRange = true
                        } else if isInRange && !isEmpty {
                            ranges.append(Range(minX: nrMinX, maxX: nx - 1, y: ny,
                                                downUp: downUp,
                                                isExtendLeft: nrMinX == minX, isExtendRight: false))
                            isInRange = false
                        }
                        if isInRange {
                            fill(value, atX: nx, y: ny)
                        }
                        if !isNext && nx == rMinX {
                            nx = rMaxX
                        }
                    }
                    if isInRange {
                        ranges.append(Range(minX: nrMinX, maxX: x - 1, y: ny,
                                            downUp: downUp,
                                            isExtendLeft: nrMinX == minX, isExtendRight: true))
                    }
                }
                if ry < h - 1 {
                    appendNextLineWith(y: ry + 1, isNext: range.downUp != .up, downUp: .down)
                }
                if ry > 0 {
                    appendNextLineWith(y: ry - 1, isNext: range.downUp != .down, downUp: .up)
                }
            }
        }
        
        func nearestFill() {
            func valueAt(x: Int, y: Int) -> FilledUInt? {
                if x >= 0 && x < w && y >= 0 && y < h {
                    let v = filledValueAt(x: x, y: y)
                    if v != 0 {
                        return v
                    }
                }
                return nil
            }
            func nearestValueAt(x: Int, y: Int, maxCount: Int = 100) -> FilledUInt? {
                var i = 0, x = x, y = y, count = 1, xd = 1, yd = 1
                while i < maxCount {
                    for _ in 0..<count {
                        x += xd
                        if let v = valueAt(x: x, y: y) {
                            return v
                        }
                    }
                    for _ in 0..<count {
                        y += yd
                        if let v = valueAt(x: x, y: y) {
                            return v
                        }
                    }
                    xd = -xd
                    yd = -yd
                    count += 1
                    i += count * 2
                }
                return nil
            }
            for y in 0..<h {
                for x in 0..<w {
                    if !isFill(x: x, y: y) {
                        if let v = nearestValueAt(x: x, y: y) {
                            fill(v, atX: x, y: y)
                        }
                    }
                }
            }
        }
        
        func surfaces() -> [Surface] {
            guard let filledData = filledCTX.data else {
                return []
            }
            let filledBytesPerPixel = filledCTX.bitsPerPixel / filledCTX.bitsPerComponent
            let w = filledCTX.width, h = filledCTX.height
            
            func filledValueAt(x: Int, y: Int) -> FilledUInt {
                let filledOffset = filledCTX.bytesPerRow * y + x * filledBytesPerPixel
                return filledData.load(fromByteOffset: filledOffset, as: FilledUInt.self)
            }
            func aroundSurface(with value: FilledUInt, atX fx: Int, y fy: Int) -> Surface {
                var points = [Point]()
                
                func isAround(x: Int, y: Int) -> Bool {
                    if x >= 0 && x < w && y >= 0 && y < h {
                        return filledValueAt(x: x, y: y) == value
                    } else {
                        return false
                    }
                }
                
                var x = fx, y = fy
                points.append(Point(x: x, y: y))
                while x != fx || y != fy {
                    if isAround(x: x - 1, y: y - 1) {
                        x -= 1
                        y -= 1
                    } else if filledValueAt(x: x, y: y - 1) == value {
                        y -= 1
                    } else if filledValueAt(x: x + 1, y: y - 1) == value {
                        x += 1
                        y -= 1
                    } else if filledValueAt(x: x + 1, y: y) == value {
                        x += 1
                    } else if filledValueAt(x: x + 1, y: y + 1) == value {
                        x += 1
                        y += 1
                    } else if filledValueAt(x: x, y: y + 1) == value {
                        y += 1
                    } else if filledValueAt(x: x - 1, y: y + 1) == value {
                        x -= 1
                        y += 1
                    } else if filledValueAt(x: x - 1, y: y) == value {
                        x -= 1
                    }
                    points.append(Point(x: x, y: y))
                }
                
                let line = Line(controls: points.map { Line.Control(point: $0, pressure: 1) })
                return Surface(line: line, uuColor: UU(Color.random()))
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
                $0.path.boundingBoxOfPath.size > $1.path.boundingBoxOfPath.size
            })
        }
        
        var value: FilledUInt = 1
        for y in 0..<h {
            for x in 0..<w {
                let v = filledValueAt(x: x, y: y)
                let a = alphaAt(x: x, y: y)
                if v != 0 && a > t {
                    floodFill(value, atX: x, y: y)
                    value = value &+ 1
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
extension Drawing: Interpolatable {
    static func linear(_ f0: Drawing, _ f1: Drawing, t: Real) -> Drawing {
        let lines = [Line].linear(f0.lines, f1.lines, t: t)
        let surfaces = [Surface].linear(f0.surfaces, f1.surfaces, t: t)
        return Drawing(lines: lines, surfaces: surfaces)
    }
    static func firstMonospline(_ f1: Drawing, _ f2: Drawing, _ f3: Drawing,
                                with ms: Monospline) -> Drawing {
        let lines = [Line].firstMonospline(f1.lines, f2.lines, f3.lines, with: ms)
        let surfaces = [Surface].firstMonospline(f1.surfaces, f2.surfaces, f3.surfaces, with: ms)
        return Drawing(lines: lines, surfaces: surfaces)
    }
    static func monospline(_ f0: Drawing, _ f1: Drawing, _ f2: Drawing, _ f3: Drawing,
                           with ms: Monospline) -> Drawing {
        let lines = [Line].monospline(f0.lines, f1.lines, f2.lines, f3.lines, with: ms)
        let surfaces = [Surface].monospline(f0.surfaces, f1.surfaces,
                                            f2.surfaces, f3.surfaces, with: ms)
        return Drawing(lines: lines, surfaces: surfaces)
    }
    static func lastMonospline(_ f0: Drawing, _ f1: Drawing, _ f2: Drawing,
                               with ms: Monospline) -> Drawing {
        let lines = [Line].lastMonospline(f0.lines, f1.lines, f2.lines, with: ms)
        let surfaces = [Surface].lastMonospline(f0.surfaces, f1.surfaces, f2.surfaces, with: ms)
        return Drawing(lines: lines, surfaces: surfaces)
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
        didSet { updateWithModel() }
    }
    var notifications = [((DrawingView<Binder>, BasicNotification) -> ())]()
    
    let linesView: ArrayView<Line, Binder>
    let surfacesView: ArrayView<Surface, Binder>
    
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
    
    var linesColor = Color.content {
        didSet { updateLinesColor() }
    }
    func updateLinesColor() {
        linesView.modelViews.forEach { $0.fillColor = linesColor }
    }
    
    var viewScale = 1.0.cg {
        didSet {
            lassoPathView?.lineWidth = 1 / viewScale
        }
    }
    var lassoPathView: View?
    var lassoCutLine: Line? {
        didSet {
            if let lassoCutLine = lassoCutLine {
                if lassoPathView != nil {
                    lassoPathView?.path = lassoCutLine.fillPath()
                } else {
                    let lassoPathView = View(path: lassoCutLine.fillPath())
                    lassoPathView.lineColor = .warning
                    lassoPathView.fillColorComposition = .anti
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
                model.surfaces[i].line = model.surfaces[i].line * affineTransform
            }
            updateWithModel()
        }
    }
}
extension DrawingView: CollectionAssignable {
    func remove(with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version) {
        push(Drawing(), to: version)
    }
}
