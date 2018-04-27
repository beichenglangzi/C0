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

/**
 Issue: ノードトラック、ノード、カットの複数選択
 Issue: 滑らかなスクロール
 Issue: sceneを取り除く
 Issue: スクロールの可視性の改善
 */
final class TimelineView: View, Queryable, Assignable, Newable, Scrollable, Zoomable {
    var scene = Scene() {
        didSet {
            _scrollPoint.x = x(withTime: scene.time)
            _intervalScrollPoint.x = x(withTime: time(withLocalX: _scrollPoint.x))
            cutViews = self.cutViews(with: scene)
            editCutView.isEdit = true
            baseTimeInterval = scene.baseTimeInterval
            tempoView.model = scene.tempoTrack.tempoItem.tempo
            tempoAnimationView.animation = scene.tempoTrack.animation
            tempoAnimationView.frame.size.width = maxScrollX
            soundWaveformView.tempoTrack = scene.tempoTrack
            soundWaveformView.sound = scene.sound
            baseTimeIntervalView.model = scene.baseTimeInterval
            updateWith(time: scene.time, scrollPoint: _scrollPoint)
        }
    }
    
    var indicatedTime = 0
    var setEditCutItemIndexClosure: ((TimelineView, Int) -> ())?
    var editCutIndex: Int {
        get {
            return scene.editCutIndex
        }
        set {
            scene.editCutIndex = newValue
            updateView(isCut: false, isTransform: false, isKeyframe: true)
            setEditCutItemIndexClosure?(self, editCutIndex)
        }
    }
    
    var editedKeyframeTime = Beat(0) {
        didSet {
            if editedKeyframeTime != oldValue {
//                let oldFrame = curretEditKeyframeTimeView.frame
//                curretEditKeyframeTimeView.rational = scene.curretEditKeyframeTime
//                curretEditKeyframeTimeView.frame.origin.x = oldFrame.maxX - curretEditKeyframeTimeView.bounds.width
            }
        }
    }
    
