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

struct Keyframe: Codable, Equatable, Hashable {
    enum Interpolation: Int8, Codable {
        case spline, bound, linear, step
        var displayText: Text {
            switch self {
            case .spline:
                return Text(english: "Spline", japanese: "スプライン")
            case .bound:
                return Text(english: "Bound", japanese: "バウンド")
            case .linear:
                return Text(english: "Linear", japanese: "リニア")
            case .step:
                return Text(english: "Step", japanese: "ステップ")
            }
        }
        static var displayTexts: [Text] {
            return [spline.displayText,
                    bound.displayText,
                    linear.displayText,
                    step.displayText]
        }
    }
    enum Loop: Int8, Codable {
        case none, began, ended
        var displayText: Text {
            switch self {
            case .none:
                return Text(english: "None", japanese: "なし")
            case .began:
                return Text(english: "Began", japanese: "開始")
            case .ended:
                return Text(english: "Ended", japanese: "終了")
            }
        }
        static var displayTexts: [Text] {
            return [none.displayText,
                    began.displayText,
                    ended.displayText]
        }
    }
    enum Label: Int8, Codable {
        case main, sub
        var displayText: Text {
            switch self {
            case .main:
                return Text(english: "Main", japanese: "メイン")
            case .sub:
                return Text(english: "Sub", japanese: "サブ")
            }
        }
        static var displayTexts: [Text] {
            return [main.displayText,
                    sub.displayText]
        }
    }
    
    var time = Beat(0)
    var easing = Easing()
    var interpolation = Interpolation.spline, loop = Loop.none, label = Label.main
    
    static func index(time t: Beat,
                      with keyframes: [Keyframe]) -> (index: Int, interTime: Beat, duration: Beat) {
        var oldT = Beat(0)
        for i in (0 ..< keyframes.count).reversed() {
            let keyframe = keyframes[i]
            if t >= keyframe.time {
                return (i, t - keyframe.time, oldT - keyframe.time)
            }
            oldT = keyframe.time
        }
        return (0, t - keyframes.first!.time, oldT - keyframes.first!.time)
    }
    func equalOption(other: Keyframe) -> Bool {
        return easing == other.easing && interpolation == other.interpolation
            && loop == other.loop && label == other.label
    }
}
extension Keyframe: Referenceable {
    static let name = Text(english: "Keyframe", japanese: "キーフレーム")
}
extension Keyframe: ObjectViewExpression {
    func thumbnail(withBounds bounds: Rect, _ sizeType: SizeType) -> View {
        return interpolation.displayText.thumbnail(withBounds: bounds, sizeType)
    }
}
extension Keyframe.Interpolation: Referenceable {
    static let uninheritanceName = Text(english: "Interpolation", japanese: "補間")
    static let name = Keyframe.name.spacedUnion(uninheritanceName)
    static let classDescription = Text(english: "\"Bound\": Uses \"Spline\" without interpolation on previous, Not previous and next: Use \"Linear\"",
                                               japanese: "バウンド: 前方側の補間をしないスプライン補間, 前後が足りない場合: リニア補間を使用")
}
extension Keyframe.Interpolation: ObjectViewExpressionWithDisplayText {
}
extension Keyframe.Loop: Referenceable {
    static let uninheritanceName = Text(english: "Loop", japanese: "ループ")
    static let name = Keyframe.name.spacedUnion(uninheritanceName)
    static let classDescription = Text(english: "Loop from \"Began Loop\" keyframe to \"Ended Loop\" keyframe on \"Ended Loop\" keyframe",
                                               japanese: "「ループ開始」キーフレームから「ループ終了」キーフレームの間を「ループ終了」キーフレーム上でループ")
}
extension Keyframe.Loop: ObjectViewExpressionWithDisplayText {
}
extension Keyframe.Label: Referenceable {
    static let uninheritanceName = Text(english: "Label", japanese: "ラベル")
    static let name = Keyframe.name.spacedUnion(uninheritanceName)
}
extension Keyframe.Label: ObjectViewExpressionWithDisplayText {
}

final class KeyframeView: View, Queryable, Assignable {
    var keyframe = Keyframe() {
        didSet {
            if !keyframe.equalOption(other: oldValue) {
                updateWithKeyframeOption()
            }
        }
    }
    
    var sizeType: SizeType
    let classNameView: TextView
    let easingView: EasingView
    let interpolationView: EnumView<Keyframe.Interpolation>
    let loopView: EnumView<Keyframe.Loop>
    let labelView: EnumView<Keyframe.Label>
    
