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

typealias BPM = Real
typealias FPS = Real
typealias FrameTime = Int
typealias BaseTime = Rational
typealias Beat = Rational
typealias RealBeat = Real
typealias RealBaseTime = Real
typealias Second = Real

/**
 Issue: シーンカラーを削減
 */
extension Color {
    static let strokeLine = Color(white: 0)
    
    static let draft = Color(red: 0, green: 0.5, blue: 1, alpha: 0.15)
    static let subDraft = Color(red: 0, green: 0.5, blue: 1, alpha: 0.1)
    static let timelineDraft = Color(red: 1, green: 1, blue: 0.2)
    
    static let previous = Color(red: 1, green: 0, blue: 0, alpha: 0.1)
    static let previousSkin = previous.with(alpha: 1)
    static let subPrevious = Color(red: 1, green: 0.2, blue: 0.2, alpha: 0.025)
    static let subPreviousSkin = subPrevious.with(alpha: 0.08)
    static let next = Color(red: 0.2, green: 0.8, blue: 0, alpha: 0.1)
    static let nextSkin = next.with(alpha: 1)
    static let subNext = Color(red: 0.4, green: 1, blue: 0, alpha: 0.025)
    static let subNextSkin = subNext.with(alpha: 0.08)
    
    static let snap = Color(red: 0.5, green: 0, blue: 1)
    static let controlEditPointIn = Color(red: 1, green: 1, blue: 0)
    static let controlPointIn = knob
    static let controlPointCapIn = knob
    static let controlPointJointIn = Color(red: 1, green: 0, blue: 0)
    static let controlPointOtherJointIn = Color(red: 1, green: 0.5, blue: 1)
    static let controlPointUnionIn = Color(red: 0, green: 1, blue: 0.2)
    static let controlPointPathIn = Color(red: 0, green: 1, blue: 1)
    static let controlPointOut = getSetBorder
    static let editControlPointIn = Color(red: 1, green: 0, blue: 0, alpha: 0.8)
    static let editControlPointOut = Color(red: 1, green: 0.5, blue: 0.5, alpha: 0.3)
    static let contolLineIn = Color(red: 1, green: 0.5, blue: 0.5, alpha: 0.3)
    static let contolLineOut = Color(red: 1, green: 0, blue: 0, alpha: 0.3)
    
    static let editMaterial = Color(red: 1, green: 0.5, blue: 0, alpha: 0.5)
    static let editMaterialColorOnly = Color(red: 1, green: 0.75, blue: 0, alpha: 0.5)
    
    static let camera = Color(red: 0.7, green: 0.6, blue: 0)
    static let cameraBorder = Color(red: 1, green: 0, blue: 0, alpha: 0.5)
    static let cutBorder = Color(red: 0.3, green: 0.46, blue: 0.7, alpha: 0.5)
    static let cutSubBorder = background.multiply(alpha: 0.5)
    
    static let playBorder = Color(white: 0.4)
    static let subtitleBorder = Color(white: 0)
    static let subtitleFill = white
}

/**
 Issue: 複数のサウンド
 Issue: 変更通知
 */
struct Scene: Codable {
    var name: Text
    var renderingVerticalResolution: Int
    var timeline: Timeline
    var isHiddenSubtitles: Bool
    var isHiddenPrevious: Bool, isHiddenNext: Bool
    var canvas: Canvas
    
    init(name: Text = Text(english: "Untitled", japanese: "名称未設定"),
         renderingVerticalResolution: Int = 1080,
         timeline: Timeline = Timeline(),
         isHiddenSubtitles: Bool = false,
         isHiddenPrevious: Bool = true, isHiddenNext: Bool = true,
         canvas: Canvas = Canvas()) {

        self.name = name
        self.renderingVerticalResolution = renderingVerticalResolution
        self.timeline = timeline
        self.isHiddenSubtitles = isHiddenSubtitles
        self.isHiddenPrevious = isHiddenPrevious
        self.isHiddenNext = isHiddenNext
        self.canvas = canvas
    }
    
    var duration: Beat {
        return timeline.duration
    }
    
    static let isEncodeLineKey = CodingUserInfoKey(rawValue: "isEncodeLineKey")!
    var diffData: Data? {
        let encoder = JSONEncoder()
        encoder.userInfo[Scene.isEncodeLineKey] = false
        return try? encoder.encode(self)
    }
}
extension Scene {
    static let renderingVerticalResolutionOption = IntOption(defaultModel: 1080,
                                                             minModel: 1, maxModel: 10000,
                                                             modelInterval: 1, exp: 1, unit: " p")
}
extension Scene: Referenceable {
    static let name = Text(english: "Scene", japanese: "シーン")
}

