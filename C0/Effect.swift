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

enum BlendType: Int8, Codable, Hashable {
    case normal, addition, subtract
}
extension BlendType: Referenceable {
    static let name = Text(english: "Blend Type", japanese: "合成タイプ")
}
extension BlendType: DisplayableText {
    var displayText: Text {
        switch self {
        case .normal: return Text(english: "Normal", japanese: "通常")
        case .addition: return Text(english: "Addition", japanese: "加算")
        case .subtract: return Text(english: "Subtract", japanese: "減算")
        }
    }
    static var displayTexts: [Text] {
        return [normal.displayText,
                addition.displayText,
                subtract.displayText]
    }
}
extension BlendType {
    static var defaultOption: EnumOption<BlendType> {
        return EnumOption(defaultModel: BlendType.normal, cationModels: [],
                          indexClosure: { Int($0) },
                          rawValueClosure: { BlendType.RawValue($0) },
                          names: BlendType.displayTexts)
    }
}
extension BlendType: AbstractViewable {
    func abstractViewWith<T : BinderProtocol>(binder: T,
                                              keyPath: ReferenceWritableKeyPath<T, BlendType>,
                                              frame: Rect, _ sizeType: SizeType,
                                              type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return EnumView(binder: binder, keyPath: keyPath, option: BlendType.defaultOption,
                            frame: frame, sizeType: sizeType)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath, frame: frame, sizeType)
        }
    }
}
extension BlendType: ObjectViewable {}

struct Effect: Codable, Hashable {
    var blendType = BlendType.normal, blurRadius = 0.0.cg, opacity = 1.0.cg
}
extension Effect {
    var isEmpty: Bool {
        return self == Effect()
    }
}
extension Effect {
    static func displayText(with keyPath: PartialKeyPath<Effect>) -> Text {
        switch keyPath {
        case \Effect.blendType: return Text(english: "Blend Type", japanese: "ブレンドタイプ")
        case \Effect.blurRadius: return Text(english: "Blur Radius", japanese: "ブラー半径")
        case \Effect.opacity: return Text(english: "Opacity", japanese: "不透明度")
        default: fatalError("No case")
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
extension Effect: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return blendType.displayText.thumbnailView(withFrame: frame, sizeType)
    }
}
extension Effect: AbstractViewable {
    func abstractViewWith<T : BinderProtocol>(binder: T,
                                              keyPath: ReferenceWritableKeyPath<T, Effect>,
                                              frame: Rect, _ sizeType: SizeType,
                                              type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return EffectView(binder: binder, keyPath: keyPath,
                              frame: frame, sizeType: sizeType)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath, frame: frame, sizeType)
        }
    }
}
extension Effect: ObjectViewable {}

struct EffectOption {
    var blendTypeOption = BlendType.defaultOption
    var blurRadiusOption = RealOption(defaultModel: 0, minModel: 0, maxModel: 1000,
                                      modelInterval: 0.1, exp: 2, numberOfDigits: 1)
    var opacityOption = RealOption.opacity
}

struct EffectTrack: Track, Codable {
    var animation = Animation<Effect>()
    var animatable: Animatable {
        return animation
    }
}

final class EffectView<T: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = Effect
    typealias ModelOption = EffectOption
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((EffectView<Binder>, BasicNotification) -> ())]()
    
    var defaultModel = Model()
    
    var option: ModelOption {
        didSet {
            blendTypeView.option = option.blendTypeOption
            blurRadiusView.option = option.blurRadiusOption
            opacityView.option = option.opacityOption
            updateWithModel()
        }
    }
    
    let blendTypeView: EnumView<BlendType, Binder>
    let blurRadiusView: DiscreteRealView<Binder>
    let opacityView: SlidableRealView<Binder>
    
    var sizeType: SizeType {
        didSet { updateLayout() }
    }
    let classNameView: TextFormView
    let classBlurNameView: TextFormView
    
    init(binder: T, keyPath: BinderKeyPath, option: ModelOption = ModelOption(),
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        self.option = option
        
        blendTypeView = EnumView(binder: binder, keyPath: keyPath.appending(path: \Model.blendType),
                                 option: option.blendTypeOption, sizeType: sizeType)
        blurRadiusView = DiscreteRealView(binder: binder,
                                          keyPath: keyPath.appending(path: \Model.blurRadius),
                                          option: option.blurRadiusOption, sizeType: sizeType)
        opacityView = SlidableRealView(binder: binder,
                                       keyPath: keyPath.appending(path: \Model.opacity),
                                       option: option.opacityOption, sizeType: sizeType)
        
        self.sizeType = sizeType
        classNameView = TextFormView(text: Effect.name, font: Font.bold(with: sizeType))
        let blurPropertyText = Effect.displayText(with: \Effect.blurRadius) + ":"
        classBlurNameView = TextFormView(text: blurPropertyText, font: Font.default(with: sizeType))
        
        super.init()
        children = [classNameView,
                    blendTypeView, classBlurNameView, blurRadiusView, opacityView]
        self.frame = frame
    }
    
    override var defaultBounds: Rect {
        let padding = Layouter.padding(with: sizeType), height = Layouter.height(with: sizeType)
        let viewHeight = height * 2 + padding * 2
        return Rect(x: 0, y: 0, width: 220, height: viewHeight)
    }
    override func updateLayout() {
        let padding = Layouter.padding(with: sizeType), h = Layouter.height(with: sizeType)
        let cw = bounds.width - padding * 2
        let rw = cw - classNameView.frame.width - padding
        let px = bounds.width - rw - padding
        classNameView.frame.origin = Point(x: padding,
                                           y: bounds.height - classNameView.frame.height - padding)
        blendTypeView.frame = Rect(x: px, y: padding + h, width: rw, height: h)
        classBlurNameView.frame.origin = Point(x: padding, y: padding * 2)
        let blurW = ((cw - classBlurNameView.frame.width) / 2).rounded(.up)
        blurRadiusView.frame = Rect(x: classBlurNameView.frame.maxX, y: padding,
                                    width: blurW, height: h)
        let ow = bounds.width - blurRadiusView.frame.maxX - padding
        opacityView.updateOpacityViews(withFrame: Rect(x: blurRadiusView.frame.maxX, y: padding,
                                                       width: ow, height: h))
    }
    func updateWithModel() {
        blendTypeView.updateWithModel()
        blurRadiusView.updateWithModel()
        opacityView.updateWithModel()
    }
}
