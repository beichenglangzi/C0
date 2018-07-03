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

struct Scene: Codable {
    var bounds = Rect(x: -288, y: -162, width: 576, height: 324)
    var z = 0.0.cg
    var editingTime = Rational(0)
    var animation = Animation<Drafting<Drawing>>()
    
    var frameRate = 60.0.cg
    var baseTimeInterval = Rational(1, 60)
}
extension Scene {
    static let padding = 50.0.cg
    var paddingBounds: Rect {
        get { return bounds.inset(by: -Scene.padding) }
        set { bounds = newValue.inset(by: Scene.padding) }
    }
    
    func time(withFrameTime frameTime: Int) -> Rational {
        if let intFrameRate = Int(exactly: frameRate) {
            return Rational(frameTime, intFrameRate)
        } else {
            return Rational(Real(frameTime) / frameRate)
        }
    }
    func time(withFrameTime frameTime: Int) -> Real {
        return Real(frameTime) / frameRate
    }
    func frameTime(withTime time: Rational) -> Int {
        return Int(Real(time) * frameRate)
    }
    func frameTime(withTime time: Real) -> Int {
        return Int(time * frameRate)
    }
    
    func time(withBaseTime baseTime: Rational) -> Rational {
        return baseTime * baseTimeInterval
    }
    func baseTime(withTime time: Rational) -> Rational {
        return time / baseTimeInterval
    }
    func basedTime(withTime time: Real) -> Rational {
        return Rational(Int(time / Real(baseTimeInterval))) * baseTimeInterval
    }
    func basedTime(withRealBaseTime realBaseTime: Real) -> Rational {
        return Rational(Int(realBaseTime)) * baseTimeInterval
    }
    func realBaseTime(withTime time: Rational) -> Real {
        return Real(time / baseTimeInterval)
    }
    func clipDeltaTime(withTime time: Rational) -> Rational {
        let ft = baseTime(withTime: time)
        let fft = ft + Rational(1, 2)
        return fft - floor(fft) < Rational(1, 2) ?
            self.time(withBaseTime: ceil(ft)) - time :
            self.time(withBaseTime: floor(ft)) - time
    }
    
