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
 △ 字幕
 - 複数のサウンド
 - 変更通知
 */
final class Scene: NSObject, NSCoding {
    var name: String
    var frame: CGRect, frameRate: FPS, baseTimeInterval: Beat
    var colorSpace: ColorSpace {
        didSet {
            self.materials = materials.map { $0.with($0.color.with(colorSpace: colorSpace)) }
        }
    }
    var editMaterial: Material, materials: [Material]
    var isShownPrevious: Bool, isShownNext: Bool
    
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
    
    var isHiddenSubtitles: Bool
    
    var sound: Sound
    
    var tempoTrack: TempoTrack
    var cutTrack: CutTrack
    var editCut: Cut {
        return cutTrack.cutItem.cut
    }
    var cuts: [Cut] {
        return cutTrack.cutItem.keyCuts
    }
    var editNode: Node {
        return editCut.editNode
    }
    var editCutIndex: Int {
        get {
            return cutTrack.animation.editLoopframeIndex
        }
        set {
            cutTrack.time = cutTrack.time(at: newValue)
        }
    }
    
    var timeBinding: ((Scene, Beat) -> ())?
    var time: Beat {
        didSet {
            timeBinding?(self, time)
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
         frame: CGRect = CGRect(x: -288, y: -162, width: 576, height: 324), frameRate: FPS = 24,
         baseTimeInterval: Beat = Beat(1, 24),
         colorSpace: ColorSpace = .sRGB,
         editMaterial: Material = Material(), materials: [Material] = [],
         isShownPrevious: Bool = false, isShownNext: Bool = false,
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
        self.colorSpace = colorSpace
        self.editMaterial = editMaterial
        self.materials = materials
        self.isShownPrevious = isShownPrevious
        self.isShownNext = isShownNext
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
        name, frame, frameRate, baseTimeInterval, tempo, colorSpace,
        editMaterial, materials, isShownPrevious, isShownNext, isHiddenSubtitles, sound,
        tempoTrack, cutTrack, time,
        viewTransform
    }
    init?(coder: NSCoder) {
        name = coder.decodeObject(forKey: CodingKeys.name.rawValue) as? String ?? ""
        frame = coder.decodeRect(forKey: CodingKeys.frame.rawValue)
        frameRate = coder.decodeInteger(forKey: CodingKeys.frameRate.rawValue)
        baseTimeInterval = coder.decodeDecodable(
            Beat.self, forKey: CodingKeys.baseTimeInterval.rawValue) ?? Beat(1, 16)
        colorSpace = ColorSpace(
            rawValue: Int8(coder.decodeInt32(forKey: CodingKeys.colorSpace.rawValue))) ?? .sRGB
        editMaterial = coder.decodeObject(
            forKey: CodingKeys.editMaterial.rawValue) as? Material ?? Material()
        materials = coder.decodeObject(forKey: CodingKeys.materials.rawValue) as? [Material] ?? []
        isShownPrevious = coder.decodeBool(forKey: CodingKeys.isShownPrevious.rawValue)
        isShownNext = coder.decodeBool(forKey: CodingKeys.isShownNext.rawValue)
        viewTransform = coder.decodeDecodable(
            Transform.self, forKey: CodingKeys.viewTransform.rawValue) ?? Transform()
        isHiddenSubtitles = coder.decodeBool(forKey: CodingKeys.isHiddenSubtitles.rawValue)
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
        coder.encode(Int32(colorSpace.rawValue), forKey: CodingKeys.colorSpace.rawValue)
        coder.encode(editMaterial, forKey: CodingKeys.editMaterial.rawValue)
        coder.encode(materials, forKey: CodingKeys.materials.rawValue)
        coder.encode(isShownPrevious, forKey: CodingKeys.isShownPrevious.rawValue)
        coder.encode(isShownNext, forKey: CodingKeys.isShownNext.rawValue)
        coder.encodeEncodable(viewTransform, forKey: CodingKeys.viewTransform.rawValue)
        coder.encode(isHiddenSubtitles, forKey: CodingKeys.isHiddenSubtitles.rawValue)
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
        return Subtitle.vtt(subtitleTuples, timeHandler: { secondTime(withBeatTime: $0) })
    }
}
extension Scene: Copying {
    func copied(from copier: Copier) -> Scene {
        return Scene(frame: frame, frameRate: frameRate,
                     editMaterial: editMaterial, materials: materials,
                     isShownPrevious: isShownPrevious, isShownNext: isShownNext,
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
final class SceneView: Layer, Respondable, Localizable {
    static let name = Localization(english: "Scene View", japanese: "シーン表示")
    
    var locale = Locale.current {
        didSet {
            updateLayout()
        }
    }
    
    var scene = Scene() {
        didSet {
            updateWithScene()
        }
    }
    
    static let sceneViewKey = "sceneView", sceneKey = "scene"
    var sceneDataModel = DataModel(key: SceneView.sceneKey)
    override var dataModel: DataModel? {
        didSet {
            guard let dataModel = dataModel else {
                return
            }
            if let sceneDataModel = dataModel.children[SceneView.sceneKey] {
                self.sceneDataModel = sceneDataModel
                if let scene: Scene = sceneDataModel.readObject() {
                    self.scene = scene
                }
                sceneDataModel.dataHandler = { [unowned self] in self.scene.differentialData }
            } else {
                dataModel.insert(sceneDataModel)
            }
            
            if let cutTrackDataModel = dataModel.children[CutTrack.dataModelKey] {
                scene.cutTrack.differentialDataModel = cutTrackDataModel
                canvas.cut = scene.editCut
            } else {
                dataModel.insert(scene.cutTrack.differentialDataModel)
            }
            
            timeline.sceneDataModel = sceneDataModel
            canvas.sceneDataModel = sceneDataModel
            updateWithScene()
        }
    }
    
    static let colorSpaceWidth = 82.cf
    static let colorSpaceFrame = CGRect(x: 0, y: Layout.basicPadding,
                                        width: colorSpaceWidth, height: Layout.basicHeight)
    static let rendererWidth = 80.0.cf, undoWidth = 120.0.cf
    static let canvasSize = CGSize(width: 730, height: 480)
    static let propertyWidth = MaterialView.defaultWidth + Layout.basicPadding * 2
    static let buttonsWidth = 120.0.cf, timelineWidth = 430.0.cf
    static let timelineTextBoxesWidth = 142.0.cf, timelineHeight = 170.0.cf
    
    let nameLabel = Label(text: Scene.name, font: .bold)
    let versionView = VersionView()
    let rendererManager = RendererManager()
    let sizeView = DiscreteSizeView()
    let frameRateSlider = NumberSlider(frame: Layout.valueFrame,
                                       min: 1, max: 1000, valueInterval: 1, unit: " fps",
                                       description: Localization(english: "Frame rate",
                                                                 japanese: "フレームレート"))
    let baseTimeIntervalSlider =
        NumberSlider(frame: Layout.valueFrame, min: 1, max: 1000, valueInterval: 1, unit: " cpb",
                     description: Localization(english: "Edit split count per beat",
                                               japanese: "1ビートあたりの編集用分割数"))
    let colorSpaceLabel = Label(text: Localization(", "))
    let colorSpaceView = EnumView(frame: SceneView.colorSpaceFrame,
                                  names: [Localization("sRGB"), Localization("Display P3")],
                                  description: Localization(english: "Color Space", japanese: "色空間"))
    let isShownPreviousView =
        EnumView(names: [Localization(english: "Hidden Previous", japanese: "前の表示なし"),
                         Localization(english: "Shown Previous", japanese: "前の表示あり")],
                 cationIndex: 1,
                 description: Localization(english: "Hide or Show line drawing of previous keyframe",
                                           japanese: "前のキーフレームの表示切り替え"))
    let isShownNextView =
        EnumView(names: [Localization(english: "Hidden Next", japanese: "次の表示なし"),
                         Localization(english: "Shown Next", japanese: "次の表示あり")],
                 cationIndex: 1,
                 description: Localization(english: "Hide or Show line drawing of next keyframe",
                                           japanese: "次のキーフレームの表示切り替え"))
    let isHiddenSubtitlesView =
        EnumView(names: [Localization(english: "Hidden Subtitles", japanese: "字幕表示なし"),
                         Localization(english: "Shown Subtitles", japanese: "字幕表示あり")],
                 cationIndex: 0,
                 isSmall: true)
    
    let shapeLinesBox = PopupBox(frame: CGRect(x: 0, y: 0, width: 100.0, height: Layout.basicHeight),
                                 text: Localization(english: "Shape Lines", japanese: "図形の線"))
    let changeToDraftBox = TextBox(name: Localization(english: "Change to Draft", japanese: "下書き化"))
    let removeDraftBox = TextBox(name: Localization(english: "Remove Draft", japanese: "下書きを削除"))
    let swapDraftBox = TextBox(name: Localization(english: "Swap Draft", japanese: "下書きと交換"))
    
    let showAllBox = TextBox(name: Localization(english: "Unlock All Cells",
                                                japanese: "すべてのセルのロックを解除"))
    let clipCellInSelectedBox = TextBox(name: Localization(english: "Clip Cell in Selected",
                                                           japanese: "セルを選択の中へクリップ"))
    let splitColorBox = TextBox(name: Localization(english: "Split Color", japanese: "カラーを分割"))
    let splitOtherThanColorBox = TextBox(name: Localization(english: "Split Material",
                                                            japanese: "マテリアルを分割"))
    
    let subtitleView = SubtitleView(isSmall: true)
    let soundView = SoundView()
    let effectView = EffectView()
    let transformView = TransformView()
    let wiggleView = WiggleView()
    
    let timeline = Timeline()
    let canvas = Canvas()
    let playerView = PlayerView()
    
    let materialManager = SceneMaterialManager()
    
    override init() {
        super.init()
        materialManager.sceneView = self
        dataModel = DataModel(key: SceneView.sceneViewKey,
                              directoryWithDataModels: [sceneDataModel,
                                                        scene.cutTrack.differentialDataModel])
        timeline.sceneDataModel = sceneDataModel
        canvas.sceneDataModel = sceneDataModel
        
        replace(children: [nameLabel,
                           versionView,
                           rendererManager.popupBox, sizeView, frameRateSlider,
                           baseTimeIntervalSlider, isShownPreviousView, isShownNextView,
                           isHiddenSubtitlesView,
                           soundView, timeline.tempoSlider, transformView, wiggleView,
                           timeline.nodeView,
                           timeline.keyframeView, timeline.tempoKeyframeView,
                           timeline.nodeBindingLineLayer, subtitleView,
                           shapeLinesBox, changeToDraftBox, removeDraftBox, swapDraftBox,
                           canvas.cellView, showAllBox, clipCellInSelectedBox,
                           canvas.materialView, materialManager.animationBox,
                           splitColorBox, splitOtherThanColorBox,
                           canvas.editCellBindingLineLayer,
                           effectView,
                           timeline, canvas, playerView])
        
        sceneDataModel.dataHandler = { [unowned self] in self.scene.differentialData }
        
        versionView.rootUndoManager = rootUndoManager
        rendererManager.progressesEdgeLayer = self
        sizeView.binding = { [unowned self] in
            self.scene.frame = CGRect(origin: CGPoint(x: -$0.size.width / 2,
                                                      y: -$0.size.height / 2), size: $0.size)
            self.canvas.setNeedsDisplay()
            let sp = CGPoint(x: self.scene.frame.width, y: self.scene.frame.height)
            self.transformView.standardTranslation = sp
            self.wiggleView.standardAmplitude = sp
            if $0.type == .end && $0.size != $0.oldSize {
                self.sceneDataModel.isWrite = true
            }
        }
        frameRateSlider.binding = { [unowned self] in
            self.scene.frameRate = Int($0.value)
            if $0.type == .end && $0.value != $0.oldValue {
                self.sceneDataModel.isWrite = true
            }
        }
        baseTimeIntervalSlider.binding = { [unowned self] in
            if $0.type == .begin {
                self.baseTimeIntervalOldTime = self.scene.secondTime(withBeatTime: self.scene.time)
            }
            self.scene.baseTimeInterval.q = Int($0.value)
            self.timeline.time = self.scene.basedBeatTime(withSecondTime: self.baseTimeIntervalOldTime)
            self.timeline.baseTimeInterval = self.scene.baseTimeInterval
            if $0.type == .end && $0.value != $0.oldValue {
                self.sceneDataModel.isWrite = true
            }
        }
        colorSpaceView.binding = { [unowned self] in
            self.scene.colorSpace = $0.index == 0 ? .sRGB : .displayP3
            self.canvas.setNeedsDisplay()
            if $0.type == .end && $0.index != $0.oldIndex {
                self.sceneDataModel.isWrite = true
            }
        }
        isShownPreviousView.binding = { [unowned self] in
            self.canvas.isShownPrevious = $0.index == 1
            if $0.type == .end && $0.index != $0.oldIndex {
                self.sceneDataModel.isWrite = true
            }
        }
        isShownNextView.binding = { [unowned self] in
            self.canvas.isShownNext = $0.index == 1
            if $0.type == .end && $0.index != $0.oldIndex {
                self.sceneDataModel.isWrite = true
            }
        }
        isHiddenSubtitlesView.binding = { [unowned self] in
            self.scene.isHiddenSubtitles = $0.index == 0
            if $0.type == .end && $0.index != $0.oldIndex {
                self.sceneDataModel.isWrite = true
            }
        }
        
        let children = [TextBox(name: Localization(english: "Append Square Lines",
                                                   japanese: "正方形の線を追加"),
                                runHandler: { [unowned self] _ in self.canvas.appendSquareLines() }),
                        TextBox(name: Localization(english: "Append Pentagon Lines",
                                                   japanese: "正五角形の線を追加"),
                                runHandler: { [unowned self] _ in self.canvas.appendPentagonLines() }),
                        TextBox(name: Localization(english: "Append Hexagon Lines",
                                                   japanese: "正六角形の線を追加"),
                                runHandler: { [unowned self] _ in self.canvas.appendHexagonLines() }),
                        TextBox(name: Localization(english: "Append Circle Lines",
                                                   japanese: "円の線を追加"),
                                runHandler: { [unowned self] _ in self.canvas.appendCircleLines() })]
        shapeLinesBox.panel.replace(children: children)
        var minSize = CGSize()
        Layout.topAlignment(shapeLinesBox.panel.children, minSize: &minSize)
        shapeLinesBox.panel.frame.size = CGSize(width: minSize.width + Layout.basicPadding * 2,
                                                height: minSize.height + Layout.basicPadding * 2)
        changeToDraftBox.runHandler = { [unowned self] _ in
            self.canvas.changeToRough()
            return true
        }
        removeDraftBox.runHandler = { [unowned self] _ in
            self.canvas.removeRough()
            return true
        }
        swapDraftBox.runHandler = { [unowned self] _ in
            self.canvas.swapRough()
            return true
        }
        
        showAllBox.runHandler = { [unowned self] _ in
            self.canvas.unlockAllCells()
            return true
        }
        clipCellInSelectedBox.runHandler = { [unowned self] _ in
            self.canvas.clipCellInSelected()
            return true
        }
        splitColorBox.runHandler = { [unowned self] _ in
            self.materialManager.splitColor()
            return true
        }
        splitOtherThanColorBox.runHandler = { [unowned self] _ in
            self.materialManager.splitOtherThanColor()
            return true
        }
        
        effectView.binding = { [unowned self] in
            self.set($0.effect, old: $0.oldEffect, type: $0.type)
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
        
        timeline.tempoSlider.binding = { [unowned self] in
            self.set(BPM($0.value), old: BPM($0.oldValue), type: $0.type)
        }
        timeline.scrollHandler = { [unowned self] (timeline, scrollPoint, event) in
            if event.sendType == .begin && self.canvas.player.isPlaying {
                self.canvas.player.opacity = 0.2
            } else if event.sendType == .end && self.canvas.player.opacity != 1 {
                self.canvas.player.opacity = 1
            }
        }
        timeline.setSceneDurationHandler = { [unowned self] in
            self.playerView.maxTime = self.scene.secondTime(withBeatTime: $1)
        }
        timeline.setEditCutItemIndexHandler = { [unowned self] _, _ in
            self.canvas.cut = self.scene.editCut
            self.transformView.transform =
                self.scene.editNode.editTrack.transformItem?.transform ?? Transform()
            self.wiggleView.wiggle =
                self.scene.editNode.editTrack.wiggleItem?.wiggle ?? Wiggle()
            self.effectView.effect =
                self.scene.editNode.editTrack.effectItem?.effect ?? Effect()
        }
        timeline.updateViewHandler = { [unowned self] in
            if $0.isCut {
                let p = self.canvas.cursorPoint
                if self.canvas.contains(p) {
                    self.canvas.updateEditView(with: self.canvas.convertToCurrentLocal(p))
                }
                self.canvas.setNeedsDisplay()
            }
            if $0.isTransform {
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
        timeline.nodeView.setIsHiddenHandler = { [unowned self] in
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
        
        canvas.bindHandler = { [unowned self] _, m, _ in self.materialManager.material = m }
        canvas.setTimeHandler = { [unowned self] _, time in self.timeline.time = time }
        canvas.updateSceneHandler = { [unowned self] _ in self.sceneDataModel.isWrite = true }
        canvas.setRoughLinesHandler = { [unowned self] _, _ in
            self.timeline.editCutView.updateChildren()
        }
        canvas.setContentsScaleHandler = { [unowned self] _, contentsScale in
            self.rendererManager.rendingContentScale = contentsScale
        }
        canvas.pasteColorBinding = { [unowned self] in
            self.materialManager.paste($1, in: $2)
        }
        canvas.pasteMaterialBinding = { [unowned self] in
            self.materialManager.paste($1, in: $2)
        }
        
        canvas.cellView.setIsTranslucentLockHandler = { [unowned self] in
            self.setIsTranslucentLockInCell(with: $0)
        }
        
        canvas.materialView.isEditingBinding = { [unowned self] (materialditor, isEditing) in
            self.canvas.materialViewType = isEditing ?
                .preview : (materialditor.isSubIndicated ? .selected : .none)
        }
        canvas.materialView.isSubIndicatedBinding = {
            [unowned self] (materialView, isSubIndicated) in
            
            self.canvas.materialViewType = materialView.isEditing ?
                .preview : (isSubIndicated ? .selected : .none)
        }
        
        canvas.player.didSetTimeHandler = { [unowned self] in
            self.playerView.time = self.scene.secondTime(withBeatTime: $0)
        }
        canvas.player.didSetPlayFrameRateHandler = { [unowned self] in
            if !self.canvas.player.isPause {
                self.playerView.playFrameRate = $0
            }
        }
        
        playerView.timeBinding = { [unowned self] in
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
        playerView.isPlayingBinding = { [unowned self] in
            if $0 {
                self.playerView.maxTime = self.scene.secondTime(withBeatTime: self.scene.duration)
                self.playerView.time = self.scene.secondTime(withBeatTime: self.scene.time)
                self.playerView.frameRate = self.scene.frameRate
                self.canvas.play()
            } else {
                self.playerView.time = self.scene.secondTime(withBeatTime: self.scene.time)
                self.playerView.frameRate = 0
                self.canvas.player.stop()
            }
        }
        
        soundView.setSoundHandler = { [unowned self] in
            self.scene.sound = $0.sound
            self.timeline.soundWaveformView.sound = $0.sound
            if $0.type == .end && $0.sound != $0.oldSound {
                self.sceneDataModel.isWrite = true
            }
            if self.scene.sound.url == nil && self.canvas.player.audioPlayer?.isPlaying ?? false {
                self.canvas.player.audioPlayer?.stop()
            }
        }
        
        updateWithScene()
        updateLayout()
    }
    
    private func updateLayout() {
        let padding = Layout.basicPadding
        let buttonH = Layout.basicHeight
        let h = buttonH + padding * 2
        
        let cs = SceneView.canvasSize, th = SceneView.timelineHeight
        let inWidth = cs.width + SceneView.propertyWidth * 1.65 + padding
        let width = inWidth + padding * 2
        let height = h * 3 + th + cs.height + padding * 4
        let y = height - padding
        versionView.frame.size = CGSize(width: SceneView.undoWidth, height: buttonH)
        rendererManager.popupBox.frame.size = CGSize(width: SceneView.rendererWidth,
                                                     height: buttonH)
        
        nameLabel.frame.origin = CGPoint(x: padding, y: y - h + padding * 2)
        let properties: [Layer] = [versionView, Padding(), rendererManager.popupBox, sizeView,
                                   frameRateSlider, Padding(),
                                   baseTimeIntervalSlider]
        properties.forEach { $0.frame.size.height = h }
        _ = Layout.leftAlignment(properties, minX: nameLabel.frame.maxX + padding,
                                 y: y - h, height: h)
        
        let previousNextFrame = CGRect(x: baseTimeIntervalSlider.frame.maxX,
                                       y: y - h,
                                       width: width - baseTimeIntervalSlider.frame.maxX - padding,
                                       height: h)
        Layout.autoHorizontalAlignment([isShownPreviousView, isShownNextView], in: previousNextFrame)
        
        let trw = transformView.defaultBounds.width, ww = wiggleView.defaultBounds.width
        let tew = Layout.valueWidth
        soundView.frame = CGRect(x: padding,
                                 y: y - h * 2 - padding,
                                 width: inWidth - trw - ww - tew - padding * 2, height: h)
        timeline.tempoSlider.frame = CGRect(x: soundView.frame.maxX + padding,
                                            y: y - h * 2 - padding,
                                            width: tew, height: h)
        transformView.frame = CGRect(x: timeline.tempoSlider.frame.maxX + padding,
                                     y: y - h * 2 - padding,
                                     width: trw, height: h)
        wiggleView.frame = CGRect(x: transformView.frame.maxX,
                                  y: y - h * 2 - padding,
                                  width: ww, height: h)
        
        let kh = 160.0.cf
        let propertyX = padding * 2 + cs.width, propertyMaxY = y - h - padding
        timeline.nodeView.frame = CGRect(x: propertyX,
                                         y: propertyMaxY - h * 2,
                                         width: SceneView.propertyWidth,
                                         height: h)
        timeline.keyframeView.frame = CGRect(x: propertyX,
                                             y: propertyMaxY - h * 2 - kh,
                                             width: SceneView.propertyWidth,
                                             height: kh)
        
        timeline.tempoKeyframeView.frame = CGRect(x: propertyX + SceneView.propertyWidth,
                                                  y: propertyMaxY - h * 5 - kh,
                                                  width: SceneView.propertyWidth * 0.65,
                                                  height: kh * 0.65)
        
        isHiddenSubtitlesView.frame = CGRect(x: propertyX + SceneView.propertyWidth,
                                             y: propertyMaxY - h * 6 - kh,
                                             width: SceneView.propertyWidth * 0.65, height: h)
        
        subtitleView.frame = CGRect(x: propertyX + SceneView.propertyWidth,
                                    y: propertyMaxY - h * 7 - kh,
                                    width: SceneView.propertyWidth * 0.65, height: h)
        
        let ch = canvas.cellView.defaultBounds.height
        let mh = canvas.materialView.defaultBounds.height
        
        shapeLinesBox.frame = CGRect(x: propertyX,
                                     y: propertyMaxY - h * 2 - buttonH - kh - padding,
                                     width: SceneView.propertyWidth,
                                     height: buttonH)
        changeToDraftBox.frame = CGRect(x: propertyX,
                                        y: propertyMaxY - h * 2 - buttonH * 2 - kh - padding,
                                        width: SceneView.propertyWidth,
                                        height: buttonH)
        removeDraftBox.frame = CGRect(x: propertyX,
                                      y: propertyMaxY - h * 2 - buttonH * 3 - kh - padding,
                                      width: SceneView.propertyWidth,
                                      height: buttonH)
        swapDraftBox.frame = CGRect(x: propertyX,
                                    y: propertyMaxY - h * 2 - buttonH * 4 - kh - padding,
                                    width: SceneView.propertyWidth,
                                    height: buttonH)
        
        let canvasPropertyMaxY = propertyMaxY - h * 2 - buttonH * 4 - kh - padding * 2
        canvas.cellView.frame = CGRect(x: propertyX,
                                       y: canvasPropertyMaxY - ch,
                                       width: SceneView.propertyWidth,
                                       height: ch)
        showAllBox.frame = CGRect(x: propertyX,
                                  y: canvasPropertyMaxY - ch - buttonH,
                                  width: SceneView.propertyWidth,
                                  height: buttonH)
        clipCellInSelectedBox.frame = CGRect(x: propertyX,
                                             y: canvasPropertyMaxY - ch - buttonH * 2,
                                             width: SceneView.propertyWidth,
                                             height: buttonH)
        
        canvas.materialView.frame = CGRect(x: propertyX,
                                           y: canvasPropertyMaxY - ch - buttonH * 2 - mh,
                                           width: SceneView.propertyWidth,
                                           height: mh)
        materialManager.animationBox.frame = CGRect(x: propertyX,
                                                    y: canvasPropertyMaxY - ch - mh - buttonH * 3,
                                                    width: SceneView.propertyWidth,
                                                    height: buttonH)
        splitColorBox.frame = CGRect(x: propertyX,
                                     y: canvasPropertyMaxY - ch - mh - buttonH * 4,
                                     width: SceneView.propertyWidth,
                                     height: buttonH)
        splitOtherThanColorBox.frame = CGRect(x: propertyX,
                                              y: canvasPropertyMaxY - ch - mh - buttonH * 5,
                                              width: SceneView.propertyWidth,
                                              height: buttonH)
        let eh = effectView.defaultBounds.height
        effectView.frame = CGRect(x: propertyX + SceneView.propertyWidth,
                                  y: y - h * 2 - padding - eh,
                                  width: SceneView.propertyWidth,
                                  height: eh)
        
        timeline.frame = CGRect(x: padding,
                                y: y - h * 2 - th - padding * 2,
                                width: cs.width, height: SceneView.timelineHeight)
        canvas.frame = CGRect(x: padding,
                              y: y - h * 2 - th - cs.height - padding * 2,
                              width: cs.width, height: cs.height)
        playerView.frame = CGRect(x: padding, y: padding, width: cs.width, height: h)
        
        let timeBindingPath = CGMutablePath()
        timeBindingPath.move(to: CGPoint(x: timeline.frame.midX, y: timeline.frame.maxY))
        timeBindingPath.addLine(to: CGPoint(x: timeline.frame.midX, y: transformView.frame.minY))
        timeline.nodeBindingLineLayer.path = timeBindingPath
        
        frame.size = CGSize(width: width, height: height)
    }
    private func updateWithScene() {
        scene.timeBinding = { [unowned self] (scene, time) in
            self.update(withTime: time)
        }
        update(withTime: scene.time)
        
        materialManager.scene = scene
        rendererManager.scene = scene
        timeline.scene = scene
        canvas.scene = scene
        sizeView.size = scene.frame.size
        frameRateSlider.value = scene.frameRate.cf
        baseTimeIntervalSlider.value = scene.baseTimeInterval.q.cf
        colorSpaceView.selectedIndex = scene.colorSpace == .sRGB ? 0 : 1
        isShownPreviousView.selectedIndex = scene.isShownPrevious ? 1 : 0
        isShownNextView.selectedIndex = scene.isShownNext ? 1 : 0
        isHiddenSubtitlesView.selectedIndex = scene.isHiddenSubtitles ? 0 : 1
        soundView.sound = scene.sound
        let sp = CGPoint(x: scene.frame.width, y: scene.frame.height)
        transformView.standardTranslation = sp
        wiggleView.standardAmplitude = sp
        if let effect = scene.editNode.editTrack.effectItem?.effect {
            effectView.effect = effect
        }
        if let transform = scene.editNode.editTrack.transformItem?.transform {
            transformView.transform = transform
        }
        if let wiggle = scene.editNode.editTrack.wiggleItem?.wiggle {
            wiggleView.wiggle = wiggle
        }
        subtitleView.subtitle = scene.editCut.subtitleTrack.subtitleItem.subtitle
        playerView.time = scene.secondTime(withBeatTime: scene.time)
        playerView.maxTime = scene.secondTime(withBeatTime: scene.duration)
    }
    
    func update(withTime time: Beat) {
        playerView.time = scene.secondTime(withBeatTime: time)
    }
    
    var time: Beat {
        get {
            return timeline.time
        }
        set {
            if newValue != time {
                timeline.time = newValue
                sceneDataModel.isWrite = true
                playerView.time = scene.secondTime(withBeatTime: newValue)
                canvas.updateEditCellBindingLine()
            }
        }
    }
    
    var rootUndoManager = UndoManager()
    override var undoManager: UndoManager? {
        return rootUndoManager
    }
    
    private func registerUndo(time: Beat, _ handler: @escaping (SceneView, Beat) -> Void) {
        undoManager?.registerUndo(withTarget: self) { [oldTime = self.time] in
            handler($0, oldTime)
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
        sceneDataModel.isWrite = true
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
        sceneDataModel.isWrite = true
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
        sceneDataModel.isWrite = true
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
        sceneDataModel.isWrite = true
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
        sceneDataModel.isWrite = true
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
        sceneDataModel.isWrite = true
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
        sceneDataModel.isWrite = true
    }
    private func set(_ wiggle: Wiggle, at index: Int,
                     in track: NodeTrack, in cutView: CutView) {
        track.replaceWiggle(wiggle, at: index)
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
        sceneDataModel.isWrite = true
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
        sceneDataModel.isWrite = true
    }
    
    private func setIsTranslucentLockInCell(with obj: CellView.Binding) {
        switch obj.type {
        case .begin:
            self.cutView = timeline.editCutView
        case .sending:
            canvas.setNeedsDisplay()
        case .end:
            guard let cutView = cutView else {
                return
            }
            if obj.isTranslucentLock != obj.oldIsTranslucentLock {
                set(isTranslucentLock: obj.isTranslucentLock,
                    oldIsTranslucentLock: obj.oldIsTranslucentLock,
                    in: obj.inCell, in: cutView, time: time)
            } else {
                canvas.setNeedsDisplay()
            }
        }
    }
    private func set(isTranslucentLock: Bool, oldIsTranslucentLock: Bool,
                     in cell: Cell, in cutView: CutView, time: Beat) {
        registerUndo(time: time) {
            $0.set(isTranslucentLock: oldIsTranslucentLock,
                   oldIsTranslucentLock: isTranslucentLock, in: cell, in: cutView, time: $1)
        }
        cell.isTranslucentLock = isTranslucentLock
        canvas.setNeedsDisplay()
        sceneDataModel.isWrite = true
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
        sceneDataModel.isWrite = true
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
        sceneDataModel.isWrite = true
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
        animationBox.deleteHandler = { [unowned self] _, _ in self.removeAnimation() }
        animationBox.newHandler = { [unowned self] _, _ in self.appendAnimation() }
    }
    
    var material: Material {
        get {
            return sceneView.canvas.materialView.material
        }
        set {
            scene.editMaterial = newValue
            sceneView.canvas.materialView.material = newValue
            sceneView.sceneDataModel.isWrite = true
            animationBox.label.localization = isAnimatedMaterial ?
                Localization(english: "Material Animation", japanese: "マテリアルアニメーションあり") :
                Localization(english: "None Material Animation", japanese: "マテリアルアニメーションなし")
            let x = animationBox.isLeftAlignment ?
                animationBox.leftPadding :
                round((animationBox.frame.width - animationBox.label.frame.width) / 2)
            let y = round((animationBox.frame.height - animationBox.label.frame.height) / 2)
            animationBox.label.frame.origin = CGPoint(x: x, y: y)
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
        let cutTuples: [CutTuple] = cuts.flatMap { cut in
            let cells = cut.cells.filter { $0.material.color == color }
            
            var materialItemTuples = [MaterialItemTuple]()
            for track in cut.editNode.tracks {
                for materialItem in track.materialItems {
                    let indexes = materialItem.keyMaterials.enumerated().flatMap {
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
            let cutTuples: [CutTuple] = cutTuples.flatMap { cutTuple in
                let cells = cutTuple.cells.filter { $0.material.id == material.id }
                let mts: [MaterialItemTuple] = cutTuple.materialItemTuples.flatMap { mit in
                    let indexes = mit.editIndexes.flatMap {
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
            let cutTuples: [CutTuple] = cuts.flatMap { cut in
                let cells = cut.cells.filter { $0.material.id == material.id }
                
                var materialItemTuples = [MaterialItemTuple]()
                for track in cut.editNode.tracks {
                    for materialItem in track.materialItems {
                        let indexes = useSelected ?
                            [track.animation.editKeyframeIndex] :
                            materialItem.keyMaterials.enumerated().flatMap {
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
        sceneView.sceneDataModel.isWrite = true
        if cut === sceneView.canvas.cut {
            sceneView.canvas.setNeedsDisplay()
        }
    }
    
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) -> Bool {
        for object in copiedObject.objects {
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
        sceneView.sceneDataModel.isWrite = true
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
    
    let animationBox = TextBox()
    
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
        sceneView.sceneDataModel.isWrite = true
    }
    private func remove(_ materialItem: MaterialItem, in track: NodeTrack, _ cut: Cut) {
        undoManager?.registerUndo(withTarget: self) { $0.append(materialItem, in: track, cut) }
        track.remove(materialItem)
        sceneView.sceneDataModel.isWrite = true
    }
}
