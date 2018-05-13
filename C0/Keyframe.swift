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

protocol Interpolatable {
    static var defaultInterpolation: KeyframeTiming.Interpolation { get }
    static func step(_ f0: Self) -> Self
    static func linear(_ f0: Self, _ f1: Self, t: Real) -> Self
    static func firstMonospline(_ f1: Self, _ f2: Self, _ f3: Self, with ms: Monospline) -> Self
    static func monospline(_ f0: Self, _ f1: Self, _ f2: Self, _ f3: Self, with ms: Monospline) -> Self
    static func lastMonospline(_ f0: Self, _ f1: Self, _ f2: Self, with ms: Monospline) -> Self
}
extension Interpolatable {
    static var defaultInterpolation: KeyframeTiming.Interpolation {
        return .spline
    }
    static func step (_ f0: Self) -> Self {
        return f0
    }
}
extension Array: Interpolatable where Element: Interpolatable {
    static func linear(_ f0: [Element], _ f1: [Element], t: Real) -> [Element] {
        guard !f0.isEmpty else {
            return f0
        }
        return f0.enumerated().map { i, e0 in
            guard i < f1.count else {
                return e0
            }
            let e1 = f1[i]
            return Element.linear(e0, e1, t: t)
        }
    }
    static func firstMonospline(_ f1: [Element],
                                _ f2: [Element], _ f3: [Element], with ms: Monospline) -> [Element] {
        guard !f1.isEmpty else {
            return f1
        }
        return f1.enumerated().map { i, e1 in
            guard i < f2.count else {
                return e1
            }
            let e2 = f2[i]
            let e3 = i >= f3.count ? e2 : f3[i]
            return Element.firstMonospline(e1, e2, e3, with: ms)
        }
    }
    static func monospline(_ f0: [Element], _ f1: [Element],
                           _ f2: [Element], _ f3: [Element], with ms: Monospline) -> [Element] {
        guard !f1.isEmpty else {
            return f1
        }
        return f1.enumerated().map { i, e1 in
            guard i < f2.count else {
                return e1
            }
            let e0 = i >= f0.count ? e1 : f0[i]
            let e2 = f2[i]
            let e3 = i >= f3.count ? e2 : f3[i]
            return Element.monospline(e0, e1, e2, e3, with: ms)
        }
    }
    static func lastMonospline(_ f0: [Element],
                               _ f1: [Element], _ f2: [Element], with ms: Monospline) -> [Element] {
        guard !f1.isEmpty else {
            return f1
        }
        return f1.enumerated().map { i, e1 in
            guard i < f2.count else {
                return e1
            }
            let e0 = i >= f0.count ? e1 : f0[i]
            let e2 = f2[i]
            return Element.lastMonospline(e0, e1, e2, with: ms)
        }
    }
}

struct Monospline {
    let h0: Real, h1: Real, h2: Real
    let reciprocalH0: Real, reciprocalH1: Real, reciprocalH2: Real
    let reciprocalH0H1: Real, reciprocalH1H2: Real, reciprocalH1H1: Real
    private(set) var xx3: Real, xx2: Real, xx1: Real
    var t: Real {
        didSet {
            xx1 = h1 * t
            xx2 = xx1 * xx1
            xx3 = xx1 * xx1 * xx1
        }
    }
    init(x1: Real, x2: Real, x3: Real, t: Real) {
        h0 = 0
        h1 = x2 - x1
        h2 = x3 - x2
        reciprocalH0 = 0
        reciprocalH1 = 1 / h1
        reciprocalH2 = 1 / h2
        reciprocalH0H1 = 0
        reciprocalH1H2 = 1 / (h1 + h2)
        reciprocalH1H1 = 1 / (h1 * h1)
        xx1 = h1 * t
        xx2 = xx1 * xx1
        xx3 = xx1 * xx1 * xx1
        self.t = t
    }
    init(x0: Real, x1: Real, x2: Real, x3: Real, t: Real) {
        h0 = x1 - x0
        h1 = x2 - x1
        h2 = x3 - x2
        reciprocalH0 = 1 / h0
        reciprocalH1 = 1 / h1
        reciprocalH2 = 1 / h2
        reciprocalH0H1 = 1 / (h0 + h1)
        reciprocalH1H2 = 1 / (h1 + h2)
        reciprocalH1H1 = 1 / (h1 * h1)
        xx1 = h1 * t
        xx2 = xx1 * xx1
        xx3 = xx1 * xx1 * xx1
        self.t = t
    }
    init(x0: Real, x1: Real, x2: Real, t: Real) {
        h0 = x1 - x0
        h1 = x2 - x1
        h2 = 0
        reciprocalH0 = 1 / h0
        reciprocalH1 = 1 / h1
        reciprocalH2 = 0
        reciprocalH0H1 = 1 / (h0 + h1)
        reciprocalH1H2 = 0
        reciprocalH1H1 = 1 / (h1 * h1)
        xx1 = h1 * t
        xx2 = xx1 * xx1
        xx3 = xx1 * xx1 * xx1
        self.t = t
    }
    
