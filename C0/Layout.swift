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

enum Orientation {
    enum Horizontal {
        case leftToRight, rightToLeft
    }
    enum Vertical {
        case bottomToTop, topToBottom
    }
    enum XY {
        case horizontal(Horizontal), vertical(Vertical)
    }
    enum Circular {
        case clockwise, counterClockwise
    }
    
    case xy(XY), circular(Circular)
}

enum Layouter {
    static let knobRadius = 4.0.cg
    static let slidableKnobRadius = 2.5.cg
    static let padding = 3.0.cg
    static let movablePadding = 6.0.cg
    static let minWidth = 30.0.cg
    static let lineWidth = 1.5.cg
    static let movableLineWidth = 2.0.cg
    static let textHeight = Font.default.ceilHeight(withPadding: 1)
    static let textPaddingHeight = textHeight + padding * 2
    static let valueWidth = 80.cg
}
