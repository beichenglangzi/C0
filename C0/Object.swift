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

protocol ObjectDecodable {
    static var appendObjectType: () { get }
}
extension ObjectDecodable {
    static var objectType: Self.Type {
        return Self.self
    }
}

protocol ObjectViewable {
    func objectViewWith<T>(binder: T, keyPath: ReferenceWritableKeyPath<T, Object>,
                           frame: Rect, _ sizeType: SizeType,
                           type: AbstractType) -> ModelView where T: BinderProtocol
}
extension ObjectViewable where Self: Codable & Referenceable & ObjectDecodable & AbstractViewable {
    func objectViewWith<T>(binder: T, keyPath: ReferenceWritableKeyPath<T, Object>,
                           frame: Rect, _ sizeType: SizeType,
                           type: AbstractType) -> ModelView where T: BinderProtocol {
        return ObjectView(binder: binder, keyPath: keyPath, value: self,
                          frame: frame, sizeType: sizeType, type: type)
    }
}

/**
 Compiler Issue: Protocolから静的に決定可能なコードを自動生成
 */
struct Object {
    private static var types = [String: Value.Type]()
    static func append<T: Value & AbstractViewable>(_ type: T.Type) {
        let arrayType = Array<T>.self
        types[String(describing: type)] = type
        types[String(describing: arrayType)] = arrayType
    }
    static func append<T: KeyframeValue>(_ type: T.Type) {
        let arrayType = Array<T>.self
        let keyframeType = Keyframe<T>.self
        let animationType = Animation<T>.self
        types[String(describing: type)] = type
        types[String(describing: arrayType)] = arrayType
        types[String(describing: keyframeType)] = keyframeType
        types[String(describing: animationType)] = animationType
    }
    
    typealias Value = Codable & Referenceable & ObjectViewable & ObjectDecodable
    
    var frame: Rect
    var value: Value
    
    init(_ value: Value, frame: Rect = Rect()) {
        self.value = value
        self.frame = frame
    }
}
extension Object: Referenceable {
    static var name = Text(english: "Object", japanese: "オブジェクト")
}
extension Object: Codable {
    private enum CodingKeys: String, CodingKey {
        case frame, typeName, value
    }
    enum CodingError: Error {
        case decoding(String), encoding(String)
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        frame = try values.decode(Rect.self, forKey: .frame)
        let key = try values.decode(String.self, forKey: .typeName)
        if let type = Object.types[key] {
            value = try type.decode(values: values, forKey: .value)
        } else {
            throw CodingError.decoding("\(dump(values))")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        let typeName = String(describing: type(of: value))
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(frame, forKey: .frame)
        try container.encode(typeName, forKey: .typeName)
        try value.encode(forKey: .value, in: &container)
    }
}
extension Object: ObjectViewable {
    func objectViewWith<T>(binder: T, keyPath: ReferenceWritableKeyPath<T, Object>,
                           frame: Rect, _ sizeType: SizeType,
                           type: AbstractType) -> ModelView where T: BinderProtocol {
        return value.objectViewWith(binder: binder, keyPath: keyPath,
                                    frame: frame, sizeType, type: type)
    }
}
extension Object: AbstractViewable {
    func abstractViewWith<T>(binder: T, keyPath: ReferenceWritableKeyPath<T, Object>,
                             frame: Rect, _ sizeType: SizeType,
                             type: AbstractType) -> ModelView where T: BinderProtocol {
        return value.objectViewWith(binder: binder, keyPath: keyPath,
                                    frame: frame, sizeType, type: type)
    }
}
extension Object: ObjectDecodable {
    static var appendObjectType: () { return () }
}

protocol ObjectProtocol {
    var object: Object { get }
}

final class ObjectView<Value: Object.Value & AbstractViewable, T: BinderProtocol>
: View, BindableReceiver {

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
    var valueView: View
    var value: Value? {
        return binder[keyPath: keyPath].value as? Value
    }
    func set(_ value: Value) {
        binder[keyPath: keyPath].value = value
    }
    
    var sizeType: SizeType {
        didSet { updateWithModel() }
    }
    var type: AbstractType {
        didSet { updateWithModel() }
    }
    
    init(binder: Binder, keyPath: BinderKeyPath, value: Value,
         frame: Rect = Rect(), sizeType: SizeType = .regular, type: AbstractType) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        self.sizeType = sizeType
        self.type = type
        
        valueBinder = BasicBinder(rootModel: value)
        valueView = value.abstractViewWith(binder: valueBinder,
                                           keyPath: \BasicBinder<Value>.rootModel,
                                           frame: Rect(origin: Point(), size: frame.size),
                                           sizeType, type: type)
        
        super.init()
        
        valueBinder.notification = { [unowned self] binder, _ in
            self.set(binder.rootModel)
        }
        children = [valueView]
        self.frame = frame
    }
    
    override var defaultBounds: Rect {
        return valueView.defaultBounds
    }
    override func updateLayout() {
        valueView.frame = bounds
    }
    func updateWithModel() {
        if let value = value {
            valueBinder = BasicBinder(rootModel: value)
            
            valueView = value.abstractViewWith(binder: valueBinder,
                                               keyPath: \BasicBinder<Value>.rootModel,
                                               frame: Rect(origin: Point(), size: frame.size),
                                               sizeType, type: type)
            
            children = [valueView]
        }
    }
}
