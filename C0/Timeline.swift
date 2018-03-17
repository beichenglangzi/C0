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
 - Bar設定
 - ノードトラック、ノード、カットの複数選択
 - 滑らかなスクロール
 - sceneを取り除く
 - スクロールの可視性の改善
 */
final class Timeline: Layer, Respondable, Localizable {
    static let name = Localization(english: "Timeline", japanese: "タイムライン")
    static let feature = Localization(
        english: "Select time: Left and right scroll\nSelect animation: Up and down scroll",
        japanese: "時間選択: 左右スクロール\nグループ選択: 上下スクロール"
    )
    
    var locale = Locale.current {
        didSet {
            updateLayout()
        }
    }
    
    var scene = Scene() {
        didSet {
            _scrollPoint.x = x(withTime: scene.time)
            _intervalScrollPoint.x = x(withTime: time(withLocalX: _scrollPoint.x))
            cutEditors = self.cutEditors(with: scene)
            editCutEditor.isEdit = true
            baseTimeInterval = scene.baseTimeInterval
            tempoSlider.value = scene.tempoTrack.tempoItem.tempo
            tempoAnimationEditor.animation = scene.tempoTrack.animation
            tempoAnimationEditor.frame.size.width = maxScrollX
            
            soundWaveformView.tempoTrack = scene.tempoTrack
            soundWaveformView.sound = scene.sound
            
            updateWith(time: scene.time, scrollPoint: _scrollPoint)
        }
    }
    var indicatedTime = 0
    var setEditCutItemIndexHandler: ((Timeline, Int) -> ())?
    var editCutIndex: Int {
        get {
            return scene.editCutIndex
        }
        set {
            scene.editCutIndex = newValue
            updateView(isCut: false, isTransform: false, isKeyframe: true)
            setEditCutItemIndexHandler?(self, editCutIndex)
        }
    }
    
