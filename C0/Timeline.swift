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
    var frameRate: FPS
    var duration = Beat(0)
    var baseTimeInterval: Beat
    var editingTime: Beat
    
    var tempoTrack: TempoTrack
    var subtitleTrack: SubtitleTrack
    
    var allTracks: [AlgebraicTrack]
    var editingLinesTrackIndex: Array<AlgebraicTrack>.Index
    var editingTrackIndex: Array<AlgebraicTrack>.Index
    var editingTrack: AlgebraicTrack {
        return allTracks[editingTrackIndex]
    }
    
    var canvas: Canvas
    
    var selectedTrackIndexes = [Array<AlgebraicTrack>.Index]()
    
    init(frameRate: FPS = 60, sound: Sound = Sound(),
         baseTimeInterval: Beat = Beat(1, 16),
         editingTime: Beat = 0,
         tempoTrack: TempoTrack = TempoTrack(),
         subtitleTrack: SubtitleTrack = SubtitleTrack(),
         canvas: Canvas = Canvas()) {
        
        self.frameRate = frameRate
        self.baseTimeInterval = baseTimeInterval
        self.editingTime = editingTime
        self.tempoTrack = tempoTrack
        self.subtitleTrack = subtitleTrack
        editingLinesTrackIndex = 0
        editingTrackIndex = 0
        allTracks = []
        self.canvas = canvas
    }
}
extension Timeline {    
    var maxDurationFromTracks: Beat {
        return allTracks.reduce(Beat(0)) { max($0, $1.animatable.duration) }
    }
    
    func beatTime(withFrameTime frameTime: FrameTime) -> Beat {
        return Beat(tempoTrack.realBeatTime(withSecondTime: Second(frameTime) / Second(frameRate)))
    }
    func basedBeatTime(withSecondTime secondTime: Second) -> Beat {
        return basedBeatTime(withDoubleBeatTime: tempoTrack.realBeatTime(withSecondTime: secondTime))
    }
    func secondTime(withBeatTime beatTime: Beat) -> Second {
        return tempoTrack.secondTime(withBeatTime: beatTime)
    }
    
    func frameTime(withBeatTime beatTime: Beat) -> FrameTime {
        return FrameTime(secondTime(withBeatTime: beatTime) * Second(frameRate))
    }
    func secondTime(withFrameTime frameTime: FrameTime) -> Second {
        return Second(frameTime) / Second(frameRate)
    }
    func frameTime(withSecondTime secondTime: Second) -> FrameTime {
        return FrameTime(secondTime * Second(frameRate))
    }
    func basedBeatTime(withDoubleBeatTime realBeatTime: RealBeat) -> Beat {
        return Beat(Int(realBeatTime / RealBeat(baseTimeInterval))) * baseTimeInterval
    }
    func realBeatTime(withBeatTime beatTime: Beat) -> RealBeat {
        return RealBeat(beatTime)
    }
    func beatTime(withBaseTime baseTime: BaseTime) -> Beat {
        return baseTime * baseTimeInterval
    }
    func baseTime(withBeatTime beatTime: Beat) -> BaseTime {
        return beatTime / baseTimeInterval
    }
    func basedBeatTime(withRealBaseTime realBaseTime: RealBaseTime) -> Beat {
        return Beat(Int(realBaseTime)) * baseTimeInterval
    }
    func realBaseTime(withBeatTime beatTime: Beat) -> RealBaseTime {
        return RealBaseTime(beatTime / baseTimeInterval)
    }
    func clipDeltaTime(withTime time: Beat) -> Beat {
        let ft = baseTime(withBeatTime: time)
        let fft = ft + BaseTime(1, 2)
        return fft - floor(fft) < BaseTime(1, 2) ?
            beatTime(withBaseTime: ceil(ft)) - time :
            beatTime(withBaseTime: floor(ft)) - time
    }
    
    var curretEditingKeyframeTime: Beat {
        return editingTrack.animatable
            .time(atKeyframeIndex: editingTrack.animatable.editingKeyframeIndex)
    }
    var curretEditingKeyframeTimeExpression: Expression {
        let time = curretEditingKeyframeTime
        let iap = time.integerAndProperFraction
        return Expression.int(iap.integer) + Expression.rational(iap.properFraction)
    }
    
    var secondTime: (second: Int, frame: Int) {
        let second = secondTime(withBeatTime: editingTime)
        let frameTime = FrameTime(second * Second(frameRate))
        return (Int(second), frameTime - Int(second * frameRate))
    }
    func secondTime(with frameTime: FrameTime) -> (second: Int, frame: Int) {
        let second = Int(Real(frameTime) / frameRate)
        return (second, frameTime - second)
    }
    
