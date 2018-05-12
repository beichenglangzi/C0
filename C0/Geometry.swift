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

struct Geometry: Equatable {
    let lines: [Line], path: CGPath
    init(lines: [Line] = []) {
        self.lines = lines
        self.path = Line.path(with: lines, length: 0.5)
    }
    
    private static let distance = 6.0.cg, vertexLineLength = 10.0.cg, minSnapRatio = 0.0625.cg
    init(lines: [Line], scale: Real) {
        guard let firstLine = lines.first else {
            self.lines = []
            self.path = CGMutablePath()
            return
        }
        guard lines.count > 1 else {
            let snapedPointLines = Geometry.snapedPointLinesWith(lines: [firstLine.autoPressure()],
                                                                 scale: scale)
            self.lines = snapedPointLines
            self.path = Line.path(with: snapedPointLines)
            return
        }
        
        enum FirstEnd {
            case first, end
        }
        var cellLines = [firstLine]
        var oldLines = lines, firstEnds = [FirstEnd.first], oldP = firstLine.lastPoint
        oldLines.removeFirst()
        while !oldLines.isEmpty {
            var minLine = oldLines[0], minFirstEnd = FirstEnd.first
            var minIndex = 0, minD = Real.infinity
            for (i, aLine) in oldLines.enumerated() {
                let firstP = aLine.firstPoint, lastP = aLine.lastPoint
                let fds = hypot²(firstP.x - oldP.x, firstP.y - oldP.y)
                let lds = hypot²(lastP.x - oldP.x, lastP.y - oldP.y)
                if fds < lds {
                    if fds < minD {
                        minD = fds
                        minLine = aLine
                        minIndex = i
                        minFirstEnd = .first
                    }
                } else {
                    if lds < minD {
                        minD = lds
                        minLine = aLine
                        minIndex = i
                        minFirstEnd = .end
                    }
                }
            }
            oldLines.remove(at: minIndex)
            cellLines.append(minLine)
            firstEnds.append(minFirstEnd)
            oldP = minFirstEnd == .first ? minLine.lastPoint : minLine.firstPoint
        }
        let count = 10000 / (cellLines.count * cellLines.count)
        for _ in 0..<count {
            var isChanged = false
            for ai0 in 0..<cellLines.count - 1 {
                for bi0 in ai0 + 1..<cellLines.count {
                    let ai1 = ai0 + 1, bi1 = bi0 + 1 < cellLines.count ? bi0 + 1 : 0
                    let a0Line = cellLines[ai0], a0IsFirst = firstEnds[ai0] == .first
                    let a1Line = cellLines[ai1], a1IsFirst = firstEnds[ai1] == .first
                    let b0Line = cellLines[bi0], b0IsFirst = firstEnds[bi0] == .first
                    let b1Line = cellLines[bi1], b1IsFirst = firstEnds[bi1] == .first
                    let a0 = a0IsFirst ? a0Line.lastPoint : a0Line.firstPoint
                    let a1 = a1IsFirst ? a1Line.firstPoint : a1Line.lastPoint
                    let b0 = b0IsFirst ? b0Line.lastPoint : b0Line.firstPoint
                    let b1 = b1IsFirst ? b1Line.firstPoint : b1Line.lastPoint
                    if a0.distance(a1) + b0.distance(b1) > a0.distance(b0) + a1.distance(b1) {
                        cellLines[ai1] = b0Line
                        firstEnds[ai1] = b0IsFirst ? .end : .first
                        cellLines[bi0] = a1Line
                        firstEnds[bi0] = a1IsFirst ? .end : .first
                        isChanged = true
                    }
                }
            }
            if !isChanged {
                break
            }
        }
        for (i, line) in cellLines.enumerated() {
            if firstEnds[i] == .end {
                cellLines[i] = line.reversed()
            }
        }
        
        let newLines = Geometry.snapedPointLinesWith(lines: cellLines.map { $0.autoPressure() },
                                                     scale: scale)
        self.lines = newLines
        self.path = Line.path(with: newLines)
    }
    static func snapedPointLinesWith(lines: [Line], scale: Real) -> [Line] {
        guard var oldLine = lines.last else {
            return []
        }
        let vd = distance * distance / scale
        return lines.map { line in
            let lp = oldLine.lastPoint, fp = line.firstPoint
            let d = lp.distance²(fp)
            let controls: [Line.Control]
            if d < vd * (line.pointsLength / vertexLineLength).clip(min: 0.1, max: 1) {
                let dp = Point(x: fp.x - lp.x, y: fp.y - lp.y)
                var cs = line.controls, dd = 1.0.cg
                for (i, fp) in line.controls.enumerated() {
                    cs[i].point = Point(x: fp.point.x - dp.x * dd, y: fp.point.y - dp.y * dd)
                    dd *= 0.5
                    if dd <= minSnapRatio || i >= line.controls.count - 2 {
                        break
                    }
                }
                controls = cs
            } else {
                controls = line.controls
            }
            oldLine = line
            return Line(controls: controls)
        }
    }

