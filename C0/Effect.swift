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
    var displayText: Text {
        switch self {
        case .normal:
            return Text(english: "Normal", japanese: "通常")
        case .add:
            return Text(english: "Add", japanese: "加算")
        case .subtract:
            return Text(english: "Subtract", japanese: "減算")
        }
    }
    static var displayTexts: [Text] {
        return [normal.displayText,
                add.displayText,
                subtract.displayText]
    }
}
extension BlendType: Referenceable {
    static let name = Text(english: "Blend Type", japanese: "ブレンドタイプ")
}
extension BlendType: ObjectViewExpressionWithDisplayText {
}

struct Effect: Codable, Equatable, Hashable {
    var blendType = BlendType.normal, blurRadius = 0.0.cg, opacity = 1.0.cg
    static let minBlurRadius = 0.0.cg
    static let minOpacity = 0.0.cg, maxOpacity = 1.0.cg
    
    var isEmpty: Bool {
        return self == Effect()
    }
    
    static func displayText(with keyPath: PartialKeyPath<Effect>) -> Text {
        switch keyPath {
        case \Effect.blendType:
            return Text(english: "Blend Type", japanese: "ブレンドタイプ")
        case \Effect.blurRadius:
            return Text(english: "Blur Radius", japanese: "ブラー半径")
        case \Effect.opacity:
            return Text(english: "Opacity", japanese: "不透明度")
        default:
            fatalError("No case")
        }
    }
}
extension Effect: Referenceable {
    static let name = Text(english: "Effect", japanese: "エフェクト")
}
extension Effect: Interpolatable {
    static func linear(_ f0: Effect, _ f1: Effect, t: Real) -> Effect {
        let blur = Real.linear(f0.blurRadius, f1.blurRadius, t: t)
        let opacity = Real.linear(f0.opacity, f1.opacity, t: t)
        let blendType = f0.blendType
        return Effect(blendType: blendType, blurRadius: blur, opacity: opacity)
    }
    static func firstMonospline(_ f1: Effect, _ f2: Effect, _ f3: Effect,
                                with ms: Monospline) -> Effect {
        let blur = Real.firstMonospline(f1.blurRadius, f2.blurRadius, f3.blurRadius, with: ms)
        let opacity = Real.firstMonospline(f1.opacity, f2.opacity, f3.opacity, with: ms)
        let blendType = f1.blendType
        return Effect(blendType: blendType, blurRadius: blur, opacity: opacity)
    }
    static func monospline(_ f0: Effect, _ f1: Effect, _ f2: Effect, _ f3: Effect,
                           with ms: Monospline) -> Effect {
        let blur = Real.monospline(f0.blurRadius, f1.blurRadius,
                                   f2.blurRadius, f3.blurRadius, with: ms)
        let opacity = Real.monospline(f0.opacity, f1.opacity, f2.opacity, f3.opacity, with: ms)
        let blendType = f1.blendType
        return Effect(blendType: blendType, blurRadius: blur, opacity: opacity)
    }
    static func lastMonospline(_ f0: Effect, _ f1: Effect, _ f2: Effect,
                               with ms: Monospline) -> Effect {
        let blur = Real.lastMonospline(f0.blurRadius, f1.blurRadius, f2.blurRadius, with: ms)
        let opacity = Real.lastMonospline(f0.opacity, f1.opacity, f2.opacity, with: ms)
        let blendType = f1.blendType
        return Effect(blendType: blendType, blurRadius: blur, opacity: opacity)
    }
}
extension Effect: ObjectViewExpression {
    func thumbnail(withBounds bounds: Rect, _ sizeType: SizeType) -> View {
        return blendType.displayText.thumbnail(withBounds: bounds, sizeType)
    }
}

final class EffectView: View, Queryable, Assignable {
    var effect: Effect {
        didSet {
            if effect != oldValue {
                updateWithEffect()
            }
        }
    }
    var defaultEffect = Effect()
    
    static let defaultWidth = 140.0.cg
    
    var sizeType: SizeType
    private let classNameView: TextView
    private let blendTypeView: EnumView<BlendType>
    private let classBlurNameView: TextView
    private let blurView: SlidableNumberView
    private let opacityView: SlidableNumberView
    