    static let defautBaseWidth = 6.0.cg, defaultTimeHeight = Layout.basicHeight
    static let defaultSumKeyTimesHeight = 18.0.cg
    var baseWidth = defautBaseWidth {
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
//    let curretEditKeyframeTimeExpressionView = ExpressionView(sizeType: .small)
    
    let baseTimeIntervalView = DiscreteRationalView(model: Rational(1, 16),
                                                          option: Scene.timeIntervalOption,
                                                          frame: Layout.valueFrame(with: .regular))
    
    let formTimeRulerView = RulerView()
    let tempoView = DiscreteRealView(model: 120,
                                           option: RealOption(defaultModel: 120,
                                                                    minModel: 1, maxModel: 10000,
                                                                    modelInterval: 1, exp: 1,
                                                                    numberOfDigits: 0, unit: " bpm"),
                                           frame: Rect(x: 0, y: 0,
                                                         width: leftWidth, height: Layout.basicHeight))
    let tempoAnimationClipView = View(isForm: true)
    let tempoAnimationView = AnimationView(height: defaultSumKeyTimesHeight)
    let soundWaveformView = SoundWaveformView()
    let cutViewsView = View(isForm: true)
    let classSumAnimationNameView = TextView(text: Text(english: "Sum:", japanese: "合計:"),
                                             font: .small)
    let sumKeyTimesClipView = View(isForm: true)
    let sumKeyTimesView = AnimationView(height: defaultSumKeyTimesHeight)
    
    let nodeTreeView = NodeTreeManager()
    let tracksManager = TracksManager()
    
    let timeView: View = {
        let view = View(isForm: true)
        view.fillColor = .editing
        view.lineColor = nil
        return view
    } ()
    let nodeBindingLinePathView: View = {
        let layer = View(path: CGMutablePath())
        layer.lineWidth = 5
        layer.lineColor = .bindingBorder
        return layer
    } ()
    enum BindingKeyframeType {
        case tempo, cut
    }
    var bindingKeyframeType = BindingKeyframeType.cut
    
    let beatsView = View(path: CGMutablePath())
    
    let tempoKeyframeView = KeyframeView(sizeType: .small)
    let keyframeView = KeyframeView(), nodeView = NodeView(sizeType: .small)
    
    init(frame: Rect = Rect()) {
        tempoAnimationClipView.children = [tempoAnimationView]
        tempoAnimationClipView.isClipped = true
        tempoAnimationView.isEdit = true
        tempoAnimationView.sizeType = .regular
        tempoAnimationView.smallHeight = tempoHeight
        cutViewsView.isClipped = true
        sumKeyTimesClipView.isClipped = true
        sumKeyTimesView.isEdit = true
        sumKeyTimesView.smallHeight = sumKeyTimesHeight
        sumKeyTimesClipView.append(child: sumKeyTimesView)
        formTimeRulerView.isClipped = true
        beatsView.isClipped = true
        beatsView.fillColor = .subContent
        beatsView.lineColor = nil
        
        super.init()
        children = [timeView, //curretEditKeyframeTimeExpressionView,
                    beatsView, classSumAnimationNameView, sumKeyTimesClipView,
                    formTimeRulerView,
                    tempoAnimationClipView, //baseTimeIntervalView,
                    nodeTreeView.nodesView, tracksManager.tracksView,
                    cutViewsView]
        if !frame.isEmpty {
            self.frame = frame
        }
        
        tempoAnimationView.setKeyframeClosure = { [unowned self] in
            guard $0.phase == .ended else {
                return
            }
            let tempoTrack = self.scene.tempoTrack
            switch $0.setType {
            case .insert:
                self.insert($0.keyframe, at: $0.index, in: tempoTrack)
            case .remove:
                self.removeKeyframe(at: $0.index,
                                    in: tempoTrack, in: self.differentialSceneDataModel,
                                    time: self.time)
            case .replace:
                self.replace($0.keyframe, at: $0.index,
                             in: tempoTrack, in: self.differentialSceneDataModel, time: self.time)
            }
        }
        tempoAnimationView.slideClosure = { [unowned self] in
            self.setAnimationInTempoTrack(with: $0)
        }
        tempoAnimationView.selectClosure = { [unowned self] in
            self.setAnimationInTempoTrack(with: $0)
        }
        
        baseTimeIntervalView.binding = { [unowned self] in
            switch $0.phase {
            case .began:
                self.baseTimeIntervalOldTime = self.scene.secondTime(withBeatTime: self.scene.time)
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
            let cutTime = self.scene.cutTrack.time(at: cutIndex)
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
        sumKeyTimesView.slideClosure = { [unowned self] in self.setAnimations(with: $0) }
        
        nodeTreeView.nodesView.newClosure = { [unowned self] _, _ in self.newNode() }
        nodeTreeView.setNodesClosure = { [unowned self] in self.setNodes(with: $0) }
        nodeTreeView.nodesView.deleteClosure = { [unowned self] _, _ in
            self.remove(self.editCutView.cut.editNode, in: self.editCutView)
        }
        nodeTreeView.nodesView.pasteClosure = { [unowned self] in
            self.pasteFromNodesView($1, for: $2)
        }
        
        tracksManager.tracksView.newClosure = { [unowned self] _, _ in self.newNodeTrack() }
        tracksManager.setTracksClosure = { [unowned self] in self.setNodeTracks(with: $0) }
        tracksManager.tracksView.deleteClosure = { [unowned self] _, _ in
            let node = self.editCutView.cut.editNode
            self.remove(trackIndex: node.editTrackIndex, in: node, in: self.editCutView)
        }
        tracksManager.tracksView.pasteClosure = { [unowned self] in
            self.pasteFromTracksView($1, for: $2)
        }
    }
    
    override var locale: Locale {
        didSet {
            updateLayout()
        }
    }
    
    override var bounds: Rect {
        didSet {
            updateLayout()
        }
    }
    func updateLayout() {
        let sp = Layout.basicPadding
        mainHeight = bounds.height - timeRulerHeight - sumKeyTimesHeight - sp * 2
        cutHeight = mainHeight - tempoHeight - subtitleHeight - soundHeight
        let midX = bounds.midX, leftWidth = TimelineView.leftWidth
        let rightX = leftWidth
        formTimeRulerView.frame = Rect(x: rightX, y: bounds.height - timeRulerHeight - sp,
                                 width: bounds.width - rightX - sp, height: timeRulerHeight)
//        curretEditKeyframeTimeView.frame.origin = Point(x: rightX - curretEditKeyframeTimeView.frame.width - Layout.smallPadding,
//                                         y: bounds.height - timeRulerHeight
//                                            - Layout.basicPadding + Layout.smallPadding)
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
            return scene.time
        }
        set {
            if newValue != scene.time {
                updateWith(time: newValue, scrollPoint: Point(x: x(withTime: newValue), y: 0))
            }
        }
    }
    private func updateWithTime() {
        updateWith(time: time, scrollPoint: _scrollPoint)
    }
    private func updateNoIntervalWith(time: Beat) {
        if time != scene.time {
            updateWith(time: time, scrollPoint: Point(x: x(withTime: time), y: 0),
                       isIntervalScroll: false)
        }
    }
    private func updateWith(time: Beat, scrollPoint: Point,
                            isIntervalScroll: Bool = true, alwaysUpdateCutIndex: Bool = false) {
        _scrollPoint = scrollPoint
        _intervalScrollPoint = isIntervalScroll ? intervalScrollPoint(with: _scrollPoint) : scrollPoint
        
        let cvi = scene.cutTrack.animation.loopedKeyframeIndex(withTime: time)
        if alwaysUpdateCutIndex || scene.editCutIndex != cvi.loopFrameIndex {
            editCutView.isEdit = false
            self.editCutIndex = cvi.loopFrameIndex
            editCutView.isEdit = true
        }
        editCutView.cut.currentTime = cvi.interTime
        editCutView.updateWithTime()
        scene.tempoTrack.time = time
        sumKeyTimesView.animation.update(withTime: time)
        tempoAnimationView.updateKeyframeIndex(with: scene.tempoTrack.animation)
        sumKeyTimesView.updateKeyframeIndex(with: sumKeyTimesView.animation)
        if time != scene.time {
            scene.time = time
            differentialSceneDataModel?.isWrite = true
        }
        updateWithScrollPosition()
        updateView(isCut: true, isTransform: true, isKeyframe: true)
    }
    var updateViewClosure: (((isCut: Bool, isTransform: Bool, isKeyframe: Bool)) -> ())?
    private func updateView(isCut: Bool, isTransform: Bool, isKeyframe: Bool) {
        if isKeyframe {
            updateKeyframeView()
//            curretEditKeyframeTimeView.rational = scene.curretEditKeyframeTime
            tempoView.model = scene.tempoTrack.tempoItem.tempo
        }
        if isCut {
            nodeTreeView.cut = scene.editCut
            tracksManager.node = scene.editNode
            nodeView.node = scene.editNode
        }
        updateViewClosure?((isCut, isTransform, isKeyframe))
    }
    func updateTime(withCutTime cutTime: Beat) {
        let time = cutTime + scene.cutTrack.time(at: scene.editCutIndex)
        _scrollPoint.x = x(withTime: time)
        self.time = time
    }
    private func intervalScrollPoint(with scrollPoint: Point) -> Point {
        return Point(x: x(withTime: time(withLocalX: scrollPoint.x)), y: 0)
    }
    
    var editCutView: CutView {
        return cutViews[scene.editCutIndex]
    }
    var cutViews = [CutView]() {
        didSet {
            var subtitleTextViews = [View]()
            cutViews.forEach { subtitleTextViews += $0.subtitleTextViews as [View] }
            
            cutViewsView.children = cutViews.reversed() as [View]
                + cutViews.map { $0.subtitleAnimationView } as [View] + subtitleTextViews as [View] + [soundWaveformView] as [View]
            updateCutViewPositions()
        }
    }
    private func updateWithScrollPosition() {
        let minX = localDeltaX
        _ = cutViews.reduce(minX) { x, cutView in
            cutView.frame.origin = Point(x: x, y: 0)
            
            cutView.subtitleAnimationView.frame.origin = Point(x: x, y: cutView.frame.height)
            _ = cutView.subtitleTextViews.reduce(x) {
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
    func updateCutViewPositions() {
        maxScrollX = x(withTime: scene.duration)
        let minX = localDeltaX
        _ = cutViews.reduce(minX) { x, cutView in
            cutView.frame.origin = Point(x: x, y: 0)
            cutView.subtitleAnimationView.frame.origin = Point(x: x, y: cutView.frame.height)
            _ = cutView.subtitleTextViews.reduce(x) {
                $1.frame.size = Size(width: 100, height: Layout.basicHeight)
                $1.frame.origin = Point(x: $0, y: cutView.frame.height + cutView.subtitleAnimationView.frame.height)
                return $0 + $1.frame.width
            }
            return x + cutView.frame.width
        }
        tempoAnimationView.frame.origin = Point(x: minX, y: 0)
        updateBeats()
        updateTimeRuler()
        updateSumKeyTimesView()
    }
    var mainHeight = 0.0.cg
    func cutViews(with scene: Scene) -> [CutView] {
        return scene.cuts.enumerated().map {
            self.bindedCutView(with: $0.element,
                                 beginBaseTime: scene.cutTrack.time(at: $0.offset), height: cutHeight)
        }
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
                    self.differentialSceneDataModel?.isWrite = true
                }
            }
            if cutView.cut == self.nodeTreeView.cut {
                self.nodeTreeView.updateWithNodes()
                self.tracksManager.node = cutView.cut.editNode
                self.tracksManager.updateWithTracks(isAlwaysUpdate: true)
                self.setNodeAndTrackBinding?(self, cutView, obj.nodeAndTrack)
            }
        }
        cutView.subtitleKeyframeBinding = { [unowned self] _ in
            var subtitleTextViews = [View]()
            self.cutViews.forEach { subtitleTextViews += $0.subtitleTextViews as [View] }
            self.cutViewsView.children = self.cutViews.reversed() as [View]
                + self.cutViews.map { $0.subtitleAnimationView } as [View] + subtitleTextViews as [View] + [self.soundWaveformView] as [View]
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
        let minSecond = Int(floor(scene.secondTime(withBeatTime: minTime)))
        let maxSecond = Int(ceil(scene.secondTime(withBeatTime: maxTime)))
        guard minSecond < maxSecond else {
            formTimeRulerView.scaleTextViews = []
            return
        }
        formTimeRulerView.scrollPosition.x = localDeltaX
        formTimeRulerView.scaleTextViews = (minSecond ... maxSecond).compactMap {
            guard !(maxSecond - minSecond > Int(bounds.width / 40) && $0 % 5 != 0) else {
                return nil
            }
            let timeView = TimelineView.timeView(withSecound: $0)
            timeView.fillColor = nil
            let secondX = x(withTime: scene.basedBeatTime(withSecondTime: Second($0)))
            timeView.frame.origin = Point(x: secondX - timeView.frame.width / 2,
                                             y: Layout.smallPadding)
            return timeView
        }
    }
    static func timeView(withSecound i: Int) -> TextView {
        let minute = i / 60
        let second = i - minute * 60
        let string = second < 0 ?
            String(format: "-%d:%02d", minute, -second) :
            String(format: "%d:%02d", minute, second)
        return TextView(text: Text(string), font: .small)
    }
    
    func updateSumKeyTimesView() {
        guard isUpdateSumKeyTimes else {
            sumKeyTimesView.frame.size.width = maxScrollX
            return
        }
        var keyframeDics = [Beat: Keyframe]()
        func updateKeyframesWith(time: Beat, _ label: Keyframe.Label) {
            if keyframeDics[time] != nil {
                if label == .main {
                    keyframeDics[time]?.label = .main
                }
            } else {
                var newKeyframe = Keyframe()
                newKeyframe.time = time
                newKeyframe.label = label
                keyframeDics[time] = newKeyframe
            }
        }
        scene.tempoTrack.animation.keyframes.forEach { updateKeyframesWith(time: $0.time, $0.label) }
        scene.cutTrack.animation.loopFrames.forEach  {
            let cut = scene.cutTrack.cutItem.keyCuts[$0.index], cutTime = $0.time
            cut.rootNode.allChildren { node in
                for track in node.tracks {
                    track.animation.keyframes.forEach {
                        updateKeyframesWith(time: $0.time + cutTime, $0.label)
                    }
                    let maxTime = track.animation.duration + cutTime
                    updateKeyframesWith(time: maxTime, Keyframe.Label.main)
                }
            }
        }
        var keyframes = keyframeDics.values.sorted(by: { $0.time < $1.time })
        guard let lastTime = keyframes.last?.time else {
            sumKeyTimesView.animation = Animation()
            return
        }
        keyframes.removeLast()
        
        var animation = sumKeyTimesView.animation
        animation.keyframes = keyframes
        animation.duration = lastTime
        sumKeyTimesView.animation = animation
        sumKeyTimesView.frame.size.width = maxScrollX
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
        let path = CGMutablePath()
        let rects: [Rect] = (intMinTime ... intMaxTime).map {
            let i0x = x(withDoubleBeatTime: RealBeat($0)) + minX
            let w = beatsPerBar != 0 && $0 % beatsPerBar == 0 ? barLineWidth : beatsLineWidth
            return Rect(x: i0x - w / 2, y: padding, width: w, height: bounds.height - padding * 2)
        }
        path.addRects(rects)
        beatsView.path = path
    }
    
    var contentFrame: Rect {
        return Rect(x: _scrollPoint.x, y: 0, width: x(withTime: scene.duration), height: 0)
    }
    
    func time(withLocalX x: Real, isBased: Bool = true) -> Beat {
        return isBased ?
            scene.baseTimeInterval * Beat(Int(round(x / baseWidth))) :
            scene.basedBeatTime(withDoubleBeatTime:
                RealBeat(x / baseWidth) * RealBeat(scene.baseTimeInterval))
    }
    func x(withTime time: Beat) -> Real {
        return scene.realBeatTime(withBeatTime: time / scene.baseTimeInterval) * baseWidth
    }
    func realBeatTime(withLocalX x: Real, isBased: Bool = true) -> RealBeat {
        return RealBeat(isBased ? round(x / baseWidth) : x / baseWidth)
            * RealBeat(scene.baseTimeInterval)
    }
    func x(withDoubleBeatTime realBeatTime: RealBeat) -> Real {
        return Real(realBeatTime * RealBeat(scene.baseTimeInterval.inversed!)) * baseWidth
    }
    func realBaseTime(withLocalX x: Real) -> RealBaseTime {
        return RealBaseTime(x / baseWidth)
    }
    func localX(withRealBaseTime realBaseTime: RealBaseTime) -> Real {
        return Real(realBaseTime) * baseWidth
    }
    func beatTime(withBaseTime baseTime: BaseTime) -> Beat {
        return baseTime * scene.baseTimeInterval
    }
    func baseTime(withBeatTime beatTime: Beat) -> BaseTime {
        return beatTime / scene.baseTimeInterval
    }
    func basedBeatTime(withRealBaseTime realBaseTime: RealBaseTime) -> Beat {
        return Beat(Int(realBaseTime)) * scene.baseTimeInterval
    }
    func realBaseTime(withBeatTime beatTime: Beat) -> RealBaseTime {
        return RealBaseTime(beatTime / scene.baseTimeInterval)
    }
    func realBaseTime(withX x: Real) -> RealBaseTime {
        return RealBaseTime(x / baseWidth)
    }
    func basedBeatTime(withDoubleBeatTime realBeatTime: RealBeat) -> Beat {
        return Beat(Int(realBeatTime / RealBeat(scene.baseTimeInterval))) * scene.baseTimeInterval
    }
    func clipDeltaTime(withTime time: Beat) -> Beat {
        let ft = baseTime(withBeatTime: time)
        let fft = ft + BaseTime(1, 2)
        return fft - floor(fft) < BaseTime(1, 2) ?
            beatTime(withBaseTime: ceil(ft)) - time :
            beatTime(withBaseTime: floor(ft)) - time
    }
    
    func cutIndex(withLocalX x: Real) -> Int {
        return scene.cutTrack.index(atTime: time(withLocalX: x))
    }
    func cutIndex(withTime time: Beat) -> Int {
        return scene.cutTrack.index(atTime: time)
    }
    func movingCutIndex(withTime time: Beat) -> Int {
        return scene.cutTrack.movingCutIndex(withTime: time)
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
        let cut = scene.cuts[ci], ct = scene.cuts[ci].currentTime
        guard cut.editNode.editTrack.animation.keyframes.count > 0 else {
            fatalError()
        }
        var minD = Real.infinity, minI = 0
        for (i, k) in cut.editNode.editTrack.animation.keyframes.enumerated() {
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
        let cut = scene.cuts[ci], ct = scene.cutTrack.animation.keyframes[ci].time
        var minD = Real.infinity, minKeyframeIndex = 0, minTrackIndex = 0
        for (ii, track) in cut.editNode.tracks.enumerated() {
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
            
            scene.baseTimeInterval = baseTimeInterval
            differentialSceneDataModel?.isWrite = true
        }
    }
    
    var differentialSceneDataModel: DataModel?
    
    private func registerUndo(time: Beat, _ closure: @escaping (TimelineView, Beat) -> Void) {
        undoManager?.registerUndo(withTarget: self) { [oldTime = self.time] in
            closure($0, oldTime)
        }
        self.time = time
    }
    
    func bindKeyframe(bindingKeyframeType: BindingKeyframeType) -> Bool {
        if bindingKeyframeType != self.bindingKeyframeType {
            set(bindingKeyframeType, time: time)
        }
        return true
    }
    private func set(_ bindingKeyframeType: BindingKeyframeType, time: Beat) {
        registerUndo(time: time) { [ob = self.bindingKeyframeType] in $0.set(ob, time: $1) }
        self.bindingKeyframeType = bindingKeyframeType
        updateKeyframeView()
    }
    private func updateKeyframeView() {
        switch bindingKeyframeType {
        case .tempo:
            keyframeView.keyframe = scene.tempoTrack.animation.editKeyframe
        case .cut:
            keyframeView.keyframe = scene.editNode.editTrack.animation.editKeyframe
        }
    }
    
    private func set(time: Beat, oldTime: Beat, alwaysUpdateCutIndex: Bool = false) {
        undoManager?.registerUndo(withTarget: self) {
            $0.set(time: oldTime, oldTime: time, alwaysUpdateCutIndex: alwaysUpdateCutIndex)
        }
        updateWith(time: time,
                   scrollPoint: Point(x: x(withTime: time), y: 0),
                   alwaysUpdateCutIndex: alwaysUpdateCutIndex)
        differentialSceneDataModel?.isWrite = true
        updateView(isCut: true, isTransform: false, isKeyframe: false)
    }
    
    func delete(for p: Point) {
        let localX = convertToLocalX(p.x)
        let cutIndex = self.cutIndex(withLocalX: localX)
        removeCut(at: cutIndex)
    }
    func copiedViewables(at p: Point) -> [Viewable] {
        return []
    }
    func paste(_ objects: [Any], for p: Point) {
        for object in objects {
            if let cut = object as? Cut {
                let localX = convertToLocalX(p.x)
                let index = cutIndex(withLocalX: localX)
                paste(cut.copied, at: index + 1)
                return
            }
        }
    }
    func paste(_ cut: Cut, at index: Int) {
        insert(bindedCutView(with: cut, height: cutHeight), at: index, time: time)
        set(time: scene.cutTrack.time(at: index), oldTime: time)
    }
    
    func new(for p: Point) {
        let localX = convertToLocalX(p.x)
        let cutIndex = self.cutIndex(withLocalX: localX)
        let cut = Cut()
        let cutView = self.bindedCutView(with: cut, height: cutHeight)
        insert(cutView, at: cutIndex + 1, time: time)
        set(time: scene.cutTrack.time(at: cutIndex + 1), oldTime: time)
    }
    
    func insert(_ cutView: CutView, at index: Int, time: Beat) {
        registerUndo(time: time) { $0.removeCutView(at: index, time: $1) }
        insert(cutView, at: index)
    }
    func insert(_ cutView: CutView, at index: Int) {
        scene.cutTrack.insert(cutView.cut, at: index)
        cutViews.insert(cutView, at: index)
        updateCutViewPositions()
        differentialSceneDataModel?.isWrite = true
        setSceneDurationClosure?(self, scene.duration)
    }
    func removeCut(at i: Int) {
        if i == 0 {
            set(time: time, oldTime: time, alwaysUpdateCutIndex: true)
            removeCutView(at: 0, time: time)
            if scene.cuts.count == 0 {
                insert(bindedCutView(with: Cut(), height: cutHeight), at: 0, time: time)
            }
            set(time: 0, oldTime: time, alwaysUpdateCutIndex: true)
        } else {
            let previousCut = scene.cuts[i - 1]
            let previousCutTimeLocation = scene.cuts[i - 1].currentTime
            let isSetTime = i == scene.editCutIndex
            set(time: time, oldTime: time, alwaysUpdateCutIndex: true)
            removeCutView(at: i, time: time)
            if isSetTime {
                let lastKeyframeTime = previousCut.editNode.editTrack.animation.lastKeyframeTime
                set(time: previousCutTimeLocation + lastKeyframeTime,
                    oldTime: time, alwaysUpdateCutIndex: true)
            } else if time >= scene.duration {
                set(time: scene.duration - scene.baseTimeInterval,
                    oldTime: time, alwaysUpdateCutIndex: true)
            }
        }
    }
    func removeCutView(at index: Int, time: Beat) {
        let cutView = cutViews[index]
        registerUndo(time: time) { $0.insert(cutView, at: index, time: $1) }
        removeCutView(at: index)
    }
    func removeCutView(at index: Int) {
        scene.cutTrack.removeCut(at: index)
        if scene.editCutIndex == cutViews.count - 1 {
            scene.editCutIndex = cutViews.count - 2
        }
        cutViews.remove(at: index)
        updateCutViewPositions()
        differentialSceneDataModel?.isWrite = true
        setSceneDurationClosure?(self, scene.duration)
    }
    
    var newNodeName: String {
        var minIndex: Int?
        scene.editCut.rootNode.allChildren { node in
            if let i = node.name.suffixNumber {
                if let minI = minIndex {
                    if i > minI {
                        minIndex = i
                    }
                } else {
                    minIndex = 0
                }
            }
        }
        let index = minIndex != nil ? minIndex! + 1 : 0
        return Text(english: "Node \(index)", japanese: "ノード\(index)").currentString
    }
    func newNode() {
        let node = Node(name: newNodeName)
        node.editTrack.name = Text(english: "Track 0", japanese: "トラック0").currentString
        append(node, in: editCutView)
    }
    func pasteFromNodesView(_ objects: [Any], for p: Point) {
        for object in objects {
            if let node = object as? Node {
                append(node.copied, in: editCutView)
                return
            }
        }
    }
    func append(_ node: Node, in cutView: CutView) {
        guard let parent = cutView.cut.editNode.parent,
            let index = parent.children.index(of: cutView.cut.editNode) else {
                return
        }
        let animationViews = cutView.newAnimationViews(with: node)
        insert(node, animationViews, at: index + 1, parent: parent, in: cutView, time: time)
        set(node, in: cutView)
    }
    func remove(_ node: Node, in cutView: CutView) {
        guard let parent = node.parent else {
            return
        }
        let index = parent.children.index(of: node)!
        removeNode(at: index, parent: parent, in: cutView, time: time)
        if parent.children.count == 0 {
            let newNode = Node(name: newNodeName)
            let animationViews = cutView.newAnimationViews(with: newNode)
            insert(newNode, animationViews, at: 0, parent: parent, in: cutView, time: time)
            set(newNode, in: cutView)
        } else {
            set(parent.children[index > 0 ? index - 1 : index], in: cutView)
        }
    }
    func insert(_ node: Node, _ animationViews: [AnimationView], at index: Int,
                parent: Node, in cutView: CutView, time: Beat) {
        registerUndo(time: time) { $0.removeNode(at: index, parent: parent, in: cutView, time: $1) }
        cutView.insert(node, at: index, animationViews, parent: parent)
        node.allChildrenAndSelf { (aNode) in
            scene.cutTrack.differentialDataModel.insert(aNode.differentialDataModel)
        }
        differentialSceneDataModel?.isWrite = true
        updateView(isCut: true, isTransform: false, isKeyframe: false)
        if cutView.cut == nodeTreeView.cut {
            nodeTreeView.updateWithNodes()
            tracksManager.updateWithTracks()
        }
    }
    func removeNode(at index: Int, parent: Node, in cutView: CutView, time: Beat) {
        let node = parent.children[index]
        let animationViews = cutView.animationViews(with: node)
        registerUndo(time: time) { [on = parent.children[index]] in
            $0.insert(on, animationViews, at: index, parent: parent, in: cutView, time: $1)
        }
        cutView.remove(at: index, animationViews, parent: parent)
        node.allChildrenAndSelf { (aNode) in
            scene.cutTrack.differentialDataModel.remove(aNode.differentialDataModel)
        }
        differentialSceneDataModel?.isWrite = true
        updateView(isCut: true, isTransform: false, isKeyframe: false)
        if cutView.cut == nodeTreeView.cut {
            nodeTreeView.updateWithNodes()
            tracksManager.updateWithTracks()
        }
    }
    func set(_ node: Node, in cutView: CutView) {
        set(Cut.NodeAndTrack(node: node, trackIndex: 0),
            old: cutView.editNodeAndTrack, in: cutView, time: time)
    }
    
    func newNodeTrackName(with node: Node) -> String {
        var minIndex: Int?
        node.tracks.forEach { track in
            if let i = track.name.suffixNumber {
                if let minI = minIndex {
                    if i > minI {
                        minIndex = i
                    }
                } else {
                    minIndex = 0
                }
            }
        }
        let index = minIndex != nil ? minIndex! + 1 : 0
        return Text(english: "Track \(index)", japanese: "トラック\(index)").currentString
    }
    func newNodeTrack() {
        let cutView = cutViews[scene.editCutIndex]
        let node = cutView.cut.editNode
        let track = NodeTrack(name: newNodeTrackName(with: node))
        let animationView = cutView.newAnimationView(with: track, node: node, sizeType: .small)
        let trackIndex = node.editTrackIndex + 1
        insert(track, animationView, at: trackIndex, in: node, in: cutView, time: time)
        bind(in: animationView, in: cutView,
             from: Cut.NodeAndTrack(node: node, trackIndex: trackIndex))
        set(editTrackIndex: trackIndex, oldEditTrackIndex: node.editTrackIndex,
            in: node, in: cutView, time: time)
    }
    func pasteFromTracksView(_ objects: [Any], for p: Point) {
        for object in objects {
            if let track = object as? NodeTrack {
                append(track.copied, in: editCutView)
                return
            }
        }
    }
    func append(_ track: NodeTrack, in cutView: CutView) {
        let node = cutView.cut.editNode
        let index = node.editTrackIndex
        let animationView = cutView.newAnimationView(with: track, node: node, sizeType: .regular)
        insert(track, animationView, at: index + 1, in: node, in: cutView, time: time)
        bind(in: animationView, in: cutView,
             from: Cut.NodeAndTrack(node: node, trackIndex: index))
        set(editTrackIndex: index + 1, oldEditTrackIndex: node.editTrackIndex,
            in: node, in: cutView, time: time)
    }
    func remove(trackIndex: Int, in node: Node, in cutView: CutView) {
        let newIndex = trackIndex > 0 ? trackIndex - 1 : trackIndex
        set(editTrackIndex: newIndex, oldEditTrackIndex: node.editTrackIndex,
            in: node, in: cutView, time: time)
        removeTrack(at: trackIndex, in: node, in: cutView, time: time)
        if node.tracks.count == 0 {
            let newTrack = NodeTrack(name: newNodeTrackName(with: node))
            let animationView = cutView.newAnimationView(with: newTrack, node: node,
                                                               sizeType: .regular)
            insert(newTrack, animationView, at: 0, in: node, in: cutView, time: time)
            bind(in: animationView, in: cutView,
                 from: Cut.NodeAndTrack(node: node, trackIndex: trackIndex))
            set(editTrackIndex: 0, oldEditTrackIndex: node.editTrackIndex,
                in: node, in: cutView, time: time)
        }
    }
    func removeTrack(at index: Int, in node: Node, in cutView: CutView) {
        if node.tracks.count > 1 {
            set(editTrackIndex: max(0, index - 1),
                oldEditTrackIndex: index, in: node, in: cutView, time: time)
            removeTrack(at: index, in: node, in: cutView, time: time)
        }
    }
    func insert(_ track: NodeTrack, _ animationView: AnimationView, at index: Int, in node: Node,
                in cutView: CutView, time: Beat) {
        registerUndo(time: time) { $0.removeTrack(at: index, in: node, in: cutView, time: $1) }
        
        let nodeAndTrack = Cut.NodeAndTrack(node: node, trackIndex: index)
        cutView.insert(track, animationView, in: nodeAndTrack)
        node.differentialDataModel.isWrite = true
        differentialSceneDataModel?.isWrite = true
        updateView(isCut: true, isTransform: false, isKeyframe: false)
        if tracksManager.node == node {
            tracksManager.updateWithTracks()
        }
    }
    func removeTrack(at index: Int, in node: Node, in cutView: CutView, time: Beat) {
        let nodeAndTrack = Cut.NodeAndTrack(node: node, trackIndex: index)
        let animationIndex = cutView.cut.nodeAndTrackIndex(with: nodeAndTrack)
        registerUndo(time: time) { [ot = node.tracks[index],
            oa = cutView.animationViews[animationIndex]] in
            
            $0.insert(ot, oa, at: index, in: node, in: cutView, time: $1)
        }
        cutView.removeTrack(at: nodeAndTrack)
        node.differentialDataModel.isWrite = true
        differentialSceneDataModel?.isWrite = true
        updateView(isCut: true, isTransform: false, isKeyframe: false)
        if tracksManager.node == node {
            tracksManager.updateWithTracks()
        }
    }
    private func set(editTrackIndex: Int, oldEditTrackIndex: Int,
                     in node: Node, in cutView: CutView, time: Beat) {
        registerUndo(time: time) {
            $0.set(editTrackIndex: oldEditTrackIndex,
                   oldEditTrackIndex: editTrackIndex, in: node, in: cutView, time: $1)
        }
        cutView.set(editTrackIndex: editTrackIndex, in: node)
        differentialSceneDataModel?.isWrite = true
        updateView(isCut: true, isTransform: true, isKeyframe: true)
        if tracksManager.node == node {
            tracksManager.updateWithTracks()
        }
    }
    
    private func set(_ editNodeAndTrack: Cut.NodeAndTrack,
                     old oldEditNodeAndTrack: Cut.NodeAndTrack,
                     in cutView: CutView, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldEditNodeAndTrack, old: editNodeAndTrack, in: cutView, time: $1)
        }
        cutView.editNodeAndTrack = editNodeAndTrack
        differentialSceneDataModel?.isWrite = true
        if cutView.cut == nodeTreeView.cut {
            nodeTreeView.updateWithNodes()
            setNodeAndTrackBinding?(self, cutView, editNodeAndTrack)
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
            let time = obj.oldTime - scene.cutTrack.time(at: cutIndex)
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
    
    private var oldTempoTrack: TempoTrack?
    private func setAnimationInTempoTrack(with obj: AnimationView.SlideBinding) {
        switch obj.phase {
        case .began:
            oldTempoTrack = scene.tempoTrack
        case .changed:
            guard let oldTrack = oldTempoTrack else {
                return
            }
            oldTrack.replace(obj.animation.keyframes)
            updateTimeRuler()
            soundWaveformView.updateWaveform()
        case .ended:
            guard let oldTrack = oldTempoTrack else {
                return
            }
            oldTrack.replace(obj.animation.keyframes)
            updateTimeRuler()
            soundWaveformView.updateWaveform()
            if obj.animation != obj.oldAnimation {
                registerUndo(time: time) { [differentialSceneDataModel] in
                    $0.set(obj.oldAnimation, old: obj.animation,
                           in: oldTrack, in: differentialSceneDataModel, time: $1)
                }
                differentialSceneDataModel?.isWrite = true
            }
            self.oldTempoTrack = nil
        }
        updateWithTime()
    }
    private func setAnimationInTempoTrack(with obj: AnimationView.SelectBinding) {
        switch obj.phase {
        case .began:
            oldTempoTrack = scene.tempoTrack
        case .changed:
            break
        case .ended:
            guard let oldTrack = oldTempoTrack else {
                return
            }
            if obj.animation != obj.oldAnimation {
                registerUndo(time: time) { [differentialSceneDataModel] in
                    $0.set(obj.oldAnimation, old: obj.animation,
                           in: oldTrack, in: differentialSceneDataModel, time: $1)
                }
                differentialSceneDataModel?.isWrite = true
            }
            self.oldTempoTrack = nil
        }
    }
    private func set(_ animation: Animation, old oldAnimation: Animation,
                     in track: TempoTrack, in sceneDataModel: DataModel?, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldAnimation, old: animation, in: track, in: sceneDataModel, time: $1)
        }
        track.replace(animation.keyframes, duration: animation.duration)
        tempoAnimationView.animation = track.animation
        sceneDataModel?.isWrite = true
        updateTimeRuler()
        soundWaveformView.updateWaveform()
        updateWithTime()
    }
    func insert(_ keyframe: Keyframe, at index: Int, in track: TempoTrack) {
        let keyframeValue = track.currentItemValues
        insert(keyframe, keyframeValue,
               at: index, in: track, in: differentialSceneDataModel, time: time)
    }
    private func replace(_ keyframe: Keyframe, at index: Int,
                         in track: TempoTrack, in sceneDataModel: DataModel?, time: Beat) {
        registerUndo(time: time) { [ok = track.animation.keyframes[index]] in
            $0.replace(ok, at: index, in: track, in: sceneDataModel, time: $1)
        }
        track.replace(keyframe, at: index)
        tempoAnimationView.animation = track.animation
        sceneDataModel?.isWrite = true
        updateWith(time: time, scrollPoint: Point(x: x(withTime: time), y: 0))
        updateWithTime()
        updateTimeRuler()
        soundWaveformView.updateWaveform()
    }
    private func insert(_ keyframe: Keyframe,
                        _ keyframeValue: TempoTrack.KeyframeValues,
                        at index: Int,
                        in track: TempoTrack, in sceneDataModel: DataModel?, time: Beat) {
        registerUndo(time: time) {
            $0.removeKeyframe(at: index, in: track, in: sceneDataModel, time: $1)
        }
        track.insert(keyframe, keyframeValue, at: index)
        tempoAnimationView.animation = track.animation
        sceneDataModel?.isWrite = true
        updateWith(time: time, scrollPoint: Point(x: x(withTime: time), y: 0))
        updateView(isCut: false, isTransform: false, isKeyframe: true)
        updateSumKeyTimesView()
        updateTimeRuler()
        soundWaveformView.updateWaveform()
    }
    private func removeKeyframe(at index: Int,
                                in track: TempoTrack, in sceneDataModel: DataModel?, time: Beat) {
        registerUndo(time: time) {
            [ok = track.animation.keyframes[index],
            okv = track.keyframeItemValues(at: index)] in

            $0.insert(ok, okv, at: index, in: track, in: sceneDataModel, time: $1)
        }
        track.removeKeyframe(at: index)
        tempoAnimationView.animation = track.animation
        sceneDataModel?.isWrite = true
        updateWith(time: time, scrollPoint: Point(x: x(withTime: time), y: 0))
        updateWithTime()
        updateSumKeyTimesView()
        updateTimeRuler()
        soundWaveformView.updateWaveform()
    }
    
    private func setAnimation(with obj: AnimationView.SlideBinding,
                              in track: NodeTrack, in node: Node, in cutView: CutView) {
        switch obj.phase {
        case .began:
            break
        case .changed:
            track.replace(obj.animation.keyframes, duration: obj.animation.duration)
            updateCutDuration(with: cutView)
        case .ended:
            track.replace(obj.animation.keyframes, duration: obj.animation.duration)
            if obj.animation != obj.oldAnimation {
                registerUndo(time: time) {
                    $0.set(obj.oldAnimation, old: obj.animation,
                           in: track, in: obj.animationView, in: cutView, time: $1)
                }
                
                node.differentialDataModel.isWrite = true
                differentialSceneDataModel?.isWrite = true
            }
            updateCutDuration(with: cutView)
        }
        updateWithTime()
    }
    private func setAnimation(with obj: AnimationView.SelectBinding,
                              in track: NodeTrack, in cutView: CutView) {
        switch obj.phase {
        case .began:
            break
        case .changed:
            break
        case .ended:
            if obj.animation != obj.oldAnimation {
                registerUndo(time: time) {
                    $0.set(obj.oldAnimation, old: obj.animation,
                           in: track, in: obj.animationView, in: cutView, time: $1)
                }
                differentialSceneDataModel?.isWrite = true
            }
        }
    }
    private func set(_ animation: Animation, old oldAnimation: Animation,
                     in track: NodeTrack,
                     in animationView: AnimationView, in cutView: CutView, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldAnimation, old: animation, in: track,
                   in: animationView, in: cutView, time: $1)
        }
        track.replace(animation.keyframes, duration: animation.duration)
        differentialSceneDataModel?.isWrite = true
        animationView.animation = track.animation
        updateCutDuration(with: cutView)
    }
    func insert(_ keyframe: Keyframe, at index: Int,
                in track: NodeTrack, in node: Node,
                in animationView: AnimationView, in cutView: CutView,
                isSplitDrawing: Bool = false) {
        var keyframeValue = track.currentItemValues
        keyframeValue.drawing = isSplitDrawing ? keyframeValue.drawing.copied : Drawing()
        insert(keyframe, keyframeValue, at: index, in: track, in: node,
               in: animationView, in: cutView, time: time)
    }
    private func replace(_ keyframe: Keyframe, at index: Int,
                         in track: NodeTrack,
                         in animationView: AnimationView, in cutView: CutView, time: Beat) {
        registerUndo(time: time) { [ok = track.animation.keyframes[index]] in
            $0.replace(ok, at: index, in: track, in: animationView, in: cutView, time: $1)
        }
        track.replace(keyframe, at: index)
        updateWith(time: time, scrollPoint: Point(x: x(withTime: time), y: 0))
        differentialSceneDataModel?.isWrite = true
        animationView.animation = track.animation
        updateView(isCut: true, isTransform: false, isKeyframe: false)
    }
    private func insert(_ keyframe: Keyframe,
                        _ keyframeValue: NodeTrack.KeyframeValues,
                        at index: Int,
                        in track: NodeTrack, in node: Node,
                        in animationView: AnimationView, in cutView: CutView, time: Beat) {
        registerUndo(time: time) { $0.removeKeyframe(at: index, in: track, in: node,
                                                     in: animationView, in: cutView, time: $1) }
        track.insert(keyframe, keyframeValue, at: index)
        node.differentialDataModel.isWrite = true
        differentialSceneDataModel?.isWrite = true
        animationView.animation = track.animation
        updateWith(time: time, scrollPoint: Point(x: x(withTime: time), y: 0))
        updateView(isCut: true, isTransform: false, isKeyframe: false)
        updateSumKeyTimesView()
    }
    private func removeKeyframe(at index: Int,
                                in track: NodeTrack, in node: Node,
                                in animationView: AnimationView, in cutView: CutView,
                                time: Beat) {
        registerUndo(time: time) {
            [ok = track.animation.keyframes[index],
            okv = track.keyframeItemValues(at: index)] in
            
            $0.insert(ok, okv, at: index, in: track, in: node,
                      in: animationView, in: cutView, time: $1)
        }
        track.removeKeyframe(at: index)
        updateWith(time: time, scrollPoint: Point(x: x(withTime: time), y: 0))
        node.differentialDataModel.isWrite = true
        differentialSceneDataModel?.isWrite = true
        animationView.animation = track.animation
        updateView(isCut: true, isTransform: false, isKeyframe: false)
        updateSumKeyTimesView()
    }
    