    func applying(_ affine: CGAffineTransform) -> Geometry {
        return Geometry(lines: lines.map { $0.applying(affine) })
    }
    func warpedWith(deltaPoint dp: Point, controlPoint: Point,
                    minDistance: Real, maxDistance: Real) -> Geometry {
        func warped(p: Point) -> Point {
            let d =  hypot²(p.x - controlPoint.x, p.y - controlPoint.y)
            let ds = d > maxDistance ? 0 : (1 - (d - minDistance) / (maxDistance - minDistance))
            return Point(x: p.x + dp.x * ds, y: p.y + dp.y * ds)
        }
        let newLines = lines.map { $0.warpedWith(deltaPoint: dp, controlPoint: controlPoint,
                                                 minDistance: minDistance, maxDistance: maxDistance) }
        return Geometry(lines: newLines)
    }
    
    static func geometriesWithInserLines(with geometries: [Geometry],
                                         lines: [Line], atLinePathIndex pi: Int) -> [Geometry] {
        let i = pi + 1
        return geometries.map {
            if i == $0.lines.count {
                return Geometry(lines: $0.lines + lines)
            } else if i < $0.lines.count {
                return Geometry(lines: Array($0.lines[..<i]) + lines + Array($0.lines[i...]))
            } else {
                return $0
            }
        }
    }
    static func geometriesWithSplitedControl(with geometries: [Geometry],
                                             at i: Int, pointIndex: Int) -> [Geometry] {
        return geometries.map {
            if i < $0.lines.count {
                var lines = $0.lines
                lines[i] = lines[i].splited(at: pointIndex).autoPressure()
                return Geometry(lines: lines)
            } else {
                return $0
            }
        }
    }
    static func geometriesWithRemovedControl(with geometries: [Geometry],
                                             atLineIndex li: Int, index i: Int) -> [Geometry] {
        return geometries.map {
            if li < $0.lines.count {
                var lines = $0.lines
                if lines[li].controls.count == 2 {
                    lines.remove(at: li)
                } else {
                    lines[li] = lines[li].removedControl(at: i).autoPressure()
                }
                return Geometry(lines: lines)
            } else {
                return $0
            }
        }
    }
    static func bezierLineGeometries(with geometries: [Geometry], scale: Real) -> [Geometry] {
        return geometries.map {
            return Geometry(lines: $0.lines.map { $0.bezierLine(withScale: scale) })
        }
    }
    
    struct NearestBezier {
        let lineIndex: Int, bezierIndex: Int, t: Real, minDistance²: Real
    }
    func nearestBezier(with point: Point)-> NearestBezier? {
        guard !lines.isEmpty else {
            return nil
        }
        var minD² = Real.infinity, minT = 0.0.cg, minLineIndex = 0, minBezierIndex = 0
        for (li, line) in lines.enumerated() {
            for (i, bezier) in line.bezierSequence.enumerated() {
                let nearest = bezier.nearest(at: point)
                if nearest.distance² < minD² {
                    minT = nearest.t
                    minBezierIndex = i
                    minLineIndex = li
                    minD² = nearest.distance²
                }
            }
        }
        return NearestBezier(lineIndex: minLineIndex, bezierIndex: minBezierIndex,
                             t: minT, minDistance²: minD²)
    }
    func nearestPathLineIndex(at p: Point) -> Int {
        var minD = Real.infinity, minIndex = 0
        for (i, line) in lines.enumerated() {
            let nextLine = lines[i + 1 < lines.count ? i + 1 : 0]
            let d = p.distanceWithLineSegment(ap: line.lastPoint, bp: nextLine.firstPoint)
            if d < minD {
                minD = d
                minIndex = i
            }
        }
        return minIndex
    }
    
