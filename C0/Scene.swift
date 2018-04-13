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

typealias BPM = CGFloat
typealias FPS = Int
typealias CPB = Int
typealias FrameTime = Int
typealias BaseTime = Q
typealias Beat = Q
typealias DoubleBaseTime = Double
typealias DoubleBeat = Double
typealias Second = Double

/**
 # Issue
 - 複数のサウンド
 - 変更通知
 */
final class Scene: NSObject, NSCoding {
    var version = Version()
    var name: String
    var frame: CGRect
    var editMaterial: Material
    var isHiddenPrevious: Bool, isHiddenNext: Bool
    var isHiddenSubtitles: Bool
    var sound: Sound
    
    var viewTransform: Transform {
        didSet {
            self.scale = viewTransform.scale.x
            self.reciprocalViewScale = 1 / viewTransform.scale.x
        }
    }
    private(set) var scale: CGFloat, reciprocalViewScale: CGFloat
    var reciprocalScale: CGFloat {
        return reciprocalViewScale / editNode.worldScale
    }
    
    var frameRate: FPS
    var baseTimeInterval: Beat
    var tempoTrack: TempoTrack
    var cutTrack: CutTrack
//    var sunAnimation
    var editCut: Cut {
        return cutTrack.cutItem.cut
    }
    var cuts: [Cut] {
        return cutTrack.cutItem.keyCuts
    }
    var editNode: Node {
        return editCut.editNode
    }
    var timeBinding: ((Scene, Beat) -> ())?
    var time: Beat {
        didSet {
            timeBinding?(self, time)
        }
    }
    var editCutIndex: Int {
        get {
            return cutTrack.animation.editLoopframeIndex
        }
        set {
            cutTrack.time = cutTrack.time(at: newValue)
        }
    }
    var duration: Beat {
        return cutTrack.animation.duration
    }
    
    var differentialData: Data {
        func set(isEncodeGeometryAndDrawing: Bool) {
            cuts.forEach { (cut) in
                cut.rootNode.allChildrenAndSelf { (node) in
                    node.tracks.forEach { (track) in
                        track.drawingItem.isEncodeDrawings = isEncodeGeometryAndDrawing
                        track.cellItems.forEach { (cellItem) in
                            cellItem.isEncodeGeometries = isEncodeGeometryAndDrawing
                        }
                    }
                }
            }
        }
        set(isEncodeGeometryAndDrawing: false)
        let data = self.data
        set(isEncodeGeometryAndDrawing: true)
        return data
    }
    
    init(name: String = Localization(english: "Untitled", japanese: "名称未設定").currentString,
         frame: CGRect = CGRect(x: -288, y: -162, width: 576, height: 324),
         frameRate: FPS = 24,
         baseTimeInterval: Beat = Beat(1, 24),
         editMaterial: Material = Material(),
         isHiddenPrevious: Bool = false, isHiddenNext: Bool = false,
         isHiddenSubtitles: Bool = false,
         sound: Sound = Sound(),
         tempoTrack: TempoTrack = TempoTrack(),
         cutTrack: CutTrack = CutTrack(),
         time: Beat = 0,
         viewTransform: Transform = Transform()) {
        
        self.name = name
        self.frame = frame
        self.frameRate = frameRate
        self.baseTimeInterval = baseTimeInterval
        self.editMaterial = editMaterial
        self.isHiddenPrevious = isHiddenPrevious
        self.isHiddenNext = isHiddenNext
        self.isHiddenSubtitles = isHiddenSubtitles
        self.sound = sound
        self.tempoTrack = tempoTrack
        self.cutTrack = cutTrack
        self.time = time
        self.viewTransform = viewTransform
        self.scale = viewTransform.scale.x
        self.reciprocalViewScale = 1 / viewTransform.scale.x
    }
    
    private enum CodingKeys: String, CodingKey {
        case
        name, frame, frameRate, baseTimeInterval,
        editMaterial, isHiddenPrevious, isHiddenNext, isHiddenSubtitles, sound, viewTransform,
        tempoTrack, cutTrack, time
    }
    init?(coder: NSCoder) {
        name = coder.decodeObject(forKey: CodingKeys.name.rawValue) as? String ?? ""
        frame = coder.decodeRect(forKey: CodingKeys.frame.rawValue)
        frameRate = coder.decodeInteger(forKey: CodingKeys.frameRate.rawValue)
        baseTimeInterval = coder.decodeDecodable(
            Beat.self, forKey: CodingKeys.baseTimeInterval.rawValue) ?? Beat(1, 16)
        editMaterial = coder.decodeObject(
            forKey: CodingKeys.editMaterial.rawValue) as? Material ?? Material()
        isHiddenPrevious = coder.decodeBool(forKey: CodingKeys.isHiddenPrevious.rawValue)
        isHiddenNext = coder.decodeBool(forKey: CodingKeys.isHiddenNext.rawValue)
        isHiddenSubtitles = coder.decodeBool(forKey: CodingKeys.isHiddenSubtitles.rawValue)
        viewTransform = coder.decodeDecodable(
            Transform.self, forKey: CodingKeys.viewTransform.rawValue) ?? Transform()
        sound = coder.decodeDecodable(Sound.self, forKey: CodingKeys.sound.rawValue) ?? Sound()
        tempoTrack = coder.decodeObject(
            forKey: CodingKeys.tempoTrack.rawValue) as? TempoTrack ?? TempoTrack()
        cutTrack = coder.decodeObject(forKey: CodingKeys.cutTrack.rawValue) as? CutTrack ?? CutTrack()
        time = coder.decodeDecodable(Beat.self, forKey: CodingKeys.time.rawValue) ?? 0
        scale = viewTransform.scale.x
        reciprocalViewScale = 1 / viewTransform.scale.x
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(name, forKey: CodingKeys.name.rawValue)
        coder.encode(frame, forKey: CodingKeys.frame.rawValue)
        coder.encode(frameRate, forKey: CodingKeys.frameRate.rawValue)
        coder.encodeEncodable(baseTimeInterval, forKey: CodingKeys.baseTimeInterval.rawValue)
        coder.encode(editMaterial, forKey: CodingKeys.editMaterial.rawValue)
        coder.encode(isHiddenPrevious, forKey: CodingKeys.isHiddenPrevious.rawValue)
        coder.encode(isHiddenNext, forKey: CodingKeys.isHiddenNext.rawValue)
        coder.encode(isHiddenSubtitles, forKey: CodingKeys.isHiddenSubtitles.rawValue)
        coder.encodeEncodable(viewTransform, forKey: CodingKeys.viewTransform.rawValue)
        coder.encodeEncodable(sound, forKey: CodingKeys.sound.rawValue)
        coder.encode(tempoTrack, forKey: CodingKeys.tempoTrack.rawValue)
        coder.encode(cutTrack, forKey: CodingKeys.cutTrack.rawValue)
        coder.encodeEncodable(time, forKey: CodingKeys.time.rawValue)
    }
    
