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

typealias Size = CGSize
extension Size {
    init(square: Real) {
        self.init(width: square, height: square)
    }
    static func +(lhs: Size, rhs: Real) -> Size {
        return Size(width: lhs.width + rhs, height: lhs.height + rhs)
    }
    static func +(lhs: Size, rhs: Size) -> Size {
        return Size(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }
    static func *(lhs: Size, rhs: Real) -> Size {
        return Size(width: lhs.width * rhs, height: lhs.height * rhs)
    }
    
    static let effectiveFieldSizeOfView = Size(width: tan(.pi * (30.0 / 2) / 180),
                                               height: tan(.pi * (20.0 / 2) / 180))
    
    func contains(_ other: Size) -> Bool {
        return width >= other.width && height >= other.height
    }
    func intersects(_ other: Size) -> Bool {
        return width >= other.width || height >= other.height
    }
}
func ceil(_ size: Size) -> Size {
    return Size(width: size.width.rounded(.up), height: size.height.rounded(.up))
}
extension Size: AppliableAffineTransform {
    static func *(lhs: Size, rhs: AffineTransform) -> Size {
        return lhs.applying(rhs)
    }
}
