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

enum BlendType: Int8, Codable, Equatable, Hashable {
    case normal, add, subtract
    
    var blendMode: CGBlendMode {
        switch self {
        case .normal:
            return .normal
        case .add:
            return .plusLighter
        case .subtract:
            return .plusDarker
        }
    }
    var displayText: Localization {
        switch self {
        case .normal:
            return Localization(english: "Normal", japanese: "通常")
        case .add:
            return Localization(english: "Add", japanese: "加算")
        case .subtract:
            return Localization(english: "Subtract", japanese: "減算")
        }
    }
    static var displayTexts: [Localization] {
        return [normal.displayText,
                add.displayText,
                subtract.displayText]
    }
}
extension BlendType: Referenceable {
    static let name = Localization(english: "Blend Type", japanese: "ブレンドタイプ")
}
extension BlendType: ObjectViewExpressionWithDisplayText {
}

struct Effect: Codable, Equatable, Hashable {
    var blendType = BlendType.normal, blurRadius = 0.0.cf, opacity = 1.0.cf
    
    func with(_ blendType: BlendType) -> Effect {
        return Effect(blendType: blendType, blurRadius: blurRadius, opacity: opacity)
    }
    func with(blur: CGFloat) -> Effect {
        return Effect(blendType: blendType, blurRadius: blur, opacity: opacity)
    }
    func with(opacity: CGFloat) -> Effect {
        return Effect(blendType: blendType, blurRadius: blurRadius, opacity: opacity)
    }
    
    var isEmpty: Bool {
        return self == Effect()
    }
    
    static func displayText(with keyPath: PartialKeyPath<Effect>) -> Localization {
        switch keyPath {
        case \Effect.blendType:
            return Localization(english: "Blend Type", japanese: "ブレンドタイプ")
        case \Effect.blurRadius:
            return Localization(english: "Blur Radius", japanese: "ブラー半径")
        case \Effect.opacity:
            return Localization(english: "Opacity", japanese: "不透明度")
        default:
            fatalError("No case")
        }
    }
}
extension Effect: Referenceable {
    static let name = Localization(english: "Effect", japanese: "エフェクト")
}
extension Effect: Interpolatable {
    static func linear(_ f0: Effect, _ f1: Effect, t: CGFloat) -> Effect {
        let blur = CGFloat.linear(f0.blurRadius, f1.blurRadius, t: t)
        let opacity = CGFloat.linear(f0.opacity, f1.opacity, t: t)
        let blendType = f0.blendType
        return Effect(blendType: blendType, blurRadius: blur, opacity: opacity)
    }
    static func firstMonospline(_ f1: Effect, _ f2: Effect, _ f3: Effect,
                                with ms: Monospline) -> Effect {
        let blur = CGFloat.firstMonospline(f1.blurRadius, f2.blurRadius, f3.blurRadius, with: ms)
        let opacity = CGFloat.firstMonospline(f1.opacity, f2.opacity, f3.opacity, with: ms)
        let blendType = f1.blendType
        return Effect(blendType: blendType, blurRadius: blur, opacity: opacity)
    }
    static func monospline(_ f0: Effect, _ f1: Effect, _ f2: Effect, _ f3: Effect,
                           with ms: Monospline) -> Effect {
        let blur = CGFloat.monospline(f0.blurRadius, f1.blurRadius,
                                      f2.blurRadius, f3.blurRadius, with: ms)
        let opacity = CGFloat.monospline(f0.opacity, f1.opacity,
                                         f2.opacity, f3.opacity, with: ms)
        let blendType = f1.blendType
        return Effect(blendType: blendType, blurRadius: blur, opacity: opacity)
    }
    static func lastMonospline(_ f0: Effect, _ f1: Effect, _ f2: Effect,
                               with ms: Monospline) -> Effect {
        let blur = CGFloat.lastMonospline(f0.blurRadius, f1.blurRadius, f2.blurRadius, with: ms)
        let opacity = CGFloat.lastMonospline(f0.opacity, f1.opacity, f2.opacity, with: ms)
        let blendType = f1.blendType
        return Effect(blendType: blendType, blurRadius: blur, opacity: opacity)
    }
}
extension Effect: ObjectViewExpression {
    func thumbnail(withBounds bounds: CGRect, sizeType: SizeType) -> Layer {
        return blendType.displayText.thumbnail(withBounds: bounds, sizeType: sizeType)
    }
}

final class EffectView: View {
    var effect: Effect {
        didSet {
            if effect != oldValue {
                updateWithEffect()
            }
        }
    }
    var defaultEffect = Effect()
    
    static let defaultWidth = 140.0.cf
    
    var sizeType: SizeType
    private let classNameView: TextView
    private let blendTypeView: EnumView<BlendType>
    private let classBlurNameView: TextView
    private let blurView: SlidableNumberView
    private let opacityView: SlidableNumberView
    
