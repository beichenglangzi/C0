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

extension Int: AdditiveGroup {}
extension Int {
    static func gcd(_ m: Int, _ n: Int) -> Int {
        return n == 0 ? m : gcd(n, m % n)
    }
    func interval(scale: Int) -> Int {
        if scale == 0 {
            return self
        } else {
            let t = (self / scale) * scale
            return self - t > scale / 2 ? t + scale : t
        }
    }
}
extension Int: Interpolatable {
    static func linear(_ f0: Int, _ f1: Int, t: Real) -> Int {
        return Int(Real.linear(Real(f0), Real(f1), t: t))
    }
    static func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) -> Int {
        return Int(Real.firstMonospline(Real(f1), Real(f2), Real(f3), with: ms))
    }
    static func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) -> Int {
        return Int(Real.monospline(Real(f0), Real(f1), Real(f2), Real(f3), with: ms))
    }
    static func lastMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with ms: Monospline) -> Int {
        return Int(Real.lastMonospline(Real(f0), Real(f1), Real(f2), with: ms))
    }
}
extension Int: Referenceable {
    static let name = Text(english: "Integer (\(MemoryLayout<Int>.size * 8)bit)",
                           japanese: "整数 (\(MemoryLayout<Int>.size * 8)bit)")
}
extension Int: CompactViewable {
    func thumbnail(withBounds bounds: Rect, _ sizeType: SizeType) -> View {
        return String(self).view(withBounds: bounds, sizeType)
    }
}

extension Int: Object1D {}

struct IntGetterOption: GetterOption {
    typealias Model = Int
    
    var unit: String
    
    func string(with model: Model) -> String {
        return "\(model)"
    }
    func text(with model: Model) -> Text {
        return Text("\(model)\(unit)")
    }
}
typealias IntGetterView<Binder: BinderProtocol> = GetterView<IntGetterOption, Binder>

struct IntOption: Object1DOption {
    typealias Model = Int
    
    var defaultModel: Model
    var minModel: Model
    var maxModel: Model
    var modelInterval: Model
    
    var exp = 1.0.cg
    var unit: String
    
    func model(with string: String) -> Model? {
        return Int(string)
    }
    func string(with model: Model) -> String {
        return "\(model)"
    }
    func text(with model: Model) -> Text {
        return Text("\(model)\(unit)")
    }
    func ratio(with model: Model) -> Real {
        return Real(model - minModel) / Real(maxModel - minModel)
    }
    func ratioFromDefaultModel(with model: Model) -> Real {
        if model < defaultModel {
            return (Real(model - minModel) / Real(defaultModel - minModel)) * 0.5
        } else {
            return (Real(model - defaultModel) / Real(maxModel - defaultModel)) * 0.5 + 0.5
        }
    }
    
    private func model(withDelta delta: Real) -> Model {
        let d = delta * Real(modelInterval)
        if exp == 1 {
            return Int(d).interval(scale: modelInterval)
        } else {
            return Int(d >= 0 ? (d ** exp) : -(abs(d) ** exp)).interval(scale: modelInterval)
        }
    }
    func model(withDelta delta: Real, oldModel: Model) -> Model {
        return oldModel.interval(scale: modelInterval) + model(withDelta: delta)
    }
    func model(withRatio ratio: Real) -> Model {
        return Int((Real(maxModel - minModel) * (ratio ** exp)).rounded()) + minModel
    }
    func clippedModel(_ model: Model) -> Model {
        return model.clip(min: minModel, max: maxModel)
    }
}
typealias DiscreteIntView<Binder: BinderProtocol> = Discrete1DView<IntOption, Binder>
