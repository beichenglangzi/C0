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

struct Rational: AdditiveGroup, SignedNumeric {
    var p, q: Int
    init(_ p: Int, _ q: Int) {
        guard q != 0 else {
            fatalError("Division by zero")
        }
        let d = abs(Int.gcd(p, q)) * (q / abs(q))
        (self.p, self.q) = d == 1 ? (p, q) : (p / d, q / d)
    }
    init(_ n: Int) {
        self.init(n, 1)
    }
    init?<T>(exactly source: T) where T : BinaryInteger {
        if let integer = Int(exactly: source) {
            self.init(integer)
        } else {
            return nil
        }
    }
    init(_ x: Real, maxDenominator: Int = 10000000, tolerance: Real = 0.000001) {
        var x = x
        var a = floor(x)
        var p1 = Int(a), q1 = 1
        if fabs(x - a) < tolerance {
            self.init(p1, q1)
            return
        }
        x = 1 / (x - a)
        a = floor(x)
        var p0 = 1, q0 = 0
        while true {
            let ia = Int(a)
            let pn = ia * p1 + p0
            let qn = ia * q1 + q0
            (p0, q0) = (p1, q1)
            (p1, q1) = (pn, qn)
            
            if qn > maxDenominator || abs(x - a) < 0.000001 {
                self.init(pn, qn)
                return
            }
            x = 1 / (x - a)
            a = floor(x)
        }
        fatalError()
    }
    
    static func continuedFractions(with x: Real, maxCount: Int = 32) -> [Int] {
        var x = x, cfs = [Int]()
        var a = floor(x)
        for _ in 0..<maxCount {
            cfs.append(Int(a))
            if abs(x - a) < 0.000001 {
                break
            }
            x = 1 / (x - a)
            a = floor(x)
        }
        return cfs
    }
    
    var inversed: Rational? {
        return p == 0 ? nil : Rational(q, p)
    }
    var integralPart: Int {
        return p / q
    }
    var decimalPart: Rational {
        return self - Rational(integralPart)
    }
    var isInteger: Bool {
        return q == 1
    }
    var integerAndProperFraction: (integer: Int, properFraction: Rational) {
        let i = integralPart
        return isInteger ? (i, Rational(0, 1)) : (i, self - Rational(i))
    }
    func interval(scale: Rational) -> Rational {
        if scale == 0 {
            return self
        } else {
            let t = floor(self / scale) * scale
            return self - t > scale / 2 ? t + scale : t
        }
    }
    
    var magnitude: Rational {
        return Rational(abs(p), q)
    }
    typealias Magnitude = Rational
    
    static func +(lhs: Rational, rhs: Rational) -> Rational {
        return Rational(lhs.p * rhs.q + lhs.q * rhs.p, lhs.q * rhs.q)
    }
    static func +=(lhs: inout Rational, rhs: Rational) {
        lhs = lhs + rhs
    }
    static func -=(lhs: inout Rational, rhs: Rational) {
        lhs = lhs - rhs
    }
    static func *=(lhs: inout Rational, rhs: Rational) {
        lhs = lhs * rhs
    }
    prefix static func -(x: Rational) -> Rational {
        return Rational(-x.p, x.q)
    }
    static func *(lhs: Rational, rhs: Rational) -> Rational {
        return Rational(lhs.p * rhs.p, lhs.q * rhs.q)
    }
    static func /(lhs: Rational, rhs: Rational) -> Rational {
        return Rational(lhs.p * rhs.q, lhs.q * rhs.p)
    }
}
extension Rational {
    static let basicEffectiveFieldOfView = Rational(152, 100)
}
extension Rational: Equatable {
    static func ==(lhs: Rational, rhs: Rational) -> Bool {
        return lhs.p * rhs.q == lhs.q * rhs.p
    }
}
extension Rational: Comparable {
    static func <(lhs: Rational, rhs: Rational) -> Bool {
        return lhs.p * rhs.q < rhs.p * lhs.q
    }
}
extension Rational: Hashable {
    var hashValue: Int {
        return Hash.uniformityHashValue(with: [p.hashValue, q.hashValue])
    }
}
extension Rational: Codable {
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let p = try container.decode(Int.self)
        let q = try container.decode(Int.self)
        self.init(p, q)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(p)
        try container.encode(q)
    }
}
extension Rational: Referenceable {
    static let name = Text(english: "Rational Number (\(MemoryLayout<Rational>.size * 8)bit)",
                                   japanese: "有理数 (\(MemoryLayout<Rational>.size * 8)bit)")
}
extension Rational: ObjectViewExpression {
    func thumbnail(withBounds bounds: Rect, _ sizeType: SizeType) -> View {
        return description.view(withBounds: bounds, sizeType)
    }
}
extension Rational: CustomStringConvertible {
    var description: String {
        switch q {
        case 1:  return "\(p)"
        default: return "\(p)/\(q)"
        }
    }
}
extension Rational: ExpressibleByIntegerLiteral {
    typealias IntegerLiteralType = Int
    init(integerLiteral value: Int) {
        self.init(value)
    }
}
extension Real {
    init(_ x: Rational) {
        self = Real(x.p) / Real(x.q)
    }
}
func floor(_ x: Rational) -> Rational {
    let i = x.integralPart
    return Rational(x.decimalPart.p == 0 ? i : (x < 0 ? i - 1 : i))
}
func ceil(_ x: Rational) -> Rational {
    return Rational(x.decimalPart.p == 0 ? x.integralPart : x.integralPart + 1)
}