    func beatTime(withFrameTime frameTime: FrameTime) -> Beat {
        return Beat(tempoTrack.doubleBeatTime(withSecondTime: Second(frameTime) / Second(frameRate)))
    }
    func basedBeatTime(withSecondTime secondTime: Second) -> Beat {
        return basedBeatTime(withDoubleBeatTime: tempoTrack.doubleBeatTime(withSecondTime: secondTime))
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
    func basedBeatTime(withDoubleBeatTime doubleBeatTime: DoubleBeat) -> Beat {
        return Beat(Int(doubleBeatTime / DoubleBeat(baseTimeInterval))) * baseTimeInterval
    }
    func doubleBeatTime(withBeatTime beatTime: Beat) -> DoubleBeat {
        return DoubleBeat(beatTime)
    }
    func beatTime(withBaseTime baseTime: BaseTime) -> Beat {
        return baseTime * baseTimeInterval
    }
    func baseTime(withBeatTime beatTime: Beat) -> BaseTime {
        return beatTime / baseTimeInterval
    }
    func basedBeatTime(withDoubleBaseTime doubleBaseTime: DoubleBaseTime) -> Beat {
        return Beat(Int(doubleBaseTime)) * baseTimeInterval
    }
    func doubleBaseTime(withBeatTime beatTime: Beat) -> DoubleBaseTime {
        return DoubleBaseTime(beatTime / baseTimeInterval)
    }
    
    func cutTime(withFrameTime frameTime: Int) -> (cutItemIndex: Int, cut: Cut, time: Beat) {
        let t = cutTrack.cutIndex(withTime: beatTime(withFrameTime: frameTime))
        return (t.index, cuts[t.index], t.interTime)
    }
    var secondTime: (second: Int, frame: Int) {
        let second = secondTime(withBeatTime: time)
        let frameTime = FrameTime(second * Second(frameRate))
        return (Int(second), frameTime - Int(second) * frameRate)
    }
    func secondTime(with frameTime: FrameTime) -> (second: Int, frame: Int) {
        let second = frameTime / frameRate
        return (second, frameTime - second)
    }
    
    var vtt: Data? {
        var subtitleTuples = [(time: Beat, duration: Beat, subtitle: Subtitle)]()
        cutTrack.cutItem.keyCuts.enumerated().forEach { (i, cut) in
            let cutTime = cutTrack.time(at: i)
            let lfs = cut.subtitleTrack.animation.loopFrames
            subtitleTuples += lfs.enumerated().map { (li, lf) in
                let subtitle = cut.subtitleTrack.subtitleItem.keySubtitles[lf.index]
                let nextTime = li + 1 < lfs.count ?
                    lfs[li + 1].time : cut.subtitleTrack.animation.duration
                return (lf.time + cutTime, nextTime - lf.time, subtitle)
            }
        }
        return Subtitle.vtt(subtitleTuples, timeClosure: { secondTime(withBeatTime: $0) })
    }
}
extension Scene: ClassCopiable {
    func copied(from copier: Copier) -> Scene {
        return Scene(frame: frame, frameRate: frameRate,
                     editMaterial: editMaterial,
                     isHiddenPrevious: isHiddenPrevious, isHiddenNext: isHiddenNext,
                     sound: sound,
                     tempoTrack: tempoTrack.copied,
                     cutTrack: cutTrack.copied,
                     time: time,
                     viewTransform: viewTransform)
    }
}
extension Scene: Referenceable {
    static let name = Localization(english: "Scene", japanese: "シーン")
}

/**
 # Issue
 - セルをキャンバス外にペースト
 - Display P3サポート
 */
final class SceneView: View {
    var scene = Scene() {
        didSet {
            updateWithScene()
        }
    }
    let dataModelKey = "scene"
    var dataModel: DataModel {
        didSet {
            if let dSceneDataModel = dataModel.children[differentialSceneDataModelKey] {
                self.differentialSceneDataModel = dSceneDataModel
            } else {
                dataModel.insert(differentialSceneDataModel)
            }
            
            if let dCutTrackDataModel = dataModel.children[scene.cutTrack.differentialDataModelKey] {
                scene.cutTrack.differentialDataModel = dCutTrackDataModel
            } else {
                dataModel.insert(scene.cutTrack.differentialDataModel)
            }
            
            timeline.sceneDataModel = differentialSceneDataModel
            canvas.sceneDataModel = differentialSceneDataModel
            updateWithScene()
        }
    }
    let differentialSceneDataModelKey = "differentialScene"
    var differentialSceneDataModel: DataModel {
        didSet {
            if let scene: Scene = differentialSceneDataModel.readObject() {
                self.scene = scene
            }
            differentialSceneDataModel.dataClosure = { [unowned self] in self.scene.differentialData }
        }
    }
    
    static let versionWidth = 120.0.cf, colorSpaceWidth = 82.0.cf
    static let propertyWidth = 200.0.cf, buttonsWidth = 120.0.cf
    static let canvasSize = CGSize(width: 730, height: 480), timelineHeight = 190.0.cf
    
    let classNameView = TextView(text: Scene.name, font: .bold)
    let versionView = VersionView()
    
    let timeline = Timeline()
    let canvas = Canvas()
    let seekBar = SeekBar()
    
    let rendererManager = RendererManager()
    let sizeView = DiscreteSizeView(sizeType: .small)
    let frameRateView = DiscreteNumberView(frame: Layout.valueFrame,
                                           min: 1, max: 1000, numberInterval: 1, unit: " fps",
                                           sizeType: .small)
    
    let isHiddenPreviousView = BoolView(defaultBool: true, cationBool: false,
                                        name: Localization(english: "Previous", japanese: "前"),
                                        boolInfo: BoolInfo.hidden)
    let isHiddenNextView = BoolView(defaultBool: true, cationBool: false,
                                    name: Localization(english: "Next", japanese: "次"),
                                    boolInfo: BoolInfo.hidden)
    let isHiddenSubtitlesView = BoolView(cationBool: true,
                                         name: Localization(english: "Subtitles", japanese: "字幕"),
                                         boolInfo: BoolInfo.hidden,
                                         sizeType: .small)
    
    let exportSubtitlesView = ClosureView(closure: {}, name: Localization(english: "Export Subtitles",
                                                                          japanese: "字幕を書き出す"))
    
    let soundView = SoundView()
    let drawingView = DrawingView()
    let materialManager = SceneMaterialManager()
    let transformView = TransformView()
    let wiggleView = WiggleView()
    let subtitleView = SubtitleView(sizeType: .small)
    let effectView = EffectView(sizeType: .small)
    
//    let showAllBox = TextBox(name: Localization(english: "Unlock All Cells",
//                                                japanese: "すべてのセルのロックを解除"),
//                             sizeType: .small)
//    let clipCellInSelectedBox = TextBox(name: Localization(english: "Clip Cell in Selected",
//                                                           japanese: "セルを選択の中へクリップ"),
//                                        sizeType: .small)
//    let splitColorBox = TextBox(name: Localization(english: "Split Color", japanese: "カラーを分割"),
//                                sizeType: .small)
//    let splitOtherThanColorBox = TextBox(name: Localization(english: "Split Material",
//                                                            japanese: "マテリアルを分割"), sizeType: .small)
    
