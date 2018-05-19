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

import Foundation

struct Transform: Codable, Initializable {//OrderedAfineTransform transformItems
    var translation: Point {
        didSet {
            affineTransform = Transform.affineTransform(translation: translation,
                                                        scale: scale, rotation: rotation)
        }
    }
    var scale: Point {
        get {
            return _scale
        }
        set {
            _scale = newValue
            _z = log2(newValue.x)
            affineTransform = Transform.affineTransform(translation: translation,
                                                        scale: scale, rotation: rotation)
        }
    }
    var z: Real {
        get {
            return _z
        }
        set {
            _z = newValue
            let pow2 = pow(2, z)
            _scale = Point(x: pow2, y: pow2)
            affineTransform = Transform.affineTransform(translation: translation,
                                                        scale: scale, rotation: rotation)
        }
    }
    private var _scale: Point, _z: Real
    var rotation: Real {
        didSet {
            affineTransform = Transform.affineTransform(translation: translation,
                                                        scale: scale, rotation: rotation)
        }
    }
    private(set) var affineTransform: CGAffineTransform
    
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
    
    private static func affineTransform(translation: Point,
                                        scale: Point, rotation: Real) -> CGAffineTransform {
        var affine = CGAffineTransform(translationX: translation.x, y: translation.y)
        if rotation != 0 {
            affine = affine.rotated(by: rotation)
        }
        if scale != Point() {
            affine = affine.scaledBy(x: scale.x, y: scale.y)
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
extension Transform: Referenceable {
    static let name = Text(english: "Transform", japanese: "トランスフォーム")
}
extension Transform: AbstractViewable {
    func abstractViewWith<T : BinderProtocol>(binder: T,
                                              keyPath: ReferenceWritableKeyPath<T, Transform>,
                                              frame: Rect, _ sizeType: SizeType,
                                              type: AbstractType) -> View {
        switch type {
        case .normal:
            return TransformView(binder: binder, keyPath: keyPath, option: TransformOption(),
                                 frame: frame, sizeType: sizeType)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath, frame: frame, sizeType)
        }
    }
}
extension Transform: KeyframeValue {}
extension Transform: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return View(isLocked: true)
    }
}

struct TransformTrack: Track, Codable {
    private(set) var animation = Animation<Transform>()
    var animatable: Animatable {
        return animation
    }
}
extension TransformTrack: Referenceable {
    static let name = Text(english: "Transform Track", japanese: "トランスフォームトラック")
}

struct TransformOption {
    var defaultModel = Transform()
    
    var standardTranslationValue = 1.0.cg {
        didSet {
            translationValueOption.transformedModel = { [standardTranslationValue] in
                $0 * standardTranslationValue
            }
            translationValueOption.reverseTransformedModel = { [standardTranslationValue] in
                $0 / standardTranslationValue
            }
        }
    }
    
    var translationValueOption = RealOption(defaultModel: 0, minModel: -1000000, maxModel: 1000000,
                                            modelInterval: 0.01, numberOfDigits: 2)
    var zOption = RealOption(defaultModel: 0, minModel: -20, maxModel: 20,
                             modelInterval: 0.01, numberOfDigits: 2)
    var rotationOption = RealOption(defaultModel: 0, minModel: -10000, maxModel: 10000,
                                    transformedModel: { $0 * .pi / 180 },
                                    reverseTransformedModel: { $0 * 180 / .pi },
                                    modelInterval: 0.5, numberOfDigits: 1)
    
    var translationOption: PointOption {
        return PointOption(xOption: translationValueOption, yOption: translationValueOption)
    }
}

final class TransformView<T: BinderProtocol>: View, BindableReceiver {
    typealias Model = Transform
    typealias ModelOption = TransformOption
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var option: ModelOption {
        didSet {
            translationView.option = option.translationOption
            zView.option = option.zOption
            rotationView.option = option.rotationOption
            updateLayout()
        }
    }
    
    let translationView: DiscretePointView<Binder>
    let zView: DiscreteRealView<Binder>
    let rotationView: DiscreteRealView<Binder>
    
    var sizeType: SizeType {
        didSet {
            translationView.sizeType = sizeType
            zView.sizeType = sizeType
            rotationView.sizeType = sizeType
            updateLayout()
        }
    }
    let classNameView = TextFormView(text: Transform.name, font: .bold)
    let classZNameView = TextFormView(text: "z:")
    let classRotationNameView = TextFormView(text: "θ:")
    
    init(binder: Binder, keyPath: BinderKeyPath, option: ModelOption,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        self.option = option
        
        translationView = DiscretePointView(binder: binder,
                                            keyPath: keyPath.appending(path: \Model.translation),
                                            option: option.translationOption,
                                            sizeType: sizeType)
        zView = DiscreteRealView(binder: binder, keyPath: keyPath.appending(path: \Model.z),
                                 option: option.zOption,
                                 frame: Layout.valueFrame(with: .regular), sizeType: sizeType)
        rotationView = DiscreteRealView(binder: binder,
                                        keyPath: keyPath.appending(path: \Model.rotation),
                                        option: option.rotationOption,
                                        frame: Layout.valueFrame(with: .regular), sizeType: sizeType)
        
        self.sizeType = sizeType
        
        super.init()
        children = [classNameView,
                    translationView,
                    classZNameView, zView,
                    classRotationNameView, rotationView]
        
        self.frame = frame
    }
    
    override var defaultBounds: Rect {
        let padding = Layout.basicPadding
        let w = Layout.propertyWidth + padding * 2
        let h = Layout.basicHeight * 2 + classNameView.frame.height + padding * 3
        return Rect(x: 0, y: 0, width: w, height: h)
    }
    override func updateLayout() {
        let padding = Layout.basicPadding
        var y = bounds.height - padding - classNameView.frame.height
        classNameView.frame.origin = Point(x: padding, y: y)
        y -= Layout.basicHeight + Layout.basicPadding
        _ = Layout.leftAlignment([.view(classZNameView), .view(zView), .xPadding(padding),
                                  .view(classRotationNameView), .view(rotationView)],
                                 y: y, height: Layout.basicHeight)
        let tdb = translationView.defaultBounds
        translationView.frame = Rect(x: bounds.width - Layout.basicPadding - tdb.width, y: padding,
                                     width: tdb.width, height: tdb.height)
    }
    func updateWithModel() {
        translationView.updateWithModel()
        zView.updateWithModel()
        rotationView.updateWithModel()
    }
}
extension TransformView: Localizable {
    func update(with locale: Locale) {
        updateLayout()
    }
}
extension TransformView: Queryable {
    static var referenceableType: Referenceable.Type {
        return Model.self
    }
}
extension TransformView: Assignable {
    func reset(for p: Point, _ version: Version) {
        push(option.defaultModel, to: version)
    }
    func copiedObjects(at p: Point) -> [Object] {
        return [Object(model)]
    }
    func paste(_ objects: [Any], for p: Point, _ version: Version) {
        for object in objects {
            if let model = object as? Transform {
                push(model, to: version)
                return
            }
        }
    }
}
