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
protocol ObjectViewable: Codable, ObjectDecodable {
    func binderAndView() -> (NotificationBinderProtocol, ModelView)
}
extension ObjectViewable where Self: Codable & Viewable {
    func binderAndView() -> (NotificationBinderProtocol, ModelView) {
        let binder = BasicBinder(rootModel: self)
        let view = viewWith(binder: binder, keyPath: \BasicBinder<Self>.rootModel)
        return (binder, view)
    }
}

struct Object {
    private(set) static var types = [String: Value.Type]()
    static func contains(_ typeName: String) -> Bool {
        return types[typeName] != nil
    }
    static func append<T: Value & Viewable>(_ type: T.Type) {
        types[type.objectTypeName] = type
//        appendInArray(type)
//        appendInArray(Transforming<T>.self)
//        appendInArray(UU<T>.self)
        appendInTransfoming(type)
//        appendInTransfoming(Array<T>.self)
        appendInTransfoming(UU<T>.self)
        appendInUU(type)
//        appendInUU(Array<T>.self)
        appendInUU(Transforming<T>.self)
    }
//    static func appendInArray<T: Value & Viewable>(_ type: T.Type) {
//        let arrayType = Array<T>.self
//        types[arrayType.objectTypeName] = arrayType
//    }
    static func appendInUU<T: Value & Viewable>(_ type: T.Type) {
        let uuType = UU<T>.self
        types[uuType.objectTypeName] = uuType
    }
    static func appendInTransfoming<T: Value & Viewable>(_ type: T.Type) {
        let transformingType = Transforming<T>.self
        types[transformingType.objectTypeName] = transformingType
    }
    static func appendTypes() {
        append(Drawing.self)
        append(Color.self)
        append(Image.self)
        append(Text.self)
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
extension Object: Viewable {
    func viewWith<T: BinderProtocol>
        (binder: T, keyPath: ReferenceWritableKeyPath<T, Object>) -> ModelView {
        
        return ObjectView(binder: binder, keyPath: keyPath)
    }
}
extension Object: ObjectViewable {}

protocol ObjectProtocol {
    var object: Object { get }
}

final class ObjectView<T: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = Object
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((ObjectView<Binder>, BasicNotification) -> ())]()
    
    var valueBinder: NotificationBinderProtocol
    var valueView: ModelView
    var value: Object.Value {
        return binder[keyPath: keyPath].value
    }
    func set(_ value: Object.Value) {
        binder[keyPath: keyPath].value = value
    }
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        (valueBinder, valueView) = binder[keyPath: keyPath].value.binderAndView()
        
        super.init(isLocked: false)
        lineColor = nil
        valueBinder.notification = { [unowned self] (value, _) in self.set(value) }
        children = [valueView]
    }
    
    override func updateLayout() {
        valueView.frame = bounds
    }
    func updateWithModel() {
        (valueBinder, valueView) = binder[keyPath: keyPath].value.binderAndView()
        valueBinder.notification = { [unowned self] (value, _) in self.set(value) }
        children = [valueView]
    }
}
