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

struct Keyframe: Codable {
    enum Interpolation: Int8, Codable {
        case spline, bound, linear, step
        var displayString: Localization {
            switch self {
            case .spline:
                return Localization(english: "Interpolation: Spline", japanese: "補間: スプライン")
            case .bound:
                return Localization(english: "Interpolation: Bound", japanese: "補間: バウンド")
            case .linear:
                return Localization(english: "Interpolation: Linear", japanese: "補間: リニア")
            case .step:
                return Localization(english: "Interpolation: Step", japanese: "補間: ステップ")
            }
        }
        static var displayStrings: [Localization] {
            return [spline.displayString,
                    bound.displayString,
                    linear.displayString,
                    step.displayString]
        }
    }
    enum Loop: Int8, Codable {
        case none, began, ended
        var displayString: Localization {
            switch self {
            case .none:
                return Localization(english: "Loop: None", japanese: "ループ: なし")
            case .began:
                return Localization(english: "Loop: Began", japanese: "ループ: 開始")
            case .ended:
                return Localization(english: "Loop: Ended", japanese: "ループ: 終了")
            }
        }
        static var displayStrings: [Localization] {
            return [none.displayString,
                    began.displayString,
                    ended.displayString]
        }
    }
    enum Label: Int8, Codable {
        case main, sub
        var displayString: Localization {
            switch self {
            case .main:
                return Localization(english: "Label: Main", japanese: "ラベル: メイン")
            case .sub:
                return Localization(english: "Label: Sub", japanese: "ラベル: サブ")
            }
        }
        static var displayStrings: [Localization] {
            return [main.displayString,
                    sub.displayString]
        }
    }
    
    var time = Beat(0)
    var easing = Easing()
    var interpolation = Interpolation.spline, loop = Loop.none, label = Label.main
    
    func with(time: Beat) -> Keyframe {
        return Keyframe(time: time, easing: easing,
                        interpolation: interpolation, loop: loop, label: label)
    }
    func with(_ easing: Easing) -> Keyframe {
        return Keyframe(time: time, easing: easing,
                        interpolation: interpolation, loop: loop, label: label)
    }
    func with(_ interpolation: Interpolation) -> Keyframe {
        return Keyframe(time: time, easing: easing,
                        interpolation: interpolation, loop: loop, label: label)
    }
    func with(_ loop: Loop) -> Keyframe {
        return Keyframe(time: time, easing: easing,
                        interpolation: interpolation, loop: loop, label: label)
    }
    func with(_ label: Label) -> Keyframe {
        return Keyframe(time: time, easing: easing,
                        interpolation: interpolation, loop: loop, label: label)
    }
    
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
extension Keyframe: Equatable {
    static func ==(lhs: Keyframe, rhs: Keyframe) -> Bool {
        return lhs.time == rhs.time
            && lhs.easing == rhs.easing && lhs.interpolation == rhs.interpolation
            && lhs.loop == rhs.loop && lhs.label == rhs.label
    }
}
extension Keyframe: Referenceable {
    static let name = Localization(english: "Keyframe", japanese: "キーフレーム")
}
extension Keyframe.Interpolation: Referenceable {
    static let mainName = Localization(english: "Interpolation", japanese: "補間")
    static let name = Keyframe.name.spacedUnion(mainName)
    static let classDescription = Localization(english: "\"Bound\": Uses \"Spline\" without interpolation on previous, Not previous and next: Use \"Linear\"",
                                               japanese: "バウンド: 前方側の補間をしないスプライン補間, 前後が足りない場合: リニア補間を使用")
}
extension Keyframe.Loop: Referenceable {
    static let mainName = Localization(english: "Loop", japanese: "ループ")
    static let name = Keyframe.name.spacedUnion(mainName)
    static let classDescription = Localization(english: "Loop from \"Began Loop\" keyframe to \"Ended Loop\" keyframe on \"Ended Loop\" keyframe",
                                               japanese: "「ループ開始」キーフレームから「ループ終了」キーフレームの間を「ループ終了」キーフレーム上でループ")
}
extension Keyframe.Label: Referenceable {
    static let mainName = Localization(english: "Label", japanese: "ラベル")
    static let name = Keyframe.name.spacedUnion(mainName)
}

final class KeyframeView: View {
    var keyframe = Keyframe() {
        didSet {
            if !keyframe.equalOption(other: oldValue) {
                updateWithKeyframeOption()
            }
        }
    }
    
    var isSmall: Bool
    let classNameLabel: Label
    let easingView: EasingView
    let interpolationView: EnumView<Keyframe.Interpolation>
    let loopView: EnumView<Keyframe.Loop>
    let labelView: EnumView<Keyframe.Label>
    