final class SceneBinder: BinderProtocol {
    var rootModel: Scene
    
    init(rootModel: Scene) {
        self.rootModel = rootModel
    }
    
    var scene: Scene
    var version: Version
    init(_ scene: Scene = Scene(), version: Version = Version()) {
        self.scene = scene
        self.version = version
        
        diffSceneDataModel = DataModel(key: diffSceneDataModelKey)
        dataModel = DataModel(key: dataModelKey,
                              directoryWith: [diffSceneDataModel, scene.cutTrack.diffDataModel])
        diffSceneDataModel.dataClosure = { [unowned self] in self.scene.diffData }
    }
    
    let dataModelKey = "scene"
    var dataModel: DataModel {
        didSet {
            if let dSceneDataModel = dataModel.children[diffSceneDataModelKey] {
                self.diffSceneDataModel = dSceneDataModel
            } else {
                dataModel.insert(diffSceneDataModel)
            }

            if let dCutTrackDataModel = dataModel.children[scene.cutTrack.diffDataModelKey] {
                scene.cutTrack.diffDataModel = dCutTrackDataModel
            } else {
                dataModel.insert(scene.cutTrack.diffDataModel)
            }

            updateWithScene()
        }
    }
    let diffSceneDataModelKey = "diffScene"
    var diffSceneDataModel: DataModel {
        didSet {
            if let scene = diffSceneDataModel.readObject(Scene.self) {
                self.scene = scene
            }
            diffSceneDataModel.dataClosure = { [unowned self] in self.scene.diffData }
        }
    }
}
struct NodeDiff: Codable {
    var trackDiffs = [UUID: MultipleTrackDiff]()
}
struct MultipleTrackDiff: Codable {
    var drawing = Drawing(), keyDrawings = [Drawing]()
    var cellDiffs = [UUID: CellDiff]()
}
struct CellDiff: Codable {
    var geometry = Geometry(), keyGeometries = [Geometry]()
}

final class SceneBinderView: View {
}

/**
 Issue: セルをキャンバス外にペースト
 Issue: Display P3サポート
 */
final class SceneView: View {
    var scene: Scene {
        get {
            return sceneBinder[keyPath: keyPath]
        }
        set {
            sceneBinder[keyPath: keyPath] = newValue
            updateWithScene()
        }
    }
    var sceneBinder: SceneBinder {
        didSet {
            versionView.version = sceneBinder.version
            updateWithScene()
        }
    }
    var keyPath: WritableKeyPath<SceneBinder, Scene> {
        didSet {
            updateWithScene()
        }
    }
    
    let versionView: VersionView<Binder>
    
    let sizeView = DiscreteSizeView(sizeType: .small)
    
    let renderingVerticalResolutionView
        = DiscreteIntView(model: 1, option: Scene.renderingVerticalResolutionOption,
                          frame: Layout.valueFrame(with: .small), sizeType: .small)
    let isHiddenSubtitlesView = BoolView(cationBool: true,
                                         name: Text(english: "Subtitles", japanese: "字幕"),
                                         boolInfo: BoolOption.Info.hidden, sizeType: .small)
    let isHiddenPreviousView = BoolView(defaultBool: true, cationBool: false,
                                        name: Text(english: "Previous", japanese: "前"),
                                        boolInfo: BoolOption.Info.hidden)
    let isHiddenNextView = BoolView(defaultBool: true, cationBool: false,
                                    name: Text(english: "Next", japanese: "次"),
                                    boolInfo: BoolOption.Info.hidden)
    let timelineView = TimelineView()
    let canvasView = CanvasView()
    let playManagerView = PlayManagerView()
    
    let exportSubtitlesView = ClosureView(name: Text(english: "Export Subtitles",
                                                     japanese: "字幕を書き出す"))
    let exportImageView = ClosureView(name: Text(english: "Export Image", japanese: "画像を書き出す"))
    let exportMovieView = ClosureView(name: Text(english: "Export Movie", japanese: "動画を書き出す"))
    
    static let versionWidth = 120.0.cg, propertyWidth = 200.0.cg
    static let canvasSize = Size(width: 730, height: 480), timelineHeight = 190.0.cg
    let classNameView = TextFormView(text: Scene.name, font: .bold)
    var rendingContentScale = 1.0.cg
    var renderQueue = OperationQueue()
    var bars = [ProgressNumberView]()
    private let progressWidth = 200.0.cg
    
