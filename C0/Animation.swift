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

typealias KeyframeIndex = KeyframeTimeCollection.Index

struct LoopFrame: Codable, Hashable {
    var index: KeyframeIndex, time: Rational, isLooping: Bool
}
typealias LoopFrameIndex = Array<LoopFrame>.Index
struct LoopFrameIndexInfo {
    var loopFrameIndex: LoopFrameIndex, keyframeIndex: KeyframeIndex
    var keyframeInternalTime: Rational, keyframeDuration: Rational
}
struct AnimatableTimeInfo {
    var time: Rational
    var isInterpolated: Bool
    var loopframeIndex: LoopFrameIndex, keyframeIndex: KeyframeIndex
    var internalRatio: Real
}

enum Interpolated {
    case step(LoopFrame)
    case linear(LoopFrame, LoopFrame)
    case monospline(LoopFrame, LoopFrame, LoopFrame, LoopFrame)
    case firstMonospline(LoopFrame, LoopFrame, LoopFrame)
    case lastMonospline(LoopFrame, LoopFrame, LoopFrame)
}

protocol Animatable {
    var beginTime: Rational { get }
    var keyframeTimings: KeyframeTimeCollection { get }
    var duration: Rational { get }
    var loopFrames: [LoopFrame] { get }
    var editingKeyframeIndex: KeyframeIndex { get }
    var selectedKeyframeIndexes: [KeyframeIndex] { get }
    func timeInfo(atTime time: Rational) -> AnimatableTimeInfo?
    func interpolation(atLoopFrameIndex li: LoopFrameIndex) -> Interpolated
    func indexInfo(atTime t: Rational) -> LoopFrameIndexInfo?
    func keyframeIndex(atTime t: Rational) -> KeyframeIndex?
    func loopedKeyframeIndex(atTime t: Rational) -> KeyframeIndex?
    func time(atKeyframeIndex index: KeyframeIndex) -> Rational
    func time(atLoopFrameIndex index: LoopFrameIndex) -> Rational
    var lastKeyframeTime: Rational? { get }
    var lastLoopedKeyframeTime: Rational? { get }
}

struct Animation<Value: KeyframeValue>: Codable {
    private var _keyframes: [Keyframe<Value>]
    var loopTimes = [Rational]()
    private var _duration: Rational
    var keyframes: [Keyframe<Value>] {
        get { return _keyframes }
        set {
            _keyframes = newValue
            loopFrames = Animation.loopFrames(with: keyframes, loopTimes: loopTimes,
                                              duration: duration)
        }
    }
    var beginTime: Rational
    var duration: Rational {
        get { return _duration }
        set {
            _duration = newValue
            loopFrames = Animation.loopFrames(with: keyframes, loopTimes: loopTimes,
                                              duration: duration)
        }
    }
    mutating func set(_ keyframes: [Keyframe<Value>], duration: Rational) {
        _keyframes = keyframes
        _duration = duration
        loopFrames = Animation.loopFrames(with: keyframes, loopTimes: loopTimes,
                                          duration: duration)
    }
    
    private(set) var loopFrames: [LoopFrame]
    