    init(isSmall: Bool = false) {
        classNameLabel = Label(text: Keyframe.name, font: isSmall ? .smallBold : .bold)
        easingView = EasingView(isSmall: isSmall)
        interpolationView = EnumView(enumeratedType: .spline,
                                     indexHandler: { Int($0) },
                                     rawValueHandler: { Keyframe.Interpolation.RawValue($0) },
                                     names: Keyframe.Interpolation.displayStrings,
                                     isSmall: isSmall)
        loopView = EnumView(enumeratedType: .none,
                            indexHandler: { Int($0) },
                            rawValueHandler: { Keyframe.Loop.RawValue($0) },
                            names: Keyframe.Loop.displayStrings,
                            isSmall: isSmall)
        labelView = EnumView(enumeratedType: .main,
                             indexHandler: { Int($0) },
                             rawValueHandler: { Keyframe.Label.RawValue($0) },
                             names: Keyframe.Label.displayStrings,
                             isSmall: isSmall)
        self.isSmall = isSmall
        super.init()
        replace(children: [classNameLabel, easingView, interpolationView, loopView, labelView])
        interpolationView.binding = { [unowned self] in self.setKeyframe(with: $0) }
        loopView.binding = { [unowned self] in self.setKeyframe(with: $0) }
        labelView.binding = { [unowned self] in self.setKeyframe(with: $0) }
        easingView.binding = { [unowned self] in self.setKeyframe(with: $0) }
    }
    
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    private func updateLayout() {
        let padding = isSmall ? Layout.smallPadding : Layout.basicPadding
        let w = bounds.width - padding * 2, h = isSmall ? Layout.smallHeight : Layout.basicHeight
        var y = bounds.height - classNameLabel.frame.height - padding
        classNameLabel.frame.origin = CGPoint(x: padding, y: y)
        y -= h + padding
        interpolationView.frame = CGRect(x: padding, y: y, width: w, height: h)
        y -= h
        loopView.frame = CGRect(x: padding, y: y, width: w, height: h)
        y -= h
        labelView.frame = CGRect(x: padding, y: y, width: w, height: h)
        easingView.frame = CGRect(x: padding, y: padding,
                                    width: w, height: y - padding)
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
        let keyframe: Keyframe, oldKeyframe: Keyframe, type: Action.SendType
    }
    var binding: ((Binding) -> ())?
    
    private var oldKeyframe = Keyframe()
    
    private func setKeyframe<T: EnumType>(with binding: EnumView<T>.Binding) {
        if binding.type == .begin {
            oldKeyframe = keyframe
            self.binding?(Binding(view: self,
                                  keyframe: oldKeyframe, oldKeyframe: oldKeyframe, type: .begin))
        } else {
            if let interpolation = binding.enumeratedType as? Keyframe.Interpolation {
                keyframe.interpolation = interpolation
            } else if let loop = binding.enumeratedType as? Keyframe.Loop {
                keyframe.loop = loop
            } else if let label = binding.enumeratedType as? Keyframe.Label {
                keyframe.label = label
            }
            self.binding?(Binding(view: self,
                                  keyframe: keyframe, oldKeyframe: oldKeyframe, type: binding.type))
        }
    }
    private func setKeyframe(with binding: EasingView.Binding) {
        if binding.type == .begin {
            oldKeyframe = keyframe
            self.binding?(Binding(view: self,
                                  keyframe: oldKeyframe, oldKeyframe: oldKeyframe, type: .begin))
        } else {
            keyframe = keyframe.with(binding.easing)
            self.binding?(Binding(view: self,
                                  keyframe: keyframe, oldKeyframe: oldKeyframe, type: binding.type))
        }
    }
    
    func copiedObjects(with event: KeyInputEvent) -> [Any]? {
        return [keyframe]
    }
    func paste(_ objects: [Any], with event: KeyInputEvent) -> Bool {
        for object in objects {
            if let keyframe = object as? Keyframe {
                guard keyframe.equalOption(other: self.keyframe) else {
                    continue
                }
                set(keyframe, old: self.keyframe)
                return true
            }
        }
        return false
    }
    func delete(with event: KeyInputEvent) -> Bool {
        let keyframe: Keyframe = {
            var keyframe = Keyframe()
            keyframe.time = self.keyframe.time
            return keyframe
        } ()
        guard keyframe.equalOption(other: self.keyframe) else {
            return false
        }
        set(keyframe, old: self.keyframe)
        return true
    }
    
    private func set(_ keyframe: Keyframe, old oldKeyframe: Keyframe) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldKeyframe, old: keyframe) }
        binding?(Binding(view: self,
                         keyframe: oldKeyframe, oldKeyframe: oldKeyframe, type: .begin))
        self.keyframe = keyframe
        binding?(Binding(view: self,
                         keyframe: keyframe, oldKeyframe: oldKeyframe, type: .end))
    }
    
    func lookUp(with event: TapEvent) -> Reference? {
        return keyframe.reference
    }
}
