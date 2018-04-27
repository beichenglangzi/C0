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

import Foundation

struct Layout {
    static let smallPadding = 2.0.cg, basicPadding = 3.0.cg, basicLargePadding = 14.0.cg
    static let smallRatio = Font.small.size / Font.default.size
    static let basicTextHeight = Font.default.ceilHeight(withPadding: 1)
    static let basicHeight = basicTextHeight + basicPadding * 2
    static let smallHeight = Font.small.ceilHeight(withPadding: 1) + smallPadding * 2
    static let basicValueWidth = 56.cg, smallValueWidth = 40.0.cg
    static let basicValueFrame = Rect(x: 0, y: basicPadding,
                                        width: basicValueWidth, height: basicHeight)
    static let smallValueFrame = Rect(x: 0, y: smallPadding,
                                        width: smallValueWidth, height: smallHeight)
    static func padding(with sizeType: SizeType) -> Real {
        return sizeType == .small ? smallPadding : basicPadding
    }
    static func height(with sizeType: SizeType) -> Real {
        return sizeType == .small ? smallHeight : basicHeight
    }
    static func valueWidth(with sizeType: SizeType) -> Real {
        return sizeType == .small ? smallValueWidth : basicValueWidth
    }
    static func valueFrame(with sizeType: SizeType) -> Rect {
        return sizeType == .small ? smallValueFrame : basicValueFrame
    }
    
    static func centered(_ views: [View],
                         in bounds: Rect, paddingWidth: Real = 0) {
        let w = views.reduce(-paddingWidth) { $0 +  $1.frame.width + paddingWidth }
        _ = views.reduce(floor((bounds.width - w) / 2)) { x, view in
            view.frame.origin.x = x
            return x + view.frame.width + paddingWidth
        }
    }
    static func leftAlignmentWidth(_ views: [View], minX: Real = basicPadding,
                                   paddingWidth: Real = 0) -> Real {
        return views.reduce(minX) { $0 + $1.frame.width + paddingWidth } - paddingWidth
    }
    static func leftAlignment(_ views: [View], minX: Real = basicPadding,
                              y: Real = 0, paddingWidth: Real = 0) {
        _ = views.reduce(minX) { x, view in
            view.frame.origin = Point(x: x, y: y)
            return x + view.frame.width + paddingWidth
        }
    }
    static func leftAlignment(_ views: [View], minX: Real = basicPadding,
                              y: Real = 0, height: Real, paddingWidth: Real = 0) -> Size {
        let width = views.reduce(minX) { x, view in
            view.frame.origin = Point(x: x, y: y + round((height - view.frame.height) / 2))
            return x + view.frame.width + paddingWidth
        }
        return Size(width: width, height: height)
    }
    static func topAlignment(_ views: [View],
                             minX: Real = basicPadding, minY: Real = basicPadding,
                             minSize: inout Size, padding: Real = Layout.basicPadding) {
        let width = views.reduce(0.0.cg) { max($0, $1.defaultBounds.width) } + padding * 2
        let height = views.reversed().reduce(minY) { y, view in
            view.frame = Rect(x: minX, y: y,
                                 width: width, height: view.defaultBounds.height)
            return y + view.frame.height
        }
        minSize = Size(width: width, height: height - minY)
    }
    static func autoHorizontalAlignment(_ views: [View],
                                        padding: Real = 0, in bounds: Rect) {
        guard !views.isEmpty else {
            return
        }
        let w = views.reduce(0.0.cg) { $0 +  $1.defaultBounds.width + padding } - padding
        let dx = (bounds.width - w) / Real(views.count)
        _ = views.enumerated().reduce(bounds.minX) { x, value in
            if value.offset == views.count - 1 {
                value.element.frame = Rect(x: x, y: bounds.minY,
                                             width: bounds.maxX - x, height: bounds.height)
                return bounds.maxX
            } else {
                value.element.frame = Rect(x: x,
                                             y: bounds.minY,
                                             width: round(value.element.defaultBounds.width + dx),
                                             height: bounds.height)
                return x + value.element.frame.width + padding
            }
        }
    }
}
final class PaddingView: View, Queryable {
    override init() {
        super.init()
        self.frame = Rect(origin: Point(), size: Size(square: Layout.basicPadding))
    }
    
    func reference(at p: Point) -> Reference {
        return Reference(name: Text(english: "Padding", japanese: "パディング"))
    }
}
