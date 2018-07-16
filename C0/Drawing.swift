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
    //membranes
    static let lineWidth = 1.0.cg
}
extension Drawing {
    var imageBounds: Rect {
        return imageBounds(withLineWidth: Drawing.lineWidth)
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
            //isPressure
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
            return  pointIndex == line.points.count - 1
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
            return orientation == .first ? 0 : line.points.count - 1
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
                        cap.line.bezier(at: cap.line.points.count - 3)).minDistance²(at: p)
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
                for (i, mp) in line.points.enumerated() {
                    guard !(isVertex && i != 0 && i != line.points.count - 1) else { continue }
                    let d² = hypot²(point.x - mp.x, point.y - mp.y)
                    if d² < minD² {
                        minD² = d²
                        minLinePoint = LinePoint(line: line, lineIndex: j, pointIndex: i)
                        minPoint = mp
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
        let p: Point, isFirst = empi == 1 || empi == editLine.points.count - 1
        if isFirst {
            p = editLine.firstPoint
        } else if empi == editLine.points.count - 2 || empi == 0 {
            p = editLine.lastPoint
        } else {
            fatalError()
        }
        var snapLines = [(ap: Point, bp: Point)](), lastSnapLines = [(ap: Point, bp: Point)]()
        func snap(with lines: [Line]) {
            for line in lines {
                if editLine.points.count == 3 {
                    if line != editLine {
                        if line.firstPoint == editLine.firstPoint {
                            snapLines.append((line.points[1], editLine.firstPoint))
                        } else if line.lastPoint == editLine.firstPoint {
                            snapLines.append((line.points[line.points.count - 2],
                                              editLine.firstPoint))
                        }
                        if line.firstPoint == editLine.lastPoint {
                            lastSnapLines.append((line.points[1], editLine.lastPoint))
                        } else if line.lastPoint == editLine.lastPoint {
                            lastSnapLines.append((line.points[line.points.count - 2],
                                                  editLine.lastPoint))
                        }
                    }
                } else {
                    if line.firstPoint == p && !(line == editLine && isFirst) {
                        snapLines.append((line.points[1], p))
                    } else if line.lastPoint == p && !(line == editLine && !isFirst) {
                        snapLines.append((line.points[line.points.count - 2], p))
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
    func formViewWith(lineWidth: Real, lineColor: Color) -> View {
        let view = View()
        view.children = lines.compactMap { $0.view(lineWidth: lineWidth, fillColor: lineColor) }
        return view
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
        return Drawing(lines: lines)
    }
    static func firstMonospline(_ f1: Drawing, _ f2: Drawing, _ f3: Drawing,
                                with ms: Monospline) -> Drawing {
        let lines = [Line].firstMonospline(f1.lines, f2.lines, f3.lines, with: ms)
        return Drawing(lines: lines)
    }
    static func monospline(_ f0: Drawing, _ f1: Drawing, _ f2: Drawing, _ f3: Drawing,
                           with ms: Monospline) -> Drawing {
        let lines = [Line].monospline(f0.lines, f1.lines, f2.lines, f3.lines, with: ms)
        return Drawing(lines: lines)
    }
    static func lastMonospline(_ f0: Drawing, _ f1: Drawing, _ f2: Drawing,
                               with ms: Monospline) -> Drawing {
        let lines = [Line].lastMonospline(f0.lines, f1.lines, f2.lines, with: ms)
        return Drawing(lines: lines)
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
    
    var viewScale = 1.0.cg
    
    init(binder: T, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        super.init(isLocked: false)
        updateWithModel()
    }
    
    var minSize: Size {
        return model.imageBounds.size
    }
    func updateWithModel() {
        children = model.lines.enumerated().map { (i, line) in
            let view = line.concreteViewWith(binder: binder,
                                             keyPath: keyPath.appending(path: \Model.lines[i]))
            view.fillColor = .black
            return view
        }
    }
    override var isEmpty: Bool {
        return false
    }
    override func containsPath(_ p: Point) -> Bool {
        return true
    }
    override func at(_ p: Point) -> View? {
        guard let nearest = model.nearest(at: p, isVertex: false),
            nearest.minDistance² < Layouter.movablePadding ** 2 else {
                return containsPath(p) ? self : nil
        }
        
//        switch nearest.result {
//        case .linePoint(let linePoint):
//            return children[linePoint.lineIndex].children[linePoint.pointIndex]
//        case .lineCapResult(let lineCapResult):
//            if let lineCap = lineCapResult.lineCapsItem.lineCaps.first {
//                return children[lineCap.lineIndex].children[lineCap.pointIndex]
//            } else {
//                return containsPath(p) ? self : nil
//            }
//        }
        return nil
    }
}
