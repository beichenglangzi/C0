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

struct Desktop: Codable {
    var version = Version()
    var copiedObject = Object(Localization(english: "Empty Copied Object",
                                           japanese: "空のコピー済みオブジェクト").currentString)
    var transform = Transform()
    var objects = [Object]()
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
    let objectsView: ArrayView<Object, Binder>

    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath

        copiedObjectView = ObjectView(binder: binder,
                                      keyPath: keyPath.appending(path: \Model.copiedObject))
        transformView = TransformView(binder: binder,
                                      keyPath: keyPath.appending(path: \Model.transform))
        objectsView = ArrayView(binder: binder,
                                keyPath: keyPath.appending(path: \Model.objects))
        
        copiedObjectView.lineColor = .content
        copiedObjectView.opacity = 0.5
        
        super.init(isLocked: false)
        fillColor = .background
        children = [objectsView]
    }
    
    func update(withBounds bounds: Rect) {
        objectsView.frame = bounds
        self.bounds = bounds
        updateTransform()
    }
    override func updateLayout() {
        objectsView.frame = bounds
        updateTransform()
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
    func updateTransform() {
        var transform = zoomingTransform
        let objectsPosition = Point(x: (bounds.width - Layouter.padding * 2).rounded(),
                                    y: (objectsView.bounds.height / 2).rounded())
        transform.translation += objectsPosition
        zoomingLocalView.transform = transform
    }
    var zoomingView: View {
        return objectsView
    }
    var zoomingLocalView: View {
        return objectsView.rootView
    }
}
extension DesktopView: Zoomable {
    func captureTransform(to version: Version) {
        transformView.push(model.transform, to: version)
    }
}
extension DesktopView: Undoable {
    var version: Version {
        return model.version
    }
}
extension DesktopView: CopiedObjectsViewer {
    var copiedObject: Object {
        get { return copiedObjectView.model }
        set { copiedObjectView.model = newValue }
    }
    func push(_ copiedObject: Object, to version: Version) {
        copiedObjectView.push(copiedObject, to: version)
    }
}
