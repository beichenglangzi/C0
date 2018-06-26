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

import struct Foundation.Data

struct Timeline: Codable {
    var frameRate: Real
    var duration = Rational(0)
    var baseTimeInterval: Rational
    var editingTime: Rational
    var allTracks: [Animation<Drawing>]
    var editingLinesTrackIndex: Array<Animation<Drawing>>.Index
    var canvas: Canvas
    
    var editingTrack: Animation<Drawing> {
        get { return allTracks[editingLinesTrackIndex] }
        set { allTracks[editingLinesTrackIndex] = newValue }
    }
    var editingDrawing: Drawing {
        get { return editingTrack.editingKeyframe.value }
        set { editingTrack.editingKeyframe.value = newValue }
    }
    
    init(frameRate: Real = 60,
         baseTimeInterval: Rational = Rational(1, 16),
         editingTime: Rational = 0,
         canvas: Canvas = Canvas()) {
        
        self.frameRate = frameRate
        self.baseTimeInterval = baseTimeInterval
        self.editingTime = editingTime
        editingLinesTrackIndex = 0
        let keyframe = Keyframe(value: Drawing(), timing: Timing())
        let animation = Animation(keyframes: [keyframe],
                                  beginTime: 0, duration: 1,
                                  editingKeyframeIndex: 0, selectedKeyframeIndexes: [])
        allTracks = [animation]
        self.canvas = canvas
    }
}
extension Timeline {    
    var maxDurationFromTracks: Rational {
        return allTracks.reduce(Rational(0)) { max($0, $1.duration) }
    }
    
    func time(withFrameTime frameTime: Int) -> Rational {
        if let intFrameRate = Int(exactly: frameRate) {
            return Rational(frameTime, intFrameRate)
        } else {
            return Rational(Real(frameTime) / frameRate)
        }
    }
    func time(withFrameTime frameTime: Int) -> Real {
        return Real(frameTime) / frameRate
    }
    func frameTime(withTime time: Rational) -> Int {
        return Int(Real(time) * frameRate)
    }
    func frameTime(withTime time: Real) -> Int {
        return Int(time * frameRate)
    }
    func time(withBaseTime baseTime: Rational) -> Rational {
        return baseTime * baseTimeInterval
    }
    func baseTime(withTime time: Rational) -> Rational {
        return time / baseTimeInterval
    }
    func basedTime(withTime time: Real) -> Rational {
        return Rational(Int(time / Real(baseTimeInterval))) * baseTimeInterval
    }
    func basedTime(withRealBaseTime realBaseTime: Real) -> Rational {
        return Rational(Int(realBaseTime)) * baseTimeInterval
    }
    func realBaseTime(withTime time: Rational) -> Real {
        return Real(time / baseTimeInterval)
    }
    func clipDeltaTime(withTime time: Rational) -> Rational {
        let ft = baseTime(withTime: time)
        let fft = ft + Rational(1, 2)
        return fft - floor(fft) < Rational(1, 2) ?
            self.time(withBaseTime: ceil(ft)) - time :
            self.time(withBaseTime: floor(ft)) - time
    }
    
    var curretEditingKeyframeTime: Rational {
        return editingTrack.time(atKeyframeIndex: editingTrack.editingKeyframeIndex)
    }
    var curretEditingKeyframeTimeExpression: Expression {
        let time = curretEditingKeyframeTime
        let iap = time.integerAndProperFraction
        return Expression.int(iap.integer) + Expression.rational(iap.properFraction)
    }
    
    var time: (second: Int, frame: Int) {
        let second = Real(editingTime)
        let frameTime = Int(second * frameRate)
        return (Int(second), frameTime - Int(second * frameRate))
    }
    func time(with frameTime: Int) -> (second: Int, frame: Int) {
        let second = Int(Real(frameTime) / frameRate)
        return (second, frameTime - second)
    }
}
extension Timeline {
    static let frameRateOption = RealOption(defaultModel: 24, minModel: 1, maxModel: 1000,
                                            modelInterval: 1, exp: 1,
                                            numberOfDigits: 0, unit: " fps")
    static let baseTimeIntervalOption = RationalOption(defaultModel: Rational(1, 16),
                                                       minModel: Rational(1, 100000),
                                                       maxModel: 100000,
                                                       modelInterval: 1, isInfinitesimal: true,
                                                       unit: " s")
    static let tempoOption = RealOption(defaultModel: 120,
                                        minModel: 1, maxModel: 10000,
                                        modelInterval: 1, exp: 1,
                                        numberOfDigits: 0, unit: " bpm")
}
extension Timeline: Referenceable {
    static let name = Text(english: "Timeline", japanese: "タイムライン")
}
extension Timeline: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect) -> View {
        return "\(duration) b".thumbnailView(withFrame: frame)
    }
}
extension Timeline: AbstractViewable {
    var defaultAbstractConstraintSize: Size {
        return Size(width: 200, height: 70)
    }
    func abstractViewWith<T : BinderProtocol>(binder: T,
                                              keyPath: ReferenceWritableKeyPath<T, Timeline>,
                                              type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return TimelineView(binder: binder, keyPath: keyPath)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath)
        }
    }
}
extension Timeline: ObjectViewable {}

