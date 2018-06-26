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

protocol Interpolatable {
    static var defaultInterpolation: Interpolation { get }
    static func step(_ f0: Self) -> Self
    static func linear(_ f0: Self, _ f1: Self, t: Real) -> Self
    static func firstMonospline(_ f1: Self, _ f2: Self, _ f3: Self,
                                with ms: Monospline) -> Self
    static func monospline(_ f0: Self, _ f1: Self, _ f2: Self, _ f3: Self,
                           with ms: Monospline) -> Self
    static func lastMonospline(_ f0: Self, _ f1: Self, _ f2: Self,
                               with ms: Monospline) -> Self
}
extension Interpolatable {
    static var defaultInterpolation: Interpolation {
        return .spline
    }
    static func step (_ f0: Self) -> Self {
        return f0
    }
}
extension Array: Interpolatable where Element: Interpolatable {
    static func linear(_ f0: [Element], _ f1: [Element], t: Real) -> [Element] {
        guard !f0.isEmpty else {
            return f0
        }
        return f0.enumerated().map { i, e0 in
            guard i < f1.count else {
                return e0
            }
            let e1 = f1[i]
            return Element.linear(e0, e1, t: t)
        }
    }
    static func firstMonospline(_ f1: [Element],
                                _ f2: [Element], _ f3: [Element],
                                with ms: Monospline) -> [Element] {
        guard !f1.isEmpty else {
            return f1
        }
        return f1.enumerated().map { i, e1 in
            guard i < f2.count else {
                return e1
            }
            let e2 = f2[i]
            let e3 = i >= f3.count ? e2 : f3[i]
            return Element.firstMonospline(e1, e2, e3, with: ms)
        }
    }
    static func monospline(_ f0: [Element], _ f1: [Element],
                           _ f2: [Element], _ f3: [Element],
                           with ms: Monospline) -> [Element] {
        guard !f1.isEmpty else {
            return f1
        }
        return f1.enumerated().map { i, e1 in
            guard i < f2.count else {
                return e1
            }
            let e0 = i >= f0.count ? e1 : f0[i]
            let e2 = f2[i]
            let e3 = i >= f3.count ? e2 : f3[i]
            return Element.monospline(e0, e1, e2, e3, with: ms)
        }
    }
    static func lastMonospline(_ f0: [Element],
                               _ f1: [Element], _ f2: [Element],
                               with ms: Monospline) -> [Element] {
        guard !f1.isEmpty else {
            return f1
        }
        return f1.enumerated().map { i, e1 in
            guard i < f2.count else {
                return e1
            }
            let e0 = i >= f0.count ? e1 : f0[i]
            let e2 = f2[i]
            return Element.lastMonospline(e0, e1, e2, with: ms)
        }
    }
}

