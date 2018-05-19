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

/**
 Issue: 線の描画の品質改善
 */
struct Line: Codable {
    struct Control: Equatable, Hashable {
        var point = Point(), pressure = 1.0.cg
        
        func mid(_ other: Control) -> Control {
            return Control(point: point.mid(other.point), pressure: (pressure + other.pressure) / 2)
        }
    }
    let controls: [Control]
    let imageBounds: Rect, firstAngle: Real, lastAngle: Real
    
    init(bezier: Bezier2,
         p0Pressure: Real, cpPressure: Real, p1Pressure: Real) {
        self.init(controls: [Control(point: bezier.p0, pressure: p0Pressure),
                             Control(point: bezier.cp, pressure: cpPressure),
                             Control(point: bezier.p1, pressure: p1Pressure)])
    }
    init(controls: [Control]) {
        self.controls = controls
        self.imageBounds = Line.imageBounds(with: controls)
        self.firstAngle = controls[0].point.tangential(controls[1].point)
        self.lastAngle = controls[controls.count - 2].point
            .tangential(controls[controls.count - 1].point)
    }
}
extension Line {
    func withInsert(_ control: Control, at i: Int) -> Line {
        return Line(controls: controls.withInserted(control, at: i))
    }
    func withRemoveControl(at i: Int) -> Line {
        return Line(controls: controls.withRemoved(at: i))
    }
    func withReplaced(_ control: Control, at i: Int) -> Line {
        return Line(controls: controls.withReplaced(control, at: i))
    }
    
    func applying(_ affine: CGAffineTransform) -> Line {
        return Line(controls: controls.map { Control(point: $0.point.applying(affine),
                                                     pressure: $0.pressure) })
    }
    func reversed() -> Line {
        return Line(controls: controls.reversed())
    }
    func warpedWith(deltaPoint dp: Point, isFirst: Bool) -> Line {
        guard controls.count >= 2 else {
            return self
        }
        var allD = 0.0.cg, oldP = firstPoint
        for i in 1..<controls.count {
            let p = controls[i].point
            allD += sqrt(p.distance²(oldP))
            oldP = p
        }
        oldP = firstPoint
        let reciprocalAllD = allD > 0 ? 1 / allD : 0
        var allAD = 0.0.cg
        return Line(controls: controls.map {
            let p = $0.point
            allAD += sqrt(p.distance²(oldP))
            oldP = p
            let t = isFirst ? 1 - allAD * reciprocalAllD : allAD * reciprocalAllD
            return Control(point: Point(x: $0.point.x + dp.x * t, y: $0.point.y + dp.y * t),
                           pressure: $0.pressure)
        })
    }
    func warpedWith(deltaPoint dp: Point, at index: Int) -> Line {
        guard controls.count >= 2 else {
            return self
        }
        var previousAllD = 0.0.cg, nextAllD = 0.0.cg, oldP = firstPoint
        for i in 1..<index {
            let p = controls[i].point
            previousAllD += sqrt(p.distance²(oldP))
            oldP = p
        }
        oldP = controls[index].point
        for i in index + 1..<controls.count {
            let p = controls[i].point
            nextAllD += sqrt(p.distance²(oldP))
            oldP = p
        }
        oldP = firstPoint
        let reciprocalPreviousAllD = previousAllD > 0 ? 1 / previousAllD : 0
        let reciprocalNextAllD = nextAllD > 0 ? 1 / nextAllD : 0
        var previousAllAD = 0.0.cg, nextAllAD = 0.0.cg, newControls = [controls[0]]
        for i in 1..<index {
            let p = controls[i].point
            previousAllAD += sqrt(p.distance²(oldP))
            let t = sqrt(previousAllAD * reciprocalPreviousAllD)
            newControls.append(Control(point: Point(x: p.x + dp.x * t, y: p.y + dp.y * t),
                                       pressure: controls[i].pressure))
            oldP = p
        }
        let p = controls[index].point
        newControls.append(Control(point: Point(x: p.x + dp.x, y: p.y + dp.y),
                                   pressure: controls[index].pressure))
        oldP = controls[index].point
        for i in index + 1..<controls.count {
            let p = controls[i].point
            nextAllAD += sqrt(p.distance²(oldP))
            let t = 1 - sqrt(nextAllAD * reciprocalNextAllD)
            newControls.append(Control(point: Point(x: p.x + dp.x * t, y: p.y + dp.y * t),
                                       pressure: controls[i].pressure))
            oldP = p
        }
        return Line(controls: newControls)
    }
    func warpedWith(deltaPoint dp: Point, controlPoint: Point,
                    minDistance: Real, maxDistance: Real) -> Line {
        return Line(controls: controls.map {
            let d =  hypot($0.point.x - controlPoint.x, $0.point.y - controlPoint.y)
            let ds = d > maxDistance ? 0 : (1 - (d - minDistance) / (maxDistance - minDistance))
            return Control(point: Point(x: $0.point.x + dp.x * ds, y: $0.point.y + dp.y * ds),
                           pressure: $0.pressure)
        })
    }
    func autoPressure(minPressure: Real = 0.5) -> Line {
        let maxAngle = .pi / 4.0.cg
        return Line(controls: controls.enumerated().map { i, control in
            if i == 0 || i == controls.count - 1 {
                return Control(point: control.point, pressure: minPressure)
            } else {
                let preControl = controls[i - 1], nextControl = controls[i + 1]
                let angle = abs(Point.differenceAngle(p0: preControl.point,
                                                      p1: control.point, p2: nextControl.point))
                let pressure = Real.linear(minPressure, 1, t: min(angle, maxAngle) / maxAngle)
                return Control(point: control.point, pressure: pressure)
            }
        })
    }
    
