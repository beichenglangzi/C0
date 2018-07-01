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

struct Parper: Codable {
    var frame: Rect
    var centeringSize: Size {
        get { return frame.size }
        set {
            frame = Rect(origin: Point(x: -(newValue.width / 2).rounded(),
                                       y: -(newValue.height / 2).rounded()),
                         size: newValue)
        }
    }
    var transform: Transform
    
    init(frame: Rect = Rect(x: -288, y: -162, width: 576, height: 324),
         transform: Transform = Transform()) {
        
        self.frame = frame
        self.transform = transform
    }
}
extension Parper {
    func view() -> View {
        return View()
    }
}
extension Parper: Referenceable {
    static let name = Text(english: "Parper", japanese: "ペーパー")
}
extension Parper: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect) -> View {
        return View(frame: frame)
    }
}
extension Parper: AbstractViewable {
    var defaultAbstractConstraintSize: Size {
        return Size(width: 600, height: 400)
    }
    func abstractViewWith<T : BinderProtocol>(binder: T,
                                              keyPath: ReferenceWritableKeyPath<T, Parper>,
                                              type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return CanvasView(binder: binder, keyPath: keyPath)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath)
        }
    }
}
extension Parper: ObjectViewable {}

final class CanvasView<T: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = Parper
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((CanvasView<Binder>, BasicNotification) -> ())]()
    
    var defaultModel = Model()
    
    let rootView = View()
    var contentsViews: [View & Strokable] {
        get { return rootView.children as? [View & Strokable] ?? [] }
        set { rootView.children = [canvasBorderView, canvasSubBorderView] + newValue }
    }
    let canvasBorderView = View()
    let canvasSubBorderView = View()
    let transformView: BasicTransformView<Binder>
    
    init(binder: T, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        transformView = BasicTransformView(binder: binder,
                                           keyPath: keyPath.appending(path: \Model.transform),
                                           option: TransformOption())
        
        super.init(isLocked: false)
        isClipped = true
        
//        canvasBorderView.lineColor = Color(red: 0.3, green: 0.46, blue: 0.7, alpha: 0.5)
//        canvasSubBorderView.lineColor = Color.background.multiply(alpha: 0.5)
        rootView.children = [canvasBorderView, canvasSubBorderView]
        children = [model.view(), rootView]
    }
    
    var minSize: Size {
        return Size(square: Layouter.defaultMinWidth)
    }
    override func updateLayout() {
        updateTransform()
    }
    func updateWithModel() {
        updateCanvasSize()
    }
    func updateCanvasSize() {
        canvasBorderView.frame = bounds.inset(by: 50)
    }
    
    var zoomingTransform: Transform {
        get { return model.transform }
        set {
            binder[keyPath: keyPath].transform = newValue
            updateTransform()
            transformView.updateWithModel()
        }
    }
    func convertZoomingLocalFromZoomingView(_ p: Point) -> Point {
        return zoomingLocalView.convert(p, from: zoomingView)
    }
    func convertZoomingLocalToZoomingView(_ p: Point) -> Point {
        return zoomingLocalView.convert(p, to: zoomingView)
    }
    func updateTransform() {
        var transform = zoomingTransform
        let objectsPosition = Point(x: (bounds.width / 2).rounded(),
                                    y: (bounds.height / 2).rounded())
        transform.translation += objectsPosition
        zoomingLocalView.transform = transform
    }
    var zoomingView: View {
        return self
    }
    var zoomingLocalView: View {
        return rootView
    }
}
