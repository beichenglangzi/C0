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

/**
 Issue: シーンカラーを削減
 */
extension Color {
    static let snap = Color(red: 0.5, green: 0, blue: 1)
    static let controlEditPointIn = Color(red: 1, green: 1, blue: 0)
    static let controlPointIn = knob
    static let controlPointCapIn = knob
    static let controlPointJointIn = Color(red: 1, green: 0, blue: 0)
    static let controlPointOtherJointIn = Color(red: 1, green: 0.5, blue: 1)
    static let controlPointUnionIn = Color(red: 0, green: 1, blue: 0.2)
    static let controlPointPathIn = Color(red: 0, green: 1, blue: 1)
    static let controlPointOut = getSetBorder
    static let editControlPointIn = Color(red: 1, green: 0, blue: 0)
    static let editControlPointOut = Color(red: 1, green: 0.5, blue: 0.5)
    static let contolLineIn = Color(red: 1, green: 0.5, blue: 0.5)
    static let contolLineOut = Color(red: 1, green: 0, blue: 0)
}

struct ColorMap: Codable {
    var color: Color
}

struct Scene: Codable {
    var timeline: Timeline
    var canvas: Canvas
    var colors: [ColorMap]
    var player: Player
    var renderingVerticalResolution: Int
    
    init(timeline: Timeline = Timeline(),
         colors: [ColorMap] = [],
         canvas: Canvas = Canvas(),
         player: Player = Player(),
         renderingVerticalResolution: Int = 1080) {

        self.timeline = timeline
        self.canvas = canvas
        self.colors = colors
        self.player = player
        self.renderingVerticalResolution = renderingVerticalResolution
    }
}
extension Scene {
    var duration: Rational {
        return timeline.duration
    }
    
    func canvas(atTime time: Rational) -> Canvas {
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
    func thumbnailView(withFrame frame: Rect) -> View {
        return timeline.duration.thumbnailView(withFrame: frame)
    }
}
extension Scene: AbstractViewable {
    var defaultAbstractConstraintSize: Size {
        return canvas.defaultAbstractConstraintSize + timeline.defaultAbstractConstraintSize
    }
    func abstractViewWith<T : BinderProtocol>(binder: T,
                                              keyPath: ReferenceWritableKeyPath<T, Scene>,
                                              type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return SceneView(binder: binder, keyPath: keyPath)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath)
        }
    }
}
extension Scene: ObjectViewable {}

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
    
    let sizeView: DiscreteSizeView<Binder>
    let renderingVerticalResolutionView: DiscreteIntView<Binder>
    let timelineView: TimelineView<Binder>
    let canvasView: CanvasView<Binder>
    let playerView: ScenePlayerView<Binder>
    let exportImageView = ClosureView(name: Text(english: "Export Image", japanese: "画像を書き出す"))
    let exportMovieView = ClosureView(name: Text(english: "Export Movie", japanese: "動画を書き出す"))
    
    var encodingQueue = OperationQueue()
    var encoderViews = [View]()
    private let encoderWidth = 200.0.cg
    var timelineHeight = 70.0.cg
    
    var previousColor = Color(red: 1, green: 0, blue: 0)
    var nextColor = Color(red: 0.2, green: 0.8, blue: 0)
    
    init(binder: Binder, keyPath: BinderKeyPath, frame: Rect = Rect()) {
        self.binder = binder
        self.keyPath = keyPath
        
        let defaultSize = binder[keyPath: keyPath].canvas.frame.size
        let sizeWidthOption = RealOption(defaultModel: defaultSize.width,
                                         minModel: 1, maxModel: 100000, modelInterval: 1, exp: 1,
                                         numberOfDigits: 0, unit: "")
        let sizeHeightOption = RealOption(defaultModel: defaultSize.height,
                                         minModel: 1, maxModel: 100000, modelInterval: 1, exp: 1,
                                         numberOfDigits: 0, unit: "")
        sizeView = DiscreteSizeView(binder: binder,
                                    keyPath: keyPath.appending(path: \Scene.canvas.centeringSize),
                                    option: SizeOption(xOption: sizeWidthOption,
                                                       yOption: sizeHeightOption))
        
        renderingVerticalResolutionView
            = DiscreteIntView(binder: binder,
                              keyPath: keyPath.appending(path: \Scene.renderingVerticalResolution),
                              option: Scene.renderingVerticalResolutionOption)
        timelineView = TimelineView(binder: binder,
                                    keyPath: keyPath.appending(path: \Model.timeline))
        canvasView = CanvasView(binder: binder,
                                keyPath: keyPath.appending(path: \Model.canvas))
        playerView = ScenePlayerView(binder: binder,
                                     keyPath: keyPath.appending(path: \Model.player),
                                     sceneKeyPath: keyPath)
        
        super.init(isLocked: false)
        sizeView.notifications.append { [unowned self] (view, notification) in
            self.canvasView.updateCanvasSize()
        }
        timelineView.notifications.append { [unowned self] (view, notification) in
            let drawingView = DrawingView(binder: self.binder,
                                          keyPath: self.keyPath.appending(path: \Model.timeline.editingDrawing))
            self.canvasView.contentsViews = [drawingView]
        }
        children = [timelineView, canvasView]
        
        exportImageView.model = { [unowned self] _ in self.exportImage() }
        exportMovieView.model = { [unowned self] _ in self.exportMovie() }
        
        let drawingView = DrawingView(binder: self.binder,
                                      keyPath: self.keyPath.appending(path: \Model.timeline.editingDrawing))
        self.canvasView.contentsViews = [drawingView]
        
        updateWithModel()
        updateLayout()
    }
    deinit {
        encodingQueue.cancelAllOperations()
    }
    
    var minSize: Size {
        let padding = Layouter.basicPadding, buttonH = Layouter.basicHeight
        let cs = canvasView.minSize, th = timelineHeight
        let inWidth = cs.width
        let width = inWidth + padding * 2
        let height = th + cs.height + buttonH + padding * 2
        return Size(width: width, height: height)
    }
    override func updateLayout() {
        let padding = Layouter.basicPadding, buttonH = Layouter.basicHeight
        let h = buttonH + padding * 2
        let th = timelineHeight
        let y = bounds.height - padding
        let cs = Size(width: bounds.width - padding * 2,
                      height: bounds.height - th - padding * 2)
        
//        var topX = bounds.width - padding
//        let eiw = exportImageView.minSize.width
//        topX -= eiw
//        exportImageView.frame = Rect(x: topX, y: y, width: eiw, height: buttonH)
//        let emw = exportMovieView.minSize.width
//        topX -= emw
//        exportMovieView.frame = Rect(x: topX, y: y, width: emw, height: buttonH)
//        let rvrms = renderingVerticalResolutionView.minSize
//        topX -= rvrms.width
//        renderingVerticalResolutionView.frame = Rect(origin: Point(x: topX, y: y), size: rvrms)
//        let sms = sizeView.minSize
//        topX -= sms.width
//        sizeView.frame = Rect(x: topX, y: y, width: sms.width, height: sms.height)
        
        var ty = y
        ty -= th
        timelineView.frame = Rect(x: padding, y: ty, width: cs.width, height: th)
        ty -= cs.height
        canvasView.frame = Rect(x: padding, y: ty, width: cs.width, height: cs.height)
        ty -= h
        playerView.frame = Rect(x: canvasView.frame.maxX, y: padding,
                                width: bounds.width - canvasView.frame.maxX - padding, height: 100)
    }
}
extension SceneView {
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
}