    init(sizeType: SizeType = .regular) {
        classNameView = TextView(text: Keyframe.name, font: Font.bold(with: sizeType))
        easingView = EasingView(sizeType: sizeType)
        interpolationView = EnumView(enumeratedType: .spline,
                                     indexClosure: { Int($0) },
                                     rawValueClosure: { Keyframe.Interpolation.RawValue($0) },
                                     names: Keyframe.Interpolation.displayTexts,
                                     sizeType: sizeType)
        loopView = EnumView(enumeratedType: .none,
                            indexClosure: { Int($0) },
                            rawValueClosure: { Keyframe.Loop.RawValue($0) },
                            names: Keyframe.Loop.displayTexts,
                            sizeType: sizeType)
        labelView = EnumView(enumeratedType: .main,
                             indexClosure: { Int($0) },
                             rawValueClosure: { Keyframe.Label.RawValue($0) },
                             names: Keyframe.Label.displayTexts,
                             sizeType: sizeType)
        self.sizeType = sizeType
        super.init()
        children = [classNameView, easingView, interpolationView, loopView, labelView]
        interpolationView.binding = { [unowned self] in self.setKeyframe(with: $0) }
        loopView.binding = { [unowned self] in self.setKeyframe(with: $0) }
        labelView.binding = { [unowned self] in self.setKeyframe(with: $0) }
        easingView.binding = { [unowned self] in self.setKeyframe(with: $0) }
    }
    
    override var bounds: Rect {
        didSet {
            updateLayout()
        }
    }
    private func updateLayout() {
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
    private func updateWithKeyframeOption() {
        labelView.enumeratedType = keyframe.label
        loopView.enumeratedType = keyframe.loop
        interpolationView.enumeratedType = keyframe.interpolation
        easingView.easing = keyframe.easing
    }
    
    var disabledRegisterUndo = false
    
    struct Binding {
        let view: KeyframeView
        let keyframe: Keyframe, oldKeyframe: Keyframe, phase: Phase
    }
    var binding: ((Binding) -> ())?
    
    private var oldKeyframe = Keyframe()
    
    private func setKeyframe<T: EnumType>(with binding: EnumView<T>.Binding) {
        if binding.phase == .began {
            oldKeyframe = keyframe
            self.binding?(Binding(view: self,
                                  keyframe: oldKeyframe, oldKeyframe: oldKeyframe, phase: .began))
        } else {
            if let interpolation = binding.enumeratedType as? Keyframe.Interpolation {
                keyframe.interpolation = interpolation
            } else if let loop = binding.enumeratedType as? Keyframe.Loop {
                keyframe.loop = loop
            } else if let label = binding.enumeratedType as? Keyframe.Label {
                keyframe.label = label
            }
            self.binding?(Binding(view: self,
                                  keyframe: keyframe, oldKeyframe: oldKeyframe, phase: binding.phase))
        }
    }
    private func setKeyframe(with binding: EasingView.Binding) {
        if binding.phase == .began {
            oldKeyframe = keyframe
            self.binding?(Binding(view: self,
                                  keyframe: oldKeyframe, oldKeyframe: oldKeyframe, phase: .began))
        } else {
            keyframe.easing = binding.easing
            self.binding?(Binding(view: self,
                                  keyframe: keyframe, oldKeyframe: oldKeyframe, phase: binding.phase))
        }
    }
    
    func delete(for p: Point) {
        let keyframe: Keyframe = {
            var keyframe = Keyframe()
            keyframe.time = self.keyframe.time
            return keyframe
        } ()
        guard keyframe.equalOption(other: self.keyframe) else {
            return
        }
        set(keyframe, old: self.keyframe)
    }
    func copiedViewables(at p: Point) -> [Viewable] {
        return [keyframe]
    }
    func paste(_ objects: [Any], for p: Point) {
        for object in objects {
            if let keyframe = object as? Keyframe {
                if keyframe.equalOption(other: self.keyframe) {
                    set(keyframe, old: self.keyframe)
                    return
                }
            }
        }
    }
    
    private func set(_ keyframe: Keyframe, old oldKeyframe: Keyframe) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldKeyframe, old: keyframe) }
        binding?(Binding(view: self,
                         keyframe: oldKeyframe, oldKeyframe: oldKeyframe, phase: .began))
        self.keyframe = keyframe
        binding?(Binding(view: self,
                         keyframe: keyframe, oldKeyframe: oldKeyframe, phase: .ended))
    }
    
    func reference(at p: Point) -> Reference {
        return Keyframe.reference
    }
}
