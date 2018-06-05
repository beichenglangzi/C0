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

protocol KeyframeProtocol {
    var timing: KeyframeTiming { get }
}
protocol KeyframeValue: Equatable, Interpolatable, Initializable, Object.Value, AbstractViewable {
    var defaultLabel: KeyframeTiming.Label { get }
}
extension KeyframeValue {
    var defaultLabel: KeyframeTiming.Label {
        return .main
    }
}
struct Keyframe<Value: KeyframeValue>: Codable, Equatable, KeyframeProtocol {
    var value = Value()
    var timing = KeyframeTiming()
}
extension Keyframe {
    struct IndexInfo {
        var index: Int, interTime: Beat, duration: Beat
    }
    static func indexInfo(atTime t: Beat, with keyframes: [Keyframe]) -> IndexInfo {
        var oldT = Beat(0)
        for i in (0..<keyframes.count).reversed() {
            let keyframe = keyframes[i]
            if t >= keyframe.timing.time {
                return IndexInfo(index: i,
                                 interTime: t - keyframe.timing.time,
                                 duration: oldT - keyframe.timing.time)
            }
            oldT = keyframe.timing.time
        }
        return IndexInfo(index: 0,
                         interTime: t - keyframes.first!.timing.time,
                         duration: oldT - keyframes.first!.timing.time)
    }
}
extension Keyframe: Referenceable {
    static var name: Text {
        return Text(english: "Keyframe", japanese: "キーフレーム") + "<" + Value.name + ">"
    }
}
extension Keyframe: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return timing.interpolation.displayText.thumbnailView(withFrame: frame, sizeType)
    }
}
extension Keyframe: AbstractViewable {
    func abstractViewWith<T : BinderProtocol>(binder: T,
                                              keyPath: ReferenceWritableKeyPath<T, Keyframe>,
                                              frame: Rect, _ sizeType: SizeType,
                                              type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return KeyframeView(binder: binder, keyPath: keyPath,
                                frame: frame, sizeType: sizeType)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath, frame: frame, sizeType)
        }
    }
}
extension Keyframe: ObjectViewable {}

struct KeyframeTiming: Codable, Hashable {
    enum Label: Int8, Codable {
        case main, sub
    }
    enum Loop: Int8, Codable {
        case none, began, ended
    }
    enum Interpolation: Int8, Codable {
        case spline, bound, linear, step
    }
    
    var time = Beat(0)
    var label = Label.main, loop = Loop.none
    var interpolation = Interpolation.spline, easing = Easing()
}
extension KeyframeTiming: Referenceable {
    static let name = Text(english: "Keyframe Timing", japanese: "キーフレームタイミング")
}

extension KeyframeTiming.Label: Referenceable {
    static let uninheritanceName = Text(english: "Label", japanese: "ラベル")
    static let name = KeyframeTiming.name.spacedUnion(uninheritanceName)
}
extension KeyframeTiming.Label: DisplayableText {
    var displayText: Text {
        switch self {
        case .main: return Text(english: "Main", japanese: "メイン")
        case .sub: return Text(english: "Sub", japanese: "サブ")
        }
    }
    static var displayTexts: [Text] {
        return [main.displayText,
                sub.displayText]
    }
}
extension KeyframeTiming.Label {
    static var defaultOption: EnumOption<KeyframeTiming.Label> {
        return EnumOption(defaultModel: KeyframeTiming.Label.main,
                          cationModels: [],
                          indexClosure: { Int($0) },
                          rawValueClosure: { KeyframeTiming.Label.RawValue($0) },
                          names: KeyframeTiming.Label.displayTexts)
    }
}
extension KeyframeTiming.Label: AbstractViewable {
    func abstractViewWith
        <T : BinderProtocol>(binder: T,
                             keyPath: ReferenceWritableKeyPath<T, KeyframeTiming.Label>,
                             frame: Rect, _ sizeType: SizeType,
                             type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return EnumView(binder: binder, keyPath: keyPath,
                            option: KeyframeTiming.Label.defaultOption,
                            frame: frame, sizeType: sizeType)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath, frame: frame, sizeType)
        }
    }
}
extension KeyframeTiming.Label: ObjectViewable {}

