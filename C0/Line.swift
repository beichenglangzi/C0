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

struct Line: Codable {
//    var points = [Point]() {
//        didSet {
//            imageBounds = Line.imageBounds(with: points)
//        }
//    }
    var points: [Point] {
        get { return beziers.flatMap { [$0.p0, $0.p1] } }
        set {
            
        }
    }
    private(set) var imageBounds = Rect()
    
    var beziers = [Bezier2]()
    init(beziers: [Bezier2]) {
        self.beziers = beziers
        imageBounds = beziers.reduce(Rect.null) { $0.union($1.boundingBox) }
    }
    init(jointedBeziers: [Bezier2]) {
        self.init(points: [jointedBeziers[0].p0] + jointedBeziers.map { $0.p1 })
    }
    init(points: [Point] = []) {
        self.points = points
        imageBounds = Line.imageBounds(with: points)
    }
}
extension Line {
    func reversed() -> Line {
        return Line(points: points.reversed())
    }
    func warpedWith(deltaPoint dp: Point, isFirst: Bool) -> Line {
        guard points.count >= 2 else {
            return self
        }
        var allD = 0.0.cg, oldP = firstPoint
        for i in 1..<points.count {
            let p = points[i]
            allD += sqrt(p.distance²(oldP))
            oldP = p
        }
        oldP = firstPoint
        let reciprocalAllD = allD > 0 ? 1 / allD : 0
        var allAD = 0.0.cg
        return Line(points: points.map {
            let p = $0
            allAD += sqrt(p.distance²(oldP))
            oldP = p
            let t = isFirst ? 1 - allAD * reciprocalAllD : allAD * reciprocalAllD
            return $0 + dp * t
        })
    }
    func warpedWith(deltaPoint dp: Point, at index: Int) -> Line {
        guard points.count >= 2 else {
            return self
        }
        var previousAllD = 0.0.cg, nextAllD = 0.0.cg, oldP = firstPoint
        for i in 1..<index {
            let p = points[i]
            previousAllD += sqrt(p.distance²(oldP))
            oldP = p
        }
        oldP = points[index]
        for i in index + 1..<points.count {
            let p = points[i]
            nextAllD += sqrt(p.distance²(oldP))
            oldP = p
        }
        oldP = firstPoint
        let reciprocalPreviousAllD = previousAllD > 0 ? 1 / previousAllD : 0
        let reciprocalNextAllD = nextAllD > 0 ? 1 / nextAllD : 0
        var previousAllAD = 0.0.cg, nextAllAD = 0.0.cg, newPoints = [points[0]]
        for i in 1..<index {
            let p = points[i]
            previousAllAD += sqrt(p.distance²(oldP))
            let t = sqrt(previousAllAD * reciprocalPreviousAllD)
            newPoints.append(p + dp * t)
            oldP = p
        }
        let p = points[index]
        newPoints.append(p + dp)
        oldP = points[index]
        for i in index + 1..<points.count {
            let p = points[i]
            nextAllAD += sqrt(p.distance²(oldP))
            let t = 1 - sqrt(nextAllAD * reciprocalNextAllD)
            newPoints.append(p + dp * t)
            oldP = p
        }
        return Line(points: newPoints)
    }
    func warpedWith(deltaPoint dp: Point, controlPoint: Point,
                    minDistance: Real, maxDistance: Real) -> Line {
        return Line(points: points.map {
            let d =  hypot($0.x - controlPoint.x, $0.y - controlPoint.y)
            let ds = d > maxDistance ? 0 : (1 - (d - minDistance) / (maxDistance - minDistance))
            return $0 + dp * ds
        })
    }
    
    func splited(at i: Int) -> Line {
        if i == 0 {
            var line = self
            line.points[1] = points[0].mid(points[1])
            return line
        } else if i == points.count - 1 {
            var line = self
            line.points[points.count - 1]
                = points[points.count - 1].mid(points[points.count - 2])
            return line
        } else {
            var cs = points
            cs[i] = points[i - 1].mid(points[i])
            cs.insert(points[i].mid(points[i + 1]), at: i + 1)
            return Line(points: cs)
        }
    }
    
