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

import Foundation

struct Variable {
    var rawValue: String
    init(_ rawValue: String) {
        self.rawValue = rawValue
    }
    static let x = Variable("x"), y = Variable("y"), z = Variable("z")
}
extension Variable: Referenceable {
    static let name = Text(english: "Variable", japanese: "変数")
}
extension Variable: Viewable {
    func view(withBounds bounds: Rect, _ sizeType: SizeType) -> View {
        return rawValue.view(withBounds: bounds, sizeType)
    }
}
struct Expression {
    enum Operator: String {
        case addition = "+", subtraction = "-", multiplication = "⋅", division = ""
    }
    var value: Viewable
    var nextOperator: Operator?
    var next: Expression? {
        get {
            return _expression as? Expression
        }
        set {
            _expression = newValue
        }
    }
    private var _expression: Any?
    init(_ value: Viewable) {
        self.value = value
    }
    static func +(_ lhs: Expression, _ rhs: Expression) -> Expression {
        var lhs = lhs
        lhs.next = rhs
        lhs.nextOperator = .addition
        return lhs
    }
}
extension Expression: Viewable {
    func view(withBounds bounds: Rect, _ sizeType: SizeType) -> View {
        return ExpressionView(expression: self, bounds: bounds, sizeType: sizeType)
    }
}
extension Expression: Referenceable {
    static let name = Text(english: "Expression", japanese: "数式")
}

final class ExpressionView: View {
    var expression: Expression
    
    init(expression: Expression = Expression(0), bounds: Rect = Rect(),
         sizeType: SizeType = .regular) {
        self.expression = expression
        
        super.init()
        var views = [View]()
        var ex = expression
        views.append(ex.value.view(withBounds: Rect(), sizeType))
        while let next = ex.next, let nextOperator = ex.nextOperator {
            if !(nextOperator == .multiplication && next.value is Variable) {
                views.append(nextOperator.rawValue.view(withBounds: Rect(), sizeType))
            }
            views.append(next.value.view(withBounds: Rect(), sizeType))
            ex = next
        }
        children = views
    }
    
    func reference(at p: Point) -> Reference {
        return Expression.reference
    }
}

func hypot²<T: BinaryFloatingPoint>(_ lhs: T, _ rhs: T) -> T {
    return lhs * lhs + rhs * rhs
}

protocol Interpolatable {
    static func linear(_ f0: Self, _ f1: Self, t: CGFloat) -> Self
    static func firstMonospline(_ f1: Self, _ f2: Self, _ f3: Self,
                                with ms: Monospline) -> Self
    static func monospline(_ f0: Self, _ f1: Self, _ f2: Self, _ f3: Self,
                           with ms: Monospline) -> Self
    static func lastMonospline(_ f0: Self, _ f1: Self, _ f2: Self,
                               with ms: Monospline) -> Self
}

struct Monospline {
    let h0: CGFloat, h1: CGFloat, h2: CGFloat
    let reciprocalH0: CGFloat, reciprocalH1: CGFloat, reciprocalH2: CGFloat
    let reciprocalH0H1: CGFloat, reciprocalH1H2: CGFloat, reciprocalH1H1: CGFloat
    private(set) var xx3: CGFloat, xx2: CGFloat, xx1: CGFloat
    var t: CGFloat {
        didSet {
            xx1 = h1 * t
            xx2 = xx1 * xx1
            xx3 = xx1 * xx1 * xx1
        }
    }
    init(x1: CGFloat, x2: CGFloat, x3: CGFloat, t: CGFloat) {
        h0 = 0
        h1 = x2 - x1
        h2 = x3 - x2
        reciprocalH0 = 0
        reciprocalH1 = 1 / h1
        reciprocalH2 = 1 / h2
        reciprocalH0H1 = 0
        reciprocalH1H2 = 1 / (h1 + h2)
        reciprocalH1H1 = 1 / (h1 * h1)
        xx1 = h1 * t
        xx2 = xx1 * xx1
        xx3 = xx1 * xx1 * xx1
        self.t = t
    }
    init(x0: CGFloat, x1: CGFloat, x2: CGFloat, x3: CGFloat, t: CGFloat) {
        h0 = x1 - x0
        h1 = x2 - x1
        h2 = x3 - x2
        reciprocalH0 = 1 / h0
        reciprocalH1 = 1 / h1
        reciprocalH2 = 1 / h2
        reciprocalH0H1 = 1 / (h0 + h1)
        reciprocalH1H2 = 1 / (h1 + h2)
        reciprocalH1H1 = 1 / (h1 * h1)
        xx1 = h1 * t
        xx2 = xx1 * xx1
        xx3 = xx1 * xx1 * xx1
        self.t = t
    }
    init(x0: CGFloat, x1: CGFloat, x2: CGFloat, t: CGFloat) {
        h0 = x1 - x0
        h1 = x2 - x1
        h2 = 0
        reciprocalH0 = 1 / h0
        reciprocalH1 = 1 / h1
        reciprocalH2 = 0
        reciprocalH0H1 = 1 / (h0 + h1)
        reciprocalH1H2 = 0
        reciprocalH1H1 = 1 / (h1 * h1)
        xx1 = h1 * t
        xx2 = xx1 * xx1
        xx3 = xx1 * xx1 * xx1
        self.t = t
    }
    
