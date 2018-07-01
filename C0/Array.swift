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

typealias AbstractElement = Object.Value & AbstractViewable & AnyInitializable
typealias ObjectElement = Object.Value

struct ArrayIndex<T>: Codable, Hashable {
    var index = 0
}

extension Array {
    subscript(arrayIndex: ArrayIndex<Element>) -> Element {
        get { return self[arrayIndex.index] }
        set { self[arrayIndex.index] = newValue }
    }
}
extension Array: Referenceable where Element: Referenceable {
    static var name: Text {
        return "[" + Element.name + "]"
    }
}

extension Array: AbstractConstraint where Element: AbstractConstraint {}
extension Array: AnyInitializable where Element: AbstractElement {}
extension Array: ThumbnailViewable where Element: AbstractElement {
    func thumbnailView(withFrame frame: Rect) -> View {
        return count.thumbnailView(withFrame: frame)
    }
}
extension Array: AbstractViewable where Element: AbstractElement {
    func abstractViewWith<T>(binder: T,
                             keyPath: ReferenceWritableKeyPath<T, Array<Element>>,
                             type: AbstractType) -> ModelView where T: BinderProtocol {
        switch type {
        case .normal:
            return ArrayView(binder: binder, keyPath: keyPath)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath)
        }
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
    
    var defaultModel = Model()
    
    var abstractType: AbstractType {
        didSet { updateChildren() }
    }
    
    private(set) var rootView: View
    private(set) var modelViews: [View]
    
    var newableValue: Object.Value?
    
    init(binder: Binder, keyPath: BinderKeyPath,
         xyOrientation: Orientation.XY? = nil, abstractType: AbstractType = .normal) {
        self.binder = binder
        self.keyPath = keyPath
        
        self.xyOrientation = xyOrientation
        self.abstractType = abstractType
        
        rootView = View(isLocked: false)
        rootView.lineWidth = 0
        modelViews = ArrayView.modelViewsWith(model: binder[keyPath: keyPath],
                                              binder: binder, keyPath: keyPath,
                                              type: abstractType)
        
        super.init(isLocked: false)
        isClipped = true
        
        rootView.children = modelViews
        children = [rootView]
    }
    
    var xyOrientation: Orientation.XY?
    var minSize: Size {
        guard let views = modelViews as? [LayoutMinSize],
            let xyOrientation = xyOrientation else {
                return Size(square: Layouter.defaultMinWidth)
        }
        switch xyOrientation {
        case .horizontal:
            return views.reduce(Size()) {
                let minSize = $1.minSize
                return Size(width: $0.width + minSize.width,
                            height: max($0.height, minSize.height))
            }
        case .vertical:
            return views.reduce(Size()) {
                let minSize = $1.minSize
                return Size(width: max($0.width, minSize.width),
                            height: $0.height + minSize.height)
            }
        }
    }
    override func updateLayout() {
        guard let views = modelViews as? [View & LayoutMinSize],
            let xyOrientation = xyOrientation else { return }
        
        let padding = Layouter.basicPadding
        switch xyOrientation {
        case .horizontal:
            var x = padding
            views.forEach {
                let ms = $0.minSize
                $0.frame = Rect(x: x,
                                y: padding,
                                width: ms.width,
                                height: abstractType == .mini ? bounds.height : ms.height)
                x += ms.width
            }
        case .vertical:
            var y = padding
            views.forEach {
                let ms = $0.minSize
                $0.frame = Rect(x: padding,
                                y: y,
                                width:abstractType == .mini ? bounds.width - padding * 2 : ms.width,
                                height: ms.width)
                y += ms.height
            }
        }
    }