    func firstInterpolatedValue(_ f1: Real, _ f2: Real, _ f3: Real) -> Real {
        let s1 = (f2 - f1) * reciprocalH1, s2 = (f3 - f2) * reciprocalH2
        let signS1: Real = s1 > 0 ? 1 : -1, signS2: Real = s2 > 0 ? 1 : -1
        let yPrime1 = s1
        let yPrime2 = (signS1 + signS2) * min(abs(s1),
                                              abs(s2),
                                              0.5 * abs((h2 * s1 + h1 * s2) * reciprocalH1H2))
        return interpolatedValue(f1: f1, s1: s1, yPrime1: yPrime1, yPrime2: yPrime2)
    }
    func interpolatedValue(_ f0: Real, _ f1: Real, _ f2: Real, _ f3: Real) -> Real {
        let s0 = (f1 - f0) * reciprocalH0
        let s1 = (f2 - f1) * reciprocalH1, s2 = (f3 - f2) * reciprocalH2
        let signS0: Real = s0 > 0 ? 1 : -1
        let signS1: Real = s1 > 0 ? 1 : -1, signS2: Real = s2 > 0 ? 1 : -1
        let yPrime1 = (signS0 + signS1) * min(abs(s0),
                                              abs(s1),
                                              0.5 * abs((h1 * s0 + h0 * s1) * reciprocalH0H1))
        let yPrime2 = (signS1 + signS2) * min(abs(s1),
                                              abs(s2),
                                              0.5 * abs((h2 * s1 + h1 * s2) * reciprocalH1H2))
        return interpolatedValue(f1: f1, s1: s1, yPrime1: yPrime1, yPrime2: yPrime2)
    }
    func lastInterpolatedValue(_ f0: Real, _ f1: Real, _ f2: Real) -> Real {
        let s0 = (f1 - f0) * reciprocalH0, s1 = (f2 - f1) * reciprocalH1
        let signS0: Real = s0 > 0 ? 1 : -1, signS1: Real = s1 > 0 ? 1 : -1
        let yPrime1 = (signS0 + signS1) * min(abs(s0),
                                              abs(s1),
                                              0.5 * abs((h1 * s0 + h0 * s1) * reciprocalH0H1))
        let yPrime2 = s1
        return interpolatedValue(f1: f1, s1: s1, yPrime1: yPrime1, yPrime2: yPrime2)
    }
    private func interpolatedValue(f1: Real, s1: Real,
                                   yPrime1: Real, yPrime2: Real) -> Real {
        let a = (yPrime1 + yPrime2 - 2 * s1) * reciprocalH1H1
        let b = (3 * s1 - 2 * yPrime1 - yPrime2) * reciprocalH1, c = yPrime1, d = f1
        return a * xx3 + b * xx2 + c * xx1 + d
    }
    
