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
    func thumbnailView(withFrame frame: Rect) -> View {
        return timing.interpolation.displayText.thumbnailView(withFrame: frame)
    }
}
extension Keyframe: AbstractViewable {
    func abstractViewWith<T : BinderProtocol>(binder: T,
                                              keyPath: ReferenceWritableKeyPath<T, Keyframe>,
                                              type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return KeyframeView(binder: binder, keyPath: keyPath)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath)
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
                             type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return EnumView(binder: binder, keyPath: keyPath,
                            option: KeyframeTiming.Label.defaultOption)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath)
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
                             type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return EnumView(binder: binder, keyPath: keyPath,
                            option: KeyframeTiming.Loop.defaultOption)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath)
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
                             type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return EnumView(binder: binder, keyPath: keyPath,
                            option: KeyframeTiming.Interpolation.defaultOption)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath)
        }
    }
}
extension KeyframeTiming.Interpolation: ObjectViewable {}

extension KeyframeTiming: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect) -> View {
        return interpolation.displayText.thumbnailView(withFrame: frame)
    }
}
extension KeyframeTiming: AbstractViewable {
    func abstractViewWith
        <T : BinderProtocol>(binder: T,
                             keyPath: ReferenceWritableKeyPath<T, KeyframeTiming>,
                             type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return KeyframeTimingView(binder: binder, keyPath: keyPath)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath)
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
    
    var keyValueView: View & LayoutMinSize
    var keyframeTimingView: KeyframeTimingView<Binder>
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        let keyValueKeyPath = keyPath.appending(path: \Model.value)
        keyValueView = binder[keyPath: keyPath].value.abstractViewWith(binder: binder,
                                                                       keyPath: keyValueKeyPath,
                                                                       type: .normal)
        keyframeTimingView = KeyframeTimingView(binder: binder,
                                                keyPath: keyPath.appending(path: \Model.timing))
        
        super.init(isLocked: false)
        
    }
    
    var minSize: Size {
        let kvms = keyValueView.minSize, ktms = keyframeTimingView.minSize
        return Size(width: max(kvms.width, ktms.width), height: kvms.height + ktms.height)
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
    
    let classNameView: TextFormView
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        labelView = EnumView(binder: binder,
                             keyPath: keyPath.appending(path: \Model.label),
                             option: Model.labelOption, isUninheritance: true)
        loopView = EnumView(binder: binder,
                            keyPath: keyPath.appending(path: \Model.loop),
                            option: Model.loopOption, isUninheritance: true)
        interpolationView = EnumView(binder: binder,
                                     keyPath: keyPath.appending(path: \Model.interpolation),
                                     option: Model.interpolationOption, isUninheritance: true)
        easingView = EasingView(binder: binder,
                                keyPath: keyPath.appending(path: \Model.easing))
        
        classNameView = TextFormView(text: Model.name, font: .bold)
        
        super.init(isLocked: false)
        children = [classNameView, labelView, loopView, interpolationView, easingView]
    }
    
    var minSize: Size {
        let w = max(labelView.minSize.width, interpolationView.minSize.width,
                    loopView.minSize.width, easingView.minSize.width)
        let padding = Layouter.basicPadding
        let h = Layouter.basicHeight
        let dh = h * 4 + easingView.minSize.width + classNameView.frame.height
        return Size(width: w + padding * 2, height: dh + padding * 2)
    }
    override func updateLayout() {
        let padding = Layouter.basicPadding
        let classNameSize = classNameView.minSize
        let classNameOrigin = Point(x: padding,
                                    y: bounds.height - classNameSize.height - padding)
        classNameView.frame = Rect(origin: classNameOrigin, size: classNameSize)
        
        let w = bounds.width - padding * 2, h = Layouter.basicHeight
        var y = bounds.height - classNameView.frame.height - padding
        let labelSize = labelView.minSize
        labelView.frame = Rect(x: classNameView.frame.maxX + padding, y: y - padding * 2,
                                 width: labelSize.width, height: labelSize.height)
        y -= h + padding * 2
        let interpolationSize = interpolationView.minSize
        interpolationView.frame = Rect(origin: Point(x: padding, y: y), size: interpolationSize)
        y -= h
        let loopSize = loopView.minSize
        loopView.frame = Rect(origin: Point(x: padding, y: y), size: loopSize)
        easingView.frame = Rect(x: padding, y: padding, width: w, height: y - padding)
    }
    
    func clippedModel(_ model: Model) -> Model {
        var model = model
        model.time = self.model.time
        return model
    }
}