    init(_ sceneBinder: SceneBinder, keyPath: WritableKeyPath<SceneBinder, Scene>) {
        self.sceneBinder = sceneBinder
        self.keyPath = keyPath
        
        versionView
        versionView.version = sceneBinder.version
        
        super.init()
        bounds = defaultBounds
        
        children = [classNameView, versionView,
                    sizeView, renderingVerticalResolutionView,
                    exportSubtitlesView, exportImageView, exportMovieView,
                    isHiddenSubtitlesView, isHiddenPreviousView, isHiddenNextView,
                    timelineView, canvasView, playManagerView]
        
//        sizeView.binding = { [unowned self] in
//            self.scene.frame = Rect(origin: Point(x: -$0.size.width / 2, y: -$0.size.height / 2),
//                                    size: $0.size)
////            self.canvasView.setNeedsDisplay()
//            let sp = Point(x: $0.size.width, y: $0.size.height)
//            self.transformView.standardTranslation = sp
//            self.wiggleXView.standardAmplitude = $0.size.width
//            self.wiggleYView.standardAmplitude = $0.size.height
//            if $0.phase == .ended && $0.size != $0.oldSize {
//                self.binder.diffSceneDataModel.isWrite = true
//            }
//        }

//        soundView.setSoundClosure = { [unowned self] in
//            self.scene.sound = $0.sound
//            self.timelineView.soundWaveformView.sound = $0.sound
//            if $0.phase == .ended && $0.sound != $0.oldSound {
//                self.diffSceneDataModel.isWrite = true
//            }
////            if self.scene.sound.url == nil && self.canvasView.playerView.audioPlayer?.isPlaying ?? false {
////                self.canvasView.playerView.audioPlayer?.stop()
////            }
//        }
        
//        timelineView.setSceneDurationClosure = { [unowned self] in
//            self.playManagerView.maxTime = self.scene.secondTime(withBeatTime: $1)
//        }
        
        exportSubtitlesView.model = { [unowned self] in self.exportSubtitles() }
        exportImageView.model = { [unowned self] in self.exportImage() }
        exportMovieView.model = { [unowned self] in self.exportMovie() }
        
        updateWithScene()
        updateLayout()
    }
    deinit {
        renderQueue.cancelAllOperations()
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
    override func updateLayout() {
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
        timelineView.baseTimeIntervalView.frame = Rect(x: topX, y: topY, width: tiw, height: buttonH)
        topX = classNameView.frame.maxX + padding
        versionView.frame = Rect(x: topX, y: y, width: SceneView.versionWidth, height: buttonH)
        
        var ty = y
        ty -= th
        timelineView.frame = Rect(x: padding, y: ty, width: cs.width, height: th)
        ty -= cs.height
        canvasView.frame = Rect(x: padding, y: ty, width: cs.width, height: cs.height)
        ty -= h
        playManagerView.frame = Rect(x: padding, y: ty, width: cs.width, height: h)
        
        let px = padding * 2 + cs.width, propertyMaxY = y
        var py = propertyMaxY
        let sh = Layout.smallHeight
        let sph = sh + Layout.smallPadding * 2
        py -= sph
        sizeView.frame = Rect(x: px, y: py, width: sizeView.defaultBounds.width, height: sph)
//        frameRateView.frame = Rect(x: sizeView.frame.maxX, y: py,
//                                   width: Layout.valueWidth(with: .small), height: sph)
        renderingVerticalResolutionView.frame
            = Rect(x: frameRateView.frame.maxX, y: py,
                                                     width: bounds.width - frameRateView.frame.maxX - padding,
                                                     height: sph)
        py -= sh
        isHiddenSubtitlesView.frame = Rect(x: px, y: py, width: pw / 2, height: sh)
    }
    private func updateWithScene() {
        renderingVerticalResolutionView.model = scene.renderingVerticalResolution
        isHiddenSubtitlesView.bool = scene.isHiddenSubtitles
        isHiddenPreviousView.bool = scene.isHiddenPrevious
        isHiddenNextView.bool = scene.isHiddenNext
    }
    
    func exportMovie() {
        let size = scene.canvas.frame.size, p = scene.renderingVerticalResolution
        let newSize = Size(width: floor((size.width * Real(p)) / size.height), height: Real(p))
        let sizeString = "w: \(Int(newSize.width)) px, h: \(Int(newSize.height)) px"
        let message = Text(english: "Export Movie(\(sizeString))",
                           japanese: "動画として書き出す(\(sizeString))")
        exportMovie(message: message, size: newSize)
    }
    func exportMovie(message: Text?, name: Text? = nil, size: Size,
                     videoType: VideoType = .mp4, codec: VideoCodec = .h264) {
        URL.file(message: message, name: nil, fileTypes: [videoType]) { [unowned self] e in
            let encoder = SceneVideoEncoder(scene: self.scene, size: size,
                                            videoType: videoType, codec: codec)
            let name = Text(e.url.deletingPathExtension().lastPathComponent)
            let type = Text(e.url.pathExtension.uppercased())
            let progressView = self.madeProgressNumberView(name: name, type: type)
            let operation = BlockOperation()
            progressView.operation = operation
            progressView.deleteClosure = { [unowned self] in self.endProgress($0) }
            self.beginProgress(progressView)
            
            operation.addExecutionBlock() { [unowned operation] in
                let progressClosure: (Real, inout Bool) -> () = { (totalProgress, stop) in
                    if operation.isCancelled {
                        stop = true
                    } else {
                        OperationQueue.main.addOperation() {
                            progressView.value = totalProgress
                        }
                    }
                }
                let completionClosure: (Error?) -> () = { error in
                    do {
                        if let error = error {
                            throw error
                        }
                        OperationQueue.main.addOperation() {
                            progressView.value = 1
                        }
                        try FileManager.default.setAttributes([.extensionHidden: e.isExtensionHidden],
                                                              ofItemAtPath: e.url.path)
                        OperationQueue.main.addOperation() {
                            self.endProgress(progressView)
                        }
                    } catch {
                        OperationQueue.main.addOperation() {
                            progressView.state = Text(english: "Error", japanese: "エラー")
                            progressView.nameView.textMaterial.color = .warning
                        }
                    }
                }
                do {
                    try encoder.writeVideo(to: e.url,
                                           progressClosure: progressClosure,
                                           completionClosure: completionClosure)
                } catch {
                    OperationQueue.main.addOperation() {
                        progressView.state = Text(english: "Error", japanese: "エラー")
                        progressView.nameView.textMaterial.color = .warning
                    }
                }
            }
            self.renderQueue.addOperation(operation)
        }
    }
    
    func exportImage() {
        let size = scene.canvas.frame.size, p = scene.renderingVerticalResolution
        let newSize = Size(width: floor((size.width * Real(p)) / size.height), height: Real(p))
        let sizeString = "w: \(Int(newSize.width)) px, h: \(Int(newSize.height)) px"
        let message = Text(english: "Export Image(\(sizeString))",
                           japanese: "画像として書き出す(\(sizeString))")
        exportImage(message: message, size: newSize)
    }
    func exportImage(message: Text?, size: Size, fileType: Image.FileType = .png) {
        URL.file(message: message, fileTypes: [fileType]) { [unowned self] e in
            let image = self.scene.canvas.image(with: size)
            do {
                try image?.write(fileType, to: e.url)
                try FileManager.default.setAttributes([.extensionHidden: e.isExtensionHidden],
                                                      ofItemAtPath: e.url.path)
            } catch {
                self.showError(withName: e.name)
            }
        }
    }
    
    func exportSubtitles(fileType: Subtitle.FileType = .vtt) {
        let message = Text(english: "Export Subtitles", japanese: "字幕として書き出す")
        URL.file(message: message, fileTypes: [fileType]) { [unowned self] e in
            let vttData = self.scene.timeline.vtt
            do {
                try vttData?.write(to: e.url)
                try FileManager.default.setAttributes([.extensionHidden: e.isExtensionHidden],
                                                      ofItemAtPath: e.url.path)
            } catch {
                self.showError(withName: e.name)
            }
        }
    }
    
    private func madeProgressNumberView(name: Text, type: Text) -> ProgressNumberView {
        return ProgressNumberView(frame: Rect(x: 0, y: 0,
                                              width: self.progressWidth, height: Layout.basicHeight),
                                  name: name, type: type,
                                  state: Text(english: "Exporting", japanese: "書き出し中"))
    }
    private func updateProgressPositions() {
        _ = bars.reduce(Point(x: frame.origin.x, y: frame.maxY)) {
            $1.frame.origin = $0
            return Point(x: $0.x + progressWidth, y: $0.y)
        }
    }
    private func beginProgress(_ progressNumberView: ProgressNumberView) {
        bars.append(progressNumberView)
        parent?.append(child: progressNumberView)
        progressNumberView.begin()
        updateProgressPositions()
    }
    private func endProgress(_ progressNumberView: ProgressNumberView) {
        progressNumberView.end()
        if let index = bars.index(where: { $0 === progressNumberView }) {
            bars[index].removeFromParent()
            bars.remove(at: index)
            updateProgressPositions()
        }
    }
    
    private func showError(withName name: Text) {
        let progressNumberView = ProgressNumberView()
        progressNumberView.name = name
        progressNumberView.state = Text(english: "Error", japanese: "エラー")
        progressNumberView.nameView.textMaterial.color = .warning
        progressNumberView.deleteClosure = { [unowned self] in self.endProgress($0) }
        beginProgress(progressNumberView)
    }
}
extension SceneView: Localizable {
    func update(with locale: Locale) {
        updateLayout()
    }
}
extension SceneView: Queryable {
    static let referenceableType: Referenceable.Type = Scene.self
}
extension SceneView: Versionable {
    var version: Version {
        return versionView.version
    }
}

final class ProgressNumberView: View {
    let barView = View(isLocked: true)
    let barBackgroundView = View(isLocked: true)
    let nameView: TextFormView
    let stopView = ClosureView(name: Text(english: "Stop", japanese: "中止"))

