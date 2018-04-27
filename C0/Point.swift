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
        let x = try container.decode(CGFloat.self)
        let y = try container.decode(CGFloat.self)
        self.init(x: x, y: y)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(x)
        try container.encode(y)
    }
}
extension _Point: Referenceable {
    static let name = Localization(english: "Point", japanese: "ポイント")
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
    func isApproximatelyEqual(other: Point, roundingError: CGFloat = 0.0000000001) -> Bool {
        return x.isApproximatelyEqual(other: other.x, roundingError: roundingError)
            && y.isApproximatelyEqual(other: other.y, roundingError: roundingError)
    }
    func tangential(_ other: Point) -> CGFloat {
        return atan2(other.y - y, other.x - x)
    }
    func crossVector(_ other: Point) -> CGFloat {
        return x * other.y - y * other.x
    }
    func distance(_ other: Point) -> CGFloat {
        return hypot(other.x - x, other.y - y)
    }
    func distanceWithLine(ap: Point, bp: Point) -> CGFloat {
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
    func tWithLineSegment(ap: Point, bp: Point) -> CGFloat {
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
    func distanceWithLineSegment(ap: Point, bp: Point) -> CGFloat {
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
    func perpendicularDeltaPoint(withDistance distance: CGFloat) -> Point {
        if self == Point() {
            return Point(x: distance, y: 0)
        } else {
            let r = distance / hypot(x, y)
            return Point(x: -r * y, y: r * x)
        }
    }
    func distance²(_ other: Point) -> CGFloat {
        let nx = x - other.x, ny = y - other.y
        return nx * nx + ny * ny
    }
    static func differenceAngle(_ p0: Point, p1: Point, p2: Point) -> CGFloat {
        let pa = p1 - p0
        let pb = p2 - pa
        let ab = hypot(pa.x, pa.y) * hypot(pb.x, pb.y)
        return ab == 0 ? 0 :
            (pa.x * pb.y - pa.y * pb.x > 0 ? 1 : -1) * acos((pa.x * pb.x + pa.y * pb.y) / ab)
    }
    static func differenceAngle(p0: Point, p1: Point, p2: Point) -> CGFloat {
        return differenceAngle(a: p1 - p0, b: p2 - p1)
    }
    static func differenceAngle(a: Point, b: Point) -> CGFloat {
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
    static func *(lhs: CGFloat, rhs: Point) -> Point {
        return Point(x: rhs.x * lhs, y: rhs.y * lhs)
    }
    static func *(lhs: Point, rhs: CGFloat) -> Point {
        return Point(x: lhs.x * rhs, y: lhs.y * rhs)
    }
    static func /(lhs: Point, rhs: CGFloat) -> Point {
        return Point(x: lhs.x / rhs, y: lhs.y / rhs)
    }
    
    init(_ string: String) {
        self = NSPointToCGPoint(NSPointFromString(string))
    }
    var string: String {
        return String(NSStringFromPoint(NSPointFromCGPoint(self)))
    }
    
    func draw(radius r: CGFloat, lineWidth: CGFloat = 1,
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
    static func linear(_ f0: Point, _ f1: Point, t: CGFloat) -> Point {
        return Point(x: CGFloat.linear(f0.x, f1.x, t: t), y: CGFloat.linear(f0.y, f1.y, t: t))
    }
    static func firstMonospline(_ f1: Point, _ f2: Point, _ f3: Point,
                                with ms: Monospline) -> Point {
        return Point(x: CGFloat.firstMonospline(f1.x, f2.x, f3.x, with: ms),
                       y: CGFloat.firstMonospline(f1.y, f2.y, f3.y, with: ms))
    }
    static func monospline(_ f0: Point, _ f1: Point, _ f2: Point, _ f3: Point,
                           with ms: Monospline) -> Point {
        return Point(x: CGFloat.monospline(f0.x, f1.x, f2.x, f3.x, with: ms),
                       y: CGFloat.monospline(f0.y, f1.y, f2.y, f3.y, with: ms))
    }
    static func lastMonospline(_ f0: Point, _ f1: Point, _ f2: Point,
                               with ms: Monospline) -> Point {
        return Point(x: CGFloat.lastMonospline(f0.x, f1.x, f2.x, with: ms),
                       y: CGFloat.lastMonospline(f0.y, f1.y, f2.y, with: ms))
    }
}
extension Point: Referenceable {
    static let name = Localization(english: "Point", japanese: "ポイント")
}
extension Point: DeepCopiable {
}
extension Point: ObjectViewExpression {
    func thumbnail(withBounds bounds: Rect, _ sizeType: SizeType) -> View {
        return string.view(withBounds: bounds, sizeType)
    }
}

final class PointView: View, Assignable, Movable, Runnable {
    var point = Point() {
        didSet {
            if point != oldValue {
                formKnobView.position = position(from: point)
            }
        }
    }
    var defaultPoint = Point()
    var pointAABB = AABB(minX: 0, maxX: 1, minY: 0, maxY: 1) {
        didSet {
            guard pointAABB.maxX - pointAABB.minX > 0 && pointAABB.maxY - pointAABB.minY > 0 else {
                fatalError("Division by zero")
            }
        }
    }
    
    var formBackgroundViews = [View]() {
        didSet {
            children = formBackgroundViews + [formKnobView]
        }
    }
    let formKnobView = KnobView()
    
    var padding = 5.0.cg
    
    init(frame: Rect = Rect()) {
        super.init()
        self.frame = frame
        append(child: formKnobView)
    }
    
    override var bounds: Rect {
        didSet {
            formKnobView.position = position(from: point)
        }
    }
    
    func clippedPoint(with point: Point) -> Point {
        return pointAABB.clippedPoint(with: point)
    }
    func point(withPosition position: Point) -> Point {
        let inB = bounds.inset(by: padding)
        let x = pointAABB.width * (position.x - inB.origin.x) / inB.width + pointAABB.minX
        let y = pointAABB.height * (position.y - inB.origin.y) / inB.height + pointAABB.minY
        return Point(x: x, y: y)
    }
    func position(from point: Point) -> Point {
        let inB = bounds.inset(by: padding)
        let x = inB.width * (point.x - pointAABB.minX) / pointAABB.width + inB.origin.x
        let y = inB.height * (point.y - pointAABB.minY) / pointAABB.height + inB.origin.y
        return Point(x: x, y: y)
    }
    
    struct Binding {
        let view: PointView, point: Point, oldPoint: Point, phase: Phase
    }
    var binding: ((Binding) -> ())?
    
    var disabledRegisterUndo = false
    
    func delete(for p: Point) {
        let point = defaultPoint
        if point != self.point {
            push(point, old: self.point)
        }
    }
    func copiedViewables(at p: Point) -> [Viewable] {
        return [point]
    }
    func paste(_ objects: [Any], for p: Point) {
        for object in objects {
            if let unclippedPoint = object as? Point {
                let point = clippedPoint(with: unclippedPoint)
                if point != self.point {
                    push(point, old: self.point)
                    return
                }
            } else if let string = object as? String {
                let point = clippedPoint(with: Point(string))
                if point != self.point {
                    push(point, old: self.point)
                    return
                }
            }
        }
    }
    
    func run(for p: Point) {
        let point = clippedPoint(with: self.point(withPosition: p))
        if point != self.point {
            push(point, old: self.point)
        }
    }
    
    private var oldPoint = Point()
    func move(for p: Point, pressure: CGFloat, time: Second, _ phase: Phase) {
        switch phase {
        case .began:
            formKnobView.fillColor = .editing
            oldPoint = point
            binding?(Binding(view: self, point: point, oldPoint: oldPoint, phase: .began))
            point = clippedPoint(with: self.point(withPosition: p))
            binding?(Binding(view: self, point: point, oldPoint: oldPoint, phase: .changed))
        case .changed:
            point = clippedPoint(with: self.point(withPosition: p))
            binding?(Binding(view: self, point: point, oldPoint: oldPoint, phase: .changed))
        case .ended:
            point = clippedPoint(with: self.point(withPosition: p))
            if point != oldPoint {
                registeringUndoManager?.registerUndo(withTarget: self) { [point, oldPoint] in
                    $0.push(oldPoint, old: point)
                }
            }
            binding?(Binding(view: self, point: point, oldPoint: oldPoint, phase: .ended))
            formKnobView.fillColor = .knob
        }
    }
    
    func push(_ point: Point, old oldPoint: Point) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.push(oldPoint, old: point) }
        binding?(Binding(view: self, point: point, oldPoint: oldPoint, phase: .began))
        self.point = point
        binding?(Binding(view: self, point: point, oldPoint: oldPoint, phase: .ended))
    }
    
    func reference(at p: Point) -> Reference {
        return _Point.reference
    }
}

final class DiscretePointView: View, Assignable {
    var point = Point() {
        didSet {
            if point != oldValue {
                xView.model = point.x
                yView.model = point.y
            }
        }
    }
    var defaultPoint = Point()
    
    var sizeType: SizeType
    let classXNameView: TextView
    let xView: DiscreteRealNumberView
    let classYNameView: TextView
    let yView: DiscreteRealNumberView
    init(point: Point = Point(), defaultPoint: Point = Point(),
         minPoint: Point = Point(x: -10000, y: -10000),
         maxPoint: Point = Point(x: 10000, y: 10000),
         xEXP: RealNumber = 1, yEXP: RealNumber = 1,
         xInterval: RealNumber = 1, xNumberOfDigits: Int = 0, xUnit: String = "",
         yInterval: RealNumber = 1, yNumberOfDigits: Int = 0, yUnit: String = "",
         frame: Rect = Rect(),
         sizeType: SizeType = .regular) {
        self.sizeType = sizeType
        
        classXNameView = TextView(text: Localization("x:"), font: Font.default(with: sizeType))
        xView = DiscreteRealNumberView(model: point.x,
                                       option: RealNumberOption(defaultModel: defaultPoint.x,
                                                                minModel: minPoint.x,
                                                                maxModel: maxPoint.x,
                                                                modelInterval: xInterval,
                                                                exp: xEXP,
                                                                numberOfDigits: xNumberOfDigits,
                                                                unit: xUnit),
                                       frame: Layout.valueFrame(with: sizeType),
                                       sizeType: sizeType)
        classYNameView = TextView(text: Localization("y:"), font: Font.default(with: sizeType))
        yView = DiscreteRealNumberView(model: point.y,
                                       option: RealNumberOption(defaultModel: defaultPoint.y,
                                                                minModel: minPoint.y,
                                                                maxModel: maxPoint.y,
                                                                modelInterval: yInterval,
                                                                exp: yEXP,
                                                                numberOfDigits: yNumberOfDigits,
                                                                unit: yUnit),
                                       frame: Layout.valueFrame(with: sizeType),
                                       sizeType: sizeType)
        
        super.init()
        children = [classXNameView, xView, classYNameView, yView]
        xView.binding = { [unowned self] in self.setPoint(with: $0) }
        yView.binding = { [unowned self] in self.setPoint(with: $0) }
        updateLayout()
    }
    
    override var defaultBounds: Rect {
        let padding = Layout.padding(with: sizeType)
        let valueFrame = Layout.valueFrame(with: sizeType)
        let xWidth = classXNameView.frame.width + valueFrame.width
        let yWidth = classYNameView.frame.height + valueFrame.width
        return Rect(x: 0,
                      y: 0,
                      width: max(xWidth, yWidth) + padding * 2,
                      height: valueFrame.height * 2 + padding * 2)
    }
    override var bounds: Rect {
        didSet {
            updateLayout()
        }
    }
    func updateLayout() {
        let padding = Layout.padding(with: sizeType)
        let valueFrame = Layout.valueFrame(with: sizeType)
        var x = bounds.width - padding, y = bounds.height - padding
        x -= valueFrame.width
        y -= valueFrame.height
        xView.frame.origin = Point(x: x, y: y)
        x -= classXNameView.frame.width
        classXNameView.frame.origin = Point(x: x, y: y + padding)
        y -= valueFrame.height
        yView.frame.origin = Point(x: x, y: y)
        x -= classYNameView.frame.width
        classYNameView.frame.origin = Point(x: x, y: y + padding)
    }
    
    struct Binding {
        let view: DiscretePointView
        let point: Point, oldPoint: Point, phase: Phase
    }
    var binding: ((Binding) -> ())?
    
    var disabledRegisterUndo = false
    
    private var oldPoint = Point()
    private func setPoint(with obj: DiscreteRealNumberView.Binding<RealNumber>) {
        if obj.phase == .began {
            oldPoint = point
            binding?(Binding(view: self, point: oldPoint, oldPoint: oldPoint, phase: .began))
        } else {
            if obj.view == xView {
                point.x = obj.model
            } else {
                point.y = obj.model
            }
            binding?(Binding(view: self, point: point, oldPoint: oldPoint, phase: obj.phase))
        }
    }
    
    func delete(for p: Point) {
        let point = defaultPoint
        if point != self.point {
            push(point, old: self.point)
        }
    }
    func copiedViewables(at p: Point) -> [Viewable] {
        return [point]
    }
    func paste(_ objects: [Any], for p: Point) {
        for object in objects {
            if let point = object as? Point {
                if point != self.point {
                    push(point, old: self.point)
                    return
                }
            } else if let string = object as? String {
                let point = Point(string)
                if point != self.point {
                    push(point, old: self.point)
                    return
                }
            }
        }
    }
    
    func push(_ point: Point, old oldPoint: Point) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.push(oldPoint, old: point) }
        binding?(Binding(view: self, point: point, oldPoint: oldPoint, phase: .began))
        self.point = point
        binding?(Binding(view: self, point: point, oldPoint: oldPoint, phase: .ended))
    }
    
    func reference(at p: Point) -> Reference {
        return _Point.reference
    }
}