    func updateCutDuration(with cutView: CutView) {
        cutView.cut.duration = cutView.cut.maxDuration
        cutView.updateWithDuration()
        scene.cutTrack.updateCutTimeAndDuration()
        differentialSceneDataModel?.isWrite = true
        setSceneDurationClosure?(self, scene.duration)
        updateTempoDuration()
        cutViews.enumerated().forEach {
            $0.element.beginBaseTime = scene.cutTrack.time(at: $0.offset)
        }
        updateCutViewPositions()
    }
    func updateTempoDuration() {
        scene.tempoTrack.replace(duration: scene.duration)
        tempoAnimationView.animation.duration = scene.duration
        tempoAnimationView.frame.size.width = maxScrollX
    }
    
    private var oldCutView: CutView?
    
    private func setNodes(with obj: NodeTreeManager.NodesBinding) {
        switch obj.phase {
        case .began:
            oldCutView = editCutView
        case .changed, .ended:
            guard let cutView = oldCutView else {
                return
            }
            cutView.moveNode(from: obj.oldIndex, fromParemt: obj.fromNode,
                               to: obj.index, toParent: obj.toNode)
            if cutView.cut == obj.nodeTreeView.cut {
                obj.nodeTreeView.updateWithNodes(isAlwaysUpdate: true)
                tracksManager.updateWithTracks(isAlwaysUpdate: true)
            }
            if obj.phase == .ended {
                if obj.index != obj.beginIndex || obj.toNode != obj.beginNode {
                    registerUndo(time: time) {
                        $0.moveNode(from: obj.index, fromParent: obj.toNode,
                                    to: obj.beginIndex, toParent: obj.beginNode,
                                    in: cutView, time: $1)
                    }
                    differentialSceneDataModel?.isWrite = true
                }
                self.oldCutView = nil
            }
        }
    }
    private func moveNode(from oldIndex: Int, fromParent: Node,
                          to index: Int, toParent: Node, in cutView: CutView, time: Beat) {
        registerUndo(time: time) {
            $0.moveNode(from: index, fromParent: toParent, to: oldIndex, toParent: fromParent,
                        in: cutView, time: $1)
        }
        cutView.moveNode(from: oldIndex, fromParemt: fromParent, to: index, toParent: toParent)
        differentialSceneDataModel?.isWrite = true
        if cutView.cut == nodeTreeView.cut {
            nodeTreeView.updateWithNodes(isAlwaysUpdate: true)
            tracksManager.updateWithTracks(isAlwaysUpdate: true)
        }
    }
    