    override init() {
        differentialSceneDataModel = DataModel(key: differentialSceneDataModelKey)
        dataModel = DataModel(key: dataModelKey,
                              directoryWith: [differentialSceneDataModel,
                                              scene.cutTrack.differentialDataModel])
        timeline.sceneDataModel = differentialSceneDataModel
        canvas.sceneDataModel = differentialSceneDataModel
        
        versionView.version = scene.version
        
        super.init()
        bounds = defaultBounds
        materialManager.sceneView = self
        
        replace(children: [classNameView,
                           versionView,
                           sizeView, frameRateView,
                           exportSubtitlesView,
                           isHiddenPreviousView, isHiddenNextView, soundView,
                           timeline.keyframeView,
                           drawingView, canvas.materialView, transformView, wiggleView,
                           timeline.tempoView, timeline.tempoKeyframeView,
                           isHiddenSubtitlesView, subtitleView,
                           timeline.nodeView, effectView,
                           canvas.cellView,
                           timeline, canvas, seekBar])
        
        differentialSceneDataModel.dataClosure = { [unowned self] in self.scene.differentialData }
        
        rendererManager.progressesEdgeLayer = self
        sizeView.binding = { [unowned self] in
            self.scene.frame = CGRect(origin: CGPoint(x: -$0.size.width / 2,
                                                      y: -$0.size.height / 2), size: $0.size)
            self.canvas.setNeedsDisplay()
            let sp = CGPoint(x: self.scene.frame.width, y: self.scene.frame.height)
            self.transformView.standardTranslation = sp
            self.wiggleView.standardAmplitude = sp
            if $0.type == .end && $0.size != $0.oldSize {
                self.differentialSceneDataModel.isWrite = true
            }
        }
        frameRateView.binding = { [unowned self] in
            self.scene.frameRate = Int($0.number)
            if $0.type == .end && $0.number != $0.oldNumber {
                self.differentialSceneDataModel.isWrite = true
            }
        }
        
        timeline.baseTimeIntervalView.binding = { [unowned self] in
            if $0.type == .begin {
                self.baseTimeIntervalOldTime = self.scene.secondTime(withBeatTime: self.scene.time)
            }
            self.scene.baseTimeInterval.q = Int($0.number)
            self.timeline.time = self.scene.basedBeatTime(withSecondTime: self.baseTimeIntervalOldTime)
            self.timeline.baseTimeInterval = self.scene.baseTimeInterval
            if $0.type == .end && $0.number != $0.oldNumber {
                self.differentialSceneDataModel.isWrite = true
            }
        }
        
        isHiddenPreviousView.binding = { [unowned self] in
            self.canvas.isHiddenPrevious = $0.bool
            if $0.type == .end && $0.bool != $0.oldBool {
                self.differentialSceneDataModel.isWrite = true
            }
        }
        isHiddenNextView.binding = { [unowned self] in
            self.canvas.isHiddenNext = $0.bool
            if $0.type == .end && $0.bool != $0.oldBool {
                self.differentialSceneDataModel.isWrite = true
            }
        }
        isHiddenSubtitlesView.binding = { [unowned self] in
            self.scene.isHiddenSubtitles = $0.bool
            if $0.type == .end && $0.bool != $0.oldBool {
                self.differentialSceneDataModel.isWrite = true
            }
        }
        
        soundView.setSoundClosure = { [unowned self] in
            self.scene.sound = $0.sound
            self.timeline.soundWaveformView.sound = $0.sound
            if $0.type == .end && $0.sound != $0.oldSound {
                self.differentialSceneDataModel.isWrite = true
            }
            if self.scene.sound.url == nil && self.canvas.player.audioPlayer?.isPlaying ?? false {
                self.canvas.player.audioPlayer?.stop()
            }
        }
        
        effectView.binding = { [unowned self] in
            self.set($0.effect, old: $0.oldEffect, type: $0.type)
        }
        drawingView.binding = { [unowned self] in
            self.set($0.drawing, old: $0.oldDrawing, type: $0.type)
        }
        transformView.binding = { [unowned self] in
            self.set($0.transform, old: $0.oldTransform, type: $0.type)
        }
        wiggleView.binding = { [unowned self] in
            self.set($0.wiggle, old: $0.oldWiggle, type: $0.type)
        }
        
        subtitleView.binding = { [unowned self] in
            self.set($0.subtitle, old: $0.oldSubtitle, type: $0.type)
        }
        
//        showAllBox.runClosure = { [unowned self] _ in
//            self.canvas.unlockAllCells()
//            return true
//        }
//        clipCellInSelectedBox.runClosure = { [unowned self] _ in
//            self.canvas.clipCellInSelected()
//            return true
//        }
//        splitColorBox.runClosure = { [unowned self] _ in
//            self.materialManager.splitColor()
//            return true
//        }
//        splitOtherThanColorBox.runClosure = { [unowned self] _ in
//            self.materialManager.splitOtherThanColor()
//            return true
//        }
        
        timeline.tempoView.binding = { [unowned self] in
            self.set(BPM($0.number), old: BPM($0.oldNumber), type: $0.type)
        }
        timeline.scrollClosure = { [unowned self] (timeline, scrollPoint, event) in
            if event.sendType == .begin && self.canvas.player.isPlaying {
                self.canvas.player.opacity = 0.2
            } else if event.sendType == .end && self.canvas.player.opacity != 1 {
                self.canvas.player.opacity = 1
            }
        }
        timeline.setSceneDurationClosure = { [unowned self] in
            self.seekBar.maxTime = self.scene.secondTime(withBeatTime: $1)
        }
        timeline.setEditCutItemIndexClosure = { [unowned self] _, _ in
            self.canvas.cut = self.scene.editCut
            self.drawingView.drawing = self.scene.editNode.editTrack.drawingItem.drawing
            self.transformView.transform =
                self.scene.editNode.editTrack.transformItem?.transform ?? Transform()
            self.wiggleView.wiggle =
                self.scene.editNode.editTrack.wiggleItem?.wiggle ?? Wiggle()
            self.effectView.effect =
                self.scene.editNode.editTrack.effectItem?.effect ?? Effect()
            self.subtitleView.subtitle = self.scene.editCut.subtitleTrack.subtitleItem.subtitle
        }
        timeline.updateViewClosure = { [unowned self] in
            if $0.isCut {
                let p = self.canvas.cursorPoint
                if self.canvas.contains(p) {
                    self.canvas.updateEditView(with: self.canvas.convertToCurrentLocal(p))
                }
                self.canvas.setNeedsDisplay()
            }
            if $0.isTransform {
                self.drawingView.drawing = self.scene.editNode.editTrack.drawingItem.drawing
                self.transformView.transform =
                    self.scene.editNode.editTrack.transformItem?.transform ?? Transform()
                self.wiggleView.wiggle =
                    self.scene.editNode.editTrack.wiggleItem?.wiggle ?? Wiggle()
                self.effectView.effect =
                    self.scene.editNode.editTrack.effectItem?.effect ?? Effect()
                self.subtitleView.subtitle = self.scene.editCut.subtitleTrack.subtitleItem.subtitle
            }
        }
        timeline.setNodeAndTrackBinding = { [unowned self] timeline, cutView, nodeAndTrack in
            if cutView == timeline.editCutView {
                let p = self.canvas.cursorPoint
                if self.canvas.contains(p) {
                    self.canvas.updateEditView(with: self.canvas.convertToCurrentLocal(p))
                    self.canvas.setNeedsDisplay()
                } else {
                    self.canvas.setNeedsDisplay()
                }
            }
        }
        timeline.nodeView.setIsHiddenClosure = { [unowned self] in
            self.setIsHiddenInNode(with: $0)
        }
        timeline.keyframeView.binding = { [unowned self] in
            switch self.timeline.bindingKeyframeType {
            case .cut:
                self.setKeyframeInNode(with: $0)
            case .tempo:
                self.setKeyframeInTempo(with: $0)
            }
        }
        
        exportSubtitlesView.closure = { [unowned self] in _ = self.rendererManager.exportSubtitles() }
        
        canvas.bindClosure = { [unowned self] _, m, _ in self.materialManager.material = m }
        canvas.setTimeClosure = { [unowned self] _, time in self.timeline.time = time }
        canvas.updateSceneClosure = { [unowned self] _ in
            self.differentialSceneDataModel.isWrite = true
        }
        canvas.setDraftLinesClosure = { [unowned self] _, _ in
            self.timeline.editCutView.updateChildren()
        }
        canvas.setContentsScaleClosure = { [unowned self] _, contentsScale in
            self.rendererManager.rendingContentScale = contentsScale
        }
        canvas.pasteColorBinding = { [unowned self] in self.materialManager.paste($1, in: $2) }
        canvas.pasteMaterialBinding = { [unowned self] in self.materialManager.paste($1, in: $2) }
        
        canvas.cellView.setIsLockedClosure = { [unowned self] in
            self.setIsLockedInCell(with: $0)
        }
        
        canvas.materialView.isEditingBinding = { [unowned self] (materialditor, isEditing) in
            self.canvas.materialViewType = isEditing ?
                .preview : (materialditor.isSubIndicated ? .selected : .none)
        }
        canvas.materialView.isSubIndicatedBinding = { [unowned self] (view, isSubIndicated) in
            self.canvas.materialViewType = view.isEditing ?
                .preview : (isSubIndicated ? .selected : .none)
        }
        
        canvas.player.didSetTimeClosure = { [unowned self] in
            self.seekBar.time = self.scene.secondTime(withBeatTime: $0)
        }
        canvas.player.didSetPlayFrameRateClosure = { [unowned self] in
            if !self.canvas.player.isPause {
                self.seekBar.playFrameRate = $0
            }
        }
        
        seekBar.timeBinding = { [unowned self] in
            switch $1 {
            case .begin:
                self.canvas.player.isPause = true
            case .sending:
                break
            case .end:
                self.canvas.player.isPause = false
            }
            self.canvas.player.currentPlaySecond = $0
        }
        seekBar.isPlayingBinding = { [unowned self] in
            if $0 {
                self.seekBar.maxTime = self.scene.secondTime(withBeatTime: self.scene.duration)
                self.seekBar.time = self.scene.secondTime(withBeatTime: self.scene.time)
                self.seekBar.frameRate = self.scene.frameRate
                self.canvas.play()
            } else {
                self.seekBar.time = self.scene.secondTime(withBeatTime: self.scene.time)
                self.seekBar.frameRate = 0
                self.canvas.player.stop()
            }
        }
        
        updateWithScene()
        updateLayout()
    }
    
    override var locale: Locale {
        didSet {
            updateLayout()
        }
    }
    
