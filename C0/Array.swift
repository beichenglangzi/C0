/*
 Copyright 2018 S
 
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

typealias AbstractElement = Object.Value & Viewable
typealias ObjectElement = Object.Value

extension Array: Viewable where Element: AbstractElement {
    func viewWith<T: BinderProtocol>
        (binder: T, keyPath: ReferenceWritableKeyPath<T, Array<Element>>) -> ModelView {
        
        return ArrayView(binder: binder, keyPath: keyPath)
    }
}
extension Array: ObjectDecodable where Element: AbstractElement {}
extension Array: ObjectViewable where Element: AbstractElement {}

enum ArrayNotification<Model> {
    case insert(Int, Model)
    case remove(Int)
    case move(Int, Model)
}

final class ArrayView<T: AbstractElement, U: BinderProtocol>: ModelView, BindableReceiver {
    typealias ModelElement = T
    typealias Model = [ModelElement]
    typealias Binder = U
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((ArrayView<ModelElement, Binder>, BasicNotification) -> ())]()
    
    private(set) var rootView: View
    private(set) var modelViews: [ModelView]
    
    var newableValue: Object.Value?
    
    init(binder: Binder, keyPath: BinderKeyPath,
         xyOrientation: Orientation.XY? = nil) {
        self.binder = binder
        self.keyPath = keyPath
        
        self.xyOrientation = xyOrientation
        
        rootView = View(isLocked: false)
        modelViews = ArrayView.modelViewsWith(model: binder[keyPath: keyPath],
                                              binder: binder, keyPath: keyPath)
        
        super.init(isLocked: false)
        
        rootView.children = modelViews
        children = [rootView]
    }
    
    var xyOrientation: Orientation.XY?
    override func updateLayout() {
        guard let xyOrientation = xyOrientation else { return }
        
        let padding = Layouter.padding
        switch xyOrientation {
        case .horizontal:
            var x = padding
            modelViews.forEach {
                let ms = $0.transformedBoundingBox
                let h = ms.height
                $0.frame = Rect(x: x, y: padding,
                                width: ms.width, height: h)
                x += ms.width
            }
        case .vertical:
            var y = padding
            modelViews.forEach {
                let ms = $0.transformedBoundingBox
                $0.frame = Rect(x: padding, y: y,
                                width: ms.width, height: ms.width)
                y += ms.height
            }
        }
    }

    func updateChildren() {
        modelViews = ArrayView.modelViewsWith(model: model,
                                              binder: binder, keyPath: keyPath)
        self.rootView.children = modelViews
        updateLayout()
    }
    static func modelViewsWith(model: Model,
                               binder: Binder, keyPath: BinderKeyPath) -> [ModelView] {
        return model.enumerated().map { (i, element) in
            element.viewWith(binder: binder,
                             keyPath: keyPath.appending(path: \Model[i]))
        }
    }
    func updateWithModel() {
        updateChildren()
    }
    
    func append(_ element: ModelElement, _ version: Version) {
        version.registerUndo(withTarget: self) { [oldIndex = model.count - 1] in
            $0.remove(at: oldIndex, version)
        }
        binder[keyPath: keyPath].append(element)
        let view = element.viewWith(binder: binder,
                                    keyPath: keyPath.appending(path: \Model[model.count - 1]))
        append(child: view)
        
//        var model = self.model
//        model.append(element)
//        push(model, to: version)
    }
    func insert(_ element: ModelElement, at index: Int, _ version: Version) {
        version.registerUndo(withTarget: self) {
            $0.remove(at: index, version)
        }
        
        binder[keyPath: keyPath].insert(element, at: index)
        let view = element.viewWith(binder: binder,
                                    keyPath: keyPath.appending(path: \Model[index]))
        append(child: view)
        
//        remove(at: index, version)
//        var model = self.model
//        model.insert(element, at: index)
//        push(model, to: version)
    }
    func remove(at index: Int, _ version: Version) {
        var model = self.model
        model.remove(at: index)
        push(model, to: version)
    }
}
