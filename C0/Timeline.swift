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
 # Issue
 - ノードトラック、ノード、カットの複数選択
 - 滑らかなスクロール
 - sceneを取り除く
 - スクロールの可視性の改善
 */
final class Timeline: View {
    var scene = Scene() {
        didSet {
            _scrollPoint.x = x(withTime: scene.time)
            _intervalScrollPoint.x = x(withTime: time(withLocalX: _scrollPoint.x))
            cutViews = self.cutViews(with: scene)
            editCutView.isEdit = true
            baseTimeInterval = scene.baseTimeInterval
            tempoView.number = scene.tempoTrack.tempoItem.tempo
            tempoAnimationView.animation = scene.tempoTrack.animation
            tempoAnimationView.frame.size.width = maxScrollX
            soundWaveformView.tempoTrack = scene.tempoTrack
            soundWaveformView.sound = scene.sound
            baseTimeIntervalView.number = scene.baseTimeInterval.q.cf
            updateWith(time: scene.time, scrollPoint: _scrollPoint)
        }
    }
    
    var indicatedTime = 0
    var setEditCutItemIndexClosure: ((Timeline, Int) -> ())?
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
                let oldFrame = curretEditKeyframeTimeView.frame
                curretEditKeyframeTimeView.localization = Localization(Timeline.timeString(atTime: editedKeyframeTime))
                curretEditKeyframeTimeView.frame.origin.x = oldFrame.maxX - curretEditKeyframeTimeView.bounds.width
            }
        }
    }
    private static func timeString(atTime time: Beat) -> String {
        let i = time.integralPart
        return i == 0 ? "\(time) b" : (time.isInteger ? "\(i) b" : "\(i) + \(time - Beat(i)) b")
    }
    
    static let defautBaseWidth = 6.0.cf, defaultTimeHeight = Layout.basicHeight
    static let defaultSumKeyTimesHeight = 18.0.cf
    var baseWidth = defautBaseWidth {
        didSet {
            sumKeyTimesView.baseWidth = baseWidth
            tempoAnimationView.baseWidth = baseWidth
            soundWaveformView.baseWidth = baseWidth
            cutViews.forEach { $0.baseWidth = baseWidth }
            updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: _scrollPoint.y))
        }
    }
    private let timeHeight = defaultTimeHeight
    private let timeRulerHeight = Layout.smallHeight
    private let tempoHeight = defaultSumKeyTimesHeight
    private let subtitleHeight = 24.0.cf, soundHeight = 20.0.cf
    private let sumKeyTimesHeight = defaultSumKeyTimesHeight
    private let knobHalfHeight = 8.0.cf, subKnobHalfHeight = 4.0.cf, maxLineHeight = 3.0.cf
    private(set) var maxScrollX = 0.0.cf, cutHeight = 0.0.cf
    
    static let leftWidth = 80.0.cf
    let curretEditKeyframeTimeView = TextView(text: Localization("0 b"), font: .small,
                          frameAlignment: .right, alignment: .right)
    
    let baseTimeIntervalView = DiscreteNumberView(frame: Layout.valueFrame,
                                                  min: 1, max: 1000, numberInterval: 1, unit: " cpb")
    
    let timeRuler = RulerLayer()
    let tempoView = DiscreteNumberView(frame: CGRect(x: 0, y: 0,
                                                     width: leftWidth, height: Layout.basicHeight),
                                       defaultNumber: 120, min: 1, max: 10000, unit: " bpm")
    let tempoAnimationLayer = Layer()
    let tempoAnimationView = AnimationView(height: defaultSumKeyTimesHeight)
    let soundWaveformView = SoundWaveformView()
    let cutViewsLayer = Layer()
    let classSumAnimationNameView = TextView(text: Localization(english: "Sum:", japanese: "合計:"),
                                             font: .small)
    let sumKeyTimesLayer = Layer()
    let sumKeyTimesView = AnimationView(height: defaultSumKeyTimesHeight)
    
    let nodeTreeView = NodeTreeManager()
    let tracksManager = TracksManager()
    
    let timeLayer: Layer = {
        let layer = Layer()
        layer.fillColor = .editing
        layer.lineColor = nil
        return layer
    } ()
    let nodeBindingLineLayer: PathLayer = {
        let layer = PathLayer()
        layer.lineWidth = 5
        layer.lineColor = .border
        return layer
    } ()
    enum BindingKeyframeType {
        case tempo, cut
    }
    var bindingKeyframeType = BindingKeyframeType.cut
    
    let beatsLayer = PathLayer()
    
    let tempoKeyframeView = KeyframeView(sizeType: .small)
    let keyframeView = KeyframeView(), nodeView = NodeView(sizeType: .small)
    
    init(frame: CGRect = CGRect()) {
        tempoAnimationLayer.replace(children: [tempoAnimationView])
        tempoAnimationLayer.isClipped = true
        tempoAnimationView.isEdit = true
        tempoAnimationView.sizeType = .regular
        tempoAnimationView.smallHeight = tempoHeight
        cutViewsLayer.isClipped = true
        sumKeyTimesLayer.isClipped = true
        sumKeyTimesView.isEdit = true
        sumKeyTimesView.smallHeight = sumKeyTimesHeight
        sumKeyTimesLayer.append(child: sumKeyTimesView)
        timeRuler.isClipped = true
        beatsLayer.isClipped = true
        beatsLayer.fillColor = .subContent
        beatsLayer.lineColor = nil
        
        super.init()
        replace(children: [timeLayer, curretEditKeyframeTimeView, beatsLayer, classSumAnimationNameView, sumKeyTimesLayer,
                           timeRuler,
                           tempoAnimationLayer, baseTimeIntervalView,
                           nodeTreeView.nodesView, tracksManager.tracksView,
                           cutViewsLayer])
        if !frame.isEmpty {
            self.frame = frame
        }
        
        tempoAnimationView.setKeyframeClosure = { [unowned self] in
            guard $0.type == .end else {
                return
            }
            let tempoTrack = self.scene.tempoTrack
            switch $0.setType {
            case .insert:
                self.insert($0.keyframe, at: $0.index, in: tempoTrack)
            case .remove:
                self.removeKeyframe(at: $0.index,
                                    in: tempoTrack, in: self.sceneDataModel, time: self.time)
            case .replace:
                self.replace($0.keyframe, at: $0.index,
                             in: tempoTrack, in: self.sceneDataModel, time: self.time)
            }
        }
        tempoAnimationView.slideClosure = { [unowned self] in
            self.setAnimationInTempoTrack(with: $0)
        }
        tempoAnimationView.selectClosure = { [unowned self] in
            self.setAnimationInTempoTrack(with: $0)
        }
        
        sumKeyTimesView.setKeyframeClosure = { [unowned self] binding in
            guard binding.type == .end else {
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
        sumKeyTimesView.slideClosure = { [unowned self] in
            self.setAnimations(with: $0)
        }
        
        nodeTreeView.nodesView.newClosure = { [unowned self] _, _ in
            _ = self.newNode()
            return true
        }
        nodeTreeView.setNodesClosure = { [unowned self] in
            self.setNodes(with: $0)
        }
        nodeTreeView.nodesView.deleteClosure = { [unowned self] _, _ in
            self.remove(self.editCutView.cut.editNode, in: self.editCutView)
            return true
        }
        nodeTreeView.nodesView.pasteClosure = { [unowned self] in
            return self.pasteFromNodesView($1, with: $2)
        }
        
        tracksManager.tracksView.newClosure = { [unowned self] _, _ in
            self.newNodeTrack()
            return true
        }
        tracksManager.setTracksClosure = { [unowned self] in
            self.setNodeTracks(with: $0)
        }
        tracksManager.tracksView.deleteClosure = { [unowned self] _, _ in
            let node = self.editCutView.cut.editNode
            self.remove(trackIndex: node.editTrackIndex, in: node, in: self.editCutView)
            return true
        }
        tracksManager.tracksView.pasteClosure = { [unowned self] in
            return self.pasteFromTracksView($1, with: $2)
        }
    }
    
    override var locale: Locale {
        didSet {
            updateLayout()
        }
    }
    
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    func updateLayout() {
        let sp = Layout.basicPadding
        mainHeight = bounds.height - timeRulerHeight - sumKeyTimesHeight - sp * 2
        cutHeight = mainHeight - tempoHeight - subtitleHeight - soundHeight
        let midX = bounds.midX, leftWidth = Timeline.leftWidth
        let rightX = leftWidth
        timeRuler.frame = CGRect(x: rightX, y: bounds.height - timeRulerHeight - sp,
                                 width: bounds.width - rightX - sp, height: timeRulerHeight)
        curretEditKeyframeTimeView.frame.origin = CGPoint(x: rightX - curretEditKeyframeTimeView.frame.width - Layout.smallPadding,
                                         y: bounds.height - timeRulerHeight
                                            - Layout.basicPadding + Layout.smallPadding)
        tempoAnimationLayer.frame = CGRect(x: rightX,
                                         y: bounds.height - timeRulerHeight - tempoHeight - sp,
                                         width: bounds.width - rightX - sp, height: tempoHeight)
        let tracksHeight = 30.0.cf
        tracksManager.tracksView.frame = CGRect(x: sp, y: sumKeyTimesHeight + sp,
                                                width: leftWidth - sp,
                                                height: tracksHeight)
        nodeTreeView.nodesView.frame = CGRect(x: sp, y: sumKeyTimesHeight + sp + tracksHeight,
                                              width: leftWidth - sp,
                                              height: cutHeight - tracksHeight)
        cutViewsLayer.frame = CGRect(x: rightX, y: sumKeyTimesHeight + sp,
                                   width: bounds.width - rightX - sp,
                                   height: mainHeight - tempoHeight)
        classSumAnimationNameView.frame.origin = CGPoint(x: rightX - classSumAnimationNameView.frame.width,
                                        y: sp + (sumKeyTimesHeight - classSumAnimationNameView.frame.height) / 2)
        sumKeyTimesLayer.frame = CGRect(x: rightX, y: sp,
                                      width: bounds.width - rightX - sp, height: sumKeyTimesHeight)
        timeLayer.frame = CGRect(x: midX - baseWidth / 2, y: sp,
                                 width: baseWidth, height: bounds.height - sp * 2)
        beatsLayer.frame = CGRect(x: rightX, y: 0,
                                  width: bounds.width - rightX, height: bounds.height)
        let bx = sp + (sumKeyTimesHeight - baseTimeIntervalView.frame.height) / 2
        baseTimeIntervalView.frame.origin = CGPoint(x: sp, y: bx)
    }
    
    private var _scrollPoint = CGPoint(), _intervalScrollPoint = CGPoint()
    var scrollPoint: CGPoint {
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
                updateWith(time: newValue, scrollPoint: CGPoint(x: x(withTime: newValue), y: 0))
            }
        }
    }
    private func updateWithTime() {
        updateWith(time: time, scrollPoint: _scrollPoint)
    }
    private func updateNoIntervalWith(time: Beat) {
        if time != scene.time {
            updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0),
                       isIntervalScroll: false)
        }
    }
    private func updateWith(time: Beat, scrollPoint: CGPoint,
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
            sceneDataModel?.isWrite = true
        }
        updateWithScrollPosition()
        updateView(isCut: true, isTransform: true, isKeyframe: true)
    }
    var updateViewClosure: (((isCut: Bool, isTransform: Bool, isKeyframe: Bool)) -> ())?
    private func updateView(isCut: Bool, isTransform: Bool, isKeyframe: Bool) {
        if isKeyframe {
            updateKeyframeView()
            let cutItem = scene.editCut
            let animation = cutItem.editNode.editTrack.animation
            let t = cutItem.currentTime >= animation.duration ?
                animation.duration : animation.editKeyframe.time
            let cutAnimation = scene.cutTrack.animation
            editedKeyframeTime = cutAnimation.keyframes[cutAnimation.editLoopframeIndex].time + t
            tempoView.number = scene.tempoTrack.tempoItem.tempo
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
    private func intervalScrollPoint(with scrollPoint: CGPoint) -> CGPoint {
        return CGPoint(x: x(withTime: time(withLocalX: scrollPoint.x)), y: 0)
    }
    
    var editCutView: CutView {
        return cutViews[scene.editCutIndex]
    }
    var cutViews = [CutView]() {
        didSet {
            cutViews.enumerated().forEach { $1.updateIndex($0) }
            
            var subtitleTextViews = [Layer]()
            cutViews.forEach { subtitleTextViews += $0.subtitleTextViews as [Layer] }
            
            cutViewsLayer.replace(children: cutViews.reversed() as [Layer]
                + cutViews.map { $0.subtitleAnimationView } as [Layer] + subtitleTextViews as [Layer] + [soundWaveformView] as [Layer])
            updateCutViewPositions()
        }
    }
    private func updateWithScrollPosition() {
        let minX = localDeltaX
        _ = cutViews.reduce(minX) { x, cutView in
            cutView.frame.origin = CGPoint(x: x, y: 0)
            
            cutView.subtitleAnimationView.frame.origin = CGPoint(x: x, y: cutView.frame.height)
            _ = cutView.subtitleTextViews.reduce(x) {
                $1.frame.size = CGSize(width: 100, height: Layout.basicHeight)
                $1.frame.origin = CGPoint(x: $0, y: cutView.frame.height + cutView.subtitleAnimationView.frame.height)
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
        soundWaveformView.frame.origin = CGPoint(x: minX, y: cutViewsLayer.frame.height - soundWaveformView.frame.height)
        tempoAnimationView.frame.origin = CGPoint(x: minX, y: 0)
        sumKeyTimesView.frame.origin.x = minX
        updateBeats()
        updateTimeRuler()
    }
    func updateCutViewPositions() {
        maxScrollX = x(withTime: scene.duration)
        let minX = localDeltaX
        _ = cutViews.reduce(minX) { x, cutView in
            cutView.frame.origin = CGPoint(x: x, y: 0)
            cutView.subtitleAnimationView.frame.origin = CGPoint(x: x, y: cutView.frame.height)
            _ = cutView.subtitleTextViews.reduce(x) {
                $1.frame.size = CGSize(width: 100, height: Layout.basicHeight)
                $1.frame.origin = CGPoint(x: $0, y: cutView.frame.height + cutView.subtitleAnimationView.frame.height)
                return $0 + $1.frame.width
            }
            return x + cutView.frame.width
        }
        tempoAnimationView.frame.origin = CGPoint(x: minX, y: 0)
        updateBeats()
        updateTimeRuler()
        updateSumKeyTimesView()
    }
    var mainHeight = 0.0.cf
    func cutViews(with scene: Scene) -> [CutView] {
        return scene.cuts.enumerated().map {
            self.bindedCutView(with: $0.element,
                                 beginBaseTime: scene.cutTrack.time(at: $0.offset), height: cutHeight)
        }
    }
    func bindedCutView(with cut: Cut, beginBaseTime: Beat = 0, height: CGFloat) -> CutView {
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
                        return true
                    }
                }
            }
            return false
        }
        cutView.deleteClosure = { [unowned self] in
            if let index = self.cutViews.index(of: $0) {
                self.removeCut(at: index)
            }
            return true
        }
        cutView.scrollClosure = { [unowned self, unowned cutView] obj in
            if obj.type == .end {
                if obj.nodeAndTrack != obj.oldNodeAndTrack {
                    self.registerUndo(time: self.time) {
                        self.set(obj.oldNodeAndTrack, old: obj.nodeAndTrack, in: cutView, time: $1)
                    }
                    self.sceneDataModel?.isWrite = true
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
            var subtitleTextViews = [Layer]()
            self.cutViews.forEach { subtitleTextViews += $0.subtitleTextViews as [Layer] }
            self.cutViewsLayer.replace(children: self.cutViews.reversed() as [Layer]
                + self.cutViews.map { $0.subtitleAnimationView } as [Layer] + subtitleTextViews as [Layer] + [self.soundWaveformView] as [Layer])
            self.updateWithScrollPosition()
        }
        cutView.subtitleBinding = { [unowned self] _ in
            self.updateWithScrollPosition()
        }
        return cutView
    }
    var setNodeAndTrackBinding: ((Timeline, CutView, Cut.NodeAndTrack) -> ())?
    
    func bind(in animationView: AnimationView, in cutView: CutView,
              from nodeAndTrack: Cut.NodeAndTrack) {
        animationView.setKeyframeClosure = { [unowned self, unowned cutView] in
            guard $0.type == .end else {
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
        let minTime = time(withLocalX: convertToLocalX(bounds.minX + Timeline.leftWidth))
        let maxTime = time(withLocalX: convertToLocalX(bounds.maxX))
        let minSecond = Int(floor(scene.secondTime(withBeatTime: minTime)))
        let maxSecond = Int(ceil(scene.secondTime(withBeatTime: maxTime)))
        guard minSecond < maxSecond else {
            timeRuler.scaleTextViews = []
            return
        }
        timeRuler.scrollPosition.x = localDeltaX
        timeRuler.scaleTextViews = (minSecond ... maxSecond).compactMap {
            guard !(maxSecond - minSecond > Int(bounds.width / 40) && $0 % 5 != 0) else {
                return nil
            }
            let timeView = Timeline.timeView(withSecound: $0)
            timeView.fillColor = nil
            let secondX = x(withTime: scene.basedBeatTime(withSecondTime: Second($0)))
            timeView.frame.origin = CGPoint(x: secondX - timeView.frame.width / 2,
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
        return TextView(text: Localization(string), font: .small)
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
    
    let beatsLineWidth = 1.0.cf, barLineWidth = 3.0.cf, beatsPerBar = 0
    func updateBeats() {
        guard baseTimeInterval < 1 else {
            beatsLayer.path = nil
            return
        }
        let minX = localDeltaX
        let minTime = time(withLocalX: convertToLocalX(bounds.minX + Timeline.leftWidth))
        let maxTime = time(withLocalX: convertToLocalX(bounds.maxX))
        let intMinTime = floor(minTime).integralPart, intMaxTime = ceil(maxTime).integralPart
        guard intMinTime < intMaxTime else {
            beatsLayer.path = nil
            return
        }
        let padding = Layout.basicPadding
        let path = CGMutablePath()
        let rects: [CGRect] = (intMinTime ... intMaxTime).map {
            let i0x = x(withDoubleBeatTime: DoubleBeat($0)) + minX
            let w = beatsPerBar != 0 && $0 % beatsPerBar == 0 ? barLineWidth : beatsLineWidth
            return CGRect(x: i0x - w / 2, y: padding, width: w, height: bounds.height - padding * 2)
        }
        path.addRects(rects)
        beatsLayer.path = path
    }
    
    var contentFrame: CGRect {
        return CGRect(x: _scrollPoint.x, y: 0, width: x(withTime: scene.duration), height: 0)
    }
    
    func time(withLocalX x: CGFloat, isBased: Bool = true) -> Beat {
        return isBased ?
            scene.baseTimeInterval * Beat(Int(round(x / baseWidth))) :
            scene.basedBeatTime(withDoubleBeatTime:
                DoubleBeat(x / baseWidth) * DoubleBeat(scene.baseTimeInterval))
    }
    func x(withTime time: Beat) -> CGFloat {
        return scene.doubleBeatTime(withBeatTime: time / scene.baseTimeInterval).cf * baseWidth
    }
    func doubleBeatTime(withLocalX x: CGFloat, isBased: Bool = true) -> DoubleBeat {
        return DoubleBeat(isBased ? round(x / baseWidth) : x / baseWidth)
            * DoubleBeat(scene.baseTimeInterval)
    }
    func x(withDoubleBeatTime doubleBeatTime: DoubleBeat) -> CGFloat {
        return CGFloat(doubleBeatTime * DoubleBeat(scene.baseTimeInterval.inversed!)) * baseWidth
    }
    func doubleBaseTime(withLocalX x: CGFloat) -> DoubleBaseTime {
        return DoubleBaseTime(x / baseWidth)
    }
    func localX(withDoubleBaseTime doubleBaseTime: DoubleBaseTime) -> CGFloat {
        return CGFloat(doubleBaseTime) * baseWidth
    }
    func beatTime(withBaseTime baseTime: BaseTime) -> Beat {
        return baseTime * scene.baseTimeInterval
    }
    func baseTime(withBeatTime beatTime: Beat) -> BaseTime {
        return beatTime / scene.baseTimeInterval
    }
    func basedBeatTime(withDoubleBaseTime doubleBaseTime: DoubleBaseTime) -> Beat {
        return Beat(Int(doubleBaseTime)) * scene.baseTimeInterval
    }
    func doubleBaseTime(withBeatTime beatTime: Beat) -> DoubleBaseTime {
        return DoubleBaseTime(beatTime / scene.baseTimeInterval)
    }
    func doubleBaseTime(withX x: CGFloat) -> DoubleBaseTime {
        return DoubleBaseTime(x / baseWidth)
    }
    func basedBeatTime(withDoubleBeatTime doubleBeatTime: DoubleBeat) -> Beat {
        return Beat(Int(doubleBeatTime / DoubleBeat(scene.baseTimeInterval))) * scene.baseTimeInterval
    }
    func clipDeltaTime(withTime time: Beat) -> Beat {
        let ft = baseTime(withBeatTime: time)
        let fft = ft + BaseTime(1, 2)
        return fft - floor(fft) < BaseTime(1, 2) ?
            beatTime(withBaseTime: ceil(ft)) - time :
            beatTime(withBaseTime: floor(ft)) - time
    }
    
    func cutIndex(withLocalX x: CGFloat) -> Int {
        return scene.cutTrack.index(atTime: time(withLocalX: x))
    }
    func cutIndex(withTime time: Beat) -> Int {
        return scene.cutTrack.index(atTime: time)
    }
    func movingCutIndex(withTime time: Beat) -> Int {
        return scene.cutTrack.movingCutIndex(withTime: time)
    }
    
    var editX: CGFloat {
        return bounds.midX - Timeline.leftWidth
    }
    
    var localDeltaX: CGFloat {
        return editX - _intervalScrollPoint.x
    }
    func convertToLocalX(_ x: CGFloat) -> CGFloat {
        return x - Timeline.leftWidth - localDeltaX
    }
    func convertFromLocalX(_ x: CGFloat) -> CGFloat {
        return x - Timeline.leftWidth + localDeltaX
    }
    func convertToLocal(_ p: CGPoint) -> CGPoint {
        return CGPoint(x: convertToLocalX(p.x), y: p.y)
    }
    func convertFromLocal(_ p: CGPoint) -> CGPoint {
        return CGPoint(x: convertFromLocalX(p.x), y: p.y)
    }
    func nearestKeyframeIndexTuple(at p: CGPoint) -> (cutIndex: Int, keyframeIndex: Int?) {
        let ci = cutIndex(withLocalX: p.x)
        let cut = scene.cuts[ci], ct = scene.cuts[ci].currentTime
        guard cut.editNode.editTrack.animation.keyframes.count > 0 else {
            fatalError()
        }
        var minD = CGFloat.infinity, minI = 0
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
    func trackIndexTuple(at p: CGPoint) -> (cutIndex: Int, trackIndex: Int, keyframeIndex: Int?) {
        let ci = cutIndex(withLocalX: p.x)
        let cut = scene.cuts[ci], ct = scene.cutTrack.animation.keyframes[ci].time
        var minD = CGFloat.infinity, minKeyframeIndex = 0, minTrackIndex = 0
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
            baseTimeIntervalView.stringView.localization = Localization("\(baseTimeInterval.inversed!) cpb")
            
            scene.baseTimeInterval = baseTimeInterval
            sceneDataModel?.isWrite = true
        }
    }
    
    var sceneDataModel: DataModel?
    
    private func registerUndo(time: Beat, _ closure: @escaping (Timeline, Beat) -> Void) {
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
                   scrollPoint: CGPoint(x: x(withTime: time), y: 0),
                   alwaysUpdateCutIndex: alwaysUpdateCutIndex)
        sceneDataModel?.isWrite = true
        updateView(isCut: true, isTransform: false, isKeyframe: false)
    }
    
    func paste(_ objects: [Any], with event: KeyInputEvent) -> Bool {
        for object in objects {
            if let cut = object as? Cut {
                let localX = convertToLocalX(point(from: event).x)
                let index = cutIndex(withLocalX: localX)
                paste(cut.copied, at: index + 1)
                return true
            }
        }
        return false
    }
    func paste(_ cut: Cut, at index: Int) {
        insert(bindedCutView(with: cut, height: cutHeight), at: index, time: time)
        set(time: scene.cutTrack.time(at: index), oldTime: time)
    }
    
    func delete(with event: KeyInputEvent) -> Bool {
        let localX = convertToLocalX(point(from: event).x)
        let cutIndex = self.cutIndex(withLocalX: localX)
        removeCut(at: cutIndex)
        return true
    }
    
    func new(with event: KeyInputEvent) -> Bool {
        let localX = convertToLocalX(point(from: event).x)
        let cutIndex = self.cutIndex(withLocalX: localX)
        let cut = Cut()
        let cutView = self.bindedCutView(with: cut, height: cutHeight)
        insert(cutView, at: cutIndex + 1, time: time)
        set(time: scene.cutTrack.time(at: cutIndex + 1), oldTime: time)
        return true
    }
    
    func insert(_ cutView: CutView, at index: Int, time: Beat) {
        registerUndo(time: time) { $0.removeCutView(at: index, time: $1) }
        insert(cutView, at: index)
    }
    func insert(_ cutView: CutView, at index: Int) {
        scene.cutTrack.insert(cutView.cut, at: index)
        cutViews.insert(cutView, at: index)
        updateCutViewPositions()
        sceneDataModel?.isWrite = true
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
        sceneDataModel?.isWrite = true
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
        return Localization(english: "Node \(index)", japanese: "ノード\(index)").currentString
    }
    func newNode() -> Bool {
        let node = Node(name: newNodeName)
        node.editTrack.name = Localization(english: "Track 0", japanese: "トラック0").currentString
        return append(node, in: editCutView)
    }
    func pasteFromNodesView(_ objects: [Any], with event: KeyInputEvent) -> Bool {
        for object in objects {
            if let node = object as? Node {
                return append(node.copied, in: editCutView)
            }
        }
        return false
    }
    func append(_ node: Node, in cutView: CutView) -> Bool {
        guard let parent = cutView.cut.editNode.parent,
            let index = parent.children.index(of: cutView.cut.editNode) else {
                return false
        }
        let animationViews = cutView.newAnimationViews(with: node)
        insert(node, animationViews, at: index + 1, parent: parent, in: cutView, time: time)
        set(node, in: cutView)
        return true
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
        sceneDataModel?.isWrite = true
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
        sceneDataModel?.isWrite = true
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
        return Localization(english: "Track \(index)", japanese: "トラック\(index)").currentString
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
    func pasteFromTracksView(_ objects: [Any], with event: KeyInputEvent) -> Bool {
        for object in objects {
            if let track = object as? NodeTrack {
                return append(track.copied, in: editCutView)
            }
        }
        return false
    }
    func append(_ track: NodeTrack, in cutView: CutView) -> Bool {
        let node = cutView.cut.editNode
        let index = node.editTrackIndex
        let animationView = cutView.newAnimationView(with: track, node: node, sizeType: .regular)
        insert(track, animationView, at: index + 1, in: node, in: cutView, time: time)
        bind(in: animationView, in: cutView,
             from: Cut.NodeAndTrack(node: node, trackIndex: index))
        set(editTrackIndex: index + 1, oldEditTrackIndex: node.editTrackIndex,
            in: node, in: cutView, time: time)
        return true
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
        sceneDataModel?.isWrite = true
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
        sceneDataModel?.isWrite = true
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
        sceneDataModel?.isWrite = true
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
        sceneDataModel?.isWrite = true
        if cutView.cut == nodeTreeView.cut {
            nodeTreeView.updateWithNodes()
            setNodeAndTrackBinding?(self, cutView, editNodeAndTrack)
        }
    }
    
    private var isUpdateSumKeyTimes = true
    private var moveAnimationViews = [(animationView: AnimationView, keyframeIndex: Int?)]()
    private func setAnimations(with obj: AnimationView.SlideBinding) {
        switch obj.type {
        case .begin:
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
                _ = $0.animationView.move(withDeltaTime: obj.deltaTime,
                                          keyframeIndex: $0.keyframeIndex, sendType: obj.type)
            }
        case .sending:
            moveAnimationViews.forEach {
                _ = $0.animationView.move(withDeltaTime: obj.deltaTime,
                                            keyframeIndex: $0.keyframeIndex, sendType: obj.type)
            }
        case .end:
            moveAnimationViews.forEach {
                _ = $0.animationView.move(withDeltaTime: obj.deltaTime,
                                            keyframeIndex: $0.keyframeIndex, sendType: obj.type)
            }
            moveAnimationViews = []
            isUpdateSumKeyTimes = true
        }
    }
    
    private var oldTempoTrack: TempoTrack?
    private func setAnimationInTempoTrack(with obj: AnimationView.SlideBinding) {
        switch obj.type {
        case .begin:
            oldTempoTrack = scene.tempoTrack
        case .sending:
            guard let oldTrack = oldTempoTrack else {
                return
            }
            oldTrack.replace(obj.animation.keyframes)
            updateTimeRuler()
            soundWaveformView.updateWaveform()
        case .end:
            guard let oldTrack = oldTempoTrack else {
                return
            }
            oldTrack.replace(obj.animation.keyframes)
            updateTimeRuler()
            soundWaveformView.updateWaveform()
            if obj.animation != obj.oldAnimation {
                registerUndo(time: time) { [sceneDataModel] in
                    $0.set(obj.oldAnimation, old: obj.animation,
                           in: oldTrack, in: sceneDataModel, time: $1)
                }
                sceneDataModel?.isWrite = true
            }
            self.oldTempoTrack = nil
        }
        updateWithTime()
    }
    private func setAnimationInTempoTrack(with obj: AnimationView.SelectBinding) {
        switch obj.type {
        case .begin:
            oldTempoTrack = scene.tempoTrack
        case .sending:
            break
        case .end:
            guard let oldTrack = oldTempoTrack else {
                return
            }
            if obj.animation != obj.oldAnimation {
                registerUndo(time: time) { [sceneDataModel] in
                    $0.set(obj.oldAnimation, old: obj.animation,
                           in: oldTrack, in: sceneDataModel, time: $1)
                }
                sceneDataModel?.isWrite = true
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
               at: index, in: track, in: sceneDataModel, time: time)
    }
    private func replace(_ keyframe: Keyframe, at index: Int,
                         in track: TempoTrack, in sceneDataModel: DataModel?, time: Beat) {
        registerUndo(time: time) { [ok = track.animation.keyframes[index]] in
            $0.replace(ok, at: index, in: track, in: sceneDataModel, time: $1)
        }
        track.replace(keyframe, at: index)
        tempoAnimationView.animation = track.animation
        sceneDataModel?.isWrite = true
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
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
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
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
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
        updateWithTime()
        updateSumKeyTimesView()
        updateTimeRuler()
        soundWaveformView.updateWaveform()
    }
    
    private func setAnimation(with obj: AnimationView.SlideBinding,
                              in track: NodeTrack, in node: Node, in cutView: CutView) {
        switch obj.type {
        case .begin:
            break
        case .sending:
            track.replace(obj.animation.keyframes, duration: obj.animation.duration)
            updateCutDuration(with: cutView)
        case .end:
            track.replace(obj.animation.keyframes, duration: obj.animation.duration)
            if obj.animation != obj.oldAnimation {
                registerUndo(time: time) {
                    $0.set(obj.oldAnimation, old: obj.animation,
                           in: track, in: obj.animationView, in: cutView, time: $1)
                }
                
                node.differentialDataModel.isWrite = true
                sceneDataModel?.isWrite = true
            }
            updateCutDuration(with: cutView)
        }
        updateWithTime()
    }
    private func setAnimation(with obj: AnimationView.SelectBinding,
                              in track: NodeTrack, in cutView: CutView) {
        switch obj.type {
        case .begin:
            break
        case .sending:
            break
        case .end:
            if obj.animation != obj.oldAnimation {
                registerUndo(time: time) {
                    $0.set(obj.oldAnimation, old: obj.animation,
                           in: track, in: obj.animationView, in: cutView, time: $1)
                }
                sceneDataModel?.isWrite = true
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
        sceneDataModel?.isWrite = true
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
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
        sceneDataModel?.isWrite = true
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
        sceneDataModel?.isWrite = true
        animationView.animation = track.animation
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
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
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
        node.differentialDataModel.isWrite = true
        sceneDataModel?.isWrite = true
        animationView.animation = track.animation
        updateView(isCut: true, isTransform: false, isKeyframe: false)
        updateSumKeyTimesView()
    }
    
    func updateCutDuration(with cutView: CutView) {
        cutView.cut.duration = cutView.cut.maxDuration
        cutView.updateWithDuration()
        scene.cutTrack.updateCutTimeAndDuration()
        sceneDataModel?.isWrite = true
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
        switch obj.type {
        case .begin:
            oldCutView = editCutView
        case .sending, .end:
            guard let cutView = oldCutView else {
                return
            }
            cutView.moveNode(from: obj.oldIndex, fromParemt: obj.fromNode,
                               to: obj.index, toParent: obj.toNode)
            if cutView.cut == obj.nodeTreeView.cut {
                obj.nodeTreeView.updateWithNodes(isAlwaysUpdate: true)
                tracksManager.updateWithTracks(isAlwaysUpdate: true)
            }
            if obj.type == .end {
                if obj.index != obj.beginIndex || obj.toNode != obj.beginNode {
                    registerUndo(time: time) {
                        $0.moveNode(from: obj.index, fromParent: obj.toNode,
                                    to: obj.beginIndex, toParent: obj.beginNode,
                                    in: cutView, time: $1)
                    }
                    sceneDataModel?.isWrite = true
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
        sceneDataModel?.isWrite = true
        if cutView.cut == nodeTreeView.cut {
            nodeTreeView.updateWithNodes(isAlwaysUpdate: true)
            tracksManager.updateWithTracks(isAlwaysUpdate: true)
        }
    }
    
    private func setNodeTracks(with obj: TracksManager.NodeTracksBinding) {
        switch obj.type {
        case .begin:
            oldCutView = editCutView
        case .sending, .end:
            guard let cutView = oldCutView else {
                return
            }
            cutView.moveTrack(from: obj.oldIndex, to: obj.index, in: obj.inNode)
            cutView.set(editTrackIndex: obj.index, in: obj.inNode)
            if cutView.cut.editNode == obj.tracksManager.node {
                obj.tracksManager.updateWithTracks(isAlwaysUpdate: true)
            }
            if obj.type == .end {
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
                    sceneDataModel?.isWrite = true
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
        sceneDataModel?.isWrite = true
        if cutView.cut == nodeTreeView.cut {
            nodeTreeView.updateWithNodes(isAlwaysUpdate: true)
            tracksManager.updateWithTracks(isAlwaysUpdate: true)
        }
    }
    
    var setSceneDurationClosure: ((Timeline, Beat) -> ())?
    
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
    
    var scrollClosure: ((Timeline, CGPoint, ScrollEvent) -> ())?
    private var isScrollTrack = false
    private weak var scrollCutView: CutView?
    func scroll(with event: ScrollEvent) -> Bool {
        if event.sendType == .begin {
            isScrollTrack = abs(event.scrollDeltaPoint.x) < abs(event.scrollDeltaPoint.y)
        }
        if isScrollTrack {
            if event.sendType == .begin {
                scrollCutView = editCutView
            }
            scrollCutView?.scrollTrack(with: event)
        } else {
            scrollTime(with: event)
        }
        return true
    }
    
    private var indexScrollDeltaPosition = CGPoint(), indexScrollBeginX = 0.0.cf
    private var indexScrollIndex = 0, indexScrollWidth = 14.0.cf
    func indexScroll(with event: ScrollEvent) {
        guard event.scrollMomentumType == nil else {
            return
        }
        switch event.sendType {
        case .begin:
            indexScrollDeltaPosition = CGPoint()
            indexScrollIndex = currentAllKeyframeIndex
        case .sending, .end:
            indexScrollDeltaPosition += event.scrollDeltaPoint
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
    
    private var isIndexScroll = false
    func scrollTime(with event: ScrollEvent) {
        if event.sendType == .begin {
            isIndexScroll = event.beginNormalizedPosition.y > 0.85
        }
        if isIndexScroll {
            indexScroll(with: event)
        } else {
            let maxX = self.x(withTime: scene.duration)
            let x = (scrollPoint.x - event.scrollDeltaPoint.x).clip(min: 0, max: maxX)
            scrollPoint = CGPoint(x: event.sendType == .begin ?
                self.x(withTime: time(withLocalX: x)) : x, y: 0)
            scrollClosure?(self, scrollPoint, event)
        }
    }
    
    private var baseTimeIntervalOldTime = Second(0)
    private var floatBaseTimeInterval = 0.0.cf, beginBaseTimeInterval = Beat(1)
    func zoom(with event: PinchEvent) -> Bool {
        switch event.sendType {
        case .begin:
            baseTimeIntervalOldTime = scene.secondTime(withBeatTime: scene.time)
            beginBaseTimeInterval = baseTimeInterval
            floatBaseTimeInterval = 0
        case .sending, .end:
            floatBaseTimeInterval += event.magnification * 40
            if beginBaseTimeInterval.q == 1 {
                let p = beginBaseTimeInterval.p - Int(floatBaseTimeInterval)
                baseTimeInterval = p < 1 ? Beat(1, 2 - p) : Beat(p)
            } else {
                let q = beginBaseTimeInterval.q + Int(floatBaseTimeInterval)
                baseTimeInterval = q < 1 ? Beat(2 - q) : Beat(1, q)
            }
            updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0),
                       isIntervalScroll: false)
            updateWithTime()
        }
//        zoom(at: point(from: event)) {
//            baseWidth = (baseWidth * (event.magnification * 2.5 + 1))
//                .clip(min: 1, max: Timeline.defautBaseWidth)
//        }
        return true
    }
//    func resetView(with event: DoubleTapEvent) -> Bool {
//        guard baseWidth != Timeline.defautBaseWidth else {
//            return false
//        }
//        zoom(at: point(from: event)) {
//            baseWidth = Timeline.defautBaseWidth
//        }
//        return true
//    }
    func zoom(at p: CGPoint, closure: () -> ()) {
        closure()
        _scrollPoint.x = x(withTime: time)
        _intervalScrollPoint.x = scrollPoint.x
        updateView(isCut: false, isTransform: false, isKeyframe: false)
    }
    
    static let name = Localization(english: "Timeline", japanese: "タイムライン")
    static let feature = Localization(english: "Select time: Left and right scroll\nSelect track: Up and down scroll",
                                      japanese: "時間選択: 左右スクロール\nトラック選択: 上下スクロール")
    
}

final class RulerLayer: Layer {
    private let scroller: Layer = {
        let layer = Layer()
        layer.lineColor = nil
        return layer
    } ()
    
    override init() {
        super.init()
        append(child: scroller)
    }
    
    var scrollPosition: CGPoint {
        get  {
            return scroller.frame.origin
        }
        set {
            scroller.frame.origin = newValue
        }
    }
    var scrollFrame = CGRect()
    
    var scaleTextViews = [TextView]() {
        didSet {
            scroller.replace(children: scaleTextViews)
        }
    }
}