    func splited(startIndex: Int, startT: Real, endIndex: Int, endT: Real) -> [Line] {
        let beziers = bezierSequence.map { $0 }
        if startIndex == endIndex {
            return [Line(jointedBeziers: [beziers[startIndex].clip(startT: startT, endT: endT)])]
        } else {
            let sb = beziers[startIndex].clip(startT: 0, endT: startT)
            let eb = beziers[endIndex].clip(startT: endT, endT: 1)
            if endIndex - (startIndex + 1) > 0 {
                let bs = beziers[startIndex + 1..<endIndex]
                return [Line(jointedBeziers: [sb] + bs + [eb])]
            } else {
                return [Line(jointedBeziers: [sb, eb])]
            }
        }
    }
//    func splited(startIndex: Int, startT: Real, endIndex: Int, endT: Real,
//                 isMultiLine: Bool = true) -> [Line] {
//        func pressure(at i: Int, t: Real) -> Real {
//            if points.count == 2 {
//                return Real.linear(points[0].pressure, points[1].pressure, t: t)
//            } else if points.count == 3 {
//                return t < 0.5 ?
//                    Real.linear(points[0].pressure, points[1].pressure, t: t * 2) :
//                    Real.linear(points[1].pressure, points[2].pressure, t: (t - 0.5) * 2)
//            } else {
//                let previousPressure = i == 0 ?
//                    points[0].pressure :
//                    (points[i].pressure + points[i + 1].pressure) / 2
//                let nextPressure = i == points.count - 3 ?
//                    points[points.count - 1].pressure :
//                    (points[i + 1].pressure + points[i + 2].pressure) / 2
//                return i  > 0 ?
//                    Real.linear(previousPressure, nextPressure, t: t) :
//                    points[i].pressure
//            }
//        }
//        if startIndex == endIndex {
//            let b = bezier(at: startIndex).clip(startT: startT, endT: endT)
//            let pr0 = startIndex == 0 && startT == 0 ?
//                points[0].pressure :
//                pressure(at: startIndex, t: startT)
//            let pr1 = endIndex == points.count - 3 && endT == 1 ?
//                points[points.count - 1].pressure :
//                pressure(at: endIndex, t: endT)
//            return [Line(bezier: b, p0Pressure: pr0, cpPressure: (pr0 + pr1) / 2, p1Pressure: pr1)]
//        } else if isMultiLine {
//            var newLines = [Line]()
//            let indexes = startIndex + 1..<endIndex + 2
//            var cs = Array(points[indexes])
//            if startIndex == 0 && startT == 0 {
//                cs.insert(points[0], at: 0)
//            } else {
//                cs[0] = points[startIndex + 1].mid(points[startIndex + 2])
//                let fprs0 = pressure(at: startIndex, t: startT), fprs1 = cs[0].pressure
//                newLines.append(Line(bezier: bezier(at: startIndex).clip(startT: startT, endT: 1),
//                                     p0Pressure: fprs0,
//                                     cpPressure: (fprs0 + fprs1) / 2,
//                                     p1Pressure: fprs1))
//            }
//            if endIndex == points.count - 3 && endT == 1 {
//                cs.append(points[points.count - 1])
//                newLines.append(Line(points: cs))
//            } else {
//                cs[cs.count - 1] = points[endIndex].mid(points[endIndex + 1])
//                newLines.append(Line(points: cs))
//                let eprs0 = cs[cs.count - 1].pressure, eprs1 = pressure(at: endIndex, t: endT)
//                newLines.append(Line(bezier: bezier(at: endIndex).clip(startT: 0, endT: endT),
//                                     p0Pressure: eprs0,
//                                     cpPressure: (eprs0 + eprs1) / 2,
//                                     p1Pressure: eprs1))
//            }
//            return newLines
//        } else {
//            let indexes = startIndex + 1..<endIndex + 2
//            var cs = Array(points[indexes])
//            if endIndex - startIndex >= 1 && cs.count >= 2 {
//                cs[0].point = Point.linear(cs[0].point, cs[1].point, t: startT * 0.5)
//                cs[cs.count - 1].point = Point.linear(cs[cs.count - 2].point,
//                                                      cs[cs.count - 1].point,
//                                                      t: endT * 0.5 + 0.5)
//            }
//            let fc = startIndex == 0 && startT == 0 ?
//                Point(point: points[0].point, pressure: points[0].pressure) :
//                Point(point: bezier(at: startIndex).position(withT: startT),
//                        pressure: pressure(at: startIndex + 1, t: startT))
//            cs.insert(fc, at: 0)
//            let lc = endIndex == points.count - 3 && endT == 1 ?
//                Point(point: points[points.count - 1].point,
//                        pressure: points[points.count - 1].pressure) :
//                Point(point: bezier(at: endIndex).position(withT: endT),
//                        pressure: pressure(at: endIndex + 1, t: endT))
//            cs.append(lc)
//            return [Line(points: cs)]
//        }
//    }
    
