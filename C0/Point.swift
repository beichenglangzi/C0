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

/**
 Issue: Core Graphicsと置き換え
 */
struct _Point: Equatable {
    var x = 0.0.cg, y = 0.0.cg
    
    var isEmpty: Bool {
        return x == 0 && y == 0
    }
}
extension _Point: Hashable {
    var hashValue: Int {
        return Hash.uniformityHashValue(with: [x.hashValue, y.hashValue])
    }
}
extension _Point: Codable {
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let x = try container.decode(Real.self)
        let y = try container.decode(Real.self)
        self.init(x: x, y: y)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(x)
        try container.encode(y)
    }
}
extension _Point: Referenceable {
    static let name = Text(english: "Point", japanese: "ポイント")
}

typealias Point = CGPoint
extension Point {
    func mid(_ other: Point) -> Point {
        return Point(x: (x + other.x) / 2, y: (y + other.y) / 2)
    }
    
    static func intersection(p0: Point, p1: Point, q0: Point, q1: Point) -> Bool {
        let a0 = (p0.x - p1.x) * (q0.y - p0.y) + (p0.y - p1.y) * (p0.x - q0.x)
        let b0 = (p0.x - p1.x) * (q1.y - p0.y) + (p0.y - p1.y) * (p0.x - q1.x)
        if a0 * b0 < 0 {
            let a1 = (q0.x - q1.x) * (p0.y - q0.y) + (q0.y - q1.y) * (q0.x - p0.x)
            let b1 = (q0.x - q1.x) * (p1.y - q0.y) + (q0.y - q1.y) * (q0.x - p1.x)
            if a1 * b1 < 0 {
                return true
            }
        }
        return false
    }
    static func intersectionLineSegment(_ p1: Point, _ p2: Point,
                                        _ p3: Point, _ p4: Point,
                                        isSegmentP3P4: Bool = true) -> Point? {
        let delta = (p2.x - p1.x) * (p4.y - p3.y) - (p2.y - p1.y) * (p4.x - p3.x)
        if delta != 0 {
            let u = ((p3.x - p1.x) * (p4.y - p3.y) - (p3.y - p1.y) * (p4.x - p3.x)) / delta
            if u >= 0 && u <= 1 {
                let v = ((p3.x - p1.x) * (p2.y - p1.y) - (p3.y - p1.y) * (p2.x - p1.x)) / delta
                if v >= 0 && v <= 1 || !isSegmentP3P4 {
                    return Point(x: p1.x + u * (p2.x - p1.x), y: p1.y + u * (p2.y - p1.y))
                }
            }
        }
        return nil
    }
    static func intersectionLine(_ p1: Point, _ p2: Point,
                                 _ p3: Point, _ p4: Point) -> Point? {
        let d = (p2.x - p1.x) * (p4.y - p3.y) - (p2.y - p1.y) * (p4.x - p3.x)
        if d == 0 {
            return nil
        }
        let u = ((p3.x - p1.x) * (p4.y - p3.y) - (p3.y - p1.y) * (p4.x - p3.x)) / d
        return Point(x: p1.x + u * (p2.x - p1.x), y: p1.y + u * (p2.y - p1.y))
    }
    func isApproximatelyEqual(other: Point, roundingError: Real = 0.0000000001) -> Bool {
        return x.isApproximatelyEqual(other: other.x, roundingError: roundingError)
            && y.isApproximatelyEqual(other: other.y, roundingError: roundingError)
    }
    func tangential(_ other: Point) -> Real {
        return atan2(other.y - y, other.x - x)
    }
    func crossVector(_ other: Point) -> Real {
        return x * other.y - y * other.x
    }
    func distance(_ other: Point) -> Real {
        return hypot(other.x - x, other.y - y)
    }
    func distanceWithLine(ap: Point, bp: Point) -> Real {
        return ap == bp ? distance(ap) : abs((bp - ap).crossVector(self - ap)) / ap.distance(bp)
    }
    func normalLinearInequality(ap: Point, bp: Point) -> Bool {
        if bp.y - ap.y == 0 {
            return bp.x > ap.x ? x <= ap.x : x >= ap.x
        } else {
            let n = -(bp.x - ap.x) / (bp.y - ap.y)
            let ny = n * (x - ap.x) + ap.y
            return bp.y > ap.y ? y <= ny : y >= ny
        }
    }
    func tWithLineSegment(ap: Point, bp: Point) -> Real {
        if ap == bp {
            return 0.5
        } else {
            let bav = bp - ap, pav = self - ap
            return ((bav.x * pav.x + bav.y * pav.y) / (bav.x * bav.x + bav.y * bav.y))
                .clip(min: 0, max: 1)
        }
    }
    static func boundsPointWithLine(ap: Point, bp: Point,
                                    bounds: Rect) -> (p0: Point, p1: Point)? {
        let p0 = Point.intersectionLineSegment(Point(x: bounds.minX, y: bounds.minY),
                                               Point(x: bounds.minX, y: bounds.maxY),
                                               ap, bp, isSegmentP3P4: false)
        let p1 = Point.intersectionLineSegment(Point(x: bounds.maxX, y: bounds.minY),
                                               Point(x: bounds.maxX, y: bounds.maxY),
                                               ap, bp, isSegmentP3P4: false)
        let p2 = Point.intersectionLineSegment(Point(x: bounds.minX, y: bounds.minY),
                                               Point(x: bounds.maxX, y: bounds.minY),
                                               ap, bp, isSegmentP3P4: false)
        let p3 = Point.intersectionLineSegment(Point(x: bounds.minX, y: bounds.maxY),
                                               Point(x: bounds.maxX, y: bounds.maxY),
                                               ap, bp, isSegmentP3P4: false)
        if let p0 = p0 {
            if let p1 = p1, p0 != p1 {
                return (p0, p1)
            } else if let p2 = p2, p0 != p2 {
                return (p0, p2)
            } else if let p3 = p3, p0 != p3 {
                return (p0, p3)
            }
        } else if let p1 = p1 {
            if let p2 = p2, p1 != p2 {
                return (p1, p2)
            } else if let p3 = p3, p1 != p3 {
                return (p1, p3)
            }
        } else if let p2 = p2, let p3 = p3, p2 != p3 {
            return (p2, p3)
        }
        return nil
    }
    func distanceWithLineSegment(ap: Point, bp: Point) -> Real {
        if ap == bp {
            return distance(ap)
        } else {
            let bav = bp - ap, pav = self - ap
            let r = (bav.x * pav.x + bav.y * pav.y) / (bav.x * bav.x + bav.y * bav.y)
            if r <= 0 {
                return distance(ap)
            } else if r > 1 {
                return distance(bp)
            } else {
                return abs(bav.crossVector(pav)) / ap.distance(bp)
            }
        }
    }
    func nearestWithLine(ap: Point, bp: Point) -> Point {
        if ap == bp {
            return ap
        } else {
            let av = bp - ap, bv = self - ap
            let r = (av.x * bv.x + av.y * bv.y) / (av.x * av.x + av.y * av.y)
            return Point(x: ap.x + r * av.x, y: ap.y + r * av.y)
        }
    }
    var integral: Point {
        return Point(x: round(x), y: round(y))
    }
    func perpendicularDeltaPoint(withDistance distance: Real) -> Point {
        if self == Point() {
            return Point(x: distance, y: 0)
        } else {
            let r = distance / hypot(x, y)
            return Point(x: -r * y, y: r * x)
        }
    }
    func distance²(_ other: Point) -> Real {
        let nx = x - other.x, ny = y - other.y
        return nx * nx + ny * ny
    }
    static func differenceAngle(_ p0: Point, p1: Point, p2: Point) -> Real {
        let pa = p1 - p0
        let pb = p2 - pa
        let ab = hypot(pa.x, pa.y) * hypot(pb.x, pb.y)
        return ab == 0 ? 0 :
            (pa.x * pb.y - pa.y * pb.x > 0 ? 1 : -1) * acos((pa.x * pb.x + pa.y * pb.y) / ab)
    }
    static func differenceAngle(p0: Point, p1: Point, p2: Point) -> Real {
        return differenceAngle(a: p1 - p0, b: p2 - p1)
    }
    static func differenceAngle(a: Point, b: Point) -> Real {
        return atan2(a.x * b.y - a.y * b.x, a.x * b.x + a.y * b.y)
    }
    static func +(lhs: Point, rha: Point) -> Point {
        return Point(x: lhs.x + rha.x, y: lhs.y + rha.y)
    }
    static func +=(lhs: inout Point, rhs: Point) {
        lhs.x += rhs.x
        lhs.y += rhs.y
    }
    static func -=(lhs: inout Point, rhs: Point) {
        lhs.x -= rhs.x
        lhs.y -= rhs.y
    }
    static func -(lhs: Point, rhs: Point) -> Point {
        return Point(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    prefix static func -(p: Point) -> Point {
        return Point(x: -p.x, y: -p.y)
    }
    static func *(lhs: Real, rhs: Point) -> Point {
        return Point(x: rhs.x * lhs, y: rhs.y * lhs)
    }
    static func *(lhs: Point, rhs: Real) -> Point {
        return Point(x: lhs.x * rhs, y: lhs.y * rhs)
    }
    static func /(lhs: Point, rhs: Real) -> Point {
        return Point(x: lhs.x / rhs, y: lhs.y / rhs)
    }
    
    func draw(radius r: Real, lineWidth: Real = 1,
              inColor: Color = .knob, outColor: Color = .getSetBorder, in ctx: CGContext) {
        let rect = Rect(x: x - r, y: y - r, width: r * 2, height: r * 2)
        ctx.setFillColor(outColor.cg)
        ctx.fillEllipse(in: rect.insetBy(dx: -lineWidth, dy: -lineWidth))
        ctx.setFillColor(inColor.cg)
        ctx.fillEllipse(in: rect)
    }
}
extension Point: Hashable {
    public var hashValue: Int {
        return Hash.uniformityHashValue(with: [x.hashValue, y.hashValue])
    }
}
extension Point: Interpolatable {
    static func linear(_ f0: Point, _ f1: Point, t: Real) -> Point {
        return Point(x: Real.linear(f0.x, f1.x, t: t), y: Real.linear(f0.y, f1.y, t: t))
    }
    static func firstMonospline(_ f1: Point, _ f2: Point, _ f3: Point,
                                with ms: Monospline) -> Point {
        return Point(x: Real.firstMonospline(f1.x, f2.x, f3.x, with: ms),
                     y: Real.firstMonospline(f1.y, f2.y, f3.y, with: ms))
    }
    static func monospline(_ f0: Point, _ f1: Point, _ f2: Point, _ f3: Point,
                           with ms: Monospline) -> Point {
        return Point(x: Real.monospline(f0.x, f1.x, f2.x, f3.x, with: ms),
                     y: Real.monospline(f0.y, f1.y, f2.y, f3.y, with: ms))
    }
    static func lastMonospline(_ f0: Point, _ f1: Point, _ f2: Point,
                               with ms: Monospline) -> Point {
        return Point(x: Real.lastMonospline(f0.x, f1.x, f2.x, with: ms),
                     y: Real.lastMonospline(f0.y, f1.y, f2.y, with: ms))
    }
}
extension Point: Referenceable {
    static let name = Text(english: "Point", japanese: "ポイント")
}
extension Point: CompactViewable {
    func thumbnail(withBounds bounds: Rect, _ sizeType: SizeType) -> View {
        return (jsonString ?? "").view(withBounds: bounds, sizeType)
    }
}

extension Array where Element == Point {
    var convexHull: [Point] {
        let points = self
        guard points.count > 3 else {
            return points
        }
        let minY = (points.min { $0.y < $1.y })!.y
        let firstP = points.filter { $0.y == minY }.min { $0.x < $1.x }!
        var ap = firstP, chps = [Point]()
        repeat {
            chps.append(ap)
            var bp = points[0]
            for i in 1..<points.count {
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
}

extension Point: Object2D {
    typealias XModel = Real
    typealias YModel = Real
    
    init(xModel: XModel, yModel: YModel) {
        self.init(x: xModel, y: yModel)
    }
    
    var xModel: XModel {
        get { return x }
        set { x = newValue }
    }
    var yModel: YModel {
        get { return y }
        set { y = newValue }
    }
}

struct PointOption: Object2DOption {
    typealias Model = Point
    typealias XOption = RealOption
    typealias YOption = RealOption
    
    var xOption: XOption
    var yOption: YOption
    
    func model(with string: String) -> Model? {
        return Model(jsonString: string)
    }
}
typealias SlidablePointView<Binder: BinderProtocol> = Slidable2DView<PointOption, Binder>
typealias DiscretePointView<Binder: BinderProtocol> = Discrete2DView<PointOption, Binder>
