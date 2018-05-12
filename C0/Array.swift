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

import struct Foundation.Locale

typealias AbstractElement = Equatable & AbstractViewable & Referenceable

struct ArrayIndex<T>: Codable, Hashable {
    var index = 0
}
extension Array {
    subscript(arrayIndex: ArrayIndex<Element>) -> Element {
        get {
            return self[arrayIndex.index]
        }
        set {
            self[arrayIndex.index] = newValue
        }
    }
}

extension Array {
    func withRemovedFirst() -> Array {
        var array = self
        array.removeFirst()
        return array
    }
    func withRemovedLast() -> Array {
        var array = self
        array.removeLast()
        return array
    }
    func withRemoved(at i: Int) -> Array {
        var array = self
        array.remove(at: i)
        return array
    }
    func withAppend(_ element: Element) -> Array {
        var array = self
        array.append(element)
        return array
    }
    func withInserted(_ element: Element, at i: Int) -> Array {
        var array = self
        array.insert(element, at: i)
        return array
    }
    func withReplaced(_ element: Element, at i: Int) -> Array {
        var array = self
        array[i] = element
        return array
    }
}
extension Array: Referenceable where Element: Referenceable {
    static var name: Text {
        return "[" + Element.name + "]"
    }
}
extension Array: Viewable where Element: Viewable {
    func view(withBounds bounds: Rect, _ sizeType: SizeType) -> View {
        return ObjectView(object: self, thumbnailView: nil, minFrame: bounds, sizeType)
    }
}

// CompactViewablesView
final class ViewablesView<T: BinderProtocol>: View, BindableReceiver {
    typealias Model = [Viewable]
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    
    init(binder: Binder, keyPath: BinderKeyPath,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        super.init()
        isClipped = true
        //children
        self.frame = frame
    }
    func updateWithModel() {
        
    }
}
private struct _Viewables: Referenceable {
    static let name = Text(english: "Array", japanese: "配列")
}
extension ViewablesView: Queryable {
    static var referenceableType: Referenceable.Type {
        return _Viewables.self
    }
}
extension ViewablesView: Copiable {
    func copiedViewables(at p: Point) -> [Viewable] {
        return model
    }
}

final class ArrayView<T: BinderProtocol, U: AbstractElement>: View, BindableReceiver {
    typealias Element = U
    typealias Model = [U]
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    
    var sizeType: SizeType {
        didSet { updateLayout() }
    }
    
    init(binder: Binder, keyPath: BinderKeyPath,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.sizeType = sizeType
        
        super.init()
        isClipped = true
        //children
        self.frame = frame
    }
    
    override func updateLayout() {
        
    }
    func updateWithModel() {
        
    }
    
    func append(_ element: Element) {
        let keyPath = self.keyPath.appending(path: \Model.[model.count - 1])
        let view = element.abstractViewWith(binder: binder, keyPath: keyPath, frame: Rect(), sizeType)
        
    }
}
extension ArrayView: Queryable {
    static var referenceableType: Referenceable.Type {
        return [Model].self
    }
}
extension ArrayView: Copiable {
    func copiedViewables(at p: Point) -> [Viewable] {
        return [model]
    }
}

final class ArrayCountView<T: BinderProtocol, U: AbstractElement>: View, BindableReceiver {
    typealias Model = [U]
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    
    let countView: IntGetterView<Binder>
    
    var sizeType: SizeType {
        didSet { updateLayout() }
    }
    var width = 40.0.cg {
        didSet { updateLayout() }
    }
    let classNameView: TextView
    let countNameView: TextView
    
    init(binder: Binder, keyPath: BinderKeyPath,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        self.sizeType = sizeType
        classNameView = TextView(text: Model.name, font: Font.bold(with: sizeType))
        countNameView = TextView(text: Text(english: "Count:", japanese: "個数:"),
                                 font: Font.default(with: sizeType))
        countView = IntGetterView(binder: binder, keyPath: keyPath.appending(path: \Model.capacity),
                                  option: IntGetterOption(unit: ""), sizeType: sizeType)
        
        super.init()
        isClipped = true
        children = [classNameView, countNameView, countView]
        self.frame = frame
    }
    
    override var defaultBounds: Rect {
        let padding = Layout.padding(with: sizeType), h = Layout.height(with: sizeType)
        return Rect(x: 0, y: 0, width: classNameView.frame.width + countNameView.frame.width + width + padding * 3, height: h)
    }
    override func updateLayout() {
        let padding = Layout.padding(with: sizeType), h = Layout.height(with: sizeType)
        classNameView.frame.origin = Point(x: padding,
                                           y: bounds.height - classNameView.frame.height - padding)
        countNameView.frame.origin = Point(x: classNameView.frame.maxX + padding,
                                           y: padding)
        countView.frame = Rect(x: countNameView.frame.maxX, y: padding,
                               width: width, height: h - padding * 2)
        updateWithModel()
    }
    func updateWithModel() {
        countView.updateWithModel()
    }
}
extension ArrayCountView: Localizable {
    func update(with locale: Locale) {
        updateLayout()
    }
}
extension ArrayCountView: Queryable {
    static var referenceableType: Referenceable.Type {
        return Model.self
    }
}
extension ArrayCountView: Copiable {
    func copiedViewables(at p: Point) -> [Viewable] {
        return [model]
    }
}
