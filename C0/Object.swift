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
enum Object {
    case bool(Bool)
    case int(Int)
    case rational(Rational)
    case real(Real)
    case string(String)
    case array([Bool])
    
    var bool: Bool {
        get {
            switch self {
            case .bool(let value): return value
            default: return Bool()
            }
        }
        set {
            self = .bool(newValue)
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
}
extension Object: Decodable {
    init(from decoder: Decoder) throws {
        
    }
}
extension Object: Encodable {
    func encode(to encoder: Encoder) throws {
        
    }
}
extension Object: AbstractViewable {
    func abstractViewWith<T>(binder: T, keyPath: ReferenceWritableKeyPath<T, Object>,
                             frame: Rect, _ sizeType: SizeType) -> View where T : BinderProtocol {
        switch self {
        case .bool(let value):
            return value.abstractViewWith(binder: binder,
                                          keyPath: keyPath.appending(path: \Object.bool),
                                          frame: frame, sizeType)
        default: fatalError()
        }
    }
}

protocol ObjectProtocol {
    var object: Object { get }
}