    func integralFirstInterpolatedValue(_ f1: Real, _ f2: Real, _ f3: Real,
                                        a: Real, b: Real) -> Real {
        let s1 = (f2 - f1) * reciprocalH1, s2 = (f3 - f2) * reciprocalH2
        let signS1: Real = s1 > 0 ? 1 : -1, signS2: Real = s2 > 0 ? 1 : -1
        let yPrime1 = s1
        let yPrime2 = (signS1 + signS2) * min(abs(s1),
                                              abs(s2),
                                              0.5 * abs((h2 * s1 + h1 * s2) * reciprocalH1H2))
        return integral(f1: f1, s1: s1, yPrime1: yPrime1, yPrime2: yPrime2, a: a, b: b)
    }
    func integralInterpolatedValue(_ f0: Real, _ f1: Real, _ f2: Real, _ f3: Real,
                                   a: Real, b: Real) -> Real {
        let s0 = (f1 - f0) * reciprocalH0
        let s1 = (f2 - f1) * reciprocalH1, s2 = (f3 - f2) * reciprocalH2
        let signS0: Real = s0 > 0 ? 1 : -1
        let signS1: Real = s1 > 0 ? 1 : -1, signS2: Real = s2 > 0 ? 1 : -1
        let yPrime1 = (signS0 + signS1) * min(abs(s0),
                                              abs(s1),
                                              0.5 * abs((h1 * s0 + h0 * s1) * reciprocalH0H1))
        let yPrime2 = (signS1 + signS2) * min(abs(s1),
                                              abs(s2),
                                              0.5 * abs((h2 * s1 + h1 * s2) * reciprocalH1H2))
        return integral(f1: f1, s1: s1, yPrime1: yPrime1, yPrime2: yPrime2, a: a, b: b)
    }
    func integralLastInterpolatedValue(_ f0: Real, _ f1: Real, _ f2: Real,
                                       a: Real, b: Real) -> Real {
        let s0 = (f1 - f0) * reciprocalH0, s1 = (f2 - f1) * reciprocalH1
        let signS0: Real = s0 > 0 ? 1 : -1, signS1: Real = s1 > 0 ? 1 : -1
        let yPrime1 = (signS0 + signS1) * min(abs(s0),
                                              abs(s1),
                                              0.5 * abs((h1 * s0 + h0 * s1) * reciprocalH0H1))
        let yPrime2 = s1
        return integral(f1: f1, s1: s1, yPrime1: yPrime1, yPrime2: yPrime2, a: a, b: b)
    }
    private func integral(f1: Real, s1: Real, yPrime1: Real, yPrime2: Real,
                          a xa: Real, b xb: Real) -> Real {
        let a = (yPrime1 + yPrime2 - 2 * s1) * reciprocalH1H1
        let b = (3 * s1 - 2 * yPrime1 - yPrime2) * reciprocalH1, c = yPrime1, nd = f1
        
        let xa2 = xa * xa, xb2 = xb * xb, h1_2 = h1 * h1
        let xa3 = xa2 * xa, xb3 = xb2 * xb, h1_3 = h2 * h1
        let xa4 = xa3 * xa, xb4 = xb3 * xb
        let na = a * h1_3 / 4, nb = b * h1_2 / 3, nc = c * h1 / 2
        let fa = na * xa4 + nb * xa3 + nc * xa2 + nd * xa
        let fb = nb * xb4 + nb * xb3 + nc * xb2 + nd * xb
        return fb - fa
    }
}