    init(frame: Rect = Rect(), backgroundColor: Color = .background,
         name: Text = "", type: Text = "", state: Text? = nil) {

        self.name = name
        self.type = type
        self.state = state
        nameView = TextFormView()
        nameView.frame.origin = Point(x: Layout.basicPadding,
                                      y: round((frame.height - nameView.frame.height) / 2))
        barView.frame = Rect(x: 0, y: 0, width: 0, height: frame.height)
        barBackgroundView.fillColor = .editing
        barView.fillColor = .content

        super.init()
        stopView.model = { [unowned self] in self.stop() }
        self.frame = frame
        isClipped = true
        children = [nameView, barBackgroundView, barView, stopView]
        updateLayout()
    }

    var value = 0.0.cg {
        didSet {
            updateLayout()
        }
    }
    func begin() {
        startDate = Date()
    }
    func end() {}
    var startDate: Date?
    var remainingTime: Real? {
        didSet {
            updateText()
        }
    }
    var computationTime = 5.0
    var name = Text() {
        didSet {
            updateText()
        }
    }
    var type = Text() {
        didSet {
            updateText()
        }
    }
    var state: Text? {
        didSet {
            updateText()
        }
    }

    override func updateLayout() {
        let padding = Layout.basicPadding
        let db = stopView.defaultBounds
        let w = bounds.width - db.width - padding
        stopView.frame = Rect(x: w, y: padding,
                              width: db.width, height: bounds.height - padding * 2)

        barBackgroundView.frame = Rect(x: padding, y: padding - 1,
                                       width: (w - padding * 2), height: 1)
        barView.frame = Rect(x: padding, y: padding - 1,
                             width: floor((w - padding * 2) * value), height: 1)
        updateText()
    }
    private func updateText() {
        var text = Text()
        if let state = state {
            text += state
        } else if let remainingTime = remainingTime {
            let minutes = Int(ceil(remainingTime)) / 60
            let seconds = Int(ceil(remainingTime)) - minutes * 60
            let ss = String(seconds)
            if minutes == 0 {
                let timeText = Text(english: String(format: "%@sec left", ss),
                                    japanese: String(format: "あと%@秒", ss))
                text += (text.isEmpty ? "" : " ") + timeText
            } else {
                let ms = String(minutes)
                let timeText = Text(english: String(format: "%@min %@sec left", ms, ss),
                                    japanese: String(format: "あと%@分%@秒", ms, ss))
                text += (text.isEmpty ? "" : " ") + timeText
            }
        }
        let t = text + (text.isEmpty ? "" : ", ") + Text("\(Int(value * 100)) %")
        nameView.text = type + "(" + name + "), " + t
        nameView.frame.origin = Point(x: Layout.basicPadding,
                                      y: round((frame.height - nameView.frame.height) / 2))
    }

    var deleteClosure: ((ProgressNumberView) -> ())?
    weak var operation: Operation?
    func stop() {
        if let operation = operation {
            operation.cancel()
        }
        deleteClosure?(self)
    }
}
extension ProgressNumberView: Localizable {
    func update(with locale: Locale) {
        updateLayout()
    }
}
extension ProgressNumberView: ViewQueryable {
    static let referenceableType: Referenceable.Type = Real.self
    static let viewDescription = Text(english: "Stop: Send \"Cut\" action",
                                      japanese: "停止: \"カット\"アクションを送信")
}

