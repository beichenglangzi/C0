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

/**
 Compiler Issue: Protocolから静的に決定可能な代数的データ型のコードを自動生成
 */
struct Object {
    var value: Codable & Referenceable
    init(_ value: Codable & Referenceable) {
        self.value = value
    }
//    case bool(Bool)
    
//    var value: Codable & Referenceable {
//        switch self {
//        case .bool(let value): return value
//        default: return nil
//        }
//    }
    
    private var bool: Bool {
        get { return value as! Bool }
        set { value = newValue }
    }
    
    private enum CodingKeys: CodingKey {
        case typeName, value
    }
    enum CodingError: Error {
        case decoding(String), encoding(String)
    }
}
extension Object: Decodable {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let key = try values.decode(String.self, forKey: .typeName)
        switch key {
        case String(describing: Bool.self): value = try values.decode(Bool.self, forKey: .value)
        default: throw CodingError.decoding("\(dump(values))")
        }
    }
}
extension Object: Encodable {
    func encode(to encoder: Encoder) throws {
        let typeName = String(describing: type(of: value))
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(typeName, forKey: .typeName)
        switch value {
        case (let value as Bool): try container.encode(value, forKey: .value)
        default: throw CodingError.encoding("\(typeName)")
        }
    }
}
extension Object: Referenceable {
    static var name = Text(english: "Object", japanese: "オブジェクト")
}
extension Object: AbstractViewable {
    func abstractViewWith<T>(binder: T, keyPath: ReferenceWritableKeyPath<T, Object>,
                             frame: Rect, _ sizeType: SizeType,
                             type: AbstractType) -> ModelView where T : BinderProtocol {
        switch value {
        case (let value as Bool):
            return value.abstractViewWith(binder: binder,
                                          keyPath: keyPath.appending(path: \Object.bool),
                                          frame: frame, sizeType, type: type)
        default: fatalError()
        }
    }
}

protocol ObjectProtocol {
    var object: Object { get }
}
