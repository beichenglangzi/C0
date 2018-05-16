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

import CoreGraphics

/**
 Issue: Core Graphicsと置き換え
 */
struct _Size: Equatable {
    var width = 0.0.cg, height = 0.0.cg
    
    var isEmpty: Bool {
        return width == 0 && height == 0
    }
    
    static func *(lhs: _Size, rhs: Real) -> _Size {
        return _Size(width: lhs.width * rhs, height: lhs.height * rhs)
    }
}
extension _Size: Hashable {
    var hashValue: Int {
        return Hash.uniformityHashValue(with: [width.hashValue, height.hashValue])
    }
}
extension _Size: Codable {
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let width = try container.decode(Real.self)
        let height = try container.decode(Real.self)
        self.init(width: width, height: height)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(width)
        try container.encode(height)
    }
}
extension _Size: Referenceable {
    static let name = Text(english: "Size", japanese: "サイズ")
}

typealias Size = CGSize
extension Size {
    init(square: Real) {
        self.init(width: square, height: square)
    }
    static func *(lhs: Size, rhs: Real) -> Size {
        return Size(width: lhs.width * rhs, height: lhs.height * rhs)
    }
    
    static let effectiveFieldSizeOfView = Size(width: tan(.pi * (30.0 / 2) / 180),
                                               height: tan(.pi * (20.0 / 2) / 180))
    
}
extension Size: Referenceable {
    static let name = Text(english: "Size", japanese: "サイズ")
}
extension Size: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return (jsonString ?? "").thumbnailView(withFrame: frame, sizeType)
    }
}

extension Size: Object2D {
    typealias XModel = Real
    typealias YModel = Real
    
    init(xModel: XModel, yModel: YModel) {
        self.init(width: xModel, height: yModel)
    }
    
    var xModel: XModel {
        get { return width }
        set { width = newValue }
    }
    var yModel: YModel {
        get { return height }
        set { height = newValue }
    }
}

struct SizeOption: Object2DOption {
    typealias Model = Size
    typealias XOption = RealOption
    typealias YOption = RealOption
    
    var xOption: XOption
    var yOption: YOption
    
    func model(with object: Any) -> Model? {
        switch object {
        case let value as Model: return value
        case let value as String: return Model(jsonString: value)
        default: return nil
        }
    }
}
typealias SlidableSizeView<Binder: BinderProtocol> = Slidable2DView<SizeOption, Binder>
typealias DiscreteSizeView<Binder: BinderProtocol> = Discrete2DView<SizeOption, Binder>
