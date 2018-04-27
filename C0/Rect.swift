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

import Foundation

/**
 Issue: Core Graphicsとの置き換え
 */
struct _Rect: Equatable {
    var origin = _Point(), size = _Size()
    init(origin: _Point = _Point(), size: _Size = _Size()) {
        self.origin = origin
        self.size = size
    }
    init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        self.init(origin: _Point(x: x, y: y), size: _Size(width: width, height: height))
    }
    
    func insetBy(dx: CGFloat, dy: CGFloat) -> _Rect {
        return _Rect(x: minX + dx, y: minY + dy,
                    width: width - dx * 2, height: height - dy * 2)
    }
    func inset(by width: CGFloat) -> _Rect {
        return insetBy(dx: width, dy: width)
    }
    
    var minX: CGFloat {
        return origin.x
    }
    var minY: CGFloat {
        return origin.y
    }
    var midX: CGFloat {
        return origin.x + size.width / 2
    }
    var midY: CGFloat {
        return origin.y + size.height / 2
    }
    var maxX: CGFloat {
        return origin.x + size.width
    }
    var maxY: CGFloat {
        return origin.y + size.height
    }
    var width: CGFloat {
        return size.width
    }
    var height: CGFloat {
        return size.height
    }
    var isEmpty: Bool {
        return origin.isEmpty && size.isEmpty
    }
    func union(_ other: _Rect) -> _Rect {
        let minX = min(self.minX, other.minX)
        let maxX = max(self.maxX, other.maxX)
        let minY = min(self.minY, other.minY)
        let maxY = max(self.maxY, other.maxY)
        return _Rect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    func unionNoEmpty(_ other: _Rect) -> _Rect {
        return other.isEmpty ? self : (isEmpty ? other : union(other))
    }
    var circleBounds: _Rect {
        let r = hypot(width, height) / 2
        return _Rect(x: midX - r, y: midY - r, width: r * 2, height: r * 2)
    }
}
extension _Rect: Hashable {
    var hashValue: Int {
        return Hash.uniformityHashValue(with: [origin.hashValue, size.hashValue])
    }
}
extension _Rect: Codable {
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let origin = try container.decode(_Point.self)
        let size = try container.decode(_Size.self)
        self.init(origin: origin, size: size)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(origin)
        try container.encode(size)
    }
}
extension _Rect: Referenceable {
    static let name = Localization(english: "Rect", japanese: "矩形")
}

typealias Rect = CGRect
extension Rect {
    func distance²(_ point: Point) -> CGFloat {
        return AABB(self).nearestDistance²(point)
    }
    func unionNoEmpty(_ other: Rect) -> Rect {
        return other.isEmpty ? self : (isEmpty ? other : union(other))
    }
    var circleBounds: Rect {
        let r = hypot(width, height) / 2
        return Rect(x: midX - r, y: midY - r, width: r * 2, height: r * 2)
    }
    func inset(by width: CGFloat) -> Rect {
        return insetBy(dx: width, dy: width)
    }
    var centerPoint: Point {
        return Point(x: midX, y: midY)
    }
}
func round(_ rect: Rect) -> Rect {
    let minX = round(rect.minX), maxX = round(rect.maxX)
    let minY = round(rect.minY), maxY = round(rect.maxY)
    return AABB(minX: minX, maxX: maxX, minY: minY, maxY: maxY).rect
}

struct AABB: Codable {
    var minX = 0.0.cg, maxX = 0.0.cg, minY = 0.0.cg, maxY = 0.0.cg
    init(minX: CGFloat = 0, maxX: CGFloat = 0, minY: CGFloat = 0, maxY: CGFloat = 0) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }
    init(_ rect: Rect) {
        minX = rect.minX
        minY = rect.minY
        maxX = rect.maxX
        maxY = rect.maxY
    }
    init(_ b: Bezier2) {
        minX = min(b.p0.x, b.cp.x, b.p1.x)
        minY = min(b.p0.y, b.cp.y, b.p1.y)
        maxX = max(b.p0.x, b.cp.x, b.p1.x)
        maxY = max(b.p0.y, b.cp.y, b.p1.y)
    }
    init(_ b: Bezier3) {
        minX = min(b.p0.x, b.cp0.x, b.cp1.x, b.p1.x)
        minY = min(b.p0.y, b.cp0.y, b.cp1.y, b.p1.y)
        maxX = max(b.p0.x, b.cp0.x, b.cp1.x, b.p1.x)
        maxY = max(b.p0.y, b.cp0.y, b.cp1.y, b.p1.y)
    }
    
    var width: CGFloat {
        return maxX - minX
    }
    var height: CGFloat {
        return maxY - minY
    }
    var position: Point {
        return Point(x: minX, y: minY)
    }
    var rect: Rect {
        return Rect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    func contains(_ point: Point) -> Bool {
        return (point.x >= minX && point.x <= maxX) && (point.y >= minY && point.y <= maxY)
    }
    func clippedPoint(with point: Point) -> Point {
        return Point(x: point.x.clip(min: minX, max: maxX),
                       y: point.y.clip(min: minY, max: maxY))
    }
    func nearestDistance²(_ p: Point) -> CGFloat {
        if p.x < minX {
            if p.y < minY {
                return hypot²(minX - p.x, minY - p.y)
            } else if p.y <= maxY {
                return (minX - p.x).²
            } else {
                return hypot²(minX - p.x, p.y - maxY)
            }
        } else if p.x <= maxX {
            if p.y < minY {
                return (minY - p.y).²
            } else if p.y <= maxY {
                return 0
            } else {
                return (p.y - maxY).²
            }
        } else {
            if p.y < minY {
                return hypot²(maxX - p.x, minY - p.y)
            } else if p.y <= maxY {
                return (maxX - p.x).²
            } else {
                return hypot²(p.x - maxX, p.y - maxY)
            }
        }
    }
    func intersects(_ other: AABB) -> Bool {
        return minX <= other.maxX && maxX >= other.minX
            && minY <= other.maxY && maxY >= other.minY
    }
}