extension KeyframeTiming.Loop: Referenceable {
    static let uninheritanceName = Text(english: "Loop", japanese: "ループ")
    static let name = KeyframeTiming.name.spacedUnion(uninheritanceName)
}
extension KeyframeTiming.Loop: DisplayableText {
    var displayText: Text {
        switch self {
        case .none: return Text(english: "None", japanese: "なし")
        case .began: return Text(english: "Began", japanese: "開始")
        case .ended: return Text(english: "Ended", japanese: "終了")
        }
    }
    static var displayTexts: [Text] {
        return [none.displayText,
                began.displayText,
                ended.displayText]
    }
}
extension KeyframeTiming.Loop {
    static var defaultOption: EnumOption<KeyframeTiming.Loop> {
        return EnumOption(defaultModel: KeyframeTiming.Loop.none,
                          cationModels: [],
                          indexClosure: { Int($0) },
                          rawValueClosure: { KeyframeTiming.Loop.RawValue($0) },
                          names: KeyframeTiming.Loop.displayTexts)
    }
}
extension KeyframeTiming.Loop: AbstractViewable {
    func abstractViewWith
        <T : BinderProtocol>(binder: T,
                             keyPath: ReferenceWritableKeyPath<T, KeyframeTiming.Loop>,
                             frame: Rect, _ sizeType: SizeType,
                             type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return EnumView(binder: binder, keyPath: keyPath,
                            option: KeyframeTiming.Loop.defaultOption,
                            frame: frame, sizeType: sizeType)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath, frame: frame, sizeType)
        }
    }
}
extension KeyframeTiming.Loop: ObjectViewable {}

extension KeyframeTiming.Interpolation: Referenceable {
    static let uninheritanceName = Text(english: "Interpolation", japanese: "補間")
    static let name = KeyframeTiming.name.spacedUnion(uninheritanceName)
}
extension KeyframeTiming.Interpolation: DisplayableText {
    var displayText: Text {
        switch self {
        case .spline: return Text(english: "Spline", japanese: "スプライン")
        case .bound: return Text(english: "Bound", japanese: "バウンド")
        case .linear: return Text(english: "Linear", japanese: "リニア")
        case .step: return Text(english: "Step", japanese: "ステップ")
        }
    }
    static var displayTexts: [Text] {
        return [spline.displayText,
                bound.displayText,
                linear.displayText,
                step.displayText]
    }
}
extension KeyframeTiming.Interpolation {
    static var defaultOption: EnumOption<KeyframeTiming.Interpolation> {
        return EnumOption(defaultModel: KeyframeTiming.Interpolation.spline,
                          cationModels: [],
                          indexClosure: { Int($0) },
                          rawValueClosure: { KeyframeTiming.Interpolation.RawValue($0) },
                          names: KeyframeTiming.Interpolation.displayTexts)
    }
}
extension KeyframeTiming.Interpolation: AbstractViewable {
    func abstractViewWith
        <T : BinderProtocol>(binder: T,
                             keyPath: ReferenceWritableKeyPath<T, KeyframeTiming.Interpolation>,
                             frame: Rect, _ sizeType: SizeType,
                             type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return EnumView(binder: binder, keyPath: keyPath,
                            option: KeyframeTiming.Interpolation.defaultOption,
                            frame: frame, sizeType: sizeType)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath, frame: frame, sizeType)
        }
    }
}
extension KeyframeTiming.Interpolation: ObjectViewable {}

extension KeyframeTiming: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return interpolation.displayText.thumbnailView(withFrame: frame, sizeType)
    }
}
extension KeyframeTiming: AbstractViewable {
    func abstractViewWith
        <T : BinderProtocol>(binder: T,
                             keyPath: ReferenceWritableKeyPath<T, KeyframeTiming>,
                             frame: Rect, _ sizeType: SizeType,
                             type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return KeyframeTimingView(binder: binder, keyPath: keyPath,
                                      frame: frame, sizeType: sizeType)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath, frame: frame, sizeType)
        }
    }
}
extension KeyframeTiming: ObjectViewable {}
extension KeyframeTiming {
    static let labelOption = KeyframeTiming.Label.defaultOption
    static let loopOption = KeyframeTiming.Loop.defaultOption
    static let interpolationOption = KeyframeTiming.Interpolation.defaultOption
}

struct KeyframeTimingCollection: RandomAccessCollection {
    let keyframes: [KeyframeProtocol]
    var startIndex: Int {
        return keyframes.startIndex
    }
    var endIndex: Int {
        return keyframes.endIndex
    }
    func index(after i: Int) -> Int {
        return keyframes.index(after: i)
    }
    func index(before i: Int) -> Int {
        return keyframes.index(before: i)
    }
    subscript(i: Int) -> KeyframeTiming {
        return keyframes[i].timing
    }
}