    func firstInterpolatedValue(_ f1: CGFloat, _ f2: CGFloat, _ f3: CGFloat) -> CGFloat {
        let s1 = (f2 - f1) * reciprocalH1, s2 = (f3 - f2) * reciprocalH2
        let signS1: CGFloat = s1 > 0 ? 1 : -1, signS2: CGFloat = s2 > 0 ? 1 : -1
        let yPrime1 = s1
        let yPrime2 = (signS1 + signS2) * min(abs(s1),
                                              abs(s2),
                                              0.5 * abs((h2 * s1 + h1 * s2) * reciprocalH1H2))
        return interpolatedValue(f1: f1, s1: s1, yPrime1: yPrime1, yPrime2: yPrime2)
    }
    func interpolatedValue(_ f0: CGFloat, _ f1: CGFloat, _ f2: CGFloat, _ f3: CGFloat) -> CGFloat {
        let s0 = (f1 - f0) * reciprocalH0
        let s1 = (f2 - f1) * reciprocalH1, s2 = (f3 - f2) * reciprocalH2
        let signS0: CGFloat = s0 > 0 ? 1 : -1
        let signS1: CGFloat = s1 > 0 ? 1 : -1, signS2: CGFloat = s2 > 0 ? 1 : -1
        let yPrime1 = (signS0 + signS1) * min(abs(s0),
                                              abs(s1),
                                              0.5 * abs((h1 * s0 + h0 * s1) * reciprocalH0H1))
        let yPrime2 = (signS1 + signS2) * min(abs(s1),
                                              abs(s2),
                                              0.5 * abs((h2 * s1 + h1 * s2) * reciprocalH1H2))
        return interpolatedValue(f1: f1, s1: s1, yPrime1: yPrime1, yPrime2: yPrime2)
    }
    func lastInterpolatedValue(_ f0: CGFloat, _ f1: CGFloat, _ f2: CGFloat) -> CGFloat {
        let s0 = (f1 - f0) * reciprocalH0, s1 = (f2 - f1) * reciprocalH1
        let signS0: CGFloat = s0 > 0 ? 1 : -1, signS1: CGFloat = s1 > 0 ? 1 : -1
        let yPrime1 = (signS0 + signS1) * min(abs(s0),
                                              abs(s1),
                                              0.5 * abs((h1 * s0 + h0 * s1) * reciprocalH0H1))
        let yPrime2 = s1
        return interpolatedValue(f1: f1, s1: s1, yPrime1: yPrime1, yPrime2: yPrime2)
    }
    private func interpolatedValue(f1: CGFloat, s1: CGFloat,
                                   yPrime1: CGFloat, yPrime2: CGFloat) -> CGFloat {
        let a = (yPrime1 + yPrime2 - 2 * s1) * reciprocalH1H1
        let b = (3 * s1 - 2 * yPrime1 - yPrime2) * reciprocalH1, c = yPrime1, d = f1
        return a * xx3 + b * xx2 + c * xx1 + d
    }
    
