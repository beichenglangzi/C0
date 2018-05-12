/*
 Copyright 2017 S
 
 This file is part of C0.
 
 C0 is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your timing) any later version.
 
 C0 is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with C0.  If not, see <http://www.gnu.org/licenses/>.
 */

import Foundation

protocol Animatable {
    var keyframeTimings: KeyframeTimingCollection { get }
    var beginTime: Rational { get }
    var duration: Rational { get }
}

struct LoopFrame: Codable, Hashable {
    var index: Int, time: Rational, loopCount: Int, loopingCount: Int
}

struct Animation<Value: KeyframeValue>: Codable, Animatable {
    enum ChangedValue {
        enum KeyframeItem {
            case insert(Int)
            case remove(Int)
            case move(Int, Rational)
        }
        case keyframes(KeyframeItem)
    }
    private var _keyframes: [Keyframe<Value>]
    private var _duration: Rational
    var keyframes: [Keyframe<Value>] {
        get {
            return _keyframes
        }
        set {
            _keyframes = newValue
            self.loopFrames = Animation.loopFrames(with: keyframes, duration: duration)
        }
    }
    var beginTime: Rational
    var duration: Rational {
        get {
            return _duration
        }
        set {
            _duration = newValue
            self.loopFrames = Animation.loopFrames(with: keyframes, duration: duration)
        }
    }
    mutating func set(_ keyframes: [Keyframe<Value>], duration: Rational) {
        _keyframes = keyframes
        _duration = duration
        self.loopFrames = Animation.loopFrames(with: keyframes, duration: duration)
    }
    
    private(set) var loopFrames: [LoopFrame]
    
    mutating func fit(repeating: Value, with keyframeTimings: [KeyframeTiming]) {
        if keyframeTimings.count < keyframes.count {
            keyframes = Array(keyframes[..<keyframeTimings.count])
        } else if keyframeTimings.count > keyframes.count {
            keyframes += keyframeTimings[(keyframes.count - 1)...].map {
                Keyframe(value: repeating, timing: $0)
            }
        }
    }

    var selectedKeyframeIndexes: [Int]

    init(keyframes: [Keyframe<Value>] = [], beginTime: Rational = 0, duration: Rational = 1,
         selectedKeyframeIndexes: [Int] = []) {
        
        _keyframes = keyframes
        self.beginTime = beginTime
        _duration = duration
        self.loopFrames = Animation.loopFrames(with: keyframes, duration: duration)
        self.selectedKeyframeIndexes = selectedKeyframeIndexes
    }
    
    init(repeating: Value, keyframeTimings: [KeyframeTiming]) {
        self.init(keyframes: keyframeTimings.map { Keyframe(value: repeating, timing: $0) })
    }
    
    var isEmpty: Bool {
        return keyframes.isEmpty
    }
    
    var keyframeTimings: KeyframeTimingCollection {
        return KeyframeTimingCollection(keyframes: keyframes)
    }
    
    private static func loopFrames(with keyframes: [Keyframe<Value>],
                                   duration: Rational) -> [LoopFrame] {
        var loopFrames = [LoopFrame](), previousIndexes = [Int]()
        func appendLoopFrameWith(time: Rational, nextTime: Rational,
                                 previousIndex: Int, currentIndex: Int, loopCount: Int) {
            var t = time
            while t <= nextTime {
                for i in previousIndex..<currentIndex {
                    let nk = loopFrames[i]
                    loopFrames.append(LoopFrame(index: nk.index, time: t,
                                                loopCount: loopCount,
                                                loopingCount: loopCount))
                    t += loopFrames[i + 1].time - nk.time
                    if t > nextTime {
                        if currentIndex == keyframes.count - 1 {
                            loopFrames.append(LoopFrame(index: loopFrames[i + 1].index,
                                                        time: t, loopCount: loopCount,
                                                        loopingCount: loopCount))
                        }
                        return
                    }
                }
            }
        }
        for (i, keyframe) in keyframes.enumerated() {
            if keyframe.timing.loop == .ended, let previousIndex = previousIndexes.last {
                let loopCount = previousIndexes.count
                previousIndexes.removeLast()
                let time = keyframe.timing.time
                let nextTime = i + 1 >= keyframes.count ? duration : keyframes[i + 1].timing.time
                appendLoopFrameWith(time: time, nextTime: nextTime,
                                    previousIndex: previousIndex, currentIndex: i,
                                    loopCount: loopCount)
            } else {
                let loopCount = keyframe.timing.loop == .began ?
                    previousIndexes.count + 1 : previousIndexes.count
                loopFrames.append(LoopFrame(index: i, time: keyframe.timing.time,
                                            loopCount: loopCount,
                                            loopingCount: max(0, loopCount - 1)))
            }
            if keyframe.timing.loop == .began {
                previousIndexes.append(loopFrames.count - 1)
            }
        }
        return loopFrames
    }
    
    struct TimeInfo {
        var time: Rational
        var isInterpolated: Bool
        var loopframeIndex: Int, keyframeIndex: Int
        var internalRatio: Real
    }
    
    func timeInfo(atTime time: Rational) -> TimeInfo? {
        guard let indexInfo = self.indexInfo(atTime: time) else {
            return nil
        }
        let li1 = indexInfo.loopFrameIndex, internalTime = indexInfo.keyframeInternalTime
        let lf1 = loopFrames[li1]
        let k1 = keyframes[lf1.index]
        if internalTime == 0 || indexInfo.keyframeDuration == 0
            || li1 + 1 >= loopFrames.count || k1.timing.interpolation == .none {
            
            return TimeInfo(time: time,
                            isInterpolated: false,
                            loopframeIndex: li1, keyframeIndex: lf1.index,
                            internalRatio: 0)
        } else {
            let lf2 = loopFrames[li1 + 1]
            return TimeInfo(time: time,
                            isInterpolated: lf1.time != lf2.time,
                            loopframeIndex: li1, keyframeIndex: lf1.index,
                            internalRatio: Real(internalTime / indexInfo.keyframeDuration))
        }
    }
    