    private static func loopFrames(with keyframes: [Keyframe<Value>], loopTimes: [Rational],
                                   duration: Rational) -> [LoopFrame] {
        guard !keyframes.isEmpty else {
            return []
        }
        guard var startLoopTime = loopTimes.first else {
            return keyframes.enumerated().map {
                LoopFrame(index: $0.offset, time: $0.element.time, isLooping: false)
            }
        }
        var loopFrames = [LoopFrame](), oldKeyframeIndex = 0
        var isLoop = false
        for loopTime in loopTimes {
            isLoop = !isLoop
            guard !isLoop else {
                startLoopTime = loopTime
                continue
            }
            
            func keyframeIndex(atTime time: Rational) -> Int {
                for (i, keyframe) in keyframes.enumerated().reversed() {
                    if keyframe.time <= time {
                        return i
                    }
                }
                return 0
            }
            
            let aStartKeyframeIndex = keyframeIndex(atTime: startLoopTime)
            let startKeyframeTime = keyframes[aStartKeyframeIndex].time
            let endKeyframeIndex = keyframeIndex(atTime: loopTime)
            guard aStartKeyframeIndex < endKeyframeIndex else { continue }
            
            for i in oldKeyframeIndex...endKeyframeIndex {
                loopFrames.append(LoopFrame(index: i, time: keyframes[i].time, isLooping: false))
            }
            
            let endTime = endKeyframeIndex < keyframes.count ?
                keyframes[endKeyframeIndex + 1].time : duration
            let startDuration = keyframes[aStartKeyframeIndex + 1].time - startLoopTime
            let endDuration = endTime - keyframes[endKeyframeIndex].time
            var time = loopTime + startDuration
            
            let startKeyframeIndex: Int
            if startLoopTime == startKeyframeTime {
                guard aStartKeyframeIndex + 1 < endKeyframeIndex else { continue }
                startKeyframeIndex = aStartKeyframeIndex + 1
            } else {
                startKeyframeIndex = aStartKeyframeIndex
            }
            while time <= endTime {
                for i in startKeyframeIndex...endKeyframeIndex {
                    loopFrames.append(LoopFrame(index: i, time: time, isLooping: true))
                    time += i == endKeyframeIndex ?
                        endDuration + startDuration :
                        keyframes[i + 1].time - keyframes[i].time
                }
            }
            oldKeyframeIndex = endKeyframeIndex + 1
        }
        for i in oldKeyframeIndex..<keyframes.count {
            loopFrames.append(LoopFrame(index: i, time: keyframes[i].time, isLooping: false))
        }
        return loopFrames
    }
    
    mutating func fit(repeating: Value, with keyframeTimes: [Rational]) {
        if keyframeTimes.count < keyframes.count {
            keyframes = Array(keyframes[..<keyframeTimes.count])
        } else if keyframeTimes.count > keyframes.count {
            keyframes += keyframeTimes[(keyframes.count - 1)...].map {
                Keyframe(value: repeating, time: $0)
            }
        }
    }

    var editingKeyframeIndex: KeyframeIndex
    var editingKeyframe: Keyframe<Value> {
        get { return keyframes[editingKeyframeIndex] }
        set { keyframes[editingKeyframeIndex] = newValue }
    }
    var selectedKeyframeIndexes: [KeyframeIndex]

    init(keyframes: [Keyframe<Value>] = [], beginTime: Rational = 0, duration: Rational = 1,
         editingKeyframeIndex: KeyframeIndex = 0, selectedKeyframeIndexes: [KeyframeIndex] = []) {
        
        _keyframes = keyframes
        self.beginTime = beginTime
        _duration = duration
        loopFrames = Animation.loopFrames(with: keyframes, loopTimes: loopTimes,
                                          duration: duration)
        self.editingKeyframeIndex = editingKeyframeIndex
        self.selectedKeyframeIndexes = selectedKeyframeIndexes
    }
    
    init(repeating: Value, keyframeTimes: [Rational]) {
        self.init(keyframes: keyframeTimes.map { Keyframe(value: repeating, time: $0) })
    }
}
extension Animation: Animatable {
    var keyframeTimings: KeyframeTimeCollection {
        return KeyframeTimeCollection(keyframes: keyframes)
    }
    
    var isEmpty: Bool {
        return keyframes.isEmpty
    }
    