    var editedKeyframeTime = Beat(0) {
        didSet {
            if editedKeyframeTime != oldValue {
                let oldFrame = timeLabel.frame
                timeLabel.localization = Localization(Timeline.timeString(atTime: editedKeyframeTime))
                timeLabel.frame.origin.x = oldFrame.maxX - timeLabel.bounds.width
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
            sumKeyTimesEditor.baseWidth = baseWidth
            tempoAnimationEditor.baseWidth = baseWidth
            soundWaveformView.baseWidth = baseWidth
            cutEditors.forEach { $0.baseWidth = baseWidth }
            updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: _scrollPoint.y))
        }
    }
    private let timeHeight = defaultTimeHeight
    private let timeRulerHeight = 14.0.cf, tempoHeight = defaultSumKeyTimesHeight
    private let speechHeight = 24.0.cf, soundHeight = 20.0.cf
    private let sumKeyTimesHeight = defaultSumKeyTimesHeight
    private let knobHalfHeight = 8.0.cf, subKnobHalfHeight = 4.0.cf, maxLineHeight = 3.0.cf
    private(set) var maxScrollX = 0.0.cf, cutHeight = 0.0.cf
    
    static let leftWidth = 80.0.cf
    let timeLabel = Label(text: Localization("0 b"), font: .small,
                          frameAlignment: .right, alignment: .right)
    let timeRuler = Ruler()
    
    let tempoSlider = NumberSlider(frame: CGRect(x: 0, y: 0,
                                                 width: leftWidth, height: Layout.basicHeight),
                                   defaultValue: 120, min: 1, max: 10000, unit: " bpm",
                                   description: Localization(english: "Tempo", japanese: "テンポ"))
    let tempoAnimationEditor = AnimationEditor(height: defaultSumKeyTimesHeight)
    let tempoEditor = Box()
    let soundWaveformView = SoundWaveformView()
    let nodeTreeEditor = NodeTreeManager()
    let tracksManager = TracksManager()
    let cutEditorsClipEditor = Box()
    let sumLabel = Label(text: Localization(english: "Sum:", japanese: "合計:"), font: .small)
    let sumKeyTimesEditor = AnimationEditor(height: defaultSumKeyTimesHeight)
    let sumKeyTimesCliper = Box()
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
    
    let keyframeEditor = KeyframeEditor(), nodeEditor = NodeEditor()
    
    init(frame: CGRect = CGRect(), description: Localization = Localization()) {
        tempoEditor.replace(children: [tempoAnimationEditor])
        tempoEditor.isClipped = true
        tempoAnimationEditor.isEdit = true
        tempoAnimationEditor.isSmall = false
        tempoAnimationEditor.smallHeight = tempoHeight
        cutEditorsClipEditor.isClipped = true
        sumKeyTimesCliper.isClipped = true
        sumKeyTimesEditor.isEdit = true
        sumKeyTimesEditor.smallHeight = sumKeyTimesHeight
        sumKeyTimesCliper.append(child: sumKeyTimesEditor)
        timeRuler.isClipped = true
        beatsLayer.isClipped = true
        beatsLayer.fillColor = .subContent
        beatsLayer.lineColor = nil
        
        super.init()
        instanceDescription = description
        replace(children: [timeLayer, timeLabel, beatsLayer, sumLabel, sumKeyTimesCliper, timeRuler,
                           tempoEditor,
                           nodeTreeEditor.nodesEditor, tracksManager.tracksEditor,
                           cutEditorsClipEditor])
        if !frame.isEmpty {
            self.frame = frame
        }
        
        tempoEditor.moveHandler = { [unowned self] in
            if ($1.sendType == .begin &&
                self.tempoAnimationEditor.frame.maxX <= $0.point(from: $1).x) ||
                $1.sendType != .begin {

                return self.tempoAnimationEditor.move(with: $1)
            } else {
                return false
            }
        }
        cutEditorsClipEditor.moveHandler = { [unowned self] in
            if let lastEditor = self.cutEditors.last {
                if ($1.sendType == .begin && lastEditor.frame.maxX <= $0.point(from: $1).x) ||
                    $1.sendType != .begin {

                    return lastEditor.editAnimationEditor.move(with: $1)
                }
            }
            return false
        }
        
        tempoAnimationEditor.setKeyframeHandler = { [unowned self] in
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
        tempoAnimationEditor.slideHandler = { [unowned self] in
            self.setAnimationInTempoTrack(with: $0)
        }
        tempoAnimationEditor.selectHandler = { [unowned self] in
            self.setAnimationInTempoTrack(with: $0)
        }
        
        tempoEditor.bindHandler = { [unowned self] _, _ in
            return self.bindKeyframe(bindingKeyframeType: .tempo)
        }
        cutEditorsClipEditor.bindHandler = { [unowned self] _, _ in
            return self.bindKeyframe(bindingKeyframeType: .cut)
        }
        
        sumKeyTimesEditor.setKeyframeHandler = { [unowned self] binding in
            guard binding.type == .end else {
                return
            }
            self.isUpdateSumKeyTimes = false
            let cutIndex = self.movingCutIndex(withTime: binding.keyframe.time)
            let cutEditor = self.cutEditors[cutIndex]
            let cutTime = self.scene.cutTrack.time(at: cutIndex)
            switch binding.setType {
            case .insert:
                _ = self.tempoAnimationEditor.splitKeyframe(withTime: binding.keyframe.time)
                cutEditor.animationEditors.forEach {
                    _ = $0.splitKeyframe(withTime: binding.keyframe.time - cutTime)
                }
            case .remove:
                _ = self.tempoAnimationEditor.deleteKeyframe(withTime: binding.keyframe.time)
                cutEditor.animationEditors.forEach {
                    _ = $0.deleteKeyframe(withTime: binding.keyframe.time - cutTime)
                }
                self.updateSumKeyTimesEditor()
            case .replace:
                break
            }
            self.isUpdateSumKeyTimes = true
        }
        sumKeyTimesEditor.slideHandler = { [unowned self] in
            self.setAnimations(with: $0)
        }
        
        nodeTreeEditor.nodesEditor.newHandler = { [unowned self] _, _ in
            _ = self.newNode()
            return true
        }
        nodeTreeEditor.setNodesHandler = { [unowned self] in
            self.setNodes(with: $0)
        }
        nodeTreeEditor.nodesEditor.deleteHandler = { [unowned self] _, _ in
            self.remove(self.editCutEditor.cut.editNode, in: self.editCutEditor)
            return true
        }
        nodeTreeEditor.nodesEditor.pasteHandler = { [unowned self] in
            return self.pasteFromNodesEditor($1, with: $2)
        }
        
        tracksManager.tracksEditor.newHandler = { [unowned self] _, _ in
            self.newNodeTrack()
            return true
        }
        tracksManager.setTracksHandler = { [unowned self] in
            self.setNodeTracks(with: $0)
        }
        tracksManager.tracksEditor.deleteHandler = { [unowned self] _, _ in
            let node = self.editCutEditor.cut.editNode
            self.remove(trackIndex: node.editTrackIndex, in: node, in: self.editCutEditor)
            return true
        }
        tracksManager.tracksEditor.pasteHandler = { [unowned self] in
            return self.pasteFromTracksEditor($1, with: $2)
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
        cutHeight = mainHeight - tempoHeight - speechHeight - soundHeight
        let midX = bounds.midX, leftWidth = Timeline.leftWidth
        let rightX = leftWidth
        timeRuler.frame = CGRect(x: rightX, y: bounds.height - timeRulerHeight - sp,
                                 width: bounds.width - rightX - sp, height: timeRulerHeight)
        timeLabel.frame.origin = CGPoint(x: rightX - timeLabel.frame.width,
                                         y: bounds.height - timeRulerHeight
                                            - Layout.basicPadding + Layout.smallPadding)
        tempoEditor.frame = CGRect(x: rightX,
                                   y: bounds.height - timeRulerHeight - tempoHeight - sp,
                                   width: bounds.width - rightX - sp, height: tempoHeight)
        let tracksHeight = 30.0.cf
        tracksManager.tracksEditor.frame = CGRect(x: sp, y: sumKeyTimesHeight + sp,
                                                  width: leftWidth - sp,
                                                  height: tracksHeight)
        nodeTreeEditor.nodesEditor.frame = CGRect(x: sp, y: sumKeyTimesHeight + sp + tracksHeight,
                                                  width: leftWidth - sp,
                                                  height: cutHeight - tracksHeight)
        cutEditorsClipEditor.frame = CGRect(x: rightX, y: sumKeyTimesHeight + sp,
                                            width: bounds.width - rightX - sp,
                                            height: mainHeight - tempoHeight)
        sumLabel.frame.origin = CGPoint(x: rightX - sumLabel.frame.width,
                                        y: sp + (sumKeyTimesHeight - sumLabel.frame.height) / 2)
        sumKeyTimesCliper.frame = CGRect(x: rightX, y: sp,
                                          width: bounds.width - rightX - sp, height: sumKeyTimesHeight)
        timeLayer.frame = CGRect(x: midX - baseWidth / 2, y: 0,
                                 width: baseWidth, height: bounds.height)
        beatsLayer.frame = CGRect(x: rightX, y: 0,
                                  width: bounds.width - rightX, height: bounds.height)
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
            editCutEditor.isEdit = false
            self.editCutIndex = cvi.loopFrameIndex
            editCutEditor.isEdit = true
        }
        editCutEditor.cut.currentTime = cvi.interTime
        editCutEditor.updateWithTime()
        scene.tempoTrack.time = time
        sumKeyTimesEditor.animation.update(withTime: time)
        tempoAnimationEditor.updateKeyframeIndex(with: scene.tempoTrack.animation)
        sumKeyTimesEditor.updateKeyframeIndex(with: sumKeyTimesEditor.animation)
        if time != scene.time {
            scene.time = time
            sceneDataModel?.isWrite = true
        }
        updateWithScrollPosition()
        updateView(isCut: true, isTransform: true, isKeyframe: true)
    }
    var updateViewHandler: (((isCut: Bool, isTransform: Bool, isKeyframe: Bool)) -> ())?
    private func updateView(isCut: Bool, isTransform: Bool, isKeyframe: Bool) {
        if isKeyframe {
            updateKeyframeEditor()
            let cutItem = scene.editCut
            let animation = cutItem.editNode.editTrack.animation
            let t = cutItem.currentTime >= animation.duration ?
                animation.duration : animation.editKeyframe.time
            editedKeyframeTime = scene.cutTrack.animation.keyframes[scene.cutTrack.animation.editLoopframeIndex].time + t
            tempoSlider.value = scene.tempoTrack.tempoItem.tempo
        }
        if isCut {
            nodeTreeEditor.cut = scene.editCut
            tracksManager.node = scene.editNode
            nodeEditor.node = scene.editNode
        }
        updateViewHandler?((isCut, isTransform, isKeyframe))
    }
    func updateTime(withCutTime cutTime: Beat) {
        let time = cutTime + scene.cutTrack.time(at: scene.editCutIndex)
        _scrollPoint.x = x(withTime: time)
        self.time = time
    }
    private func intervalScrollPoint(with scrollPoint: CGPoint) -> CGPoint {
        return CGPoint(x: x(withTime: time(withLocalX: scrollPoint.x)), y: 0)
    }
    
    var editCutEditor: CutEditor {
        return cutEditors[scene.editCutIndex]
    }
    var cutEditors = [CutEditor]() {
        didSet {
            cutEditors.enumerated().forEach { $1.updateIndex($0) }
            
            var textEditors = [Layer]()
            cutEditors.forEach { textEditors += $0.speechTextEditors as [Layer] }
            
            cutEditorsClipEditor.replace(children: cutEditors.reversed() as [Layer]
                + cutEditors.map { $0.speechAnimationEditor } as [Layer] + textEditors as [Layer] + [soundWaveformView] as [Layer])
            updateCutEditorPositions()
        }
    }
    private func updateWithScrollPosition() {
        let minX = localDeltaX
        _ = cutEditors.reduce(minX) { x, cutEditor in
            cutEditor.frame.origin = CGPoint(x: x, y: 0)
            cutEditor.speechAnimationEditor.frame.origin = CGPoint(x: x, y: cutEditor.frame.height)
            _ = cutEditor.speechTextEditors.reduce(x) {
                $1.frame.size = CGSize(width: 100, height: Layout.basicHeight)
                $1.frame.origin = CGPoint(x: $0, y: cutEditor.frame.height + cutEditor.speechAnimationEditor.frame.height)
                return $0 + $1.frame.width
            }
            
            if !(cutEditor.frame.minX > bounds.maxX && cutEditor.frame.maxX < bounds.minX) {
                let sp = Layout.smallPadding
                if cutEditor.frame.minX < bounds.minX {
                    let nw = cutEditor.nameLabel.frame.width + sp
                    if bounds.minX + nw > cutEditor.frame.maxX {
                        cutEditor.nameLabel.frame.origin.x = cutEditor.frame.width - nw
                    } else {
                        cutEditor.nameLabel.frame.origin.x = bounds.minX + sp - cutEditor.frame.minX
                    }
                } else {
                    cutEditor.nameLabel.frame.origin.x = sp
                }
            }
            
            return x + cutEditor.frame.width
        }
        soundWaveformView.frame.origin = CGPoint(x: minX, y: cutEditorsClipEditor.frame.height - soundWaveformView.frame.height)
        tempoAnimationEditor.frame.origin = CGPoint(x: minX, y: 0)
        sumKeyTimesEditor.frame.origin.x = minX
        updateBeats()
        updateTimeRuler()
    }
    func updateCutEditorPositions() {
        maxScrollX = x(withTime: scene.duration)
        let minX = localDeltaX
        _ = cutEditors.reduce(minX) { x, cutEditor in
            cutEditor.frame.origin = CGPoint(x: x, y: 0)
            cutEditor.speechAnimationEditor.frame.origin = CGPoint(x: x, y: cutEditor.frame.height)
            _ = cutEditor.speechTextEditors.reduce(x) {
                $1.frame.size = CGSize(width: 100, height: Layout.basicHeight)
                $1.frame.origin = CGPoint(x: $0, y: cutEditor.frame.height + cutEditor.speechAnimationEditor.frame.height)
                return $0 + $1.frame.width
            }
            return x + cutEditor.frame.width
        }
        tempoAnimationEditor.frame.origin = CGPoint(x: minX, y: 0)
        updateBeats()
        updateTimeRuler()
        updateSumKeyTimesEditor()
    }
    var mainHeight = 0.0.cf
    func cutEditors(with scene: Scene) -> [CutEditor] {
        return scene.cuts.enumerated().map {
            self.bindedCutEditor(with: $0.element,
                                 beginBaseTime: scene.cutTrack.time(at: $0.offset), height: cutHeight)
        }
    }
    func bindedCutEditor(with cut: Cut, beginBaseTime: Beat = 0, height: CGFloat) -> CutEditor {
        let cutEditor = CutEditor(cut,
                                  beginBaseTime: beginBaseTime,
                                  baseWidth: baseWidth,
                                  baseTimeInterval: baseTimeInterval,
                                  knobHalfHeight: knobHalfHeight,
                                  subKnobHalfHeight: subKnobHalfHeight,
                                  maxLineWidth: maxLineHeight, height: height)
        
        cutEditor.animationEditors.enumerated().forEach { (i, animationEditor) in
            let nodeAndTrack = cutEditor.cut.nodeAndTrack(atNodeAndTrackIndex: i)
            bind(in: animationEditor, in: cutEditor, from: nodeAndTrack)
        }
        cutEditor.pasteHandler = { [unowned self] in
            if let index = self.cutEditors.index(of: $0) {
                for object in $1.objects {
                    if let cut = object as? Cut {
                        self.paste(cut, at: index + 1)
                        return true
                    }
                }
            }
            return false
        }
        cutEditor.deleteHandler = { [unowned self] in
            if let index = self.cutEditors.index(of: $0) {
                self.removeCut(at: index)
            }
            return true
        }
        cutEditor.scrollHandler = { [unowned self, unowned cutEditor] obj in
            if obj.type == .end {
                if obj.nodeAndTrack != obj.oldNodeAndTrack {
                    self.registerUndo(time: self.time) {
                        self.set(obj.oldNodeAndTrack, old: obj.nodeAndTrack, in: cutEditor, time: $1)
                    }
                    self.sceneDataModel?.isWrite = true
                }
            }
            if cutEditor.cut == self.nodeTreeEditor.cut {
                self.nodeTreeEditor.updateWithNodes()
                self.tracksManager.node = cutEditor.cut.editNode
                self.tracksManager.updateWithTracks(isAlwaysUpdate: true)
                self.setNodeAndTrackBinding?(self, cutEditor, obj.nodeAndTrack)
            }
        }
        return cutEditor
    }
    var setNodeAndTrackBinding: ((Timeline, CutEditor, Cut.NodeAndTrack) -> ())?
    
    func bind(in animationEditor: AnimationEditor, in cutEditor: CutEditor,
              from nodeAndTrack: Cut.NodeAndTrack) {
        animationEditor.setKeyframeHandler = { [unowned self, unowned cutEditor] in
            guard $0.type == .end else {
                return
            }
            switch $0.setType {
            case .insert:
                self.insert($0.keyframe, at: $0.index, in: nodeAndTrack.track, in: nodeAndTrack.node,
                            in: $0.animationEditor, in: cutEditor)
            case .remove:
                self.removeKeyframe(at: $0.index,
                                    in: nodeAndTrack.track, in: nodeAndTrack.node,
                                    in: $0.animationEditor, in: cutEditor, time: self.time)
            case .replace:
                self.replace($0.keyframe, at: $0.index,
                             in: nodeAndTrack.track,
                             in: $0.animationEditor, in: cutEditor, time: self.time)
            }
        }
        animationEditor.slideHandler = { [unowned self, unowned cutEditor] in
            self.setAnimation(with: $0, in: nodeAndTrack.track, in: nodeAndTrack.node, in: cutEditor)
        }
        animationEditor.selectHandler = { [unowned self, unowned cutEditor] in
            self.setAnimation(with: $0, in: nodeAndTrack.track, in: cutEditor)
        }
    }
    
    func updateTimeRuler() {
        let minTime = time(withLocalX: convertToLocalX(bounds.minX + Timeline.leftWidth))
        let maxTime = time(withLocalX: convertToLocalX(bounds.maxX))
        let minSecond = Int(floor(scene.secondTime(withBeatTime: minTime)))
        let maxSecond = Int(ceil(scene.secondTime(withBeatTime: maxTime)))
        guard minSecond < maxSecond else {
            return
        }
        timeRuler.scrollPosition.x = localDeltaX
        timeRuler.labels = (minSecond ... maxSecond).map {
            let timeLabel = Timeline.timeLabel(withSecound: $0)
            timeLabel.fillColor = nil
            let secondX = x(withTime: scene.basedBeatTime(withSecondTime: Second($0)))
            timeLabel.frame.origin = CGPoint(x: secondX - timeLabel.frame.width / 2,
                                             y: Layout.smallPadding)
            return timeLabel
        }
    }
    static func timeLabel(withSecound i: Int) -> Label {
        let minute = i / 60
        let second = i - minute * 60
        let string = second < 0 ?
            String(format: "-%d:%02d", minute, -second) :
            String(format: "%d:%02d", minute, second)
        return Label(text: Localization(string), font: .small)
    }
    
    func updateSumKeyTimesEditor() {
        guard isUpdateSumKeyTimes else {
            sumKeyTimesEditor.frame.size.width = maxScrollX
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
            sumKeyTimesEditor.animation = Animation()
            return
        }
        keyframes.removeLast()
        
        var animation = sumKeyTimesEditor.animation
        animation.keyframes = keyframes
        animation.duration = lastTime
        sumKeyTimesEditor.animation = animation
        sumKeyTimesEditor.frame.size.width = maxScrollX
    }
    
    let beatsLineWidth = 1.0.cf, barLineWidth = 3.0.cf, beatsPerBar = 0
    func updateBeats() {
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
            sumKeyTimesEditor.baseTimeInterval = baseTimeInterval
            tempoAnimationEditor.baseTimeInterval = baseTimeInterval
            soundWaveformView.baseTimeInterval = baseTimeInterval
            cutEditors.forEach { $0.baseTimeInterval = baseTimeInterval }
            updateCutEditorPositions()
        }
    }
    
    var sceneDataModel: DataModel?
    
    private func registerUndo(time: Beat, _ handler: @escaping (Timeline, Beat) -> Void) {
        undoManager?.registerUndo(withTarget: self) { [oldTime = self.time] in
            handler($0, oldTime)
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
        updateKeyframeEditor()
    }
    private func updateKeyframeEditor() {
        switch bindingKeyframeType {
        case .tempo:
            keyframeEditor.keyframe = scene.tempoTrack.animation.editKeyframe
        case .cut:
            keyframeEditor.keyframe = scene.editNode.editTrack.animation.editKeyframe
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
    
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) -> Bool {
        for object in copiedObject.objects {
            if let cut = object as? Cut {
                let localX = convertToLocalX(point(from: event).x)
                let index = cutIndex(withLocalX: localX)
                paste(cut, at: index + 1)
                return true
            }
        }
        return false
    }
    func paste(_ cut: Cut, at index: Int) {
        insert(bindedCutEditor(with: cut, height: cutHeight), at: index, time: time)
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
        let cutEditor = self.bindedCutEditor(with: cut, height: cutHeight)
        insert(cutEditor, at: cutIndex + 1, time: time)
        set(time: scene.cutTrack.time(at: cutIndex + 1), oldTime: time)
        return true
    }
    
    func insert(_ cutEditor: CutEditor, at index: Int, time: Beat) {
        registerUndo(time: time) { $0.removeCutEditor(at: index, time: $1) }
        insert(cutEditor, at: index)
    }
    func insert(_ cutEditor: CutEditor, at index: Int) {
        scene.cutTrack.insert(cutEditor.cut, at: index)
        cutEditors.insert(cutEditor, at: index)
        updateCutEditorPositions()
        sceneDataModel?.isWrite = true
        setSceneDurationHandler?(self, scene.duration)
    }
    func removeCut(at i: Int) {
        if i == 0 {
            set(time: time, oldTime: time, alwaysUpdateCutIndex: true)
            removeCutEditor(at: 0, time: time)
            if scene.cuts.count == 0 {
                insert(bindedCutEditor(with: Cut(), height: cutHeight), at: 0, time: time)
            }
            set(time: 0, oldTime: time, alwaysUpdateCutIndex: true)
        } else {
            let previousCut = scene.cuts[i - 1]
            let previousCutTimeLocation = scene.cuts[i - 1].currentTime
            let isSetTime = i == scene.editCutIndex
            set(time: time, oldTime: time, alwaysUpdateCutIndex: true)
            removeCutEditor(at: i, time: time)
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
    func removeCutEditor(at index: Int, time: Beat) {
        let cutEditor = cutEditors[index]
        registerUndo(time: time) { $0.insert(cutEditor, at: index, time: $1) }
        removeCutEditor(at: index)
    }
    func removeCutEditor(at index: Int) {
        scene.cutTrack.removeCut(at: index)
        if scene.editCutIndex == cutEditors.count - 1 {
            scene.editCutIndex = cutEditors.count - 2
        }
        cutEditors.remove(at: index)
        updateCutEditorPositions()
        sceneDataModel?.isWrite = true
        setSceneDurationHandler?(self, scene.duration)
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
        return append(node, in: editCutEditor)
    }
    func pasteFromNodesEditor(_ copiedObject: CopiedObject, with event: KeyInputEvent) -> Bool {
        for object in copiedObject.objects {
            if let node = object as? Node {
                return append(node, in: editCutEditor)
            }
        }
        return false
    }
    func append(_ node: Node, in cutEditor: CutEditor) -> Bool {
        guard let parent = cutEditor.cut.editNode.parent,
            let index = parent.children.index(of: cutEditor.cut.editNode) else {
                return false
        }
        let animationEditors = cutEditor.newAnimationEditors(with: node)
        insert(node, animationEditors, at: index + 1, parent: parent, in: cutEditor, time: time)
        set(node, in: cutEditor)
        return true
    }
    func remove(_ node: Node, in cutEditor: CutEditor) {
        guard let parent = node.parent else {
            return
        }
        let index = parent.children.index(of: node)!
        removeNode(at: index, parent: parent, in: cutEditor, time: time)
        if parent.children.count == 0 {
            let newNode = Node(name: newNodeName)
            let animationEditors = cutEditor.newAnimationEditors(with: newNode)
            insert(newNode, animationEditors, at: 0, parent: parent, in: cutEditor, time: time)
            set(newNode, in: cutEditor)
        } else {
            set(parent.children[index > 0 ? index - 1 : index], in: cutEditor)
        }
    }
    func insert(_ node: Node, _ animationEditors: [AnimationEditor], at index: Int,
                parent: Node, in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) { $0.removeNode(at: index, parent: parent, in: cutEditor, time: $1) }
        cutEditor.insert(node, at: index, animationEditors, parent: parent)
        node.allChildrenAndSelf { (aNode) in
            scene.cutTrack.differentialDataModel.insert(aNode.differentialDataModel)
        }
        sceneDataModel?.isWrite = true
        updateView(isCut: true, isTransform: false, isKeyframe: false)
        if cutEditor.cut == nodeTreeEditor.cut {
            nodeTreeEditor.updateWithNodes()
            tracksManager.updateWithTracks()
        }
    }
    func removeNode(at index: Int, parent: Node, in cutEditor: CutEditor, time: Beat) {
        let node = parent.children[index]
        let animationEditors = cutEditor.animationEditors(with: node)
        registerUndo(time: time) { [on = parent.children[index]] in
            $0.insert(on, animationEditors, at: index, parent: parent, in: cutEditor, time: $1)
        }
        cutEditor.remove(at: index, animationEditors, parent: parent)
        node.allChildrenAndSelf { (aNode) in
            scene.cutTrack.differentialDataModel.remove(aNode.differentialDataModel)
        }
        sceneDataModel?.isWrite = true
        updateView(isCut: true, isTransform: false, isKeyframe: false)
        if cutEditor.cut == nodeTreeEditor.cut {
            nodeTreeEditor.updateWithNodes()
            tracksManager.updateWithTracks()
        }
    }
    func set(_ node: Node, in cutEditor: CutEditor) {
        set(Cut.NodeAndTrack(node: node, trackIndex: 0),
            old: cutEditor.editNodeAndTrack, in: cutEditor, time: time)
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
        let cutEditor = cutEditors[scene.editCutIndex]
        let node = cutEditor.cut.editNode
        let track = NodeTrack(name: newNodeTrackName(with: node))
        let animationEditor = cutEditor.newAnimationEditor(with: track, node: node, isSmall: true)
        let trackIndex = node.editTrackIndex + 1
        insert(track, animationEditor, at: trackIndex, in: node, in: cutEditor, time: time)
        bind(in: animationEditor, in: cutEditor,
             from: Cut.NodeAndTrack(node: node, trackIndex: trackIndex))
        set(editTrackIndex: trackIndex, oldEditTrackIndex: node.editTrackIndex,
            in: node, in: cutEditor, time: time)
    }
    func pasteFromTracksEditor(_ copiedObject: CopiedObject, with event: KeyInputEvent) -> Bool {
        for object in copiedObject.objects {
            if let track = object as? NodeTrack {
                return append(track, in: editCutEditor)
            }
        }
        return false
    }
    func append(_ track: NodeTrack, in cutEditor: CutEditor) -> Bool {
        let node = cutEditor.cut.editNode
        let index = node.editTrackIndex
        let animationEditor = cutEditor.newAnimationEditor(with: track, node: node, isSmall: false)
        insert(track, animationEditor, at: index + 1, in: node, in: cutEditor, time: time)
        bind(in: animationEditor, in: cutEditor,
             from: Cut.NodeAndTrack(node: node, trackIndex: index))
        set(editTrackIndex: index + 1, oldEditTrackIndex: node.editTrackIndex,
            in: node, in: cutEditor, time: time)
        return true
    }
    func remove(trackIndex: Int, in node: Node, in cutEditor: CutEditor) {
        let newIndex = trackIndex > 0 ? trackIndex - 1 : trackIndex
        set(editTrackIndex: newIndex, oldEditTrackIndex: node.editTrackIndex,
            in: node, in: cutEditor, time: time)
        removeTrack(at: trackIndex, in: node, in: cutEditor, time: time)
        if node.tracks.count == 0 {
            let newTrack = NodeTrack(name: newNodeTrackName(with: node))
            let animationEditor = cutEditor.newAnimationEditor(with: newTrack, node: node,
                                                               isSmall: false)
            insert(newTrack, animationEditor, at: 0, in: node, in: cutEditor, time: time)
            bind(in: animationEditor, in: cutEditor,
                 from: Cut.NodeAndTrack(node: node, trackIndex: trackIndex))
            set(editTrackIndex: 0, oldEditTrackIndex: node.editTrackIndex,
                in: node, in: cutEditor, time: time)
        }
    }
    func removeTrack(at index: Int, in node: Node, in cutEditor: CutEditor) {
        if node.tracks.count > 1 {
            set(editTrackIndex: max(0, index - 1),
                oldEditTrackIndex: index, in: node, in: cutEditor, time: time)
            removeTrack(at: index, in: node, in: cutEditor, time: time)
        }
    }
    func insert(_ track: NodeTrack, _ animationEditor: AnimationEditor, at index: Int, in node: Node,
                in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) { $0.removeTrack(at: index, in: node, in: cutEditor, time: $1) }
        
        let nodeAndTrack = Cut.NodeAndTrack(node: node, trackIndex: index)
        cutEditor.insert(track, animationEditor, in: nodeAndTrack)
        node.differentialDataModel.isWrite = true
        sceneDataModel?.isWrite = true
        updateView(isCut: true, isTransform: false, isKeyframe: false)
        if tracksManager.node == node {
            tracksManager.updateWithTracks()
        }
    }
    func removeTrack(at index: Int, in node: Node, in cutEditor: CutEditor, time: Beat) {
        let nodeAndTrack = Cut.NodeAndTrack(node: node, trackIndex: index)
        let animationIndex = cutEditor.cut.nodeAndTrackIndex(with: nodeAndTrack)
        registerUndo(time: time) { [ot = node.tracks[index],
            oa = cutEditor.animationEditors[animationIndex]] in
            
            $0.insert(ot, oa, at: index, in: node, in: cutEditor, time: $1)
        }
        cutEditor.removeTrack(at: nodeAndTrack)
        node.differentialDataModel.isWrite = true
        sceneDataModel?.isWrite = true
        updateView(isCut: true, isTransform: false, isKeyframe: false)
        if tracksManager.node == node {
            tracksManager.updateWithTracks()
        }
    }
    private func set(editTrackIndex: Int, oldEditTrackIndex: Int,
                     in node: Node, in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) {
            $0.set(editTrackIndex: oldEditTrackIndex,
                   oldEditTrackIndex: editTrackIndex, in: node, in: cutEditor, time: $1)
        }
        cutEditor.set(editTrackIndex: editTrackIndex, in: node)
        sceneDataModel?.isWrite = true
        updateView(isCut: true, isTransform: true, isKeyframe: true)
        if tracksManager.node == node {
            tracksManager.updateWithTracks()
        }
    }
    
    private func set(_ editNodeAndTrack: Cut.NodeAndTrack,
                     old oldEditNodeAndTrack: Cut.NodeAndTrack,
                     in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldEditNodeAndTrack, old: editNodeAndTrack, in: cutEditor, time: $1)
        }
        cutEditor.editNodeAndTrack = editNodeAndTrack
        sceneDataModel?.isWrite = true
        if cutEditor.cut == nodeTreeEditor.cut {
            nodeTreeEditor.updateWithNodes()
            setNodeAndTrackBinding?(self, cutEditor, editNodeAndTrack)
        }
    }
    
    private var isUpdateSumKeyTimes = true
    private var moveAnimationEditors = [(animationEditor: AnimationEditor, keyframeIndex: Int?)]()
    private func setAnimations(with obj: AnimationEditor.SlideBinding) {
        switch obj.type {
        case .begin:
            isUpdateSumKeyTimes = false
            let cutIndex = movingCutIndex(withTime: obj.oldTime)
            let cutEditor = self.cutEditors[cutIndex]
            let time = obj.oldTime - scene.cutTrack.time(at: cutIndex)
            moveAnimationEditors = []
            cutEditor.animationEditors.forEach {
                let s = $0.movingKeyframeIndex(atTime: time)
                if s.isSolution {
                    moveAnimationEditors.append(($0, s.index))
                }
            }
            let ts = tempoAnimationEditor.movingKeyframeIndex(atTime: obj.oldTime)
            if ts.isSolution {
                moveAnimationEditors.append((tempoAnimationEditor, ts.index))
            }
            
            moveAnimationEditors.forEach {
                _ = $0.animationEditor.move(withDeltaTime: obj.deltaTime,
                                            keyframeIndex: $0.keyframeIndex, sendType: obj.type)
            }
        case .sending:
            moveAnimationEditors.forEach {
                _ = $0.animationEditor.move(withDeltaTime: obj.deltaTime,
                                            keyframeIndex: $0.keyframeIndex, sendType: obj.type)
            }
        case .end:
            moveAnimationEditors.forEach {
                _ = $0.animationEditor.move(withDeltaTime: obj.deltaTime,
                                            keyframeIndex: $0.keyframeIndex, sendType: obj.type)
            }
            moveAnimationEditors = []
            isUpdateSumKeyTimes = true
        }
    }
    
    private var oldTempoTrack: TempoTrack?
    private func setAnimationInTempoTrack(with obj: AnimationEditor.SlideBinding) {
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
    private func setAnimationInTempoTrack(with obj: AnimationEditor.SelectBinding) {
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
        tempoAnimationEditor.animation = track.animation
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
        tempoAnimationEditor.animation = track.animation
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
        tempoAnimationEditor.animation = track.animation
        sceneDataModel?.isWrite = true
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
        updateView(isCut: false, isTransform: false, isKeyframe: true)
        updateSumKeyTimesEditor()
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
        tempoAnimationEditor.animation = track.animation
        sceneDataModel?.isWrite = true
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
        updateWithTime()
        updateSumKeyTimesEditor()
        updateTimeRuler()
        soundWaveformView.updateWaveform()
    }
    
    private func setAnimation(with obj: AnimationEditor.SlideBinding,
                              in track: NodeTrack, in node: Node, in cutEditor: CutEditor) {
        switch obj.type {
        case .begin:
            break
        case .sending:
            track.replace(obj.animation.keyframes, duration: obj.animation.duration)
            updateCutDuration(with: cutEditor)
        case .end:
            track.replace(obj.animation.keyframes, duration: obj.animation.duration)
            if obj.animation != obj.oldAnimation {
                registerUndo(time: time) {
                    $0.set(obj.oldAnimation, old: obj.animation,
                           in: track, in: obj.animationEditor, in: cutEditor, time: $1)
                }
                
                node.differentialDataModel.isWrite = true
                sceneDataModel?.isWrite = true
            }
            updateCutDuration(with: cutEditor)
        }
        updateWithTime()
    }
    private func setAnimation(with obj: AnimationEditor.SelectBinding,
                              in track: NodeTrack, in cutEditor: CutEditor) {
        switch obj.type {
        case .begin:
            break
        case .sending:
            break
        case .end:
            if obj.animation != obj.oldAnimation {
                registerUndo(time: time) {
                    $0.set(obj.oldAnimation, old: obj.animation,
                           in: track, in: obj.animationEditor, in: cutEditor, time: $1)
                }
                sceneDataModel?.isWrite = true
            }
        }
    }
    private func set(_ animation: Animation, old oldAnimation: Animation,
                     in track: NodeTrack,
                     in animationEditor: AnimationEditor, in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldAnimation, old: animation, in: track,
                   in: animationEditor, in: cutEditor, time: $1)
        }
        track.replace(animation.keyframes, duration: animation.duration)
        sceneDataModel?.isWrite = true
        animationEditor.animation = track.animation
        updateCutDuration(with: cutEditor)
    }
    func insert(_ keyframe: Keyframe, at index: Int,
                in track: NodeTrack, in node: Node,
                in animationEditor: AnimationEditor, in cutEditor: CutEditor,
                isSplitDrawing: Bool = false) {
        var keyframeValue = track.currentItemValues
        keyframeValue.drawing = isSplitDrawing ? keyframeValue.drawing.copied : Drawing()
        insert(keyframe, keyframeValue, at: index, in: track, in: node,
               in: animationEditor, in: cutEditor, time: time)
    }
    private func replace(_ keyframe: Keyframe, at index: Int,
                         in track: NodeTrack,
                         in animationEditor: AnimationEditor, in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) { [ok = track.animation.keyframes[index]] in
            $0.replace(ok, at: index, in: track, in: animationEditor, in: cutEditor, time: $1)
        }
        track.replace(keyframe, at: index)
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
        sceneDataModel?.isWrite = true
        animationEditor.animation = track.animation
        updateView(isCut: true, isTransform: false, isKeyframe: false)
    }
    private func insert(_ keyframe: Keyframe,
                        _ keyframeValue: NodeTrack.KeyframeValues,
                        at index: Int,
                        in track: NodeTrack, in node: Node,
                        in animationEditor: AnimationEditor, in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) { $0.removeKeyframe(at: index, in: track, in: node,
                                                     in: animationEditor, in: cutEditor, time: $1) }
        track.insert(keyframe, keyframeValue, at: index)
        node.differentialDataModel.isWrite = true
        sceneDataModel?.isWrite = true
        animationEditor.animation = track.animation
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
        updateView(isCut: true, isTransform: false, isKeyframe: false)
        updateSumKeyTimesEditor()
    }
    private func removeKeyframe(at index: Int,
                                in track: NodeTrack, in node: Node,
                                in animationEditor: AnimationEditor, in cutEditor: CutEditor,
                                time: Beat) {
        registerUndo(time: time) {
            [ok = track.animation.keyframes[index],
            okv = track.keyframeItemValues(at: index)] in
            
            $0.insert(ok, okv, at: index, in: track, in: node,
                      in: animationEditor, in: cutEditor, time: $1)
        }
        track.removeKeyframe(at: index)
        updateWith(time: time, scrollPoint: CGPoint(x: x(withTime: time), y: 0))
        node.differentialDataModel.isWrite = true
        sceneDataModel?.isWrite = true
        animationEditor.animation = track.animation
        updateView(isCut: true, isTransform: false, isKeyframe: false)
        updateSumKeyTimesEditor()
    }
    
    func updateCutDuration(with cutEditor: CutEditor) {
        cutEditor.cut.duration = cutEditor.cut.maxDuration
        cutEditor.updateWithDuration()
        scene.cutTrack.updateCutTimeAndDuration()
        sceneDataModel?.isWrite = true
        setSceneDurationHandler?(self, scene.duration)
        updateTempoDuration()
        cutEditors.enumerated().forEach {
            $0.element.beginBaseTime = scene.cutTrack.time(at: $0.offset)
        }
        updateCutEditorPositions()
    }
    func updateTempoDuration() {
        scene.tempoTrack.replace(duration: scene.duration)
        tempoAnimationEditor.animation.duration = scene.duration
        tempoAnimationEditor.frame.size.width = maxScrollX
    }
    
    private var oldCutEditor: CutEditor?
    
    private func setNodes(with obj: NodeTreeManager.NodesBinding) {
        switch obj.type {
        case .begin:
            oldCutEditor = editCutEditor
        case .sending, .end:
            guard let cutEditor = oldCutEditor else {
                return
            }
            cutEditor.moveNode(from: obj.oldIndex, fromParemt: obj.fromNode,
                               to: obj.index, toParent: obj.toNode)
            if cutEditor.cut == obj.nodeTreeEditor.cut {
                obj.nodeTreeEditor.updateWithNodes(isAlwaysUpdate: true)
                tracksManager.updateWithTracks(isAlwaysUpdate: true)
            }
            if obj.type == .end {
                if obj.index != obj.beginIndex || obj.toNode != obj.beginNode {
                    registerUndo(time: time) {
                        $0.moveNode(from: obj.index, fromParent: obj.toNode,
                                    to: obj.beginIndex, toParent: obj.beginNode,
                                    in: cutEditor, time: $1)
                    }
                    sceneDataModel?.isWrite = true
                }
                self.oldCutEditor = nil
            }
        }
    }
    private func moveNode(from oldIndex: Int, fromParent: Node,
                          to index: Int, toParent: Node, in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) {
            $0.moveNode(from: index, fromParent: toParent, to: oldIndex, toParent: fromParent,
                        in: cutEditor, time: $1)
        }
        cutEditor.moveNode(from: oldIndex, fromParemt: fromParent, to: index, toParent: toParent)
        sceneDataModel?.isWrite = true
        if cutEditor.cut == nodeTreeEditor.cut {
            nodeTreeEditor.updateWithNodes(isAlwaysUpdate: true)
            tracksManager.updateWithTracks(isAlwaysUpdate: true)
        }
    }
    
    private func setNodeTracks(with obj: TracksManager.NodeTracksBinding) {
        switch obj.type {
        case .begin:
            oldCutEditor = editCutEditor
        case .sending, .end:
            guard let cutEditor = oldCutEditor else {
                return
            }
            cutEditor.moveTrack(from: obj.oldIndex, to: obj.index, in: obj.inNode)
            cutEditor.set(editTrackIndex: obj.index, in: obj.inNode)
            if cutEditor.cut.editNode == obj.tracksManager.node {
                obj.tracksManager.updateWithTracks(isAlwaysUpdate: true)
            }
            if obj.type == .end {
                if obj.index != obj.beginIndex {
                    registerUndo(time: time) {
                        $0.moveTrack(from: obj.index, to: obj.beginIndex,
                                     in: obj.inNode, in: cutEditor, time: $1)
                    }
                    registerUndo(time: time) {
                        $0.set(editTrackIndex: obj.beginIndex, oldEditTrackIndex: obj.index,
                               in: obj.inNode, in: cutEditor, time: $1)
                    }
                    obj.inNode.differentialDataModel.isWrite = true
                    sceneDataModel?.isWrite = true
                }
                self.oldCutEditor = nil
            }
        }
    }
    private func moveTrack(from oldIndex: Int, to index: Int,
                      in node: Node, in cutEditor: CutEditor, time: Beat) {
        registerUndo(time: time) {
            $0.moveTrack(from: index, to: oldIndex, in: node, in: cutEditor, time: $1)
        }
        cutEditor.moveTrack(from: oldIndex, to: index, in: node)
        node.differentialDataModel.isWrite = true
        sceneDataModel?.isWrite = true
        if cutEditor.cut == nodeTreeEditor.cut {
            nodeTreeEditor.updateWithNodes(isAlwaysUpdate: true)
            tracksManager.updateWithTracks(isAlwaysUpdate: true)
        }
    }
    
    var setSceneDurationHandler: ((Timeline, Beat) -> ())?
    
    func moveToPrevious() {
        let cut = scene.editCut
        let track = cut.editNode.editTrack
        let loopFrameIndex = track.animation.loopedKeyframeIndex(withTime: cut.currentTime).loopFrameIndex
        let loopFrame = track.animation.loopFrames[loopFrameIndex]
        if cut.currentTime - loopFrame.time > 0 {
            updateTime(withCutTime: loopFrame.time)
        } else if loopFrameIndex - 1 >= 0 {
            updateTime(withCutTime: track.animation.loopFrames[loopFrameIndex - 1].time)
        } else if scene.editCutIndex - 1 >= 0 {
            self.editCutIndex -= 1
            updateTime(withCutTime: scene.editCut.editNode.editTrack.animation.lastLoopedKeyframeTime)
        }
    }
    func moveToNext() {
        let cut = scene.editCut
        let track = cut.editNode.editTrack
        let loopFrameIndex = track.animation.loopedKeyframeIndex(withTime: cut.currentTime).loopFrameIndex
        if loopFrameIndex + 1 <= track.animation.loopFrames.count - 1 {
            let t = track.animation.loopFrames[loopFrameIndex + 1].time
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
    
    var scrollHandler: ((Timeline, CGPoint, ScrollEvent) -> ())?
    private var isScrollTrack = false
    private weak var scrollCutEditor: CutEditor?
    func scroll(with event: ScrollEvent) -> Bool {
        if event.sendType == .begin {
            isScrollTrack = abs(event.scrollDeltaPoint.x) < abs(event.scrollDeltaPoint.y)
        }
        if isScrollTrack {
            if event.sendType == .begin {
                scrollCutEditor = editCutEditor
            }
            scrollCutEditor?.scrollTrack(with: event)
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
            scrollHandler?(self, scrollPoint, event)
        }
    }
    
    func zoom(with event: PinchEvent) -> Bool {
        zoom(at: point(from: event)) {
            baseWidth = (baseWidth * (event.magnification * 2.5 + 1))
                .clip(min: 1, max: Timeline.defautBaseWidth)
        }
        return true
    }
    func resetView(with event: DoubleTapEvent) -> Bool {
        guard baseWidth != Timeline.defautBaseWidth else {
            return false
        }
        zoom(at: point(from: event)) {
            baseWidth = Timeline.defautBaseWidth
        }
        return true
    }
    func zoom(at p: CGPoint, handler: () -> ()) {
        handler()
        _scrollPoint.x = x(withTime: time)
        _intervalScrollPoint.x = scrollPoint.x
        updateView(isCut: false, isTransform: false, isKeyframe: false)
    }
}

final class Ruler: Layer, Respondable {
    static let name = Localization(english: "Ruler", japanese: "目盛り")
    
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
//    var scrollFrame: CGRect {
//    }
    
    var labels = [Label]() {
        didSet {
            scroller.replace(children: labels)
        }
    }
}
