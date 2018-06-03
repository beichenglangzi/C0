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

import struct Foundation.URL
import class Foundation.OperationQueue

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
    
    static let subtitleBorder = Color(white: 0)
    static let subtitleFill = white
}

struct CellgroupIndex: Codable {
    var index: Int, cellIndexes: [Int]
}
struct MaterialMap: Codable {
    var material: Material
    var cellNodeIndexes: [CellgroupIndex]
}
struct ColorMap: Codable {
    var color: Color
    var cellNodeIndexes: [CellgroupIndex]
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
    var materials: [MaterialMap]
    var colors: [ColorMap]
    var player: Player
    var version = Version()
    
    init(name: Text = Text(english: "Untitled", japanese: "名称未設定"),
         renderingVerticalResolution: Int = 1080,
         timeline: Timeline = Timeline(),
         isHiddenSubtitles: Bool = false,
         isHiddenPrevious: Bool = true, isHiddenNext: Bool = true,
         materials: [MaterialMap] = [],
         colors: [ColorMap] = [],
         canvas: Canvas = Canvas(),
         player: Player = Player()) {

        self.name = name
        self.renderingVerticalResolution = renderingVerticalResolution
        self.timeline = timeline
        self.isHiddenSubtitles = isHiddenSubtitles
        self.isHiddenPrevious = isHiddenPrevious
        self.isHiddenNext = isHiddenNext
        self.canvas = canvas
        self.materials = materials
        self.colors = colors
        self.player = player
    }
}
extension Scene {
    var duration: Beat {
        return timeline.duration
    }
    
    func canvas(atTime time: Beat) -> Canvas {
        fatalError()
    }
}
extension Scene {
    static let renderingVerticalResolutionOption = IntOption(defaultModel: 1080,
                                                             minModel: 1, maxModel: 10000,
                                                             modelInterval: 1, exp: 1, unit: " p")
    static let isHiddenSubtitlesOption
        = BoolOption(defaultModel: false, cationModel: true,
                     name: Text(english: "Subtitles", japanese: "字幕"),
                     info: .hidden)
    static let isHiddenPreviousOption = BoolOption(defaultModel: true, cationModel: false,
                                                   name: Text(english: "Previous", japanese: "前"),
                                                   info: .hidden)
    static let isHiddenNextOption = BoolOption(defaultModel: true, cationModel: false,
                                               name: Text(english: "Next", japanese: "次"),
                                               info: .hidden)
}
extension Scene: Referenceable {
    static let name = Text(english: "Scene", japanese: "シーン")
}
extension Scene: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return name.thumbnailView(withFrame: frame, sizeType)
    }
}
extension Scene: AbstractViewable {
    func abstractViewWith<T : BinderProtocol>(binder: T,
                                              keyPath: ReferenceWritableKeyPath<T, Scene>,
                                              frame: Rect, _ sizeType: SizeType,
                                              type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return SceneView(binder: binder, keyPath: keyPath, frame: frame, sizeType: sizeType)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath, frame: frame, sizeType)
        }
    }
}
extension Scene: ObjectViewable {}

struct SceneLayout {
    static let versionWidth = 120.0.cg, propertyWidth = 200.0.cg
    static let canvasSize = Size(width: 730, height: 480), timelineHeight = 190.0.cg
}

/**
 Issue: セルをキャンバス外にペースト
 Issue: Display P3サポート
 */
