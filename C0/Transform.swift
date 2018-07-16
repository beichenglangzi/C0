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

typealias AffineTransform = CGAffineTransform

extension AffineTransform {
    init(translation: Point) {
        self.init(translationX: translation.x, y: translation.y)
    }
    mutating func translateBy(x: Real, y: Real) {
        self = translatedBy(x: x, y: y)
    }
    mutating func translate(by translation: Point) {
        self = translatedBy(x: translation.x, y: translation.y)
    }
    func translated(by translation: Point) -> AffineTransform {
        return translatedBy(x: translation.x, y: translation.y)
    }
    mutating func scale(by scale: Real) {
        self = scaledBy(x: scale, y: scale)
    }
    mutating func scaleBy(x: Real, y: Real) {
        self = scaledBy(x: x, y: y)
    }
    func scaled(by scale: Real) -> AffineTransform {
        return scaledBy(x: scale, y: scale)
    }
    mutating func scale(by scale: Point) {
        self = scaledBy(x: scale.x, y: scale.y)
    }
    func scaled(by scale: Point) -> AffineTransform {
        return scaledBy(x: scale.x, y: scale.y)
    }
    mutating func rotate(by rotation: Real) {
        self = rotated(by: rotation)
    }
    mutating func rotate(byDegrees rotation: Real) {
        self = rotated(by: rotation * .pi / 180)
    }
    func rotated(byDegrees rotation: Real) -> AffineTransform {
        return rotated(by: rotation * .pi / 180)
    }
    
    var xScale: Real {
        return sqrt(a * a + c * c)
    }
    var yScale: Real {
        return sqrt(b * b + d * d)
    }
    
    static func *(lhs: AffineTransform, rhs: AffineTransform) -> AffineTransform {
        return lhs.concatenating(rhs)
    }
    static func *=(lhs: inout AffineTransform, rhs: AffineTransform) {
        lhs = lhs.concatenating(rhs)
    }
}
extension AffineTransform {
    static func centering(from fromFrame: Rect,
                          to toFrame: Rect) -> (scale: Real, affine: AffineTransform) {
        guard !fromFrame.isEmpty && !toFrame.isEmpty else {
            return (1, AffineTransform.identity)
        }
        var affine = AffineTransform.identity
        let fromRatio = fromFrame.width / fromFrame.height
        let toRatio = toFrame.width / toFrame.height
        if fromRatio > toRatio {
            let xScale = toFrame.width / fromFrame.size.width
            let y = toFrame.origin.y + (toFrame.height - fromFrame.height * xScale) / 2
            affine.translateBy(x: toFrame.origin.x, y: y)
            affine.scale(by: xScale)
            affine.translate(by: -fromFrame.origin)
            return (xScale, affine)
        } else {
            let yScale = toFrame.height / fromFrame.size.height
            let x = toFrame.origin.x + (toFrame.width - fromFrame.width * yScale) / 2
            affine.translateBy(x: x, y: toFrame.origin.y)
            affine.scale(by: yScale)
            affine.translate(by: -fromFrame.origin)
            return (yScale, affine)
        }
    }
    func flippedHorizontal(by width: Real) -> AffineTransform {
        return translatedBy(x: width, y: 0).scaledBy(x: -1, y: 1)
    }
}

protocol AppliableAffineTransform {
    static func *(lhs: Self, rhs: AffineTransform) -> Self
}

struct Transform: Codable, Initializable {
    var translation: Point {
        didSet {
            affineTransform = Transform.affineTransform(translation: translation,
                                                        scale: scale, rotation: rotation)
        }
    }
    var scale: Point {
        get { return _scale }
        set {
            _scale = newValue
            _z = log2(newValue.x)
            affineTransform = Transform.affineTransform(translation: translation,
                                                        scale: scale, rotation: rotation)
        }
    }
    var z: Real {
        get { return _z }
        set {
            _z = newValue
            let pow2 = pow(2, z)
            _scale = Point(x: pow2, y: pow2)
            affineTransform = Transform.affineTransform(translation: translation,
                                                        scale: scale, rotation: rotation)
        }
    }
    static func scale(fromZ z: Real) -> Real {
        return pow(2, z)
    }
    private var _scale: Point, _z: Real
    var rotation: Real {
        didSet {
            affineTransform = Transform.affineTransform(translation: translation,
                                                        scale: scale, rotation: rotation)
        }
    }
    var degreesRotation: Real {
        get { return rotation * 180 / .pi }
        set { rotation = newValue * .pi / 180 }
    }
    private(set) var affineTransform: AffineTransform
    
