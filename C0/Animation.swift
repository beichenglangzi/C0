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

import CoreGraphics

protocol Animatable {
    var keyframeTimings: KeyframeTimingCollection { get }
    var beginTime: Rational { get }
    var duration: Rational { get }
}

struct Animation<Value: KeyframeValue>: Codable, Animatable {
    typealias KeyframeIndex = Array<Keyframe<Value>>.Index
    typealias KeyframeTimingIndex = KeyframeTimingCollection.Index
    
    struct LoopFrame: Codable, Hashable {
        var index: KeyframeIndex, time: Rational, loopCount: Int, loopingCount: Int
    }
    typealias LoopFrameIndex = Array<LoopFrame>.Index
    
    private var _keyframes: [Keyframe<Value>]
    private var _duration: Rational
    var keyframes: [Keyframe<Value>] {
        get { return _keyframes }
        set {
            _keyframes = newValue
            self.loopFrames = Animation.loopFrames(with: keyframes, duration: duration)
        }
    }
    var beginTime: Rational
    var duration: Rational {
        get { return _duration }
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

    var selectedKeyframeIndexes: [KeyframeIndex]

    init(keyframes: [Keyframe<Value>] = [], beginTime: Rational = 0, duration: Rational = 1,
         selectedKeyframeIndexes: [KeyframeIndex] = []) {
        
        _keyframes = keyframes
        self.beginTime = beginTime
        _duration = duration
        self.loopFrames = Animation.loopFrames(with: keyframes, duration: duration)
        self.selectedKeyframeIndexes = selectedKeyframeIndexes
    }
    
    init(repeating: Value, keyframeTimings: [KeyframeTiming]) {
        self.init(keyframes: keyframeTimings.map { Keyframe(value: repeating, timing: $0) })
    }
    
    var keyframeTimings: KeyframeTimingCollection {
        return KeyframeTimingCollection(keyframes: keyframes)
    }
    
    var isEmpty: Bool {
        return keyframes.isEmpty
    }
    
    private static func loopFrames(with keyframes: [Keyframe<Value>],
                                   duration: Rational) -> [LoopFrame] {
        var loopFrames = [LoopFrame](), previousIndexes = [KeyframeIndex]()
        func appendLoopFrameWith(time: Rational, nextTime: Rational,
                                 previousIndex: KeyframeIndex, currentIndex: KeyframeIndex,
                                 loopCount: Int) {
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
        var loopframeIndex: LoopFrameIndex, keyframeIndex: KeyframeIndex
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
    
    func interpolation(atLoopFrameIndex li: LoopFrameIndex,
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
        var loopFrameIndex: LoopFrameIndex, keyframeIndex: KeyframeIndex
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
    func movingKeyframeIndex(atTime time: Rational) -> Int? {
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
    func time(atLoopFrameIndex index: LoopFrameIndex) -> Rational {
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
    func movingKeyframeIndex(atTime t: Rational) -> (index: KeyframeIndex?, isSolution: Bool) {
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
extension Animation: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        let text = Text(english: "\(keyframes.count) Keyframes",
                        japanese: "\(keyframes.count)キーフレーム")
        return text.thumbnailView(withFrame: frame, sizeType)
    }
}

final class AnimationView<Value: KeyframeValue, T: BinderProtocol>: View, BindableReceiver {
    typealias Model = Animation<Value>
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    enum Notification: NotificationProtocol {
        case didChange
        case insert(Int)
        case remove([Int])
        
        static var _didChange: Notification {
            return .didChange
        }
    }
    var notifications = [((AnimationView<Value, Binder>, Notification) -> ())]()
    
    var defaultModel = Model()
    
    var keyframesView: ObjectsView<Keyframe<Value>, Binder>
    
    private var knobViews = [View]()
    let editView: View = {
        let view = View(isLocked: true)
        view.fillColor = .selected
        view.lineColor = nil
        view.isHidden = true
        return view
    } ()
    let indicatedView: View = {
        let view = View(isLocked: true)
        view.fillColor = .subIndicated
        view.lineColor = nil
        view.isHidden = true
        return view
    } ()
    var baseWidth = 6.0.cg {
        didSet { updateLayout() }
    }
    let smallKnobHalfHeight = 3.0.cg, smallSubKnobHalfHeight = 2.0.cg
    let knobHalfHeight = 6.0.cg, subKnobHalfHeight = 3.0.cg, maxLineWidth = 3.0.cg
    var baseTimeInterval: Rational {
        didSet { updateLayout() }
    }
    var beginBaseTime = Rational(0) {
        didSet { updateWithBeginTime() }
    }
    var height: Real {
        didSet { updateWithHeight() }
    }
    var smallHeight: Real {
        didSet { updateWithHeight() }
    }
    var sizeType = SizeType.small {
        didSet { updateWithHeight() }
    }
    
    init(binder: Binder, keyPath: BinderKeyPath,
         beginBaseTime: Rational = 0, baseTimeInterval: Rational = Rational(1, 16),
         origin: Point = Point(),
         height: Real = Layout.basicHeight, smallHeight: Real = 8.0,
         sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        self.beginBaseTime = beginBaseTime
        self.baseTimeInterval = baseTimeInterval
        self.height = height
        self.smallHeight = smallHeight
        self.sizeType = sizeType
        
        super.init()
        frame = Rect(x: origin.x, y: origin.y,
                     width: 0, height: sizeType == .small ? smallHeight : height)
        updateLayout()
    }

    private static func knobLinePathView(from p: Point, lineColor: Color,
                                         baseWidth: Real, lineHeight: Real,
                                         lineWidth: Real = 4, linearLineWidth: Real = 2,
                                         with interpolation: KeyframeTiming.Interpolation) -> View {
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
                                 with label: KeyframeTiming.Label) -> View {
        let kh = label == .main ? knobHalfHeight : subKnobHalfHeight
        let knobView = View.discreteKnob(Size(width: baseWidth, height: kh * 2))
        knobView.position = p
        knobView.fillColor = fillColor
        knobView.lineColor = lineColor
        return knobView
    }
    private static func keyLinePathViewWith(_ keyframe: Keyframe<Value>, lineColor: Color,
                                            baseWidth: Real,
                                            lineWidth: Real, maxLineWidth: Real,
                                            position: Point, width: Real) -> View {
        let path = CGMutablePath()
        if keyframe.timing.easing.isLinear {
            path.addRect(Rect(x: position.x, y: position.y - lineWidth / 2,
                              width: width, height: lineWidth))
        } else {
            let b = keyframe.timing.easing.bezier, bw = width
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
    
    override func updateLayout() {
        let height = frame.height
        let midY = height / 2, lineWidth = 2.0.cg
        let khh = sizeType == .small ? smallKnobHalfHeight : self.knobHalfHeight
        let skhh = sizeType == .small ? smallSubKnobHalfHeight : self.subKnobHalfHeight
        let selectedStartIndex = model.selectedKeyframeIndexes.first
            ?? model.keyframes.count - 1
        let selectedEndIndex = model.selectedKeyframeIndexes.last ?? 0

        var keyLineViews = [View](), knobViews = [View](), selectedViews = [View]()
        for (i, li) in model.loopFrames.enumerated() {
            let keyframe = model.keyframes[li.index]
            let time = li.time
            let nextTime = i + 1 >= model.loopFrames.count ?
                model.duration : model.loopFrames[i + 1].time
            let x = self.x(withTime: time), nextX = self.x(withTime: nextTime)
            let width = nextX - x
            let position = Point(x: x, y: midY)

            if sizeType == .regular {
                let keyLineColor = Color.content
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
                                                              with: keyframe.timing.interpolation)
                keyLineViews.append(knobLine)

                if li.loopCount > 0 {
                    let path = CGMutablePath()
                    if i > 0 && model.loopFrames[i - 1].loopCount < li.loopCount {
                        path.move(to: Point(x: x, y: midY + height / 2 - 4))
                        path.addLine(to: Point(x: x + 3, y: midY + height / 2 - 1))
                        path.addLine(to: Point(x: x, y: midY + height / 2 - 1))
                        path.closeSubpath()
                    }
                    path.addRect(Rect(x: x, y: midY + height / 2 - 2, width: width, height: 1))
                    if li.loopingCount > 0 {
                        if i > 0 && model.loopFrames[i - 1].loopingCount < li.loopingCount {
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
                let fillColor = Color.knob
                let lineColor = ((li.time + beginBaseTime) / baseTimeInterval).isInteger ?
                    Color.getSetBorder : Color.warning
                let knob = AnimationView.knobView(from: position,
                                                  fillColor: fillColor,
                                                  lineColor: lineColor,
                                                  baseWidth: baseWidth,
                                                  knobHalfHeight: khh,
                                                  subKnobHalfHeight: skhh,
                                                  with: keyframe.timing.label)
                knobViews.append(knob)
            }

            if model.selectedKeyframeIndexes.contains(li.index) {
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

        let maxX = self.x(withTime: model.duration)

        if sizeType == .small {
            let keyLineView = View(isLocked: true)
            keyLineView.frame = Rect(x: 0, y: midY - 0.5, width: maxX, height: 1)
            keyLineView.fillColor = .content
            keyLineView.lineColor = nil
            keyLineViews.append(keyLineView)
        }

        let durationFillColor = Color.knob
        let durationLineColor = ((model.duration + beginBaseTime) / baseTimeInterval).isInteger ?
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
        
        children = [editView, indicatedView] + keyLineViews + knobViews as [View] + selectedViews
    }
    private func updateWithBeginTime() {
        for (i, li) in model.loopFrames.enumerated() {
            if i > 0 {
                knobViews[i - 1].lineColor = ((li.time + beginBaseTime) / baseTimeInterval).isInteger ?
                    Color.getSetBorder : Color.warning
            }
        }
        knobViews.last?.lineColor = ((model.duration + beginBaseTime) / baseTimeInterval).isInteger ?
            Color.getSetBorder : Color.warning
    }
    func updateWithModel() {
        
    }
    private func updateWithHeight() {
        frame.size.height = sizeType == .small ? smallHeight : height
        updateLayout()
    }

    func movingKeyframeIndex(atTime time: Rational) -> (index: Int?, isSolution: Bool) {
        return model.movingKeyframeIndex(atTime: time)
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
            baseTimeInterval * Rational(Int((basedX / baseWidth).rounded())) :
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
        guard !model.keyframes.isEmpty else {
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
        for (i, keyframe) in model.keyframes.enumerated().reversed() {
            updateMin(index: i, time: keyframe.timing.time)
        }
        updateMin(index: nil, time: model.duration)
        return minIndex
    }

    enum SetKeyframeType {
        case insert(Int), remove(Range<Int>), replace(Int)
    }
}
extension AnimationView: Queryable {
    static var referenceableType: Referenceable.Type {
        return Model.self
    }
}
extension AnimationView: Selectable {
    func captureSelections(to version: Version) {
        version.registerUndo(withTarget: self) {
            [oldSelectedKeyframeIndexes = model.selectedKeyframeIndexes, unowned version] in
            
            $0.pushSelectedKeyframeIndexes(oldSelectedKeyframeIndexes, to: version)
        }
    }
    func pushSelectedKeyframeIndexes(_ selectedKeyframeIndexes: [Animation<Value>.KeyframeIndex],
                                     to version: Version) {
        version.registerUndo(withTarget: self) {
            [oldSelectedKeyframeIndexes = model.selectedKeyframeIndexes, unowned version] in
            
            $0.pushSelectedKeyframeIndexes(oldSelectedKeyframeIndexes, to: version)
        }
        model.selectedKeyframeIndexes = selectedKeyframeIndexes
        updateLayout()
    }
    
    func makeViewSelector() -> ViewSelector {
        return AnimationViewSelector(animationView: self)
    }
    
    func selectAll() {
        model.selectedKeyframeIndexes = Array(0..<model.keyframes.count)
        updateLayout()
    }
    func deselectAll() {
        model.selectedKeyframeIndexes = []
        updateLayout()
    }
}
final class AnimationViewSelector<Value: KeyframeValue, Binder: BinderProtocol>: ViewSelector {
    var animationView: AnimationView<Value, Binder>
    var model: Animation<Value> {
        get { return animationView.model }
        set { animationView.model = newValue }
    }
    
    init(animationView: AnimationView<Value, Binder>) {
        self.animationView = animationView
    }
    
    var beginSelectedKeyframeIndexes = [Animation<Value>.KeyframeIndex]()
    
    func select(from rect: Rect, _ phase: Phase) {
        select(from: rect, phase, isDeselect: false)
    }
    func deselect(from rect: Rect, _ phase: Phase) {
        select(from: rect, phase, isDeselect: true)
    }
    func select(from rect: Rect, _ phase: Phase, isDeselect: Bool) {
        switch phase {
        case .began:
            beginSelectedKeyframeIndexes = model.selectedKeyframeIndexes
        case .changed, .ended:
            model.selectedKeyframeIndexes = selectedIndex(from: rect, isDeselect: isDeselect)
            animationView.updateLayout()
        }
    }
    private func indexes(from rect: Rect) -> [Animation<Value>.KeyframeIndex] {
        let halfTimeInterval = animationView.baseTimeInterval / 2
        let startTime = animationView.time(withX: rect.minX, isBased: false) + halfTimeInterval
        let startIndexInfo = Keyframe.indexInfo(atTime: startTime,
                                                with: animationView.model.keyframes)
        let startIndex = startIndexInfo.index
        let selectEndX = rect.maxX
        let endTime = animationView.time(withX: selectEndX, isBased: false) + halfTimeInterval
        let endIndexInfo = Keyframe.indexInfo(atTime: endTime,
                                              with: animationView.model.keyframes)
        let endIndex = endIndexInfo.index
        return startIndex == endIndex ?
            [startIndex] :
            Array(startIndex < endIndex ? (startIndex...endIndex) : (endIndex...startIndex))
    }
    private func selectedIndex(from rect: Rect,
                               isDeselect: Bool) -> [Animation<Value>.KeyframeIndex] {
        let selectedIndexes = indexes(from: rect)
        return isDeselect ?
            Array(Set(beginSelectedKeyframeIndexes).subtracting(Set(selectedIndexes))).sorted() :
            Array(Set(beginSelectedKeyframeIndexes).union(Set(selectedIndexes))).sorted()
    }
    
}
extension AnimationView: Assignable {
    func reset(for p: Point, _ version: Version) {
        push(defaultModel, to: version)
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
extension AnimationView: Newable {
    func new(for p: Point, _ version: Version) {
        _ = splitKeyframe(withTime: time(withX: p.x), version)
    }
    func splitKeyframe(withTime time: Rational, _ version: Version) -> Bool {
        guard time < model.duration else {
            return false
        }
        let ii = Keyframe.indexInfo(atTime: time, with: model.keyframes)
        guard ii.interTime > 0 else {
            return false
        }
        let keyframe = model.keyframes[ii.index]
        let newEaing = ii.duration != 0 ?
            keyframe.timing.easing.split(with: Real(ii.interTime / ii.duration)) :
            (b0: keyframe.timing.easing, b1: Easing())
        var splitKeyframe0 = keyframe, splitKeyframe1 = keyframe
        splitKeyframe0.timing.easing = newEaing.b0
        splitKeyframe1.timing.time = time
        splitKeyframe1.timing.label = keyframe.value.defaultLabel
        splitKeyframe1.timing.easing = newEaing.b1
        pushReplace(splitKeyframe0, at: ii.index, version)
        pushInsert(splitKeyframe1, at: ii.index + 1, version)
        let indexes = model.selectedKeyframeIndexes
        for (i, index) in indexes.enumerated() {
            if index >= ii.index {
                let movedIndexes = indexes.map { $0 > ii.index ? $0 + 1 : $0 }
                let intertedIndexes = index == ii.index ?
                    movedIndexes.withInserted(index + 1, at: i + 1) : movedIndexes
                pushSelectedKeyframeIndexes(intertedIndexes, to: version)
                break
            }
        }
        return true
    }
    
    func pushInsert(_ keyframe: Keyframe<Value>,
                    at index: Animation<Value>.KeyframeIndex, _ version: Version) {
        version.registerUndo(withTarget: self) { [unowned version] in
            $0.pushRemove(at: index, version)
        }
        model.keyframes.insert(keyframe, at: index)
        //insertView
    }
    func pushRemove(at index: Animation<Value>.KeyframeIndex, _ version: Version) {
        version.registerUndo(withTarget: self) {
            [keyframe = model.keyframes[index], unowned version] in
            
            $0.pushInsert(keyframe, at: index, version)
        }
        model.keyframes.remove(at: index)
        //removeView
    }
    func pushReplace(_ keyframe: Keyframe<Value>,
                     at index: Animation<Value>.KeyframeIndex, _ version: Version) {
        version.registerUndo(withTarget: self) {
            [oldKeyframe = model.keyframes[index], unowned version] in
            
            $0.pushReplace(oldKeyframe, at: index, version)
        }
        model.keyframes[index] = keyframe
        //updateView
    }
}
final class AnimationViewPointMover<Value: KeyframeValue, Binder: BinderProtocol> {
    var animationView: AnimationView<Value, Binder>
    var model: Animation<Value> {
        get { return animationView.model }
        set { animationView.model = newValue }
    }
    
    init(animationView: AnimationView<Value, Binder>) {
        self.animationView = animationView
    }
    
    var editingKeyframeIndex: Int?
    
    var oldRealBaseTime = RealBaseTime(0), oldKeyframeIndex: Int?
    var clipDeltaTime = Rational(0), minDeltaTime = Rational(0), oldTime = Rational(0)
    var oldAnimation = Animation<Value>()
    
    func move(for point: Point, pressure: Real,
              time: Second, _ phase: Phase) {
        let p = point
        switch phase {
        case .began:
            oldRealBaseTime = animationView.realBaseTime(withX: p.x)
            if let ki = animationView.nearestKeyframeIndex(at: p), model.keyframes.count > 1 {
                let keyframeIndex = ki > 0 ? ki : 1
                oldKeyframeIndex = keyframeIndex
                moveKeyframe(withDeltaTime: 0, keyframeIndex: keyframeIndex, phase: phase)
            } else {
                oldKeyframeIndex = nil
                moveDuration(withDeltaTime: 0, phase)
            }
        case .changed, .ended:
            let t = animationView.realBaseTime(withX: point.x)
            let fdt = t - oldRealBaseTime + (t - oldRealBaseTime >= 0 ? 0.5 : -0.5)
            let dt = animationView.basedRationalTime(withRealBaseTime: fdt)
            let deltaTime = max(minDeltaTime, dt + clipDeltaTime)
            if let keyframeIndex = oldKeyframeIndex, keyframeIndex < model.keyframes.count {
                moveKeyframe(withDeltaTime: deltaTime, keyframeIndex: keyframeIndex, phase: phase)
            } else {
                moveDuration(withDeltaTime: deltaTime, phase)
            }
        }
    }
    func move(withDeltaTime deltaTime: Rational, keyframeIndex: Int?, _ phase: Phase) {
        if let keyframeIndex = keyframeIndex, keyframeIndex < model.keyframes.count {
            moveKeyframe(withDeltaTime: deltaTime, keyframeIndex: keyframeIndex, phase: phase)
        } else {
            moveDuration(withDeltaTime: deltaTime, phase)
        }
    }
    func moveKeyframe(withDeltaTime deltaTime: Rational,
                      keyframeIndex: Int, phase: Phase) {
        switch phase {
        case .began:
            editingKeyframeIndex = keyframeIndex
            let preTime = model.keyframes[keyframeIndex - 1].timing.time
            let time = model.keyframes[keyframeIndex].timing.time
            clipDeltaTime = animationView.clipDeltaTime(withTime: time + animationView.beginBaseTime)
            minDeltaTime = preTime - time
            oldAnimation = model
            oldTime = time
        case .changed, .ended:
            var nks = oldAnimation.keyframes
            (keyframeIndex..<nks.count).forEach {
                nks[$0].timing.time += deltaTime
            }
            model.keyframes = nks
            model.duration = oldAnimation.duration + deltaTime
            animationView.updateLayout()
        }
    }
    func moveDuration(withDeltaTime deltaTime: Rational, _ phase: Phase) {
        switch phase {
        case .began:
            editingKeyframeIndex = model.keyframes.count
            let preTime = model.keyframes[model.keyframes.count - 1].timing.time
            let time = model.duration
            clipDeltaTime = animationView.clipDeltaTime(withTime: time + animationView.beginBaseTime)
            minDeltaTime = preTime - time
            oldAnimation = model
            oldTime = time
        case .changed, .ended:
            model.duration = oldAnimation.duration + deltaTime
            animationView.updateLayout()
        }
    }
}
