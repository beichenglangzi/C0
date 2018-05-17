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

import CoreGraphics

func hypot²<T: BinaryFloatingPoint>(_ lhs: T, _ rhs: T) -> T {
    return lhs * lhs + rhs * rhs
}

typealias Real = CGFloat
typealias Real32 = Float

extension Real: AdditiveGroup {}
extension Real {
    func interval(scale: Real) -> Real {
        if scale == 0 {
            return self
        } else {
            let t = floor(self / scale) * scale
            return self - t > scale / 2 ? t + scale : t
        }
    }
    func differenceRotation(_ other: Real) -> Real {
        let a = self - other
        return a + (a > .pi ? -2 * (.pi) : (a < -.pi ? 2 * (.pi) : 0))
    }
    var clipRotation: Real {
        return self < -.pi ? self + 2 * (.pi) : (self > .pi ? self - 2 * (.pi) : self)
    }
    func isApproximatelyEqual(other: Real, roundingError: Real = 0.0000000001) -> Bool {
        return abs(self - other) < roundingError
    }
    var ²: Real {
        return self * self
    }
    func loopValue(other: Real, begin: Real = 0, end: Real = 1) -> Real {
        if other < self {
            let value = (other - begin) + (end - self)
            return self - other < value ? self : self - (end - begin)
        } else {
            let value = (self - begin) + (end - other)
            return other - self < value ? self : self + (end - begin)
        }
    }
    func loopValue(begin: Real = 0, end: Real = 1) -> Real {
        return self < begin ? self + (end - begin) : (self > end ? self - (end - begin) : self)
    }
    static func random(min: Real, max: Real) -> Real {
        return (max - min) * (Real(arc4random_uniform(UInt32.max)) / Real(UInt32.max)) + min
    }
    static func bilinear(x: Real, y: Real,
                         a: Real, b: Real, c: Real, d: Real) -> Real {
        return x * y * (a - b - c + d) + x * (b - a) + y * (c - a) + a
    }
    
    static func simpsonIntegral(splitHalfCount m: Int, a: Real, b: Real,
                                f: (Real) -> (Real)) -> Real {
        let n = Real(2 * m)
        let h = (b - a) / n
        func x(at i: Int) -> Real {
            return a + Real(i) * h
        }
        let s0 = 2 * (1..<m - 1).reduce(0.0.cg) { $0 + f(x(at: 2 * $1)) }
        let s1 = 4 * (1..<m).reduce(0.0.cg) { $0 + f(x(at: 2 * $1 - 1)) }
        return (h / 3) * (f(a) + s0 + s1 + f(b))
    }
    static func simpsonIntegralB(splitHalfCount m: Int, a: Real, maxB: Real,
                                 s: Real, bisectionCount: Int = 3,
                                 f: (Real) -> (Real)) -> Real {
        let n = 2 * m
        let h = (maxB - a) / Real(n)
        func x(at i: Int) -> Real {
            return a + Real(i) * h
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
extension Real {
    static func **(_ lhs: Real, _rhs: Real) -> Real {
        return pow(lhs, lhs)
    }
}
extension Real: Interpolatable {
    static func linear(_ f0: Real, _ f1: Real, t: Real) -> Real {
        return f0 * (1 - t) + f1 * t
    }
    static func firstMonospline(_ f1: Real, _ f2: Real, _ f3: Real,
                                with ms: Monospline) -> Real {
        return ms.firstInterpolatedValue(f1, f2, f3)
    }
    static func monospline(_ f0: Real, _ f1: Real, _ f2: Real, _ f3: Real,
                           with ms: Monospline) -> Real {
        return ms.interpolatedValue(f0, f1, f2, f3)
    }
    static func lastMonospline(_ f0: Real, _ f1: Real, _ f2: Real,
                               with ms: Monospline) -> Real {
        return ms.lastInterpolatedValue(f0, f1, f2)
    }
    
    static func integralLinear(_ f0: Real, _ f1: Real, a: Real, b: Real) -> Real {
        let f01 = f1 - f0
        let fa = a * (f01 * a / 2 + f0)
        let fb = b * (f01 * b / 2 + f0)
        return fb - fa
    }
}
extension Real: KeyframeValue {}
extension Real: Referenceable {
    static let name = Text(english: "Real Number (\(MemoryLayout<Real>.size * 8)bit)",
                           japanese: "実数 (\(MemoryLayout<Real>.size * 8)bit)")
}
extension Real: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return String(self).thumbnailView(withFrame: frame, sizeType)
    }
}
extension Real {
    init?(_ string: String) {
        if let value = Double(string)?.cg {
            self = value
        } else {
            return nil
        }
    }
    init(_ x: Rational) {
        self = Real(x.p) / Real(x.q)
    }
}
extension Double {
    var cg: Real {
        return Real(self)
    }
}
extension String {
    init(_ value: Real) {
        self = String(Double(value))
    }
}

struct RealGetterOption: GetterOption {
    typealias Model = Real
    
