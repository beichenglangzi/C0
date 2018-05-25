/*
 Copyright 2018 S
 
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

struct Ellipse {
    var frame = Rect()
}

struct PathLine {
    struct Arc {
        var centerPoint: Point
        var endAngle: Real, circularOrientation: Orientation.Circular
    }
    enum Element {
        case linear(Point)
        case bezier2(point: Point, control: Point)
        case arc(Arc)
    }
    
    var firstPoint: Point
    var elements: [Element]
    
    init(firstPoint: Point = Point(), elements: [Element]) {
        self.firstPoint = firstPoint
        self.elements = elements
    }
    init(points: [Point]) {
        firstPoint = points.first!
        elements = (1..<points.count).map { .linear(points[$0]) }
    }
}

struct Path {
    var cg: CGPath {
        return mcg
    }
    private var mcg = CGMutablePath()
    
    private mutating func copyStorageIfShared() {
        if !isKnownUniquelyReferenced(&mcg), let mcg = mcg.mutableCopy() {
            self.mcg = mcg
        }
    }
    
    init() {}
    init(_ cg: CGPath) {
        let mcg = CGMutablePath()
        mcg.addPath(cg)
        self.mcg = mcg
    }
    init(_ mcg: CGMutablePath) {
        self.mcg = mcg
    }
    
    mutating func append(_ path: Path) {
        copyStorageIfShared()
        mcg.addPath(path.mcg)
    }
    mutating func append(_ rect: Rect) {
        copyStorageIfShared()
        mcg.addRect(rect)
    }
    mutating func append(_ rects: [Rect]) {
        copyStorageIfShared()
        mcg.addRects(rects)
    }
    mutating func append(_ ellipse: Ellipse) {
        mcg.addEllipse(in: ellipse.frame)
    }
    mutating func append(_ ellipses: [Ellipse]) {
        ellipses.forEach { mcg.addEllipse(in: $0.frame) }
    }
    mutating func append(_ pathLine: PathLine) {
        copyStorageIfShared()
        mcg.move(to: pathLine.firstPoint)
        pathLine.elements.forEach {
            switch $0 {
            case .linear(let p): mcg.addLine(to: p)
            case .bezier2(let p, let cp): mcg.addQuadCurve(to: p, control: cp)
            case .arc(let arc):
                let radius = mcg.currentPoint.distance(arc.centerPoint)
                let startAngle = arc.centerPoint.tangential(mcg.currentPoint)
                mcg.addArc(center: arc.centerPoint, radius: radius,
                           startAngle: startAngle, endAngle: arc.endAngle,
                           clockwise: arc.circularOrientation == .clockwise)
            }
        }
    }
    
    
    func contains(_ p: Point) -> Bool {
        return mcg.contains(p)
    }
    var boundingBoxOfPath: Rect {
        return mcg.boundingBoxOfPath
    }
}
extension Path {
    static func checkerboard(with size: Size, in frame: Rect) -> Path {
        var path = Path()
        path.append([Rect].checkerboard(with: size, in: frame))
        return path
    }
}