    override var defaultBounds: CGRect {
        let padding = Layout.basicPadding, buttonH = Layout.basicHeight
        let h = buttonH + padding * 2
        let cs = SceneView.canvasSize, th = SceneView.timelineHeight
        let inWidth = cs.width + padding + SceneView.propertyWidth
        let width = inWidth + padding * 2
        let height = th + cs.height + h + buttonH + padding * 2
        return CGRect(x: 0, y: 0, width: width, height: height)
    }
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    private func updateLayout() {
        let padding = Layout.basicPadding, sPadding = Layout.smallPadding, buttonH = Layout.basicHeight
        let h = buttonH + padding * 2
        let cs = SceneView.canvasSize, th = SceneView.timelineHeight
        let pw = SceneView.propertyWidth
        let y = bounds.height - buttonH - padding
        
        let soundWidth = 120.0.cf
        let kh = 120.0.cf
        
        classNameView.frame.origin = CGPoint(x: padding,
                                             y: bounds.height - classNameView.frame.height - padding)
        
        var topX = bounds.width - padding
        let topY = bounds.height - buttonH - padding
        let esw = exportSubtitlesView.defaultBounds.width
        topX -= esw
        exportSubtitlesView.frame = CGRect(x: topX, y: y, width: esw, height: buttonH)
        topX -= padding
        topX -= soundWidth
        soundView.frame = CGRect(x: topX, y: y, width: soundWidth, height: buttonH)
        let ihnw = isHiddenNextView.defaultBounds.width
        topX -= ihnw + padding
        isHiddenNextView.frame = CGRect(x: topX, y: topY, width: ihnw, height: buttonH)
        let ihpw = isHiddenPreviousView.defaultBounds.width
        topX -= ihpw
        isHiddenPreviousView.frame = CGRect(x: topX, y: topY, width: ihnw, height: buttonH)
        topX = classNameView.frame.maxX + padding
        versionView.frame = CGRect(x: topX, y: y, width: SceneView.versionWidth, height: buttonH)
        
        var ty = y
        ty -= th
        timeline.frame = CGRect(x: padding, y: ty, width: cs.width, height: th)
        ty -= cs.height
        canvas.frame = CGRect(x: padding, y: ty, width: cs.width, height: cs.height)
        ty -= h
        seekBar.frame = CGRect(x: padding, y: ty, width: cs.width, height: h)
        
        let px = padding * 2 + cs.width, propertyMaxY = y
        var py = propertyMaxY
        let sh = Layout.smallHeight
        let sph = sh + Layout.smallPadding * 2
        py -= sph
        sizeView.frame = CGRect(x: px, y: py, width: sizeView.defaultBounds.width, height: sph)
        frameRateView.frame = CGRect(x: sizeView.frame.maxX, y: py,
                                     width: bounds.width - sizeView.frame.maxX - padding, height: sph)
        py -= sh
        isHiddenSubtitlesView.frame = CGRect(x: px, y: py, width: pw, height: sh)
        py -= sPadding
        py -= sph
        timeline.tempoView.frame = CGRect(x: px, y: py, width: pw, height: sph)
        let tkh = ceil(kh * 0.6)
        py -= tkh
        timeline.tempoKeyframeView.frame = CGRect(x: px, y: py, width: pw, height: tkh)
        py -= padding
        py -= kh
        timeline.keyframeView.frame = CGRect(x: px, y: py, width: pw, height: kh)
        py -= sPadding
        let eh = effectView.defaultBounds.height
        py -= eh
        effectView.frame = CGRect(x: px, y: py, width: pw, height: eh)
        py -= padding
        let dh = drawingView.defaultBounds.height
        py -= dh
        drawingView.frame = CGRect(x: px, y: py, width:pw, height: dh)
        py -= padding
        let mh = canvas.materialView.defaultBounds(withWidth: pw).height
        py -= mh
        canvas.materialView.frame = CGRect(x: px, y: py, width: pw, height: mh)
        py -= padding
        let trb = transformView.defaultBounds
        py -= trb.height
        transformView.frame = CGRect(x: px, y: py, width: trb.width, height: trb.height)
        py -= padding
        let wb = wiggleView.defaultBounds
        py -= wb.height
        wiggleView.frame = CGRect(x: px, y: py, width: wb.width, height: wb.height)
        
        subtitleView.frame = CGRect(x: px, y: padding + sph, width: pw, height: sph)
        timeline.nodeView.frame = CGRect(x: px + 100, y: padding, width: pw, height: sph)
        let ch = canvas.cellView.defaultBounds.height
        py -= ch
        canvas.cellView.frame = CGRect(x: px, y: padding, width: pw, height: ch)
    }
    private func updateWithScene() {
        scene.timeBinding = { [unowned self] (_, time) in self.update(withTime: time) }
        update(withTime: scene.time)
        
        materialManager.scene = scene
        rendererManager.scene = scene
        timeline.scene = scene
        canvas.scene = scene
        sizeView.size = scene.frame.size
        frameRateView.number = scene.frameRate.cf
        isHiddenPreviousView.bool = scene.isHiddenPrevious
        isHiddenNextView.bool = scene.isHiddenNext
        isHiddenSubtitlesView.bool = scene.isHiddenSubtitles
        soundView.sound = scene.sound
        let sp = CGPoint(x: scene.frame.width, y: scene.frame.height)
        transformView.standardTranslation = sp
        wiggleView.standardAmplitude = sp
        if let effect = scene.editNode.editTrack.effectItem?.effect {
            effectView.effect = effect
        }
        drawingView.drawing = scene.editNode.editTrack.drawingItem.drawing
        if let transform = scene.editNode.editTrack.transformItem?.transform {
            transformView.transform = transform
        }
        if let wiggle = scene.editNode.editTrack.wiggleItem?.wiggle {
            wiggleView.wiggle = wiggle
        }
        subtitleView.subtitle = scene.editCut.subtitleTrack.subtitleItem.subtitle
        seekBar.time = scene.secondTime(withBeatTime: scene.time)
        seekBar.maxTime = scene.secondTime(withBeatTime: scene.duration)
    }
    
    func update(withTime time: Beat) {
        seekBar.time = scene.secondTime(withBeatTime: time)
    }
    
    var time: Beat {
        get {
            return timeline.time
        }
        set {
            if newValue != time {
                timeline.time = newValue
                differentialSceneDataModel.isWrite = true
                seekBar.time = scene.secondTime(withBeatTime: newValue)
                canvas.updateEditCellBindingLine()
            }
        }
    }
    
    override var undoManager: UndoManager? {
        return scene.version
    }
    
    private func registerUndo(time: Beat, _ closure: @escaping (SceneView, Beat) -> Void) {
        undoManager?.registerUndo(withTarget: self) { [oldTime = self.time] in
            closure($0, oldTime)
        }
        self.time = time
    }
    
    private var baseTimeIntervalOldTime = Second(0)
    