    func integralFirstInterpolatedValue(_ f1: CGFloat, _ f2: CGFloat, _ f3: CGFloat,
                                        a: CGFloat, b: CGFloat) -> CGFloat {
        let s1 = (f2 - f1) * reciprocalH1, s2 = (f3 - f2) * reciprocalH2
        let signS1: CGFloat = s1 > 0 ? 1 : -1, signS2: CGFloat = s2 > 0 ? 1 : -1
        let yPrime1 = s1
        let yPrime2 = (signS1 + signS2) * min(abs(s1),
                                              abs(s2),
                                              0.5 * abs((h2 * s1 + h1 * s2) * reciprocalH1H2))
        return integral(f1: f1, s1: s1, yPrime1: yPrime1, yPrime2: yPrime2, a: a, b: b)
    }
    func integralInterpolatedValue(_ f0: CGFloat, _ f1: CGFloat, _ f2: CGFloat, _ f3: CGFloat,
                                   a: CGFloat, b: CGFloat) -> CGFloat {
        let s0 = (f1 - f0) * reciprocalH0
        let s1 = (f2 - f1) * reciprocalH1, s2 = (f3 - f2) * reciprocalH2
        let signS0: CGFloat = s0 > 0 ? 1 : -1
        let signS1: CGFloat = s1 > 0 ? 1 : -1, signS2: CGFloat = s2 > 0 ? 1 : -1
        let yPrime1 = (signS0 + signS1) * min(abs(s0),
                                              abs(s1),
                                              0.5 * abs((h1 * s0 + h0 * s1) * reciprocalH0H1))
        let yPrime2 = (signS1 + signS2) * min(abs(s1),
                                              abs(s2),
                                              0.5 * abs((h2 * s1 + h1 * s2) * reciprocalH1H2))
        return integral(f1: f1, s1: s1, yPrime1: yPrime1, yPrime2: yPrime2, a: a, b: b)
    }
    func integralLastInterpolatedValue(_ f0: CGFloat, _ f1: CGFloat, _ f2: CGFloat,
                                       a: CGFloat, b: CGFloat) -> CGFloat {
        let s0 = (f1 - f0) * reciprocalH0, s1 = (f2 - f1) * reciprocalH1
        let signS0: CGFloat = s0 > 0 ? 1 : -1, signS1: CGFloat = s1 > 0 ? 1 : -1
        let yPrime1 = (signS0 + signS1) * min(abs(s0),
                                              abs(s1),
                                              0.5 * abs((h1 * s0 + h0 * s1) * reciprocalH0H1))
        let yPrime2 = s1
        return integral(f1: f1, s1: s1, yPrime1: yPrime1, yPrime2: yPrime2, a: a, b: b)
    }
    private func integral(f1: CGFloat, s1: CGFloat, yPrime1: CGFloat, yPrime2: CGFloat,
                          a xa: CGFloat, b xb: CGFloat) -> CGFloat {
        let a = (yPrime1 + yPrime2 - 2 * s1) * reciprocalH1H1
        let b = (3 * s1 - 2 * yPrime1 - yPrime2) * reciprocalH1, c = yPrime1, nd = f1
        
        let xa2 = xa * xa, xb2 = xb * xb, h1_2 = h1 * h1
        let xa3 = xa2 * xa, xb3 = xb2 * xb, h1_3 = h2 * h1
        let xa4 = xa3 * xa, xb4 = xb3 * xb
        let na = a * h1_3 / 4, nb = b * h1_2 / 3, nc = c * h1 / 2
        let fa = na * xa4 + nb * xa3 + nc * xa2 + nd * xa
        let fb = nb * xb4 + nb * xb3 + nc * xb2 + nd * xb
        return fb - fa
    }
}

extension Comparable {
    func clip(min: Self, max: Self) -> Self {
        return self < min ? min : (self > max ? max : self)
    }
    func isOver(old: Self, new: Self) -> Bool {
        return (new >= self && old < self) || (new <= self && old > self)
    }
}