    private func setNodeTracks(with obj: TracksManager.NodeTracksBinding) {
        switch obj.phase {
        case .began:
            oldCutView = editCutView
        case .changed, .ended:
            guard let cutView = oldCutView else {
                return
            }
            cutView.moveTrack(from: obj.oldIndex, to: obj.index, in: obj.inNode)
            cutView.set(editTrackIndex: obj.index, in: obj.inNode)
            if cutView.cut.editNode == obj.tracksManager.node {
                obj.tracksManager.updateWithTracks(isAlwaysUpdate: true)
            }
            if obj.phase == .ended {
                if obj.index != obj.beginIndex {
                    registerUndo(time: time) {
                        $0.moveTrack(from: obj.index, to: obj.beginIndex,
                                     in: obj.inNode, in: cutView, time: $1)
                    }
                    registerUndo(time: time) {
                        $0.set(editTrackIndex: obj.beginIndex, oldEditTrackIndex: obj.index,
                               in: obj.inNode, in: cutView, time: $1)
                    }
                    obj.inNode.differentialDataModel.isWrite = true
                    differentialSceneDataModel?.isWrite = true
                }
                self.oldCutView = nil
            }
        }
    }
    private func moveTrack(from oldIndex: Int, to index: Int,
                      in node: Node, in cutView: CutView, time: Beat) {
        registerUndo(time: time) {
            $0.moveTrack(from: index, to: oldIndex, in: node, in: cutView, time: $1)
        }
        cutView.moveTrack(from: oldIndex, to: index, in: node)
        node.differentialDataModel.isWrite = true
        differentialSceneDataModel?.isWrite = true
        if cutView.cut == nodeTreeView.cut {
            nodeTreeView.updateWithNodes(isAlwaysUpdate: true)
            tracksManager.updateWithTracks(isAlwaysUpdate: true)
        }
    }
    
