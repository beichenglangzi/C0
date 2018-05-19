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

struct Timeline: Codable {
    var frameRate: FPS
    var duration = Beat(0)
    var baseTimeInterval: Beat
    var editingTime: Beat {
        didSet {
            //tracks -> rootCellGroup
        }
    }
    var rootTrack: TreeTrack
    var soundTrack: SoundTrack
    var tempoTrack: TempoTrack
    var subtitleTrack: SubtitleTrack
    var childrenTrack: Track<CellGroupChildren>
    var materialTracks
    var tracks: [MultipleTrack] = [MultipleTrack()], editTrackIndex: Int = 0,
    var allTracks: [Track]
    var editingTrack: Track {
        return tracks[editingTrackIndex]
    }
    var canvas: Canvas
    var selectedTrackIndexes = [Int]()
    
    init(frameRate: FPS = 60, sound: Sound = Sound(),
         baseTimeInterval: Beat = Beat(1, 16),
         editingTime: Beat = 0, tempoTrack: TempoTrack = TempoTrack(),
         canvas: Canvas = Canvas()) {
        
        self.frameRate = frameRate
        self.baseTimeInterval = baseTimeInterval
        self.editingTime = editingTime
        self.tempoTrack = tempoTrack
        allTracks = []
        self.canvas = canvas
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
    
    var curretEditKeyframeTime: Beat {
        let cut = editCut
        let animation = cut.currentNode.editTrack.animation
        let t = cut.currentTime >= animation.duration ?
            animation.duration : animation.editKeyframe.time
        let cutAnimation = cutTrack.animation
        return 0
    }
    var curretEditKeyframeTimeExpression: Expression {
        let time = curretEditKeyframeTime
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
        
    }
    
    var vtt: Data? {
        var subtitleTuples = [(time: Beat, duration: Beat, subtitle: Subtitle)]()
        cutTrack.keyCuts.enumerated().forEach { (i, cut) in
            let cutTime = cutTrack.animation.time(atLoopFrameIndex: i)
            let lfs = cut.subtitleTrack.animation.loopFrames
            let keySubtitles = cut.subtitleTrack.keySubtitles
            subtitleTuples += lfs.enumerated().map { (li, lf) in
                let subtitle = keySubtitles[lf.index]
                let nextTime = li + 1 < lfs.count ?
                    lfs[li + 1].time : cut.subtitleTrack.animation.duration
                return (lf.time + cutTime, nextTime - lf.time, subtitle)
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
                                                       minModel: Rational(1, 100000), maxModel: 100000,
                                                       modelInterval: 1, isInfinitesimal: true,
                                                       unit: " b")
}
extension Timeline: Referenceable {
    static let name = Text(english: "Timeline", japanese: "タイムライン")
}

/**
 Issue: 複数選択
 Issue: 滑らかなスクロール
 Issue: スクロールの可視性の改善
 */
final class TimelineView<T: BinderProtocol>: View, BindableReceiver {
    typealias Model = Timeline
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var defaultModel = Model()
    
    let frameRateView: DiscreteRealView<Binder>
    let baseTimeIntervalView: DiscreteRationalView<Binder>
    let curretEditKeyframeTimeExpressionView: ExpressionView<Binder>
    let timeRulerView = RulerView()
    let tempoView = DiscreteRealView(model: 120,
                                               option: RealOption(defaultModel: 120,
                                                                        minModel: 1, maxModel: 10000,
                                                                        modelInterval: 1, exp: 1,
                                                                        numberOfDigits: 0, unit: " bpm"),
                                               frame: Rect(x: 0, y: 0,
                                                             width: leftWidth, height: Layout.basicHeight))
    let tempoAnimationClipView = View(isLocked: true)
    let tempoAnimationView = AnimationView(height: defaultSumKeyTimesHeight)
    let soundWaveformView = SoundWaveformView()
    let cutViewsView = View(isLocked: true)
    let classSumAnimationNameView = StringView(text: Text(english: "Sum:", japanese: "合計:"),
                                               font: .small)
    let sumKeyTimesClipView = View(isLocked: true)
    
    static let defaultTimeHeight = Layout.basicHeight
    static let defaultSumKeyTimesHeight = 18.0.cg
    var baseWidth = 6.0.cg {
        didSet {
            sumKeyTimesView.baseWidth = baseWidth
            tempoAnimationView.baseWidth = baseWidth
            soundWaveformView.baseWidth = baseWidth
            cutViews.forEach { $0.baseWidth = baseWidth }
            updateWith(time: time, scrollPoint: Point(x: x(withTime: time), y: _scrollPoint.y))
        }
    }
    private let timeHeight = defaultTimeHeight
    private let timeRulerHeight = Layout.smallHeight
    private let tempoHeight = defaultSumKeyTimesHeight
    private let subtitleHeight = 24.0.cg, soundHeight = 20.0.cg
    private let sumKeyTimesHeight = defaultSumKeyTimesHeight
    private let knobHalfHeight = 8.0.cg, subKnobHalfHeight = 4.0.cg, maxLineHeight = 3.0.cg
    private(set) var maxScrollX = 0.0.cg, cutHeight = 0.0.cg
    static let leftWidth = 80.0.cg
    let timeView: View = {
        let view = View(isLocked: true)
        view.fillColor = .editing
        view.lineColor = nil
        return view
    } ()
    let beatsView = View(path: CGMutablePath())

    init(binder: Binder, keyPath: BinderKeyPath,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        frameRateView = DiscreteRealView(binder: binder,
                                         keyPath: keyPath.appending(path: \Model.frameRate),
                                         option: Model.frameRateOption,
                                         frame: Layout.valueFrame(with: .small), sizeType: .small)
        baseTimeIntervalView = DiscreteRationalView(binder: binder,
                                                    keyPath: keyPath.appending(path: \Model.baseTimeInterval),
                                                    option: Model.baseTimeIntervalOption,
                                                    frame: Layout.valueFrame(with: .regular),
                                                    sizeType: sizeType)
        
        super.init()
        children = [timeView, curretEditKeyframeTimeExpressionView,
                    beatsView, classSumAnimationNameView, sumKeyTimesClipView,
                    timeRulerView,
                    tempoAnimationClipView, baseTimeIntervalView,
                    nodeTreeView.nodesView, tracksManager.tracksView,
                    cutViewsView]
        
        baseTimeIntervalView.binding = { [unowned self] in
            switch $0.phase {
            case .began:
                self.baseTimeIntervalOldTime = self.model.secondTime(withBeatTime: self.model.editingTime)
            case .changed, .ended:
                self.baseTimeInterval = $0.model
                self.updateWith(time: self.time,
                                scrollPoint: Point(x: self.x(withTime: self.time), y: 0),
                                isIntervalScroll: false)
                self.updateWithTime()
            }
        }

        sumKeyTimesView.setKeyframeClosure = { [unowned self] binding in
            guard binding.phase == .ended else {
                return
            }
            self.isUpdateSumKeyTimes = false
            let cutIndex = self.movingCutIndex(withTime: binding.keyframe.time)
            let cutView = self.cutViews[cutIndex]
            let cutTime = self.model.cutTrack.animation.time(atLoopFrameIndex: cutIndex)
            switch binding.setType {
            case .insert:
                _ = self.tempoAnimationView.splitKeyframe(withTime: binding.keyframe.time)
                cutView.animationViews.forEach {
                    _ = $0.splitKeyframe(withTime: binding.keyframe.time - cutTime)
                }
            case .remove:
                _ = self.tempoAnimationView.deleteKeyframe(withTime: binding.keyframe.time)
                cutView.animationViews.forEach {
                    _ = $0.deleteKeyframe(withTime: binding.keyframe.time - cutTime)
                }
                self.updateSumKeyTimesView()
            case .replace:
                break
            }
            self.isUpdateSumKeyTimes = true
        }
    }
    
    override func updateLayout() {
        let sp = Layout.basicPadding
        mainHeight = bounds.height - timeRulerHeight - sumKeyTimesHeight - sp * 2
        cutHeight = mainHeight - tempoHeight - subtitleHeight - soundHeight
        let midX = bounds.midX, leftWidth = TimelineView.leftWidth
        let rightX = leftWidth
        timeRulerView.frame = Rect(x: rightX, y: bounds.height - timeRulerHeight - sp,
                                 width: bounds.width - rightX - sp, height: timeRulerHeight)
        curretEditKeyframeTimeView.frame.origin = Point(x: rightX - curretEditKeyframeTimeView.frame.width - Layout.smallPadding,
                                         y: bounds.height - timeRulerHeight
                                            - Layout.basicPadding + Layout.smallPadding)
        tempoAnimationClipView.frame = Rect(x: rightX,
                                         y: bounds.height - timeRulerHeight - tempoHeight - sp,
                                         width: bounds.width - rightX - sp, height: tempoHeight)
        let tracksHeight = 30.0.cg
        tracksManager.tracksView.frame = Rect(x: sp, y: sumKeyTimesHeight + sp,
                                                width: leftWidth - sp,
                                                height: tracksHeight)
        nodeTreeView.nodesView.frame = Rect(x: sp, y: sumKeyTimesHeight + sp + tracksHeight,
                                              width: leftWidth - sp,
                                              height: cutHeight - tracksHeight)
        cutViewsView.frame = Rect(x: rightX, y: sumKeyTimesHeight + sp,
                                   width: bounds.width - rightX - sp,
                                   height: mainHeight - tempoHeight)
        classSumAnimationNameView.frame.origin = Point(x: rightX - classSumAnimationNameView.frame.width,
                                        y: sp + (sumKeyTimesHeight - classSumAnimationNameView.frame.height) / 2)
        sumKeyTimesClipView.frame = Rect(x: rightX, y: sp,
                                      width: bounds.width - rightX - sp, height: sumKeyTimesHeight)
        timeView.frame = Rect(x: midX - baseWidth / 2, y: sp,
                                 width: baseWidth, height: bounds.height - sp * 2)
        beatsView.frame = Rect(x: rightX, y: 0,
                                  width: bounds.width - rightX, height: bounds.height)
        let bx = sp + (sumKeyTimesHeight - baseTimeIntervalView.frame.height) / 2
        baseTimeIntervalView.frame.origin = Point(x: sp, y: bx)
    }
    func updateWithModel() {
        _scrollPoint.x = x(withTime: model.editingTime)
        _intervalScrollPoint.x = x(withTime: time(withLocalX: _scrollPoint.x))
        cutViews = self.cutViews(with: model)
        editCutView.isEdit = true
        
    }

    private var _scrollPoint = Point(), _intervalScrollPoint = Point()
    var scrollPoint: Point {
        get {
            return _scrollPoint
        }
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
        get {
            return model.editingTime
        }
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
        _intervalScrollPoint = isIntervalScroll ? intervalScrollPoint(with: _scrollPoint) : scrollPoint

        let cvi = model.cutTrack.animation.indexInfo(withTime: time)
        if alwaysUpdateCutIndex || model.editCutIndex != cvi.loopFrameIndex {
            editCutView.isEdit = false
            self.editCutIndex = cvi.loopFrameIndex
            editCutView.isEdit = true
        }
        
        
        if time != model.editingTime {
            model.editingTime = time
            
        }
        updateWithScrollPosition()
        updateView(isCut: true, isTransform: true, isKeyframe: true)
    }
    var updateViewClosure: (((isCut: Bool, isTransform: Bool, isKeyframe: Bool)) -> ())?
    private func updateView(isCut: Bool, isTransform: Bool, isKeyframe: Bool) {
        if isKeyframe {
            updateKeyframeView()
//            curretEditKeyframeTimeView.rational = model.curretEditKeyframeTime
            tempoView.model = model.tempoTrack.editingTempo
        }
        if isCut {
            nodeTreeView.cut = model.editCut
            tracksManager.node = model.currentNode
            nodeView.node = model.currentNode
        }
        updateViewClosure?((isCut, isTransform, isKeyframe))
    }
    func updateTime(withCutTime cutTime: Beat) {
        let time = cutTime + model.cutTrack.animation.time(atLoopFrameIndex: model.editCutIndex)
        _scrollPoint.x = x(withTime: time)
        self.time = time
    }
    private func intervalScrollPoint(with scrollPoint: Point) -> Point {
        return Point(x: x(withTime: time(withLocalX: scrollPoint.x)), y: 0)
    }
    
    private func updateWithScrollPosition() {
        let minX = localDeltaX
        _ = cutViews.reduce(minX) { x, cutView in
            cutView.frame.origin = Point(x: x, y: 0)

            cutView.subtitleAnimationView.frame.origin = Point(x: x, y: cutView.frame.height)
            _ = cutView.subtitleStringViews.reduce(x) {
                $1.frame.size = Size(width: 100, height: Layout.basicHeight)
                $1.frame.origin = Point(x: $0, y: cutView.frame.height + cutView.subtitleAnimationView.frame.height)
                return $0 + $1.frame.width
            }

            if !(cutView.frame.minX > bounds.maxX && cutView.frame.maxX < bounds.minX) {
                let sp = Layout.smallPadding
                if cutView.frame.minX < bounds.minX {
                    let nw = cutView.classNameView.frame.width + sp
                    if bounds.minX + nw > cutView.frame.maxX {
                        cutView.nameX = cutView.frame.width - nw
                    } else {
                        cutView.nameX = bounds.minX + sp - cutView.frame.minX
                    }
                } else {
                    cutView.nameX = sp
                }
            }

            return x + cutView.frame.width
        }
        soundWaveformView.frame.origin = Point(x: minX, y: cutViewsView.frame.height - soundWaveformView.frame.height)
        tempoAnimationView.frame.origin = Point(x: minX, y: 0)
        sumKeyTimesView.frame.origin.x = minX
        updateBeats()
        updateTimeRuler()
    }
    
    func bindedCutView(with cut: Cut, beginBaseTime: Beat = 0, height: Real) -> CutView {
        let cutView = CutView(cut,
                              beginBaseTime: beginBaseTime,
                              baseWidth: baseWidth,
                              baseTimeInterval: baseTimeInterval,
                              knobHalfHeight: knobHalfHeight,
                              subKnobHalfHeight: subKnobHalfHeight,
                              maxLineWidth: maxLineHeight, height: height)

        cutView.animationViews.enumerated().forEach { (i, animationView) in
            let nodeAndTrack = cutView.cut.nodeAndTrack(atNodeAndTrackIndex: i)
            bind(in: animationView, in: cutView, from: nodeAndTrack)
        }
        cutView.pasteClosure = { [unowned self] in
            if let index = self.cutViews.index(of: $0) {
                for object in $1 {
                    if let cut = object as? Cut {
                        self.paste(cut.copied, at: index + 1)
                        return
                    }
                }
            }
        }
        cutView.deleteClosure = { [unowned self] in
            if let index = self.cutViews.index(of: $0) {
                self.removeCut(at: index)
            }
        }
        cutView.scrollClosure = { [unowned self, unowned cutView] obj in
            if obj.phase == .ended {
                if obj.nodeAndTrack != obj.oldNodeAndTrack {
                    self.registerUndo(time: self.time) {
                        self.set(obj.oldNodeAndTrack, old: obj.nodeAndTrack, in: cutView, time: $1)
                    }
                    self.
                }
            }
            if cutView.cut == self.nodeTreeView.cut {
                self.nodeTreeView.updateWithNodes()
                self.tracksManager.node = cutView.cut.currentNode
                self.tracksManager.updateWithTracks(isAlwaysUpdate: true)
                self.setNodeAndTrackBinding?(self, cutView, obj.nodeAndTrack)
            }
        }
        cutView.subtitleKeyframeBinding = { [unowned self] _ in
            var subtitleStringViews = [View]()
            self.cutViews.forEach { subtitleStringViews += $0.subtitleStringViews as [View] }
            self.cutViewsView.children = self.cutViews.reversed() as [View]
                + self.cutViews.map { $0.subtitleAnimationView } as [View] + subtitleStringViews as [View] + [self.soundWaveformView] as [View]
            self.updateWithScrollPosition()
        }
        cutView.subtitleBinding = { [unowned self] _ in
            self.updateWithScrollPosition()
        }
        return cutView
    }
    var setNodeAndTrackBinding: ((TimelineView, CutView, Cut.NodeAndTrack) -> ())?

    func bind(in animationView: AnimationView, in cutView: CutView,
              from nodeAndTrack: Cut.NodeAndTrack) {
        animationView.setKeyframeClosure = { [unowned self, unowned cutView] in
            guard $0.phase == .ended else {
                return
            }
            switch $0.setType {
            case .insert:
                self.insert($0.keyframe, at: $0.index, in: nodeAndTrack.track, in: nodeAndTrack.node,
                            in: $0.animationView, in: cutView)
            case .remove:
                self.removeKeyframe(at: $0.index,
                                    in: nodeAndTrack.track, in: nodeAndTrack.node,
                                    in: $0.animationView, in: cutView, time: self.time)
            case .replace:
                self.replace($0.keyframe, at: $0.index,
                             in: nodeAndTrack.track,
                             in: $0.animationView, in: cutView, time: self.time)
            }
        }
        animationView.slideClosure = { [unowned self, unowned cutView] in
            self.setAnimation(with: $0, in: nodeAndTrack.track, in: nodeAndTrack.node, in: cutView)
        }
        animationView.selectClosure = { [unowned self, unowned cutView] in
            self.setAnimation(with: $0, in: nodeAndTrack.track, in: cutView)
        }
    }

    func updateTimeRuler() {
        let minTime = time(withLocalX: convertToLocalX(bounds.minX + TimelineView.leftWidth))
        let maxTime = time(withLocalX: convertToLocalX(bounds.maxX))
        let minSecond = Int(floor(model.secondTime(withBeatTime: minTime)))
        let maxSecond = Int(ceil(model.secondTime(withBeatTime: maxTime)))
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
                                             y: Layout.smallPadding)
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
        let minTime = time(withLocalX: convertToLocalX(bounds.minX + TimelineView.leftWidth))
        let maxTime = time(withLocalX: convertToLocalX(bounds.maxX))
        let intMinTime = floor(minTime).integralPart, intMaxTime = ceil(maxTime).integralPart
        guard intMinTime < intMaxTime else {
            beatsView.path = nil
            return
        }
        let padding = Layout.basicPadding
        let rects: [Rect] = (intMinTime...intMaxTime).map {
            let i0x = x(withDoubleBeatTime: RealBeat($0)) + minX
            let w = beatsPerBar != 0 && $0 % beatsPerBar == 0 ? barLineWidth : beatsLineWidth
            return Rect(x: i0x - w / 2, y: padding, width: w, height: bounds.height - padding * 2)
        }
        let path = CGMutablePath()
        path.addRects(rects)
        beatsView.path = path
    }

    func time(withLocalX x: Real, isBased: Bool = true) -> Beat {
        return isBased ?
            model.baseTimeInterval * Beat(Int(round(x / baseWidth))) :
            model.basedBeatTime(withDoubleBeatTime:
                RealBeat(x / baseWidth) * RealBeat(model.baseTimeInterval))
    }
    func x(withTime time: Beat) -> Real {
        return model.realBeatTime(withBeatTime: time / model.baseTimeInterval) * baseWidth
    }
    func realBeatTime(withLocalX x: Real, isBased: Bool = true) -> RealBeat {
        return RealBeat(isBased ? round(x / baseWidth) : x / baseWidth)
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
    func cutIndex(withLocalX x: Real) -> Int {
        return model.cutTrack.animation.keyframeIndex(atTime: time(withLocalX: x))
    }
    func cutIndex(withTime time: Beat) -> Int {
        return model.cutTrack.animation.keyframeIndex(atTime: time)
    }
    func movingCutIndex(withTime time: Beat) -> Int {
        return model.cutTrack.animation.movingKeyframeIndex(withTime: time)
    }
    var editX: Real {
        return bounds.midX - TimelineView.leftWidth
    }
    var localDeltaX: Real {
        return editX - _intervalScrollPoint.x
    }
    func convertToLocalX(_ x: Real) -> Real {
        return x - TimelineView.leftWidth - localDeltaX
    }
    func convertFromLocalX(_ x: Real) -> Real {
        return x - TimelineView.leftWidth + localDeltaX
    }
    func convertToLocal(_ p: Point) -> Point {
        return Point(x: convertToLocalX(p.x), y: p.y)
    }
    func convertFromLocal(_ p: Point) -> Point {
        return Point(x: convertFromLocalX(p.x), y: p.y)
    }
    func nearestKeyframeIndexTuple(at p: Point) -> (cutIndex: Int, keyframeIndex: Int?) {
        let ci = cutIndex(withLocalX: p.x)
        let cut = model.cuts[ci], ct = model.cuts[ci].currentTime
        guard cut.currentNode.editTrack.animation.keyframes.count > 0 else {
            fatalError()
        }
        var minD = Real.infinity, minI = 0
        for (i, k) in cut.currentNode.editTrack.animation.keyframes.enumerated() {
            let x = self.x(withTime: ct + k.time)
            let d = abs(p.x - x)
            if d < minD {
                minI = i
                minD = d
            }
        }
        let x = self.x(withTime: ct + cut.duration)
        let d = abs(p.x - x)
        if d < minD {
            return (ci, nil)
        } else if minI == 0 && ci > 0 {
            return (ci - 1, nil)
        } else {
            return (ci, minI)
        }
    }
    func trackIndexTuple(at p: Point) -> (cutIndex: Int, trackIndex: Int, keyframeIndex: Int?) {
        let ci = cutIndex(withLocalX: p.x)
        let cut = model.cuts[ci], ct = model.cutTrack.animation.keyframes[ci].time
        var minD = Real.infinity, minKeyframeIndex = 0, minTrackIndex = 0
        for (ii, track) in cut.currentNode.tracks.enumerated() {
            for (i, k) in track.animation.keyframes.enumerated() {
                let x = self.x(withTime: ct + k.time)
                let d = abs(p.x - x)
                if d < minD {
                    minTrackIndex = ii
                    minKeyframeIndex = i
                    minD = d
                }
            }
        }
        let x = self.x(withTime: ct + cut.duration)
        let d = abs(p.x - x)
        if d < minD {
            return (ci, minTrackIndex, nil)
        } else if minKeyframeIndex == 0 && ci > 0 {
            return (ci - 1, minTrackIndex, nil)
        } else {
            return (ci,  minTrackIndex, minKeyframeIndex)
        }
    }

    var baseTimeInterval = Beat(1, 16) {
        didSet {
            sumKeyTimesView.baseTimeInterval = baseTimeInterval
            tempoAnimationView.baseTimeInterval = baseTimeInterval
            soundWaveformView.baseTimeInterval = baseTimeInterval
            cutViews.forEach { $0.baseTimeInterval = baseTimeInterval }
            updateCutViewPositions()
            baseTimeIntervalView.model = baseTimeInterval

            model.baseTimeInterval = baseTimeInterval
            
        }
    }

    private var isUpdateSumKeyTimes = true
    private var moveAnimationViews = [(animationView: AnimationView, keyframeIndex: Int?)]()
    private func setAnimations(with obj: AnimationView.SlideBinding) {
        switch obj.phase {
        case .began:
            isUpdateSumKeyTimes = false
            let cutIndex = movingCutIndex(withTime: obj.oldTime)
            let cutView = self.cutViews[cutIndex]
            let time = obj.oldTime - model.cutTrack.animation.time(atLoopFrameIndex: cutIndex)
            moveAnimationViews = []
            cutView.animationViews.forEach {
                let s = $0.movingKeyframeIndex(atTime: time)
                if s.isSolution && (s.index != nil ? s.index! > 0 : true) {
                    moveAnimationViews.append(($0, s.index))
                }
            }
            let ts = tempoAnimationView.movingKeyframeIndex(atTime: obj.oldTime)
            if ts.isSolution {
                moveAnimationViews.append((tempoAnimationView, ts.index))
            }

            moveAnimationViews.forEach {
                $0.animationView.move(withDeltaTime: obj.deltaTime,
                                      keyframeIndex: $0.keyframeIndex, obj.phase)
            }
        case .changed:
            moveAnimationViews.forEach {
                $0.animationView.move(withDeltaTime: obj.deltaTime,
                                      keyframeIndex: $0.keyframeIndex, obj.phase)
            }
        case .ended:
            moveAnimationViews.forEach {
                $0.animationView.move(withDeltaTime: obj.deltaTime,
                                      keyframeIndex: $0.keyframeIndex, obj.phase)
            }
            moveAnimationViews = []
            isUpdateSumKeyTimes = true
        }
    }

    private var isScrollTrack = false
    private weak var scrollCutView: CutView?
    func scroll(for p: Point, time: Second, scrollDeltaPoint: Point,
                phase: Phase, momentumPhase: Phase?) {
        if phase == .began {
            isScrollTrack = abs(scrollDeltaPoint.x) < abs(scrollDeltaPoint.y)
        }
        if isScrollTrack {
            if phase == .began {
                scrollCutView = editCutView
            }
            scrollCutView?.scrollTrack(for: p, time: time, scrollDeltaPoint: scrollDeltaPoint,
                                       phase: phase, momentumPhase: momentumPhase)
        } else {
            scrollTime(for: p, time: time, scrollDeltaPoint: scrollDeltaPoint,
                       phase: phase, momentumPhase: momentumPhase)
        }
    }

    private var indexScrollDeltaPosition = Point(), indexScrollBeginX = 0.0.cg
    private var indexScrollIndex = 0, indexScrollWidth = 14.0.cg
    func indexScroll(for p: Point, time: Second, scrollDeltaPoint: Point,
                     phase: Phase, momentumPhase: Phase?) {
        guard momentumPhase == nil else {
            return
        }
        switch phase {
        case .began:
            indexScrollDeltaPosition = Point()
            indexScrollIndex = currentAllKeyframeIndex
        case .changed, .ended:
            indexScrollDeltaPosition += scrollDeltaPoint
            let di = Int(-indexScrollDeltaPosition.x / indexScrollWidth)
            currentAllKeyframeIndex = indexScrollIndex + di
        }
    }
    var currentAllKeyframeIndex: Int {
        get {
            var index = 0
            for cut in model.cuts {
                if cut == model.editCut {
                    break
                }
                index += cut.currentNode.editTrack.animation.loopFrames.count
            }
            index += model.currentNode.editTrack.animation.currentLoopframeIndex
            return model.editingTime == model.duration ? index + 1 : index
        }
        set {
            guard newValue != currentAllKeyframeIndex else {
                return
            }
            var index = 0
            for (cutIndex, cut) in model.cuts.enumerated() {
                let animation = cut.currentNode.editTrack.animation
                let newIndex = index + animation.keyframes.count
                if newIndex > newValue {
                    let i = (newValue - index).clip(min: 0, max: animation.loopFrames.count - 1)
                    let cutTime = model.cutTrack.animation.time(atLoopFrameIndex: cutIndex)
                    updateNoIntervalWith(time: cutTime + animation.loopFrames[i].time)
                    return
                }
                index = newIndex
            }
            updateNoIntervalWith(time: model.duration)
        }
    }
    var maxAllKeyframeIndex: Int {
        return model.cuts.reduce(0) { $0 + $1.currentNode.editTrack.animation.loopFrames.count }
    }

    func scrollTime(for p: Point, time: Second, scrollDeltaPoint: Point,
                    phase: Phase, momentumPhase: Phase?) {
        let maxX = self.x(withTime: model.duration)
        let x = (scrollPoint.x - scrollDeltaPoint.x).clip(min: 0, max: maxX)
        scrollPoint = Point(x: phase == .began ?
            self.x(withTime: self.time(withLocalX: x)) : x, y: 0)
    }
}
extension TimelineView: Localizable {
    func update(with locale: Locale) {
        updateLayout()
    }
}
extension TimelineView: ViewQueryable {
    static var referenceableType: Referenceable.Type {
        return Model.self
    }
    static var viewDescription: Text {
        return Text(english: "Select time: Left and right scroll\nSelect track: Up and down scroll",
                    japanese: "時間選択: 左右スクロール\nトラック選択: 上下スクロール")
    }
}
extension TimelineView: Assignable {
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
        get  {
            return scrollView.frame.origin
        }
        set {
            scrollView.frame.origin = newValue
        }
    }
    var scrollFrame = Rect()
    
    var scaleStringViews = [TextFormView]() {
        didSet {
            scrollView.children = scaleStringViews
        }
    }
}