    func splited(at i: Int) -> Line {
        if i == 0 {
            return withInsert(controls[0].mid(controls[1]), at: 1)
        } else if i == controls.count - 1 {
            return withInsert(controls[controls.count - 1].mid(controls[controls.count - 2]),
                              at: controls.count - 1)
        } else {
            var cs = controls
            cs[i] = controls[i - 1].mid(controls[i])
            cs.insert(controls[i].mid(controls[i + 1]), at: i + 1)
            return Line(controls: cs)
        }
    }
    func removedControl(at i: Int) -> Line {
        var cs = controls
        if i == 0 {
            cs.removeFirst()
            cs[0].point = cs[0].point.mid(cs[1].point)
        } else if i == controls.count - 1 {
            cs.removeLast()
            cs[cs.count - 1].point = cs[cs.count - 2].point.mid(cs[cs.count - 1].point)
        } else {
            cs.remove(at: i)
        }
        return Line(controls: cs)
    }
    
    func splited(startIndex: Int, endIndex: Int) -> Line {
        return Line(controls: Array(controls[startIndex...endIndex]))
    }
    func splited(startIndex: Int, startT: Real, endIndex: Int, endT: Real,
                 isMultiLine: Bool = true) -> [Line] {
        func pressure(at i: Int, t: Real) -> Real {
            if controls.count == 2 {
                return Real.linear(controls[0].pressure, controls[1].pressure, t: t)
            } else if controls.count == 3 {
                return t < 0.5 ?
                    Real.linear(controls[0].pressure, controls[1].pressure, t: t * 2) :
                    Real.linear(controls[1].pressure, controls[2].pressure, t: (t - 0.5) * 2)
            } else {
                let previousPressure = i == 0 ?
                    controls[0].pressure :
                    (controls[i].pressure + controls[i + 1].pressure) / 2
                let nextPressure = i == controls.count - 3 ?
                    controls[controls.count - 1].pressure :
                    (controls[i + 1].pressure + controls[i + 2].pressure) / 2
                return i  > 0 ?
                    Real.linear(previousPressure, nextPressure, t: t) :
                    controls[i].pressure
            }
        }
        if startIndex == endIndex {
            let b = bezier(at: startIndex).clip(startT: startT, endT: endT)
            let pr0 = startIndex == 0 && startT == 0 ?
                controls[0].pressure :
                pressure(at: startIndex, t: startT)
            let pr1 = endIndex == controls.count - 3 && endT == 1 ?
                controls[controls.count - 1].pressure :
                pressure(at: endIndex, t: endT)
            return [Line(bezier: b, p0Pressure: pr0, cpPressure: (pr0 + pr1) / 2, p1Pressure: pr1)]
        } else if isMultiLine {
            var newLines = [Line]()
            let indexes = startIndex + 1..<endIndex + 2
            var cs = Array(controls[indexes])
            if startIndex == 0 && startT == 0 {
                cs.insert(controls[0], at: 0)
            } else {
                cs[0] = controls[startIndex + 1].mid(controls[startIndex + 2])
                let fprs0 = pressure(at: startIndex, t: startT), fprs1 = cs[0].pressure
                newLines.append(Line(bezier: bezier(at: startIndex).clip(startT: startT, endT: 1),
                                     p0Pressure: fprs0,
                                     cpPressure: (fprs0 + fprs1) / 2,
                                     p1Pressure: fprs1))
            }
            if endIndex == controls.count - 3 && endT == 1 {
                cs.append(controls[controls.count - 1])
                newLines.append(Line(controls: cs))
            } else {
                cs[cs.count - 1] = controls[endIndex].mid(controls[endIndex + 1])
                newLines.append(Line(controls: cs))
                let eprs0 = cs[cs.count - 1].pressure, eprs1 = pressure(at: endIndex, t: endT)
                newLines.append(Line(bezier: bezier(at: endIndex).clip(startT: 0, endT: endT),
                                     p0Pressure: eprs0,
                                     cpPressure: (eprs0 + eprs1) / 2,
                                     p1Pressure: eprs1))
            }
            return newLines
        } else {
            let indexes = startIndex + 1..<endIndex + 2
            var cs = Array(controls[indexes])
            if endIndex - startIndex >= 1 && cs.count >= 2 {
                cs[0].point = Point.linear(cs[0].point, cs[1].point, t: startT * 0.5)
                cs[cs.count - 1].point = Point.linear(cs[cs.count - 2].point,
                                                      cs[cs.count - 1].point,
                                                      t: endT * 0.5 + 0.5)
            }
            let fc = startIndex == 0 && startT == 0 ?
                Control(point: controls[0].point, pressure: controls[0].pressure) :
                Control(point: bezier(at: startIndex).position(withT: startT),
                        pressure: pressure(at: startIndex + 1, t: startT))
            cs.insert(fc, at: 0)
            let lc = endIndex == controls.count - 3 && endT == 1 ?
                Control(point: controls[controls.count - 1].point,
                        pressure: controls[controls.count - 1].pressure) :
                Control(point: bezier(at: endIndex).position(withT: endT),
                        pressure: pressure(at: endIndex + 1, t: endT))
            cs.append(lc)
            return [Line(controls: cs)]
        }
    }
    
