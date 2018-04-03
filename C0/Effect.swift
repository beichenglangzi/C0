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

struct Effect: Codable {
    enum BlendType: Int8, Codable {
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
        var displayString: Localization {
            switch self {
            case .normal:
                return Localization(english: "Normal", japanese: "通常")
            case .add:
                return Localization(english: "Add", japanese: "加算")
            case .subtract:
                return Localization(english: "Subtract", japanese: "減算")
            }
        }
        static var displayStrings: [Localization] {
            return [normal.displayString,
                    add.displayString,
                    subtract.displayString]
        }
    }
    var blur = 0.0.cf, opacity = 1.0.cf, blendType = BlendType.normal
    var isEmpty: Bool {
        return self == Effect()
    }
    func with(blur: CGFloat) -> Effect {
        return Effect(blur: blur, opacity: opacity, blendType: blendType)
    }
    func with(opacity: CGFloat) -> Effect {
        return Effect(blur: blur, opacity: opacity, blendType: blendType)
    }
    func with(_ blendType: BlendType) -> Effect {
        return Effect(blur: blur, opacity: opacity, blendType: blendType)
    }
}
extension Effect: Equatable {
    static func ==(lhs: Effect, rhs: Effect) -> Bool {
        return lhs.blur == rhs.blur && lhs.opacity == rhs.opacity && lhs.blendType == rhs.blendType
    }
}
extension Effect: Referenceable {
    static let name = Localization(english: "Effect", japanese: "エフェクト")
}
extension Effect: Interpolatable {
    static func linear(_ f0: Effect, _ f1: Effect, t: CGFloat) -> Effect {
        let blur = CGFloat.linear(f0.blur, f1.blur, t: t)
        let opacity = CGFloat.linear(f0.opacity, f1.opacity, t: t)
        let blendType = f0.blendType
        return Effect(blur: blur, opacity: opacity, blendType: blendType)
    }
    static func firstMonospline(_ f1: Effect, _ f2: Effect, _ f3: Effect,
                                with ms: Monospline) -> Effect {
        let blur = CGFloat.firstMonospline(f1.blur, f2.blur, f3.blur, with: ms)
        let opacity = CGFloat.firstMonospline(f1.opacity, f2.opacity, f3.opacity, with: ms)
        let blendType = f1.blendType
        return Effect(blur: blur, opacity: opacity, blendType: blendType)
    }
    static func monospline(_ f0: Effect, _ f1: Effect, _ f2: Effect, _ f3: Effect,
                           with ms: Monospline) -> Effect {
        let blur = CGFloat.monospline(f0.blur, f1.blur, f2.blur, f3.blur, with: ms)
        let opacity = CGFloat.monospline(f0.opacity, f1.opacity,
                                         f2.opacity, f3.opacity, with: ms)
        let blendType = f1.blendType
        return Effect(blur: blur, opacity: opacity, blendType: blendType)
    }
    static func lastMonospline(_ f0: Effect, _ f1: Effect, _ f2: Effect,
                               with ms: Monospline) -> Effect {
        let blur = CGFloat.lastMonospline(f0.blur, f1.blur, f2.blur, with: ms)
        let opacity = CGFloat.lastMonospline(f0.opacity, f1.opacity, f2.opacity, with: ms)
        let blendType = f1.blendType
        return Effect(blur: blur, opacity: opacity, blendType: blendType)
    }
}

final class EffectView: Layer, Respondable {
    static let name = Effect.name
    
    var effect: Effect {
        didSet {
            if effect != oldValue {
                updateWithEffect()
            }
        }
    }
    var defaultEffect = Effect()
    
    static let defaultWidth = 140.0.cf
    
    var isSmall: Bool
    private let nameLabel: Label
    private let blendTypeView: EnumView
    private let blurLabel: Label
    private let blurView: NumberView
    private let opacityView: NumberView
    
