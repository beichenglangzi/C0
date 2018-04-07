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

struct Point {
    var x = 0.0, y = 0.0
    func with(x: Double) -> Point {
        return Point(x: x, y: y)
    }
    func with(y: Double) -> Point {
        return Point(x: x, y: y)
    }
    
    var isEmpty: Bool {
        return x == 0 && y == 0
    }
}
extension Point: Equatable {
    static func ==(lhs: Point, rhs: Point) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }
}
extension Point: Hashable {
    var hashValue: Int {
        return Hash.uniformityHashValue(with: [x.hashValue, y.hashValue])
    }
}
extension Point: Codable {
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let x = try container.decode(Double.self)
        let y = try container.decode(Double.self)
        self.init(x: x, y: y)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(x)
        try container.encode(y)
    }
}
extension Point: Referenceable {
    static let name = Localization(english: "Point", japanese: "ポイント")
}

extension CGPoint {
    func mid(_ other: CGPoint) -> CGPoint {
        return CGPoint(x: (x + other.x) / 2, y: (y + other.y) / 2)
    }
    
    static func intersection(p0: CGPoint, p1: CGPoint, q0: CGPoint, q1: CGPoint) -> Bool {
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
    static func intersectionLineSegment(_ p1: CGPoint, _ p2: CGPoint,
                                        _ p3: CGPoint, _ p4: CGPoint,
                                        isSegmentP3P4: Bool = true) -> CGPoint? {
        
        let delta = (p2.x - p1.x) * (p4.y - p3.y) - (p2.y - p1.y) * (p4.x - p3.x)
        if delta != 0 {
            let u = ((p3.x - p1.x) * (p4.y - p3.y) - (p3.y - p1.y) * (p4.x - p3.x)) / delta
            if u >= 0 && u <= 1 {
                let v = ((p3.x - p1.x) * (p2.y - p1.y) - (p3.y - p1.y) * (p2.x - p1.x)) / delta
                if v >= 0 && v <= 1 || !isSegmentP3P4 {
                    return CGPoint(x: p1.x + u * (p2.x - p1.x), y: p1.y + u * (p2.y - p1.y))
                }
            }
        }
        return nil
    }
    static func intersectionLine(_ p1: CGPoint, _ p2: CGPoint,
                                 _ p3: CGPoint, _ p4: CGPoint) -> CGPoint? {
        
        let d = (p2.x - p1.x) * (p4.y - p3.y) - (p2.y - p1.y) * (p4.x - p3.x)
        if d == 0 {
            return nil
        }
        let u = ((p3.x - p1.x) * (p4.y - p3.y) - (p3.y - p1.y) * (p4.x - p3.x)) / d
        return CGPoint(x: p1.x + u * (p2.x - p1.x), y: p1.y + u * (p2.y - p1.y))
    }
    func isApproximatelyEqual(other: CGPoint, roundingError: CGFloat = 0.0000000001.cf) -> Bool {
        return x.isApproximatelyEqual(other: other.x, roundingError: roundingError)
            && y.isApproximatelyEqual(other: other.y, roundingError: roundingError)
    }
    func tangential(_ other: CGPoint) -> CGFloat {
        return atan2(other.y - y, other.x - x)
    }
    func crossVector(_ other: CGPoint) -> CGFloat {
        return x * other.y - y * other.x
    }
    func distance(_ other: CGPoint) -> CGFloat {
        return hypot(other.x - x, other.y - y)
    }
    func distanceWithLine(ap: CGPoint, bp: CGPoint) -> CGFloat {
        return ap == bp ? distance(ap) : abs((bp - ap).crossVector(self - ap)) / ap.distance(bp)
    }
    func normalLinearInequality(ap: CGPoint, bp: CGPoint) -> Bool {
        if bp.y - ap.y == 0 {
            return bp.x > ap.x ? x <= ap.x : x >= ap.x
        } else {
            let n = -(bp.x - ap.x) / (bp.y - ap.y)
            let ny = n * (x - ap.x) + ap.y
            return bp.y > ap.y ? y <= ny : y >= ny
        }
    }
    func tWithLineSegment(ap: CGPoint, bp: CGPoint) -> CGFloat {
        if ap == bp {
            return 0.5
        } else {
            let bav = bp - ap, pav = self - ap
            return ((bav.x * pav.x + bav.y * pav.y) / (bav.x * bav.x + bav.y * bav.y))
                .clip(min: 0, max: 1)
        }
    }
    static func boundsPointWithLine(ap: CGPoint, bp: CGPoint,
                                    bounds: CGRect) -> (p0: CGPoint, p1: CGPoint)? {
        
        let p0 = CGPoint.intersectionLineSegment(CGPoint(x: bounds.minX, y: bounds.minY),
                                                 CGPoint(x: bounds.minX, y: bounds.maxY),
                                                 ap, bp, isSegmentP3P4: false)
        let p1 = CGPoint.intersectionLineSegment(CGPoint(x: bounds.maxX, y: bounds.minY),
                                                 CGPoint(x: bounds.maxX, y: bounds.maxY),
                                                 ap, bp, isSegmentP3P4: false)
        let p2 = CGPoint.intersectionLineSegment(CGPoint(x: bounds.minX, y: bounds.minY),
                                                 CGPoint(x: bounds.maxX, y: bounds.minY),
                                                 ap, bp, isSegmentP3P4: false)
        let p3 = CGPoint.intersectionLineSegment(CGPoint(x: bounds.minX, y: bounds.maxY),
                                                 CGPoint(x: bounds.maxX, y: bounds.maxY),
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
    func distanceWithLineSegment(ap: CGPoint, bp: CGPoint) -> CGFloat {
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
    func nearestWithLine(ap: CGPoint, bp: CGPoint) -> CGPoint {
        if ap == bp {
            return ap
        } else {
            let av = bp - ap, bv = self - ap
            let r = (av.x * bv.x + av.y * bv.y) / (av.x * av.x + av.y * av.y)
            return CGPoint(x: ap.x + r * av.x, y: ap.y + r * av.y)
        }
    }
    var integral: CGPoint {
        return CGPoint(x: round(x), y: round(y))
    }
    func perpendicularDeltaPoint(withDistance distance: CGFloat) -> CGPoint {
        if self == CGPoint() {
            return CGPoint(x: distance, y: 0)
        } else {
            let r = distance / hypot(x, y)
            return CGPoint(x: -r * y, y: r * x)
        }
    }
    func distance²(_ other: CGPoint) -> CGFloat {
        let nx = x - other.x, ny = y - other.y
        return nx * nx + ny * ny
    }
    static func differenceAngle(_ p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGFloat {
        let pa = p1 - p0
        let pb = p2 - pa
        let ab = hypot(pa.x, pa.y) * hypot(pb.x, pb.y)
        return ab == 0 ? 0 :
            (pa.x * pb.y - pa.y * pb.x > 0 ? 1 : -1) * acos((pa.x * pb.x + pa.y * pb.y) / ab)
    }
    static func differenceAngle(p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGFloat {
        return differenceAngle(a: p1 - p0, b: p2 - p1)
    }
    static func differenceAngle(a: CGPoint, b: CGPoint) -> CGFloat {
        return atan2(a.x * b.y - a.y * b.x, a.x * b.x + a.y * b.y)
    }
    static func +(lhs: CGPoint, rha: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rha.x, y: lhs.y + rha.y)
    }
    static func +=(lhs: inout CGPoint, rhs: CGPoint) {
        lhs.x += rhs.x
        lhs.y += rhs.y
    }
    static func -=(lhs: inout CGPoint, rhs: CGPoint) {
        lhs.x -= rhs.x
        lhs.y -= rhs.y
    }
    static func -(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    prefix static func -(p: CGPoint) -> CGPoint {
        return CGPoint(x: -p.x, y: -p.y)
    }
    static func *(lhs: CGFloat, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: rhs.x * lhs, y: rhs.y * lhs)
    }
    static func *(lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        return CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }
    static func /(lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        return CGPoint(x: lhs.x / rhs, y: lhs.y / rhs)
    }
    
    func draw(radius r: CGFloat, lineWidth: CGFloat = 1,
              inColor: Color = .knob, outColor: Color = .border, in ctx: CGContext) {
        
        let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
        ctx.setFillColor(outColor.cgColor)
        ctx.fillEllipse(in: rect.insetBy(dx: -lineWidth, dy: -lineWidth))
        ctx.setFillColor(inColor.cgColor)
        ctx.fillEllipse(in: rect)
    }
}
extension CGPoint: Hashable {
    public var hashValue: Int {
        return Hash.uniformityHashValue(with: [x.hashValue, y.hashValue])
    }
}
extension CGPoint: Interpolatable {
    static func linear(_ f0: CGPoint, _ f1: CGPoint, t: CGFloat) -> CGPoint {
        return CGPoint(x: CGFloat.linear(f0.x, f1.x, t: t), y: CGFloat.linear(f0.y, f1.y, t: t))
    }
    static func firstMonospline(_ f1: CGPoint, _ f2: CGPoint, _ f3: CGPoint,
                                with ms: Monospline) -> CGPoint {
        return CGPoint(x: CGFloat.firstMonospline(f1.x, f2.x, f3.x, with: ms),
                       y: CGFloat.firstMonospline(f1.y, f2.y, f3.y, with: ms))
    }
    static func monospline(_ f0: CGPoint, _ f1: CGPoint, _ f2: CGPoint, _ f3: CGPoint,
                           with ms: Monospline) -> CGPoint {
        return CGPoint(x: CGFloat.monospline(f0.x, f1.x, f2.x, f3.x, with: ms),
                       y: CGFloat.monospline(f0.y, f1.y, f2.y, f3.y, with: ms))
    }
    static func lastMonospline(_ f0: CGPoint, _ f1: CGPoint, _ f2: CGPoint,
                               with ms: Monospline) -> CGPoint {
        return CGPoint(x: CGFloat.lastMonospline(f0.x, f1.x, f2.x, with: ms),
                       y: CGFloat.lastMonospline(f0.y, f1.y, f2.y, with: ms))
    }
}
extension CGPoint: Referenceable {
    static let name = Localization(english: "Point", japanese: "ポイント")
}

final class PointView: View {
    static let name = CGPoint.name
    
    var backgroundLayers = [Layer]() {
        didSet {
            replace(children: backgroundLayers + [knob])
        }
    }
    
    let knob = Knob()
    init(frame: CGRect = CGRect()) {
        super.init()
        self.frame = frame
        append(child: knob)
    }
    
    override var bounds: CGRect {
        didSet {
            knob.position = position(from: point)
        }
    }
    
    var isOutOfBounds = false {
        didSet {
            if isOutOfBounds != oldValue {
                knob.fillColor = isOutOfBounds ? .warning : .knob
            }
        }
    }
    var padding = 5.0.cf
    
    var defaultPoint = CGPoint()
    var pointAABB = AABB(minX: 0, maxX: 1, minY: 0, maxY: 1) {
        didSet {
            guard pointAABB.maxX - pointAABB.minX > 0 && pointAABB.maxY - pointAABB.minY > 0 else {
                fatalError("Division by zero")
            }
        }
    }
    var point = CGPoint() {
        didSet {
            isOutOfBounds = !pointAABB.contains(point)
            if point != oldValue {
                knob.position = isOutOfBounds ?
                    position(from: clippedPoint(with: point)) : position(from: point)
            }
        }
    }
    
    func clippedPoint(with point: CGPoint) -> CGPoint {
        return pointAABB.clippedPoint(with: point)
    }
    func point(withPosition position: CGPoint) -> CGPoint {
        let inB = bounds.inset(by: padding)
        let x = pointAABB.width * (position.x - inB.origin.x) / inB.width + pointAABB.minX
        let y = pointAABB.height * (position.y - inB.origin.y) / inB.height + pointAABB.minY
        return CGPoint(x: x, y: y)
    }
    func position(from point: CGPoint) -> CGPoint {
        let inB = bounds.inset(by: padding)
        let x = inB.width * (point.x - pointAABB.minX) / pointAABB.width + inB.origin.x
        let y = inB.height * (point.y - pointAABB.minY) / pointAABB.height + inB.origin.y
        return CGPoint(x: x, y: y)
    }
    
    struct Binding {
        let view: PointView, point: CGPoint, oldPoint: CGPoint, type: Action.SendType
    }
    var binding: ((Binding) -> ())?
    
    var disabledRegisterUndo = false
    
    func copiedObjects(with event: KeyInputEvent) -> [Any]? {
        return [point]
    }
    func paste(_ objects: [Any], with event: KeyInputEvent) -> Bool {
        for object in objects {
            if let point = object as? CGPoint {
                guard point != self.point else {
                    continue
                }
                set(point, oldPoint: self.point)
                return true
            }
        }
        return false
    }
    func delete(with event: KeyInputEvent) -> Bool {
        let point = defaultPoint
        guard point != self.point else {
            return false
        }
        set(point, oldPoint: self.point)
        return true
    }
    
    func run(with event: ClickEvent) -> Bool {
        let p = self.point(from: event)
        let point = clippedPoint(with: self.point(withPosition: p))
        guard point != self.point else {
            return false
        }
        set(point, oldPoint: self.point)
        return true
    }
    
    private var oldPoint = CGPoint()
    func move(with event: DragEvent) -> Bool {
        let p = self.point(from: event)
        switch event.sendType {
        case .begin:
            knob.fillColor = .editing
            oldPoint = point
            binding?(Binding(view: self, point: point, oldPoint: oldPoint, type: .begin))
            point = clippedPoint(with: self.point(withPosition: p))
            binding?(Binding(view: self, point: point, oldPoint: oldPoint, type: .sending))
        case .sending:
            point = clippedPoint(with: self.point(withPosition: p))
            binding?(Binding(view: self, point: point, oldPoint: oldPoint, type: .sending))
        case .end:
            point = clippedPoint(with: self.point(withPosition: p))
            if point != oldPoint {
                registeringUndoManager?.registerUndo(withTarget: self) { [point, oldPoint] in
                    $0.set(oldPoint, oldPoint: point)
                }
            }
            binding?(Binding(view: self, point: point, oldPoint: oldPoint, type: .end))
            knob.fillColor = .knob
        }
        return true
    }
    
    func set(_ point: CGPoint, oldPoint: CGPoint) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldPoint, oldPoint: point) }
        binding?(Binding(view: self, point: point, oldPoint: oldPoint, type: .begin))
        self.point = point
        binding?(Binding(view: self, point: point, oldPoint: oldPoint, type: .end))
    }
}