final class KeyframeView<Value: KeyframeValue, T: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = Keyframe<Value>
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((KeyframeView<Value, Binder>, BasicNotification) -> ())]()
    
    var defaultModel = Model()
    
    var keyValueView: View
    var keyframeTimingView: KeyframeTimingView<Binder>
    
    init(binder: Binder, keyPath: BinderKeyPath,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        let keyValueKeyPath = keyPath.appending(path: \Model.value)
        keyValueView = binder[keyPath: keyPath].value.abstractViewWith(binder: binder,
                                                                       keyPath: keyValueKeyPath,
                                                                       frame: Rect(),
                                                                       sizeType, type: .normal)
        keyframeTimingView = KeyframeTimingView(binder: binder,
                                                keyPath: keyPath.appending(path: \Model.timing),
                                                sizeType: sizeType)
        super.init()
        
    }
    
    override func updateLayout() {
        
    }
    func updateWithModel() {
//        keyValueView
        keyframeTimingView.updateWithModel()
    }
    
    func clippedModel(_ model: Model) -> Model {
        var model = model
        model.timing.time = self.model.timing.time
        return model
    }
}

final class KeyframeTimingView<T: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = KeyframeTiming
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((KeyframeTimingView<Binder>, BasicNotification) -> ())]()
    
    var defaultModel = Model()
    
    let labelView: EnumView<KeyframeTiming.Label, Binder>
    let loopView: EnumView<KeyframeTiming.Loop, Binder>
    let interpolationView: EnumView<KeyframeTiming.Interpolation, Binder>
    let easingView: EasingView<Binder>
    
    var sizeType: SizeType {
        didSet { updateLayout() }
    }
    let classNameView: TextFormView
    
    init(binder: Binder, keyPath: BinderKeyPath,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        labelView = EnumView(binder: binder,
                             keyPath: keyPath.appending(path: \Model.label),
                             option: Model.labelOption, sizeType: sizeType)
        loopView = EnumView(binder: binder,
                            keyPath: keyPath.appending(path: \Model.loop),
                            option: Model.loopOption, sizeType: sizeType)
        interpolationView = EnumView(binder: binder,
                                     keyPath: keyPath.appending(path: \Model.interpolation),
                                     option: Model.interpolationOption, sizeType: sizeType)
        easingView = EasingView(binder: binder,
                                keyPath: keyPath.appending(path: \Model.easing),
                                sizeType: sizeType)
        
        self.sizeType = sizeType
        classNameView = TextFormView(text: Model.name, font: Font.bold(with: sizeType))
        
        super.init()
        children = [classNameView, labelView, loopView, interpolationView, easingView]
        self.frame = frame
    }
    
    override var defaultBounds: Rect {
        let w = max(labelView.defaultBounds.width, interpolationView.defaultBounds.width,
                    loopView.defaultBounds.width, easingView.defaultBounds.width)
        let padding = Layouter.padding(with: sizeType)
        let h = Layouter.height(with: sizeType)
        let dh = h * 4 + easingView.frame.width + classNameView.frame.height
        return Rect(x: 0, y: 0, width: w + padding * 2, height: dh + padding * 2)
    }
    override func updateLayout() {
        let padding = Layouter.padding(with: sizeType)
        let w = bounds.width - padding * 2, h = Layouter.height(with: sizeType)
        var y = bounds.height - classNameView.frame.height - padding
        classNameView.frame.origin = Point(x: padding, y: y)
        labelView.frame = Rect(x: classNameView.frame.maxX + padding, y: y - padding * 2,
                                 width: w - classNameView.frame.width - padding, height: h)
        y -= h + padding * 2
        interpolationView.frame = Rect(x: padding, y: y, width: w, height: h)
        y -= h
        loopView.frame = Rect(x: padding, y: y, width: w, height: h)
        easingView.frame = Rect(x: padding, y: padding, width: w, height: y - padding)
    }
    func updateWithModel() {
        labelView.updateWithModel()
        loopView.updateWithModel()
        interpolationView.updateWithModel()
        easingView.updateWithModel()
    }
    
    func clippedModel(_ model: Model) -> Model {
        var model = model
        model.time = self.model.time
        return model
    }
}
