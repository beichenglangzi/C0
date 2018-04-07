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

struct Transform: Codable {
    var translation: CGPoint {
        didSet {
            affineTransform = Transform.affineTransform(translation: translation,
                                                        scale: scale, rotation: rotation)
        }
    }
    var scale: CGPoint {
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
    var z: CGFloat {
        get {
            return _z
        }
        set {
            _z = newValue
            let pow2 = pow(2, z)
            _scale = CGPoint(x: pow2, y: pow2)
            affineTransform = Transform.affineTransform(translation: translation,
                                                        scale: scale, rotation: rotation)
        }
    }
    var _scale: CGPoint, _z: CGFloat
    var rotation: CGFloat {
        didSet {
            affineTransform = Transform.affineTransform(translation: translation,
                                                        scale: scale, rotation: rotation)
        }
    }
    private(set) var affineTransform: CGAffineTransform
    
    init(translation: CGPoint = CGPoint(), z: CGFloat = 0, rotation: CGFloat = 0) {
        let pow2 = pow(2, z)
        self.translation = translation
        _scale = CGPoint(x: pow2, y: pow2)
        _z = z
        self.rotation = rotation
        affineTransform = Transform.affineTransform(translation: translation,
                                                    scale: _scale, rotation: rotation)
    }
    init(translation: CGPoint = CGPoint(), scale: CGPoint, rotation: CGFloat = 0) {
        self.translation = translation
        _z = log2(scale.x)
        _scale = scale
        self.rotation = rotation
        affineTransform = Transform.affineTransform(translation: translation,
                                                    scale: scale, rotation: rotation)
    }
    private init(translation: CGPoint, z: CGFloat, scale: CGPoint, rotation: CGFloat) {
        self.translation = translation
        _z = z
        _scale = scale
        self.rotation = rotation
        affineTransform = Transform.affineTransform(translation: translation,
                                                    scale: scale, rotation: rotation)
    }
    
    private static func affineTransform(translation: CGPoint,
                                        scale: CGPoint, rotation: CGFloat) -> CGAffineTransform {
        var affine = CGAffineTransform(translationX: translation.x, y: translation.y)
        if rotation != 0 {
            affine = affine.rotated(by: rotation)
        }
        if scale != CGPoint() {
            affine = affine.scaledBy(x: scale.x, y: scale.y)
        }
        return affine
    }
    
    func with(translation: CGPoint) -> Transform {
        return Transform(translation: translation, z: z, scale: scale, rotation: rotation)
    }
    func with(z: CGFloat) -> Transform {
        return Transform(translation: translation, z: z, rotation: rotation)
    }
    func with(scale: CGFloat) -> Transform {
        return Transform(translation: translation,
                         scale: CGPoint(x: scale, y: scale), rotation: rotation)
    }
    func with(scale: CGPoint) -> Transform {
        return Transform(translation: translation, scale: scale, rotation: rotation)
    }
    func with(rotation: CGFloat) -> Transform {
        return Transform(translation: translation, z: z, scale: scale, rotation: rotation)
    }
    
    var isIdentity: Bool {
        return translation == CGPoint() && scale == CGPoint(x: 1, y: 1) && rotation == 0
    }
}
extension Transform: Equatable {
    static func ==(lhs: Transform, rhs: Transform) -> Bool {
        return lhs.translation == rhs.translation
            && lhs.scale == rhs.scale && lhs.rotation == rhs.rotation
    }
}
extension Transform: Interpolatable {
    static func linear(_ f0: Transform, _ f1: Transform, t: CGFloat) -> Transform {
        let translation = CGPoint.linear(f0.translation, f1.translation, t: t)
        let scaleX = CGFloat.linear(f0.scale.x, f1.scale.x, t: t)
        let scaleY = CGFloat.linear(f0.scale.y, f1.scale.y, t: t)
        let rotation = CGFloat.linear(f0.rotation, f1.rotation, t: t)
        return Transform(translation: translation,
                         scale: CGPoint(x: scaleX, y: scaleY), rotation: rotation)
    }
    static func firstMonospline(_ f1: Transform, _ f2: Transform, _ f3: Transform,
                                with ms: Monospline) -> Transform {
        let translation = CGPoint.firstMonospline(f1.translation, f2.translation,
                                                  f3.translation, with: ms)
        let scaleX = CGFloat.firstMonospline(f1.scale.x, f2.scale.x, f3.scale.x, with: ms)
        let scaleY = CGFloat.firstMonospline(f1.scale.y, f2.scale.y, f3.scale.y, with: ms)
        let rotation = CGFloat.firstMonospline(f1.rotation, f2.rotation, f3.rotation, with: ms)
        return Transform(translation: translation,
                         scale: CGPoint(x: scaleX, y: scaleY), rotation: rotation)
    }
    static func monospline(_ f0: Transform, _ f1: Transform, _ f2: Transform, _ f3: Transform,
                           with ms: Monospline) -> Transform {
        let translation = CGPoint.monospline(f0.translation, f1.translation,
                                             f2.translation, f3.translation, with: ms)
        let scaleX = CGFloat.monospline(f0.scale.x, f1.scale.x,
                                        f2.scale.x, f3.scale.x, with: ms)
        let scaleY = CGFloat.monospline(f0.scale.y, f1.scale.y,
                                        f2.scale.y, f3.scale.y, with: ms)
        let rotation = CGFloat.monospline(f0.rotation, f1.rotation,
                                          f2.rotation, f3.rotation, with: ms)
        return Transform(translation: translation,
                         scale: CGPoint(x: scaleX, y: scaleY), rotation: rotation)
    }
    static func lastMonospline(_ f0: Transform, _ f1: Transform, _ f2: Transform,
                              with ms: Monospline) -> Transform {
        
        let translation = CGPoint.lastMonospline(f0.translation, f1.translation,
                                                f2.translation, with: ms)
        let scaleX = CGFloat.lastMonospline(f0.scale.x, f1.scale.x, f2.scale.x, with: ms)
        let scaleY = CGFloat.lastMonospline(f0.scale.y, f1.scale.y, f2.scale.y, with: ms)
        let rotation = CGFloat.lastMonospline(f0.rotation, f1.rotation, f2.rotation, with: ms)
        return Transform(translation: translation,
                         scale: CGPoint(x: scaleX, y: scaleY), rotation: rotation)
    }
}
extension Transform: Referenceable {
    static let name = Localization(english: "Transform", japanese: "トランスフォーム")
}

final class TransformView: View {
    var transform = Transform() {
        didSet {
            if transform != oldValue {
                updateWithTransform()
            }
        }
    }
    
