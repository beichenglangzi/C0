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

extension Comparable {
    func clip(min: Self, max: Self) -> Self {
        return self < min ? min : (self > max ? max : self)
    }
    func isOver(old: Self, new: Self) -> Bool {
        return (new >= self && old < self) || (new <= self && old > self)
    }
}

extension Int {
    var cf: CGFloat {
        return CGFloat(self)
    }
    var d: Double {
        return Double(self)
    }
}
extension Float {
    var cf: CGFloat {
        return CGFloat(self)
    }
    var d: Double {
        return Double(self)
    }
}
extension Double {
    var cf: CGFloat {
        return CGFloat(self)
    }
}
extension CGFloat {
    var d: Double {
        return Double(self)
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

extension Double {
    static func random(min: Double, max: Double) -> Double {
        return (max - min) * (Double(arc4random_uniform(UInt32.max)) / Double(UInt32.max)) + min
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
        let s0 = 2 * (1..<m - 1).reduce(0.0.cf) { $0 + f(x(at: 2 * $1)) }
        let s1 = 4 * (1..<m).reduce(0.0.cf) { $0 + f(x(at: 2 * $1 - 1)) }
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
        var fa = f(a), allS = 0.0.cf
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

extension CGAffineTransform {
    static func centering(from fromFrame: CGRect,
                          to toFrame: CGRect) -> (scale: CGFloat, affine: CGAffineTransform) {
        
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
