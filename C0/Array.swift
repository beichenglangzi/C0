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

//extension Array: Object.Value & AbstractViewable where Element == Object {
//    func abstractViewWith<T>(binder: T,
//                             keyPath: ReferenceWritableKeyPath<T, Array<Element>>,
//                             frame: Rect, _ sizeType: SizeType,
//                             type: AbstractType) -> ModelView where T: BinderProtocol {
//        switch type {
//        case .normal:
//            return ObjectsView(binder: binder, keyPath: keyPath, frame: frame, sizeType: sizeType)
//        case .mini:
//            return MiniView(binder: binder, keyPath: keyPath, frame: frame, sizeType)
//        }
//    }
//    func objectViewWith<T>(binder: T, keyPath: ReferenceWritableKeyPath<T, Object>,
//                           frame: Rect, _ sizeType: SizeType,
//                           type: AbstractType) -> ModelView where T: BinderProtocol {
//        return ObjectView(binder: binder, keyPath: keyPath, value: self, type: type)
//    }
//}
extension Array: AnyInitializable where Element: AbstractElement {}
extension Array: ThumbnailViewable where Element: AbstractElement {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return count.thumbnailView(withFrame: frame, sizeType)
    }
}
extension Array: AbstractViewable where Element: AbstractElement {
    func abstractViewWith<T>(binder: T,
                             keyPath: ReferenceWritableKeyPath<T, Array<Element>>,
                             frame: Rect, _ sizeType: SizeType,
                             type: AbstractType) -> ModelView where T: BinderProtocol {
        switch type {
        case .normal:
            return ArrayView(binder: binder, keyPath: keyPath, frame: frame,
                             sizeType: sizeType, abstractType: type)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath, frame: frame, sizeType)
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
    
    var sizeType: SizeType {
        didSet { updateLayout() }
    }
    var abstractType: AbstractType {
        didSet { updateChildren() }
    }
    
    var modelViews: [View]
    
    init(binder: Binder, keyPath: BinderKeyPath,
         frame: Rect = Rect(), sizeType: SizeType = .regular,
         abstractType: AbstractType = .normal) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        self.sizeType = sizeType
        self.abstractType = abstractType
        
        modelViews = ArrayView.modelViewsWith(model: binder[keyPath: keyPath],
                                              binder: binder, keyPath: keyPath,
                                              sizeType: sizeType, type: abstractType)
        
        super.init()
        isClipped = true
        self.frame = frame
    }
    
//    var layoutClosure: ((Model, [View]) -> ())?
//    override func updateLayout() {
//        layoutClosure?(model, modelViews)
//    }
    override func updateLayout() {
        let padding = Layouter.padding(with: sizeType)
        //test
        if !(ModelElement.self is Layoutable.Type) {
            var x = padding
            modelViews.forEach {
                let db = $0.defaultBounds
                $0.frame = Rect(x: x,
                                y: padding,
                                width: db.width,
                                height: abstractType == .mini ? bounds.height - padding * 2 : db.height)
                x += db.width
            }

        }
//        layoutClosure?(model, modelViews)
    }

    func updateChildren() {
        modelViews = ArrayView.modelViewsWith(model: model,
                                              binder: binder, keyPath: keyPath,
                                              sizeType: sizeType, type: abstractType)
        self.children = modelViews
        updateLayout()
    }
    static func modelViewsWith(model: Model, binder: Binder, keyPath: BinderKeyPath,
                               sizeType: SizeType, type: AbstractType) -> [View] {
        return model.enumerated().map { (i, element) in
            return element.abstractViewWith(binder: binder,
                                            keyPath: keyPath.appending(path: \Model[i]),
                                            frame: Rect(), sizeType, type: type)
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
extension ArrayView: CollectionAssignable {
    func add(_ objects: [Any], for p: Point, _ version: Version) {
        let model = objects.compactMap { ModelElement(anyValue: $0) }
        if !model.isEmpty {
            push(self.model + model, to: version)
            return
        }
    }
    func remove(for p: Point, _ version: Version) {
        guard let index = children.index(where: { $0.contains($0.convert(p, from: self)) }) else { return }
//        let child = children[index]
        remove(at: index, version)
    }
}
extension ArrayView {
    func updateLayoutPositions() {
        
    }
}
extension ArrayView: Zoomable {
//    override var transform: Transform {
//        get { return childrenTransform }
//        set { childrenTransform = newValue }
//    }
    
    func resetView(for p: Point, _ version: Version) {
        childrenTransform = Transform()
    }
    
    func captureTransform(to version: Version) {
        
    }
    
    func makeViewZoomer() -> ViewZoomer {
        return BasicViewZomer(zoomableView: self)
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
    
    var sizeType: SizeType {
        didSet { updateLayout() }
    }
    var width = 40.0.cg {
        didSet { updateLayout() }
    }
    let classNameView: TextFormView
    let countNameView: TextFormView
    
    init(binder: Binder, keyPath: BinderKeyPath,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        self.sizeType = sizeType
        classNameView = TextFormView(text: Model.name, font: Font.bold(with: sizeType))
        countNameView = TextFormView(text: Text(english: "Count", japanese: "個数") + ":",
                                     font: Font.default(with: sizeType))
        countView = IntGetterView(binder: binder, keyPath: keyPath.appending(path: \Model.count),
                                  option: IntGetterOption(unit: ""), sizeType: sizeType,
                                  isSizeToFit: false)
        
        super.init()
        isClipped = true
        children = [classNameView, countNameView, countView]
        self.frame = frame
    }
    
    override var defaultBounds: Rect {
        let padding = Layouter.padding(with: sizeType), h = Layouter.height(with: sizeType)
        let w = classNameView.frame.width + countNameView.frame.width + width + padding * 3
        return Rect(x: 0, y: 0, width: w, height: h)
    }
    override func updateLayout() {
        let padding = Layouter.padding(with: sizeType), h = Layouter.height(with: sizeType)
        classNameView.frame.origin = Point(x: padding,
                                           y: bounds.height - classNameView.frame.height - padding)
        countNameView.frame.origin = Point(x: classNameView.frame.maxX + padding,
                                           y: padding)
        countView.frame = Rect(x: countNameView.frame.maxX, y: padding,
                               width: width, height: h - padding * 2)
    }
    func updateWithModel() {
        countView.updateWithModel()
    }
}
