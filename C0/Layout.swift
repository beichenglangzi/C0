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
    static let smallPadding = 2.0.cf, basicPadding = 3.0.cf, basicLargePadding = 14.0.cf
    static let smallRatio = Font.small.size / Font.default.size
    static let basicTextHeight = Font.default.ceilHeight(withPadding: 1)
    static let basicHeight = basicTextHeight + basicPadding * 2
    static let smallHeight = Font.small.ceilHeight(withPadding: 1) + smallPadding * 2
    static let basicValueWidth = 56.cf, smallValueWidth = 40.0.cf
    static let basicValueFrame = CGRect(x: 0, y: basicPadding,
                                        width: basicValueWidth, height: basicHeight)
    static let smallValueFrame = CGRect(x: 0, y: smallPadding,
                                        width: smallValueWidth, height: smallHeight)
    static func padding(with sizeType: SizeType) -> CGFloat {
        return sizeType == .small ? smallPadding : basicPadding
    }
    static func height(with sizeType: SizeType) -> CGFloat {
        return sizeType == .small ? smallHeight : basicHeight
    }
    static func valueWidth(with sizeType: SizeType) -> CGFloat {
        return sizeType == .small ? smallValueWidth : basicValueWidth
    }
    static func valueFrame(with sizeType: SizeType) -> CGRect {
        return sizeType == .small ? smallValueFrame : basicValueFrame
    }
    
    static func centered(_ views: [View],
                         in bounds: CGRect, paddingWidth: CGFloat = 0) {
        let w = views.reduce(-paddingWidth) { $0 +  $1.frame.width + paddingWidth }
        _ = views.reduce(floor((bounds.width - w) / 2)) { x, view in
            view.frame.origin.x = x
            return x + view.frame.width + paddingWidth
        }
    }
    static func leftAlignmentWidth(_ views: [View], minX: CGFloat = basicPadding,
                                   paddingWidth: CGFloat = 0) -> CGFloat {
        return views.reduce(minX) { $0 + $1.frame.width + paddingWidth } - paddingWidth
    }
    static func leftAlignment(_ views: [View], minX: CGFloat = basicPadding,
                              y: CGFloat = 0, paddingWidth: CGFloat = 0) {
        _ = views.reduce(minX) { x, view in
            view.frame.origin = CGPoint(x: x, y: y)
            return x + view.frame.width + paddingWidth
        }
    }
    static func leftAlignment(_ views: [View], minX: CGFloat = basicPadding,
                              y: CGFloat = 0, height: CGFloat, paddingWidth: CGFloat = 0) -> CGSize {
        let width = views.reduce(minX) { x, view in
            view.frame.origin = CGPoint(x: x, y: y + round((height - view.frame.height) / 2))
            return x + view.frame.width + paddingWidth
        }
        return CGSize(width: width, height: height)
    }
    static func topAlignment(_ views: [View],
                             minX: CGFloat = basicPadding, minY: CGFloat = basicPadding,
                             minSize: inout CGSize, padding: CGFloat = Layout.basicPadding) {
        let width = views.reduce(0.0.cf) { max($0, $1.defaultBounds.width) } + padding * 2
        let height = views.reversed().reduce(minY) { y, view in
            view.frame = CGRect(x: minX, y: y,
                                 width: width, height: view.defaultBounds.height)
            return y + view.frame.height
        }
        minSize = CGSize(width: width, height: height - minY)
    }
    static func autoHorizontalAlignment(_ views: [View],
                                        padding: CGFloat = 0, in bounds: CGRect) {
        guard !views.isEmpty else {
            return
        }
        let w = views.reduce(0.0.cf) { $0 +  $1.defaultBounds.width + padding } - padding
        let dx = (bounds.width - w) / views.count.cf
        _ = views.enumerated().reduce(bounds.minX) { x, value in
            if value.offset == views.count - 1 {
                value.element.frame = CGRect(x: x, y: bounds.minY,
                                             width: bounds.maxX - x, height: bounds.height)
                return bounds.maxX
            } else {
                value.element.frame = CGRect(x: x,
                                             y: bounds.minY,
                                             width: round(value.element.defaultBounds.width + dx),
                                             height: bounds.height)
                return x + value.element.frame.width + padding
            }
        }
    }
}
final class Padding: View {
    override init() {
        super.init()
        self.frame = CGRect(origin: CGPoint(), size: CGSize(square: Layout.basicPadding))
    }
    
    func reference(at p: CGPoint) -> Reference {
        return Reference(name: Localization(english: "Padding", japanese: "パディング"))
    }
}