    private let classNameLabel = Label(text: Transform.name, font: .bold)
    private let xLabel = Label(text: Localization("x:"))
    private let yLabel = Label(text: Localization("y:"))
    private let zLabel = Label(text: Localization("z:"))
    private let thetaLabel = Label(text: Localization("θ:"))
    private let xView = DiscreteNumberView(frame: Layout.valueFrame,
                                           min: -10000, max: 10000, numberInterval: 0.01)
    private let yView = DiscreteNumberView(frame: Layout.valueFrame,
                                           min: -10000, max: 10000, numberInterval: 0.01)
    private let zView = DiscreteNumberView(frame: Layout.valueFrame,
                                           min: -20, max: 20, numberInterval: 0.01)
    private let thetaView = DiscreteNumberView(frame: Layout.valueFrame,
                                               min: -10000, max: 10000, numberInterval: 0.5, unit: "°")
    
    override init() {
        super.init()
        replace(children: [classNameLabel, xLabel, xView, yLabel, yView, zLabel, zView,
                           thetaLabel, thetaView])
        
        xView.binding = { [unowned self] in self.setTransform(with: $0) }
        yView.binding = { [unowned self] in self.setTransform(with: $0) }
        zView.binding = { [unowned self] in self.setTransform(with: $0) }
        thetaView.binding = { [unowned self] in self.setTransform(with: $0) }
    }
    
    override var locale: Locale {
        didSet {
            updateLayout()
        }
    }
    