    init(sizeType: SizeType = .regular) {
        self.sizeType = sizeType
        classNameView = TextView(text: Effect.name, font: Font.bold(with: sizeType))
        let blurPropertyText = Effect.displayText(with: \Effect.blurRadius) + Localization(":")
        classBlurNameView = TextView(text: blurPropertyText, font: Font.default(with: sizeType))
        blurView = SlidableNumberView.widthViewWith(min: 0, max: 500, exp: 3, sizeType: sizeType)
        opacityView = SlidableNumberView.opacityView(sizeType: sizeType)
        blendTypeView = EnumView(enumeratedType: .normal,
                                 indexClosure: { Int($0) },
                                 rawValueClosure: { BlendType.RawValue($0) },
                                 names: BlendType.displayTexts, sizeType: sizeType)
        effect = defaultEffect
        super.init()
        replace(children: [classNameView,
                           blendTypeView,
                           classBlurNameView, blurView,
                           opacityView])
        
        blurView.binding = { [unowned self] in self.setEffect(with: $0) }
        opacityView.binding = { [unowned self] in self.setEffect(with: $0) }
        blendTypeView.binding = { [unowned self] in self.setEffect(with: $0) }
    }
    
    override var locale: Locale {
        didSet {
            updateLayout()
        }
    }
    
    override var defaultBounds: CGRect {
        let padding = Layout.padding(with: sizeType), height = Layout.height(with: sizeType)
        let viewHeight = height * 2 + padding * 2
        return CGRect(x: 0, y: 0, width: EffectView.defaultWidth, height: viewHeight)
    }
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    func updateLayout() {
        let padding = Layout.padding(with: sizeType), h = Layout.height(with: sizeType)
        let cw = bounds.width - padding * 2
        let rw = cw - classNameView.frame.width - padding
        let px = bounds.width - rw - padding
        classNameView.frame.origin = CGPoint(x: padding,
                                             y: bounds.height - classNameView.frame.height - padding)
        blendTypeView.frame = CGRect(x: px, y: padding + h, width: rw, height: h)
        classBlurNameView.frame.origin = CGPoint(x: padding,
                                                 y: padding * 2)
        let blurW = ceil((cw - classBlurNameView.frame.width) / 2)
        blurView.updateLineWidthLayers(withFrame: CGRect(x: classBlurNameView.frame.maxX, y: padding,
                                                         width: blurW, height: h))
        opacityView.updateOpacityLayers(withFrame: CGRect(x: blurView.frame.maxX,
                                                          y: padding,
                                                          width: bounds.width - blurView.frame.maxX - padding,
                                                          height: h))
    }
    private func updateWithEffect() {
        blurView.number = effect.blurRadius
        opacityView.number = effect.opacity
        blendTypeView.enumeratedType = effect.blendType
    }
    
    var disabledRegisterUndo = true
    
    struct Binding {
        let view: EffectView
        let effect: Effect, oldEffect: Effect, type: Action.SendType
    }
    var binding: ((Binding) -> ())?
    
    private var oldEffect = Effect()
    private func setEffect(with obj: EnumView<BlendType>.Binding) {
        if obj.type == .begin {
            oldEffect = effect
            binding?(Binding(view: self, effect: oldEffect, oldEffect: oldEffect, type: .begin))
        } else {
            effect.blendType = obj.enumeratedType
            binding?(Binding(view: self, effect: effect, oldEffect: oldEffect, type: obj.type))
        }
    }
    private func setEffect(with obj: SlidableNumberView.Binding) {
        if obj.type == .begin {
            oldEffect = effect
            binding?(Binding(view: self, effect: oldEffect, oldEffect: oldEffect, type: .begin))
        } else {
            switch obj.view {
            case blurView:
                effect.blurRadius = obj.number
            case opacityView:
                effect.opacity = obj.number
            default:
                fatalError("No case")
            }
            binding?(Binding(view: self, effect: effect, oldEffect: oldEffect, type: obj.type))
        }
    }
    
    func copiedObjects(with event: KeyInputEvent) -> [ViewExpression]? {
        return [effect]
    }
    func paste(_ objects: [Any], with event: KeyInputEvent) -> Bool {
        for object in objects {
            if let effect = object as? Effect {
                if effect != self.effect {
                    set(effect, old: self.effect)
                    return true
                }
            }
        }
        return false
    }
    func delete(with event: KeyInputEvent) -> Bool {
        let effect = defaultEffect
        guard effect != self.effect else {
            return false
        }
        set(effect, old: self.effect)
        return true
    }
    
    private func set(_ effect: Effect, old oldEffect: Effect) {
        registeringUndoManager?.registerUndo(withTarget: self) {
            $0.set(oldEffect, old: effect)
        }
        binding?(Binding(view: self, effect: oldEffect, oldEffect: oldEffect, type: .begin))
        self.effect = effect
        binding?(Binding(view: self, effect: effect, oldEffect: oldEffect, type: .end))
    }
    
    func reference(with event: TapEvent) -> Reference? {
        return effect.reference
    }
}