    func approximatedBezierLine(withScale scale: Real) -> Line {
        if points.count <= 2 {
            return points.count < 2 ?
                self :
                Line(points: [points[0], points[0].mid(points[1]), points[1]])
        } else if points.count == 3 {
            return self
        } else {
            var maxD = 0.0.cg, maxPoint = points[0]
            for point in points {
                let d = point.distanceWithLine(ap: firstPoint, bp: lastPoint)
                if d * scale > maxD {
                    maxD = d
                    maxPoint = point
                }
            }
            let mcp = maxPoint.nearestWithLine(ap: firstPoint, bp: lastPoint)
            let cp = 2 * maxPoint - mcp
            return Line(points: [points[0],
                                 cp,
                                 points[points.count - 1]])
        }
    }
    
    var isEmpty: Bool {
        return points.isEmpty
    }
    
    var firstPoint: Point {
        return points[0]
    }
    var lastPoint: Point {
        return points[points.count - 1]
    }
    
    static func imageBounds(with points: [Point]) -> Rect {
        if points.isEmpty {
            return Rect.null
        } else if points.count == 1 {
            return Rect(origin: points[0], size: Size())
        } else if points.count == 2 {
            return Bezier2.linear(points[0], points[points.count - 1]).bounds
        } else {
            return BezierSequence(points).reduce(Rect.null) { $0.union($1.boundingBox) }
        }
    }
    static func imageBounds(with lines: [Line], lineWidth: Real) -> Rect {
        guard let firstBounds = lines.first?.imageBounds else {
            return Rect.null
        }
        let bounds = lines.reduce(into: firstBounds) { $0.formUnion($1.imageBounds) }
        return Line.visibleImageBoundsWith(imageBounds: bounds, lineWidth: lineWidth)
    }
    static func visibleLineWidth(withLineWidth lineWidth: Real) -> Real {
        return lineWidth * sqrt(2) / 2
    }
    func visibleImageBounds(withLineWidth lineWidth: Real) -> Rect {
        return imageBounds.inset(by: -lineWidth * sqrt(2) / 2)
    }
    static func visibleImageBoundsWith(imageBounds: Rect, lineWidth: Real) -> Rect {
        return imageBounds.inset(by: -lineWidth * sqrt(2) / 2)
    }
    
    struct BezierSequence: Sequence, IteratorProtocol {
        private let points: [Point]
        let underestimatedCount: Int
        
        init(_ points: [Point]) {
            self.points = points
            guard points.count > 3 else {
                oldPoint = points.first ?? Point()
                underestimatedCount = points.isEmpty ? 0 : 1
                return
            }
            oldPoint = points[0]
            underestimatedCount = points.count - 2
        }
        
        private var i = 0, oldPoint: Point
        mutating func next() -> Bezier2? {
            guard points.count > 3 else {
                if i == 0 && !points.isEmpty {
                    i += 1
                    return points.count < 3 ?
                        Bezier2.linear(points[0], points[points.count - 1]) :
                        Bezier2(p0: points[0], cp: points[1], p1: points[2])
                } else {
                    return nil
                }
            }
            if i < points.count - 3 {
                let connectP = points[i + 1].mid(points[i + 2])
                let bezier = Bezier2(p0: oldPoint, cp: points[i + 1], p1: connectP)
                oldPoint = connectP
                i += 1
                return bezier
            } else if i == points.count - 3 {
                i += 1
                return Bezier2(p0: oldPoint,
                               cp: points[points.count - 2],
                               p1: points[points.count - 1])
            } else {
                return nil
            }
        }
    }
    var bezierSequence: BezierSequence {
        return BezierSequence(points)
    }
    
