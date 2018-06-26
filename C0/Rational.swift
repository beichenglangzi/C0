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

struct Rational: AdditiveGroup, SignedNumeric {
    var p, q: Int
    
    init() {
        p = 0
        q = 1
    }
    init(_ p: Int, _ q: Int) {
        guard q != 0 else { fatalError("Division by zero") }
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
        var a = x.rounded(.down)
        var p0 = 1, q0 = 0, p1 = Int(a), q1 = 1
        while abs(x - a) >= tolerance {
            x = 1 / (x - a)
            a = x.rounded(.down)
            let ia = Int(a)
            let p2 = ia * p1 + p0
            let q2 = ia * q1 + q0
            if q2 > maxDenominator {
                self.init(p2, q2)
                return
            }
            (p0, q0) = (p1, q1)
            (p1, q1) = (p2, q2)
        }
        self.init(p1, q1)
    }
}
extension Rational {
    static func continuedFractions(with x: Real, maxCount: Int = 32) -> [Int] {
        var x = x, cfs = [Int]()
        var a = x.rounded(.down)
        for _ in 0..<maxCount {
            cfs.append(Int(a))
            if abs(x - a) < 0.000001 {
                break
            }
            x = 1 / (x - a)
            a = x.rounded(.down)
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
    
    static var min: Rational {
        return Rational(Int(Int32.min))
    }
    static var max: Rational {
        return Rational(Int(Int32.max))
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
    
    func description(q: Int) -> String? {
        switch q % self.q {
        case 0: return "\(p * (q / self.q)) / \(q)"
        default: return nil
        }
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
extension Rational: Hashable {
    var hashValue: Int {
        return Hash.uniformityHashValue(with: [p.hashValue, q.hashValue])
    }
}
extension Rational: Comparable {
    static func <(lhs: Rational, rhs: Rational) -> Bool {
        return lhs.p * rhs.q < rhs.p * lhs.q
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
extension Rational: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect) -> View {
        return description.thumbnailView(withFrame: frame)
    }
}
extension Rational: AbstractViewable {
    func abstractViewWith<T : BinderProtocol>(binder: T,
                                              keyPath: ReferenceWritableKeyPath<T, Rational>,
                                              type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return DiscreteRationalView(binder: binder, keyPath: keyPath,
                                        option: RationalOption(defaultModel: 0,
                                                               minModel: .min,
                                                               maxModel: .max,
                                                               modelInterval: Rational(1, 10),
                                                               descriptionQ: 10,
                                                               isInfinitesimal: false))
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath)
        }
    }
}
extension Rational: ObjectViewable {}
extension Rational: LosslessStringConvertible {
    init?(_ description: String) {
        let values = description.components(separatedBy: "/")
        if values.count == 2, let p = Int(values[0]), let q = Int(values[1]) {
            self = Rational(p, q)
        } else if let value = Int(description) {
            self = Rational(value)
        }
        return nil
    }
}
extension Rational: CustomStringConvertible {
    var description: String {
        switch q {
        case 1: return "\(p)"
        default: return "\(p) / \(q)"
        }
    }
}
extension Rational: ExpressibleByIntegerLiteral {
    typealias IntegerLiteralType = Int
    init(integerLiteral value: Int) {
        self.init(value)
    }
}
extension Rational: AnyInitializable {
    init?(anyValue: Any) {
        switch anyValue {
        case let value as Rational: self = value
        case let value as Int: self = Rational(value)
        case let value as Real: self = Rational(value)
        case let value as String:
            if let value = Rational(value) {
                self = value
            } else {
                return nil
            }
        case let valueChain as ValueChain:
            if let value = Rational(anyValue: valueChain.rootChainValue) {
                self = value
            } else {
                return nil
            }
        default: return nil
        }
    }
}
func floor(_ x: Rational) -> Rational {
    let i = x.integralPart
    return Rational(x.decimalPart.p == 0 ? i : (x < 0 ? i - 1 : i))
}
func ceil(_ x: Rational) -> Rational {
    return Rational(x.decimalPart.p == 0 ? x.integralPart : x.integralPart + 1)
}

struct RationalOption: Object1DOption {
    typealias Model = Rational
    
    var defaultModel: Model
    var minModel: Model
    var maxModel: Model
    var transformedModel: ((Model) -> (Model))
    var reverseTransformedModel: ((Model) -> (Model))
    var modelInterval: Model
    var descriptionQ: Int?
    var isInfinitesimal: Bool
    var unit: String
    
    init(defaultModel: Model, minModel: Model, maxModel: Model,
         transformedModel: @escaping ((Model) -> (Model)) = { $0 },
         reverseTransformedModel: @escaping ((Model) -> (Model)) = { $0 },
         modelInterval: Model = 0, descriptionQ: Int? = nil, isInfinitesimal: Bool,
         unit: String = "") {
        
        self.defaultModel = defaultModel
        self.minModel = minModel
        self.maxModel = maxModel
        self.transformedModel = transformedModel
        self.reverseTransformedModel = reverseTransformedModel
        self.modelInterval = modelInterval
        self.descriptionQ = descriptionQ
        self.isInfinitesimal = isInfinitesimal
        self.unit = unit
    }
    
    func string(with model: Model) -> String {
        if let descriptionQ = descriptionQ, let description = model.description(q: descriptionQ) {
            return description
        } else {
            return model.description
        }
    }
    func displayText(with model: Model) -> Text {
        if let descriptionQ = descriptionQ, let description = model.description(q: descriptionQ) {
            return Text(description + "\(unit)")
        } else {
            return Text(model.description + "\(unit)")
        }
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
                let p = oldModel.p + Int(delta)
                newModel = p < 1 ? Rational(1, 2 - p) : Rational(p)
            } else {
                let q = oldModel.q - Int(delta)
                newModel = q < 1 ? Rational(2 - q) : Rational(1, q)
            }
        } else {
            newModel = oldModel.interval(scale: modelInterval) + model(withDelta: delta)
        }
        return newModel.clip(min: minModel, max: maxModel)
    }
    func model(withRatio ratio: Real) -> Model {
        return (maxModel - minModel) * Rational(ratio) + minModel
    }
    func clippedModel(_ model: Model) -> Model {
        return model.clip(min: minModel, max: maxModel)
    }
}
typealias DiscreteRationalView<Binder: BinderProtocol> = Discrete1DView<RationalOption, Binder>
