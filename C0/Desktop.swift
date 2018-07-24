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

struct Desktop: Codable {
    var version = Version()
    var copiedObject = Object(Text(stringLines:
        [StringLine(string: Localization(english: "Empty", japanese: "空").currentString,
                    origin: Point())]))
    var transform = Transform()
    
    var drawingFrame = Rect(x: -250, y: -310, width: 500, height: 620)
    var drawing = Drawing()
    var draftDrawing = Drawing()
}
extension Desktop: Viewable {
    func viewWith<T: BinderProtocol>
        (binder: T, keyPath: ReferenceWritableKeyPath<T, Desktop>) -> ModelView {
        
        return DesktopView(binder: binder, keyPath: keyPath)
    }
}
extension Desktop: ObjectViewable {}

final class DesktopBinder: BinderProtocol {
    var rootModel: Desktop {
        didSet { diffDesktopDataModel.isWrite = true }
    }
    
    init(rootModel: Desktop) {
        self.rootModel = rootModel
        diffDesktopDataModel = DataModel(key: diffDesktopDataModelKey)
        objectsDataModel = DataModel(key: objectsDataModelKey, directoryWith: [])
        dataModel = DataModel(key: dataModelKey,
                              directoryWith: [diffDesktopDataModel, objectsDataModel])
        
        diffDesktopDataModel.dataClosure = { [unowned self] in self.rootModel.jsonData }
    }
    
    let dataModelKey = "desktop"
    var dataModel: DataModel {
        didSet {
            if let objectsDataModel = dataModel.children[objectsDataModelKey] {
                self.objectsDataModel = objectsDataModel
            } else {
                dataModel.insert(objectsDataModel)
            }
            
            if let dDesktopDataModel = dataModel.children[diffDesktopDataModelKey] {
                self.diffDesktopDataModel = dDesktopDataModel
            } else {
                dataModel.insert(diffDesktopDataModel)
            }
        }
    }
    
    let diffDesktopDataModelKey = "diffDesktop"
    var diffDesktopDataModel: DataModel {
        didSet {
            if let desktop = diffDesktopDataModel.readObject(Desktop.self) {
                diffDesktopDataModel.stopIsWriteClosure { self.rootModel = desktop }
            }
            diffDesktopDataModel.dataClosure = { [unowned self] in self.rootModel.jsonData }
        }
    }
    
    let objectsDataModelKey = "objects"
    var objectsDataModel: DataModel
}

final class DesktopView<T: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = Desktop
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((DesktopView<Binder>, BasicNotification) -> ())]()
    
    let copiedObjectView: ObjectView<Binder>
    let transformView: TransformView<Binder>
    let drawingFrameView: RectView<Binder>
    let drawingView: DrawingView<Binder>
    let draftDrawingView: DrawingView<Binder>

    let drawingFrameAroundView: View
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath

        copiedObjectView = ObjectView(binder: binder,
                                      keyPath: keyPath.appending(path: \Model.copiedObject))
        transformView = TransformView(binder: binder,
                                      keyPath: keyPath.appending(path: \Model.transform))
        drawingView = DrawingView(binder: binder,
                                  keyPath: keyPath.appending(path: \Model.drawing))
        draftDrawingView = DrawingView(binder: binder,
                                       keyPath: keyPath.appending(path: \Model.draftDrawing))
        drawingFrameView = RectView(binder: binder,
                                    keyPath: keyPath.appending(path: \Model.drawingFrame))
        drawingFrameAroundView = View(path: Path())
        
        copiedObjectView.lineColor = .content
        copiedObjectView.opacity = 0.5
        draftDrawingView.linesColor = .draft
        draftDrawingView.opacity = 0.1
        
        drawingFrameAroundView.fillColorComposition = .around
        
        super.init(isLocked: false)
        drawingFrameView.notifications.append { [unowned self] (_, _) in
            self.updateDrawingFrame()
        }
        transformView.notifications.append { [unowned self] (_, _) in
            self.updateAround()
        }
        fillColor = .background
        transformView.children = [draftDrawingView, drawingView, drawingFrameView]
        children = [transformView, drawingFrameAroundView]
        updateWithModel()
        updateAround()
    }
    
    func updateWithModel() {
        copiedObjectView.updateWithModel()
        transformView.updateWithModel()
        drawingFrameView.updateWithModel()
        drawingView.updateWithModel()
        draftDrawingView.updateWithModel()
        updateDrawingFrame()
    }
    override func updateLayout() {
        updateTransform()
    }
    func updateDrawingFrame() {
        drawingView.frame = model.drawingFrame
        draftDrawingView.frame = model.drawingFrame
        updateAround()
    }
    var zoomingLocalTransform: Transform {
        var transform = zoomingTransform
        let objectsPosition = Point(x: (bounds.width / 2).rounded(),
                                    y: (bounds.height / 2).rounded())
        transform.translation += objectsPosition
        return transform
    }
    func updateTransform() {
        transformView.transform = zoomingLocalTransform
        updateAround()
    }
    func updateAround() {
        var path = Path()
        path.append(bounds)
        let affine = zoomingLocalTransform.affineTransform
        path.append(PathLine(points: [model.drawingFrame.minXminYPoint * affine,
                                      model.drawingFrame.minXmaxYPoint * affine,
                                      model.drawingFrame.maxXmaxYPoint * affine,
                                      model.drawingFrame.maxXminYPoint * affine]))
        drawingFrameAroundView.path = path
    }
}