    func bezier(at i: Int) -> Bezier2 {
        guard points.count > 3 else {
            return points.count < 3 ?
                Bezier2.linear(points[0], points[points.count - 1]) :
                Bezier2(p0: points[0], cp: points[1], p1: points[2])
        }
        if i == 0 {
            return Bezier2.firstSpline(points[0], points[1], points[2])
        } else if i == points.count - 3 {
            return Bezier2.endSpline(points[points.count - 3],
                                     points[points.count - 2],
                                     points[points.count - 1])
        } else {
            return Bezier2.spline(points[i], points[i + 1], points[i + 2])
        }
    }
    
    func bezierT(at p: Point) -> (bezierIndex: Int, t: Real, distance²: Real)? {
        guard points.count > 2 else {
            if points.isEmpty {
                return nil
            } else {
                let t = p.tWithLineSegment(ap: firstPoint, bp: lastPoint)
                let d = p.distanceWithLineSegment(ap: firstPoint, bp: lastPoint)
                return (0, t, d * d)
            }
        }
        var minD² = Real.infinity, minT = 0.0.cg, minBezierIndex = 0
        for (i, bezier) in bezierSequence.enumerated() {
            let nearest = bezier.nearest(at: p)
            if nearest.distance² < minD² {
                minD² = nearest.distance²
                minT = nearest.t
                minBezierIndex = i
            }
        }
        return (minBezierIndex, minT, minD²)
    }
    func bezierT(withLength length: Real) -> (b: Bezier2, t: Real)? {
        var bs: (b: Bezier2, t: Real)?, allD = 0.0.cg
        for b in bezierSequence {
            let d = b.length()
            let newAllD = allD + d
            if length < newAllD && d > 0 {
                bs = (b, b.t(withLength: length - allD))
                break
            }
            allD = newAllD
        }
        return bs
    }
    
    var bezierCurveElementsTuple: (firstPoint: Point, elements: [PathLine.Element])? {
        guard let fp = points.first, let lp = points.last else {
            return nil
        }
        var elements = [PathLine.Element]()
        if points.count >= 3 {
            for i in 2..<points.count - 1 {
                let control = points[i], oldPoint = points[i - 1]
                let p = oldPoint.mid(control)
                elements.append(.bezier2(point: p, control: oldPoint))
            }
            elements.append(.bezier2(point: lp, control: points[points.count - 2]))
        } else {
            elements.append(.linear(lp))
        }
        return (fp, elements)
    }
    
    func minDistance²(at p: Point) -> Real {
        var minD² = Real.infinity
        for b in bezierSequence {
            minD² = min(minD², b.minDistance²(at: p))
        }
        return minD²
    }
    func maxDistance²(at p: Point) -> Real {
        var maxD² = 0.0.cg
        for b in bezierSequence {
            maxD² = max(maxD², b.maxDistance²(at: p))
        }
        return maxD²
    }
    
    func isReverse(from other: Line) -> Bool {
        let l0 = other.lastPoint, f1 = firstPoint, l1 = lastPoint
        return hypot²(l1.x - l0.x, l1.y - l0.y) < hypot²(f1.x - l0.x, f1.y - l0.y)
    }
    
    var pointsLinearLength: Real {
        var length = 0.0.cg
        if var oldPoint = points.first {
            for point in points {
                length += hypot(point.x - oldPoint.x, point.y - oldPoint.y)
                oldPoint = point
            }
        }
        return length
    }
    