    func beziers(with indexes: [Int]) -> [Line] {
        return indexes.map { lines[$0] }
    }
    var isEmpty: Bool {
        return lines.isEmpty
    }
    
    var imageBounds: Rect {
        return path.boundingBoxOfPath
    }
    
    func maxDistance²(at p: Point) -> Real {
        return Line.maxDistance²(at: p, with: lines)
    }
    func minDistance²(at p: Point, maxDistance²: Real) -> Real {
        var minD² = Real.infinity
        for (i, line) in lines.enumerated() {
            let d² = line.minDistance²(at: p)
            if d² < minD² && d² < maxDistance² {
                minD² = d²
            }
            let nextIndex = i + 1 >= lines.count ? 0 : i + 1
            let nextLine = lines[nextIndex]
            let lld = p.distanceWithLineSegment(ap: line.lastPoint, bp: nextLine.firstPoint)
            let ld² = lld * lld
            if ld² < minD² && ld² < maxDistance² {
                minD² = ld²
            }
        }
        return minD²
    }
    
    func contains(_ p: Point) -> Bool {
        return path.contains(p)
    }
    func contains(_ bounds: Rect) -> Bool {
        guard !isEmpty && imageBounds.intersects(bounds) else {
            return false
        }
        let x0y0 = bounds.origin
        let x1y0 = Point(x: bounds.maxX, y: bounds.minY)
        let x0y1 = Point(x: bounds.minX, y: bounds.maxY)
        let x1y1 = Point(x: bounds.maxX, y: bounds.maxY)
        if contains(x0y0) || contains(x1y0) || contains(x0y1) || contains(x1y1) {
            return true
        } else {
            return intersects(bounds)
        }
    }
    func contains(_ other: Geometry) -> Bool {
        guard !isEmpty && !other.isEmpty && imageBounds.contains(other.imageBounds) else {
            return false
        }
        for line in lines {
            for aLine in other.lines {
                if line.intersects(aLine) {
                    return false
                }
            }
        }
        for aLine in other.lines {
            if !contains(aLine.firstPoint) || !contains(aLine.lastPoint) {
                return false
            }
        }
        return true
    }
    
