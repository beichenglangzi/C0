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
    
    var drawingFrame = Rect(x: -400, y: -400, width: 800, height: 800)
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
    let rootView = View()
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
        draftDrawingView.opacity = 0.2
        
        drawingFrameAroundView.fillColorComposition = .around
        
        super.init(isLocked: false)
        drawingFrameView.notifications.append { [unowned self] (_, _) in
            self.updateDrawingFrame()
        }
        fillColor = .background
        rootView.children = [draftDrawingView, drawingView, drawingFrameView]
        transformView.children = [rootView]
        children = [transformView, drawingFrameAroundView]
    }
    
    override func updateLayout() {
        updateTransform()
    }
    func updateDrawingFrame() {
        drawingView.frame = model.drawingFrame
        draftDrawingView.frame = model.drawingFrame
        updateAround()
    }
    func updateTransform() {
        var transform = zoomingTransform
        let objectsPosition = Point(x: (bounds.width / 2).rounded(),
                                    y: (bounds.height / 2).rounded())
        transform.translation += objectsPosition
        zoomingLocalView.transform = transform
        
        updateAround()
    }
    func updateAround() {
        var path = Path()
        path.append(bounds)
        let affine = transform.affineTransform
        path.append(PathLine(points: [model.drawingFrame.minXminYPoint * affine,
                                      model.drawingFrame.maxXminYPoint * affine,
                                      model.drawingFrame.maxXmaxYPoint * affine,
                                      model.drawingFrame.minXmaxYPoint * affine]))
        drawingFrameAroundView.path = path
    }
}
extension DesktopView: RootModeler {
    func userObject(at p: Point) -> UserObjectProtocol {
        let tmo = TransformingMovableObject(viewAndFirstOrigins: [(drawingView, transform.translation)],
                                            rootView: self)
        let userObject = DesktopUserObject(rootView: self, transformingMovableObject: tmo)
        if let view = rootView.at(p, Copiable.self) {
            userObject.copiedObject = view.copiedObject
        }
        return userObject
    }
    func strokable(withRootView rootView: View) -> Strokable {
        return StrokableUserObject(rootView: self, drawingView: drawingView)
    }
}
extension DesktopView: Zoomable {
    func captureTransform(to version: Version) {
        transformView.push(model.transform, to: version)
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
        return rootView
    }
}
extension DesktopView: Undoable {
    var version: Version {
        return model.version
    }
}
extension DesktopView: CopiableViewer {
    var copiedObject: Object {
        get { return copiedObjectView.model }
        set { copiedObjectView.model = newValue }
    }
    func push(_ copiedObject: Object, to version: Version) {
        copiedObjectView.push(copiedObject, to: version)
    }
}
extension DesktopView: CollectionAssignable {
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
extension DesktopView: URLEncodable {
    func write(to url: URL,
               progressClosure: @escaping (Real, inout Bool) -> () = { (_, _) in },
               completionClosure: @escaping (Error?) -> () = { _ in }) throws {
        let size = ceil(model.drawingFrame.size * model.transform.scale.x)
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

final class DesktopUserObject: UserObjectProtocol {
    var draftValue: Object.Value
    var copiedObject = Object(Text(stringLines: [StringLine(string: "None", origin: Point())]))
    var rootView: Sender.RootView
    var transformingMovableObject: TransformingMovableObject?
    
    init(rootView: Sender.RootView, transformingMovableObject: TransformingMovableObject?) {
        self.rootView = rootView
        self.transformingMovableObject = transformingMovableObject
    }
    
    func move(with eventValue: DragEvent.Value, _ phase: Phase, _ version: Version) {
        transformingMovableObject?.move(with: eventValue, phase, version)
    }
    
    func remove(with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version) {
        rootView.remove(with: eventValue, phase, version)
    }
    func paste(_ object: Object,
               with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version) {
        rootView.paste(object, with: eventValue, phase, version)
    }
    
    func changeToDraft(with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version) {
        rootView.changeToDraft(with: eventValue, phase, version)
    }
    func removeDraft(with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version) {
        rootView.removeDraft(with: eventValue, phase, version)
    }
    func export(with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version) {
        rootView.export(with: eventValue, phase, version)
    }
}