    private func setKeyframeInNode(with obj: KeyframeView.Binding) {
        switch obj.type {
        case .begin:
            let cutView = timeline.editCutView
            let track = cutView.cut.editNode.editTrack
            self.cutView = cutView
            self.animationView = cutView.editAnimationView
            self.track = track
            keyframeIndex = track.animation.editKeyframeIndex
        case .sending:
            guard let track = track,
                let animationView = animationView, let cutView = cutView else {
                    return
            }
            set(obj.keyframe, at: keyframeIndex, in: track,
                in: animationView, in: cutView)
        case .end:
            guard let track = track,
                let animationView = animationView, let cutView = cutView else {
                    return
            }
            if obj.keyframe != obj.oldKeyframe {
                set(obj.keyframe, old: obj.oldKeyframe, at: keyframeIndex, in: track,
                    in: animationView, in: cutView, time: scene.time)
            } else {
                set(obj.oldKeyframe, at: keyframeIndex, in: track,
                    in: animationView, in: cutView)
            }
        }
    }
    private func set(_ keyframe: Keyframe, at index: Int,
                     in track: NodeTrack,
                     in animationView: AnimationView, in cutView: CutView) {
        track.replace(keyframe, at: index)
        animationView.animation = track.animation
        canvas.setNeedsDisplay()
    }
    private func set(_ keyframe: Keyframe, old oldKeyframe: Keyframe,
                     at index: Int, in track: NodeTrack,
                     in animationView: AnimationView, in cutView: CutView, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldKeyframe, old: keyframe, at: index, in: track,
                   in: animationView, in: cutView, time: $1)
        }
        set(keyframe, at: index, in: track, in: animationView, in: cutView)
        differentialSceneDataModel.isWrite = true
    }
    
    private func setKeyframeInTempo(with obj: KeyframeView.Binding) {
        switch obj.type {
        case .begin:
            let track = scene.tempoTrack
            self.oldTempoTrack = track
            keyframeIndex = track.animation.editKeyframeIndex
        case .sending:
            guard let track = oldTempoTrack else {
                return
            }
            set(obj.keyframe, at: keyframeIndex, in: track, in: timeline.tempoAnimationView)
        case .end:
            guard let track = oldTempoTrack else {
                return
            }
            if obj.keyframe != obj.oldKeyframe {
                set(obj.keyframe, old: obj.oldKeyframe, at: keyframeIndex, in: track,
                    in: timeline.tempoAnimationView, time: scene.time)
            } else {
                set(obj.oldKeyframe, at: keyframeIndex, in: track,
                    in: timeline.tempoAnimationView)
            }
        }
    }
    private func set(_ keyframe: Keyframe, at index: Int,
                     in track: TempoTrack,
                     in animationView: AnimationView) {
        track.replace(keyframe, at: index)
        animationView.animation = track.animation
        timeline.updateTimeRuler()
    }
    private func set(_ keyframe: Keyframe, old oldKeyframe: Keyframe,
                     at index: Int, in track: TempoTrack,
                     in animationView: AnimationView, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldKeyframe, old: keyframe, at: index, in: track,
                   in: animationView, time: $1)
        }
        set(keyframe, at: index, in: track, in: animationView)
        timeline.updateTimeRuler()
        timeline.soundWaveformView.updateWaveform()
        differentialSceneDataModel.isWrite = true
    }
    
    private var isMadeEffectItem = false
    private weak var oldEffectItem: EffectItem?
    func set(_ effect: Effect, old oldEffect: Effect, type: Action.SendType) {
        switch type {
        case .begin:
            let cutView = timeline.editCutView
            let track = cutView.cut.editNode.editTrack
            oldEffectItem = track.effectItem
            if track.effectItem != nil {
                isMadeEffectItem = false
            } else {
                let effectItem = EffectItem.empty(with: track.animation)
                set(effectItem, in: track, in: cutView)
                isMadeEffectItem = true
            }
            self.cutView = cutView
            self.track = track
            keyframeIndex = track.animation.editKeyframeIndex
            
            set(effect, at: keyframeIndex, in: track, in: cutView)
        case .sending:
            guard let track = track, let cutView = cutView else {
                return
            }
            set(effect, at: keyframeIndex, in: track, in: cutView)
        case .end:
            guard let track = track, let cutView = cutView,
                let effectItem = track.effectItem else {
                    return
            }
            set(effect, at: keyframeIndex, in: track, in: cutView)
            if effectItem.isEmpty {
                if isMadeEffectItem {
                    set(EffectItem?.none, in: track, in: cutView)
                } else {
                    set(EffectItem?.none, old: oldEffectItem, in: track, in: cutView, time: time)
                }
            } else {
                if isMadeEffectItem {
                    set(effectItem, old: oldEffectItem,
                        in: track, in: cutView, time: scene.time)
                }
                if effect != oldEffect {
                    set(effect, old: oldEffect, at: keyframeIndex,
                        in: track, in: cutView, time: scene.time)
                } else {
                    set(oldEffect, at: keyframeIndex, in: track, in: cutView)
                }
            }
        }
    }
    private func set(_ effectItem: EffectItem?, in track: NodeTrack, in cutView: CutView) {
        track.effectItem = effectItem
        cutView.updateChildren()
    }
    private func set(_ effectItem: EffectItem?, old oldEffectItem: EffectItem?,
                     in track: NodeTrack, in cutView: CutView, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldEffectItem, old: effectItem, in: track, in: cutView, time: $1)
        }
        set(effectItem, in: track, in: cutView)
        differentialSceneDataModel.isWrite = true
    }
    private func set(_ effect: Effect, at index: Int,
                     in track: NodeTrack, in cutView: CutView) {
        track.effectItem?.replace(effect, at: index)
        track.updateInterpolation()
        cutView.cut.editNode.updateEffect()
        cutView.updateChildren()
        canvas.setNeedsDisplay()
    }
    private func set(_ effect: Effect, old oldEffect: Effect,
                     at index: Int, in track: NodeTrack, in cutView: CutView, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldEffect, old: effect, at: index, in: track, in: cutView, time: $1)
        }
        set(effect, at: index, in: track, in: cutView)
        differentialSceneDataModel.isWrite = true
    }
    
    private var keyframeIndex = 0, isMadeTransformItem = false
    private weak var oldTransformItem: TransformItem?, track: NodeTrack?
    private weak var animationView: AnimationView?, cutView: CutView?
    func set(_ transform: Transform, old oldTransform: Transform, type: Action.SendType) {
        switch type {
        case .begin:
            let cutView = timeline.editCutView
            let track = cutView.cut.editNode.editTrack
            oldTransformItem = track.transformItem
            if track.transformItem != nil {
                isMadeTransformItem = false
            } else {
                let transformItem = TransformItem.empty(with: track.animation)
                set(transformItem, in: track, in: cutView)
                isMadeTransformItem = true
            }
            self.cutView = cutView
            self.track = track
            keyframeIndex = track.animation.editKeyframeIndex
            
            set(transform, at: keyframeIndex, in: track, in: cutView)
        case .sending:
            guard let track = track, let cutView = cutView else {
                return
            }
            set(transform, at: keyframeIndex, in: track, in: cutView)
        case .end:
            guard let track = track, let cutView = cutView,
                let transformItem = track.transformItem else {
                    return
            }
            set(transform, at: keyframeIndex, in: track, in: cutView)
            if transformItem.isEmpty {
                if isMadeTransformItem {
                    set(TransformItem?.none, in: track, in: cutView)
                } else {
                    set(TransformItem?.none,
                        old: oldTransformItem, in: track, in: cutView, time: time)
                }
            } else {
                if isMadeTransformItem {
                    set(transformItem, old: oldTransformItem,
                        in: track, in: cutView, time: scene.time)
                }
                if transform != oldTransform {
                    set(transform, old: oldTransform, at: keyframeIndex,
                        in: track, in: cutView, time: scene.time)
                } else {
                    set(oldTransform, at: keyframeIndex, in: track, in: cutView)
                }
            }
        }
    }
    private func set(_ transformItem: TransformItem?, in track: NodeTrack, in cutView: CutView) {
        track.transformItem = transformItem
        cutView.updateChildren()
    }
    private func set(_ transformItem: TransformItem?, old oldTransformItem: TransformItem?,
                     in track: NodeTrack, in cutView: CutView, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldTransformItem, old: transformItem, in: track, in: cutView, time: $1)
        }
        set(transformItem, in: track, in: cutView)
        differentialSceneDataModel.isWrite = true
    }
    private func set(_ transform: Transform, at index: Int,
                     in track: NodeTrack, in cutView: CutView) {
        track.transformItem?.replace(transform, at: index)
        track.updateInterpolation()
        cutView.cut.editNode.updateTransform()
        cutView.updateChildren()
        canvas.setNeedsDisplay()
    }
    private func set(_ transform: Transform, old oldTransform: Transform,
                     at index: Int, in track: NodeTrack, in cutView: CutView, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldTransform, old: transform, at: index, in: track, in: cutView, time: $1)
        }
        set(transform, at: index, in: track, in: cutView)
        differentialSceneDataModel.isWrite = true
    }
    
    private var isMadeWiggleItem = false
    private weak var oldWiggleItem: WiggleItem?
    func set(_ wiggle: Wiggle, old oldWiggle: Wiggle, type: Action.SendType) {
        switch type {
        case .begin:
            let cutView = timeline.editCutView
            let track = cutView.cut.editNode.editTrack
            oldWiggleItem = track.wiggleItem
            if track.wiggleItem != nil {
                isMadeWiggleItem = false
            } else {
                let wiggleItem = WiggleItem.empty(with: track.animation)
                set(wiggleItem, in: track, in: cutView)
                isMadeWiggleItem = true
            }
            self.cutView = cutView
            self.track = track
            keyframeIndex = track.animation.editKeyframeIndex
            
            set(wiggle, at: keyframeIndex, in: track, in: cutView)
        case .sending:
            guard let track = track, let cutView = cutView else {
                return
            }
            set(wiggle, at: keyframeIndex, in: track, in: cutView)
        case .end:
            guard let track = track, let cutView = cutView,
                let wiggleItem = track.wiggleItem else {
                    return
            }
            set(wiggle, at: keyframeIndex, in: track, in: cutView)
            if wiggleItem.isEmpty {
                if isMadeWiggleItem {
                    set(WiggleItem?.none, in: track, in: cutView)
                } else {
                    set(WiggleItem?.none,
                        old: oldWiggleItem, in: track, in: cutView, time: time)
                }
            } else {
                if isMadeWiggleItem {
                    set(wiggleItem, old: oldWiggleItem,
                        in: track, in: cutView, time: scene.time)
                }
                if wiggle != oldWiggle {
                    set(wiggle, old: oldWiggle, at: keyframeIndex,
                        in: track, in: cutView, time: scene.time)
                } else {
                    set(oldWiggle, at: keyframeIndex, in: track, in: cutView)
                }
            }
        }
    }
    private func set(_ wiggleItem: WiggleItem?, in track: NodeTrack, in cutView: CutView) {
        track.wiggleItem = wiggleItem
        cutView.updateChildren()
    }
    private func set(_ wiggleItem: WiggleItem?, old oldWiggleItem: WiggleItem?,
                     in track: NodeTrack, in cutView: CutView, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldWiggleItem, old: wiggleItem, in: track, in: cutView, time: $1)
        }
        set(wiggleItem, in: track, in: cutView)
        differentialSceneDataModel.isWrite = true
    }
    private func set(_ wiggle: Wiggle, at index: Int,
                     in track: NodeTrack, in cutView: CutView) {
        track.replace(wiggle, at: index)
        track.updateInterpolation()
        cutView.cut.editNode.updateWiggle()
        canvas.setNeedsDisplay()
    }
    private func set(_ wiggle: Wiggle, old oldWiggle: Wiggle,
                     at index: Int, in track: NodeTrack, in cutView: CutView, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldWiggle, old: wiggle, at: index, in: track, in: cutView, time: $1)
        }
        set(wiggle, at: index, in: track, in: cutView)
        differentialSceneDataModel.isWrite = true
    }
    
    private func setIsHiddenInNode(with obj: NodeView.Binding) {
        switch obj.type {
        case .begin:
            self.cutView = timeline.editCutView
        case .sending:
            canvas.setNeedsDisplay()
            cutView?.updateChildren()
        case .end:
            guard let cutView = cutView else {
                return
            }
            
            if obj.isHidden != obj.oldIsHidden {
                set(isHidden: obj.isHidden,
                    oldIsHidden: obj.oldIsHidden,
                    in: obj.inNode, in: cutView, time: time)
            } else {
                canvas.setNeedsDisplay()
                cutView.updateChildren()
            }
        }
    }
    private func set(isHidden: Bool, oldIsHidden: Bool,
                     in node: Node, in cutView: CutView, time: Beat) {
        registerUndo(time: time) {
            $0.set(isHidden: oldIsHidden, oldIsHidden: isHidden, in: node, in: cutView, time: $1)
        }
        node.isHidden = isHidden
        canvas.setNeedsDisplay()
        cutView.updateChildren()
        differentialSceneDataModel.isWrite = true
    }
    
    private func setIsLockedInCell(with obj: CellView.Binding) {
        switch obj.type {
        case .begin:
            self.cutView = timeline.editCutView
        case .sending:
            canvas.setNeedsDisplay()
        case .end:
            guard let cutView = cutView else {
                return
            }
            if obj.isLocked != obj.oldIsLocked {
                set(isLocked: obj.isLocked,
                    oldIsLocked: obj.oldIsLocked,
                    in: obj.inCell, in: cutView, time: time)
            } else {
                canvas.setNeedsDisplay()
            }
        }
    }
    private func set(isLocked: Bool, oldIsLocked: Bool,
                     in cell: Cell, in cutView: CutView, time: Beat) {
        registerUndo(time: time) {
            $0.set(isLocked: oldIsLocked,
                   oldIsLocked: isLocked, in: cell, in: cutView, time: $1)
        }
        cell.isLocked = isLocked
        canvas.setNeedsDisplay()
        differentialSceneDataModel.isWrite = true
    }
    
    func scroll(with event: ScrollEvent) -> Bool {
        return timeline.scroll(with: event)
    }
    
    private weak var oldTempoTrack: TempoTrack?
    func set(_ tempo: BPM, old oldTempo: BPM, type: Action.SendType) {
        switch type {
        case .begin:
            let track = scene.tempoTrack
            oldTempoTrack = track
            keyframeIndex = track.animation.editKeyframeIndex
            set(tempo, at: keyframeIndex, in: track)
        case .sending:
            guard let track = oldTempoTrack else {
                return
            }
            set(tempo, at: keyframeIndex, in: track)
        case .end:
            guard let track = oldTempoTrack else {
                return
            }
            set(tempo, at: keyframeIndex, in: track)
            if tempo != oldTempo {
                set(tempo, old: oldTempo, at: keyframeIndex, in: track, time: scene.time)
            } else {
                set(oldTempo, at: keyframeIndex, in: track)
            }
        }
    }
    private func set(_ tempo: BPM, at index: Int, in track: TempoTrack) {
        track.replace(tempo: tempo, at: index)
        timeline.updateTimeRuler()
        timeline.soundWaveformView.updateWaveform()
    }
    private func set(_ tempo: BPM, old oldTempo: BPM,
                     at index: Int, in track: TempoTrack, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldTempo, old: tempo, at: index, in: track, time: $1)
        }
        set(tempo, at: index, in: track)
        differentialSceneDataModel.isWrite = true
    }
    
    private var oldNode: Node?
    func set(_ drawing: Drawing, old oldDrawing: Drawing, type: Action.SendType) {
        switch type {
        case .begin:
            let track = scene.editCut.editNode.editTrack
            oldNode = scene.editNode
            self.track = track
            keyframeIndex = track.animation.editKeyframeIndex
            set(drawing, at: keyframeIndex, in: track)
        case .sending:
            guard let track = track else {
                return
            }
            set(drawing, at: keyframeIndex, in: track)
        case .end:
            guard let track = track, let oldNode = oldNode else {
                return
            }
            set(drawing, at: keyframeIndex, in: track)
            if drawing != oldDrawing {
                set(drawing, old: oldDrawing, at: keyframeIndex, in: track, oldNode, time: scene.time)
            } else {
                set(oldDrawing, at: keyframeIndex, in: track)
            }
        }
    }
    private func set(_ drawing: Drawing, at index: Int, in track: NodeTrack) {
        track.replace(drawing, at: index)
        canvas.setNeedsDisplay()
    }
    private func set(_ drawing: Drawing, old oldDrawing: Drawing,
                     at index: Int, in track: NodeTrack, _ node: Node, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldDrawing, old: drawing, at: index, in: track, node, time: $1)
        }
        set(drawing, at: index, in: track)
        node.differentialDataModel.isWrite = true
        differentialSceneDataModel.isWrite = true
    }
    
    private weak var oldSubtitleTrack: SubtitleTrack?
    func set(_ subtitle: Subtitle, old oldSubtitle: Subtitle, type: Action.SendType) {
        switch type {
        case .begin:
            let track = scene.editCut.subtitleTrack
            oldSubtitleTrack = track
            keyframeIndex = track.animation.editKeyframeIndex
            set(subtitle, at: keyframeIndex, in: track)
        case .sending:
            guard let track = oldSubtitleTrack else {
                return
            }
            set(subtitle, at: keyframeIndex, in: track)
        case .end:
            guard let track = oldSubtitleTrack else {
                return
            }
            set(subtitle, at: keyframeIndex, in: track)
            if subtitle != oldSubtitle {
                set(subtitle, old: oldSubtitle, at: keyframeIndex, in: track, time: scene.time)
            } else {
                set(oldSubtitle, at: keyframeIndex, in: track)
            }
        }
    }
    private func set(_ subtitle: Subtitle, at index: Int, in track: SubtitleTrack) {
        track.replace(subtitle, at: index)
    }
    private func set(_ subtitle: Subtitle, old oldSubtitle: Subtitle,
                     at index: Int, in track: SubtitleTrack, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldSubtitle, old: subtitle, at: index, in: track, time: $1)
        }
        set(subtitle, at: index, in: track)
        differentialSceneDataModel.isWrite = true
    }
}