final class RationalView: View, Queryable, Copiable {
    var rational: Rational {
        didSet {
            updateWithRational()
        }
    }
    
    var isIntegerAndProperFraction: Bool {
        didSet {
            if isIntegerAndProperFraction != oldValue {
                updateChildren()
            }
        }
    }
    var unit: String {
        didSet {
            updateWithRational()
        }
    }
    
    var sizeType: SizeType
    let integerView: IntView
    let formPlusView: TextView
    let pView: IntView, qView: IntView
    let unitView: TextView
    let formLinePathView = View(path: CGMutablePath())
    
    init(rational: Rational = 0,
         isIntegerAndProperFraction: Bool = true, unit: String = "",
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.rational = rational
        self.isIntegerAndProperFraction = isIntegerAndProperFraction
        self.unit = unit
        self.sizeType = sizeType
        integerView = IntView(model: 0, option: IntGetterOption(unit: ""), sizeType: sizeType)
        formPlusView = TextView(text: "+", font: Font.default(with: sizeType))
        pView = IntView(model: 0, option: IntGetterOption(unit: ""), sizeType: sizeType)
        qView = IntView(model: 1, option: IntGetterOption(unit: ""), sizeType: sizeType)
        unitView = TextView(text: Text(unit), font: Font.default(with: sizeType))
        
        super.init()
        isClipped = true
        updateChildren()
        self.frame = frame
    }
    
    override var bounds: Rect {
        didSet {
            updateLayout()
        }
    }
    private func updateChildren() {
        if isIntegerAndProperFraction {
            children = [integerView, formPlusView, pView, formLinePathView, qView]
        } else {
            children = [pView, formLinePathView, qView]
        }
    }
    private func updateLayout() {
        updateWithRational()
    }
    private func updateWithRational() {
        if isIntegerAndProperFraction {
            let (integer, properFraction) = rational.integerAndProperFraction
            integerView.model = integer
            pView.model = properFraction.p
            qView.model = properFraction.q
        } else {
            pView.model = rational.p
            qView.model = rational.q
        }
        
        let padding = Layout.padding(with: sizeType)
        if isIntegerAndProperFraction {
            
        } else {
            pView.frame.origin = Point(x: padding, y: padding)
        }
    }
    
    func copiedViewables(at p: Point) -> [Viewable] {
        return [rational]
    }
    
    func reference(at p: Point) -> Reference {
        return Rational.reference
    }
}

struct RationalOption: OneDimensionalOption {
    typealias Model = Rational
    
    var defaultModel: Model
    var minModel: Model
    var maxModel: Model
    var modelInterval: Model
    
    var isInfinitesimal: Bool
    var unit: String
    
    func model(with string: String) -> Model? {
        return nil
    }
    func string(with model: Model) -> String {
        return "\(model)"
    }
    func text(with model: Model) -> Text {
        return Text("\(model)\(unit)")
    }
    func ratio(with model: Model) -> Real {
        return Real((model - minModel) / (maxModel - minModel))
    }
    func ratioFromDefaultModel(with model: Model) -> Real {
        if model < defaultModel {
            return Real((model - minModel) / (defaultModel - minModel)) * 0.5
        } else {
            return Real((model - defaultModel) / (maxModel - defaultModel)) * 0.5 + 0.5
        }
    }
    
    private func model(withDelta delta: Real) -> Model {
        let d = Model(delta) * modelInterval
        return d.interval(scale: modelInterval)
    }
    func model(withDelta delta: Real, oldModel: Model) -> Model {
        let newModel: Model
        if isInfinitesimal {
            if oldModel.q == 1 {
                let p = oldModel.p - Int(delta)
                newModel = p < 1 ? Beat(1, 2 - p) : Beat(p)
            } else {
                let q = oldModel.q + Int(delta)
                newModel = q < 1 ? Beat(2 - q) : Beat(1, q)
            }
        } else {
            newModel = oldModel.interval(scale: modelInterval) + model(withDelta: delta)
        }
        return newModel.clip(min: minModel, max: maxModel)
    }
    func model(withRatio ratio: Real) -> Model {
        return (maxModel - minModel) * Rational(ratio) + minModel
    }
}
typealias DiscreteRationalView = DiscreteOneDimensionalView<Rational, RationalOption>