    func intersects(_ bounds: Rect) -> Bool {
        guard !isEmpty && imageBounds.intersects(bounds) else {
            return false
        }
        if !path.isEmpty {
            if path.contains(bounds.origin)
                || path.contains(Point(x: bounds.maxX, y: bounds.minY))
                || path.contains(Point(x: bounds.minX, y: bounds.maxY))
                || path.contains(Point(x: bounds.maxX, y: bounds.maxY)) {
                
                return true
            }
        }
        for line in lines {
            if line.intersects(bounds) {
                return true
            }
        }
        return false
    }
    func intersects(_ other: Geometry) -> Bool {
        guard !isEmpty && !other.isEmpty && imageBounds.intersects(other.imageBounds) else {
            return false
        }
        for line in lines {
            for aLine in other.lines {
                if line.intersects(aLine) {
                    return true
                }
            }
        }
        for aLine in other.lines {
            if contains(aLine.firstPoint) || contains(aLine.lastPoint) {
                return true
            }
        }
        for line in lines {
            if other.contains(line.firstPoint) || other.contains(line.lastPoint) {
                return true
            }
        }
        return false
    }
    func intersects(_ lasso: LineLasso) -> Bool {
        guard !isEmpty && imageBounds.intersects(lasso.imageBounds) else {
            return false
        }
        for line in lines {
            for aLine in lasso.lines {
                if aLine.intersects(line) {
                    return true
                }
            }
        }
        for line in lines {
            if lasso.contains(line.firstPoint) || lasso.contains(line.lastPoint) {
                return true
            }
        }
        return false
    }
    func intersectsLines(_ bounds: Rect) -> Bool {
        guard !isEmpty && imageBounds.intersects(bounds) else {
            return false
        }
        for line in lines {
            if line.intersects(bounds) {
                return true
            }
        }
        if intersectsClosePathLines(bounds) {
            return true
        }
        return false
    }
    func intersectsClosePathLines(_ bounds: Rect) -> Bool {
        guard var lp = lines.last?.lastPoint else {
            return false
        }
        for line in lines {
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
        return false
    }
    
    func isSnapped(_ other: Geometry) -> Bool {
        for line in lines {
            for otherLine in other.lines {
                if line.firstPoint == otherLine.firstPoint
                    || line.firstPoint == otherLine.lastPoint
                    || line.lastPoint == otherLine.firstPoint
                    || line.lastPoint == otherLine.lastPoint {
                    
                    return true
                }
            }
        }
        return false
    }
    
    //view
    func clip(in ctx: CGContext, closure: () -> Void) {
        guard !path.isEmpty else { return }
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        closure()
        ctx.restoreGState()
    }
    func addPath(in ctx: CGContext) {
        guard !path.isEmpty else { return }
        ctx.addPath(path)
    }
    func fillPath(in ctx: CGContext) {
        guard !path.isEmpty else { return }
        ctx.addPath(path)
        ctx.fillPath()
    }
    func fillPath(with color: Color, _ path: CGPath, in ctx: CGContext) {
        ctx.setFillColor(color.cg)
        ctx.addPath(path)
        ctx.fillPath()
    }
    func drawLines(withColor color: Color, reciprocalScale: Real, in ctx: CGContext) {
        ctx.setFillColor(color.cg)
        draw(withLineWidth: 0.5 * reciprocalScale, in: ctx)
    }
    func drawPathLine(withReciprocalScale reciprocalScale: Real, in ctx: CGContext) {
        ctx.setLineWidth(0.5 * reciprocalScale)
        ctx.setStrokeColor(Color.getSetBorder.cg)
        for (i, line) in lines.enumerated() {
            let nextLine = lines[i + 1 < lines.count ? i + 1 : 0]
            if line.lastPoint != nextLine.firstPoint {
                ctx.move(to: line.lastExtensionPoint(withLength: 0.5))
                ctx.addLine(to: nextLine.firstExtensionPoint(withLength: 0.5))
            }
        }
        ctx.strokePath()
    }
    func drawSkin(lineColor: Color, subColor: Color, backColor: Color = .getSetBorder,
                  skinLineWidth: Real = 1,
                  reciprocalScale: Real, reciprocalAllScale: Real, in ctx: CGContext) {
        fillPath(with: subColor, path, in: ctx)
        ctx.setFillColor(backColor.cg)
        draw(withLineWidth: 1 * reciprocalAllScale, in: ctx)
        ctx.setFillColor(lineColor.cg)
        draw(withLineWidth: skinLineWidth * reciprocalScale, in: ctx)
    }
    func draw(withLineWidth lineWidth: Real, in ctx: CGContext) {
        lines.forEach { $0.draw(size: lineWidth, in: ctx) }
    }
}
extension Geometry: Interpolatable {
    static func linear(_ f0: Geometry, _ f1: Geometry, t: Real) -> Geometry {
        let lines = [Line].linear(f0.lines, f1.lines, t: t)
        return Geometry(lines: lines)
    }
    static func firstMonospline(_ f1: Geometry, _ f2: Geometry, _ f3: Geometry,
                                with ms: Monospline) -> Geometry {
        let lines = [Line].firstMonospline(f1.lines, f2.lines, f3.lines, with: ms)
        return Geometry(lines: lines)
    }
    static func monospline(_ f0: Geometry, _ f1: Geometry, _ f2: Geometry, _ f3: Geometry,
                           with ms: Monospline) -> Geometry {
        let lines = [Line].monospline(f0.lines, f1.lines, f2.lines, f3.lines, with: ms)
        return Geometry(lines: lines)
    }
    static func lastMonospline(_ f0: Geometry, _ f1: Geometry, _ f2: Geometry,
                              with ms: Monospline) -> Geometry {
        let lines = [Line].lastMonospline(f0.lines, f1.lines, f2.lines, with: ms)
        return Geometry(lines: lines)
    }
}
extension Geometry: Referenceable {
    static let name = Text(english: "Geometry", japanese: "ジオメトリ")
}
extension Geometry: Codable {
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let lines = try container.decode([Line].self)
        self.init(lines: lines)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(lines)
    }
}