    init() {
        translation = Point()
        _z = 0
        _scale = Point(x: 1, y: 1)
        rotation = 0
        affineTransform = Transform.affineTransform(translation: translation,
                                                    scale: _scale, rotation: rotation)
    }
    init(translation: Point = Point(), z: Real, rotation: Real = 0) {
        let pow2 = pow(2, z)
        self.translation = translation
        _scale = Point(x: pow2, y: pow2)
        _z = z
        self.rotation = rotation
        affineTransform = Transform.affineTransform(translation: translation,
                                                    scale: _scale, rotation: rotation)
    }
    init(translation: Point = Point(), scale: Point, rotation: Real = 0) {
        self.translation = translation
        _z = log2(scale.x)
        _scale = scale
        self.rotation = rotation
        affineTransform = Transform.affineTransform(translation: translation,
                                                    scale: scale, rotation: rotation)
    }
    private init(translation: Point, z: Real, scale: Point, rotation: Real) {
        self.translation = translation
        _z = z
        _scale = scale
        self.rotation = rotation
        affineTransform = Transform.affineTransform(translation: translation,
                                                    scale: scale, rotation: rotation)
    }
}
extension Transform {
    private static func affineTransform(translation: Point,
                                        scale: Point, rotation: Real) -> AffineTransform {
        var affine = AffineTransform(translation: translation)
        if rotation != 0 {
            affine.rotate(by: rotation)
        }
        if scale != Point() {
            affine.scale(by: scale)
        }
        return affine
    }
    
    var isIdentity: Bool {
        return translation == Point() && scale == Point(x: 1, y: 1) && rotation == 0
    }
}
extension Transform: Equatable {
    static func ==(lhs: Transform, rhs: Transform) -> Bool {
        return lhs.translation == rhs.translation
            && lhs.scale == rhs.scale && lhs.rotation == rhs.rotation
    }
}
extension Transform: Interpolatable {
    static func linear(_ f0: Transform, _ f1: Transform, t: Real) -> Transform {
        let translation = Point.linear(f0.translation, f1.translation, t: t)
        let scaleX = Real.linear(f0.scale.x, f1.scale.x, t: t)
        let scaleY = Real.linear(f0.scale.y, f1.scale.y, t: t)
        let rotation = Real.linear(f0.rotation, f1.rotation, t: t)
        return Transform(translation: translation,
                         scale: Point(x: scaleX, y: scaleY), rotation: rotation)
    }
    static func firstMonospline(_ f1: Transform, _ f2: Transform, _ f3: Transform,
                                with ms: Monospline) -> Transform {
        let translation = Point.firstMonospline(f1.translation, f2.translation,
                                                f3.translation, with: ms)
        let scaleX = Real.firstMonospline(f1.scale.x, f2.scale.x, f3.scale.x, with: ms)
        let scaleY = Real.firstMonospline(f1.scale.y, f2.scale.y, f3.scale.y, with: ms)
        let rotation = Real.firstMonospline(f1.rotation, f2.rotation, f3.rotation, with: ms)
        return Transform(translation: translation,
                         scale: Point(x: scaleX, y: scaleY), rotation: rotation)
    }
    static func monospline(_ f0: Transform, _ f1: Transform, _ f2: Transform, _ f3: Transform,
                           with ms: Monospline) -> Transform {
        let translation = Point.monospline(f0.translation, f1.translation,
                                           f2.translation, f3.translation, with: ms)
        let scaleX = Real.monospline(f0.scale.x, f1.scale.x, f2.scale.x, f3.scale.x, with: ms)
        let scaleY = Real.monospline(f0.scale.y, f1.scale.y, f2.scale.y, f3.scale.y, with: ms)
        let rotation = Real.monospline(f0.rotation, f1.rotation, f2.rotation, f3.rotation, with: ms)
        return Transform(translation: translation,
                         scale: Point(x: scaleX, y: scaleY), rotation: rotation)
    }
    static func lastMonospline(_ f0: Transform, _ f1: Transform, _ f2: Transform,
                               with ms: Monospline) -> Transform {
        let translation = Point.lastMonospline(f0.translation, f1.translation,
                                               f2.translation, with: ms)
        let scaleX = Real.lastMonospline(f0.scale.x, f1.scale.x, f2.scale.x, with: ms)
        let scaleY = Real.lastMonospline(f0.scale.y, f1.scale.y, f2.scale.y, with: ms)
        let rotation = Real.lastMonospline(f0.rotation, f1.rotation, f2.rotation, with: ms)
        return Transform(translation: translation,
                         scale: Point(x: scaleX, y: scaleY), rotation: rotation)
    }
}
extension Transform: Viewable {
    func viewWith<T: BinderProtocol>
        (binder: T, keyPath: ReferenceWritableKeyPath<T, Transform>) -> ModelView {
        
        return TransformView(binder: binder, keyPath: keyPath)
    }
}
extension Transform: ObjectViewable {}

protocol TransformProtocol {
    var transform: Transform { get set }
}
struct Transforming<Value: Object.Value & Viewable>: Codable, TransformProtocol {
    var value: Value
    var transform: Transform
    
    init(_ value: Value, transform: Transform = Transform()) {
        self.value = value
        self.transform = transform
    }
}

final class TransformView<T: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = Transform
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((TransformView<Binder>, BasicNotification) -> ())]()
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        super.init(isLocked: false)
    }
    
    func updateWithModel() {
        transform = model
    }
}
