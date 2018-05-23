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

protocol KeyframeTimingProtocol {
    var timing: KeyframeTiming { get }
}
protocol KeyframeValue: Codable, Equatable, Interpolatable, Initializable, Referenceable {
    var defaultLabel: KeyframeTiming.Label { get }
}
extension KeyframeValue {
    var defaultLabel: KeyframeTiming.Label {
        return .main
    }
}
struct Keyframe<Value: KeyframeValue>: Codable, Equatable, KeyframeTimingProtocol {
    var value = Value()
    var timing = KeyframeTiming()
    
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
                                              type: AbstractType) -> View {
        switch type {
        case .normal:
            return KeyframeView(binder: binder, keyPath: keyPath,
                                frame: frame, sizeType: sizeType)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath, frame: frame, sizeType)
        }
    }
}


struct KeyframeTiming: Codable, Hashable {
    enum Interpolation: Int8, Codable {
        case spline, bound, linear, step
    }
    enum Loop: Int8, Codable {
        case none, began, ended
    }
    enum Label: Int8, Codable {
        case main, sub
    }
    
    var time = Beat(0)
    var label = Label.main, loop = Loop.none
    var interpolation = Interpolation.spline, easing = Easing()
}
extension KeyframeTiming: Referenceable {
    static let name = Text(english: "Keyframe Timing", japanese: "キーフレームタイミング")
}
extension KeyframeTiming: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return interpolation.displayText.thumbnailView(withFrame: frame, sizeType)
    }
}
extension KeyframeTiming.Interpolation: Referenceable {
    static let uninheritanceName = Text(english: "Interpolation", japanese: "補間")
    static let name = KeyframeTiming.name.spacedUnion(uninheritanceName)
    static let classDescription
        = Text(english: "\"Bound\": Uses \"Spline\" without interpolation on previous, Not previous and next: Use \"Linear\"",
               japanese: "バウンド: 前方側の補間をしないスプライン補間, 前後が足りない場合: リニア補間を使用")
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
extension KeyframeTiming.Loop: Referenceable {
    static let uninheritanceName = Text(english: "Loop", japanese: "ループ")
    static let name = KeyframeTiming.name.spacedUnion(uninheritanceName)
    static let classDescription
        = Text(english: "Loop from \"Began Loop\" keyframe to \"Ended Loop\" keyframe on \"Ended Loop\" keyframe",
               japanese: "「ループ開始」キーフレームから「ループ終了」キーフレームの間を「ループ終了」キーフレーム上でループ")
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
extension KeyframeTiming {
    static let labelOption = EnumOption(defaultModel: Label.main,
                                        cationModels: [],
                                        indexClosure: { Int($0) },
                                        rawValueClosure: { Label.RawValue($0) },
                                        names: Label.displayTexts)
    static let loopOption = EnumOption(defaultModel: Loop.none,
                                       cationModels: [],
                                       indexClosure: { Int($0) },
                                       rawValueClosure: { Loop.RawValue($0) },
                                       names: Loop.displayTexts)
    static let interpolationOption = EnumOption(defaultModel: Interpolation.spline,
                                                cationModels: [],
                                                indexClosure: { Int($0) },
                                                rawValueClosure: { Interpolation.RawValue($0) },
                                                names: Interpolation.displayTexts)
}

struct KeyframeTimingCollection: RandomAccessCollection {
    let keyframes: [KeyframeTimingProtocol]
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

final class KeyframeView<Value: KeyframeValue, T: BinderProtocol>: View, BindableReceiver {
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
        
        super.init()
        
    }
    
    override func updateLayout() {
        
    }
    func updateWithModel() {
//        keyValueView
        keyframeTimingView.updateWithModel()
    }
}
extension KeyframeView: Queryable {
    static var referenceableType: Referenceable.Type {
        return Model.self
    }
}
extension KeyframeView: Assignable {
    func reset(for p: Point, _ version: Version) {
        var model = Model()
        model.timing.time = self.model.timing.time
        push(model, to: version)
    }
    func copiedObjects(at p: Point) -> [Object] {
        return [Object(model)]
    }
    func paste(_ objects: [Any], for p: Point, _ version: Version) {
        for object in objects {
            if let model = object as? Model {
                push(model, to: version)
                return
            }
        }
    }
}

final class KeyframeTimingView<T: BinderProtocol>: View, BindableReceiver {
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
        children = [labelView, loopView, interpolationView, easingView]
        self.frame = frame
    }
    
    override func updateLayout() {
        let padding = Layout.padding(with: sizeType)
        let w = bounds.width - padding * 2, h = Layout.height(with: sizeType)
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
}
extension KeyframeTimingView: Queryable {
    static var referenceableType: Referenceable.Type {
        return Model.self
    }
}
extension KeyframeTimingView: Assignable {
    func reset(for p: Point, _ version: Version) {
        push(defaultModel, to: version)
    }
    func copiedObjects(at p: Point) -> [Object] {
        return [Object(model)]
    }
    func paste(_ objects: [Any], for p: Point, _ version: Version) {
        for object in objects {
            if let keyframe = object as? Model {
                push(keyframe, to: version)
                return
            }
        }
    }
}