    var setSceneDurationClosure: ((TimelineView, Beat) -> ())?
    
    func moveToPrevious() {
        let cut = scene.editCut
        let track = cut.editNode.editTrack
        let lfi = track.animation.loopedKeyframeIndex(withTime: cut.currentTime).loopFrameIndex
        let loopFrame = track.animation.loopFrames[lfi]
        if cut.currentTime - loopFrame.time > 0 {
            updateTime(withCutTime: loopFrame.time)
        } else if lfi - 1 >= 0 {
            updateTime(withCutTime: track.animation.loopFrames[lfi - 1].time)
        } else if scene.editCutIndex - 1 >= 0 {
            self.editCutIndex -= 1
            updateTime(withCutTime: scene.editCut.editNode.editTrack.animation.lastLoopedKeyframeTime)
        }
    }
    func moveToNext() {
        let cut = scene.editCut
        let track = cut.editNode.editTrack
        let lfi = track.animation.loopedKeyframeIndex(withTime: cut.currentTime).loopFrameIndex
        if lfi + 1 <= track.animation.loopFrames.count - 1 {
            let t = track.animation.loopFrames[lfi + 1].time
            if t < track.animation.duration {
                updateTime(withCutTime: t)
                return
            }
        }
        if scene.editCutIndex + 1 <= scene.cuts.count - 1 {
            self.editCutIndex += 1
            updateTime(withCutTime: 0)
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
            for cut in scene.cuts {
                if cut == scene.editCut {
                    break
                }
                index += cut.editNode.editTrack.animation.loopFrames.count
            }
            index += scene.editNode.editTrack.animation.editLoopframeIndex
            return scene.time == scene.duration ? index + 1 : index
        }
        set {
            guard newValue != currentAllKeyframeIndex else {
                return
            }
            var index = 0
            for (cutIndex, cut) in scene.cuts.enumerated() {
                let animation = cut.editNode.editTrack.animation
                let newIndex = index + animation.keyframes.count
                if newIndex > newValue {
                    let i = (newValue - index).clip(min: 0, max: animation.loopFrames.count - 1)
                    let cutTime = scene.cutTrack.time(at: cutIndex)
                    updateNoIntervalWith(time: cutTime + animation.loopFrames[i].time)
                    return
                }
                index = newIndex
            }
            updateNoIntervalWith(time: scene.duration)
        }
    }
    var maxAllKeyframeIndex: Int {
        return scene.cuts.reduce(0) { $0 + $1.editNode.editTrack.animation.loopFrames.count }
    }
    