    func updateChildren() {
        modelViews = ArrayView.modelViewsWith(model: model,
                                              binder: binder, keyPath: keyPath,
                                              type: abstractType)
        if let views = modelViews as? [LayoutView<Object, Binder>] {
            views.forEach { $0.updateWithModel() }
        }
        self.rootView.children = modelViews
        updateLayout()
    }
    static func modelViewsWith(model: Model, binder: Binder, keyPath: BinderKeyPath,
                               type: AbstractType) -> [View] {
        return model.enumerated().map { (i, element) in
            return element.abstractViewWith(binder: binder,
                                            keyPath: keyPath.appending(path: \Model[i]),
                                            type: type)
        }
    }
    func updateWithModel() {
        updateChildren()
    }
    
    func append(_ element: ModelElement, _ version: Version) {
        var model = self.model
        model.append(element)
        push(model, to: version)
    }
    func insert(_ element: ModelElement, at index: Int, _ version: Version) {
        var model = self.model
        model.insert(element, at: index)
        push(model, to: version)
    }
    func remove(at index: Int, _ version: Version) {
        var model = self.model
        model.remove(at: index)
        push(model, to: version)
    }
}
extension ArrayView: Newable, CollectionAssignable {
    func paste(_ objects: [Any], for p: Point, _ version: Version) {
        let p = rootView.convert(p, from: self)
        let model: [ModelElement] = objects.compactMap {
            let element = ModelElement(anyValue: $0)
            if var layout = element as? LayoutProtocol {
                layout.transform.translation = p
                return layout as? ModelElement
            } else {
                return element
            }
        }
        if !model.isEmpty {
            push(self.model + model, to: version)
            return
        }
    }
    func remove(for p: Point, _ version: Version) {
        guard let index = rootView.children
            .index(where: { $0.contains($0.convert(p, from: self)) }) else { return }//no convert
//        let child = rootView.children[index]
        remove(at: index, version)
    }
    
    func new(for p: Point, _ version: Version) {
        if let newableValue = newableValue {
            paste([Object(newableValue)], for: p, version)
        }
    }
}
extension ArrayView {
    func updateLayoutPositions() {
        
    }
}

typealias ArrayCountElement = Equatable & Object.Value & AbstractViewable

final class ArrayCountView<T: ArrayCountElement, U: BinderProtocol>: ModelView, BindableReceiver {
    typealias ModelElement = T
    typealias Model = [ModelElement]
    typealias Binder = U
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((ArrayCountView<ModelElement, Binder>, BasicNotification) -> ())]()
    
    var defaultModel = Model()
    
    let countView: IntGetterView<Binder>
    
    let width = 40.0.cg
    let classNameView: TextFormView
    let countNameView: TextFormView
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        classNameView = TextFormView(text: Model.name, font: .bold)
        countNameView = TextFormView(text: Text(english: "Count", japanese: "個数") + ":")
        countView = IntGetterView(binder: binder, keyPath: keyPath.appending(path: \Model.count),
                                  option: IntGetterOption(unit: ""),
                                  isSizeToFit: false)
        
        super.init(isLocked: false)
        isClipped = true
        children = [classNameView, countNameView, countView]
    }
    
    var minSize: Size {
        let padding = Layouter.basicPadding, h = Layouter.basicHeight
        let w = classNameView.minSize.width + countNameView.minSize.width + width + padding * 3
        return Size(width: w, height: h)
    }
    override func updateLayout() {
        let padding = Layouter.basicPadding
        let classNameSize = classNameView.minSize
        let classNameOrigin = Point(x: padding,
                                    y: bounds.height - classNameSize.height - padding)
        classNameView.frame = Rect(origin: classNameOrigin, size: classNameSize)
        
        let countNameSize = countNameView.minSize
        let h = Layouter.basicHeight
        let countNameOrigin = Point(x: classNameView.frame.maxX + padding,
                                    y: padding)
        countNameView.frame = Rect(origin: countNameOrigin, size: countNameSize)
        countView.frame = Rect(x: countNameView.frame.maxX, y: padding,
                               width: width, height: h - padding * 2)
    }
    func updateWithModel() {
        countView.updateWithModel()
    }
}