protocol NumberGetterOption {
    associatedtype Model
    func string(with model: Model) -> String
    func text(with model: Model) -> Text
}
protocol OneDimensionalOption: NumberGetterOption {
    associatedtype Model
    var defaultModel: Model { get }
    var minModel: Model { get }
    var maxModel: Model { get }
    func model(with string: String) -> Model?
    func ratio(with model: Model) -> CGFloat
    func ratioFromDefaultModel(with model: Model) -> CGFloat
    func model(withDelta delta: CGFloat, oldModel: Model) -> Model
    func model(withRatio ratio: CGFloat) -> Model
}

enum Orientation {
    case leftHanded, rightHanded
}

/**
 Issue: スクロールによる値の変更
 */
final class DiscreteOneDimensionalView
    <T: Comparable & Viewable & Referenceable, U: OneDimensionalOption>: View, Assignable, Runnable, Movable where U.Model == T {
    var model: T {
        didSet {
            updateWithModel()
        }
    }
    var option: U
    
    enum LayoutOrientation {
        case horizontal, vertical
    }
    var sizeType: SizeType
    var interval = 1.5.cg
    var orientation: Orientation, layoutOrientation: LayoutOrientation
    private var knobLineFrame = Rect()
    private let labelPaddingX: CGFloat, knobPadding: CGFloat
    private let knobView = DiscreteKnobView(Size(width: 6, height: 4), lineWidth: 1)
    private let linePathView: View = {
        let linePathView = View(isForm: true)
        linePathView.lineColor = .content
        return linePathView
    } ()
    let formStringView: TextView
    
    init(model: T, option: U,
         orientation: Orientation = .rightHanded,
         layoutOrientation: LayoutOrientation = .horizontal,
         frame: Rect = Rect(),
         sizeType: SizeType = .regular) {
        
        self.model = model.clip(min: option.minModel, max: option.maxModel)
        self.option = option
        self.orientation = orientation
        self.layoutOrientation = layoutOrientation
        self.knobPadding = sizeType == .small ? 2 : 3
        labelPaddingX = Layout.padding(with: sizeType)
        formStringView = TextView(font: Font.default(with: sizeType),
                                  frameAlignment: .right, alignment: .right)
        self.sizeType = sizeType
        
        super.init()
        updateWithModel()
        isClipped = true
        children = [formStringView, linePathView, knobView]
        self.frame = frame
    }
    
    override var bounds: Rect {
        didSet {
            updateLayout()
        }
    }
    private func updateLayout() {
        let paddingX = sizeType == .small ? 3.0.cg : 5.0.cg
        knobLineFrame = Rect(x: paddingX, y: sizeType == .small ? 1 : 2,
                               width: bounds.width - paddingX * 2, height: 1)
        linePathView.frame = knobLineFrame
        formStringView.frame.origin = Point(x: bounds.width - formStringView.frame.width - labelPaddingX,
                                          y: round((bounds.height - formStringView.frame.height) / 2))
    }
    func updateWithModel() {
        updateString()
        updateknob()
    }
    func updateString() {
        formStringView.text = option.text(with: model)
    }
    func updateknob() {
        let x = knobLineFrame.width * option.ratioFromDefaultModel(with: model) + knobLineFrame.minX
        knobView.position = Point(x: round(x), y: knobPadding)
    }
    
    private func model(at p: Point, old oldModel: T) -> T {
        let d = layoutOrientation == .vertical ? p.y - oldPoint.y : p.x - oldPoint.x
        let delta = orientation == .rightHanded ? d : -d
        return option.model(withDelta: delta / interval, oldModel: oldModel)
    }
    
    var disabledRegisterUndo = false
    
    struct Binding<T> {
        let view: DiscreteOneDimensionalView, model: T, oldModel: T, phase: Phase
    }
    var binding: ((Binding<T>) -> ())?
    
    func delete(for p: Point) {
        let model = option.defaultModel.clip(min: option.minModel, max: option.maxModel)
        if model != self.model {
            set(model, old: self.model)
        }
    }
    func copiedViewables(at p: Point) -> [Viewable] {
        return [model]
    }
    func paste(_ objects: [Any], for p: Point) {
        for object in objects {
            if let model = (object as? T)?.clip(min: option.minModel, max: option.maxModel) {
                if model != self.model {
                    set(model, old: self.model)
                    return
                }
            } else if let string = object as? String {
                if let model = option.model(with: string)?.clip(min: option.minModel,
                                                                max: option.maxModel) {
                    if model != self.model {
                        set(model, old: self.model)
                        return
                    }
                }
            }
        }
    }
    
    func run(for p: Point) {
        let model = self.model(at: p, old: self.model)
        if model != self.model {
            set(model, old: self.model)
        }
    }
    
    private var oldModel: T?, oldPoint = Point()
    func move(for p: Point, pressure: CGFloat, time: Second, _ phase: Phase) {
        switch phase {
        case .began:
            knobView.fillColor = .editing
            let oldModel = model
            self.oldModel = oldModel
            oldPoint = p
            binding?(Binding(view: self, model: model, oldModel: oldModel, phase: .began))
            model = self.model(at: p, old: oldModel)
            binding?(Binding(view: self, model: model, oldModel: oldModel, phase: .changed))
        case .changed:
            guard let oldModel = oldModel else {
                return
            }
            model = self.model(at: p, old: oldModel)
            binding?(Binding(view: self, model: model, oldModel: oldModel, phase: .changed))
        case .ended:
            guard let oldModel = oldModel else {
                return
            }
            model = self.model(at: p, old: oldModel)
            if model != oldModel {
                registeringUndoManager?.registerUndo(withTarget: self) { [model, oldModel] in
                    $0.set(oldModel, old: model)
                }
            }
            binding?(Binding(view: self, model: model, oldModel: oldModel, phase: .ended))
            knobView.fillColor = .knob
        }
    }
    
    private func set(_ model: T, old oldModel: T) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldModel, old: model) }
        binding?(Binding(view: self, model: oldModel, oldModel: oldModel, phase: .began))
        self.model = model
        binding?(Binding(view: self, model: model, oldModel: oldModel, phase: .ended))
    }
    
    func reference(at p: Point) -> Reference {
        var reference = T.reference
        reference.viewDescription = Localization(english: "Discrete Slider", japanese: "離散スライダー")
        return reference
    }
}