    func interpolatedValue(atTime time: Rational) -> Value? {
        if let timeInfo = self.timeInfo(atTime: time) {
            return interpolatedValue(with: timeInfo)
        } else {
            return nil
        }
    }
    func interpolatedValue(with timeInfo: TimeInfo) -> Value {
        func value(_ lf: LoopFrame) -> Value {
            return keyframes[lf.index].value
        }
        let li1 = timeInfo.loopframeIndex
        let lf1 = loopFrames[li1]
        guard timeInfo.isInterpolated else {
            return Value.step(value(lf1))
        }
        let k1 = keyframes[lf1.index]
        let lf2 = loopFrames[li1 + 1]
        
        let t = k1.timing.easing.convertT(timeInfo.internalRatio)
        guard k1.timing.interpolation != .linear && keyframes.count > 2 else {
            return Value.linear(value(lf1), value(lf2), t: t)
        }
        let isUseIndex0 = li1 - 1 >= 0
            && k1.timing.interpolation != .bound
            && loopFrames[li1 - 1].time != lf1.time
        let isUseIndex3 = li1 + 2 < loopFrames.count
            && keyframes[lf2.index].timing.interpolation != .bound
            && loopFrames[li1 + 2].time != lf2.time
        if isUseIndex0 {
            if isUseIndex3 {
                let lf0 = loopFrames[li1 - 1], lf3 = loopFrames[li1 + 2]
                let ms = Monospline(x0: Real(lf0.time), x1: Real(lf1.time),
                                    x2: Real(lf2.time), x3: Real(lf3.time), t: t)
                return Value.monospline(value(lf0), value(lf1), value(lf2), value(lf3), with: ms)
            } else {
                let lf0 = loopFrames[li1 - 1]
                let ms = Monospline(x0: Real(lf0.time), x1: Real(lf1.time),
                                    x2: Real(lf2.time), t: t)
                return Value.lastMonospline(value(lf0), value(lf1), value(lf2), with: ms)
            }
        } else if isUseIndex3 {
            let lf3 = loopFrames[li1 + 2]
            let ms = Monospline(x1: Real(lf1.time),
                                x2: Real(lf2.time), x3: Real(lf3.time), t: t)
            return Value.firstMonospline(value(lf1), value(lf2), value(lf3), with: ms)
        } else {
            return Value.linear(value(lf1), value(lf2), t: t)
        }
    }
    
    func interpolation(at li: Int,
                       step: ((LoopFrame) -> ()),
                       linear: ((LoopFrame, LoopFrame) -> ()),
                       monospline: ((LoopFrame, LoopFrame, LoopFrame, LoopFrame) -> ()),
                       firstMonospline: ((LoopFrame, LoopFrame, LoopFrame) -> ()),
                       endMonospline: ((LoopFrame, LoopFrame, LoopFrame) -> ())) {
        let lf1 = loopFrames[li], lf2 = loopFrames[li + 1]
        let k1 = keyframes[lf1.index], k2 = keyframes[lf2.index]
        if k1.timing.interpolation == .none || lf2.time - lf1.time == 0 {
            step(lf1)
        } else if k1.timing.interpolation == .linear {
            linear(lf1, lf2)
        } else {
            let isUseIndex0 = li - 1 >= 0
                && k2.timing.interpolation != .bound
                && loopFrames[li - 1].time != lf1.time
            let isUseIndex3 = li + 2 < loopFrames.count
                && k2.timing.interpolation != .bound
                && loopFrames[li + 2].time != lf2.time
            if isUseIndex0 {
                if isUseIndex3 {
                    let lf0 = loopFrames[li - 1], lf3 = loopFrames[li + 2]
                    monospline(lf0, lf1, lf2, lf3)
                } else {
                    let lf0 = loopFrames[li - 1]
                    endMonospline(lf0, lf1, lf2)
                }
            } else if isUseIndex3 {
                let lf3 = loopFrames[li + 2]
                firstMonospline(lf1, lf2, lf3)
            } else {
                linear(lf1, lf2)
            }
        }
    }
    
    struct IndexInfo {
        var loopFrameIndex: Int, keyframeIndex: Int
        var keyframeInternalTime: Rational, keyframeDuration: Rational
    }
    func indexInfo(atTime t: Rational) -> IndexInfo? {
        guard let firstLoopFrame = loopFrames.first else {
            return nil
        }
        var oldT = duration
        for i in (0..<loopFrames.count).reversed() {
            let li = loopFrames[i]
            let kt = li.time
            if t >= kt {
                return IndexInfo(loopFrameIndex: i, keyframeIndex: li.index,
                                 keyframeInternalTime: t - kt, keyframeDuration: oldT - kt)
            }
            oldT = kt
        }
        return IndexInfo(loopFrameIndex: 0, keyframeIndex: 0,
                         keyframeInternalTime: t - firstLoopFrame.time,
                         keyframeDuration: oldT - firstLoopFrame.time)
    }
    func keyframeIndexTuple(atTime time: Beat) -> (index: Int, interTime: Beat, isOver: Bool)? {
        guard !keyframes.isEmpty else {
            return nil
        }
        guard keyframes.count > 1 else {
            return (0, time, duration <= time)
        }
        let lfi = indexInfo(atTime: time)!
        return (lfi.keyframeIndex, lfi.keyframeInternalTime, duration <= time)
    }
    func movingKeyframeIndex(atTime time: Beat) -> Int? {
        guard !keyframes.isEmpty else {
            return nil
        }
        guard keyframes.count > 1 else {
            return 0
        }
        for i in 1..<keyframes.count {
            if time <= keyframes[i].timing.time {
                return i - 1
            }
        }
        return keyframes.count - 1
    }
    func time(atLoopFrameIndex index: Int) -> Beat {
        return loopFrames[index].time
    }
    func loopedKeyframeIndex(atTime t: Rational) -> Int? {
        return indexInfo(atTime: t)?.keyframeIndex
    }
    func keyframeIndex(atTime t: Rational) -> Int? {
        guard t < duration && !keyframes.isEmpty else {
            return nil
        }
        for i in (0..<keyframes.count).reversed() {
            if t >= keyframes[i].timing.time {
                return i
            }
        }
        return 0
    }
    func movingKeyframeIndex(atTime t: Rational) -> (index: Int?, isSolution: Bool) {
        if t > duration {
            return (nil, false)
        } else if t == duration {
            return (nil, true)
        } else {
            for i in (0..<keyframes.count).reversed() {
                let time = keyframes[i].timing.time
                if t == time {
                    return (i, true)
                } else if t > time {
                    return (i + 1, true)
                }
            }
            return (nil, false)
        }
    }
    var lastKeyframeTime: Rational? {
        return keyframes.last?.timing.time
    }
    var lastLoopedKeyframeTime: Rational? {
        guard !loopFrames.isEmpty else {
            return nil
        }
        let t = loopFrames[loopFrames.count - 1].time
        if t >= duration {
            return loopFrames.count >= 2 ? loopFrames[loopFrames.count - 2].time : 0
        } else {
            return t
        }
    }
}
extension Animation: Equatable {
    static func ==(lhs: Animation, rhs: Animation) -> Bool {
        return lhs.keyframes == rhs.keyframes
            && lhs.duration == rhs.duration
            && lhs.selectedKeyframeIndexes == rhs.selectedKeyframeIndexes
    }
}
extension Animation: Referenceable {
    static var name: Text {
        return Text(english: "Animation", japanese: "アニメーション") + "<" + Value.name + ">"
    }
}
extension Animation: CompactViewable {
    func thumbnail(withBounds bounds: Rect, _ sizeType: SizeType) -> View {
        let text = Text(english: "\(keyframes.count) Keyframes",
                        japanese: "\(keyframes.count)キーフレーム")
        return text.thumbnail(withBounds: bounds, sizeType)
    }
}