    func intersects(_ bezier: Bezier2) -> Bool {
        guard  imageBounds.intersects(bezier.boundingBox) else {
            return false
        }
        for b in bezierSequence {
            if bezier.intersects(b) {
                return true
            }
        }
        return false
    }
    func intersects(_ other: Line) -> Bool {
        guard imageBounds.intersects(other.imageBounds) else {
            return false
        }
        for bezier in bezierSequence {
            if other.intersects(bezier) {
                return true
            }
        }
        return false
    }
    func intersects(_ bounds: Rect) -> Bool {
        guard imageBounds.intersects(bounds) else {
            return false
        }
        if bounds.contains(firstPoint) {
            return true
        } else {
            let x0y0 = bounds.origin, x1y0 = Point(x: bounds.maxX, y: bounds.minY)
            let x0y1 = Point(x: bounds.minX, y: bounds.maxY)
            let x1y1 = Point(x: bounds.maxX, y: bounds.maxY)
            return intersects(Bezier2.linear(x0y0, x1y0))
                || intersects(Bezier2.linear(x1y0, x1y1))
                || intersects(Bezier2.linear(x1y1, x0y1))
                || intersects(Bezier2.linear(x0y1, x0y0))
        }
    }
}
extension Line {
    func concreteViewWith<T>
        (binder: T,
         keyPath: ReferenceWritableKeyPath<T, Line>) -> ModelView where T: BinderProtocol {
        
        return LineView(binder: binder, keyPath: keyPath)
    }
    func view(lineWidth size: Real, fillColor: Color) -> View {
        let path = self.path(lineWidth: size)
        let view = View(path: path)
        view.fillColor = fillColor
        return view
    }
    func path(lineWidth size: Real) -> Path {
        let s = size / 2
        
        guard let firstPoint = beziers.first?.p0 else {
            return Path()
        }
        var es = [PathLine.Element](), res = [PathLine.Element]()
        for bezier in beziers {
            let length = bezier.p0.distance(bezier.cp) + bezier.cp.distance(bezier.p1)
            let count = Int(length)
            if count > 0 {
                let splitDeltaT = 1 / length
                var t = 0.0.cg
                for _ in 0..<count {
                    t += splitDeltaT
                    let p = bezier.position(withT: t)
                    let dp = bezier.difference(withT: t)
                        .perpendicularDeltaPoint(withDistance: s)
                    es.append(.linear(p + dp))
                    res.append(.linear(p - dp))
                }
            }
        }
        es += res.reversed()
        var path = Path()
        path.append(PathLine(firstPoint: firstPoint, elements: es))
        return path
        
        if points.count <= 2 {
            guard points.count == 2 else {
                return Path()
            }
            let firstTheta = points[0].tangential(points[1]) + .pi / 2
            let dp0 = Point(x: cos(firstTheta), y: sin(firstTheta))
            let dp1 = Point(x: cos(firstTheta), y: sin(firstTheta))
            
            let fp = points[0] + dp0
            let p0 = points[1] + dp1
            let arc0 = PathLine.Arc(radius: s,
                                    startAngle: firstTheta + .pi, endAngle: firstTheta - .pi)
            let p1 = points[0] - dp0
            let arc1 = PathLine.Arc(radius: s,
                                    startAngle: firstTheta - .pi, endAngle: firstTheta + .pi)
            let pathLine = PathLine(firstPoint: fp, elements: [.linear(p0), .arc(arc0),
                                                               .linear(p1), .arc(arc1)])
            
            var path = Path()
            path.append(pathLine)
            return path
        } else {
            let firstTheta = points[0].tangential(points[1]) + .pi / 2
            var es = [PathLine.Element](), res = [PathLine.Element]()
            let fp = points[0] + Point(x: cos(firstTheta), y: sin(firstTheta))
            if points.count == 3 {
                let bezier = self.bezier(at: 0)
                let length = bezier.p0.distance(bezier.cp) + bezier.cp.distance(bezier.p1)
                let count = Int(length)
                if count > 0 {
                    let splitDeltaT = 1 / length
                    var t = 0.0.cg
                    for _ in 0..<count {
                        t += splitDeltaT
                        let p = bezier.position(withT: t)
                        let dp = bezier.difference(withT: t)
                            .perpendicularDeltaPoint(withDistance: s)
                        es.append(.linear(p + dp))
                        res.append(.linear(p - dp))
                    }
                }
            } else {
                for bezier in bezierSequence {
                    let length = bezier.p0.distance(bezier.cp) + bezier.cp.distance(bezier.p1)
                    let count = Int(length)
                    if count > 0 {
                        let splitDeltaT = 1 / length
                        var t = 0.0.cg
                        for _ in 0..<count {
                            t += splitDeltaT
                            let p = bezier.position(withT: t)
                            let dp = bezier.difference(withT: t)
                                .perpendicularDeltaPoint(withDistance: s)
                            es.append(.linear(p + dp))
                            res.append(.linear(p - dp))
                        }
                    }
                }
            }
            
            let lp = points[points.count - 1]
            let lastTheta = points[points.count - 2].tangential(points[points.count - 1]) + .pi / 2
            es.append(.linear(lp + Point(x: cos(lastTheta), y: sin(lastTheta))))
            res.append(.linear(lp - Point(x: cos(lastTheta), y: sin(lastTheta))))
            
            es.append(.arc(PathLine.Arc(radius: s,
                                        startAngle: lastTheta,
                                        endAngle: lastTheta + .pi)))
            es += res.reversed()
            es.append(.linear(points[0] - Point(x: cos(firstTheta), y: sin(firstTheta))))
            es.append(.arc(PathLine.Arc(radius: s,
                                        startAngle: firstTheta + .pi,
                                        endAngle: firstTheta)))
            
            var path = Path()
            path.append(PathLine(firstPoint: fp, elements: es))
            return path
        }
    }
}
extension Line: AppliableAffineTransform {
    static func *(lhs: Line, rhs: AffineTransform) -> Line {
        return Line(points: lhs.points.map { $0 * rhs })
    }
}
extension Line: Equatable {
    static func ==(lhs: Line, rhs: Line) -> Bool {
        return lhs.points == rhs.points
    }
}
extension Line: Hashable {
    var hashValue: Int {
        return Hash.uniformityHashValue(with: points.map { $0.hashValue })
    }
}
extension Line: Referenceable {
    static let name = Text(english: "Line", japanese: "線")
}
extension Line: Interpolatable {
    static func linear(_ f0: Line, _ f1: Line, t: Real) -> Line {
        return Line(points: [Point].linear(f0.points, f1.points, t: t))
    }
    static func firstMonospline(_ f1: Line, _ f2: Line, _ f3: Line, with ms: Monospline) -> Line {
        return Line(points: [Point].firstMonospline(f1.points, f2.points, f3.points, with: ms))
    }
    static func monospline(_ f0: Line, _ f1: Line, _ f2: Line, _ f3: Line,
                           with ms: Monospline) -> Line {
        return Line(points: [Point].monospline(f0.points, f1.points, f2.points, f3.points, with: ms))
    }
    static func lastMonospline(_ f0: Line, _ f1: Line, _ f2: Line, with ms: Monospline) -> Line {
        return Line(points: [Point].lastMonospline(f0.points, f1.points, f2.points, with: ms))
    }
}
extension Line: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect) -> View {
        let thumbnailView = View(drawClosure: { self.draw(with: $2, in: $0) })
        thumbnailView.lineColor = .formBorder
        thumbnailView.frame = frame
        return thumbnailView
    }
    func draw(with bounds: Rect, in ctx: CGContext) {
        let imageBounds = self.visibleImageBounds(withLineWidth: 1)
        let c = AffineTransform.centering(from: imageBounds, to: bounds.inset(by: 5))
        ctx.concatenate(c.affine)
//        draw(size: 0.5 / c.scale, in: ctx)
    }
}
extension Line: Viewable {
    func standardViewWith<T: BinderProtocol>
        (binder: T, keyPath: ReferenceWritableKeyPath<T, Line>) -> ModelView {
        
        return MiniView(binder: binder, keyPath: keyPath)
    }
}
extension Line: ObjectViewable {}