    init(sizeType: SizeType = .regular) {
        self.sizeType = sizeType
        classNameView = TextView(text: Effect.name, font: Font.bold(with: sizeType))
        let blurPropertyText = Effect.displayText(with: \Effect.blurRadius) + ":"
        classBlurNameView = TextView(text: blurPropertyText, font: Font.default(with: sizeType))
        blurView = SlidableNumberView.widthViewWith(min: 0, max: 500, exp: 3, sizeType)
        opacityView = SlidableNumberView.opacityView(sizeType)
        blendTypeView = EnumView(enumeratedType: .normal,
                                 indexClosure: { Int($0) },
                                 rawValueClosure: { BlendType.RawValue($0) },
                                 names: BlendType.displayTexts, sizeType: sizeType)
        effect = defaultEffect
        super.init()
        children = [classNameView,
                    blendTypeView,
                    classBlurNameView, blurView,
                    opacityView]
        
        blurView.binding = { [unowned self] in self.setEffect(with: $0) }
        opacityView.binding = { [unowned self] in self.setEffect(with: $0) }
        blendTypeView.binding = { [unowned self] in self.setEffect(with: $0) }
    }
    
    override var locale: Locale {
        didSet {
            updateLayout()
        }
    }
    
    override var defaultBounds: Rect {
        let padding = Layout.padding(with: sizeType), height = Layout.height(with: sizeType)
        let viewHeight = height * 2 + padding * 2
        return Rect(x: 0, y: 0, width: EffectView.defaultWidth, height: viewHeight)
    }
    override var bounds: Rect {
        didSet {
            updateLayout()
        }
    }
    func updateLayout() {
        let padding = Layout.padding(with: sizeType), h = Layout.height(with: sizeType)
        let cw = bounds.width - padding * 2
        let rw = cw - classNameView.frame.width - padding
        let px = bounds.width - rw - padding
        classNameView.frame.origin = Point(x: padding,
                                             y: bounds.height - classNameView.frame.height - padding)
        blendTypeView.frame = Rect(x: px, y: padding + h, width: rw, height: h)
        classBlurNameView.frame.origin = Point(x: padding,
                                                 y: padding * 2)
        let blurW = ceil((cw - classBlurNameView.frame.width) / 2)
        blurView.updateLineWidthViews(withFrame: Rect(x: classBlurNameView.frame.maxX, y: padding,
                                                         width: blurW, height: h))
        opacityView.updateOpacityViews(withFrame: Rect(x: blurView.frame.maxX,
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
        let effect: Effect, oldEffect: Effect, phase: Phase
    }
    var binding: ((Binding) -> ())?
    
    private var oldEffect = Effect()
    private func setEffect(with obj: EnumView<BlendType>.Binding) {
        if obj.phase == .began {
            oldEffect = effect
            binding?(Binding(view: self, effect: oldEffect, oldEffect: oldEffect, phase: .began))
        } else {
            effect.blendType = obj.enumeratedType
            binding?(Binding(view: self, effect: effect, oldEffect: oldEffect, phase: obj.phase))
        }
    }
    private func setEffect(with obj: SlidableNumberView.Binding) {
        if obj.phase == .began {
            oldEffect = effect
            binding?(Binding(view: self, effect: oldEffect, oldEffect: oldEffect, phase: .began))
        } else {
            switch obj.view {
            case blurView:
                effect.blurRadius = obj.number
            case opacityView:
                effect.opacity = obj.number
            default:
                fatalError("No case")
            }
            binding?(Binding(view: self, effect: effect, oldEffect: oldEffect, phase: obj.phase))
        }
    }
    
    func delete(for p: Point) {
        let effect = defaultEffect
        guard effect != self.effect else {
            return
        }
        set(effect, old: self.effect)
    }
    func copiedViewables(at p: Point) -> [Viewable] {
        return [effect]
    }
    func paste(_ objects: [Any], for p: Point) {
        for object in objects {
            if let effect = object as? Effect {
                if effect != self.effect {
                    set(effect, old: self.effect)
                    return
                }
            }
        }
    }
    
    private func set(_ effect: Effect, old oldEffect: Effect) {
        registeringUndoManager?.registerUndo(withTarget: self) {
            $0.set(oldEffect, old: effect)
        }
        binding?(Binding(view: self, effect: oldEffect, oldEffect: oldEffect, phase: .began))
        self.effect = effect
        binding?(Binding(view: self, effect: effect, oldEffect: oldEffect, phase: .ended))
    }
    
    func reference(at p: Point) -> Reference {
        return Effect.reference
    }
}