protocol KeyframeTimingProtocol {
    var timing: KeyframeTiming { get }
}
protocol KeyframeValue: Codable, Equatable, Interpolatable, Initializable, Referenceable {}
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
extension Keyframe: MiniViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return timing.interpolation.displayText.thumbnailView(withBounds: bounds, sizeType)
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
extension KeyframeTiming: MiniViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return interpolation.displayText.thumbnailView(withBounds: bounds, sizeType)
    }
}
extension KeyframeTiming.Interpolation: Referenceable {
    static let uninheritanceName = Text(english: "Interpolation", japanese: "補間")
    static let name = KeyframeTiming.name.spacedUnion(uninheritanceName)
    static let classDescription = Text(english: "\"Bound\": Uses \"Spline\" without interpolation on previous, Not previous and next: Use \"Linear\"",
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
    static let classDescription = Text(english: "Loop from \"Began Loop\" keyframe to \"Ended Loop\" keyframe on \"Ended Loop\" keyframe",
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

final class KeyframeView<Value: KeyframeValue>: View {
    var keyframe = Keyframe<Value>() {
        didSet {
            if keyframe.timing != oldValue.timing {
                updateWithKeyframeOption()
            }
        }
    }
}

final class KeyframeTimingView: View {
    var keyframeTiming = KeyframeTiming() {
        didSet {
            if keyframeTiming != oldValue {
                updateWithKeyframeTiming()
            }
        }
    }
    
    let labelView: EnumView<KeyframeTiming.Label>
    let loopView: EnumView<KeyframeTiming.Loop>
    let interpolationView: EnumView<KeyframeTiming.Interpolation>
    let easingView: EasingView
    
    var sizeType: SizeType
    let classNameView: TextFormView
    
    init(sizeType: SizeType = .regular) {
        classNameView = TextView(text: Keyframe<Value>.name, font: Font.bold(with: sizeType))
        easingView = EasingView(sizeType: sizeType)
        interpolationView = EnumView(enumeratedType: .spline,
                                     indexClosure: { Int($0) },
                                     rawValueClosure: { KeyframeTiming.Interpolation.RawValue($0) },
                                     names: KeyframeTiming.Interpolation.displayTexts,
                                     sizeType: sizeType)
        loopView = EnumView(enumeratedType: .none,
                            indexClosure: { Int($0) },
                            rawValueClosure: { KeyframeTiming.Loop.RawValue($0) },
                            names: KeyframeTiming.Loop.displayTexts,
                            sizeType: sizeType)
        labelView = EnumView(enumeratedType: .main,
                             indexClosure: { Int($0) },
                             rawValueClosure: { KeyframeTiming.Label.RawValue($0) },
                             names: KeyframeTiming.Label.displayTexts,
                             sizeType: sizeType)
        self.sizeType = sizeType
        
        super.init()
//        children = [classNameView, easingView, interpolationView, loopView, labelView]
//        interpolationView.binding = { [unowned self] in self.setKeyframe(with: $0) }
//        loopView.binding = { [unowned self] in self.setKeyframe(with: $0) }
//        labelView.binding = { [unowned self] in self.setKeyframe(with: $0) }
//        easingView.binding = { [unowned self] in self.setKeyframe(with: $0) }
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
    private func updateWithKeyframeTiming() {
        labelView.enumeratedType = keyframeTiming.label
        loopView.enumeratedType = keyframeTiming.loop
        interpolationView.enumeratedType = keyframe.timing.interpolation
        easingView.easing = keyframe.timing.easing
    }
    
    private func push(_ keyframe: Keyframe<Value>, old oldKeyframe: Keyframe<Value>) {
//        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldKeyframe, old: keyframe) }
        self.keyframe = keyframe
    }
}
extension KeyframeView: Queryable {
    static var referenceableType: Referenceable.Type {
        return Keyframe<Value>.self
    }
}
extension KeyframeView: Assignable {
    func delete(for p: Point) {
        let keyframe: Keyframe<Value> = {
            var keyframe = Keyframe<Value>()
            keyframe.timing.time = self.keyframe.timing.time
            return keyframe
        } ()
        push(keyframe, old: self.keyframe)
    }
    func copiedObjects(at p: Point) -> [Viewable] {
        return [keyframe]
    }
    func paste(_ objects: [Object], for p: Point) {
        for object in objects {
            if let keyframe = object as? Keyframe<Value> {
                push(keyframe, old: self.keyframe)
                return
            }
        }
    }
}