final class TimelineView<T: BinderProtocol>: ModelView, BindableReceiver {//animationsView
    typealias Model = Timeline
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((TimelineView<Binder>, BasicNotification) -> ())]()
    
    var defaultModel = Model()
    
    let frameRateView: DiscreteRealView<Binder>
    let baseTimeIntervalView: DiscreteRationalView<Binder>
    let curretEditKeyframeTimeView: TextFormView
    
    var linesTrackViews: [AnimationView<Drawing, Binder>] {
        didSet {
            linesTracksClipView.children = linesTrackViews
        }
    }
    let linesTracksClipView = View()
    
    var timeRulerView = View()
    var baseWidth = 6.0.cg {
        didSet {
            updateWith(time: time, scrollPoint: Point(x: x(withTime: time), y: _scrollPoint.y))
        }
    }
    private let timeHeight = Layouter.basicHeight
    private let timeRulerHeight = Layouter.smallHeight
    private let tempoHeight = 18.0.cg
    private let subtitleHeight = 24.0.cg, soundHeight = 20.0.cg
    private let sumKeyTimesHeight = 18.0.cg
    private let knobHalfHeight = 8.0.cg, subKnobHalfHeight = 4.0.cg, maxLineHeight = 3.0.cg
    private(set) var maxScrollX = 0.0.cg, cutHeight = 0.0.cg
    private let leftWidth = 80.0.cg
    let timeView: View = {
        let view = View()
        view.fillColor = .editing
        view.lineColor = nil
        return view
    } ()
    let intTimesView = View(path: Path())
    
    var baseTimeIntervalBeginSecondTime: Real?
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        frameRateView = DiscreteRealView(binder: binder,
                                         keyPath: keyPath.appending(path: \Model.frameRate),
                                         option: Model.frameRateOption)
        baseTimeIntervalView
            = DiscreteRationalView(binder: binder,
                                   keyPath: keyPath.appending(path: \Model.baseTimeInterval),
                                   option: Model.baseTimeIntervalOption)
        
        let editingTimeString = binder[keyPath: keyPath]
            .curretEditingKeyframeTimeExpression.displayString
        curretEditKeyframeTimeView = TextFormView(text: Text(editingTimeString))
        
        linesTrackViews = binder[keyPath: keyPath].allTracks.enumerated().map { (i, _) in
            return AnimationView(binder: binder,
                                 keyPath: keyPath.appending(path: \Model.allTracks[i]))
        }
        linesTracksClipView.children = linesTrackViews
        
        super.init(isLocked: false)
        children = [timeView, curretEditKeyframeTimeView,
                    intTimesView, linesTracksClipView]
        
        baseTimeIntervalView.notifications.append({ [unowned self] view, notification in
            self.linesTrackViews.forEach { $0.baseTimeInterval = view.model }
            
            switch notification {
            case .didChange:
                self.updateWith(time: self.time,
                                scrollPoint: Point(x: self.x(withTime: self.time), y: 0),
                                isIntervalScroll: false)
                self.updateWithTime()
            case .didChangeFromPhase(let phase, _):
                switch phase {
                case .began:
                    self.baseTimeIntervalBeginSecondTime = Real(self.model.editingTime)
                case .changed, .ended:
                    guard let beginSecondTime = self.baseTimeIntervalBeginSecondTime else { return }
                    self.time = self.model.basedTime(withTime: beginSecondTime)
                }
            }
        })
    }
    
    var minSize: Size {
        return Size(width: 200, height: 100)
    }
    override func updateLayout() {
        let sp = Layouter.basicPadding
        let midX = bounds.midX
        let rightX = leftWidth
        linesTracksClipView.frame = Rect(x: sp,
                                         y: sp,
                                         width: bounds.width - sp * 2,
                                         height: bounds.height - sp * 2)
        timeView.frame = Rect(x: midX - baseWidth / 2, y: sp,
                              width: baseWidth, height: bounds.height - sp * 2)
        intTimesView.frame = Rect(x: rightX, y: 0,
                               width: bounds.width - rightX, height: bounds.height)
        let btims = baseTimeIntervalView.minSize
        let by = sp + (sumKeyTimesHeight - btims.height) / 2
        baseTimeIntervalView.frame = Rect(origin: Point(x: sp, y: by),
                                          size: btims)
        
        _scrollPoint.x = x(withTime: model.editingTime)
        _intervalScrollPoint.x = x(withTime: self.time(withLocalX: _scrollPoint.x))
        
        var y = linesTracksClipView.bounds.midY
        linesTrackViews.forEach {
            let minSize = $0.minSize
            $0.frame = Rect(origin: Point(x: 0, y: y - minSize.height / 2), size: minSize)
            y -= minSize.height
        }
    }
    func updateWithModel() {
        _scrollPoint.x = x(withTime: model.editingTime)
        _intervalScrollPoint.x = x(withTime: self.time(withLocalX: _scrollPoint.x))
        
        frameRateView.updateWithModel()
        baseTimeIntervalView.updateWithModel()
        
        linesTrackViews = model.allTracks.enumerated().map { (i, _) in
            return AnimationView(binder: binder,
                                 keyPath: keyPath.appending(path: \Model.allTracks[i]))
        }
        updateLayout()
    }
    
    private var _scrollPoint = Point(), _intervalScrollPoint = Point()
    var scrollPoint: Point {
        get { return _scrollPoint }
        set {
            let newTime = self.time(withLocalX: newValue.x)
            if newTime != time {
                updateWith(time: newTime, scrollPoint: newValue)
            } else {
                _scrollPoint = newValue
            }
        }
    }
    var time: Rational {
        get { return model.editingTime }
        set {
            if newValue != model.editingTime {
                updateWith(time: newValue, scrollPoint: Point(x: x(withTime: newValue), y: 0))
            }
        }
    }
    private func updateWithTime() {
        updateWith(time: time, scrollPoint: _scrollPoint)
    }
    private func updateNoIntervalWith(time: Rational) {
        if time != model.editingTime {
            updateWith(time: time, scrollPoint: Point(x: x(withTime: time), y: 0),
                       isIntervalScroll: false)
        }
    }
    private func updateWith(time: Rational, scrollPoint: Point,
                            isIntervalScroll: Bool = true, alwaysUpdateCutIndex: Bool = false) {
        _scrollPoint = scrollPoint
        _intervalScrollPoint = isIntervalScroll ?
            intervalScrollPoint(with: _scrollPoint) : scrollPoint
        
        if time != model.editingTime {
            model.editingTime = time
            
        }
        updateWithScrollPosition()
        updateView(isCut: true, isTransform: true, isKeyframe: true)
    }
    var updateViewClosure: (((isCut: Bool, isTransform: Bool, isKeyframe: Bool)) -> ())?
    private func updateView(isCut: Bool, isTransform: Bool, isKeyframe: Bool) {
        updateViewClosure?((isCut, isTransform, isKeyframe))
    }
    private func intervalScrollPoint(with scrollPoint: Point) -> Point {
        return Point(x: x(withTime: self.time(withLocalX: scrollPoint.x)), y: 0)
    }
    
    private func updateWithScrollPosition() {
        updateIntTimes()
        updateTimeRuler()
    }
    
    func updateTimeRuler() {
        let minTime = self.time(withLocalX: convertToLocalX(bounds.minX + leftWidth))
        let maxTime = self.time(withLocalX: convertToLocalX(bounds.maxX))
        let minSecond = Int(Real(minTime).rounded(.down))
        let maxSecond = Int(Real(maxTime).rounded(.up))
        guard minSecond < maxSecond else {
            timeRulerView.children = []
            return
        }
        timeRulerView.position.x = localDeltaX
        timeRulerView.children = (minSecond...maxSecond).compactMap {
            guard !(maxSecond - minSecond > Int(bounds.width / 40) && $0 % 5 != 0) else {
                return nil
            }
            let timeView = TimelineView.timeView(withSecound: $0)
            timeView.fillColor = nil
            let secondX = x(withTime: model.basedTime(withTime: Real($0)))
            timeView.frame.origin = Point(x: secondX - timeView.frame.width / 2,
                                          y: Layouter.smallPadding)
            return timeView
        }
    }
    static func timeView(withSecound i: Int) -> TextFormView {
        let minute = i / 60
        let second = i - minute * 60
        let string = second < 0 ?
            String(format: "-%d:%02d", minute, -second) :
            String(format: "%d:%02d", minute, second)
        return TextFormView(text: Text(string), font: .small)
    }
    
    let intTimesLineWidth = 1.0.cg, barLineWidth = 3.0.cg, intTimesPerBar = 0
    func updateIntTimes() {
        guard model.baseTimeInterval < 1 else {
            intTimesView.path = Path()
            return
        }
        let minX = localDeltaX
        let minTime = self.time(withLocalX: convertToLocalX(bounds.minX + leftWidth))
        let maxTime = self.time(withLocalX: convertToLocalX(bounds.maxX))
        let intMinTime = floor(minTime).integralPart, intMaxTime = ceil(maxTime).integralPart
        guard intMinTime < intMaxTime else {
            intTimesView.path = Path()
            return
        }
        let padding = Layouter.basicPadding
        let rects: [Rect] = (intMinTime...intMaxTime).map {
            let i0x = x(withTime: Real($0)) + minX
            let w = intTimesPerBar != 0 && $0 % intTimesPerBar == 0 ?
                barLineWidth : intTimesLineWidth
            return Rect(x: i0x - w / 2, y: padding, width: w, height: bounds.height - padding * 2)
        }
        var path = Path()
        path.append(rects)
        intTimesView.path = path
    }
    
    func time(withLocalX x: Real, isBased: Bool = true) -> Rational {
        return isBased ?
            model.baseTimeInterval * Rational(Int((x / baseWidth).rounded())) :
            model.basedTime(withTime:
                Real(x / baseWidth) * Real(model.baseTimeInterval))
    }
    func x(withTime time: Rational) -> Real {
        return Real(time / model.baseTimeInterval) * baseWidth
    }
    func realTime(withLocalX x: Real, isBased: Bool = true) -> Real {
        return Real(isBased ? (x / baseWidth).rounded() : x / baseWidth)
            * Real(model.baseTimeInterval)
    }
    func x(withTime time: Real) -> Real {
        return Real(time * Real(model.baseTimeInterval.inversed!)) * baseWidth
    }
    func realBaseTime(withLocalX x: Real) -> Real {
        return Real(x / baseWidth)
    }
    func localX(withRealBaseTime realBaseTime: Real) -> Real {
        return Real(realBaseTime) * baseWidth
    }
    var editX: Real {
        return bounds.midX - leftWidth
    }
    var localDeltaX: Real {
        return editX - _intervalScrollPoint.x
    }
    func convertToLocalX(_ x: Real) -> Real {
        return x - leftWidth - localDeltaX
    }
    func convertFromLocalX(_ x: Real) -> Real {
        return x - leftWidth + localDeltaX
    }
    func convertToLocal(_ p: Point) -> Point {
        return Point(x: convertToLocalX(p.x), y: p.y)
    }
    func convertFromLocal(_ p: Point) -> Point {
        return Point(x: convertFromLocalX(p.x), y: p.y)
    }
    
    func scroll(for p: Point, time: Real, scrollDeltaPoint: Point,
                phase: Phase, momentumPhase: Phase?) {
        scrollTime(for: p, time: time, scrollDeltaPoint: scrollDeltaPoint,
                   phase: phase, momentumPhase: momentumPhase)
    }
    
    private var indexScrollDeltaPosition = Point(), indexScrollBeginX = 0.0.cg
    private var indexScrollIndex = 0, indexScrollWidth = 14.0.cg
    func indexScroll(for p: Point, time: Real, scrollDeltaPoint: Point,
                     phase: Phase, momentumPhase: Phase?) {
        guard momentumPhase == nil else { return }
        switch phase {
        case .began:
            indexScrollDeltaPosition = Point()
            indexScrollIndex = model.editingTrack.editingKeyframeIndex
        case .changed, .ended:
            indexScrollDeltaPosition += scrollDeltaPoint
            let di = Int(-indexScrollDeltaPosition.x / indexScrollWidth)
            let li = indexScrollIndex + di
            model.editingTime = model.editingTrack.time(atLoopFrameIndex: li)
        }
    }
    
    func scrollTime(for p: Point, time: Real, scrollDeltaPoint: Point,
                    phase: Phase, momentumPhase: Phase?) {
        let maxX = self.x(withTime: model.duration)
        let x = (scrollPoint.x - scrollDeltaPoint.x).clip(min: 0, max: maxX)
        scrollPoint = Point(x: phase == .began ?
            self.x(withTime: self.time(withLocalX: x)) : x, y: 0)
    }
}
