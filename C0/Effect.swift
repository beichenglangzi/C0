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
    case normal, addition, subtract
    
    var blendMode: CGBlendMode {
        switch self {
        case .normal:
            return .normal
        case .addition:
            return .plusLighter
        case .subtract:
            return .plusDarker
        }
    }
    var displayText: Text {
        switch self {
        case .normal:
            return Text(english: "Normal", japanese: "通常")
        case .addition:
            return Text(english: "Addition", japanese: "加算")
        case .subtract:
            return Text(english: "Subtract", japanese: "減算")
        }
    }
    static var displayTexts: [Text] {
        return [normal.displayText,
                addition.displayText,
                subtract.displayText]
    }
}
extension BlendType: Referenceable {
    static let name = Text(english: "Blend Type", japanese: "ブレンドタイプ")
}
extension BlendType: CompactViewableWithDisplayText {}

struct Effect: Codable, Equatable, Hashable {
    var blendType = BlendType.normal, blurRadius = 0.0.cg, opacity = 1.0.cg
    
    static let minBlurRadius = 0.0.cg, maxBlurRadius = 1000.0.cg
    static let minOpacity = 0.0.cg, maxOpacity = 1.0.cg
    
    var isEmpty: Bool {
        return self == Effect()
    }
}
extension Effect {
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
        let blendType = f0.blendType
        let blur = Real.linear(f0.blurRadius, f1.blurRadius, t: t)
        let opacity = Real.linear(f0.opacity, f1.opacity, t: t)
        return Effect(blendType: blendType, blurRadius: blur, opacity: opacity)
    }
    static func firstMonospline(_ f1: Effect, _ f2: Effect, _ f3: Effect,
                                with ms: Monospline) -> Effect {
        let blendType = f1.blendType
        let blur = Real.firstMonospline(f1.blurRadius, f2.blurRadius, f3.blurRadius, with: ms)
        let opacity = Real.firstMonospline(f1.opacity, f2.opacity, f3.opacity, with: ms)
        return Effect(blendType: blendType, blurRadius: blur, opacity: opacity)
    }
    static func monospline(_ f0: Effect, _ f1: Effect, _ f2: Effect, _ f3: Effect,
                           with ms: Monospline) -> Effect {
        let blendType = f1.blendType
        let blur = Real.monospline(f0.blurRadius, f1.blurRadius,
                                   f2.blurRadius, f3.blurRadius, with: ms)
        let opacity = Real.monospline(f0.opacity, f1.opacity, f2.opacity, f3.opacity, with: ms)
        return Effect(blendType: blendType, blurRadius: blur, opacity: opacity)
    }
    static func lastMonospline(_ f0: Effect, _ f1: Effect, _ f2: Effect,
                               with ms: Monospline) -> Effect {
        let blendType = f1.blendType
        let blur = Real.lastMonospline(f0.blurRadius, f1.blurRadius, f2.blurRadius, with: ms)
        let opacity = Real.lastMonospline(f0.opacity, f1.opacity, f2.opacity, with: ms)
        return Effect(blendType: blendType, blurRadius: blur, opacity: opacity)
    }
}
extension Effect: Initializable {}
extension Effect: KeyframeValue {}
extension Effect: CompactViewable {
    func thumbnail(withBounds bounds: Rect, _ sizeType: SizeType) -> View {
        return blendType.displayText.thumbnail(withBounds: bounds, sizeType)
    }
}

struct EffectTrack: Track, Codable {
    private(set) var animation = Animation<Effect>()
    var animatable: Animatable {
        return animation
    }
}

final class EffectView<T: BinderProtocol>: View, BindableReceiver {
    typealias Model = Effect
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    
    let blendTypeView: EnumView<BlendType, Binder>
    let blurView: SlidableNumberView
    let opacityView: SlidableNumberView
    
    var sizeType: SizeType
    let classNameView: TextView
    let classBlurNameView: TextView
    
    init(binder: T, keyPath: ReferenceWritableKeyPath<T, Effect>, sizeType: SizeType = .regular) {
        self.sizeType = sizeType
        classNameView = TextView(text: Effect.name, font: Font.bold(with: sizeType))
        let blurPropertyText = Effect.displayText(with: \Effect.blurRadius) + ":"
        classBlurNameView = TextView(text: blurPropertyText, font: Font.default(with: sizeType))
        
        blendTypeView = EnumView(enumeratedType: .normal,
                                 indexClosure: { Int($0) },
                                 rawValueClosure: { BlendType.RawValue($0) },
                                 names: BlendType.displayTexts, sizeType: sizeType)
        blurView = SlidableNumberView.widthViewWith(min: Effect.minBlurRadius,
                                                    max: Effect.maxBlurRadius, exp: 3, sizeType)
        opacityView = SlidableNumberView.opacityView(sizeType)
        
        self.binder = binder
        self.keyPath = keyPath
        
        super.init()
        children = [classNameView,
                    blendTypeView, classBlurNameView, blurView, opacityView]
    }
    
    override var defaultBounds: Rect {
        let padding = Layout.padding(with: sizeType), height = Layout.height(with: sizeType)
        let viewHeight = height * 2 + padding * 2
        return Rect(x: 0, y: 0, width: Layout.propertyWidth, height: viewHeight)
    }
    override func updateLayout() {
        let padding = Layout.padding(with: sizeType), h = Layout.height(with: sizeType)
        let cw = bounds.width - padding * 2
        let rw = cw - classNameView.frame.width - padding
        let px = bounds.width - rw - padding
        classNameView.frame.origin = Point(x: padding,
                                           y: bounds.height - classNameView.frame.height - padding)
        blendTypeView.frame = Rect(x: px, y: padding + h, width: rw, height: h)
        classBlurNameView.frame.origin = Point(x: padding, y: padding * 2)
        let blurW = ceil((cw - classBlurNameView.frame.width) / 2)
        blurView.updateLineWidthViews(withFrame: Rect(x: classBlurNameView.frame.maxX, y: padding,
                                                      width: blurW, height: h))
        opacityView.updateOpacityViews(withFrame: Rect(x: blurView.frame.maxX,
                                                       y: padding,
                                                       width: bounds.width - blurView.frame.maxX - padding,
                                                       height: h))
    }
    func updateWithModel() {
        blendTypeView.enumeratedType = model.blendType
        blurView.number = effect.blurRadius
        opacityView.number = effect.opacity
    }
}
extension EffectView: Localizable {
    func update(with locale: Locale) {
        updateLayout()
    }
}
extension EffectView: Queryable {
    static var referenceableType: Referenceable.Type {
        return Effect.self
    }
}
extension EffectView: Assignable {
    func delete(for p: Point) {
        push(Effect())
    }
    func copiedViewables(at p: Point) -> [Viewable] {
        return [model]
    }
    func paste(_ objects: [Any], for p: Point) {
        for object in objects {
            if let effect = object as? Effect {
                push(effect)
                return
            }
        }
    }
}