final class NumberGetterView<T: Comparable & Viewable & Referenceable, U: NumberGetterOption>: View, Copiable where U.Model == T {
    var model: T {
        didSet {
            updateWithModel()
        }
    }
    var option: U
    
    var sizeType: SizeType
    var formPropertyNameView: TextView?
    let formStringView: TextView
    var orientation: Orientation
    private let labelPaddingX: CGFloat
    
    init(model: T, option: U,
         orientation: Orientation = .rightHanded,
         frame: Rect = Rect(),
         sizeType: SizeType = .regular) {
        
        self.model = model
        self.option = option
        self.orientation = orientation
        labelPaddingX = Layout.padding(with: sizeType)
        formStringView = TextView(font: Font.default(with: sizeType),
                                  frameAlignment: .right, alignment: .right)
        self.sizeType = sizeType
        
        super.init()
        noIndicatedLineColor = .getBorder
        indicatedLineColor = .indicated
        isClipped = true
        children = [formStringView]
        self.frame = frame
    }
    
    override var defaultBounds: Rect {
        return formStringView.defaultBounds
    }
    override var bounds: Rect {
        didSet {
            updateLayout()
        }
    }
    private func updateLayout() {
        formStringView.frame.origin = Point(x: bounds.width - formStringView.frame.width - labelPaddingX,
                                            y: round((bounds.height - formStringView.frame.height) / 2))
    }
    func updateWithModel() {
        updateString()
    }
    func updateString() {
        formStringView.text = option.text(with: model)
    }
    
    func copiedViewables(at p: Point) -> [Viewable] {
        return [model]
    }
    
    func reference(at p: Point) -> Reference {
        return T.reference
    }
}

protocol AdditiveGroup: Equatable {
    static func +(lhs: Self, rhs: Self) -> Self
    static func -(lhs: Self, rhs: Self) -> Self
    prefix static func -(x: Self) -> Self
}
extension AdditiveGroup {
    static func -(lhs: Self, rhs: Self) -> Self {
        return (lhs + (-rhs))
    }
}

