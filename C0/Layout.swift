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

protocol Layoutable {
    var frame: Rect { get set }
    var transform: Transform { get set }
}

typealias LayoutValue = Codable & ThumbnailViewable & Referenceable & AbstractViewable

struct Layout<Value: LayoutValue>: Layoutable, Codable {
    var value: Value
    var transform: Transform
    var frame: Rect
    
    init(_ value: Value, transform: Transform = Transform(), frame: Rect = Rect()) {
        self.value = value
        self.transform = transform
        self.frame = frame
    }
}
extension Layout: ValueChain {
    var chainValue: Any { return value }
}
extension Layout: AnyInitializable {
    init?(anyValue: Any) {
        if let value = (anyValue as? ValueChain)?.value(Value.self) {
            self = Layout(value)
        } else if let value = anyValue as? Value {
            self = Layout(value)
        } else {
            return nil
        }
    }
}
extension Layout: Referenceable {
    static var name: Text {
        return Text(english: "Layout", japanese: "レイアウト") + "<" + Value.name + ">"
    }
}
extension Layout: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return value.thumbnailView(withFrame: frame, sizeType)
    }
}
extension Layout: AbstractViewable {
    func abstractViewWith<T : BinderProtocol>(binder: T,
                                              keyPath: ReferenceWritableKeyPath<T, Layout<Value>>,
                                              frame: Rect, _ sizeType: SizeType,
                                              type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return LayoutView(binder: binder, keyPath: keyPath,
                              frame: frame, sizeType: sizeType)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath, frame: frame, sizeType)
        }
    }
}
extension Layout: ObjectViewable {}

enum Layouter {
    static let smallPadding = 2.0.cg, basicPadding = 3.0.cg, basicLargePadding = 14.0.cg
    static let smallRatio = Font.small.size / Font.default.size
    static let basicTextHeight = Font.default.ceilHeight(withPadding: 1)
    static let basicTextSmallHeight = Font.small.ceilHeight(withPadding: 1)
    static let basicHeight = basicTextHeight + basicPadding * 2
    static let smallHeight = Font.small.ceilHeight(withPadding: 1) + smallPadding * 2
    static let basicValueWidth = 56.cg, smallValueWidth = 40.0.cg
    static let basicValueFrame = Rect(x: 0, y: basicPadding,
                                      width: basicValueWidth, height: basicHeight)
    static let smallValueFrame = Rect(x: 0, y: smallPadding,
                                      width: smallValueWidth, height: smallHeight)
    static let propertyWidth = 140.0.cg
    static func padding(with sizeType: SizeType) -> Real {
        return sizeType == .small ? smallPadding : basicPadding
    }
    static func height(with sizeType: SizeType) -> Real {
        return sizeType == .small ? smallHeight : basicHeight
    }
    static func textHeight(with sizeType: SizeType) -> Real {
        return sizeType == .small ? basicTextSmallHeight : basicTextHeight
    }
    static func valueWidth(with sizeType: SizeType) -> Real {
        return sizeType == .small ? smallValueWidth : basicValueWidth
    }
    static func valueFrame(with sizeType: SizeType) -> Rect {
        return sizeType == .small ? smallValueFrame : basicValueFrame
    }
    
    enum Item {
        case view(View), xPadding(Real), yPadding(Real)
        
        var view: View? {
            switch self {
            case .view(let view): return view
            default: return nil
            }
        }
        var width: Real {
            switch self {
            case .view(let view): return view.bounds.width
            case .xPadding(let padding): return padding
            case .yPadding: return 0
            }
        }
        var height: Real {
            switch self {
            case .view(let view): return view.bounds.width
            case .xPadding: return 0
            case .yPadding(let padding): return padding
            }
        }
        var bounds: Rect {
            switch self {
            case .view(let view): return view.bounds
            case .xPadding(let padding): return Rect(x: 0, y: 0, width: padding, height: 0)
            case .yPadding(let padding): return Rect(x: 0, y: 0, width: 0, height: padding)
            }
        }
        var defaultBounds: Rect {
            switch self {
            case .view(let view): return view.defaultBounds
            case .xPadding(let padding): return Rect(x: 0, y: 0, width: padding, height: 0)
            case .yPadding(let padding): return Rect(x: 0, y: 0, width: 0, height: padding)
            }
        }
    }
    