extension DesktopView: Zoomable {
    func captureTransform(to version: Version) {
        transformView.capture(model.transform, to: version)
    }
    var defaultTransform: Transform {
        return Transform(translation: model.drawingFrame.centerPoint, z: 0, rotation: 0)
    }
    var zoomingTransform: Transform {
        get { return model.transform }
        set {
            binder[keyPath: keyPath].transform = newValue
            updateTransform()
        }
    }
    func convertZoomingLocalFromZoomingView(_ p: Point) -> Point {
        return zoomingLocalView.convert(p, from: zoomingView)
    }
    func convertZoomingLocalToZoomingView(_ p: Point) -> Point {
        return zoomingLocalView.convert(p, to: zoomingView)
    }
    var zoomingView: View {
        return self
    }
    var zoomingLocalView: View {
        return transformView
    }
}

extension DesktopView: MakableStrokable {
    func strokable(at p: Point) -> Strokable {
        return StrokableUserObject(rootView: self, drawingView: drawingView)
    }
}

extension DesktopView: MakableChangeableColor {
    func changeableColor(at p: Point) -> ChangeableColor? {
        let point = drawingView.convertFromRoot(p)
        guard let surfaceView = drawingView.surfacesView.at(point) as? SurfaceView<Binder> else {
            return nil
        }
        let uuColor = surfaceView.model.uuColor
        let views: [View & ChangeableColorOwner] = drawingView.surfacesView.modelViews.compactMap {
            let surfaceView = $0 as? SurfaceView<Binder>
            return surfaceView?.model.uuColor == uuColor ? surfaceView : nil
        }
        return ChangeableColorObject(views: views, firstUUColor: uuColor)
    }
}

extension DesktopView: MakableMovable {
    func movable(at p: Point) -> Movable {
        if let makableMovable = at(p, (View & MakableMovable).self), makableMovable != self {
            return makableMovable.movable(at: makableMovable.convertFromRoot(p))
        } else {
            return drawingView
        }
    }
}

extension DesktopView: Undoable {
    var version: Version {
        return model.version
    }
}

extension DesktopView: MakableCollectionAssignable {
    func collectionAssignable(at p: Point) -> CollectionAssignable {
        
        
        return at(p, CollectionAssignable.self) ?? drawingView
    }
    var copiedObject: Object {
        return copiedObjectView.model
    }
    func push(copiedObject: Object, to version: Version) {
        copiedObjectView.push(copiedObject, to: version)
    }
}
extension DesktopView: CollectionAssignable {
    var copiableObject: Object {
        return Object(model.drawing)
    }
    func remove(with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version) {
        push(drawing: Drawing(), to: version)
    }
    func paste(_ object: Object,
               with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version) {
        if let drawing = object.value as? Drawing {
            push(drawing: model.drawing + drawing, to: version)
        }
    }
}

extension DesktopView: MakableChangeableDraft {
    func changeableDraft(at p: Point) -> ChangeableDraft {
        return self
    }
}
extension DesktopView: ChangeableDraft {
    func changeToDraft(with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version) {
        push(draftDrawing: model.draftDrawing + model.drawing, to: version)
        push(drawing: Drawing(), to: version)
    }
    func removeDraft(with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version) {
        push(draftDrawing: Drawing(), to: version)
    }
    func push(drawing: Drawing, to version: Version) {
        version.registerUndo(withTarget: self) { [oldDrawing = model.drawing] in
            $0.push(drawing: oldDrawing, to: version)
        }
        drawingView.model = drawing
    }
    func push(draftDrawing: Drawing, to version: Version) {
        version.registerUndo(withTarget: self) { [oldDraftDrawing = model.draftDrawing] in
            $0.push(draftDrawing: oldDraftDrawing, to: version)
        }
        draftDrawingView.model = draftDrawing
    }
    var draftValue: Object.Value {
        return model.draftDrawing
    }
}

extension DesktopView: MakableExportable {
    func exportable(at p: Point) -> Exportable {
        return self
    }
}
extension DesktopView: URLEncodable {
    func write(to url: URL,
               progressClosure: @escaping (Real, inout Bool) -> () = { (_, _) in },
               completionClosure: @escaping (Error?) -> () = { _ in }) throws {
        let size = ceil(model.drawingFrame.size * model.transform.scale.x * contentsScale)
        let image = drawingView.renderImage(with: size)
        try image?.write(.png, to: url)
        completionClosure(nil)
    }
}
extension DesktopView: Exportable {
    func export(with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version) {
        URL.file(fileTypes: [Image.FileType.png]) { file in
            try? self.write(to: file.url)
        }
    }
}

extension DesktopView: RootModeler {}