extension Int {
    static func gcd(_ m: Int, _ n: Int) -> Int {
        return n == 0 ? m : gcd(n, m % n)
    }
}
extension Int: Interpolatable {
    static func linear(_ f0: Int, _ f1: Int, t: CGFloat) -> Int {
        return Int(CGFloat.linear(CGFloat(f0), CGFloat(f1), t: t))
    }
    static func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) -> Int {
        return Int(CGFloat.firstMonospline(CGFloat(f1), CGFloat(f2), CGFloat(f3), with: ms))
    }
    static func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) -> Int {
        return Int(CGFloat.monospline(CGFloat(f0), CGFloat(f1), CGFloat(f2), CGFloat(f3), with: ms))
    }
    static func lastMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with ms: Monospline) -> Int {
        return Int(CGFloat.lastMonospline(CGFloat(f0), CGFloat(f1), CGFloat(f2), with: ms))
    }
}
extension Int: Referenceable {
    static let name = Localization(english: "Integer", japanese: "整数")
}
extension Int: ObjectViewExpression {
    func thumbnail(withBounds bounds: Rect, _ sizeType: SizeType) -> View {
        return String(self).view(withBounds: bounds, sizeType)
    }
}

struct Hash {
    static func uniformityHashValue(with hashValues: [Int]) -> Int {
        return Int(bitPattern: hashValues.reduce(into: UInt(bitPattern: 0), unionHashValues))
    }
    static func unionHashValues(_ lhs: inout UInt, _ rhs: Int) {
        #if arch(arm64) || arch(x86_64)
            let magicValue: UInt = 0x9e3779b97f4a7c15
        #else
            let magicValue: UInt = 0x9e3779b9
        #endif
        let urhs = UInt(bitPattern: rhs)
        lhs ^= urhs &+ magicValue &+ (lhs << 6) &+ (lhs >> 2)
    }
}

extension CGFloat {
    func interval(scale: CGFloat) -> CGFloat {
        if scale == 0 {
            return self
        } else {
            let t = floor(self / scale) * scale
            return self - t > scale / 2 ? t + scale : t
        }
    }
    func differenceRotation(_ other: CGFloat) -> CGFloat {
        let a = self - other
        return a + (a > .pi ? -2 * (.pi) : (a < -.pi ? 2 * (.pi) : 0))
    }
    var clipRotation: CGFloat {
        return self < -.pi ? self + 2 * (.pi) : (self > .pi ? self - 2 * (.pi) : self)
    }
    func isApproximatelyEqual(other: CGFloat, roundingError: CGFloat = 0.0000000001) -> Bool {
        return abs(self - other) < roundingError
    }
    var ²: CGFloat {
        return self * self
    }
    func loopValue(other: CGFloat, begin: CGFloat = 0, end: CGFloat = 1) -> CGFloat {
        if other < self {
            let value = (other - begin) + (end - self)
            return self - other < value ? self : self - (end - begin)
        } else {
            let value = (self - begin) + (end - other)
            return other - self < value ? self : self + (end - begin)
        }
    }
    func loopValue(begin: CGFloat = 0, end: CGFloat = 1) -> CGFloat {
        return self < begin ? self + (end - begin) : (self > end ? self - (end - begin) : self)
    }
    static func random(min: CGFloat, max: CGFloat) -> CGFloat {
        return (max - min) * (CGFloat(arc4random_uniform(UInt32.max)) / CGFloat(UInt32.max)) + min
    }
    static func bilinear(x: CGFloat, y: CGFloat,
                         a: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat) -> CGFloat {
        return x * y * (a - b - c + d) + x * (b - a) + y * (c - a) + a
    }
    