    func timeInfo(atTime time: Rational) -> AnimatableTimeInfo? {
        guard let indexInfo = self.indexInfo(atTime: time) else {
            return nil
        }
        let li1 = indexInfo.loopFrameIndex, internalTime = indexInfo.keyframeInternalTime
        let lf1 = loopFrames[li1]
        if internalTime == 0 || indexInfo.keyframeDuration == 0 || li1 + 1 >= loopFrames.count {
            return AnimatableTimeInfo(time: time,
                                      isInterpolated: false,
                                      loopframeIndex: li1, keyframeIndex: lf1.index,
                                      internalRatio: 0)
        } else {
            let lf2 = loopFrames[li1 + 1]
            return AnimatableTimeInfo(time: time,
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
    func interpolatedValue(with timeInfo: AnimatableTimeInfo) -> Value {
        func value(_ lf: LoopFrame) -> Value {
            return keyframes[lf.index].value
        }
        let li1 = timeInfo.loopframeIndex
        let lf1 = loopFrames[li1]
        guard timeInfo.isInterpolated else {
            return Value.step(value(lf1))
        }
        let lf2 = loopFrames[li1 + 1]
        
        let t = timeInfo.internalRatio
        guard keyframes.count > 2 else {
            return Value.linear(value(lf1), value(lf2), t: t)
        }
        let isUseIndex0 = li1 - 1 >= 0 && loopFrames[li1 - 1].time != lf1.time
        let isUseIndex3 = li1 + 2 < loopFrames.count && loopFrames[li1 + 2].time != lf2.time
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
    
    func interpolation(atLoopFrameIndex li: LoopFrameIndex) -> Interpolated {
        let lf1 = loopFrames[li], lf2 = loopFrames[li + 1]
        guard lf2.time - lf1.time != 0 else {
            return .step(lf1)
        }
        let isUseIndex0 = li - 1 >= 0 && loopFrames[li - 1].time != lf1.time
        let isUseIndex3 = li + 2 < loopFrames.count && loopFrames[li + 2].time != lf2.time
        if isUseIndex0 {
            if isUseIndex3 {
                let lf0 = loopFrames[li - 1], lf3 = loopFrames[li + 2]
                return .monospline(lf0, lf1, lf2, lf3)
            } else {
                let lf0 = loopFrames[li - 1]
                return .lastMonospline(lf0, lf1, lf2)
            }
        } else if isUseIndex3 {
            let lf3 = loopFrames[li + 2]
            return .firstMonospline(lf1, lf2, lf3)
        } else {
            return .linear(lf1, lf2)
        }
    }
    
    func indexInfo(atTime t: Rational) -> LoopFrameIndexInfo? {
        guard let firstLoopFrame = loopFrames.first else {
            return nil
        }
        var oldT = duration
        for i in (0..<loopFrames.count).reversed() {
            let li = loopFrames[i]
            let kt = li.time
            if t >= kt {
                return LoopFrameIndexInfo(loopFrameIndex: i, keyframeIndex: li.index,
                                          keyframeInternalTime: t - kt,
                                          keyframeDuration: oldT - kt)
            }
            oldT = kt
        }
        return LoopFrameIndexInfo(loopFrameIndex: 0, keyframeIndex: 0,
                                  keyframeInternalTime: t - firstLoopFrame.time,
                                  keyframeDuration: oldT - firstLoopFrame.time)
    }
    func keyframeIndex(atTime t: Rational) -> KeyframeIndex? {
        guard t < duration && !keyframes.isEmpty else {
            return nil
        }
        for i in (0..<keyframes.count).reversed() {
            if t >= keyframes[i].time {
                return i
            }
        }
        return 0
    }
    func loopedKeyframeIndex(atTime t: Rational) -> KeyframeIndex? {
        return indexInfo(atTime: t)?.keyframeIndex
    }
    
    func time(atKeyframeIndex index: KeyframeIndex) -> Rational {
        return keyframes[index].time
    }
    func time(atLoopFrameIndex index: LoopFrameIndex) -> Rational {
        return loopFrames[index].time
    }
    var lastKeyframeTime: Rational? {
        return keyframes.last?.time
    }
    var lastLoopedKeyframeTime: Rational? {
        return loopFrames.last?.time
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
    func thumbnailView(withFrame frame: Rect) -> View {
        let text = Text(english: "\(keyframes.count) Keyframes",
                        japanese: "\(keyframes.count)キーフレーム")
        return text.thumbnailView(withFrame: frame)
    }
}
extension Animation: Viewable {
    func standardViewWith<T: BinderProtocol>
        (binder: T, keyPath: ReferenceWritableKeyPath<T, Animation>) -> ModelView {
        
        return AnimationView(binder: binder, keyPath: keyPath)
    }
}
extension Animation: ObjectViewable {}

final class AnimationView<Value: KeyframeValue, T: BinderProtocol>: ModelView, BindableReceiver {
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
    
    var keyframesView: ArrayView<Keyframe<Value>, Binder>
    
    private var knobViews = [View]()
    let editView: View = {
        let view = View()
        view.fillColor = .selected
        view.lineColor = nil
        view.isHidden = true
        return view
    } ()
    let indicatedView: View = {
        let view = View()
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
    
    init(binder: Binder, keyPath: BinderKeyPath,
         beginBaseTime: Rational = 0, baseTimeInterval: Rational = Rational(1, 16),
         origin: Point = Point(),
         height: Real = Layouter.basicHeight, smallHeight: Real = 8.0) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        self.beginBaseTime = beginBaseTime
        self.baseTimeInterval = baseTimeInterval
        self.height = height
        self.smallHeight = smallHeight
        keyframesView = ArrayView(binder: binder,
                                  keyPath: keyPath.appending(path: \Model.keyframes),
                                  viewableType: .standard)
        
        super.init(isLocked: false)
        frame = Rect(x: origin.x, y: origin.y,
                     width: 0, height: height)
        updateLayout()
    }
    
    private static func knobView(from p: Point,
                                 fillColor: Color, lineColor: Color,
                                 baseWidth: Real,
                                 knobHalfHeight: Real, subKnobHalfHeight: Real) -> View {
        let knobView = View.discreteKnob(Size(width: baseWidth, height: knobHalfHeight * 2))
        knobView.position = p
        knobView.fillColor = fillColor
        knobView.lineColor = lineColor
        return knobView
    }
    private static func keyLinePathViewWith(_ keyframe: Keyframe<Value>, lineColor: Color,
                                            baseWidth: Real,
                                            lineWidth: Real, maxLineWidth: Real,
                                            position: Point, width: Real) -> View {
        var path = Path()
        path.append(Rect(x: position.x, y: position.y - lineWidth / 2,
                         width: width, height: lineWidth))
        let view = View(path: path)
        view.fillColor = lineColor
        return view
    }
    
    var minSize: Size {
        return Size(width: x(withTime: model.duration) + baseWidth / 2 + Layouter.basicPadding,
                    height: height)
    }
    override func updateLayout() {
        let height = frame.height
        let midY = height / 2, lineWidth = 2.0.cg
        let khh = knobHalfHeight, skhh = subKnobHalfHeight
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

            let keyLineColor = Color.content
            let keyLine = AnimationView.keyLinePathViewWith(keyframe,
                                                            lineColor: keyLineColor,
                                                            baseWidth: baseWidth,
                                                            lineWidth: lineWidth,
                                                            maxLineWidth: maxLineWidth,
                                                            position: position,
                                                            width: width)
            keyLineViews.append(keyLine)
            
            if i > 0 {
                let fillColor = Color.knob
                let lineColor = ((li.time + beginBaseTime) / baseTimeInterval).isInteger ?
                    Color.getSetBorder : Color.warning
                let knob = AnimationView.knobView(from: position,
                                                  fillColor: fillColor,
                                                  lineColor: lineColor,
                                                  baseWidth: baseWidth,
                                                  knobHalfHeight: li.isLooping ? khh / 2 : khh,
                                                  subKnobHalfHeight: skhh)
                knobViews.append(knob)
            }

            if model.selectedKeyframeIndexes.contains(li.index) {
                let view = View.selection
                view.frame = Rect(x: position.x, y: 0, width: width, height: height)
                selectedViews.append(view)
            } else if li.index >= selectedStartIndex && li.index < selectedEndIndex {
                var path = Path(), h = 2.0.cg
                path.append(Rect(x: position.x, y: 0, width: width, height: h))
                path.append(Rect(x: position.x, y: height - h, width: width, height: h))
                let view = View(path: path)
                view.fillColorComposition = .select
                view.lineColorComposition = .selectBorder
                selectedViews.append(view)
            }
        }

        let maxX = self.x(withTime: model.duration)

        let durationFillColor = Color.knob
        let durationLineColor = ((model.duration + beginBaseTime) / baseTimeInterval).isInteger ?
            Color.getSetBorder : Color.warning
        let durationKnob = AnimationView.knobView(from: Point(x: maxX, y: midY),
                                                  fillColor: durationFillColor,
                                                  lineColor: durationLineColor,
                                                  baseWidth: baseWidth,
                                                  knobHalfHeight: khh,
                                                  subKnobHalfHeight: skhh)
        knobViews.append(durationKnob)
        
        self.knobViews = knobViews
        
        children = [editView, indicatedView] + keyLineViews + knobViews as [View] + selectedViews
    }
    private func updateWithBeginTime() {
        for (i, li) in model.loopFrames.enumerated() {
            if i > 0 {
                let isInteger = ((li.time + beginBaseTime) / baseTimeInterval).isInteger
                knobViews[i - 1].lineColor = isInteger ? .getSetBorder : .warning
            }
        }
        let isInteger = ((model.duration + beginBaseTime) / baseTimeInterval).isInteger
        knobViews.last?.lineColor = isInteger ? .getSetBorder : .warning
    }
    func updateWithModel() {
        updateLayout()
    }
    private func updateWithHeight() {
        frame.size.height = height
        updateLayout()
    }
    
    func time(withBaseTime baseTime: Rational) -> Rational {
        return baseTime * baseTimeInterval
    }
    func baseTime(withRationalTime time: Rational) -> Rational {
        return time / baseTimeInterval
    }
    func basedRationalTime(withRealBaseTime realBaseTime: Real) -> Rational {
        return Rational(Int(realBaseTime)) * baseTimeInterval
    }
    func realBaseTime(withRationalTime time: Rational) -> Real {
        return Real(time / baseTimeInterval)
    }
    func realBaseTime(withX x: Real) -> Real {
        return Real(x / baseWidth)
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
        let fft = ft + Rational(1, 2)
        return fft - floor(fft) < Rational(1, 2) ?
            self.time(withBaseTime: ceil(ft)) - time :
            self.time(withBaseTime: floor(ft)) - time
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
            updateMin(index: i, time: keyframe.time)
        }
        updateMin(index: nil, time: model.duration)
        return minIndex
    }
}
extension AnimationView: Newable {
    func new(for p: Point, _ version: Version) {
        splitKeyframe(withTime: time(withX: p.x), version)
    }
    func splitKeyframe(withTime time: Rational, _ version: Version) {
        guard time < model.duration else { return }
        guard !model.keyframes.isEmpty else { return }
        let ii = Keyframe.indexInfo(atTime: time, with: model.keyframes)
        guard ii.interTime > 0 else { return }
        let keyframe = model.keyframes[ii.index]
        var splitKeyframe0 = keyframe, splitKeyframe1 = keyframe
        splitKeyframe1.time = time
        pushReplace(splitKeyframe0, at: ii.index, version)
        pushInsert(splitKeyframe1, at: ii.index + 1, version)
    }
    
    func pushInsert(_ keyframe: Keyframe<Value>,
                    at index: KeyframeIndex, _ version: Version) {
        version.registerUndo(withTarget: self) { [unowned version] in
            $0.pushRemove(at: index, version)
        }
        model.keyframes.insert(keyframe, at: index)
        //insertView
    }
    func pushRemove(at index: KeyframeIndex, _ version: Version) {
        version.registerUndo(withTarget: self) {
            [keyframe = model.keyframes[index], unowned version] in
            
            $0.pushInsert(keyframe, at: index, version)
        }
        model.keyframes.remove(at: index)
        //removeView
    }
    func pushReplace(_ keyframe: Keyframe<Value>,
                     at index: KeyframeIndex, _ version: Version) {
        version.registerUndo(withTarget: self) {
            [oldKeyframe = model.keyframes[index], unowned version] in
            
            $0.pushReplace(oldKeyframe, at: index, version)
        }
        model.keyframes[index] = keyframe
        //updateView
    }
}