/**
 # Issue
 - Undo時の時間の登録
 - マテリアルアニメーション
 */
final class SceneMaterialManager {
    lazy var scene = Scene()
    weak var sceneView: SceneView! {
        didSet {
            let view = sceneView.canvas.materialView
            view.typeBinding = { [unowned self] in self.setType(with: $0) }
            view.colorBinding = { [unowned self] in self.setColor(with: $0) }
            view.lineColorBinding = { [unowned self] in self.setLineColor(with: $0) }
            view.lineWidthBinding = { [unowned self] in self.setLineWidth(with: $0) }
            view.opacityBinding = { [unowned self] in self.setOpacity(with: $0) }
        }
    }
    
    init() {
    }
    
    var material: Material {
        get {
            return sceneView.canvas.materialView.material
        }
        set {
            scene.editMaterial = newValue
            sceneView.canvas.materialView.material = newValue
            sceneView.differentialSceneDataModel.isWrite = true
        }
    }
    
    var undoManager: UndoManager? {
        return sceneView.undoManager
    }
    
    private struct ColorTuple {
        var color: Color, materialTuples: [UUID: MaterialTuple]
    }
    private struct MaterialTuple {
        var material: Material, cutTuples: [CutTuple]
    }
    private struct CutTuple {
        var cut: Cut, cells: [Cell], materialItemTuples: [MaterialItemTuple]
    }
    private struct MaterialItemTuple {
        var track: NodeTrack, materialItem: MaterialItem, editIndexes: [Int]
        static func materialItemTuples(with materialItem: MaterialItem,
                                       isSelected: Bool, in track: NodeTrack
            ) -> [UUID: (material: Material, itemTupe: MaterialItemTuple)] {
            
            var mits = [UUID: (material: Material, itemTupe: MaterialItemTuple)]()
            for (i, material) in materialItem.keyMaterials.enumerated() {
                if mits[material.id] == nil {
                    let indexes: [Int]
                    if isSelected {
                        indexes = [track.animation.editKeyframeIndex]
                    } else {
                        indexes = (i ..< materialItem.keyMaterials.count)
                            .filter { materialItem.keyMaterials[$0].id == material.id }
                    }
                    mits[material.id] = (material, MaterialItemTuple(track: track,
                                                                     materialItem: materialItem,
                                                                     editIndexes: indexes))
                }
            }
            return mits
        }
    }
    
    private var materialTuples = [UUID: MaterialTuple](), colorTuples = [ColorTuple]()
    private var oldMaterialTuple: MaterialTuple?, oldMaterial: Material?
    private func colorTuplesWith(color: Color?, useSelected: Bool = false,
                                 in cut: Cut, _ cuts: [Cut]) -> [ColorTuple] {
        if useSelected {
            let allSelectedCells = cut.editNode.allSelectedCellItemsWithNoEmptyGeometry
            if !allSelectedCells.isEmpty {
                return colorTuplesWith(cells: allSelectedCells.map { $0.cell },
                                       isSelected: useSelected, in: cut)
            }
        }
        if let color = color {
            return colorTuplesWith(color: color, isSelected: useSelected, in: cuts)
        } else {
            return colorTuplesWith(cells: cut.cells, isSelected: useSelected, in: cut)
        }
    }
    private func colorTuplesWith(cells: [Cell], isSelected: Bool, in cut: Cut) -> [ColorTuple] {
        struct ColorCell {
            var color: Color, cells: [Cell]
        }
        var colors = [UUID: ColorCell]()
        for cell in cells {
            if colors[cell.material.color.id] != nil {
                colors[cell.material.color.id]?.cells.append(cell)
            } else {
                colors[cell.material.color.id] = ColorCell(color: cell.material.color, cells: [cell])
            }
        }
        return colors.map {
            ColorTuple(color: $0.value.color,
                       materialTuples: materialTuplesWith(cells: $0.value.cells,
                                                          isSelected: isSelected, in: cut))
        }
    }
    private func colorTuplesWith(color: Color, isSelected: Bool, in cuts: [Cut]) -> [ColorTuple] {
        let cutTuples: [CutTuple] = cuts.compactMap { cut in
            let cells = cut.cells.filter { $0.material.color == color }
            
            var materialItemTuples = [MaterialItemTuple]()
            for track in cut.editNode.tracks {
                for materialItem in track.materialItems {
                    let indexes = materialItem.keyMaterials.enumerated().compactMap {
                        $0.element.color == color ? $0.offset : nil
                    }
                    if !indexes.isEmpty {
                        materialItemTuples.append(MaterialItemTuple(track: track,
                                                                    materialItem: materialItem,
                                                                    editIndexes: indexes))
                    }
                }
            }
            
            return cells.isEmpty && materialItemTuples.isEmpty ?
                nil : CutTuple(cut: cut, cells: cells, materialItemTuples: materialItemTuples)
        }
        let materialTuples = SceneMaterialManager.materialTuples(with: cutTuples)
        
        return materialTuples.isEmpty ?
            [] : [ColorTuple(color: color, materialTuples: materialTuples)]
    }
    private static func materialTuples(with cutTuples: [CutTuple]) -> [UUID: MaterialTuple] {
        let materials = cutTuples.reduce(into: Set<Material>()) { materials, cutTuple in
            cutTuple.cells.forEach { materials.insert($0.material) }
            cutTuple.materialItemTuples.forEach { mit in
                mit.editIndexes.forEach { materials.insert(mit.materialItem.keyMaterials[$0]) }
            }
        }
        return materials.reduce(into: [UUID: MaterialTuple]()) { materialTuples, material in
            let cutTuples: [CutTuple] = cutTuples.compactMap { cutTuple in
                let cells = cutTuple.cells.filter { $0.material.id == material.id }
                let mts: [MaterialItemTuple] = cutTuple.materialItemTuples.compactMap { mit in
                    let indexes = mit.editIndexes.compactMap {
                        mit.materialItem.keyMaterials[$0].id == material.id ? $0 : nil
                    }
                    return indexes.isEmpty ?
                        nil :
                        MaterialItemTuple(track: mit.track,
                                          materialItem: mit.materialItem, editIndexes: indexes)
                }
                return cells.isEmpty && mts.isEmpty ?
                    nil : CutTuple(cut: cutTuple.cut, cells: cells, materialItemTuples: mts)
            }
            materialTuples[material.id] = MaterialTuple(material: material, cutTuples: cutTuples)
        }
    }
    