struct Monospline {
    let h0: Real, h1: Real, h2: Real
    let reciprocalH0: Real, reciprocalH1: Real, reciprocalH2: Real
    let reciprocalH0H1: Real, reciprocalH1H2: Real, reciprocalH1H1: Real
    private(set) var xx3: Real, xx2: Real, xx1: Real
    var t: Real {
        didSet {
            xx1 = h1 * t
            xx2 = xx1 * xx1
            xx3 = xx1 * xx1 * xx1
        }
    }
    init(x1: Real, x2: Real, x3: Real, t: Real) {
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
    init(x0: Real, x1: Real, x2: Real, x3: Real, t: Real) {
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
    init(x0: Real, x1: Real, x2: Real, t: Real) {
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
    
    func firstInterpolatedValue(_ f1: Real, _ f2: Real, _ f3: Real) -> Real {
        let s1 = (f2 - f1) * reciprocalH1, s2 = (f3 - f2) * reciprocalH2
        let signS1: Real = s1 > 0 ? 1 : -1, signS2: Real = s2 > 0 ? 1 : -1
        let yPrime1 = s1
        let yPrime2 = (signS1 + signS2) * min(abs(s1),
                                              abs(s2),
                                              0.5 * abs((h2 * s1 + h1 * s2) * reciprocalH1H2))
        return interpolatedValue(f1: f1, s1: s1, yPrime1: yPrime1, yPrime2: yPrime2)
    }
    func interpolatedValue(_ f0: Real, _ f1: Real, _ f2: Real, _ f3: Real) -> Real {
        let s0 = (f1 - f0) * reciprocalH0
        let s1 = (f2 - f1) * reciprocalH1, s2 = (f3 - f2) * reciprocalH2
        let signS0: Real = s0 > 0 ? 1 : -1
        let signS1: Real = s1 > 0 ? 1 : -1, signS2: Real = s2 > 0 ? 1 : -1
        let yPrime1 = (signS0 + signS1) * min(abs(s0),
                                              abs(s1),
                                              0.5 * abs((h1 * s0 + h0 * s1) * reciprocalH0H1))
        let yPrime2 = (signS1 + signS2) * min(abs(s1),
                                              abs(s2),
                                              0.5 * abs((h2 * s1 + h1 * s2) * reciprocalH1H2))
        return interpolatedValue(f1: f1, s1: s1, yPrime1: yPrime1, yPrime2: yPrime2)
    }
    func lastInterpolatedValue(_ f0: Real, _ f1: Real, _ f2: Real) -> Real {
        let s0 = (f1 - f0) * reciprocalH0, s1 = (f2 - f1) * reciprocalH1
        let signS0: Real = s0 > 0 ? 1 : -1, signS1: Real = s1 > 0 ? 1 : -1
        let yPrime1 = (signS0 + signS1) * min(abs(s0),
                                              abs(s1),
                                              0.5 * abs((h1 * s0 + h0 * s1) * reciprocalH0H1))
        let yPrime2 = s1
        return interpolatedValue(f1: f1, s1: s1, yPrime1: yPrime1, yPrime2: yPrime2)
    }
    private func interpolatedValue(f1: Real, s1: Real,
                                   yPrime1: Real, yPrime2: Real) -> Real {
        let a = (yPrime1 + yPrime2 - 2 * s1) * reciprocalH1H1
        let b = (3 * s1 - 2 * yPrime1 - yPrime2) * reciprocalH1, c = yPrime1, d = f1
        return a * xx3 + b * xx2 + c * xx1 + d
    }
    
    func integralFirstInterpolatedValue(_ f1: Real, _ f2: Real, _ f3: Real,
                                        a: Real, b: Real) -> Real {
        let s1 = (f2 - f1) * reciprocalH1, s2 = (f3 - f2) * reciprocalH2
        let signS1: Real = s1 > 0 ? 1 : -1, signS2: Real = s2 > 0 ? 1 : -1
        let yPrime1 = s1
        let yPrime2 = (signS1 + signS2) * min(abs(s1),
                                              abs(s2),
                                              0.5 * abs((h2 * s1 + h1 * s2) * reciprocalH1H2))
        return integral(f1: f1, s1: s1, yPrime1: yPrime1, yPrime2: yPrime2, a: a, b: b)
    }
    func integralInterpolatedValue(_ f0: Real, _ f1: Real, _ f2: Real, _ f3: Real,
                                   a: Real, b: Real) -> Real {
        let s0 = (f1 - f0) * reciprocalH0
        let s1 = (f2 - f1) * reciprocalH1, s2 = (f3 - f2) * reciprocalH2
        let signS0: Real = s0 > 0 ? 1 : -1
        let signS1: Real = s1 > 0 ? 1 : -1, signS2: Real = s2 > 0 ? 1 : -1
        let yPrime1 = (signS0 + signS1) * min(abs(s0),
                                              abs(s1),
                                              0.5 * abs((h1 * s0 + h0 * s1) * reciprocalH0H1))
        let yPrime2 = (signS1 + signS2) * min(abs(s1),
                                              abs(s2),
                                              0.5 * abs((h2 * s1 + h1 * s2) * reciprocalH1H2))
        return integral(f1: f1, s1: s1, yPrime1: yPrime1, yPrime2: yPrime2, a: a, b: b)
    }
    func integralLastInterpolatedValue(_ f0: Real, _ f1: Real, _ f2: Real,
                                       a: Real, b: Real) -> Real {
        let s0 = (f1 - f0) * reciprocalH0, s1 = (f2 - f1) * reciprocalH1
        let signS0: Real = s0 > 0 ? 1 : -1, signS1: Real = s1 > 0 ? 1 : -1
        let yPrime1 = (signS0 + signS1) * min(abs(s0),
                                              abs(s1),
                                              0.5 * abs((h1 * s0 + h0 * s1) * reciprocalH0H1))
        let yPrime2 = s1
        return integral(f1: f1, s1: s1, yPrime1: yPrime1, yPrime2: yPrime2, a: a, b: b)
    }
    private func integral(f1: Real, s1: Real, yPrime1: Real, yPrime2: Real,
                          a xa: Real, b xb: Real) -> Real {
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

enum Interpolation: Int8, Codable {
    case spline, bound, linear, step
}
extension Interpolation: Referenceable {
    static let name = Text(english: "Interpolation", japanese: "補間")
}
extension Interpolation: DisplayableText {
    var displayText: Text {
        switch self {
        case .spline: return Text(english: "Spline", japanese: "スプライン")
        case .bound: return Text(english: "Bound", japanese: "バウンド")
        case .linear: return Text(english: "Linear", japanese: "リニア")
        case .step: return Text(english: "Step", japanese: "ステップ")
        }
    }
    static var displayTexts: [Text] {
        return [spline.displayText,
                bound.displayText,
                linear.displayText,
                step.displayText]
    }
}
extension Interpolation {
    static var defaultOption: EnumOption<Interpolation> {
        return EnumOption(defaultModel: Interpolation.spline,
                          cationModels: [],
                          indexClosure: { Int($0) },
                          rawValueClosure: { Interpolation.RawValue($0) },
                          names: Interpolation.displayTexts)
    }
}
extension Interpolation: AbstractViewable {
    func abstractViewWith
        <T : BinderProtocol>(binder: T,
                             keyPath: ReferenceWritableKeyPath<T, Interpolation>,
                             type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return EnumView(binder: binder, keyPath: keyPath,
                            option: Interpolation.defaultOption)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath)
        }
    }
}
extension Interpolation: ObjectViewable {}
