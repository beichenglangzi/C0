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
typealias FPS = CGFloat
typealias FrameTime = Int
typealias BaseTime = Q
typealias Beat = Q
typealias DoubleBeat = CGFloat
typealias DoubleBaseTime = CGFloat
typealias Second = CGFloat

/**
 Issue: 複数のサウンド
 Issue: 変更通知
 */
final class Scene: NSObject, NSCoding {
    var version = Version()
    var name: String
    var frame: Rect
    var editMaterial: Material
    var isHiddenPrevious: Bool, isHiddenNext: Bool
    var isHiddenSubtitles: Bool
    var sound: Sound
    var renderingVerticalResolution: Int
    
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
//    var sumAnimation
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
    
    static let timeIntervalOption = RationalNumberOption(defaultModel: Q(1, 16),
                                                         minModel: Q(1, 100000), maxModel: 100000,
                                                         modelInterval: 1,
                                                         isInfinitesimal: true, unit: " b")
    
    init(name: String = Localization(english: "Untitled", japanese: "名称未設定").currentString,
         frame: Rect = Rect(x: -288, y: -162, width: 576, height: 324),
         frameRate: FPS = 24,
         baseTimeInterval: Beat = Beat(1, 24),
         editMaterial: Material = Material(),
         isHiddenPrevious: Bool = true, isHiddenNext: Bool = true,
         isHiddenSubtitles: Bool = false,
         sound: Sound = Sound(),
         renderingVerticalResolution: Int = 1080,
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
        self.renderingVerticalResolution = renderingVerticalResolution
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
        editMaterial, isHiddenPrevious, isHiddenNext, isHiddenSubtitles, sound,
        renderingVerticalResolution,
        viewTransform,
        tempoTrack, cutTrack, time
    }
    init?(coder: NSCoder) {
        name = coder.decodeObject(forKey: CodingKeys.name.rawValue) as? String ?? ""
        frame = coder.decodeRect(forKey: CodingKeys.frame.rawValue)
        frameRate = coder.decodeDouble(forKey: CodingKeys.frameRate.rawValue).cg
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
        renderingVerticalResolution = coder.decodeInteger(forKey:
            CodingKeys.renderingVerticalResolution.rawValue)
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
        coder.encode(Double(frameRate), forKey: CodingKeys.frameRate.rawValue)
        coder.encodeEncodable(baseTimeInterval, forKey: CodingKeys.baseTimeInterval.rawValue)
        coder.encode(editMaterial, forKey: CodingKeys.editMaterial.rawValue)
        coder.encode(isHiddenPrevious, forKey: CodingKeys.isHiddenPrevious.rawValue)
        coder.encode(isHiddenNext, forKey: CodingKeys.isHiddenNext.rawValue)
        coder.encode(isHiddenSubtitles, forKey: CodingKeys.isHiddenSubtitles.rawValue)
        coder.encodeEncodable(viewTransform, forKey: CodingKeys.viewTransform.rawValue)
        coder.encodeEncodable(sound, forKey: CodingKeys.sound.rawValue)
        coder.encode(renderingVerticalResolution, forKey:
            CodingKeys.renderingVerticalResolution.rawValue)
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
    
    var curretEditKeyframeTime: Beat {
        let cut = editCut
        let animation = cut.editNode.editTrack.animation
        let t = cut.currentTime >= animation.duration ?
            animation.duration : animation.editKeyframe.time
        let cutAnimation = cutTrack.animation
        return cutAnimation.keyframes[cutAnimation.editLoopframeIndex].time + t
    }
    var curretEditKeyframeTimeExpression: Expression {
        let time = curretEditKeyframeTime
        let iap = time.integerAndProperFraction
        return Expression(iap.integer) + Expression(iap.properFraction)
    }
    
    func cutTime(withFrameTime frameTime: Int) -> (cutItemIndex: Int, cut: Cut, time: Beat) {
        let t = cutTrack.cutIndex(withTime: beatTime(withFrameTime: frameTime))
        return (t.index, cuts[t.index], t.interTime)
    }
    var secondTime: (second: Int, frame: Int) {
        let second = secondTime(withBeatTime: time)
        let frameTime = FrameTime(second * Second(frameRate))
        return (Int(second), frameTime - Int(second * frameRate))
    }
    func secondTime(with frameTime: FrameTime) -> (second: Int, frame: Int) {
        let second = Int(CGFloat(frameTime) / frameRate)
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
extension Scene: ClassDeepCopiable {
    func copied(from deepCopier: DeepCopier) -> Scene {
        return Scene(frame: frame, frameRate: frameRate,
                     editMaterial: editMaterial,
                     isHiddenPrevious: isHiddenPrevious, isHiddenNext: isHiddenNext,
                     sound: sound,
                     renderingVerticalResolution: renderingVerticalResolution,
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
 Issue: セルをキャンバス外にペースト
 Issue: Display P3サポート
 */
final class SceneView: View, Scrollable {
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
            
            timelineView.differentialSceneDataModel = differentialSceneDataModel
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
    
    static let versionWidth = 120.0.cg, propertyWidth = 200.0.cg
    static let canvasSize = Size(width: 730, height: 480), timelineHeight = 190.0.cg
    
    let classNameView = TextView(text: Scene.name, font: .bold)
    let versionView = VersionView()
    
    let timelineView = TimelineView()
    let canvas = Canvas()
    let seekBar = SeekBar()
    
    let rendererManager = RendererManager()
    let sizeView = DiscreteSizeView(sizeType: .small)
    let frameRateView = DiscreteRealNumberView(model: 24,
                                           option: RealNumberOption(defaultModel: 24,
                                                                minModel: 1, maxModel: 1000,
                                                                modelInterval: 1, exp: 1,
                                                                numberOfDigits: 0, unit: " fps"),
                                           frame: Layout.valueFrame(with: .small),
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
    
    let renderingVerticalResolutionView = DiscreteIntView(model: 1,
                                                          option: IntOption(defaultModel: 1080,
                                                                            minModel: 1,
                                                                            maxModel: 10000,
                                                                            modelInterval: 1, exp: 1,
                                                                            unit: " p"),
                                                          frame: Layout.valueFrame(with: .small),
                                                          sizeType: .small)
    
    let exportSubtitlesView = ClosureView(closure: {}, name: Localization(english: "Export Subtitles",
                                                                          japanese: "字幕を書き出す"))
    let exportImageView = ClosureView(closure: {}, name: Localization(english: "Export Image",
                                                                      japanese: "画像を書き出す"))
    let exportMovieView = ClosureView(closure: {}, name: Localization(english: "Export Movie",
                                                                      japanese: "動画を書き出す"))
    
    let soundView = SoundView(sizeType: .small)
    let drawingView = DrawingView()
    let materialManager = SceneMaterialManager()
    //bindingView   /cutTrack.cuts[].editNode.tracks[].transforms[]
    let transformView = TransformView()
    let wiggleXView = WiggleView()
    let wiggleYView = WiggleView()
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
        timelineView.differentialSceneDataModel = differentialSceneDataModel
        canvas.sceneDataModel = differentialSceneDataModel
        
        versionView.version = scene.version
        
        super.init()
        bounds = defaultBounds
        materialManager.sceneView = self
        
        children = [classNameView,
                    versionView,
                    sizeView, frameRateView, renderingVerticalResolutionView,
                    exportSubtitlesView, exportImageView, exportMovieView,
                    isHiddenPreviousView, isHiddenNextView, timelineView.baseTimeIntervalView,
                    soundView,
                    timelineView.keyframeView,
                    drawingView, canvas.materialView, transformView, wiggleXView, wiggleYView,
                    timelineView.tempoView, timelineView.tempoKeyframeView,
                    timelineView.baseTimeIntervalView,
                    isHiddenSubtitlesView,
                    timelineView.nodeView, effectView,
                    canvas.cellView,
                    timelineView, canvas, seekBar]
        
        differentialSceneDataModel.dataClosure = { [unowned self] in self.scene.differentialData }
        
        rendererManager.progressesEdgeView = self
        sizeView.binding = { [unowned self] in
            self.scene.frame = Rect(origin: Point(x: -$0.size.width / 2,
                                                      y: -$0.size.height / 2), size: $0.size)
            self.canvas.setNeedsDisplay()
            let sp = Point(x: $0.size.width, y: $0.size.height)
            self.transformView.standardTranslation = sp
            self.wiggleXView.standardAmplitude = $0.size.width
            self.wiggleYView.standardAmplitude = $0.size.height
            if $0.phase == .ended && $0.size != $0.oldSize {
                self.differentialSceneDataModel.isWrite = true
            }
        }
        frameRateView.binding = { [unowned self] in
            self.scene.frameRate = $0.model
            if $0.phase == .ended && $0.model != $0.oldModel {
                self.differentialSceneDataModel.isWrite = true
            }
        }
        renderingVerticalResolutionView.binding = { [unowned self] in
            self.scene.renderingVerticalResolution = $0.model
            if $0.phase == .ended && $0.model != $0.oldModel {
                self.differentialSceneDataModel.isWrite = true
            }
        }
        
        isHiddenPreviousView.binding = { [unowned self] in
            self.canvas.isHiddenPrevious = $0.bool
            if $0.phase == .ended && $0.bool != $0.oldBool {
                self.differentialSceneDataModel.isWrite = true
            }
        }
        isHiddenNextView.binding = { [unowned self] in
            self.canvas.isHiddenNext = $0.bool
            if $0.phase == .ended && $0.bool != $0.oldBool {
                self.differentialSceneDataModel.isWrite = true
            }
        }
        isHiddenSubtitlesView.binding = { [unowned self] in
            self.scene.isHiddenSubtitles = $0.bool
            if $0.phase == .ended && $0.bool != $0.oldBool {
                self.differentialSceneDataModel.isWrite = true
            }
        }
        
        soundView.setSoundClosure = { [unowned self] in
            self.scene.sound = $0.sound
            self.timelineView.soundWaveformView.sound = $0.sound
            if $0.phase == .ended && $0.sound != $0.oldSound {
                self.differentialSceneDataModel.isWrite = true
            }
            if self.scene.sound.url == nil && self.canvas.player.audioPlayer?.isPlaying ?? false {
                self.canvas.player.audioPlayer?.stop()
            }
        }
        
        effectView.binding = { [unowned self] in
            self.set($0.effect, old: $0.oldEffect, $0.phase)
        }
        drawingView.binding = { [unowned self] in
            self.set($0.drawing, old: $0.oldDrawing, $0.phase)
        }
        transformView.binding = { [unowned self] in
            self.set($0.transform, old: $0.oldTransform, $0.phase)
        }
        wiggleXView.binding = { [unowned self] in
            self.set($0.wiggle, old: $0.oldWiggle, $0.phase)
        }
        
//        subtitleView.binding = { [unowned self] in
//            self.set($0.subtitle, old: $0.oldSubtitle, type: $0.type)
//        }
        
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
        
        timelineView.tempoView.binding = { [unowned self] in
            self.set($0.model, old: $0.oldModel, $0.phase)
        }
        timelineView.setSceneDurationClosure = { [unowned self] in
            self.seekBar.maxTime = self.scene.secondTime(withBeatTime: $1)
        }
        timelineView.setEditCutItemIndexClosure = { [unowned self] _, _ in
            self.canvas.cut = self.scene.editCut
            self.drawingView.drawing = self.scene.editNode.editTrack.drawingItem.drawing
            self.transformView.transform =
                self.scene.editNode.editTrack.transformItem?.transform ?? Transform()
            self.wiggleXView.wiggle =
                self.scene.editNode.editTrack.wiggleItem?.wiggle ?? Wiggle()
            self.effectView.effect =
                self.scene.editNode.editTrack.effectItem?.effect ?? Effect()
            self.subtitleView.subtitle = self.scene.editCut.subtitleTrack.subtitleItem.subtitle
        }
        timelineView.updateViewClosure = { [unowned self] in
            if $0.isCut {
//                let p = self.canvas.cursorPoint
//                if self.canvas.contains(p) {
//                    self.canvas.updateEditView(with: self.canvas.convertToCurrentLocal(p))
//                }
                self.canvas.setNeedsDisplay()
            }
            if $0.isTransform {
                self.drawingView.drawing = self.scene.editNode.editTrack.drawingItem.drawing
                self.transformView.transform =
                    self.scene.editNode.editTrack.transformItem?.transform ?? Transform()
                self.wiggleXView.wiggle =
                    self.scene.editNode.editTrack.wiggleItem?.wiggle ?? Wiggle()
                self.effectView.effect =
                    self.scene.editNode.editTrack.effectItem?.effect ?? Effect()
                self.subtitleView.subtitle = self.scene.editCut.subtitleTrack.subtitleItem.subtitle
            }
        }
        timelineView.setNodeAndTrackBinding = { [unowned self] timeline, cutView, nodeAndTrack in
            if cutView == timeline.editCutView {
//                let p = self.canvas.cursorPoint
//                if self.canvas.contains(p) {
//                    self.canvas.updateEditView(with: self.canvas.convertToCurrentLocal(p))
//                }
                self.canvas.setNeedsDisplay()
            }
        }
        timelineView.nodeView.setIsHiddenClosure = { [unowned self] in
            self.setIsHiddenInNode(with: $0)
        }
        timelineView.keyframeView.binding = { [unowned self] in
            switch self.timelineView.bindingKeyframeType {
            case .cut:
                self.setKeyframeInNode(with: $0)
            case .tempo:
                self.setKeyframeInTempo(with: $0)
            }
        }
        
        exportSubtitlesView.closure = { [unowned self] in _ = self.rendererManager.exportSubtitles() }
        exportImageView.closure = { [unowned self] in
            let size = self.scene.frame.size, p = self.scene.renderingVerticalResolution
            let newSize = Size(width: floor((size.width * CGFloat(p)) / size.height), height: CGFloat(p))
            let sizeString = "w: \(Int(newSize.width)) px, h: \(Int(newSize.height)) px"
            let message = Localization(english: "Export Image(\(sizeString))",
                                       japanese: "画像として書き出す(\(sizeString))").currentString
            _ = self.rendererManager.exportImage(message: message, size: newSize)
        }
        exportMovieView.closure = { [unowned self] in
            let size = self.scene.frame.size, p = self.scene.renderingVerticalResolution
            let newSize = Size(width: floor((size.width * CGFloat(p)) / size.height), height: CGFloat(p))
            let sizeString = "w: \(Int(newSize.width)) px, h: \(Int(newSize.height)) px"
            let message = Localization(english: "Export Movie(\(sizeString))",
                                       japanese: "動画として書き出す(\(sizeString))").currentString
            _ = self.rendererManager.exportMovie(message: message, size: newSize)
        }
        
        canvas.bindClosure = { [unowned self] _, m, _ in self.materialManager.material = m }
        canvas.setTimeClosure = { [unowned self] _, time in self.timelineView.time = time }
        canvas.updateSceneClosure = { [unowned self] _ in
            self.differentialSceneDataModel.isWrite = true
        }
        canvas.setDraftLinesClosure = { [unowned self] _, _ in
            self.timelineView.editCutView.updateChildren()
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
            case .began:
                self.canvas.player.isPause = true
            case .changed:
                break
            case .ended:
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
    
    override var defaultBounds: Rect {
        let padding = Layout.basicPadding, buttonH = Layout.basicHeight
        let h = buttonH + padding * 2
        let cs = SceneView.canvasSize, th = SceneView.timelineHeight
        let inWidth = cs.width + padding + SceneView.propertyWidth
        let width = inWidth + padding * 2
        let height = th + cs.height + h + buttonH + padding * 2
        return Rect(x: 0, y: 0, width: width, height: height)
    }
    override var bounds: Rect {
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
        
        let kh = 120.0.cg
        
        classNameView.frame.origin = Point(x: padding,
                                             y: bounds.height - classNameView.frame.height - padding)
        
        var topX = bounds.width - padding
        let topY = bounds.height - buttonH - padding
        let esw = exportSubtitlesView.defaultBounds.width
        topX -= esw
        exportSubtitlesView.frame = Rect(x: topX, y: y, width: esw, height: buttonH)
        topX -= esw
        exportImageView.frame = Rect(x: topX, y: y, width: esw, height: buttonH)
        topX -= esw
        exportMovieView.frame = Rect(x: topX, y: y, width: esw, height: buttonH)
        let ihnw = isHiddenNextView.defaultBounds.width
        topX -= ihnw + padding
        isHiddenNextView.frame = Rect(x: topX, y: topY, width: ihnw, height: buttonH)
        let ihpw = isHiddenPreviousView.defaultBounds.width
        topX -= ihpw
        isHiddenPreviousView.frame = Rect(x: topX, y: topY, width: ihpw, height: buttonH)
        let tiw = Layout.valueWidth(with: .regular)
        topX -= tiw
        timelineView.baseTimeIntervalView.frame = Rect(x: topX, y: topY,
                                                         width: tiw, height: buttonH)
        topX = classNameView.frame.maxX + padding
        versionView.frame = Rect(x: topX, y: y, width: SceneView.versionWidth, height: buttonH)
        
        var ty = y
        ty -= th
        timelineView.frame = Rect(x: padding, y: ty, width: cs.width, height: th)
        ty -= cs.height
        canvas.frame = Rect(x: padding, y: ty, width: cs.width, height: cs.height)
        ty -= h
        seekBar.frame = Rect(x: padding, y: ty, width: cs.width, height: h)
        
        let px = padding * 2 + cs.width, propertyMaxY = y
        var py = propertyMaxY
        let sh = Layout.smallHeight
        let sph = sh + Layout.smallPadding * 2
        py -= sph
        sizeView.frame = Rect(x: px, y: py, width: sizeView.defaultBounds.width, height: sph)
        frameRateView.frame = Rect(x: sizeView.frame.maxX, y: py,
                                     width: Layout.valueWidth(with: .small), height: sph)
        renderingVerticalResolutionView.frame = Rect(x: frameRateView.frame.maxX,
                                                       y: py,
                                                       width: bounds.width - frameRateView.frame.maxX - padding,
                                                       height: sph)
        py -= sh
        isHiddenSubtitlesView.frame = Rect(x: px, y: py, width: pw / 2, height: sh)
        soundView.frame = Rect(x: px + pw / 2, y: py, width: pw / 2, height: sh)
        
        py -= sPadding
        py -= sph
        timelineView.tempoView.frame = Rect(x: px, y: py, width: pw, height: sph)
//        let tkh = ceil(kh * 0.6)
//        py -= tkh
//        timelineView.tempoKeyframeView.frame = Rect(x: px, y: py, width: pw, height: tkh)
        py -= padding
        py -= kh
        timelineView.keyframeView.frame = Rect(x: px, y: py, width: pw, height: kh)
        py -= sPadding
        let eh = effectView.defaultBounds.height
        py -= eh
        effectView.frame = Rect(x: px, y: py, width: pw, height: eh)
        py -= padding
        let dh = drawingView.defaultBounds.height
        py -= dh
        drawingView.frame = Rect(x: px, y: py, width:pw, height: dh)
        py -= padding
        let mh = canvas.materialView.defaultBounds(withWidth: pw).height
        py -= mh
        canvas.materialView.frame = Rect(x: px, y: py, width: pw, height: mh)
        py -= padding
        let trb = transformView.defaultBounds
        py -= trb.height
        transformView.frame = Rect(x: px, y: py, width: pw, height: trb.height)
        py -= padding
        let wb = wiggleXView.defaultBounds
        py -= wb.height
        wiggleXView.frame = Rect(x: px, y: py, width: pw / 2, height: wb.height)
        
//        subtitleView.frame = Rect(x: px, y: padding + sph, width: pw, height: sph)
        timelineView.nodeView.frame = Rect(x: px + 100, y: padding, width: pw, height: sph)
        let ch = canvas.cellView.defaultBounds.height
        py -= ch
        canvas.cellView.frame = Rect(x: px, y: padding, width: pw, height: ch)
    }
    private func updateWithScene() {
        scene.timeBinding = { [unowned self] (_, time) in self.update(withTime: time) }
        update(withTime: scene.time)
        
        versionView.version = scene.version
        
        materialManager.scene = scene
        rendererManager.scene = scene
        timelineView.scene = scene
        canvas.scene = scene
        sizeView.size = scene.frame.size
        frameRateView.model = scene.frameRate
        isHiddenPreviousView.bool = scene.isHiddenPrevious
        isHiddenNextView.bool = scene.isHiddenNext
        isHiddenSubtitlesView.bool = scene.isHiddenSubtitles
        soundView.sound = scene.sound
        renderingVerticalResolutionView.model = scene.renderingVerticalResolution
        let sp = Point(x: scene.frame.width, y: scene.frame.height)
        transformView.standardTranslation = sp
        wiggleXView.standardAmplitude = scene.frame.width
        wiggleYView.standardAmplitude = scene.frame.height
        if let effect = scene.editNode.editTrack.effectItem?.effect {
            effectView.effect = effect
        }
        drawingView.drawing = scene.editNode.editTrack.drawingItem.drawing
        if let transform = scene.editNode.editTrack.transformItem?.transform {
            transformView.transform = transform
        }
        if let wiggle = scene.editNode.editTrack.wiggleItem?.wiggle {
            wiggleXView.wiggle = wiggle
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
            return timelineView.time
        }
        set {
            if newValue != time {
                timelineView.time = newValue
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
        switch obj.phase {
        case .began:
            let cutView = timelineView.editCutView
            let track = cutView.cut.editNode.editTrack
            self.cutView = cutView
            self.animationView = cutView.editAnimationView
            self.track = track
            keyframeIndex = track.animation.editKeyframeIndex
        case .changed:
            guard let track = track,
                let animationView = animationView, let cutView = cutView else {
                    return
            }
            set(obj.keyframe, at: keyframeIndex, in: track,
                in: animationView, in: cutView)
        case .ended:
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
        switch obj.phase {
        case .began:
            let track = scene.tempoTrack
            self.oldTempoTrack = track
            keyframeIndex = track.animation.editKeyframeIndex
        case .changed:
            guard let track = oldTempoTrack else {
                return
            }
            set(obj.keyframe, at: keyframeIndex, in: track, in: timelineView.tempoAnimationView)
        case .ended:
            guard let track = oldTempoTrack else {
                return
            }
            if obj.keyframe != obj.oldKeyframe {
                set(obj.keyframe, old: obj.oldKeyframe, at: keyframeIndex, in: track,
                    in: timelineView.tempoAnimationView, time: scene.time)
            } else {
                set(obj.oldKeyframe, at: keyframeIndex, in: track,
                    in: timelineView.tempoAnimationView)
            }
        }
    }
    private func set(_ keyframe: Keyframe, at index: Int,
                     in track: TempoTrack,
                     in animationView: AnimationView) {
        track.replace(keyframe, at: index)
        animationView.animation = track.animation
        timelineView.updateTimeRuler()
    }
    private func set(_ keyframe: Keyframe, old oldKeyframe: Keyframe,
                     at index: Int, in track: TempoTrack,
                     in animationView: AnimationView, time: Beat) {
        registerUndo(time: time) {
            $0.set(oldKeyframe, old: keyframe, at: index, in: track,
                   in: animationView, time: $1)
        }
        set(keyframe, at: index, in: track, in: animationView)
        timelineView.updateTimeRuler()
        timelineView.soundWaveformView.updateWaveform()
        differentialSceneDataModel.isWrite = true
    }
    
    private var isMadeEffectItem = false
    private weak var oldEffectItem: EffectItem?
    func set(_ effect: Effect, old oldEffect: Effect, _ phase: Phase) {
        switch phase {
        case .began:
            let cutView = timelineView.editCutView
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
        case .changed:
            guard let track = track, let cutView = cutView else {
                return
            }
            set(effect, at: keyframeIndex, in: track, in: cutView)
        case .ended:
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
    func set(_ transform: Transform, old oldTransform: Transform, _ phase: Phase) {
        switch phase {
        case .began:
            let cutView = timelineView.editCutView
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
        case .changed:
            guard let track = track, let cutView = cutView else {
                return
            }
            set(transform, at: keyframeIndex, in: track, in: cutView)
        case .ended:
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
    func set(_ wiggle: Wiggle, old oldWiggle: Wiggle, _ phase: Phase) {
        switch phase {
        case .began:
            let cutView = timelineView.editCutView
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
        case .changed:
            guard let track = track, let cutView = cutView else {
                return
            }
            set(wiggle, at: keyframeIndex, in: track, in: cutView)
        case .ended:
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
        switch obj.phase {
        case .began:
            self.cutView = timelineView.editCutView
        case .changed:
            canvas.setNeedsDisplay()
            cutView?.updateChildren()
        case .ended:
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
        switch obj.phase {
        case .began:
            self.cutView = timelineView.editCutView
        case .changed:
            canvas.setNeedsDisplay()
        case .ended:
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
    
    func scroll(for p: Point, time: Second, scrollDeltaPoint: Point,
                phase: Phase, momentumPhase: Phase?) {
        timelineView.scroll(for: p, time: time, scrollDeltaPoint: scrollDeltaPoint,
                            phase: phase, momentumPhase: momentumPhase)
    }
    
    private weak var oldTempoTrack: TempoTrack?
    func set(_ tempo: BPM, old oldTempo: BPM, _ phase: Phase) {
        switch phase {
        case .began:
            let track = scene.tempoTrack
            oldTempoTrack = track
            keyframeIndex = track.animation.editKeyframeIndex
            set(tempo, at: keyframeIndex, in: track)
        case .changed:
            guard let track = oldTempoTrack else {
                return
            }
            set(tempo, at: keyframeIndex, in: track)
        case .ended:
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
        timelineView.updateTimeRuler()
        timelineView.soundWaveformView.updateWaveform()
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
    func set(_ drawing: Drawing, old oldDrawing: Drawing, _ phase: Phase) {
        switch phase {
        case .began:
            let track = scene.editCut.editNode.editTrack
            oldNode = scene.editNode
            self.track = track
            keyframeIndex = track.animation.editKeyframeIndex
            set(drawing, at: keyframeIndex, in: track)
        case .changed:
            guard let track = track else {
                return
            }
            set(drawing, at: keyframeIndex, in: track)
        case .ended:
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
    func set(_ subtitle: Subtitle, old oldSubtitle: Subtitle, _ phase: Phase) {
        switch phase {
        case .began:
            let track = scene.editCut.subtitleTrack
            oldSubtitleTrack = track
            keyframeIndex = track.animation.editKeyframeIndex
            set(subtitle, at: keyframeIndex, in: track)
        case .changed:
            guard let track = oldSubtitleTrack else {
                return
            }
            set(subtitle, at: keyframeIndex, in: track)
        case .ended:
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
    
    func reference(at p: Point) -> Reference {
        return Scene.reference
    }
}

/**
 Issue: Undo時の時間の登録
 Issue: マテリアルアニメーション
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
            return colorTuplesWith(cells: cut.allCells, isSelected: useSelected, in: cut)
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
            let cells = cut.allCells.filter { $0.material.color == color }
            
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
                let cells = cut.allCells.filter { $0.material.id == material.id }
                
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
            return materialTuplesWith(cells: editCut.allCells, isSelected: useSelected, in: editCut)
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
    private func changeMaterialWith(isColorTuple: Bool, _ phase: Phase) {
        switch phase {
        case .began:
            oldMaterialTuple = isColorTuple ?
                selectedMaterialTuple(with: colorTuples) :
                selectedMaterialTuple(with: materialTuples)
            if let oldMaterialTuple = oldMaterialTuple {
                material = oldMaterialTuple.cutTuples[0].cells[0].material
            }
        case .changed:
            if let oldMaterialTuple = oldMaterialTuple {
                material = oldMaterialTuple.cutTuples[0].cells[0].material
            }
        case .ended:
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
    
    func paste(_ objects: [Any], for p: Point) -> Bool {
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
        switch binding.phase {
        case .began:
            materialTuples = materialTuplesWith(material: binding.oldMaterial,
                                                in: scene.editCut, scene.cutTrack.cutItem.keyCuts)
        case .changed:
            setMaterialType(binding.type, in: materialTuples)
        case .ended:
            _setMaterialType(binding.type, in: materialTuples)
            materialTuples = [:]
        }
        changeMaterialWith(isColorTuple: false, binding.phase)
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
        switch binding.phase {
        case .began:
            colorTuples = colorTuplesWith(color: binding.oldColor,
                                          in: scene.editCut, scene.cutTrack.cutItem.keyCuts)
        case .changed:
            setColor(binding.color, in: colorTuples)
        case .ended:
            _setColor(binding.color, in: colorTuples)
            colorTuples = []
        }
        changeMaterialWith(isColorTuple: true, binding.phase)
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
        switch binding.phase {
        case .began:
            materialTuples = materialTuplesWith(material: binding.oldMaterial,
                                                in: scene.editCut, scene.cutTrack.cutItem.keyCuts)
            setLineColor(binding.lineColor, in: materialTuples)
        case .changed:
            setLineColor(binding.lineColor, in: materialTuples)
        case .ended:
            _setLineColor(binding.lineColor, in: materialTuples)
            materialTuples = [:]
        }
        changeMaterialWith(isColorTuple: false, binding.phase)
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
        switch binding.phase {
        case .began:
            materialTuples = materialTuplesWith(material: binding.oldMaterial,
                                                in: scene.editCut, scene.cutTrack.cutItem.keyCuts)
        case .changed:
            setLineWidth(binding.lineWidth, in: materialTuples)
        case .ended:
            _setLineWidth(binding.lineWidth, in: materialTuples)
            materialTuples = [:]
        }
        changeMaterialWith(isColorTuple: false, binding.phase)
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
        switch binding.phase {
        case .began:
            materialTuples = materialTuplesWith(material: binding.oldMaterial,
                                                in: scene.editCut, scene.cutTrack.cutItem.keyCuts)
        case .changed:
            setOpacity(binding.opacity, in: materialTuples)
        case .ended:
            _setOpacity(binding.opacity, in: materialTuples)
            materialTuples = [:]
        }
        changeMaterialWith(isColorTuple: false, binding.phase)
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
        let cells = cut.allCells.filter { $0.material == material }
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