final class SceneView<T: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = Scene
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((SceneView<Binder>, BasicNotification) -> ())]()
    
    var defaultModel: Model {
        return Model()
    }
    
    let versionView: VersionView<Binder>
    
    let sizeView: DiscreteSizeView<Binder>
    let renderingVerticalResolutionView: DiscreteIntView<Binder>
    let isHiddenSubtitlesView: BoolView<Binder>
    let isHiddenPreviousView: BoolView<Binder>
    let isHiddenNextView: BoolView<Binder>
    let timelineView: TimelineView<Binder>
    let canvasView: CanvasView<Binder>
    let playerView: ScenePlayerView<Binder>
    
    let exportSubtitlesView = ClosureView(name: Text(english: "Export Subtitles",
                                                     japanese: "字幕を書き出す"))
    let exportImageView = ClosureView(name: Text(english: "Export Image", japanese: "画像を書き出す"))
    let exportMovieView = ClosureView(name: Text(english: "Export Movie", japanese: "動画を書き出す"))
    
    let classNameView = TextFormView(text: Scene.name, font: .bold)
    var encodingQueue = OperationQueue()
    var encoderViews = [View]()
    private let encoderWidth = 200.0.cg
    
    init(binder: Binder, keyPath: BinderKeyPath,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        versionView = VersionView(binder: binder, keyPath: keyPath.appending(path: \Model.version))
        
        let defaultSize = binder[keyPath: keyPath].canvas.frame.size
        let sizeWidthOption = RealOption(defaultModel: defaultSize.width,
                                         minModel: 1, maxModel: 100000, modelInterval: 1, exp: 1,
                                         numberOfDigits: 0, unit: "")
        let sizeHeightOption = RealOption(defaultModel: defaultSize.height,
                                         minModel: 1, maxModel: 100000, modelInterval: 1, exp: 1,
                                         numberOfDigits: 0, unit: "")
        sizeView = DiscreteSizeView(binder: binder,
                                    keyPath: keyPath.appending(path: \Scene.canvas.frame.size),
                                    option: SizeOption(xOption: sizeWidthOption,
                                                       yOption: sizeHeightOption),
                                    sizeType: .small)
        
        renderingVerticalResolutionView
            = DiscreteIntView(binder: binder,
                              keyPath: keyPath.appending(path: \Scene.renderingVerticalResolution),
                              option: Scene.renderingVerticalResolutionOption,
                              frame: Layouter.valueFrame(with: .small), sizeType: .small)
        isHiddenSubtitlesView = BoolView(binder: binder,
                                         keyPath: keyPath.appending(path: \Scene.isHiddenSubtitles),
                                         option: Scene.isHiddenSubtitlesOption, sizeType: .small)
        isHiddenPreviousView = BoolView(binder: binder,
                                        keyPath: keyPath.appending(path: \Scene.isHiddenPrevious),
                                        option: Scene.isHiddenPreviousOption)
        isHiddenNextView = BoolView(binder: binder,
                                    keyPath: keyPath.appending(path: \Scene.isHiddenNext),
                                    option: Scene.isHiddenNextOption)
        timelineView = TimelineView(binder: binder,
                                    keyPath: keyPath.appending(path: \Model.timeline),
                                    sizeType: sizeType)
        canvasView = CanvasView(binder: binder,
                                keyPath: keyPath.appending(path: \Model.canvas),
                                sizeType: sizeType)
        playerView = ScenePlayerView(binder: binder,
                                     keyPath: keyPath.appending(path: \Model.player),
                                     sceneKeyPath: keyPath, sizeType: sizeType)
        
        super.init()
        bounds = defaultBounds
        
        children = [classNameView, versionView,
                    sizeView, renderingVerticalResolutionView,
                    exportSubtitlesView, exportImageView, exportMovieView,
                    isHiddenSubtitlesView, isHiddenPreviousView, isHiddenNextView,
                    timelineView, canvasView, playerView]
        
        exportSubtitlesView.model = { [unowned self] _ in self.exportSubtitles() }
        exportImageView.model = { [unowned self] _ in self.exportImage() }
        exportMovieView.model = { [unowned self] _ in self.exportMovie() }
        
        updateWithModel()
        updateLayout()
    }
    deinit {
        encodingQueue.cancelAllOperations()
    }
    
    override var defaultBounds: Rect {
        return Rect(x: 0, y: 0, width: 50, height: 50)
        
//        let padding = Layout.basicPadding, buttonH = Layout.basicHeight
//        let h = buttonH + padding * 2
//        let cs = SceneLayout.canvasSize, th = SceneLayout.timelineHeight
//        let inWidth = cs.width + padding + SceneLayout.propertyWidth
//        let width = inWidth + padding * 2
//        let height = th + cs.height + h + buttonH + padding * 2
//        return Rect(x: 0, y: 0, width: width, height: height)
    }
    override func updateLayout() {
        let padding = Layouter.basicPadding, buttonH = Layouter.basicHeight
        let h = buttonH + padding * 2
        let cs = SceneLayout.canvasSize, th = SceneLayout.timelineHeight
        let pw = SceneLayout.propertyWidth
        let y = bounds.height - buttonH - padding
        
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
        let tiw = Layouter.valueWidth(with: .regular)
        topX -= tiw
        timelineView.baseTimeIntervalView.frame = Rect(x: topX, y: topY, width: tiw, height: buttonH)
        topX = classNameView.frame.maxX + padding
        versionView.frame = Rect(x: topX, y: y, width: SceneLayout.versionWidth, height: buttonH)
        
        var ty = y
        ty -= th
        timelineView.frame = Rect(x: padding, y: ty, width: cs.width, height: th)
        ty -= cs.height
        canvasView.frame = Rect(x: padding, y: ty, width: cs.width, height: cs.height)
        ty -= h
        playerView.frame = Rect(x: padding, y: ty, width: cs.width, height: h)
        
        let px = padding * 2 + cs.width, propertyMaxY = y
        var py = propertyMaxY
        let sh = Layouter.smallHeight
        let sph = sh + Layouter.smallPadding * 2
        py -= sph
        sizeView.frame = Rect(x: px, y: py, width: sizeView.defaultBounds.width, height: sph)
        py -= sh
        isHiddenSubtitlesView.frame = Rect(x: px, y: py, width: pw / 2, height: sh)
    }
    func updateWithModel() {
        renderingVerticalResolutionView.updateWithModel()
        isHiddenSubtitlesView.updateWithModel()
        isHiddenPreviousView.updateWithModel()
        isHiddenNextView.updateWithModel()
    }
    
    private func updateEncoderPositions() {
        _ = encoderViews.reduce(Point(x: frame.origin.x, y: frame.maxY)) {
            $1.frame.origin = $0
            return Point(x: $0.x + encoderWidth, y: $0.y)
        }
    }
    private func beganEncode<T: MediaEncoder>(_ view: MediaEncoderView<T>, to file: URL.File) {
        view.stoppedClosure = { [unowned self] in self.endedEncode($0) }
        view.endedClosure = { [unowned self] in self.endedEncode($0) }
        encoderViews.append(view)
        parent?.append(child: view)
        updateEncoderPositions()
        encodingQueue.addOperation(view.write(to: file))
    }
    private func endedEncode<T: MediaEncoder>(_ view: MediaEncoderView<T>) {
        if let index = encoderViews.index(of: view) {
            encoderViews.remove(at: index)
        }
        view.removeFromParent()
        updateEncoderPositions()
    }
    
    func exportMovie() {
        let size = model.canvas.frame.size, p = model.renderingVerticalResolution
        let newSize = Size(width: ((size.width * Real(p)) / size.height).rounded(.down),
                           height: Real(p))
        let sizeString = "w: \(Int(newSize.width)) px, h: \(Int(newSize.height)) px"
        let message = Text(english: "Export Movie(\(sizeString))",
                           japanese: "動画として書き出す(\(sizeString))")
        exportMovie(message: message, size: newSize)
    }
    func exportMovie(message: Text?, name: Text? = nil, size: Size,
                     videoType: VideoType = .mp4, codec: VideoCodec = .h264) {
        URL.file(message: message, name: nil, fileTypes: [videoType]) { [unowned self] file in
            let encoder = SceneVideoEncoder(scene: self.model, size: size,
                                            videoType: videoType, codec: codec)
            self.beganEncode(SceneVideoEncoderView(encoder: encoder), to: file)
        }
    }
    
    func exportImage() {
        let size = model.canvas.frame.size, p = model.renderingVerticalResolution
        let newSize = Size(width: ((size.width * Real(p)) / size.height).rounded(.down),
                           height: Real(p))
        let sizeString = "w: \(Int(newSize.width)) px, h: \(Int(newSize.height)) px"
        let message = Text(english: "Export Image(\(sizeString))",
                           japanese: "画像として書き出す(\(sizeString))")
        exportImage(message: message, size: newSize)
    }
    func exportImage(message: Text?, size: Size, fileType: Image.FileType = .png) {
        URL.file(message: message, fileTypes: [fileType]) { [unowned self] file in
            let encoder = SceneImageEncoder(canvas: self.model.canvas,
                                            size: size, fileType: fileType)
            self.beganEncode(SceneImageEncoderView(encoder: encoder), to: file)
        }
    }
    
    func exportSubtitles() {
        let message = Text(english: "Export Subtitles", japanese: "字幕として書き出す")
        exportSubtitles(message: message)
    }
    func exportSubtitles(message: Text?, fileType: Subtitle.FileType = .vtt) {
        URL.file(message: message, fileTypes: [fileType]) { [unowned self] file in
            let encoder = SceneSubtitlesEncoder(timeline: self.model.timeline, fileType: fileType)
            self.beganEncode(SceneSubtitlesEncoderView(encoder: encoder), to: file)
        }
    }
}
extension SceneView: Undoable {
    var version: Version {
        return versionView.model
    }
}