final class AnimationView<Value: KeyframeValue, T: BinderProtocol>:
View, Indicatable, Selectable, Assignable, Newable, Movable {
    var animation: Animation<Value>
    
    init(_ animation: Animation<T> = Animation<T>(),
         beginBaseTime: Rational = 0, baseTimeInterval: Rational = Rational(1, 16),
         origin: Point = Point(),
         height: Real = Layout.basicHeight, smallHeight: Real = 8.0,
         sizeType: SizeType = .small) {

        self.animation = animation
        self.beginBaseTime = beginBaseTime
        self.baseTimeInterval = baseTimeInterval
        self.height = height
        self.smallHeight = smallHeight
        self.sizeType = sizeType
        super.init()
        frame = Rect(x: origin.x, y: origin.y,
                     width: 0, height: sizeType == .small ? smallHeight : height)
        updateChildren()
    }

    private static func knobLinePathView(from p: Point, lineColor: Color,
                                         baseWidth: Real, lineHeight: Real,
                                         lineWidth: Real = 4, linearLineWidth: Real = 2,
                                         with interpolation: KeyframeOption.Interpolation) -> View {
        let path = CGMutablePath()
        switch interpolation {
        case .spline:
            break
        case .bound:
            path.addRect(Rect(x: p.x - linearLineWidth / 2, y: p.y - lineHeight / 2,
                              width: linearLineWidth, height: lineHeight / 2))
        case .linear:
            path.addRect(Rect(x: p.x - linearLineWidth / 2, y: p.y - lineHeight / 2,
                              width: linearLineWidth, height: lineHeight))
        case .step:
            path.addRect(Rect(x: p.x - lineWidth / 2, y: p.y - lineHeight / 2,
                              width: lineWidth, height: lineHeight))
        }
        let view = View(path: path)
        view.fillColor = lineColor
        return view
    }
    private static func knobView(from p: Point,
                                 fillColor: Color, lineColor: Color,
                                 baseWidth: Real,
                                 knobHalfHeight: Real, subKnobHalfHeight: Real,
                                 with label: Keyframe.Label) -> View {
        let kh = label == .main ? knobHalfHeight : subKnobHalfHeight
        let knobView = View.discreteKnob(Size(width: baseWidth, height: kh * 2))
        knobView.position = p
        knobView.fillColor = fillColor
        knobView.lineColor = lineColor
        return knobView
    }
    private static func keyLinePathViewWith(_ keyframe: Keyframe, lineColor: Color,
                                            baseWidth: Real,
                                            lineWidth: Real, maxLineWidth: Real,
                                            position: Point, width: Real) -> View {
        let path = CGMutablePath()
        if keyframe.easing.isLinear {
            path.addRect(Rect(x: position.x, y: position.y - lineWidth / 2,
                              width: width, height: lineWidth))
        } else {
            let b = keyframe.easing.bezier, bw = width
            let bx = position.x, count = Int(width / 5.0)
            let d = 1 / Real(count)
            let points: [Point] = (0...count).map { i in
                let dx = d * Real(i)
                let dp = b.difference(withT: dx)
                let dy = max(0.5, min(maxLineWidth, (dp.x == dp.y ?
                    .pi / 2 : 1.8 * atan2(dp.y, dp.x)) / (.pi / 2)))
                return Point(x: dx * bw + bx, y: dy)
            }
            let ps0 = points.map { Point(x: $0.x, y: position.y + $0.y) }
            let ps1 = points.reversed().map { Point(x: $0.x, y: position.y - $0.y) }
            path.addLines(between: ps0 + ps1)
        }
        let view = View(path: path)
        view.fillColor = lineColor
        return view
    }

    var lineColorClosure: ((Int) -> (Color)) = { _ in .content }
    var smallLineColorClosure: (() -> (Color)) = { .content }
    var knobColorClosure: ((Int) -> (Color)) = { _ in .knob }
    private var knobViews = [View]()
    let editView: View = {
        let view = View(isForm: true)
        view.fillColor = .selected
        view.lineColor = nil
        view.isHidden = true
        return view
    } ()
    let indicatedView: View = {
        let view = View(isForm: true)
        view.fillColor = .subIndicated
        view.lineColor = nil
        view.isHidden = true
        return view
    } ()
    func updateChildren() {
        let height = frame.height
        let midY = height / 2, lineWidth = 2.0.cg
        let khh = sizeType == .small ? smallKnobHalfHeight : self.knobHalfHeight
        let skhh = sizeType == .small ? smallSubKnobHalfHeight : self.subKnobHalfHeight
        let selectedStartIndex = animation.selectedKeyframeIndexes.first
            ?? animation.keyframes.count - 1
        let selectedEndIndex = animation.selectedKeyframeIndexes.last ?? 0

        var keyLineViews = [View](), knobViews = [View](), selectedViews = [View]()
        for (i, li) in animation.loopFrames.enumerated() {
            let keyframe = animation.keyframes[li.index]
            let time = li.time
            let nextTime = i + 1 >= animation.loopFrames.count ?
                animation.duration : animation.loopFrames[i + 1].time
            let x = self.x(withTime: time), nextX = self.x(withTime: nextTime)
            let width = nextX - x
            let position = Point(x: x, y: midY)

            if sizeType == .regular {
                let keyLineColor = lineColorClosure(li.index)
                let keyLine = AnimationView.keyLinePathViewWith(keyframe,
                                                                lineColor: keyLineColor,
                                                                baseWidth: baseWidth,
                                                                lineWidth: lineWidth,
                                                                maxLineWidth: maxLineWidth,
                                                                position: position, width: width)
                keyLineViews.append(keyLine)

                let knobLine = AnimationView.knobLinePathView(from: position,
                                                              lineColor: keyLineColor,
                                                              baseWidth: baseWidth,
                                                              lineHeight: height - 2,
                                                              with: keyframe.interpolation)
                keyLineViews.append(knobLine)

                if li.loopCount > 0 {
                    let path = CGMutablePath()
                    if i > 0 && animation.loopFrames[i - 1].loopCount < li.loopCount {
                        path.move(to: Point(x: x, y: midY + height / 2 - 4))
                        path.addLine(to: Point(x: x + 3, y: midY + height / 2 - 1))
                        path.addLine(to: Point(x: x, y: midY + height / 2 - 1))
                        path.closeSubpath()
                    }
                    path.addRect(Rect(x: x, y: midY + height / 2 - 2, width: width, height: 1))
                    if li.loopingCount > 0 {
                        if i > 0 && animation.loopFrames[i - 1].loopingCount < li.loopingCount {
                            path.move(to: Point(x: x, y: 1))
                            path.addLine(to: Point(x: x + 3, y: 1))
                            path.addLine(to: Point(x: x, y: 4))
                            path.closeSubpath()
                        }
                        path.addRect(Rect(x: x, y: 1, width: width, height: 1))
                    }

                    let layer = View(path: path)
                    layer.fillColor = keyLineColor
                    keyLineViews.append(layer)
                }
            }

            if i > 0 {
                let fillColor = li.loopingCount > 0 || li.index == editingKeyframeIndex ?
                    Color.editing : knobColorClosure(li.index)
                let lineColor = ((li.time + beginBaseTime) / baseTimeInterval).isInteger ?
                    Color.getSetBorder : Color.warning
                let knob = AnimationView.knobView(from: position,
                                                  fillColor: fillColor,
                                                  lineColor: lineColor,
                                                  baseWidth: baseWidth,
                                                  knobHalfHeight: khh,
                                                  subKnobHalfHeight: skhh,
                                                  with: keyframe.label)
                knobViews.append(knob)
            }

            if animation.selectedKeyframeIndexes.contains(li.index) {
                let view = View.selection
                view.frame = Rect(x: position.x, y: 0, width: width, height: height)
                selectedViews.append(view)
            } else if li.index >= selectedStartIndex && li.index < selectedEndIndex {
                let path = CGMutablePath(), h = 2.0.cg
                path.addRect(Rect(x: position.x, y: 0, width: width, height: h))
                path.addRect(Rect(x: position.x, y: height - h, width: width, height: h))
                let view = View(path: path)
                view.fillColor = .select
                view.lineColor = .selectBorder
                selectedViews.append(view)
            }
        }

        let maxX = self.x(withTime: animation.duration)

        if sizeType == .small {
            let keyLineView = View(isForm: true)
            keyLineView.frame = Rect(x: 0, y: midY - 0.5, width: maxX, height: 1)
            keyLineView.fillColor = smallLineColorClosure()
            keyLineView.lineColor = nil
            keyLineViews.append(keyLineView)
        }

        let durationFillColor = editingKeyframeIndex == animation.keyframes.count ?
            Color.editing : Color.knob
        let durationLineColor = ((animation.duration + beginBaseTime) / baseTimeInterval).isInteger ?
            Color.getSetBorder : Color.warning
        let durationKnob = AnimationView.knobView(from: Point(x: maxX, y: midY),
                                                  fillColor: durationFillColor,
                                                  lineColor: durationLineColor,
                                                  baseWidth: baseWidth,
                                                  knobHalfHeight: khh,
                                                  subKnobHalfHeight: skhh,
                                                  with: .main)
        knobViews.append(durationKnob)

        self.knobViews = knobViews

        if let selectionView = selectionView {
            selectedViews.append(selectionView)
        }

        updateEditLoopframeIndex()
        updateIndicatedView()
        children = [editView, indicatedView] + keyLineViews + knobViews as [View] + selectedViews
    }
    private func updateWithBeginTime() {
        for (i, li) in animation.loopFrames.enumerated() {
            if i > 0 {
                knobViews[i - 1].lineColor = ((li.time + beginBaseTime) / baseTimeInterval).isInteger ?
                    Color.getSetBorder : Color.warning
            }
        }
        knobViews.last?.lineColor = ((animation.duration + beginBaseTime) / baseTimeInterval).isInteger ?
            Color.getSetBorder : Color.warning
    }

    var height: Real {
        didSet {
            updateWithHeight()
        }
    }
    var smallHeight: Real {
        didSet {
            updateWithHeight()
        }
    }
    var sizeType = SizeType.small {
        didSet {
            updateWithHeight()
        }
    }
    private func updateWithHeight() {
        frame.size.height = sizeType == .small ? smallHeight : height
        updateChildren()
    }
    private var isUseUpdateChildren = true
    var animation: Animation {
        didSet {
            if isUseUpdateChildren {
                editLoopframeIndex = animation.currentLoopframeIndex
                isInterpolated = animation.currentIsInterpolated
                updateChildren()
                //                updateIndicatedKeyframeIndex(at: cursorPoint)
            }
        }
    }

    override var isIndicated: Bool {
        didSet {
            indicatedView.isHidden = !isIndicated
        }
    }
    var indicatedKeyframeIndex: Int? {
        didSet {
            updateIndicatedView()
        }
    }
    func updateIndicatedView() {
        if let indicatedKeyframeIndex = indicatedKeyframeIndex {
            let time: Rational
            if indicatedKeyframeIndex >= animation.keyframes.count {
                time = animation.duration
            } else {
                time = animation.keyframes[indicatedKeyframeIndex].time
            }
            let x = self.x(withTime: time)
            indicatedView.frame = Rect(x: x - baseWidth / 2, y: 0,
                                       width: baseWidth, height: frame.height)
        }
    }
    func indicate(at p: Point) {
        updateIndicatedKeyframeIndex(at: p)
    }
    func updateIndicatedKeyframeIndex(at p: Point) {
        if let i = nearestKeyframeIndex(at: p) {
            indicatedKeyframeIndex = i == 0 ? nil : i
        } else {
            indicatedKeyframeIndex = animation.keyframes.count
        }
    }

    func updateKeyframeIndex(with animation: Animation) {
        //        isInterpolated = animation.isInterpolated
        //        editLoopframeIndex = animation.currentLoopframeIndex
    }

    var isInterpolated = false {
        didSet {
            if isInterpolated != oldValue {
                updateEditLoopframeIndex()
            }
        }
    }
    var isEdit = false {
        didSet {
            editView.isHidden = !isEdit
        }
    }
    var editLoopframeIndex = 0 {
        didSet {
            if editLoopframeIndex != oldValue {
                updateEditLoopframeIndex()
            }
        }
    }
    func updateEditLoopframeIndex() {
        let time: Rational
        if editLoopframeIndex >= animation.loopFrames.count {
            time = animation.duration
        } else {
            time = animation.loopFrames[editLoopframeIndex].time
        }
        let x = self.x(withTime: time)
        editView.fillColor = isInterpolated ? .subSelected : .selected
        editView.frame = Rect(x: x - baseWidth / 2, y: 0, width: baseWidth, height: frame.height)
    }
    var editingKeyframeIndex: Int?

    static let defautBaseWidth = 6.0.cg
    var baseWidth = defautBaseWidth {
        didSet {
            updateChildren()
        }
    }
    let smallKnobHalfHeight = 3.0.cg, smallSubKnobHalfHeight = 2.0.cg
    let knobHalfHeight = 6.0.cg, subKnobHalfHeight = 3.0.cg, maxLineWidth = 3.0.cg
    var baseTimeInterval: Rational {
        didSet {
            updateChildren()
        }
    }
    var beginBaseTime = Rational(0) {
        didSet {
            updateWithBeginTime()
        }
    }

    func movingKeyframeIndex(atTime time: Rational) -> (index: Int?, isSolution: Bool) {
        return animation.movingKeyframeIndex(withTime: time)
    }
    func beatTime(withBaseTime baseTime: BaseTime) -> Rational {
        return baseTime * baseTimeInterval
    }
    func baseTime(withRationalTime beatTime: Rational) -> BaseTime {
        return beatTime / baseTimeInterval
    }
    func basedRationalTime(withRealBaseTime realBaseTime: Real) -> Rational {
        return Rational(Int(realBaseTime)) * baseTimeInterval
    }
    func realBaseTime(withRationalTime beatTime: Rational) -> Real {
        return RealBaseTime(beatTime / baseTimeInterval)
    }
    func realBaseTime(withX x: Real) -> Real {
        return RealBaseTime(x / baseWidth)
    }
    func basedRationalTime(withRealTime realTime: Real) -> Rational {
        return Rational(Int(realTime / Real(baseTimeInterval))) * baseTimeInterval
    }
    func time(withX x: Real, isBased: Bool = true) -> Rational {
        let dt = beginBaseTime - floor(beginBaseTime / baseTimeInterval) * baseTimeInterval
        let basedX = x + self.x(withTime: dt)
        let t =  isBased ?
            baseTimeInterval * Rational(Int(round(basedX / baseWidth))) :
            basedRationalTime(withRealTime: Real(basedX / baseWidth) * Real(baseTimeInterval))
        return t - (beginBaseTime - floor(beginBaseTime / baseTimeInterval) * baseTimeInterval)
    }
    func x(withTime time: Rational) -> Real {
        return Real(time / baseTimeInterval) * baseWidth
    }
    func clipDeltaTime(withTime time: Rational) -> Rational {
        let ft = baseTime(withRationalTime: time)
        let fft = ft + BaseTime(1, 2)
        return fft - floor(fft) < BaseTime(1, 2) ?
            beatTime(withBaseTime: ceil(ft)) - time :
            beatTime(withBaseTime: floor(ft)) - time
    }
    func nearestKeyframeIndex(at p: Point) -> Int? {
        guard !animation.keyframes.isEmpty else {
            return nil
        }
        var minD = Real.infinity, minIndex: Int?
        func updateMin(index: Int?, time: Rational) {
            let x = self.x(withTime: time)
            let d = abs(p.x - x)
            if d < minD {
                minIndex = index
                minD = d
            }
        }
        for (i, keyframe) in animation.keyframes.enumerated().reversed() {
            updateMin(index: i, time: keyframe.time)
        }
        updateMin(index: nil, time: animation.duration)
        return minIndex
    }

    enum SetKeyframeType {
        case insert, remove, replace
    }
    struct SetKeyframeBinding {
        let animationView: AnimationView
        let keyframe: Keyframe, index: Int, setType: SetKeyframeType
        let animation: Animation, oldAnimation: Animation, phase: Phase
    }
    var setKeyframeClosure: ((SetKeyframeBinding) -> ())?

    struct SlideBinding {
        let animationView: AnimationView
        let keyframeIndex: Int?, deltaTime: Rational, oldTime: Rational
        let animation: Animation, oldAnimation: Animation, phase: Phase
    }
    var slideClosure: ((SlideBinding) -> ())?

    struct SelectBinding {
        let animationView: AnimationView
        let selectedIndexes: [Int], oldSelectedIndexes: [Int]
        let animation: Animation, oldAnimation: Animation, phase: Phase
    }
    var selectClosure: ((SelectBinding) -> ())?

    func delete(for p: Point) {
        deleteKeyframe(at: p)
    }
    var noRemovedClosure: ((AnimationView) -> ())?
    func deleteKeyframe(withTime time: Rational) {
        let lf = animation.indexInfo(withTime: time)
        if lf.keyframeInternalTime == 0 {
            deleteKeyframe(at: lf.keyframeIndex)
        }
    }
    func deleteKeyframe(at point: Point) {
        guard let ki = nearestKeyframeIndex(at: point) else { return }
        deleteKeyframe(at: ki)
    }
    func deleteKeyframe(at ki: Int) {
        let containsIndexes = animation.selectedKeyframeIndexes.contains(ki)
        let indexes = containsIndexes ? animation.selectedKeyframeIndexes : [ki]
        if containsIndexes {
            set(selectedIndexes: [],
                oldSelectedIndexes: animation.selectedKeyframeIndexes)
        }
        indexes.sorted().reversed().forEach {
            if animation.keyframes.count > 1 {
                if $0 == 0 {
                    deleteFirstKeyframe()
                } else {
                    removeKeyframe(at: $0)
                }
            } else {
                noRemovedClosure?(self)
            }
        }
    }
    private func deleteFirstKeyframe() {
        let deltaTime = animation.keyframes[1].time
        removeKeyframe(at: 0)
        let keyframes: [Keyframe] = animation.keyframes.map {
            var keyframe = $0
            keyframe.time -= deltaTime
            return keyframe
        }
        set(keyframes, old: animation.keyframes)
    }
    func copiedViewables(at p: Point) -> [Viewable] {
        return [animation]
    }
    func paste(_ objects: [Any], for p: Point) {
        //        for object in objects {
        //            if let animation = object as? Animation {
        //                if keyframe.equalOption(other: self.keyframe) {
        //                    set(keyframe, old: self.keyframe)
        //                    return
        //                }
        //            }
        //        }
    }
    func new(for p: Point) {
        _ = splitKeyframe(withTime: time(withX: p.x))
    }

    var splitKeyframeLabelClosure: ((Keyframe, Int) -> (Keyframe.Label))?
    func splitKeyframe(withTime time: Rational) -> Bool {
        guard time < animation.duration else {
            return false
        }
        let ki = Keyframe.index(time: time, with: animation.keyframes)
        guard ki.interTime > 0 else {
            return false
        }
        let k = animation.keyframes[ki.index]
        let newEaing = ki.duration != 0 ?
            k.easing.split(with: Real(ki.interTime / ki.duration)) :
            (b0: k.easing, b1: Easing())
        let splitKeyframe0 = Keyframe(time: k.time, label: k.label,
                                      loop: k.loop, interpolation: k.interpolation,
                                      easing: newEaing.b0)
        let splitKeyframe1 = Keyframe(time: time,
                                      label: splitKeyframeLabelClosure?(k, ki.index) ?? .main,
                                      loop: k.loop, interpolation: k.interpolation,
                                      easing: newEaing.b1)
        replace(splitKeyframe0, at: ki.index)
        insert(splitKeyframe1, at: ki.index + 1)
        let indexes = animation.selectedKeyframeIndexes
        for (i, index) in indexes.enumerated() {
            if index >= ki.index {
                let movedIndexes = indexes.map { $0 > ki.index ? $0 + 1 : $0 }
                let intertedIndexes = index == ki.index ?
                    movedIndexes.withInserted(index + 1, at: i + 1) : movedIndexes
                set(selectedIndexes: intertedIndexes, oldSelectedIndexes: indexes)
                break
            }
        }
        return true
    }

    private func replace(_ keyframe: Keyframe, at index: Int) {
        registeringUndoManager?.registerUndo(withTarget: self) { [ok = animation.keyframes[index]] in
            $0.replace(ok, at: index)
        }
        isUseUpdateChildren = false
        let oldAnimation = animation
        setKeyframeClosure?(SetKeyframeBinding(animationView: self,
                                               keyframe: keyframe, index: index,
                                               setType: .replace,
                                               animation: oldAnimation,
                                               oldAnimation: oldAnimation, phase: .began))
        animation.keyframes[index] = keyframe
        setKeyframeClosure?(SetKeyframeBinding(animationView: self,
                                               keyframe: keyframe, index: index,
                                               setType: .replace,
                                               animation: animation,
                                               oldAnimation: oldAnimation, phase: .ended))
        isUseUpdateChildren = true
        updateChildren()
    }
    private func insert(_ keyframe: Keyframe, at index: Int) {
        registeringUndoManager?.registerUndo(withTarget: self) {
            $0.removeKeyframe(at: index)
        }
        isUseUpdateChildren = false
        let oldAnimation = animation
        setKeyframeClosure?(SetKeyframeBinding(animationView: self,
                                               keyframe: keyframe, index: index,
                                               setType: .insert,
                                               animation: oldAnimation,
                                               oldAnimation: oldAnimation, phase: .began))
        animation.keyframes.insert(keyframe, at: index)
        setKeyframeClosure?(SetKeyframeBinding(animationView: self,
                                               keyframe: keyframe, index: index,
                                               setType: .insert,
                                               animation: animation,
                                               oldAnimation: oldAnimation, phase: .ended))
        isUseUpdateChildren = true
        updateChildren()
    }
    private func removeKeyframe(at index: Int) {
        registeringUndoManager?.registerUndo(withTarget: self) { [ok = animation.keyframes[index]] in
            $0.insert(ok, at: index)
        }
        isUseUpdateChildren = false
        let oldAnimation = animation
        setKeyframeClosure?(SetKeyframeBinding(animationView: self,
                                               keyframe: oldAnimation.keyframes[index],
                                               index: index,
                                               setType: .remove,
                                               animation: oldAnimation,
                                               oldAnimation: oldAnimation, phase: .began))
        animation.keyframes.remove(at: index)
        setKeyframeClosure?(SetKeyframeBinding(animationView: self,
                                               keyframe: oldAnimation.keyframes[index],
                                               index: index,
                                               setType: .remove,
                                               animation: animation,
                                               oldAnimation: oldAnimation, phase: .ended))
        isUseUpdateChildren = true
        updateChildren()
    }

    private var isDrag = false, oldTime = RealBaseTime(0), oldKeyframeIndex: Int?
    private struct DragObject {
        var clipDeltaTime = Rational(0), minDeltaTime = Rational(0), oldTime = Rational(0)
        var oldAnimation = Animation()
    }

    private var dragObject = DragObject()
    func move(for point: Point, pressure: Real, time: Second, _ phase: Phase) {
        let p = point
        switch phase {
        case .began:
            oldTime = realBaseTime(withX: p.x)
            if let ki = nearestKeyframeIndex(at: p), animation.keyframes.count > 1 {
                let keyframeIndex = ki > 0 ? ki : 1
                oldKeyframeIndex = keyframeIndex
                moveKeyframe(withDeltaTime: 0, keyframeIndex: keyframeIndex, phase: phase)
            } else {
                oldKeyframeIndex = nil
                moveDuration(withDeltaTime: 0, phase)
            }
        case .changed, .ended:
            let t = realBaseTime(withX: point.x)
            let fdt = t - oldTime + (t - oldTime >= 0 ? 0.5 : -0.5)
            let dt = basedRationalTime(withRealBaseTime: fdt)
            let deltaTime = max(dragObject.minDeltaTime, dt + dragObject.clipDeltaTime)
            if let keyframeIndex = oldKeyframeIndex, keyframeIndex < animation.keyframes.count {
                moveKeyframe(withDeltaTime: deltaTime,
                             keyframeIndex: keyframeIndex, phase: phase)
            } else {
                moveDuration(withDeltaTime: deltaTime, phase)
            }
        }
    }
    func move(withDeltaTime deltaTime: Rational, keyframeIndex: Int?, _ phase: Phase) {
        if let keyframeIndex = keyframeIndex, keyframeIndex < animation.keyframes.count {
            moveKeyframe(withDeltaTime: deltaTime,
                         keyframeIndex: keyframeIndex, phase: phase)
        } else {
            moveDuration(withDeltaTime: deltaTime, phase)
        }
    }
    func moveKeyframe(withDeltaTime deltaTime: Rational,
                      keyframeIndex: Int, phase: Phase) {
        switch phase {
        case .began:
            editingKeyframeIndex = keyframeIndex
            isDrag = false
            let preTime = animation.keyframes[keyframeIndex - 1].time
            let time = animation.keyframes[keyframeIndex].time
            dragObject.clipDeltaTime = clipDeltaTime(withTime: time + beginBaseTime)
            dragObject.minDeltaTime = preTime - time
            dragObject.oldAnimation = animation
            dragObject.oldTime = time
            slideClosure?(SlideBinding(animationView: self,
                                       keyframeIndex: keyframeIndex,
                                       deltaTime: deltaTime,
                                       oldTime: dragObject.oldTime,
                                       animation: animation,
                                       oldAnimation: dragObject.oldAnimation, phase: .began))
        case .changed:
            isDrag = true
            var nks = dragObject.oldAnimation.keyframes
            (keyframeIndex..<nks.count).forEach {
                nks[$0].time += deltaTime
            }
            isUseUpdateChildren = false
            animation.keyframes = nks
            animation.duration = dragObject.oldAnimation.duration + deltaTime
            slideClosure?(SlideBinding(animationView: self,
                                       keyframeIndex: keyframeIndex,
                                       deltaTime: deltaTime,
                                       oldTime: dragObject.oldTime,
                                       animation: animation, oldAnimation: dragObject.oldAnimation,
                                       phase: .changed))
            isUseUpdateChildren = true
            updateChildren()
        case .ended:
            editingKeyframeIndex = nil
            guard isDrag else {
                dragObject = DragObject()
                return
            }
            let newKeyframes: [Keyframe]
            if deltaTime != 0 {
                var nks = dragObject.oldAnimation.keyframes
                (keyframeIndex..<nks.count).forEach {
                    nks[$0].time += deltaTime
                }
                registeringUndoManager?.registerUndo(withTarget: self) { [dragObject] in
                    $0.set(dragObject.oldAnimation.keyframes, old: nks,
                           duration: dragObject.oldAnimation.duration,
                           oldDuration: dragObject.oldAnimation.duration + deltaTime)
                }
                newKeyframes = nks
            } else {
                newKeyframes = dragObject.oldAnimation.keyframes
            }
            isUseUpdateChildren = false
            animation.keyframes = newKeyframes
            animation.duration = dragObject.oldAnimation.duration + deltaTime
            slideClosure?(SlideBinding(animationView: self,
                                       keyframeIndex: keyframeIndex,
                                       deltaTime: deltaTime,
                                       oldTime: dragObject.oldTime,
                                       animation: animation,
                                       oldAnimation: dragObject.oldAnimation, phase: .ended))
            isUseUpdateChildren = true
            updateChildren()

            isDrag = false
            dragObject = DragObject()
        }
    }
    func moveDuration(withDeltaTime deltaTime: Rational, _ phase: Phase) {
        switch phase {
        case .began:
            editingKeyframeIndex = animation.keyframes.count
            isDrag = false
            let preTime = animation.keyframes[animation.keyframes.count - 1].time
            let time = animation.duration
            dragObject.clipDeltaTime = clipDeltaTime(withTime: time + beginBaseTime)
            dragObject.minDeltaTime = preTime - time
            dragObject.oldAnimation = animation
            dragObject.oldTime = time
            slideClosure?(SlideBinding(animationView: self,
                                       keyframeIndex: nil,
                                       deltaTime: deltaTime,
                                       oldTime: dragObject.oldTime,
                                       animation: animation,
                                       oldAnimation: dragObject.oldAnimation, phase: .began))
        case .changed:
            isDrag = true
            isUseUpdateChildren = false
            animation.duration = dragObject.oldAnimation.duration + deltaTime
            slideClosure?(SlideBinding(animationView: self,
                                       keyframeIndex: nil,
                                       deltaTime: deltaTime,
                                       oldTime: dragObject.oldTime,
                                       animation: animation,
                                       oldAnimation: dragObject.oldAnimation, phase: .changed))
            isUseUpdateChildren = true
            updateChildren()
        case .ended:
            editingKeyframeIndex = nil
            guard isDrag else {
                dragObject = DragObject()
                return
            }
            if deltaTime != 0 {
                registeringUndoManager?.registerUndo(withTarget: self) { [dragObject] in
                    $0.set(duration: dragObject.oldAnimation.duration,
                           oldDuration: dragObject.oldAnimation.duration + deltaTime)
                }
            }
            isUseUpdateChildren = false
            animation.duration = dragObject.oldAnimation.duration + deltaTime
            slideClosure?(SlideBinding(animationView: self,
                                       keyframeIndex: nil,
                                       deltaTime: deltaTime,
                                       oldTime: dragObject.oldTime,
                                       animation: animation,
                                       oldAnimation: dragObject.oldAnimation, phase: .ended))
            isUseUpdateChildren = true
            updateChildren()

            isDrag = false
            dragObject = DragObject()
        }
    }

    struct Binding {
        let animationView: AnimationView
        let animation: Animation, oldAnimation: Animation, phase: Phase
    }
    var binding: ((Binding) -> ())?
    private func set(_ keyframes: [Keyframe], old oldKeyframes: [Keyframe]) {
        registeringUndoManager?.registerUndo(withTarget: self) {
            $0.set(oldKeyframes, old: keyframes)
        }
        isUseUpdateChildren = false
        let oldAnimation = animation
        binding?(Binding(animationView: self,
                         animation: animation, oldAnimation: animation, phase: .began))
        animation.keyframes = keyframes
        binding?(Binding(animationView: self,
                         animation: animation, oldAnimation: oldAnimation, phase: .ended))
        isUseUpdateChildren = true
        updateChildren()
    }
    private func set(_ keyframes: [Keyframe], old oldKeyframes: [Keyframe],
                     duration: Rational, oldDuration: Rational) {
        registeringUndoManager?.registerUndo(withTarget: self) {
            $0.set(oldKeyframes, old: keyframes, duration: oldDuration, oldDuration: duration)
        }
        isUseUpdateChildren = false
        let oldAnimation = animation
        binding?(Binding(animationView: self,
                         animation: animation, oldAnimation: animation, phase: .began))
        animation.keyframes = keyframes
        animation.duration = duration
        binding?(Binding(animationView: self,
                         animation: animation, oldAnimation: oldAnimation, phase: .ended))
        isUseUpdateChildren = true
        updateChildren()
    }
    private func set(duration: Rational, oldDuration: Rational) {
        registeringUndoManager?.registerUndo(withTarget: self) {
            $0.set(duration: oldDuration, oldDuration: duration)
        }
        isUseUpdateChildren = false
        let oldAnimation = animation
        binding?(Binding(animationView: self,
                         animation: animation, oldAnimation: animation, phase: .began))
        animation.duration = duration
        binding?(Binding(animationView: self,
                         animation: animation, oldAnimation: oldAnimation, phase: .ended))
        isUseUpdateChildren = true
        updateChildren()
    }

    func select(from rect: Rect, _ phase: Phase) {
        select(from: rect, phase, isDeselect: false)
    }
    func selectAll() {
        selectAll(isDeselect: false)
    }
    func deselect(from rect: Rect, _ phase: Phase) {
        select(from: rect, phase, isDeselect: true)
    }
    func deselectAll() {
        selectAll(isDeselect: true)
    }
    var selectionView: View? {
        didSet {
            if let selectionView = selectionView {
                append(child: selectionView)
            } else {
                oldValue?.removeFromParent()
            }
        }
    }
    private struct SelectObject {
        var oldAnimation = Animation()
    }
    private var selectObject = SelectObject()
    func select(from rect: Rect, _ phase: Phase, isDeselect: Bool) {
        switch phase {
        case .began:
            selectionView = isDeselect ? View.deselection : View.selection
            selectObject.oldAnimation = animation
            selectionView?.frame = rect
            selectClosure?(SelectBinding(animationView: self,
                                         selectedIndexes: animation.selectedKeyframeIndexes,
                                         oldSelectedIndexes: animation.selectedKeyframeIndexes,
                                         animation: animation, oldAnimation: animation,
                                         phase: .began))
        case .changed:
            selectionView?.frame = rect
            isUseUpdateChildren = false
            animation.selectedKeyframeIndexes = selectedIndex(from: rect,
                                                              with: selectObject,
                                                              isDeselect: isDeselect)
            selectClosure?(SelectBinding(animationView: self,
                                         selectedIndexes: animation.selectedKeyframeIndexes,
                                         oldSelectedIndexes: selectObject.oldAnimation.selectedKeyframeIndexes,
                                         animation: animation,
                                         oldAnimation: selectObject.oldAnimation,
                                         phase: .changed))
            isUseUpdateChildren = true
            updateChildren()
        case .ended:
            let newIndexes = selectedIndex(from: rect,
                                           with: selectObject, isDeselect: isDeselect)
            if selectObject.oldAnimation.selectedKeyframeIndexes != newIndexes {
                registeringUndoManager?.registerUndo(withTarget: self) { [so = selectObject] in
                    $0.set(selectedIndexes: so.oldAnimation.selectedKeyframeIndexes,
                           oldSelectedIndexes: newIndexes)
                }
            }
            isUseUpdateChildren = false
            animation.selectedKeyframeIndexes = newIndexes
            selectClosure?(SelectBinding(animationView: self,
                                         selectedIndexes: animation.selectedKeyframeIndexes,
                                         oldSelectedIndexes: selectObject.oldAnimation.selectedKeyframeIndexes,
                                         animation: animation,
                                         oldAnimation: selectObject.oldAnimation,
                                         phase: .ended))
            isUseUpdateChildren = true
            updateChildren()

            selectionView = nil
            selectObject = SelectObject()
        }
    }
    private func indexes(from rect: Rect, with selectObject: SelectObject) -> [Int] {
        let startTime = time(withX: rect.minX, isBased: false) + baseTimeInterval / 2
        let startIndexTuple = Keyframe.index(time: startTime,
                                             with: selectObject.oldAnimation.keyframes)
        let startIndex = startIndexTuple.index
        let selectEndX = rect.maxX
        let endTime = time(withX: selectEndX, isBased: false) + baseTimeInterval / 2
        let endIndexTuple = Keyframe.index(time: endTime,
                                           with: selectObject.oldAnimation.keyframes)
        let endIndex = endIndexTuple.index
        return startIndex == endIndex ?
            [startIndex] :
            Array(startIndex < endIndex ? (startIndex...endIndex) : (endIndex...startIndex))
    }
    private func selectedIndex(from rect: Rect,
                               with selectObject: SelectObject, isDeselect: Bool) -> [Int] {
        let selectedIndexes = indexes(from: rect, with: selectObject)
        let oldIndexes = selectObject.oldAnimation.selectedKeyframeIndexes
        return isDeselect ?
            Array(Set(oldIndexes).subtracting(Set(selectedIndexes))).sorted() :
            Array(Set(oldIndexes).union(Set(selectedIndexes))).sorted()
    }
    func selectAll(isDeselect: Bool) {
        let indexes = isDeselect ? [] : Array(0..<animation.keyframes.count)
        if indexes != animation.selectedKeyframeIndexes {
            set(selectedIndexes: indexes,
                oldSelectedIndexes: animation.selectedKeyframeIndexes)
        }
    }

    func set(selectedIndexes: [Int], oldSelectedIndexes: [Int]) {
        registeringUndoManager?.registerUndo(withTarget: self) {
            $0.set(selectedIndexes: oldSelectedIndexes,
                   oldSelectedIndexes: selectedIndexes)
        }
        isUseUpdateChildren = false
        let oldAnimation = animation
        selectClosure?(SelectBinding(animationView: self,
                                     selectedIndexes: oldSelectedIndexes,
                                     oldSelectedIndexes: oldSelectedIndexes,
                                     animation: animation, oldAnimation: animation,
                                     phase: .began))
        animation.selectedKeyframeIndexes = selectedIndexes
        selectClosure?(SelectBinding(animationView: self,
                                     selectedIndexes: animation.selectedKeyframeIndexes,
                                     oldSelectedIndexes: oldSelectedIndexes,
                                     animation: animation,
                                     oldAnimation: oldAnimation,
                                     phase: .ended))
        isUseUpdateChildren = true
        updateChildren()
    }
}
extension AnimationView: Queryable {
    static let referenceableType: Referenceable.Type = Animation.self
}
