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

import struct Foundation.URL

protocol ValueChain {
    var chainValue: Any { get }
    var rootChainValue: Any { get }
    func value<T>(_ type: T.Type) -> T?
}
extension ValueChain {
    var rootChainValue: Any {
        let chainValue = self.chainValue
        if let valueChain = chainValue as? ValueChain {
            return valueChain.rootChainValue
        } else {
            return chainValue
        }
    }
    func value<T>(_ type: T.Type) -> T? {
        let chainValue = rootChainValue
        return chainValue as? T
    }
}

protocol ObjectDecodable {
    static var objectTypeName: String { get }
    var objectTypeName: String { get }
}
extension ObjectDecodable {
    static var objectTypeName: String {
        return String(describing: self)
    }
    var objectTypeName: String {
        return String(describing: type(of: self))
    }
}
protocol ObjectViewable
: Codable, Referenceable, ThumbnailViewable, ObjectDecodable, AnyInitializable {

    func objectViewWith<T: BinderProtocol>
        (binder: T, keyPath: ReferenceWritableKeyPath<T, Object>, type: ViewableType) -> ModelView
}
extension ObjectViewable where Self: Codable & Referenceable & Viewable {
    func objectViewWith<T: BinderProtocol>
        (binder: T, keyPath: ReferenceWritableKeyPath<T, Object>, type: ViewableType) -> ModelView {
        
        return ObjectView(binder: binder, keyPath: keyPath, value: self, viewableType: type)
    }
}

struct Object {
    //😖
    private(set) static var types = [String: Value.Type]()
    static func contains(_ typeName: String) -> Bool {
        return types[typeName] != nil
    }
    static func append<T: Value & Viewable>(_ type: T.Type) {
        types[type.objectTypeName] = type
        appendInArray(type)
        appendInArray(Layout<T>.self)
        appendInLayout(type)
        appendInLayout(Array<T>.self)
    }
    static func appendInArray<T: Value & Viewable>(_ type: T.Type) {
        let arrayType = Array<T>.self
        types[arrayType.objectTypeName] = arrayType
    }
    static func appendInLayout<T: Value & Viewable>(_ type: T.Type) {
        let layoutType = Layout<T>.self
        types[layoutType.objectTypeName] = layoutType
    }
    static func append<T: KeyframeValue>(_ type: T.Type) {
        types[type.objectTypeName] = type
        appendInArray(type)
        appendInArray(Layout<T>.self)
        appendInArray(Keyframe<T>.self)
        appendInArray(Animation<T>.self)
        appendInLayout(type)
        appendInLayout(Array<T>.self)
        appendInLayout(Keyframe<T>.self)
        appendInLayout(Animation<T>.self)
        let keyframeType = Keyframe<T>.self
        let animationType = Animation<T>.self
        types[keyframeType.objectTypeName] = keyframeType
        types[animationType.objectTypeName] = animationType
    }
    static func appendTypes() {
        append(Scene.self)
        append(Drafting<Drawing>.self)
        append(Drawing.self)
        append(Line.self)
        append(Color.self)
        append(Transform.self)
        append(Image.self)
        append(URL.self)
        append(Size.self)
        append(Point.self)
        append(Real.self)
        append(Rational.self)
        append(Int.self)
        append(Bool.self)
        append(String.self)
        append(Object.self)
    }
    
    typealias Value = ObjectViewable
    
    var value: Value
    
    init(_ value: Value) {
        if let object = value as? Object {
            self = object
        } else {
            self.value = value
        }
    }
}
extension Object: ValueChain {
    var chainValue: Any { return value }
}
extension Object: Referenceable {
    static var name = Text(english: "Object", japanese: "オブジェクト")
}
extension Object: Codable {
    private enum CodingKeys: String, CodingKey {
        case typeName, value
    }
    enum CodingError: Error {
        case decoding(String)
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let key = try values.decode(String.self, forKey: .typeName)
        if let type = Object.types[key] {
            value = try type.decode(values: values, forKey: .value)
        } else {
            throw CodingError.decoding("key bug = \(key)")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        let typeName = String(describing: value.objectTypeName)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(typeName, forKey: .typeName)
        try value.encode(forKey: .value, in: &container)
    }
}
extension Object: ObjectViewable {
    func objectViewWith<T>(binder: T, keyPath: ReferenceWritableKeyPath<T, Object>,
                           type: ViewableType) -> ModelView where T: BinderProtocol {
        return value.objectViewWith(binder: binder, keyPath: keyPath, type: type)
    }
}
extension Object: StandardViewable {
    func standardViewWith<T: BinderProtocol>
        (binder: T, keyPath: ReferenceWritableKeyPath<T, Object>) -> ModelView {
        
        return value.objectViewWith(binder: binder, keyPath: keyPath, type: .standard)
    }
}
extension Object: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect) -> View {
        return value.thumbnailView(withFrame: frame)
    }
}
extension Object: MiniViewable {
    func miniViewWith<T: BinderProtocol>
        (binder: T, keyPath: ReferenceWritableKeyPath<T, Object>) -> ModelView {
        
        return value.objectViewWith(binder: binder, keyPath: keyPath, type: .mini)
    }
}
extension Object: Viewable {}

protocol ObjectProtocol {
    var object: Object { get }
}

final class ObjectView<Value: Object.Value & Viewable, T: BinderProtocol>
: ModelView, BindableReceiver {
    
    typealias Model = Object
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((ObjectView<Value, Binder>, BasicNotification) -> ())]()
    
    var valueBinder: BasicBinder<Value>
    var valueView: ModelView & LayoutMinSize
    var value: Value? {
        return binder[keyPath: keyPath].value as? Value
    }
    func set(_ value: Value) {
        binder[keyPath: keyPath].value = value
    }
    
    var viewableType: ViewableType {
        didSet { updateWithModel() }
    }
    
    init(binder: Binder, keyPath: BinderKeyPath, value: Value, viewableType: ViewableType) {
        self.binder = binder
        self.keyPath = keyPath
        self.viewableType = viewableType
        
        valueBinder = BasicBinder(rootModel: value)
        valueView = value.viewWith(binder: valueBinder, keyPath: \BasicBinder<Value>.rootModel,
                                   type: viewableType)
        
        super.init(isLocked: false)
        lineColor = nil
        valueBinder.notification = { [unowned self] (binder, _) in self.set(binder.rootModel) }
        children = [valueView]
    }
    
    var minSize: Size {
        return valueView.minSize
    }
    override func updateLayout() {
        valueView.frame = bounds
    }
    func updateWithModel() {
        guard let value = value else { return }
        valueBinder = BasicBinder(rootModel: value)
        valueView = value.viewWith(binder: valueBinder, keyPath: \BasicBinder<Value>.rootModel,
                                   type: viewableType)
        
        children = [valueView]
    }
}
