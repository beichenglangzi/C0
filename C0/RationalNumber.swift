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

typealias Q = RationalNumber
struct RationalNumber: AdditiveGroup, SignedNumeric {
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
    init(_ x: Double, maxDenominator: Int = 10000000, tolerance: Double = 0.000001) {
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
    
    static func continuedFractions(with x: Double, maxCount: Int = 32) -> [Int] {
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
    
    var inversed: RationalNumber? {
        return p == 0 ? nil : RationalNumber(q, p)
    }
    var integralPart: Int {
        return p / q
    }
    var decimalPart: RationalNumber {
        return self - RationalNumber(integralPart)
    }
    var isInteger: Bool {
        return q == 1
    }
    var integerAndProperFraction: (integer: Int, properFraction: RationalNumber) {
        let i = integralPart
        return isInteger ? (i, RationalNumber(0, 1)) : (i, self - RationalNumber(i))
    }
    func interval(scale: RationalNumber) -> RationalNumber {
        if scale == 0 {
            return self
        } else {
            let t = floor(self / scale) * scale
            return self - t > scale / 2 ? t + scale : t
        }
    }
    
    var magnitude: RationalNumber {
        return RationalNumber(abs(p), q)
    }
    typealias Magnitude = RationalNumber
    
    static func +(lhs: RationalNumber, rhs: RationalNumber) -> RationalNumber {
        return RationalNumber(lhs.p * rhs.q + lhs.q * rhs.p, lhs.q * rhs.q)
    }
    static func +=(lhs: inout RationalNumber, rhs: RationalNumber) {
        lhs = lhs + rhs
    }
    static func -=(lhs: inout RationalNumber, rhs: RationalNumber) {
        lhs = lhs - rhs
    }
    static func *=(lhs: inout RationalNumber, rhs: RationalNumber) {
        lhs = lhs * rhs
    }
    prefix static func -(x: RationalNumber) -> RationalNumber {
        return RationalNumber(-x.p, x.q)
    }
    static func *(lhs: RationalNumber, rhs: RationalNumber) -> RationalNumber {
        return RationalNumber(lhs.p * rhs.p, lhs.q * rhs.q)
    }
    static func /(lhs: RationalNumber, rhs: RationalNumber) -> RationalNumber {
        return RationalNumber(lhs.p * rhs.q, lhs.q * rhs.p)
    }
}
extension RationalNumber {
    static let basicEffectiveFieldOfView = Q(152, 100)
}
extension RationalNumber: Equatable {
    static func ==(lhs: RationalNumber, rhs: RationalNumber) -> Bool {
        return lhs.p * rhs.q == lhs.q * rhs.p
    }
}
extension RationalNumber: Comparable {
    static func <(lhs: RationalNumber, rhs: RationalNumber) -> Bool {
        return lhs.p * rhs.q < rhs.p * lhs.q
    }
}
extension RationalNumber: Hashable {
    var hashValue: Int {
        return Hash.uniformityHashValue(with: [p.hashValue, q.hashValue])
    }
}
extension RationalNumber: Codable {
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
extension RationalNumber: Referenceable {
    static let name = Localization(english: "Rational RealNumber", japanese: "有理数")
}
extension RationalNumber: ObjectViewExpression {
    func thumbnail(withBounds bounds: CGRect, sizeType: SizeType) -> Layer {
        return description.view(withBounds: bounds, sizeType: sizeType)
    }
}
extension RationalNumber: CustomStringConvertible {
    var description: String {
        switch q {
        case 1:  return "\(p)"
        default: return "\(p)/\(q)"
        }
    }
}
extension RationalNumber: ExpressibleByIntegerLiteral {
    typealias IntegerLiteralType = Int
    init(integerLiteral value: Int) {
        self.init(value)
    }
}
extension Double {
    init(_ x: RationalNumber) {
        self = Double(x.p) / Double(x.q)
    }
}
func floor(_ x: RationalNumber) -> RationalNumber {
    let i = x.integralPart
    return RationalNumber(x.decimalPart.p == 0 ? i : (x < 0 ? i - 1 : i))
}
func ceil(_ x: RationalNumber) -> RationalNumber {
    return RationalNumber(x.decimalPart.p == 0 ? x.integralPart : x.integralPart + 1)
}
extension RationalNumber: ViewExpression {
    func view(withBounds bounds: CGRect, sizeType: SizeType) -> View {
        return RationalNumberView(rationalNumber: self, frame: bounds, sizeType: sizeType)
    }
}

final class RationalNumberView: View {
    var rationalNumber: RationalNumber {
        didSet {
            updateWithRationalNumber()
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
            updateWithRationalNumber()
        }
    }
    
    var sizeType: SizeType
    let integerView: RealNumberView
    let formPlusView: TextView
    let pView: RealNumberView, qView: RealNumberView
    let unitView: TextView
    let formLinePathView = PathLayer()
    
    init(rationalNumber: RationalNumber = 0,
         isIntegerAndProperFraction: Bool = true, unit: String = "",
         frame: CGRect = CGRect(), sizeType: SizeType = .regular) {
        
        self.rationalNumber = rationalNumber
        self.isIntegerAndProperFraction = isIntegerAndProperFraction
        self.unit = unit
        self.sizeType = sizeType
        integerView = RealNumberView(sizeType: sizeType)
        formPlusView = TextView(text: Text("+"), font: Font.default(with: sizeType))
        pView = RealNumberView(sizeType: sizeType)
        qView = RealNumberView(sizeType: sizeType)
        unitView = TextView(text: Text(unit), font: Font.default(with: sizeType))
        
        super.init()
        isClipped = true
        updateChildren()
        self.frame = frame
    }
    
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    private func updateChildren() {
        if isIntegerAndProperFraction {
            replace(children: [integerView, formPlusView, pView, formLinePathView, qView])
        } else {
            replace(children: [pView, formLinePathView, qView])
        }
    }
    private func updateLayout() {
        updateWithRationalNumber()
    }
    private func updateWithRationalNumber() {
        if isIntegerAndProperFraction {
            let (integer, properFraction) = rationalNumber.integerAndProperFraction
            integerView.number = integer.cf
            pView.number = properFraction.p.cf
            qView.number = properFraction.q.cf
        } else {
            pView.number = rationalNumber.p.cf
            qView.number = rationalNumber.q.cf
        }
        
        let padding = Layout.padding(with: sizeType)
        if isIntegerAndProperFraction {
            
        } else {
            pView.frame.origin = CGPoint(x: padding, y: padding)
        }
    }
    
    func copiedObjects(with event: KeyInputEvent) -> [ViewExpression]? {
        return [rationalNumber, rationalNumber.description]
    }
    
    func reference(with event: TapEvent) -> Reference? {
        return rationalNumber.reference
    }
}

struct RationalNumberOption: OneDimensionalOption {
    typealias Model = RationalNumber
    
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
    func text(with model: Model) -> Localization {
        return Localization("\(model)\(unit)")
    }
    func ratio(with model: Model) -> CGFloat {
        return Double((model - minModel) / (maxModel - minModel)).cf
    }
    func ratioFromDefaultModel(with model: Model) -> CGFloat {
        if model < defaultModel {
            return Double((model - minModel) / (defaultModel - minModel)).cf * 0.5
        } else {
            return Double((model - defaultModel) / (maxModel - defaultModel)).cf * 0.5 + 0.5
        }
    }
    
    private func model(withDelta delta: CGFloat) -> Model {
        let d = Model(delta.d) * modelInterval
        return d.interval(scale: modelInterval)
    }
    func model(withDelta delta: CGFloat, oldModel: Model) -> Model {
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
    func model(withRatio ratio: CGFloat) -> Model {
        return (maxModel - minModel) * RationalNumber(ratio.d) + minModel
    }
}
typealias DiscreteRationalNumberView = DiscreteOneDimensionalView<RationalNumber, RationalNumberOption>