    private func materialTuplesWith(cells: [Cell], color: Color? = nil,
                                    isSelected: Bool, in cut: Cut) -> [UUID: MaterialTuple] {
        var materials = [UUID: MaterialTuple]()
        for cell in cells {
            if materials[cell.material.id] != nil {
                materials[cell.material.id]?.cutTuples[0].cells.append(cell)
            } else {
                let cutTuples = [CutTuple(cut: cut, cells: [cell], materialItemTuples: [])]
                materials[cell.material.id] = MaterialTuple(material: cell.material,
                                                            cutTuples: cutTuples)
            }
        }
        
        for track in cut.editNode.tracks {
            for materialItem in track.materialItems {
                if cells.contains(where: { materialItem.cells.contains($0) }) {
                    let mits = MaterialItemTuple.materialItemTuples(with: materialItem,
                                                                    isSelected: isSelected, in: track)
                    for mit in mits {
                        if let color = color {
                            if mit.value.material.color != color {
                                continue
                            }
                        }
                        if materials[mit.key] != nil {
                            materials[mit.key]?.cutTuples[0]
                                .materialItemTuples.append(mit.value.itemTupe)
                        } else {
                            let materialItemTuples = [mit.value.itemTupe]
                            let cutTuples = [CutTuple(cut: cut, cells: [],
                                                      materialItemTuples: materialItemTuples)]
                            materials[mit.key] = MaterialTuple(material: mit.value.material,
                                                               cutTuples: cutTuples)
                        }
                    }
                }
            }
        }
        
        return materials
    }
    private func materialTuplesWith(material: Material?, useSelected: Bool = false,
                                    in editCut: Cut, _ cuts: [Cut]) -> [UUID: MaterialTuple] {
        if useSelected {
            let allSelectedCells = editCut.editNode.allSelectedCellItemsWithNoEmptyGeometry
            if !allSelectedCells.isEmpty {
                return materialTuplesWith(cells: allSelectedCells.map { $0.cell },
                                          isSelected: useSelected, in: editCut)
            }
        }
        if let material = material {
            let cutTuples: [CutTuple] = cuts.compactMap { cut in
                let cells = cut.cells.filter { $0.material.id == material.id }
                
                var materialItemTuples = [MaterialItemTuple]()
                for track in cut.editNode.tracks {
                    for materialItem in track.materialItems {
                        let indexes = useSelected ?
                            [track.animation.editKeyframeIndex] :
                            materialItem.keyMaterials.enumerated().compactMap {
                                $0.element.id == material.id ? $0.offset : nil }
                        if !indexes.isEmpty {
                            materialItemTuples.append(MaterialItemTuple(track: track,
                                                                        materialItem: materialItem,
                                                                        editIndexes: indexes))
                        }
                    }
                }
                
                return cells.isEmpty && materialItemTuples.isEmpty ?
                    nil : CutTuple(cut: cut, cells: cells, materialItemTuples: materialItemTuples)
            }
            return cutTuples.isEmpty ? [:] : [material.id: MaterialTuple(material: material,
                                                                         cutTuples: cutTuples)]
        } else {
            return materialTuplesWith(cells: editCut.cells, isSelected: useSelected, in: editCut)
        }
    }
    
    private var oldTime = Beat(0)
    
    private func selectedMaterialTuple(with colorTuples: [ColorTuple]) -> MaterialTuple? {
        for colorTuple in colorTuples {
            if let tuple = colorTuple.materialTuples[material.id] {
                return tuple
            }
        }
        return nil
    }
    private func selectedMaterialTuple(with materialTuples: [UUID: MaterialTuple]) -> MaterialTuple? {
        return materialTuples[material.id]
    }
    private func changeMaterialWith(isColorTuple: Bool, type: Action.SendType) {
        switch type {
        case .begin:
            oldMaterialTuple = isColorTuple ?
                selectedMaterialTuple(with: colorTuples) :
                selectedMaterialTuple(with: materialTuples)
            if let oldMaterialTuple = oldMaterialTuple {
                material = oldMaterialTuple.cutTuples[0].cells[0].material
            }
        case .sending:
            if let oldMaterialTuple = oldMaterialTuple {
                material = oldMaterialTuple.cutTuples[0].cells[0].material
            }
        case .end:
            if let oldMaterialTuple = oldMaterialTuple {
                _set(oldMaterialTuple.cutTuples[0].cells[0].material,
                     old: oldMaterialTuple.material)
            }
            oldMaterialTuple = nil
        }
    }
    private func set(_ material: Material, in materialTuple: MaterialTuple) {
        for cutTuple in materialTuple.cutTuples {
            for cell in cutTuple.cells {
                cell.material = material
            }
            for materialItemTuple in cutTuple.materialItemTuples {
                set(material, editIndexes: materialItemTuple.editIndexes,
                    in: materialItemTuple.materialItem, materialItemTuple.track)
            }
        }
    }
    private func _set(_ material: Material, in materialTuple: MaterialTuple) {
        for cutTuple in materialTuple.cutTuples {
            _set(material, old: materialTuple.material, in: cutTuple.cells, cutTuple.cut)
            
            for materialItemTuple in cutTuple.materialItemTuples {
                _set(material, old: materialTuple.material,
                     editIndexes: materialItemTuple.editIndexes,
                     in: materialItemTuple.materialItem, materialItemTuple.track, cutTuple.cut)
            }
        }
    }
    
    private func set(_ material: Material, editIndexes: [Int],
                     in materialItem: MaterialItem, _ track: NodeTrack) {
        var keyMaterials = materialItem.keyMaterials
        editIndexes.forEach { keyMaterials[$0] = material }
        track.set(keyMaterials, in: materialItem)
        track.updateInterpolation()
    }
    private func _set(_ material: Material, old oldMaterial: Material, editIndexes: [Int],
                      in materialItem: MaterialItem, _ track: NodeTrack, _ cut: Cut) {
        undoManager?.registerUndo(withTarget: self) {
            $0._set(oldMaterial, old: material, editIndexes: editIndexes, in: materialItem, track, cut)
        }
        set(material, editIndexes: editIndexes, in: materialItem, track)
        sceneView.differentialSceneDataModel.isWrite = true
        if cut === sceneView.canvas.cut {
            sceneView.canvas.setNeedsDisplay()
        }
    }
    
    func paste(_ objects: [Any], with event: KeyInputEvent) -> Bool {
        for object in objects {
            if let material = object as? Material {
                paste(material, withSelected: self.material, useSelected: false)
                return true
            }
        }
        return false
    }
    
    func splitColor() {
        guard let editCell = sceneView.canvas.editCell else {
            return
        }
        let node = scene.editNode
        let cells = node.selectedCells(with: editCell)
        if !cells.isEmpty {
            splitColor(with: cells)
        }
    }
    func splitOtherThanColor() {
        guard let editCell = sceneView.canvas.editCell else {
            return
        }
        let node = scene.editNode
        let cells = node.selectedCells(with: editCell)
        if !cells.isEmpty {
            splitOtherThanColor(with: cells)
        }
    }
    
