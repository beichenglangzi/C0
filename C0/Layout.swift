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

typealias LayoutValue = Codable & Viewable

protocol Layoutable {
    var frame: Rect { get set }
    var transform: Transform { get set }
}

enum ConstraintType {
    case none, width, height, widthAndHeight
}

protocol LayoutProtocol {
    var transform: Transform { get set }
}
struct Layout<Value: LayoutValue>: Codable, LayoutProtocol {
    var value: Value
    var transform: Transform
    
    init(_ value: Value, transform: Transform = Transform()) {
        self.value = value
        self.transform = transform
    }
}
extension Layout: ValueChain {
    var chainValue: Any { return value }
}
extension Layout {
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
extension Layout: Viewable {
    func viewWith<T: BinderProtocol>
        (binder: T, keyPath: ReferenceWritableKeyPath<T, Layout<Value>>) -> ModelView {
        
        return LayoutView(binder: binder, keyPath: keyPath)
    }
}
extension Layout: ObjectViewable {}

enum Layouter {
    static let knobRadius = 4.0.cg
    static let slidableKnobRadius = 2.5.cg
    static let padding = 3.0.cg
    static let movablePadding = 6.0.cg
    static let minWidth = 30.0.cg
    static let lineWidth = 1.0.cg
    static let movableLineWidth = 2.0.cg
    static let textHeight = Font.default.ceilHeight(withPadding: 1)
    static let textPaddingHeight = textHeight + padding * 2
    static let valueWidth = 80.cg
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
    
    var valueView: View
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        valueView = binder[keyPath: keyPath].value
            .viewWith(binder: binder,
                              keyPath: keyPath.appending(path: \Model.value))
        
        super.init(isLocked: false)
        children = [valueView]
        updateWithModel()
    }
    
    func updateWithModel() {
        transform = model.transform
    }
    
    var movingOrigin: Point {
        get { return model.transform.translation }
        set {
            binder[keyPath: keyPath].transform.translation = newValue
            self.transform.translation = newValue
        }
    }
}