    var soundTuples: [(sound: Sound, startFrameTime: FrameTime)] {
        return allTracks.reduce(into: [(sound: Sound, startFrameTime: FrameTime)]()) {
            (values, track) in
            
            guard let track = track.soundTrack else { return }
            values += track.animation.loopFrames.map { lf in
                let keyframe = track.animation.keyframes[lf.index]
                return (keyframe.value, frameTime(withBeatTime: keyframe.timing.time))
            }
        }
    }
    
    var vtt: Data? {
        var subtitleTuples = [(subtitle: Subtitle, time: Beat, duration: Beat)]()
        subtitleTuples = allTracks.reduce(into: subtitleTuples) { (values, track) in
            guard let track = track.subtitleTrack else { return }
            let lfs = track.animation.loopFrames
            values += lfs.enumerated().map { (li, lf) in
                let subtitle = track.animation.keyframes[lf.index].value
                let nextTime = li + 1 < lfs.count ?
                    lfs[li + 1].time : track.animation.duration
                return (subtitle, lf.time, nextTime - lf.time)
            }
        }
        return Subtitle.vtt(subtitleTuples, timeClosure: { secondTime(withBeatTime: $0) })
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
                                                       unit: " b")
    static let tempoOption = RealOption(defaultModel: 120,
                                        minModel: 1, maxModel: 10000,
                                        modelInterval: 1, exp: 1,
                                        numberOfDigits: 0, unit: " bpm")
}
extension Timeline: Referenceable {
    static let name = Text(english: "Timeline", japanese: "タイムライン")
}
extension Timeline: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return "\(duration) b".thumbnailView(withFrame: frame, sizeType)
    }
}
extension Timeline: AbstractViewable {
    func abstractViewWith<T : BinderProtocol>(binder: T,
                                              keyPath: ReferenceWritableKeyPath<T, Timeline>,
                                              frame: Rect, _ sizeType: SizeType,
                                              type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return TimelineView(binder: binder, keyPath: keyPath, frame: frame, sizeType: sizeType)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath, frame: frame, sizeType)
        }
    }
}
extension Timeline: ObjectViewable {}

/**
 Issue: 複数選択
 Issue: 滑らかなスクロール
 Issue: スクロールの可視性の改善
 */
final class TimelineView<T: BinderProtocol>: ModelView, BindableReceiver {
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
    let timeRulerView = RulerView()
    
    let tempoAnimationClipView = View(isLocked: true)
    let tempoAnimationView: AnimationView<BPM, Binder>
    let soundWaveformView = SoundWaveformView()
    let cutViewsView = View(isLocked: true)
    let sumAnimationNameView = TextFormView(text: Text(english: "Sum:", japanese: "合計:"),
                                            font: .small)
    let sumKeyTimesClipView = View(isLocked: true)
    