struct RotatedRect: Codable, Equatable {
    var centerPoint: Point, size: Size, angle: CGFloat
    
    init(convexHullPoints chps: [Point]) {
        guard !chps.isEmpty else {
            fatalError()
        }
        guard chps.count > 1 else {
            self.centerPoint = chps[0]
            self.size = Size()
            self.angle = 0.0
            return
        }
        var minArea = CGFloat.infinity, minAngle = 0.0.cg, minBounds = Rect()
        for (i, p) in chps.enumerated() {
            let nextP = chps[i == chps.count - 1 ? 0 : i + 1]
            let angle = p.tangential(nextP)
            let affine = CGAffineTransform(rotationAngle: -angle)
            let ps = chps.map { $0.applying(affine) }
            let bounds = Point.boundingBox(with: ps)
            let area = bounds.width * bounds.height
            if area < minArea {
                minArea = area
                minAngle = angle
                minBounds = bounds
            }
        }
        centerPoint = Point(x: minBounds.midX,
                              y: minBounds.midY).applying(CGAffineTransform(rotationAngle: minAngle))
        size = minBounds.size
        angle = minAngle
    }
    
    var bounds: Rect {
        return Rect(x: 0, y: 0, width: size.width, height: size.height)
    }
    var affineTransform: CGAffineTransform {
        return CGAffineTransform(translationX: centerPoint.x, y: centerPoint.y)
            .rotated(by: angle)
            .translatedBy(x: -size.width / 2, y: -size.height / 2)
    }
    func convertToLocal(p: Point) -> Point {
        return p.applying(affineTransform.inverted())
    }
    var minXMidYPoint: Point {
        return Point(x: 0, y: size.height / 2).applying(affineTransform)
    }
    var maxXMidYPoint: Point {
        return Point(x: size.width, y: size.height / 2).applying(affineTransform)
    }
    var midXMinYPoint: Point {
        return Point(x: size.width / 2, y: 0).applying(affineTransform)
    }
    var midXMaxYPoint: Point {
        return Point(x: size.width / 2, y: size.height).applying(affineTransform)
    }
    var midXMidYPoint: Point {
        return Point(x: size.width / 2, y: size.height / 2).applying(affineTransform)
    }
}
extension Point {
    static func convexHullPoints(with points: [Point]) -> [Point] {
        guard points.count > 3 else {
            return points
        }
        let minY = (points.min { $0.y < $1.y })!.y
        let firstP = points.filter { $0.y == minY }.min { $0.x < $1.x }!
        var ap = firstP, chps = [Point]()
        repeat {
            chps.append(ap)
            var bp = points[0]
            for i in 1 ..< points.count {
                let cp = points[i]
                if bp == ap {
                    bp = cp
                } else {
                    let v = (bp - ap).crossVector(cp - ap)
                    if v > 0 || (v == 0 && ap.distance²(cp) > ap.distance²(bp)) {
                        bp = cp
                    }
                }
            }
            ap = bp
        } while ap != firstP
        return chps
    }
    static func boundingBox(with points: [Point]) -> Rect {
        guard points.count > 1 else {
            return Rect()
        }
        let minX = points.min { $0.x < $1.x }!.x, maxX = points.max { $0.x < $1.x }!.x
        let minY = points.min { $0.y < $1.y }!.y, maxY = points.max { $0.y < $1.y }!.y
        return AABB(minX: minX, maxX: maxX, minY: minY, maxY: maxY).rect
    }
}
