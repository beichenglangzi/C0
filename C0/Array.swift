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

//extension Array: Viewable where Element: AbstractElement {
//    func viewWith<T: BinderProtocol>
//        (binder: T, keyPath: ReferenceWritableKeyPath<T, Array<Element>>) -> ModelView {
//
//        return ArrayView(binder: binder, keyPath: keyPath)
//    }
//}
//extension Array: ObjectDecodable where Element: AbstractElement {}
//extension Array: ObjectViewable where Element: AbstractElement {}

enum ArrayNotification<Model> {
    case insert(Int, Model)
    case remove(Int)
    case move(Int, Model)
}

final class ArrayView<T: View & InitializableBindableReceiver>
: ModelView, BindableReceiver where T.Model: Viewable {
    typealias ElementView = T
    typealias Binder = T.Binder
    typealias ModelElement = T.Model
    typealias Model = [T.Model]
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet {
            elementViews.enumerated().forEach { (i, view) in
                view.keyPath = keyPath.appending(path: \Model[i])
            }
        }
    }
    var notifications = [((ArrayView<T>, BasicNotification) -> ())]()
    
    private(set) var rootView: View
    private(set) var elementViews: [ElementView]
    
    var newableValue: Object.Value?
    
    convenience init(binder: Binder, keyPath: BinderKeyPath) {
        self.init(binder: binder, keyPath: keyPath, xyOrientation: nil)
    }
    init(binder: Binder, keyPath: BinderKeyPath,
         xyOrientation: Orientation.XY?) {
        self.binder = binder
        self.keyPath = keyPath
        
        self.xyOrientation = xyOrientation
        
        rootView = View(isLocked: false)
        elementViews = ArrayView.elementViewsWith(model: binder[keyPath: keyPath],
                                              binder: binder, keyPath: keyPath)
        
        super.init(isLocked: false)
        
        rootView.children = elementViews
        children = [rootView]
    }
    
    var xyOrientation: Orientation.XY?
    override func updateLayout() {
        guard let xyOrientation = xyOrientation else { return }
        
        let padding = Layouter.padding
        switch xyOrientation {
        case .horizontal:
            var x = padding
            elementViews.forEach {
                let ms = $0.transformedBoundingBox
                let h = ms.height
                $0.frame = Rect(x: x, y: padding,
                                width: ms.width, height: h)
                x += ms.width
            }
        case .vertical:
            var y = padding
            elementViews.forEach {
                let ms = $0.transformedBoundingBox
                $0.frame = Rect(x: padding, y: y,
                                width: ms.width, height: ms.width)
                y += ms.height
            }
        }
    }

    func updateChildren() {
        elementViews = ArrayView.elementViewsWith(model: model,
                                                  binder: binder, keyPath: keyPath)
        rootView.children = elementViews
        updateLayout()
    }
    static func elementViewsWith(model: Model,
                                 binder: Binder, keyPath: BinderKeyPath) -> [ElementView] {
        return model.enumerated().map { (i, _) in
            ElementView(binder: binder, keyPath: keyPath.appending(path: \Model[i]))
        }
    }
    func updateWithModel() {
        updateChildren()
    }
    
    override var isEmpty: Bool {
        return true
    }
    
    func append(_ element: ModelElement, _ version: Version) {
        version.registerUndo(withTarget: self) {
            let oldIndex = $0.model.count - 1
            $0.remove(at: oldIndex, version)
        }
        binder[keyPath: keyPath].append(element)
        let view = ElementView(binder: binder,
                               keyPath: keyPath.appending(path: \Model[model.count - 1]))
        elementViews.append(view)
        rootView.append(child: view)
    }
    func insert(_ element: ModelElement, at index: Int, _ version: Version) {
        version.registerUndo(withTarget: self) {
            $0.remove(at: index, version)
        }
        binder[keyPath: keyPath].insert(element, at: index)
        let view = ElementView(binder: binder,
                               keyPath: keyPath.appending(path: \Model[index]))
        elementViews.insert(view, at: index)
        rootView.insert(child: view, at: index)
    
        elementViews[(index + 1)...].enumerated().forEach { (i, aView) in
            aView.keyPath = keyPath.appending(path: \Model[index + 1 + i])
        }
    }
    func insert(_ view: ElementView, _ element: ModelElement, at index: Int, _ version: Version) {
        version.registerUndo(withTarget: self) {
            $0.remove(at: index, version)
        }
        binder[keyPath: keyPath].insert(element, at: index)
        elementViews.insert(view, at: index)
        rootView.insert(child: view, at: index)
        
        elementViews[(index + 1)...].enumerated().forEach { (i, aView) in
            aView.keyPath = keyPath.appending(path: \Model[index + 1 + i])
        }
    }
    func remove(at index: Int, _ version: Version) {
        version.registerUndo(withTarget: self) {
            [oldView = elementViews[index], oldElement = model[index]] in
            
            $0.insert(oldView, oldElement, at: index, version)
        }
        binder[keyPath: keyPath].remove(at: index)
        elementViews.remove(at: index)
        rootView.children[index].removeFromParent()
        
        elementViews[index...].enumerated().forEach { (i, aView) in
            aView.keyPath = keyPath.appending(path: \Model[index + i])
        }
    }
    func push(_ model: [T.Model], to version: Version) {
        version.registerUndo(withTarget: self) {
            [oldElementViews = self.elementViews, oldModel = self.model] in
            
            $0.push(oldElementViews, oldModel, to: version)
        }
        binder[keyPath: keyPath] = model
        let elementViews = ArrayView.elementViewsWith(model: model, binder: binder, keyPath: keyPath)
        self.elementViews = elementViews
        rootView.children = elementViews
    }
    func push(_ elementViews: [ElementView], _ model: [T.Model], to version: Version) {
        version.registerUndo(withTarget: self) {
            [oldElementViews = self.elementViews, oldModel = self.model] in
            
            $0.push(oldElementViews, oldModel, to: version)
        }
        binder[keyPath: keyPath] = model
        self.elementViews = elementViews
        rootView.children = elementViews
    }
    