    var baseWidth = 6.0.cg {
        didSet {
            
//            tempoAnimationView.baseWidth = baseWidth
            soundWaveformView.baseWidth = baseWidth
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
        let view = View(isLocked: true)
        view.fillColor = .editing
        view.lineColor = nil
        return view
    } ()
    let beatsView = View(path: Path())
    
    var baseTimeIntervalBeginSecondTime: Second?
    
    init(binder: Binder, keyPath: BinderKeyPath,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        frameRateView = DiscreteRealView(binder: binder,
                                         keyPath: keyPath.appending(path: \Model.frameRate),
                                         option: Model.frameRateOption,
                                         frame: Layouter.valueFrame(with: .small),
                                         sizeType: .small)
        baseTimeIntervalView
            = DiscreteRationalView(binder: binder,
                                   keyPath: keyPath.appending(path: \Model.baseTimeInterval),
                                   option: Model.baseTimeIntervalOption,
                                   frame: Layouter.valueFrame(with: .regular),
                                   sizeType: sizeType)
        
        let editingTimeString = binder[keyPath: keyPath]
            .curretEditingKeyframeTimeExpression.displayString
        curretEditKeyframeTimeView = TextFormView(text: Text(editingTimeString))
        
        tempoAnimationView
            = AnimationView(binder: binder,
                            keyPath: keyPath.appending(path: \Model.tempoTrack.animation),
                            beginBaseTime: 0, baseTimeInterval: baseTimeInterval,
                            origin: Point(), height: timeHeight,
                            smallHeight: sumKeyTimesHeight,
                            sizeType: sizeType)
        
        super.init()
        children = [timeView, curretEditKeyframeTimeView,
                    beatsView, sumAnimationNameView, sumKeyTimesClipView,
                    timeRulerView,
                    tempoAnimationClipView, baseTimeIntervalView,
                    cutViewsView]
        
        baseTimeIntervalView.notifications.append({ [unowned self] in
            switch $1 {
            case .didChange:
                self.updateWith(time: self.time,
                                scrollPoint: Point(x: self.x(withTime: self.time), y: 0),
                                isIntervalScroll: false)
                self.updateWithTime()
            case .didChangeFromPhase(let phase, _):
                switch phase {
                case .began:
                    self.baseTimeIntervalBeginSecondTime
                        = self.model.secondTime(withBeatTime: self.model.editingTime)
                case .changed, .ended:
                    guard let beginSecondTime = self.baseTimeIntervalBeginSecondTime else { return }
                    self.time = self.model.basedBeatTime(withSecondTime: beginSecondTime)
                }
            }
        })
    }
    
    override func updateLayout() {
        let sp = Layouter.basicPadding
        let midX = bounds.midX
        let rightX = leftWidth
        sumKeyTimesClipView.frame = Rect(x: rightX,
                                         y: sp,
                                         width: bounds.width - rightX - sp,
                                         height: sumKeyTimesHeight)
        timeView.frame = Rect(x: midX - baseWidth / 2, y: sp,
                              width: baseWidth, height: bounds.height - sp * 2)
        beatsView.frame = Rect(x: rightX, y: 0,
                               width: bounds.width - rightX, height: bounds.height)
        let bx = sp + (sumKeyTimesHeight - baseTimeIntervalView.frame.height) / 2
        baseTimeIntervalView.frame.origin = Point(x: sp, y: bx)
        
        _scrollPoint.x = x(withTime: model.editingTime)
        _intervalScrollPoint.x = x(withTime: time(withLocalX: _scrollPoint.x))
    }
    func updateWithModel() {
        _scrollPoint.x = x(withTime: model.editingTime)
        _intervalScrollPoint.x = x(withTime: time(withLocalX: _scrollPoint.x))
        
    }
    
    private var _scrollPoint = Point(), _intervalScrollPoint = Point()
    var scrollPoint: Point {
        get { return _scrollPoint }
        set {
            let newTime = time(withLocalX: newValue.x)
            if newTime != time {
                updateWith(time: newTime, scrollPoint: newValue)
            } else {
                _scrollPoint = newValue
            }
        }
    }
    var time: Beat {
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
    private func updateNoIntervalWith(time: Beat) {
        if time != model.editingTime {
            updateWith(time: time, scrollPoint: Point(x: x(withTime: time), y: 0),
                       isIntervalScroll: false)
        }
    }
    private func updateWith(time: Beat, scrollPoint: Point,
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
        return Point(x: x(withTime: time(withLocalX: scrollPoint.x)), y: 0)
    }
    
    private func updateWithScrollPosition() {
        let minX = localDeltaX
        soundWaveformView.frame.origin
            = Point(x: minX, y: cutViewsView.frame.height - soundWaveformView.frame.height)
//        tempoAnimationView.frame.origin = Point(x: minX, y: 0)
        
        updateBeats()
        updateTimeRuler()
    }
    
    func updateTimeRuler() {
        let minTime = time(withLocalX: convertToLocalX(bounds.minX + leftWidth))
        let maxTime = time(withLocalX: convertToLocalX(bounds.maxX))
        let minSecond = Int((model.secondTime(withBeatTime: minTime)).rounded(.down))
        let maxSecond = Int((model.secondTime(withBeatTime: maxTime)).rounded(.up))
        guard minSecond < maxSecond else {
            timeRulerView.scaleStringViews = []
            return
        }
        timeRulerView.scrollPosition.x = localDeltaX
        timeRulerView.scaleStringViews = (minSecond...maxSecond).compactMap {
            guard !(maxSecond - minSecond > Int(bounds.width / 40) && $0 % 5 != 0) else {
                return nil
            }
            let timeView = TimelineView.timeView(withSecound: $0)
            timeView.fillColor = nil
            let secondX = x(withTime: model.basedBeatTime(withSecondTime: Second($0)))
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
    
    let beatsLineWidth = 1.0.cg, barLineWidth = 3.0.cg, beatsPerBar = 0
    func updateBeats() {
        guard baseTimeInterval < 1 else {
            beatsView.path = nil
            return
        }
        let minX = localDeltaX
        let minTime = time(withLocalX: convertToLocalX(bounds.minX + leftWidth))
        let maxTime = time(withLocalX: convertToLocalX(bounds.maxX))
        let intMinTime = floor(minTime).integralPart, intMaxTime = ceil(maxTime).integralPart
        guard intMinTime < intMaxTime else {
            beatsView.path = nil
            return
        }
        let padding = Layouter.basicPadding
        let rects: [Rect] = (intMinTime...intMaxTime).map {
            let i0x = x(withDoubleBeatTime: RealBeat($0)) + minX
            let w = beatsPerBar != 0 && $0 % beatsPerBar == 0 ? barLineWidth : beatsLineWidth
            return Rect(x: i0x - w / 2, y: padding, width: w, height: bounds.height - padding * 2)
        }
        var path = Path()
        path.append(rects)
        beatsView.path = path
    }
    
    func time(withLocalX x: Real, isBased: Bool = true) -> Beat {
        return isBased ?
            model.baseTimeInterval * Beat(Int((x / baseWidth).rounded())) :
            model.basedBeatTime(withDoubleBeatTime:
                RealBeat(x / baseWidth) * RealBeat(model.baseTimeInterval))
    }
    func x(withTime time: Beat) -> Real {
        return model.realBeatTime(withBeatTime: time / model.baseTimeInterval) * baseWidth
    }
    func realBeatTime(withLocalX x: Real, isBased: Bool = true) -> RealBeat {
        return RealBeat(isBased ? (x / baseWidth).rounded() : x / baseWidth)
            * RealBeat(model.baseTimeInterval)
    }
    func x(withDoubleBeatTime realBeatTime: RealBeat) -> Real {
        return Real(realBeatTime * RealBeat(model.baseTimeInterval.inversed!)) * baseWidth
    }
    func realBaseTime(withLocalX x: Real) -> RealBaseTime {
        return RealBaseTime(x / baseWidth)
    }
    func localX(withRealBaseTime realBaseTime: RealBaseTime) -> Real {
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
    
    var baseTimeInterval = Beat(1, 16) {
        didSet {
            
//            tempoAnimationView.baseTimeInterval = baseTimeInterval
            soundWaveformView.baseTimeInterval = baseTimeInterval
            
            baseTimeIntervalView.model = baseTimeInterval
            
            model.baseTimeInterval = baseTimeInterval
            
        }
    }
    
    private var isScrollTrack = false
    private weak var scrollCutView: TrackItemView<Binder>?
    func scroll(for p: Point, time: Second, scrollDeltaPoint: Point,
                phase: Phase, momentumPhase: Phase?) {
        scrollTime(for: p, time: time, scrollDeltaPoint: scrollDeltaPoint,
                   phase: phase, momentumPhase: momentumPhase)
    }
    
    private var indexScrollDeltaPosition = Point(), indexScrollBeginX = 0.0.cg
    private var indexScrollIndex = 0, indexScrollWidth = 14.0.cg
    func indexScroll(for p: Point, time: Second, scrollDeltaPoint: Point,
                     phase: Phase, momentumPhase: Phase?) {
        guard momentumPhase == nil else { return }
        switch phase {
        case .began:
            indexScrollDeltaPosition = Point()
            indexScrollIndex = model.editingTrack.animatable.editingKeyframeIndex
        case .changed, .ended:
            indexScrollDeltaPosition += scrollDeltaPoint
            let di = Int(-indexScrollDeltaPosition.x / indexScrollWidth)
            let li = indexScrollIndex + di
            model.editingTime = model.editingTrack.animatable.time(atLoopFrameIndex: li)
        }
    }
    
    func scrollTime(for p: Point, time: Second, scrollDeltaPoint: Point,
                    phase: Phase, momentumPhase: Phase?) {
        let maxX = self.x(withTime: model.duration)
        let x = (scrollPoint.x - scrollDeltaPoint.x).clip(min: 0, max: maxX)
        scrollPoint = Point(x: phase == .began ?
            self.x(withTime: self.time(withLocalX: x)) : x, y: 0)
    }
}

final class RulerView: View {
    private let scrollView: View = {
        let view = View(isLocked: true)
        view.lineColor = nil
        return view
    } ()
    
    override init() {
        super.init()
        append(child: scrollView)
    }
    
    var scrollPosition: Point {
        get { return scrollView.frame.origin }
        set { scrollView.frame.origin = newValue }
    }
    var scrollFrame = Rect()
    
    var scaleStringViews = [TextFormView]() {
        didSet {
            scrollView.children = scaleStringViews
        }
    }
}
