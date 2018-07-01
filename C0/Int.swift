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
    init(_ x: Rational) {
        self = x.integralPart
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
extension Int: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect) -> View {
        return String(self).thumbnailView(withFrame: frame)
    }
}
extension Int: AbstractViewable {
    func abstractViewWith<T : BinderProtocol>(binder: T,
                                              keyPath: ReferenceWritableKeyPath<T, Int>,
                                              type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return DiscreteIntView(binder: binder, keyPath: keyPath,
                                   option: IntOption(defaultModel: 0,
                                                     minModel: Int(Int32.min),
                                                     maxModel: Int(Int32.max),
                                                     modelInterval: 1))
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath)
        }
    }
}
extension Int: ObjectViewable {}
extension Int: AnyInitializable {
    init?(anyValue: Any) {
        switch anyValue {
        case let value as Int: self = value
        case let value as Rational: self = Int(value)
        case let value as Real: self = Int(value)
        case let value as String:
            if let value = Int(value) {
                self = value
            } else {
                return nil
            }
        case let valueChain as ValueChain:
            if let value = Int(anyValue: valueChain.rootChainValue) {
                self = value
            } else {
                return nil
            }
        default: return nil
        }
    }
}

struct IntGetterOption: GetterOption {
    typealias Model = Int
    
    var reverseTransformedModel: ((Model) -> (Model))
    var unit: String
    
    init(reverseTransformedModel: @escaping ((Model) -> (Model)) = { $0 },
         unit: String = "") {
        
        self.reverseTransformedModel = reverseTransformedModel
        self.unit = unit
    }
    
    func string(with model: Model) -> String {
        return "\(model)"
    }
    func displayText(with model: Model) -> Text {
        return Text("\(model)\(unit)")
    }
}
typealias IntGetterView<Binder: BinderProtocol> = GetterView<IntGetterOption, Binder>

struct IntOption: Object1DOption {
    typealias Model = Int
    
    var defaultModel: Model
    var minModel: Model
    var maxModel: Model
    var transformedModel: ((Model) -> (Model))
    var reverseTransformedModel: ((Model) -> (Model))
    var modelInterval: Model
    var exp: Real
    var unit: String
    
    init(defaultModel: Model, minModel: Model, maxModel: Model,
         transformedModel: @escaping ((Model) -> (Model)) = { $0 },
         reverseTransformedModel: @escaping ((Model) -> (Model)) = { $0 },
         modelInterval: Model = 0, exp: Real = 1, unit: String = "") {
        
        self.defaultModel = defaultModel
        self.minModel = minModel
        self.maxModel = maxModel
        self.transformedModel = transformedModel
        self.reverseTransformedModel = reverseTransformedModel
        self.modelInterval = modelInterval
        self.exp = exp
        self.unit = unit
    }
    
    func string(with model: Model) -> String {
        return model.description
    }
    func displayText(with model: Model) -> Text {
        return Text(model.description + "\(unit)")
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
    func realValue(with model: Int) -> Real {
        return Real(model)
    }
    func model(with realValue: Real) -> Int {
        return Model(realValue)
    }
}
typealias DiscreteIntView<Binder: BinderProtocol> = Discrete1DView<IntOption, Binder>