    var isHorizontal = false
    override var defaultBounds: CGRect {
        if isHorizontal {
            let children = [classNameLabel, Padding(),
                            xLabel, xView, Padding(), yLabel, yView, Padding(),
                            zLabel, zView, Padding(), thetaLabel, thetaView]
            return CGRect(x: 0,
                          y: 0,
                          width: Layout.leftAlignmentWidth(children) + Layout.basicPadding,
                          height: Layout.basicHeight)
        } else {
            let w = MaterialView.defaultWidth + Layout.basicPadding * 2
            let h = Layout.basicHeight * 2 + classNameLabel.frame.height + Layout.basicPadding * 3
            return CGRect(x: 0, y: 0, width: w, height: h)
        }
    }
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    func updateLayout() {
        if isHorizontal {
            let children = [classNameLabel, Padding(),
                            xLabel, xView, Padding(), yLabel, yView, Padding(),
                            zLabel, zView, Padding(), thetaLabel, thetaView]
            _ = Layout.leftAlignment(children, height: frame.height)
        } else {
            var y = bounds.height - Layout.basicPadding - classNameLabel.frame.height
            classNameLabel.frame.origin = CGPoint(x: Layout.basicPadding, y: y)
            y -= Layout.basicHeight + Layout.basicPadding
            _ = Layout.leftAlignment([xLabel, xView, Padding(), yLabel, yView],
                                     y: y, height: Layout.basicHeight)
            y -= Layout.basicHeight
            _ = Layout.leftAlignment([zLabel, zView, Padding(), thetaLabel, thetaView],
                                     y: y, height: Layout.basicHeight)
            if yView.frame.maxX < thetaView.frame.maxX {
                yView.frame.origin.x = thetaView.frame.minX
                yLabel.frame.origin.x = yView.frame.minX - yLabel.frame.width
            } else {
                thetaView.frame.origin.x = yView.frame.minX
                thetaLabel.frame.origin.x = thetaView.frame.minX - thetaLabel.frame.width
            }
        }
    }
    private func updateWithTransform() {
        xView.number = transform.translation.x / standardTranslation.x
        yView.number = transform.translation.y / standardTranslation.y
        zView.number = transform.z
        thetaView.number = transform.rotation * 180 / (.pi)
    }
    
    var standardTranslation = CGPoint(x: 1, y: 1)
    
    var isLocked = false {
        didSet {
            xView.isLocked = isLocked
            yView.isLocked = isLocked
            zView.isLocked = isLocked
            thetaView.isLocked = isLocked
        }
    }
    
    var disabledRegisterUndo = true
    
    struct Binding {
        let transformView: TransformView
        let transform: Transform, oldTransform: Transform, type: Action.SendType
    }
    var binding: ((Binding) -> ())?
    
    private var oldTransform = Transform()
    private func setTransform(with obj: DiscreteNumberView.Binding) {
        if obj.type == .begin {
            oldTransform = transform
            binding?(Binding(transformView: self,
                             transform: oldTransform, oldTransform: oldTransform, type: .begin))
        } else {
            switch obj.view {
            case xView:
                transform = transform.with(translation: CGPoint(x: obj.number * standardTranslation.x,
                                                                y: transform.translation.y))
            case yView:
                transform = transform.with(translation: CGPoint(x: transform.translation.x,
                                                                y: obj.number * standardTranslation.y))
            case zView:
                transform = transform.with(z: obj.number)
            case thetaView:
                transform = transform.with(rotation: obj.number * (.pi / 180))
            default:
                fatalError("No case")
            }
            binding?(Binding(transformView: self,
                             transform: transform, oldTransform: oldTransform, type: obj.type))
        }
    }
    
    func copiedObjects(with event: KeyInputEvent) -> [Any]? {
        return [transform]
    }
    func paste(_ objects: [Any], with event: KeyInputEvent) -> Bool {
        guard !isLocked else {
            return false
        }
        for object in objects {
            if let transform = object as? Transform {
                guard transform != self.transform else {
                    continue
                }
                set(transform, oldTransform: self.transform)
                return true
            }
        }
        return false
    }
    func delete(with event: KeyInputEvent) -> Bool {
        guard !isLocked else {
            return false
        }
        let transform = Transform()
        guard transform != self.transform else {
            return false
        }
        set(transform, oldTransform: self.transform)
        return true
    }
    
    private func set(_ transform: Transform, oldTransform: Transform) {
        registeringUndoManager?.registerUndo(withTarget: self) {
            $0.set(oldTransform, oldTransform: transform)
        }
        binding?(Binding(transformView: self,
                         transform: oldTransform, oldTransform: oldTransform, type: .begin))
        self.transform = transform
        binding?(Binding(transformView: self,
                         transform: transform, oldTransform: oldTransform, type: .end))
    }
}