extension Array where Element == Line {
    func maxDistance²(at p: Point) -> Real {
        return reduce(0.0.cg) { Swift.max($0, $1.maxDistance²(at: p)) }
    }
    var centroidPoint: Point? {
        let allPointsCount = reduce(0) { $0 + $1.points.count }
        guard allPointsCount > 0 else {
            return nil
        }
        let reciprocalCount = Real(1 / allPointsCount)
        let p = reduce(Point()) { $1.points.reduce($0) { $0 + $1 } }
        return Point(x: p.x * reciprocalCount, y: p.y * reciprocalCount)
    }
}
extension Array where Element == Line {
    static let triangleName = Text(english: "Triangle", japanese: "正三角形")
    static let squareName = Text(english: "Square", japanese: "正方形")
    static let pentagonName = Text(english: "Pentagon", japanese: "正五角形")
    static let hexagonName = Text(english: "Hexagon", japanese: "正六角形")
    static let circleName = Text(english: "Circle", japanese: "円")
    
    static func triangle(centerPosition cp: Point = Point(),
                         radius r: Real = 50) -> [Line] {
        return regularPolygon(centerPosition: cp, radius: r, count: 3)
    }
    static func square(centerPosition cp: Point = Point(),
                       polygonRadius r: Real = 50) -> [Line] {
        let p0 = Point(x: cp.x - r, y: cp.y - r), p1 = Point(x: cp.x + r, y: cp.y - r)
        let p2 = Point(x: cp.x + r, y: cp.y + r), p3 = Point(x: cp.x - r, y: cp.y + r)
        let l0 = Line(points: [p0, p1]), l1 = Line(points: [p1, p2])
        let l2 = Line(points: [p2, p3]), l3 = Line(points: [p3, p0])
        return [l0, l1, l2, l3]
    }
    static func rectangle(_ rect: Rect) -> [Line] {
        let p0 = Point(x: rect.minX, y: rect.minY), p1 = Point(x: rect.maxX, y: rect.minY)
        let p2 = Point(x: rect.maxX, y: rect.maxY), p3 = Point(x: rect.minX, y: rect.maxY)
        let l0 = Line(points: [p0, p1]), l1 = Line(points: [p1, p2])
        let l2 = Line(points: [p2, p3]), l3 = Line(points: [p3, p0])
        return [l0, l1, l2, l3]
    }
    static func pentagon(centerPosition cp: Point = Point(),
                         radius r: Real = 50) -> [Line] {
        return regularPolygon(centerPosition: cp, radius: r, count: 5)
    }
    static func hexagon(centerPosition cp: Point = Point(),
                        radius r: Real = 50) -> [Line] {
        return regularPolygon(centerPosition: cp, radius: r, count: 6)
    }
    static func circle(centerPosition cp: Point = Point(),
                       radius r: Real = 50) -> [Line] {
        let count = 8
        let theta = .pi / Real(count)
        let fp = Point(x: cp.x, y: cp.y + r)
        let points = [Point].circle(centerPosition: cp,
                                    radius: r / cos(theta),
                                    firstAngle: .pi / 2 + theta,
                                    count: count)
        let newPoints = [fp] + points + [fp]
        return [Line(points: newPoints)]
    }
    static func regularPolygon(centerPosition cp: Point = Point(), radius r: Real = 50,
                               firstAngle: Real = .pi / 2, count: Int) -> [Line] {
        let points = [Point].circle(centerPosition: cp, radius: r,
                                    firstAngle: firstAngle, count: count)
        return points.enumerated().map {
            let p0 = $0.element, i = $0.offset
            let p1 = i + 1 < points.count ? points[i + 1] : points[0]
            return Line(points: [p0, p1])
        }
    }
}
extension Array where Element == Point {
    static func circle(centerPosition cp: Point = Point(),
                       radius r: Real = 50,
                       firstAngle: Real = .pi / 2,
                       count: Int) -> [Point] {
        var angle = firstAngle, theta = (2 * .pi) / Real(count)
        return (0..<count).map { _ in
            let p = Point(x: cp.x + r * cos(angle), y: cp.y + r * sin(angle))
            angle += theta
            return p
        }
    }
}

final class LineView<T: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = Line
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((LineView<Binder>, BasicNotification) -> ())]()
    
    var width = 1.0.cg
    
    init(binder: T, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        super.init(path: Path(), isLocked: false)
        updateWithModel()
    }
    
    var minSize: Size {
        return model.imageBounds.size
    }
    func updateWithModel() {
        path = model.path(lineWidth: width)
        children = model.points.enumerated().map { (i, control) in
            let view = PointView(binder: binder,
                                 keyPath: keyPath.appending(path: \Model.points[i]),
                                 radius: 1.5)
            view.notifications.append { [unowned self] _, _ in
                self.path = self.model.path(lineWidth: self.width)
            }
            return view
        }
    }
}
