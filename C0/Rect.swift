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

typealias Rect = CGRect
extension Rect {
    func distance²(_ point: Point) -> Real {
        return AABB(self).nearestDistance²(point)
    }
    var circleBounds: Rect {
        let r = hypot(width, height) / 2
        return Rect(x: midX - r, y: midY - r, width: r * 2, height: r * 2)
    }
    func inset(by width: Real) -> Rect {
        return insetBy(dx: width, dy: width)
    }
    mutating func formUnion(_ other: Rect) {
        self = union(other)
    }
    
    var minXminYPoint: Point {
        return Point(x: minX, y: minY)
    }
    var midXminYPoint: Point {
        return Point(x: midX, y: minY)
    }
    var maxXminYPoint: Point {
        return Point(x: maxX, y: minY)
    }
    var minXmidYPoint: Point {
        return Point(x: minX, y: midY)
    }
    var centerPoint: Point {
        return Point(x: midX, y: midY)
    }
    var maxXmidYPoint: Point {
        return Point(x: maxX, y: midY)
    }
    var minXmaxYPoint: Point {
        return Point(x: minX, y: maxY)
    }
    var midXmaxYPoint: Point {
        return Point(x: midX, y: maxY)
    }
    var maxXmaxYPoint: Point {
        return Point(x: maxX, y: maxY)
    }
    
    static func boundingBox(with points: [Point]) -> Rect {
        guard !points.isEmpty else {
            return Rect.null
        }
        guard points.count > 1 else {
            return Rect(origin: points[0], size: Size())
        }
        let minX = points.min { $0.x < $1.x }!.x, maxX = points.max { $0.x < $1.x }!.x
        let minY = points.min { $0.y < $1.y }!.y, maxY = points.max { $0.y < $1.y }!.y
        return AABB(minX: minX, maxX: maxX, minY: minY, maxY: maxY).rect
    }
}
extension Rect: AppliableAffineTransform {
    static func *(lhs: Rect, rhs: AffineTransform) -> Rect {
        return lhs.applying(rhs)
    }
}

extension Rect: Viewable {
    func viewWith<T: BinderProtocol>
        (binder: T, keyPath: ReferenceWritableKeyPath<T, Rect>) -> ModelView {
        
        return RectView(binder: binder, keyPath: keyPath)
    }
}
extension Rect: ObjectViewable {}
extension Array where Element == Rect {
    static func checkerboard(with size: Size, in frame: Rect) -> [Rect] {
        let xCount = Int(frame.width / size.width)
        let yCount = Int(frame.height / (size.height * 2))
        var rects = [Rect]()
        
        for xi in 0..<xCount {
            let x = frame.minX + Real(xi) * size.width
            let fy = xi % 2 == 0 ? size.height : 0
            for yi in 0..<yCount {
                let y = frame.minY + Real(yi) * size.height * 2 + fy
                rects.append(Rect(x: x, y: y, width: size.width, height: size.height))
            }
        }
        return rects
    }
}
func round(_ rect: Rect) -> Rect {
    let minX = round(rect.minX), maxX = round(rect.maxX)
    let minY = round(rect.minY), maxY = round(rect.maxY)
    return AABB(minX: minX, maxX: maxX, minY: minY, maxY: maxY).rect
}

struct AABB: Codable {
    var minX = 0.0.cg, maxX = 0.0.cg, minY = 0.0.cg, maxY = 0.0.cg
    init(minX: Real = 0, maxX: Real = 0, minY: Real = 0, maxY: Real = 0) {
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
    
    var width: Real {
        return maxX - minX
    }
    var height: Real {
        return maxY - minY
    }
    var midX: Real {
        return (minX + maxX) / 2
    }
    var midY: Real {
        return (minY + maxY) / 2
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
    func nearestDistance²(_ p: Point) -> Real {
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
    var centerPoint: Point, size: Size, angle: Real
    
    init(convexHullPoints chps: [Point]) {
        guard !chps.isEmpty else { fatalError() }
        guard chps.count > 1 else {
            self.centerPoint = chps[0]
            self.size = Size()
            self.angle = 0.0
            return
        }
        var minArea = Real.infinity, minAngle = 0.0.cg, minBounds = Rect.null
        for (i, p) in chps.enumerated() {
            let nextP = chps[i == chps.count - 1 ? 0 : i + 1]
            let angle = p.tangential(nextP)
            let affine = AffineTransform(rotationAngle: -angle)
            let ps = chps.map { $0 * affine }
            let bounds = Rect.boundingBox(with: ps)
            let area = bounds.width * bounds.height
            if area < minArea {
                minArea = area
                minAngle = angle
                minBounds = bounds
            }
        }
        centerPoint = minBounds.centerPoint * AffineTransform(rotationAngle: minAngle)
        size = minBounds.size
        angle = minAngle
    }
    
    var bounds: Rect {
        return Rect(x: 0, y: 0, width: size.width, height: size.height)
    }
    var affineTransform: AffineTransform {
        return AffineTransform(translation: centerPoint)
            .rotated(by: angle)
            .translated(by: Point(x: -size.width / 2, y: -size.height / 2))
    }
    func convertToLocal(p: Point) -> Point {
        return p * affineTransform.inverted()
    }
    var minXMidYPoint: Point {
        return Point(x: 0, y: size.height / 2) * affineTransform
    }
    var maxXMidYPoint: Point {
        return Point(x: size.width, y: size.height / 2) * affineTransform
    }
    var midXMinYPoint: Point {
        return Point(x: size.width / 2, y: 0) * affineTransform
    }
    var midXMaxYPoint: Point {
        return Point(x: size.width / 2, y: size.height) * affineTransform
    }
    var midXMidYPoint: Point {
        return Point(x: size.width / 2, y: size.height / 2) * affineTransform
    }
}

final class RectView<T: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = Rect
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((RectView<Binder>, BasicNotification) -> ())]()
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        super.init(isLocked: false)
        lineWidth = 1
        lineColor = .content
        updateWithModel()
    }
    
    func updateWithModel() {
        frame = model.inset(by: -lineWidth)
    }
    
    override func containsPath(_ p: Point) -> Bool {
        return false
    }
    
    var oldFrame = Rect()
    func captureWillMoveObject(at p: Point, to version: Version) {
        oldFrame = frame
    }
    func transform(with affineTransform: AffineTransform) {
        model = oldFrame.applying(affineTransform)
    }
    func anchorPoint(from p: Point) -> Point {
        let frame = transformedBoundingBox
        var minD = p.distance²(frame.minXminYPoint), anchorPoint = frame.maxXmaxYPoint
        var d = p.distance²(frame.midXminYPoint)
        if d < minD {
            anchorPoint = frame.midXmaxYPoint
            minD = d
        }
        d = p.distance²(frame.maxXminYPoint)
        if d < minD {
            anchorPoint = frame.minXmaxYPoint
            minD = d
        }
        d = p.distance²(frame.minXmidYPoint)
        if d < minD {
            anchorPoint = frame.maxXmidYPoint
            minD = d
        }
        d = p.distance²(frame.maxXmidYPoint)
        if d < minD {
            anchorPoint = frame.minXmidYPoint
            minD = d
        }
        d = p.distance²(frame.minXmaxYPoint)
        if d < minD {
            anchorPoint = frame.maxXminYPoint
            minD = d
        }
        d = p.distance²(frame.midXmaxYPoint)
        if d < minD {
            anchorPoint = frame.midXminYPoint
            minD = d
        }
        d = p.distance²(frame.maxXmaxYPoint)
        if d < minD {
            anchorPoint = frame.minXminYPoint
            minD = d
        }
        return anchorPoint
    }
}