    func paste(_ material: Material, in cells: [Cell]) {
        if cells.count == 1, let cell = cells.first {
            paste(material, withSelected: cell.material, useSelected: false)
        } else {
            let materialTuples = materialTuplesWith(cells: cells, isSelected: true, in: scene.editCut)
            for materialTuple in materialTuples.values {
                _set(material, in: materialTuple)
            }
            if let material = materialTuples.first?.value.cutTuples.first?.cells.first?.material {
                _set(material, old: self.material)
            }
        }
    }
    func paste(_ color: Color, in cells: [Cell]) {
        let colorTuples = colorTuplesWith(cells: cells, isSelected: true, in: scene.editCut)
        for colorTuple in colorTuples {
            for materialTuple in colorTuple.materialTuples.values {
                _set(materialTuple.material.with(color), in: materialTuple)
            }
        }
        if let material =
            colorTuples.first?.materialTuples.first?.value.cutTuples.first?.cells.first?.material {
            
            _set(material, old: self.material)
        }
    }
    func paste(_ material: Material, withSelected selectedMaterial: Material, useSelected: Bool) {
        let materialTuples = materialTuplesWith(material: selectedMaterial,
                                                useSelected: useSelected,
                                                in: scene.editCut, scene.cutTrack.cutItem.keyCuts)
        for materialTuple in materialTuples.values {
            _set(material, in: materialTuple)
        }
        if let material = materialTuples.first?.value.cutTuples.first?.cells.first?.material {
            _set(material, old: self.material)
        }
    }
    func paste(_ color: Color, withSelected selectedMaterial: Material, useSelected: Bool) {
        let colorTuples = colorTuplesWith(color: selectedMaterial.color, useSelected: useSelected,
                                          in: scene.editCut, scene.cutTrack.cutItem.keyCuts)
        _setColor(color, in: colorTuples)
        if let material =
            colorTuples.first?.materialTuples.first?.value.cutTuples.first?.cells.first?.material {
            
            _set(material, old: self.material)
        }
    }
    func splitMaterial(with cells: [Cell]) {
        let materialTuples = materialTuplesWith(cells: cells, isSelected: true, in: scene.editCut)
        for materialTuple in materialTuples.values {
            _set(materialTuple.material.with(materialTuple.material.color.withNewID()),
                 in: materialTuple)
        }
        if let material = materialTuples.first?.value.cutTuples.first?.cells.first?.material {
            _set(material, old: self.material)
        }
    }
    func splitColor(with cells: [Cell]) {
        let colorTuples = colorTuplesWith(cells: cells, isSelected: true, in: scene.editCut)
        for colorTuple in colorTuples {
            let newColor = colorTuple.color.withNewID()
            for materialTuple in colorTuple.materialTuples.values {
                _set(materialTuple.material.with(newColor), in: materialTuple)
            }
        }
        if let material =
            colorTuples.first?.materialTuples.first?.value.cutTuples.first?.cells.first?.material {
            
            _set(material, old: self.material)
        }
    }
    func splitOtherThanColor(with cells: [Cell]) {
        let materialTuples = materialTuplesWith(cells: cells, isSelected: true, in: scene.editCut)
        for materialTuple in materialTuples.values {
            _set(materialTuple.material.with(materialTuple.material.color),
                 in: materialTuple)
        }
        if let material = materialTuples.first?.value.cutTuples.first?.cells.first?.material {
            _set(material, old: self.material)
        }
    }
    private func _set(_ material: Material, old oldMaterial: Material,
                      in cells: [Cell], _ cut: Cut) {
        undoManager?.registerUndo(withTarget: self) {
            $0._set(oldMaterial, old: material, in: cells, cut)
        }
        cells.forEach { $0.material = material }
        sceneView.differentialSceneDataModel.isWrite = true
        if cut === sceneView.canvas.cut {
            sceneView.canvas.setNeedsDisplay()
        }
    }
    func select(_ material: Material) {
        _set(material, old: self.material)
    }
    private func _set(_ material: Material, old oldMaterial: Material) {
        undoManager?.registerUndo(withTarget: self) { $0._set(oldMaterial, old: material) }
        self.material = material
    }
    
    func setType(with binding: MaterialView.TypeBinding) {
        switch binding.sendType {
        case .begin:
            materialTuples = materialTuplesWith(material: binding.oldMaterial,
                                                in: scene.editCut, scene.cutTrack.cutItem.keyCuts)
        case .sending:
            setMaterialType(binding.type, in: materialTuples)
        case .end:
            _setMaterialType(binding.type, in: materialTuples)
            materialTuples = [:]
        }
        changeMaterialWith(isColorTuple: false, type: binding.sendType)
        sceneView.canvas.setNeedsDisplay()
    }
    private func setMaterialType(_ type: Material.MaterialType,
                                 in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            set(materialTuple.material.with(type), in: materialTuple)
        }
    }
    private func _setMaterialType(_ type: Material.MaterialType,
                                  in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            _set(materialTuple.material.with(type), in: materialTuple)
        }
    }
    
    private func setColor(with binding: MaterialView.ColorBinding) {
        switch binding.type {
        case .begin:
            colorTuples = colorTuplesWith(color: binding.oldColor,
                                          in: scene.editCut, scene.cutTrack.cutItem.keyCuts)
        case .sending:
            setColor(binding.color, in: colorTuples)
        case .end:
            _setColor(binding.color, in: colorTuples)
            colorTuples = []
        }
        changeMaterialWith(isColorTuple: true, type: binding.type)
        sceneView.canvas.setNeedsDisplay()
    }
    private func setColor(_ color: Color, in colorTuples: [ColorTuple]) {
        for colorTuple in colorTuples {
            for materialTuple in colorTuple.materialTuples.values {
                set(materialTuple.material.with(color), in: materialTuple)
            }
        }
    }
    private func _setColor(_ color: Color, in colorTuples: [ColorTuple]) {
        for colorTuple in colorTuples {
            for materialTuple in colorTuple.materialTuples.values {
                _set(materialTuple.material.with(color), in: materialTuple)
            }
        }
    }
    
    private func setLineColor(with binding: MaterialView.LineColorBinding) {
        switch binding.type {
        case .begin:
            materialTuples = materialTuplesWith(material: binding.oldMaterial,
                                                in: scene.editCut, scene.cutTrack.cutItem.keyCuts)
            setLineColor(binding.lineColor, in: materialTuples)
        case .sending:
            setLineColor(binding.lineColor, in: materialTuples)
        case .end:
            _setLineColor(binding.lineColor, in: materialTuples)
            materialTuples = [:]
        }
        changeMaterialWith(isColorTuple: false, type: binding.type)
        sceneView.canvas.setNeedsDisplay()
    }
    private func setLineColor(_ lineColor: Color, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            set(materialTuple.material.with(lineColor: lineColor), in: materialTuple)
        }
    }
    private func _setLineColor(_ lineColor: Color, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            _set(materialTuple.material.with(lineColor: lineColor), in: materialTuple)
        }
    }
    
    func setLineWidth(with binding: MaterialView.LineWidthBinding) {
        switch binding.type {
        case .begin:
            materialTuples = materialTuplesWith(material: binding.oldMaterial,
                                                in: scene.editCut, scene.cutTrack.cutItem.keyCuts)
        case .sending:
            setLineWidth(binding.lineWidth, in: materialTuples)
        case .end:
            _setLineWidth(binding.lineWidth, in: materialTuples)
            materialTuples = [:]
        }
        changeMaterialWith(isColorTuple: false, type: binding.type)
        sceneView.canvas.setNeedsDisplay()
    }
    private func setLineWidth(_ lineWidth: CGFloat, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            set(materialTuple.material.with(lineWidth: lineWidth), in: materialTuple)
        }
    }
    private func _setLineWidth(_ lineWidth: CGFloat, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            _set(materialTuple.material.with(lineWidth: lineWidth), in: materialTuple)
        }
    }
    
    func setOpacity(with binding: MaterialView.OpacityBinding) {
        switch binding.type {
        case .begin:
            materialTuples = materialTuplesWith(material: binding.oldMaterial,
                                                in: scene.editCut, scene.cutTrack.cutItem.keyCuts)
        case .sending:
            setOpacity(binding.opacity, in: materialTuples)
        case .end:
            _setOpacity(binding.opacity, in: materialTuples)
            materialTuples = [:]
        }
        changeMaterialWith(isColorTuple: false, type: binding.type)
        sceneView.canvas.setNeedsDisplay()
    }
    private func setOpacity(_ opacity: CGFloat, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            set(materialTuple.material.with(opacity: opacity), in: materialTuple)
        }
    }
    private func _setOpacity(_ opacity: CGFloat, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            _set(materialTuple.material.with(opacity: opacity), in: materialTuple)
        }
    }
    
    var isAnimatedMaterial: Bool {
        for materialItem in scene.editNode.editTrack.materialItems {
            if materialItem.keyMaterials.contains(material) {
                return true
            }
        }
        return false
    }
    
    func appendAnimation() -> Bool {
        guard !isAnimatedMaterial else {
            return false
        }
        let cut =  scene.editCut
        let track = cut.editNode.editTrack
        let keyMaterials = track.emptyKeyMaterials(with: material)
        let cells = cut.cells.filter { $0.material == material }
        append(MaterialItem(material: material, cells: cells, keyMaterials: keyMaterials),
               in: track, cut)
        return true
    }
    func removeAnimation() -> Bool {
        guard isAnimatedMaterial else {
            return false
        }
        let cut = scene.editCut
        let track = cut.editNode.editTrack
        remove(track.materialItems[track.materialItems.count - 1],
               in: cut.editNode.editTrack, cut)
        return true
    }
    
    private func append(_ materialItem: MaterialItem, in track: NodeTrack, _ cut: Cut) {
        undoManager?.registerUndo(withTarget: self) { $0.remove(materialItem, in: track, cut) }
        track.append(materialItem)
        sceneView.differentialSceneDataModel.isWrite = true
    }
    private func remove(_ materialItem: MaterialItem, in track: NodeTrack, _ cut: Cut) {
        undoManager?.registerUndo(withTarget: self) { $0.append(materialItem, in: track, cut) }
        track.remove(materialItem)
        sceneView.differentialSceneDataModel.isWrite = true
    }
}
