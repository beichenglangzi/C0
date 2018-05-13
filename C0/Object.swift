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
 Issue: Protocolから静的に決定可能な代数的データ型のコードを自動生成
 */
enum Object: AbstractViewable, Referenceable, Codable {
    case bool(Bool)
    case int(Int)
    case real(Real)
    case string(String)
    case array([Bool])
    
    var bool: Bool? {
        switch self {
        case .bool(let value): return value
        default: return nil
        }
    }
    var int: Int? {
        switch self {
        case .int(let value): return value
        default: return nil
        }
    }
    var real: Real? {
        switch self {
        case .real(let value): return value
        default: return nil
        }
    }
    var string: String? {
        switch self {
        case .string(let value): return value
        default: return nil
        }
    }
    
    
    //    static func decode(from data: Data, forKey key: String) -> Any? {
    //        let decoder = JSONDecoder()
    //        switch key {
    //        case typeKey(from: KeyframeTiming.self):
    //            return try? decoder.decode(KeyframeTiming.self, from: data)
    //        case typeKey(from: Easing.self):
    //            return try? decoder.decode(Easing.self, from: data)
    //        case typeKey(from: Transform.self):
    //            return try? decoder.decode(Transform.self, from: data)
    //        case typeKey(from: Wiggle.self):
    //            return try? decoder.decode(Wiggle.self, from: data)
    //        case typeKey(from: Effect.self):
    //            return try? decoder.decode(Effect.self, from: data)
    //        case typeKey(from: Line.self):
    //            return try? decoder.decode(Line.self, from: data)
    //        case typeKey(from: Color.self):
    //            return try? decoder.decode(Color.self, from: data)
    //        case typeKey(from: URL.self):
    //            return try? decoder.decode(URL.self, from: data)
    //        case typeKey(from: Real.self):
    //            return try? decoder.decode(URL.self, from: data)
    //        case typeKey(from: Size.self):
    //            return try? decoder.decode(URL.self, from: data)
    //        case typeKey(from: Point.self):
    //            return try? decoder.decode(URL.self, from: data)
    //        case typeKey(from: Bool.self):
    //            return try? decoder.decode(URL.self, from: data)
    //        case typeKey(from: [Line].self):
    //            return try? decoder.decode([Line].self, from: data)
    //        default:
    //            return nil
    //        }
    //    }
}
extension Object: MiniViewable {
    func miniViewWith<T: BinderProtocol>(binder: T, keyPath: KeyPath<T, Object>,
                                            frame: Rect, _ sizeType: SizeType) -> View  {
        switch self {
        case .bool(let value):
            return value.miniViewWith(binder: binder,
                                         keyPath: keyPath.appending(path: \Object.bool!),
                                         frame: frame, sizeType)
        case .int(let value):
            return value.miniViewWith(binder: binder,
                                         keyPath: keyPath.appending(path: \Object.int!),
                                         frame: frame, sizeType)
        case .real(let value):
            return value.miniViewWith(binder: binder,
                                         keyPath: keyPath.appending(path: \Object.real!),
                                         frame: frame, sizeType)
        }
    }
}

protocol ObjectProtocol {
    var object: Object { get }
}