//    func append(_ elements: [ModelElement], _ version: Version) {
//        version.registerUndo(withTarget: self) {
//            let oldIndexes = Array($0.model.count - elements.count...$0.model.count - 1)
//            $0.remove(at: oldIndexes, version)
//        }
//        let lastIndex = model.count - 1
//        binder[keyPath: keyPath] += elements
//        let views = elements.enumerated().map { (i, element) in
//            element.viewWith(binder: binder,
//                             keyPath: keyPath.appending(path: \Model[lastIndex + 1 + i]))
//        }
//        modelViews += views
//        views.forEach { rootView.append(child: $0) }
//    }
//    func insert(_ elements: [ModelElement], at indexes: [Int], _ version: Version) {
//        var oldDeltaIndex = 0
//        let oldIndexes: [Int] = indexes.map {
//            let newIdnex = $0 + oldDeltaIndex
//            oldDeltaIndex -= 1
//            return newIdnex
//        }
//        version.registerUndo(withTarget: self) {
//            $0.remove(at: oldIndexes, version)
//        }
//        var deltaIndex = 0
//        indexes.enumerated().forEach { (i, index) in
//            let element = elements[i]
//            binder[keyPath: keyPath].insert(element, at: index)
//            deltaIndex += 1
//        }
//        deltaIndex = 0
//        indexes.enumerated().forEach { (i, index) in
//            let element = elements[i]
//            let view = element.viewWith(binder: binder,
//                                        keyPath: keyPath.appending(path: \Model[index]))
//            modelViews.insert(view, at: index + deltaIndex)
//            rootView.insert(child: view, at: index + deltaIndex)
//            deltaIndex += 1
//        }
//    }
//    func remove(at indexes: [Int], _ version: Version) {
//        let oldElements: [ModelElement] = indexes.map { i in model[i] }
//        var oldDeltaIndex = 0
//        let oldIndexes: [Int] = indexes.map {
//            let newIdnex = $0 + oldDeltaIndex
//            oldDeltaIndex -= 1
//            return newIdnex
//        }
//        version.registerUndo(withTarget: self) {
//            $0.insert(oldElements, at: oldIndexes, version)
//        }
//        var deltaIndex = 0
//        indexes.forEach {
//            binder[keyPath: keyPath].remove(at: $0 + deltaIndex)
//            deltaIndex -= 1
//        }
//        deltaIndex = 0
//        indexes.forEach {
//            let index = $0 + deltaIndex
//            modelViews.remove(at: index)
//            rootView.children[index].removeFromParent()
//            deltaIndex -= 1
//        }
//    }
}