    static func simpsonIntegral(splitHalfCount m: Int, a: CGFloat, b: CGFloat,
                                f: (CGFloat) -> (CGFloat)) -> CGFloat {
        let n = CGFloat(2 * m)
        let h = (b - a) / n
        func x(at i: Int) -> CGFloat {
            return a + CGFloat(i) * h
        }
        let s0 = 2 * (1..<m - 1).reduce(0.0.cg) { $0 + f(x(at: 2 * $1)) }
        let s1 = 4 * (1..<m).reduce(0.0.cg) { $0 + f(x(at: 2 * $1 - 1)) }
        return (h / 3) * (f(a) + s0 + s1 + f(b))
    }
    static func simpsonIntegralB(splitHalfCount m: Int, a: CGFloat, maxB: CGFloat,
                                 s: CGFloat, bisectionCount: Int = 3,
                                 f: (CGFloat) -> (CGFloat)) -> CGFloat {
        let n = 2 * m
        let h = (maxB - a) / CGFloat(n)
        func x(at i: Int) -> CGFloat {
            return a + CGFloat(i) * h
        }
        let h3 = h / 3
        var a = a
        var fa = f(a), allS = 0.0.cg
        for i in (0..<m) {
            let ab = x(at: i * 2 + 1), b = x(at: i * 2 + 2)
            let fab = f(ab), fb = f(b)
            let abS = fa + 4 * fab + fb
            let nAllS = allS + abS
            if h3 * nAllS >= s {
                let hAllS = h3 * allS
                var bA = a, bB = b
                var fbA = fa
                for _ in (0..<bisectionCount) {
                    let bAB = (bA + bB) / 2
                    let bS = fbA + 4 * f((bA + bAB) / 2) + f(bAB)
                    let hBS = hAllS + ((bB - bA) / 6) * bS
                    if hBS >= s {
                        bA = bAB
                        fbA = f(bA)
                    } else {
                        bB = bAB
                    }
                }
                return bA
            }
            allS = nAllS
            a = b
            fa = fb
        }
        return maxB
    }
}
extension CGFloat: Interpolatable {
    static func linear(_ f0: CGFloat, _ f1: CGFloat, t: CGFloat) -> CGFloat {
        return f0 * (1 - t) + f1 * t
    }
    static func firstMonospline(_ f1: CGFloat, _ f2: CGFloat, _ f3: CGFloat,
                                with ms: Monospline) -> CGFloat {
        return ms.firstInterpolatedValue(f1, f2, f3)
    }
    static func monospline(_ f0: CGFloat, _ f1: CGFloat, _ f2: CGFloat, _ f3: CGFloat,
                           with ms: Monospline) -> CGFloat {
        return ms.interpolatedValue(f0, f1, f2, f3)
    }
    static func lastMonospline(_ f0: CGFloat, _ f1: CGFloat, _ f2: CGFloat,
                              with ms: Monospline) -> CGFloat {
        return ms.lastInterpolatedValue(f0, f1, f2)
    }
    
    static func integralLinear(_ f0: CGFloat, _ f1: CGFloat, a: CGFloat, b: CGFloat) -> CGFloat {
        let f01 = f1 - f0
        let fa = a * (f01 * a / 2 + f0)
        let fb = b * (f01 * b / 2 + f0)
        return fb - fa
    }
}

extension CGAffineTransform {
    static func centering(from fromFrame: Rect,
                          to toFrame: Rect) -> (scale: CGFloat, affine: CGAffineTransform) {
        guard !fromFrame.isEmpty && !toFrame.isEmpty else {
            return (1, CGAffineTransform.identity)
        }
        var affine = CGAffineTransform.identity
        let fromRatio = fromFrame.width / fromFrame.height
        let toRatio = toFrame.width / toFrame.height
        if fromRatio > toRatio {
            let xScale = toFrame.width / fromFrame.size.width
            let y = toFrame.origin.y + (toFrame.height - fromFrame.height * xScale) / 2
            affine = affine.translatedBy(x: toFrame.origin.x, y: y)
            affine = affine.scaledBy(x: xScale, y: xScale)
            return (xScale, affine.translatedBy(x: -fromFrame.origin.x, y: -fromFrame.origin.y))
        } else {
            let yScale = toFrame.height / fromFrame.size.height
            let x = toFrame.origin.x + (toFrame.width - fromFrame.width * yScale) / 2
            affine = affine.translatedBy(x: x, y: toFrame.origin.y)
            affine = affine.scaledBy(x: yScale, y: yScale)
            return (yScale, affine.translatedBy(x: -fromFrame.origin.x, y: -fromFrame.origin.y))
        }
    }
    func flippedHorizontal(by width: CGFloat) -> CGAffineTransform {
        return translatedBy(x: width, y: 0).scaledBy(x: -1, y: 1)
    }
}