    func scrollTime(for p: Point, time: Second, scrollDeltaPoint: Point,
                    phase: Phase, momentumPhase: Phase?) {
        let maxX = self.x(withTime: scene.duration)
        let x = (scrollPoint.x - scrollDeltaPoint.x).clip(min: 0, max: maxX)
        scrollPoint = Point(x: phase == .began ?
            self.x(withTime: self.time(withLocalX: x)) : x, y: 0)
    }
    
    private var baseTimeIntervalOldTime = Second(0)
    private var floatBaseTimeInterval = 0.0.cg, beginBaseTimeInterval = Beat(1)
    func zoom(for p: Point, time: Second, magnification: Real, _ phase: Phase) {
        switch phase {
        case .began:
            baseTimeIntervalOldTime = scene.secondTime(withBeatTime: scene.time)
            beginBaseTimeInterval = baseTimeInterval
            floatBaseTimeInterval = 0
        case .changed, .ended:
            floatBaseTimeInterval += magnification * 40
            if beginBaseTimeInterval.q == 1 {
                let p = beginBaseTimeInterval.p - Int(floatBaseTimeInterval)
                baseTimeInterval = p < 1 ? Beat(1, 2 - p) : Beat(p)
            } else {
                let q = beginBaseTimeInterval.q + Int(floatBaseTimeInterval)
                baseTimeInterval = q < 1 ? Beat(2 - q) : Beat(1, q)
            }
            updateWith(time: self.time, scrollPoint: Point(x: x(withTime: self.time), y: 0),
                       isIntervalScroll: false)
            updateWithTime()
        }
//        zoom(at: point(from: event)) {
//            baseWidth = (baseWidth * (event.magnification * 2.5 + 1))
//                .clip(min: 1, max: Timeline.defautBaseWidth)
//        }
    }
    func resetView(for p: Point) {
//        guard baseWidth != Timeline.defautBaseWidth else {
//            return
//        }
//        zoom(at: point(from: event)) {
//            baseWidth = Timeline.defautBaseWidth
//        }
    }
    func zoom(at p: Point, closure: () -> ()) {
        closure()
        _scrollPoint.x = x(withTime: time)
        _intervalScrollPoint.x = scrollPoint.x
        updateView(isCut: false, isTransform: false, isKeyframe: false)
    }
    
    func reference(at p: Point) -> Reference {
        return Reference(name: Text(english: "Timeline", japanese: "タイムライン"),
                         viewDescription: Text(english: "Select time: Left and right scroll\nSelect track: Up and down scroll",
                                                       japanese: "時間選択: 左右スクロール\nトラック選択: 上下スクロール"))
    }
}

final class RulerView: View {
    private let scrollView: View = {
        let view = View(isForm: true)
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
    
    var scaleTextViews = [TextView]() {
        didSet {
            scrollView.children = scaleTextViews
        }
    }
}