    init(isSmall: Bool = false) {
        self.isSmall = isSmall
        nameLabel = Label(text: Effect.name, font: isSmall ? .smallBold : .bold)
        blurLabel = Label(text: Localization(english: "Blur:", japanese: "ブラー:"),
                          font: isSmall ? .small : .default)
        blurView = NumberView.widthViewWith(min: 0, max: 500, exp: 3, isSmall: isSmall)
        opacityView = NumberView.opacityView(isSmall: isSmall)
        blendTypeView = EnumView(names: Effect.BlendType.displayStrings, isSmall: isSmall)
        effect = defaultEffect
        super.init()
        replace(children: [nameLabel,
                           blendTypeView,
                           blurLabel, blurView,
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
        let height = isSmall ?
            Layout.smallHeight * 3 + Layout.smallPadding * 2 :
            Layout.basicHeight * 3 + Layout.basicPadding * 2
        return CGRect(x: 0, y: 0, width: EffectView.defaultWidth, height: height)
    }
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    func updateLayout() {
        let padding = isSmall ? Layout.smallPadding : Layout.basicPadding
        let h = isSmall ? Layout.smallHeight : Layout.basicHeight
        let cw = bounds.width - padding * 2
        let rw = cw - nameLabel.frame.width - padding
        let px = bounds.width - rw - padding
        nameLabel.frame.origin = CGPoint(x: padding,
                                         y: bounds.height - nameLabel.frame.height - padding)
        blendTypeView.frame = CGRect(x: px, y: padding + h * 2, width: rw, height: h)
        blurLabel.frame.origin = CGPoint(x: px - blurLabel.frame.width, y: padding * 2 + h)
        blurView.updateLineWidthLayers(withFrame: CGRect(x: px, y: padding + h, width: rw, height: h))
        opacityView.updateOpacityLayers(withFrame: CGRect(x: px, y: padding, width: rw, height: h))
    }
    private func updateWithEffect() {
        blurView.number = effect.blur
        opacityView.number = effect.opacity
        blendTypeView.selectedIndex = index(with: effect.blendType)
    }
    
    private func blendType(withIndex index: Int) -> Effect.BlendType {
        return Effect.BlendType(rawValue: Int8(index)) ?? .normal
    }
    private func index(with type: Effect.BlendType) -> Int {
        return Int(type.rawValue)
    }
    
    var disabledRegisterUndo = true
    
    struct Binding {
        let view: EffectView
        let effect: Effect, oldEffect: Effect, type: Action.SendType
    }
    var binding: ((Binding) -> ())?
    
    private var oldEffect = Effect()
    private func setEffect(with obj: NumberView.Binding) {
        if obj.type == .begin {
            oldEffect = effect
            binding?(Binding(view: self, effect: oldEffect, oldEffect: oldEffect, type: .begin))
        } else {
            switch obj.view {
            case blurView:
                effect = effect.with(blur: obj.number)
            case opacityView:
                effect = effect.with(opacity: obj.number)
            default:
                fatalError("No case")
            }
            binding?(Binding(view: self, effect: effect, oldEffect: oldEffect, type: obj.type))
        }
    }
    private func setEffect(with obj: EnumView.Binding) {
        if obj.type == .begin {
            oldEffect = effect
            binding?(Binding(view: self, effect: oldEffect, oldEffect: oldEffect, type: .begin))
        } else {
            effect = effect.with(blendType(withIndex: obj.index))
            binding?(Binding(view: self, effect: effect, oldEffect: oldEffect, type: obj.type))
        }
    }
    
    func copy(with event: KeyInputEvent) -> CopyManager? {
        return CopyManager(copiedObjects: [effect])
    }
    func paste(_ copyManager: CopyManager, with event: KeyInputEvent) -> Bool {
        for object in copyManager.copiedObjects {
            if let effect = object as? Effect {
                guard effect != self.effect else {
                    continue
                }
                set(effect, old: self.effect)
                return true
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
}
