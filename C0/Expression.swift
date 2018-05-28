/*
 Copyright 2017 S
 
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

struct Variable: Codable, Hashable {
    var rawValue: String
    init(_ rawValue: String) {
        self.rawValue = rawValue
    }
    static let x = Variable("x"), y = Variable("y"), z = Variable("z")
}
extension Variable: Referenceable {
    static let name = Text(english: "Variable", japanese: "変数")
}
extension Variable: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return rawValue.thumbnailView(withFrame: frame, sizeType)
    }
}

indirect enum Expression: Hashable {
    case number(Variable)
    case int(Int)
    case rational(Rational)
    case real(Real)
    case addition(Expression, Expression)
    case subtraction(Expression, Expression)
    case multiplication(Expression, Expression)
    case division(Expression, Expression)
    static func +(_ lhs: Expression, _ rhs: Expression) -> Expression {
        return Expression.addition(lhs, rhs)
    }
    static func -(_ lhs: Expression, _ rhs: Expression) -> Expression {
        return Expression.subtraction(lhs, rhs)
    }
    static func *(_ lhs: Expression, _ rhs: Expression) -> Expression {
        return Expression.multiplication(lhs, rhs)
    }
    static func /(_ lhs: Expression, _ rhs: Expression) -> Expression {
        return Expression.division(lhs, rhs)
    }
    var displayString: String {
        switch self {
        case .number(let value): return value.rawValue
        case .int(let value): return "\(value)"
        case .rational(let value): return "\(value)"
        case .real(let value): return "\(value)"
        case .addition(let lhs, let rhs): return lhs.displayString + " + " + rhs.displayString
        case .subtraction(let lhs, let rhs): return lhs.displayString + " - " + rhs.displayString
        case .multiplication(let lhs, let rhs): return lhs.displayString + " * " + rhs.displayString
        case .division(let lhs, let rhs): return lhs.displayString + " / " + rhs.displayString
        }
    }
}
extension Expression: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return displayString.thumbnailView(withFrame: frame, sizeType)
    }
}
extension Expression: Referenceable {
    static let name = Text(english: "Expression", japanese: "数式")
}

final class ExpressionView<T: BinderProtocol>: View, BindableGetterReceiver {
    typealias Model = Expression
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((ExpressionView<Binder>, BasicNotification) -> ())]()
    
    var sizeType: SizeType {
        didSet { updateLayout() }
    }
    
    init(binder: Binder, keyPath: BinderKeyPath,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        self.sizeType = sizeType
        
        super.init()
        self.frame = frame
    }
    func updateWithModel() {
        children = [TextFormView(text: Text(model.displayString))]
    }
}