    var reverseTransformedModel: ((Model) -> (Model))
    var numberOfDigits: Int
    var unit: String
    
    init(reverseTransformedModel: @escaping ((Model) -> (Model)) = { $0 },
         numberOfDigits: Int = 0, unit: String = "") {
        
        self.reverseTransformedModel = reverseTransformedModel
        self.numberOfDigits = numberOfDigits
        self.unit = unit
    }
    
    func string(with model: Model) -> String {
        return "\(model)"
    }
    func displayText(with model: Model) -> Text {
        if numberOfDigits == 0 {
            let string = model - floor(model) > 0 ?
                String(format: "%g", model) + "\(unit)" :
                "\(Int(model))" + "\(unit)"
            return Text(string)
        } else {
            let string = String(format: "%.\(numberOfDigits)f", model) + "\(unit)"
            return Text(string)
        }
    }
}
typealias RealGetterView<Binder: BinderProtocol> = GetterView<RealGetterOption, Binder>

struct RealOption: Object1DOption {
    typealias Model = Real
    
    var defaultModel: Model
    var minModel: Model
    var maxModel: Model
    var transformedModel: ((Model) -> (Model))
    var reverseTransformedModel: ((Model) -> (Model))
    var modelInterval: Model
    var exp: Real
    var numberOfDigits: Int
    var unit: String
    
    init(defaultModel: Model, minModel: Model, maxModel: Model,
         transformedModel: @escaping ((Model) -> (Model)) = { $0 },
         reverseTransformedModel: @escaping ((Model) -> (Model)) = { $0 },
         modelInterval: Model = 0, exp: Real = 1, numberOfDigits: Int = 0, unit: String = "") {
        
        self.defaultModel = defaultModel
        self.minModel = minModel
        self.maxModel = maxModel
        self.transformedModel = transformedModel
        self.reverseTransformedModel = reverseTransformedModel
        self.modelInterval = modelInterval
        self.exp = exp
        self.numberOfDigits = numberOfDigits
        self.unit = unit
    }
    
    func model(with object: Any) -> Real? {
        switch object {
        case let value as Model: return value
        case let value as Int: return Model(value)
        case let value as Rational: return Model(value)
        case let value as String: return Model(value)
        default: return nil
        }
    }
    func string(with model: Model) -> String {
        return "\(model)"
    }
    func displayText(with model: Model) -> Text {
        if numberOfDigits == 0 {
            let string = model - floor(model) > 0 ?
                String(format: "%g", model) + "\(unit)" :
                "\(Int(model))" + "\(unit)"
            return Text(string)
        } else {
            let string = String(format: "%.\(numberOfDigits)f", model) + "\(unit)"
            return Text(string)
        }
    }
    func ratio(with model: Model) -> Real {
        return (model - minModel) / (maxModel - minModel)
    }
    func ratioFromDefaultModel(with model: Model) -> Real {
        if model < defaultModel {
            return ((model - minModel) / (defaultModel - minModel)) * 0.5
        } else {
            return ((model - defaultModel) / (maxModel - defaultModel)) * 0.5 + 0.5
        }
    }
    
    private func model(withDelta delta: Real) -> Model {
        let d = delta * modelInterval
        if exp == 1 {
            return d.interval(scale: modelInterval)
        } else {
            return (d >= 0 ? (d ** exp) : -(abs(d) ** exp)).interval(scale: modelInterval)
        }
    }
    func model(withDelta delta: Real, oldModel: Model) -> Model {
        let v = oldModel.interval(scale: modelInterval) + model(withDelta: delta)
        return v.clip(min: minModel, max: maxModel)
    }
    func intervalModel(with m: Model) -> Model {
        guard modelInterval != 0 else {
            return m
        }
        let t = (m / modelInterval).rounded(.down) * modelInterval
        return m - t > modelInterval / 2 ? t + modelInterval : t
    }
    func model(withRatio ratio: Real) -> Model {
        let m = (maxModel - minModel) * (ratio ** exp) + minModel
        return intervalModel(with: m).clip(min: minModel, max: maxModel)
    }
    func clippedModel(_ model: Model) -> Model {
        return model.clip(min: minModel, max: maxModel)
    }
}
extension RealOption {
    static let opacity = RealOption(defaultModel: 1, minModel: 0, maxModel: 1)
}
typealias AssignableRealView<Binder: BinderProtocol> = Assignable1DView<RealOption, Binder>
typealias DiscreteRealView<Binder: BinderProtocol> = Discrete1DView<RealOption, Binder>
typealias SlidableRealView<Binder: BinderProtocol> = Slidable1DView<RealOption, Binder>
typealias CircularRealView<Binder: BinderProtocol> = Circular1DView<RealOption, Binder>