    func bezierLine(withScale scale: Real) -> Line {
        if controls.count <= 2 {
            return controls.count < 2 ?
                self :
                Line(controls: [controls[0], controls[0].mid(controls[1]), controls[1]])
        } else if controls.count == 3 {
            return self
        } else {
            var maxD = 0.0.cg, maxControl = controls[0]
            for control in controls {
                let d = control.point.distanceWithLine(ap: firstPoint, bp: lastPoint)
                if d * scale > maxD {
                    maxD = d
                    maxControl = control
                }
            }
            let mcp = maxControl.point.nearestWithLine(ap: firstPoint, bp: lastPoint)
            let cp = 2 * maxControl.point - mcp
            return Line(controls: [controls[0],
                                   Line.Control(point: cp, pressure: maxControl.pressure),
                                   controls[controls.count - 1]])
        }
    }
    
    var isEmpty: Bool {
        return controls.isEmpty
    }
    
    var firstPoint: Point {
        return controls[0].point
    }
    var lastPoint: Point {
        return controls[controls.count - 1].point
    }
    private static func imageBounds(with controls: [Control]) -> Rect {
        if controls.isEmpty {
            return Rect.null
        } else if controls.count == 1 {
            return Rect(origin: controls[0].point, size: Size())
        } else if controls.count == 2 {
            return Bezier2.linear(controls[0].point, controls[controls.count - 1].point).bounds
        } else if controls.count == 3 {
            return Bezier2(p0: controls[0].point,
                           cp: controls[1].point, p1: controls[controls.count - 1].point).bounds
        } else {
            var connectP = controls[1].point.mid(controls[2].point)
            var b = Bezier2(p0: controls[0].point, cp: controls[1].point, p1: connectP).bounds
            for i in 1..<controls.count - 3 {
                let newConnectP = controls[i + 1].point.mid(controls[i + 2].point)
                b = b.union(Bezier2(p0: connectP, cp: controls[i + 1].point, p1: newConnectP).bounds)
                connectP = newConnectP
            }
            b = b.union(Bezier2(p0: connectP,
                                cp: controls[controls.count - 2].point,
                                p1: controls[controls.count - 1].point).bounds)
            return b
        }
    }
    static func imageBounds(with lines: [Line], lineWidth: Real) -> Rect {
        guard let firstBounds = lines.first?.imageBounds else {
            return Rect.null
        }
        let bounds = lines.reduce(into: firstBounds) { $0.formUnion($1.imageBounds) }
        return Line.visibleImageBoundsWith(imageBounds: bounds, lineWidth: lineWidth)
    }
    static func path(with lines: [Line], length: Real = 0) -> CGPath {
        guard !lines.isEmpty else {
            return CGMutablePath()
        }
        let path = CGMutablePath()
        for (i, line) in lines.enumerated() {
            line.appendBezierCurves(withIsMove: i == 0, in: path)
            let nextLine = lines[i + 1 < lines.count ? i + 1 : 0]
            if length > 0 && line.lastPoint != nextLine.firstPoint {
                path.addLine(to: line.lastExtensionPoint(withLength: length))
                path.addLine(to: nextLine.firstExtensionPoint(withLength: length))
            }
        }
        path.closeSubpath()
        return path
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
    
    func isFirst(at index: Int, t: Real) -> Bool {
        return controls.count <= 2 ? t < 0.5 : (Real(index) + t < Real(controls.count - 2) / 2)
    }
    
    struct BezierSequence: Sequence, IteratorProtocol {
        private let controls: [Line.Control]
        let underestimatedCount: Int
        
        init(_ controls: [Line.Control]) {
            self.controls = controls
            guard controls.count > 3 else {
                oldPoint = controls.first?.point ?? Point()
                underestimatedCount = controls.isEmpty ? 0 : 1
                return
            }
            oldPoint = controls[0].point
            underestimatedCount = controls.count - 2
        }
        
        private var i = 0, oldPoint: Point
        mutating func next() -> Bezier2? {
            guard controls.count > 3 else {
                if i == 0 && !controls.isEmpty {
                    i += 1
                    return controls.count < 3 ?
                        Bezier2.linear(controls[0].point, controls[controls.count - 1].point) :
                        Bezier2(p0: controls[0].point, cp: controls[1].point, p1: controls[2].point)
                } else {
                    return nil
                }
            }
            if i < controls.count - 3 {
                let connectP = controls[i + 1].point.mid(controls[i + 2].point)
                let bezier = Bezier2(p0: oldPoint, cp: controls[i + 1].point, p1: connectP)
                oldPoint = connectP
                i += 1
                return bezier
            } else if i == controls.count - 3 {
                i += 1
                return Bezier2(p0: oldPoint,
                               cp: controls[controls.count - 2].point,
                               p1: controls[controls.count - 1].point)
            } else {
                return nil
            }
        }
    }
    var bezierSequence: BezierSequence {
        return BezierSequence(controls)
    }
    
    func bezier(at i: Int) -> Bezier2 {
        guard controls.count > 3 else {
            return controls.count < 3 ?
                Bezier2.linear(controls[0].point, controls[controls.count - 1].point) :
                Bezier2(p0: controls[0].point, cp: controls[1].point, p1: controls[2].point)
        }
        if i == 0 {
            return Bezier2.firstSpline(controls[0].point, controls[1].point, controls[2].point)
        } else if i == controls.count - 3 {
            return Bezier2.endSpline(controls[controls.count - 3].point,
                                     controls[controls.count - 2].point,
                                     controls[controls.count - 1].point)
        } else {
            return Bezier2.spline(controls[i].point, controls[i + 1].point, controls[i + 2].point)
        }
    }
    
    func bezierT(at p: Point) -> (bezierIndex: Int, t: Real, distance²: Real)? {
        guard controls.count > 2 else {
            if controls.isEmpty {
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
    
    func appendBezierCurves(withIsMove isMove: Bool, in path: CGMutablePath) {
        guard let fp = controls.first?.point, let lp = controls.last?.point else { return }
        if isMove {
            path.move(to: fp)
        } else {
            path.addLine(to: fp)
        }
        if controls.count >= 3 {
            for i in 2..<controls.count - 1 {
                let control = controls[i], oldControl = controls[i - 1]
                path.addQuadCurve(to: oldControl.point.mid(control.point),
                                  control: oldControl.point)
            }
            path.addQuadCurve(to: lp, control: controls[controls.count - 2].point)
        } else {
            path.addLine(to: lp)
        }
    }
    
    static func maxDistance²(at p: Point, with lines: [Line]) -> Real {
        return lines.reduce(0.0.cg) { max($0, $1.maxDistance²(at: p)) }
    }
    static func centroidPoint(with lines: [Line]) -> Point? {
        let allPointsCount = lines.reduce(0) { $0 + $1.controls.count }
        guard allPointsCount > 0 else {
            return nil
        }
        let reciprocalCount = Real(1 / allPointsCount)
        let p = lines.reduce(Point()) { $1.controls.reduce($0) { $0 + $1.point } }
        return Point(x: p.x * reciprocalCount, y: p.y * reciprocalCount)
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
    
    func equalPoints(_ other: Line) -> Bool {
        if controls.elementsEqual(other.controls, by: { $0.point == $1.point }) {
            return true
        } else if controls.elementsEqual(other.controls.reversed(), by: { $0.point == $1.point }) {
            return true
        } else {
            return false
        }
    }
    
    struct MainPointSequence: Sequence, IteratorProtocol {
        private let controls: [Line.Control]
        private var bezierSequence: BezierSequence
        let underestimatedCount: Int
        
        private var i = 0
        mutating func next() -> Point? {
            if i == 0 {
                i += 1
                return controls.first?.point
            } else if i < controls.count - 1 {
                i += 1
                return bezierSequence.next()?.position(withT: 0.5)
            } else if i == controls.count - 1 {
                i += 1
                return controls.last?.point
            } else {
                return nil
            }
        }
        
        init(_ controls: [Line.Control]) {
            self.controls = controls
            bezierSequence = BezierSequence(controls)
            underestimatedCount = controls.count
        }
    }
    var mainPointSequence: MainPointSequence {
        return MainPointSequence(controls)
    }
    
    func mainPoint(at i: Int) -> Point {
        if i == 0 {
            return controls[0].point
        } else if i == controls.count - 1 {
            return controls[controls.count - 1].point
        } else {
            return bezier(at: i - 1).position(withT: 0.5)
        }
    }
    
    func mainPoint(withMainCenterPoint xp: Point, at i: Int) -> Point {
        guard i > 0 else {
            return controls[0].point
        }
        let bi = i - 1
        let m0 = bi == 0 ? 0 : 0.5.cg, m1 = bi == controls.count - 3 ? 1 : 0.5.cg
        let n0 = 1 - m0, n1 = 1 - m1, p0 = controls[bi].point, p2 = controls[bi + 2].point
        return (4 * xp - n0 * p0 - m1 * p2) / (m0 + n1 + 2)
    }
    
    func isReverse(from other: Line) -> Bool {
        let l0 = other.lastPoint, f1 = firstPoint, l1 = lastPoint
        return hypot²(l1.x - l0.x, l1.y - l0.y) < hypot²(f1.x - l0.x, f1.y - l0.y)
    }
    
    func firstExtensionPoint(withLength length: Real) -> Point {
        return extensionPointWith(p0: controls[1].point, p1: controls[0].point, length: length)
    }
    func lastExtensionPoint(withLength length: Real) -> Point {
        return extensionPointWith(p0: controls[controls.count - 2].point,
                                  p1: controls[controls.count - 1].point, length: length)
    }
    private func extensionPointWith(p0: Point, p1: Point, length: Real) -> Point {
        guard p0 != p1 else {
            return p1
        }
        let x = p1.x - p0.x, y = p1.y - p0.y
        let reciprocalD = 1 / hypot(x, y)
        return Point(x: p1.x + x * length * reciprocalD, y: p1.y + y * length * reciprocalD)
    }
    
    func angle(withPreviousLine preLine: Line) -> Real {
        return abs(lastAngle.differenceRotation(firstAngle))
    }
    static func isConnected(line: Line, isFirst: Bool, otherLine: Line, isOtherFirst: Bool) -> Bool {
        if isFirst {
            if isOtherFirst {
                let newP = line.controls[1].point.mid(otherLine.controls[1].point)
                if newP.isApproximatelyEqual(other: line.firstPoint) {
                    return true
                }
            } else {
                let newP = line.controls[1].point
                    .mid(otherLine.controls[otherLine.controls.count - 2].point)
                if newP.isApproximatelyEqual(other: line.firstPoint) {
                    return true
                }
            }
        } else {
            if isOtherFirst {
                let newP = line.controls[line.controls.count - 2].point
                    .mid(otherLine.controls[1].point)
                if newP.isApproximatelyEqual(other: line.lastPoint) {
                    return true
                }
            } else {
                let newP = line.controls[line.controls.count - 2].point
                    .mid(otherLine.controls[otherLine.controls.count - 2].point)
                if newP.isApproximatelyEqual(other: line.lastPoint) {
                    return true
                }
            }
        }
        return false
    }
    var strokeLastBoundingBox: Rect {
        guard controls.count > 4 else {
            return imageBounds
        }
        let b0 = Bezier2.spline(controls[controls.count - 4].point,
                                controls[controls.count - 3].point,
                                controls[controls.count - 2].point)
        let b1 = Bezier2.endSpline(controls[controls.count - 3].point,
                                   controls[controls.count - 2].point,
                                   controls[controls.count - 1].point)
        return b0.boundingBox.union(b1.boundingBox)
    }
    var pointsLength: Real {
        var length = 0.0.cg
        if var oldPoint = controls.first?.point {
            for control in controls {
                length += hypot(control.point.x - oldPoint.x, control.point.y - oldPoint.y)
                oldPoint = control.point
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
    //View
    static func drawMainPointsWith(lines: [Line], inColor: Color = .controlEditPointIn,
                                   outColor: Color = .controlPointOut,
                                   skinLineWidth: Real = 1, skinRadius: Real = 1.5,
                                   reciprocalScale s: Real, in ctx: CGContext) {
        let lineWidth = skinLineWidth * s * 0.5, mor = skinRadius * s
        lines.forEach { line in
            for (i, p) in line.mainPointSequence.enumerated() {
                if i != 0 && i != line.controls.count {
                    p.draw(radius: mor, lineWidth: lineWidth,
                           inColor: inColor, outColor: outColor, in: ctx)
                }
            }
        }
    }
    static func drawCapPointsWith(lines: [Line],
                                  inColor: Color = .controlPointCapIn,
                                  outColor: Color = .controlPointOut,
                                  jointInColor: Color = .controlPointJointIn,
                                  jointOutColor: Color = .controlPointOut,
                                  unionInColor: Color = .controlPointUnionIn,
                                  unionOutColor: Color = .controlPointOut,
                                  skinLineWidth: Real = 1, skinRadius: Real = 1.5,
                                  reciprocalScale s: Real, in ctx: CGContext) {
        let lineWidth = skinLineWidth * s * 0.5, mor = skinRadius * s
        guard var oldLine = lines.last else { return }
        for line in lines {
            let isUnion = oldLine.lastPoint == line.firstPoint
            if isUnion {
                if oldLine.controls[oldLine.controls.count - 2].point
                    .mid(line.controls[1].point).isApproximatelyEqual(other: line.firstPoint) {
                    line.firstPoint.draw(radius: mor, lineWidth: lineWidth,
                                         inColor: unionInColor, outColor: unionOutColor, in: ctx)
                } else {
                    line.firstPoint.draw(radius: mor, lineWidth: lineWidth,
                                         inColor:  jointInColor, outColor: jointOutColor, in: ctx)
                }
            } else {
                oldLine.lastPoint.draw(radius: mor, lineWidth: lineWidth,
                                       inColor: inColor, outColor: outColor, in: ctx)
                line.firstPoint.draw(radius: mor, lineWidth: lineWidth,
                                     inColor: inColor, outColor: outColor, in: ctx)
            }
            oldLine = line
        }
    }
    func draw(size: Real, in ctx: CGContext) {
        let s = size / 2
        guard ctx.boundingBoxOfClipPath.intersects(imageBounds.inset(by: -s)) else { return }
        if controls.count <= 2 {
            guard controls.count == 2 else { return }
            let firstTheta = firstAngle + .pi / 2
            let pres = s * controls[0].pressure, pres2 = s * controls[1].pressure
            let dp = Point(x: pres * cos(firstTheta), y: pres * sin(firstTheta))
            ctx.move(to: controls[0].point + dp)
            ctx.addArc(center: controls[controls.count - 1].point,
                       radius: pres2,
                       startAngle: firstTheta, endAngle: firstTheta - .pi,
                       clockwise: true)
            ctx.addArc(center: controls[0].point,
                       radius: pres,
                       startAngle: firstTheta - .pi, endAngle: firstTheta - .pi * 2,
                       clockwise: true)
            ctx.fillPath()
        } else {
            let firstTheta = firstAngle + .pi / 2, pres = s * controls[0].pressure
            var ps = [Point](), previousPressure = controls[0].pressure
            ctx.move(to: controls[0].point + Point(x: pres * cos(firstTheta),
                                                   y: pres * sin(firstTheta)))
            if controls.count == 3 {
                let bezier = self.bezier(at: 0)
                let pr0 = s * controls[0].pressure
                let pr1 = s * controls[1].pressure, pr2 = s * controls[2].pressure
                let length = bezier.p0.distance(bezier.cp) + bezier.cp.distance(bezier.p1)
                let count = Int(length)
                if count != 0 {
                    let splitDeltaT = 1 / length
                    var t = 0.0.cg
                    for _ in 0..<count {
                        t += splitDeltaT
                        let p = bezier.position(withT: t)
                        let pres = t < 0.5 ?
                            Real.linear(pr0, pr1, t: t * 2) :
                            Real.linear(pr1, pr2, t: (t - 0.5) * 2)
                        let dp = bezier.difference(withT: t)
                            .perpendicularDeltaPoint(withDistance: pres)
                        ctx.addLine(to: p + dp)
                        ps.append(p - dp)
                    }
                }
            } else {
                for (i, bezier) in bezierSequence.enumerated() {
                    let length = bezier.p0.distance(bezier.cp) + bezier.cp.distance(bezier.p1)
                    let nextPressure = i == controls.count - 3 ?
                        controls[controls.count - 1].pressure :
                        (controls[i + 1].pressure + controls[i + 2].pressure) / 2
                    let count = Int(length)
                    if count != 0 {
                        let splitDeltaT = 1 / length
                        var t = 0.0.cg
                        for _ in 0..<count {
                            t += splitDeltaT
                            let p = bezier.position(withT: t)
                            let pres = Real.linear(s * previousPressure, s * nextPressure, t: t)
                            let dp = bezier.difference(withT: t)
                                .perpendicularDeltaPoint(withDistance: pres)
                            ctx.addLine(to: p + dp)
                            ps.append(p - dp)
                        }
                    }
                    previousPressure = nextPressure
                }
            }
            let lastTheta = lastAngle + .pi / 2, pres2 = s * controls[controls.count - 1].pressure
            ctx.addArc(center: controls[controls.count - 1].point,
                       radius: pres2,
                       startAngle: lastTheta, endAngle: lastTheta - .pi,
                       clockwise: true)
            for p in ps.reversed() {
                ctx.addLine(to: p)
            }
            ctx.addArc(center: controls[0].point,
                       radius: pres,
                       startAngle: firstTheta - .pi, endAngle: firstTheta - .pi * 2,
                       clockwise: true)
            ctx.fillPath()
        }
    }
}
extension Line.Control: Codable {
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let point = try container.decode(Point.self)
        let pressure = try container.decode(Real.self)
        self.init(point: point, pressure: pressure)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(point)
        try container.encode(pressure)
    }
}
extension Line: Equatable {
    static func ==(lhs: Line, rhs: Line) -> Bool {
        return lhs.controls == rhs.controls
    }
}
extension Line: Hashable {
    var hashValue: Int {
        return Hash.uniformityHashValue(with: controls.map { $0.hashValue })
    }
}
extension Line: Referenceable {
    static let name = Text(english: "Line", japanese: "線")
}
extension Line: Interpolatable {
    static func linear(_ f0: Line, _ f1: Line, t: Real) -> Line {
        let count = max(f0.controls.count, f1.controls.count)
        return Line(controls: (0..<count).map { i in
            let f0c = f0.control(at: i, maxCount: count), f1c = f1.control(at: i, maxCount: count)
            return Control(point: Point.linear(f0c.point, f1c.point, t: t),
                           pressure: Real.linear(f0c.pressure, f1c.pressure, t: t))
        })
    }
    static func firstMonospline(_ f1: Line, _ f2: Line, _ f3: Line, with ms: Monospline) -> Line {
        let count = max(f1.controls.count, f2.controls.count, f3.controls.count)
        return Line(controls: (0..<count).map { i in
            let f1c = f1.control(at: i, maxCount: count)
            let f2c = f2.control(at: i, maxCount: count)
            let f3c = f3.control(at: i, maxCount: count)
            return Control(point: Point.firstMonospline(f1c.point, f2c.point, f3c.point, with: ms),
                           pressure: Real.firstMonospline(f1c.pressure, f2c.pressure,
                                                          f3c.pressure, with: ms))
        })
    }
    static func monospline(_ f0: Line, _ f1: Line, _ f2: Line, _ f3: Line,
                           with ms: Monospline) -> Line {
        let count = max(f0.controls.count, f1.controls.count, f2.controls.count, f3.controls.count)
        return Line(controls: (0..<count).map { i in
            let f0c = f0.control(at: i, maxCount: count), f1c = f1.control(at: i, maxCount: count)
            let f2c = f2.control(at: i, maxCount: count), f3c = f3.control(at: i, maxCount: count)
            return Control(point: Point.monospline(f0c.point, f1c.point,
                                                   f2c.point, f3c.point, with: ms),
                           pressure: Real.monospline(f0c.pressure, f1c.pressure,
                                                     f2c.pressure, f3c.pressure, with: ms))
        })
    }
    static func lastMonospline(_ f0: Line, _ f1: Line, _ f2: Line, with ms: Monospline) -> Line {
        let count = max(f0.controls.count, f1.controls.count, f2.controls.count)
        return Line(controls: (0..<count).map { i in
            let f0c = f0.control(at: i, maxCount: count)
            let f1c = f1.control(at: i, maxCount: count)
            let f2c = f2.control(at: i, maxCount: count)
            return Control(point: Point.lastMonospline(f0c.point, f1c.point, f2c.point, with: ms),
                           pressure: Real.lastMonospline(f0c.pressure, f1c.pressure,
                                                         f2c.pressure, with: ms))
        })
    }
    private func control(at i: Int, maxCount: Int) -> Control {
        if controls.count == maxCount {
            return controls[i]
        } else {
            let d = maxCount - controls.count
            let minD = d / 2
            if i < minD {
                return controls[0]
            } else if i > maxCount - (d - minD) - 1 {
                return controls[controls.count - 1]
            } else {
                return controls[i - minD]
            }
        }
    }
}
extension Line: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        let thumbnailView = View(drawClosure: { self.draw(with: $1.bounds, in: $0) })
        thumbnailView.frame = frame
        return thumbnailView
    }
    func draw(with bounds: Rect, in ctx: CGContext) {
        let imageBounds = self.visibleImageBounds(withLineWidth: 1)
        let c = CGAffineTransform.centering(from: imageBounds, to: bounds.inset(by: 5))
        ctx.concatenate(c.affine)
        draw(size: 0.5 / c.scale, in: ctx)
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
        let l0 = Line(controls: [Line.Control(point: p0, pressure: 1),
                                 Line.Control(point: p1, pressure: 1)])
        let l1 = Line(controls: [Line.Control(point: p1, pressure: 1),
                                 Line.Control(point: p2, pressure: 1)])
        let l2 = Line(controls: [Line.Control(point: p2, pressure: 1),
                                 Line.Control(point: p3, pressure: 1)])
        let l3 = Line(controls: [Line.Control(point: p3, pressure: 1),
                                 Line.Control(point: p0, pressure: 1)])
        return [l0, l1, l2, l3]
    }
    static func rectangle(_ rect: Rect) -> [Line] {
        let p0 = Point(x: rect.minX, y: rect.minY), p1 = Point(x: rect.maxX, y: rect.minY)
        let p2 = Point(x: rect.maxX, y: rect.maxY), p3 = Point(x: rect.minX, y: rect.maxY)
        let l0 = Line(controls: [Line.Control(point: p0, pressure: 1),
                                 Line.Control(point: p1, pressure: 1)])
        let l1 = Line(controls: [Line.Control(point: p1, pressure: 1),
                                 Line.Control(point: p2, pressure: 1)])
        let l2 = Line(controls: [Line.Control(point: p2, pressure: 1),
                                 Line.Control(point: p3, pressure: 1)])
        let l3 = Line(controls: [Line.Control(point: p3, pressure: 1),
                                 Line.Control(point: p0, pressure: 1)])
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
        return [Line(controls: newPoints.map { Line.Control(point: $0, pressure: 1) })]
    }
    static func regularPolygon(centerPosition cp: Point = Point(), radius r: Real = 50,
                               firstAngle: Real = .pi / 2, count: Int) -> [Line] {
        let points = [Point].circle(centerPosition: cp, radius: r,
                                    firstAngle: firstAngle, count: count)
        return points.enumerated().map {
            let p0 = $0.element, i = $0.offset
            let p1 = i + 1 < points.count ? points[i + 1] : points[0]
            return Line(controls: [Line.Control(point: p0, pressure: 1),
                                   Line.Control(point: p1, pressure: 1)])
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

struct LineLasso {
    let lines: [Line], path: CGPath
    init(lines: [Line]) {
        self.lines = lines
        self.path = Line.path(with: lines)
    }
    var imageBounds: Rect {
        return path.boundingBox
    }
    func contains(_ p: Point) -> Bool {
        return (imageBounds.contains(p) ? path.contains(p) : false)
    }
    
    func intersects(_ otherLine: Line) -> Bool {
        guard imageBounds.intersects(otherLine.imageBounds) else {
            return false
        }
        for line in lines {
            if line.intersects(otherLine) {
                return true
            }
        }
        for control in otherLine.controls {
            if contains(control.point) {
                return true
            }
        }
        return false
    }
    
    struct SplitItem {
        let isAround: Bool
        let indexes: [Index]
        struct Index {
            let startIndex: Int, startT: Real, endIndex: Int, endT: Real
        }
    }
    func splitItem(with otherLine: Line, isMultiLine: Bool = true) -> SplitItem {
        func intersectsLineImageBounds(_ otherLine: Line) -> Bool {
            for line in lines {
                if otherLine.imageBounds.intersects(line.imageBounds) {
                    return true
                }
            }
            return false
        }
        guard !otherLine.isEmpty && intersectsLineImageBounds(otherLine) else {
            return SplitItem(isAround: false, indexes: [])
        }
        
        var newSplitIndexes = [SplitItem.Index](), oldIndex = 0, oldT = 0.0.cg
        var splitLine = false, leftIndex = 0
        let firstPointInPath = path.contains(otherLine.firstPoint)
        let lastPointInPath = path.contains(otherLine.lastPoint)
        for (i0, b0) in otherLine.bezierSequence.enumerated() {
            guard var oldLassoLine = lines.last else { continue }
            let bis = lines.reduce(into: [BezierIntersection]()) { (bis, lassoLine) in
                guard !lassoLine.isEmpty else { return }
                let lp = oldLassoLine.lastPoint, fp = lassoLine.firstPoint
                if lp != fp {
                    bis += b0.intersections(Bezier2.linear(lp, fp))
                }
                for b1 in lassoLine.bezierSequence {
                    bis += b0.intersections(b1)
                }
                oldLassoLine = lassoLine
            }
            guard !bis.isEmpty else { continue }
            
            let sbis = bis.sorted { $0.t < $1.t }
            for bi in sbis {
                let newLeftIndex = leftIndex + (bi.isLeft ? 1 : -1)
                if firstPointInPath {
                    if leftIndex != 0 && newLeftIndex == 0 {
                        newSplitIndexes.append(SplitItem.Index(startIndex: oldIndex, startT: oldT,
                                                               endIndex: i0, endT: bi.t))
                    } else if leftIndex == 0 && newLeftIndex != 0 {
                        oldIndex = i0
                        oldT = bi.t
                    }
                } else {
                    if leftIndex != 0 && newLeftIndex == 0 {
                        oldIndex = i0
                        oldT = bi.t
                    } else if leftIndex == 0 && newLeftIndex != 0 {
                        newSplitIndexes.append(SplitItem.Index(startIndex: oldIndex, startT: oldT,
                                                               endIndex: i0, endT: bi.t))
                    }
                }
                leftIndex = newLeftIndex
            }
            splitLine = true
        }
        if splitLine && !lastPointInPath {
            let endIndex = otherLine.controls.count <= 2 ? 0 : otherLine.controls.count - 3
            newSplitIndexes.append(SplitItem.Index(startIndex: oldIndex, startT: oldT,
                                                   endIndex: endIndex, endT: 1))
        }
        if !newSplitIndexes.isEmpty {
            return SplitItem(isAround: true, indexes: newSplitIndexes)
        } else if !splitLine && firstPointInPath && lastPointInPath {
            return SplitItem(isAround: true, indexes: [])
        } else {
            return SplitItem(isAround: false, indexes: [])
        }
    }
    static func split(with otherLine: Line, _ splitItemIndexes: [SplitItem.Index],
                      isMultiLine: Bool = true) -> [Line] {
        return splitItemIndexes.reduce(into: [Line]()) { (lines, si) in
            lines += otherLine.splited(startIndex: si.startIndex, startT: si.startT,
                                       endIndex: si.endIndex, endT: si.endT,
                                       isMultiLine: isMultiLine)
        }
    }
    func split(with otherLine: Line, isMultiLine: Bool = true) -> (isAround: Bool, lines: [Line]) {
        let splitItem = self.splitItem(with: otherLine)
        if splitItem.isAround {
            return (true, LineLasso.split(with: otherLine, splitItem.indexes))
        } else {
            return (false, [])
        }
    }
}