    var time: (second: Int, frame: Int) {
        let second = Real(editingTime)
        let frameTime = Int(second * frameRate)
        return (Int(second), frameTime - Int(second * frameRate))
    }
    func time(with frameTime: Int) -> (second: Int, frame: Int) {
        let second = Int(Real(frameTime) / frameRate)
        return (second, frameTime - second)
    }
    static func timeString(withSecound i: Int) -> String {
        let minute = i / 60
        let second = i - minute * 60
        return second < 0 ?
            String(format: "-%d:%02d", minute, -second) :
            String(format: "%d:%02d", minute, second)
    }
}
extension Scene {
    static let zOption = RealOption(minModel: -30, maxModel: 0,
                                    modelInterval: 0.01, numberOfDigits: 2)
}
extension Scene: Referenceable {
    static let name = Text(english: "Scene", japanese: "シーン")
}
extension Scene: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect) -> View {
        return animation.duration.thumbnailView(withFrame: frame)
    }
}
extension Scene: Viewable {
    func standardViewWith<T: BinderProtocol>
        (binder: T, keyPath: ReferenceWritableKeyPath<T, Scene>) -> ModelView {
    
        return SceneView(binder: binder, keyPath: keyPath)
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
    
    let boundsView: RectView<Binder>
    let zView: DiscreteRealView<Binder>
    let editingTimeView: IntervalRationalView<Binder>
    let animationView: AnimationView<Drafting<Drawing>, Binder>
    let editingDraftingView: DraftingView<Drawing, Binder> 
    
    let transformFormView: View
    let canvasBorderView = View()
    let canvasSubBorderView = View()
    let timeView: View = {
        let view = View()
        view.fillColor = .editing
        view.lineColor = nil
        return view
    } ()
    let intTimesView = View(path: Path())
    
    init(binder: Binder, keyPath: BinderKeyPath, frame: Rect = Rect()) {
        self.binder = binder
        self.keyPath = keyPath
        
        boundsView = RectView(binder: binder,
                              keyPath: keyPath.appending(path: \Model.bounds))
        zView = DiscreteRealView(binder: binder, keyPath: keyPath.appending(path: \Model.z),
                                 option: Scene.zOption)
        
        let duration = binder[keyPath: keyPath].animation.duration
        editingTimeView
            = IntervalRationalView(binder: binder,
                                   keyPath: keyPath.appending(path: \Model.editingTime),
                                   option: RationalOption(minModel: 0, maxModel: duration,
                                                          isInfinitesimal: false),
                                   intervalOption: IntervalRationalOption(intervalModel: 1))
        animationView = AnimationView(binder: binder,
                                      keyPath: keyPath.appending(path: \Model.animation))
        editingDraftingView = DraftingView(binder: self.binder,
                                           keyPath: self.keyPath.appending(path: \Model.animation.editingKeyframe.value))
        transformFormView = View()
        
        super.init(isLocked: false)
//        boundsView.notifications.append { [unowned self] (view, notification) in
//            self.updateLayout()
//        }
//        timelineView.notifications.append { [unowned self] (view, notification) in
//            let drawingView = DrawingView(binder: self.binder,
//                                          keyPath: self.keyPath.appending(path: \Model.timeline.editingDrawing))
//            self.canvasView.contentsViews = [drawingView]
//        }
        zView.notifications.append { [unowned self] (view, notification) in
            self.transformFormView.transform.z = view.model
//            self.canvasView.updateTransform()
        }
        
        transformFormView.children = [editingDraftingView]
        children = [boundsView, zView, editingTimeView, animationView, transformFormView]
        
        updateWithModel()
    }
    
    var minSize: Size {
        let padding = Layouter.basicPadding, h = Layouter.basicHeight
        let size = model.paddingBounds.size
        return Size(width: size.width + padding * 2, height: size.height + h * 2 + padding * 2)
    }
    override func updateLayout() {
        let padding = Layouter.basicPadding, h = Layouter.basicHeight

        let colorsHeight = 100 + padding * 2
        let y = bounds.height - padding
        let cs = Size(width: bounds.width - padding * 2,
                      height: bounds.height - h - padding * 2 - colorsHeight)
        
        var ty = y
        zView.frame = Rect(x: padding, y: ty,
                           width: zView.minSize.width, height: h)
        
        editingTimeView.frame = Rect(x: zView.frame.maxX, y: padding + h,
                                     width: bounds.width - zView.bounds.width, height: h)
//        timeView.frame = Rect(x: padding, y: padding + h,
//                              width: baseWidth, height: bounds.height - sp * 2)
    }
    private func updateTransform() {
        var transform = transformFormView.transform
        let objectsPosition = Point(x: (bounds.width / 2).rounded(),
                                    y: (bounds.height / 2).rounded())
        transform.translation += objectsPosition
        transformFormView.transform = transform
    }
}
//extension SceneView: Exportable {
//    func export(withZ z: Real) -> BlockOperation {
//        contentsScale * z
//        if model.animation.isEmpty {
//            exportMovie()
//        } else {
//
//        }
//        //        isClosedAnimations
//    }
//
//    func exportMovie() {
//        let size = model.canvas.frame.size, p = model.renderingVerticalResolution
//        let newSize = Size(width: ((size.width * Real(p)) / size.height).rounded(.down),
//                           height: Real(p))
//        let sizeString = "w: \(Int(newSize.width)) px, h: \(Int(newSize.height)) px"
//        let message = Text(english: "Export Movie(\(sizeString))",
//            japanese: "動画として書き出す(\(sizeString))")
//        exportMovie(message: message, size: newSize)
//    }
//    func exportMovie(message: Text?, name: Text? = nil, size: Size,
//                     videoType: VideoType = .mp4, codec: VideoCodec = .h264) {
//        URL.file(message: message, name: nil, fileTypes: [videoType]) { [unowned self] file in
//            let encoder = SceneVideoEncoder(scene: self.model, size: size,
//                                            videoType: videoType, codec: codec)
//            let view = SceneVideoEncoderView(encoder: encoder)
//            encodingQueue.addOperation(view.write(to: file))
//        }
//    }
//
//    func exportImage() {
//        let size = model.canvas.frame.size, p = model.renderingVerticalResolution
//        let newSize = Size(width: ((size.width * Real(p)) / size.height).rounded(.down),
//                           height: Real(p))
//        let sizeString = "w: \(Int(newSize.width)) px, h: \(Int(newSize.height)) px"
//        let message = Text(english: "Export Image(\(sizeString))",
//            japanese: "画像として書き出す(\(sizeString))")
//        exportImage(message: message, size: newSize)
//    }
//    func exportImage(message: Text?, size: Size, fileType: Image.FileType = .png) {
//        URL.file(message: message, fileTypes: [fileType]) { [unowned self] file in
//            let encoder = SceneImageEncoder(canvas: self.model.canvas,
//                                            size: size, fileType: fileType)
//            self.beganEncode(SceneImageEncoderView(encoder: encoder), to: file)
//            encodingQueue.addOperation(view.write(to: file))
//        }
//    }
//}
