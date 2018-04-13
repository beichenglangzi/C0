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
    static let name = Localization(english: "Rational Number", japanese: "有理数")
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