    static func centered(_ items: [Item],
                         in bounds: Rect, paddingWidth: Real = 0) {
        let w = items.reduce(-paddingWidth) { $0 +  $1.bounds.width + paddingWidth }
        _ = items.reduce(((bounds.width - w) / 2).rounded(.down)) { x, item in
            item.view?.frame.origin.x = x
            return x + item.width + paddingWidth
        }
    }
    static func leftAlignmentWidth(_ items: [Item], minX: Real = basicPadding,
                                   paddingWidth: Real = 0) -> Real {
        return items.reduce(minX) { $0 + $1.bounds.width + paddingWidth } - paddingWidth
    }
    static func leftAlignment(_ items: [Item], minX: Real = basicPadding,
                              y: Real = 0, paddingWidth: Real = 0) {
        _ = items.reduce(minX) { x, item in
            item.view?.frame.origin = Point(x: x, y: y)
            return x + item.width + paddingWidth
        }
    }
    static func leftAlignment(_ items: [Item], minX: Real = basicPadding,
                              y: Real = 0, height: Real, paddingWidth: Real = 0) -> Size {
        let width = items.reduce(minX) { x, item in
            item.view?.frame.origin = Point(x: x,
                                            y: y + ((height - item.bounds.height) / 2).rounded())
            return x + item.width + paddingWidth
        }
        return Size(width: width, height: height)
    }
    static func topAlignment(_ items: [Item],
                             minX: Real = basicPadding, minY: Real = basicPadding,
                             minSize: inout Size, padding: Real = Layouter.basicPadding) {
        let width = items.reduce(0.0.cg) { max($0, $1.defaultBounds.width) } + padding * 2
        let height = items.reversed().reduce(minY) { y, item in
            item.view?.frame = Rect(x: minX, y: y, width: width, height: item.defaultBounds.height)
            return y + item.height
        }
        minSize = Size(width: width, height: height - minY)
    }
    static func autoHorizontalAlignment(_ items: [Item],
                                        padding: Real = 0, in bounds: Rect) {
        guard !items.isEmpty else { return }
        let w = items.reduce(0.0.cg) { $0 +  $1.defaultBounds.width + padding } - padding
        let dx = (bounds.width - w) / Real(items.count)
        _ = items.enumerated().reduce(bounds.minX) { x, value in
            let (i, item) = value
            if i == items.count - 1 {
                item.view?.frame = Rect(x: x, y: bounds.minY,
                                        width: bounds.maxX - x, height: bounds.height)
                return bounds.maxX
            } else {
                item.view?.frame = Rect(x: x,
                                        y: bounds.minY,
                                        width: (value.element.defaultBounds.width + dx).rounded(),
                                        height: bounds.height)
                return x + item.width + padding
            }
        }
    }
}

final class LayoutView<Value: LayoutValue, Binder: BinderProtocol>
: ModelView, BindableReceiver, Layoutable {
    
    typealias Model = Layout<Value>
    typealias BinderKeyPath = ReferenceWritableKeyPath<Binder, Model>
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((LayoutView<Value, Binder>, BasicPhaseNotification<Model>) -> ())]()
    
    var sizeType: SizeType {
        didSet { updateLayout() }
    }
    
    var defaultModel: Layout<Value> {
        return Layout(model.value)
    }
    
    let valueView: View
    
    init(binder: Binder, keyPath: BinderKeyPath,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        let padding = Layouter.padding(with: sizeType)
        let valueFrame = Size(square: padding).intersects(binder[keyPath: keyPath].frame.size) ?
            Rect() :
            binder[keyPath: keyPath].frame.inset(by: padding)
        self.sizeType = sizeType
        valueView = binder[keyPath: keyPath].value
            .abstractViewWith(binder: binder,
                              keyPath: keyPath.appending(path: \Model.value),
                              frame: valueFrame, sizeType, type: .normal)
        if valueView.frame.isEmpty {
            valueView.frame.size = valueView.defaultBounds.size
        }
        super.init()
        self.model.frame.size = valueView.frame.inset(by: -padding).size
        self.frame = self.model.frame
        children = [valueView]
    }
    
    override var defaultBounds: Rect {
        return valueView.defaultBounds.inset(by: -Layouter.padding(with: sizeType))
    }
    override func updateLayout() {
        model.frame = frame
        valueView.frame = bounds.inset(by: Layouter.padding(with: sizeType))
    }
    func updateWithModel() {
        
    }
}
