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

typealias RPB = Real
struct Wiggle: Codable, Hashable, Initializable {//SineWave
    var amplitude = 0.0.cg, frequency = 8.0.cg
    
    var isEmpty: Bool {
        return amplitude == 0
    }
    
    func  yWith(t: Real, φ: Real = 0) -> Real {
        let ω = 2 * .pi * frequency
        return amplitude * sin(ω * t + φ)
    }
    func  yWith(phase: Real, φ: Real = 0) -> Real {
        return amplitude * sin(phase + φ)
    }
}
extension Wiggle {
    static let amplitudeOption = RealOption(defaultModel: 0, minModel: 0, maxModel: 10000,
                                            modelInterval: 0.01, exp: 1,
                                            numberOfDigits: 2, unit: "")
    static let frequencyOption = RealOption(defaultModel: 8, minModel: 0.1, maxModel: 100000,
                                            modelInterval: 0.1, exp: 1,
                                            numberOfDigits: 1, unit: "rpb")
}
extension Wiggle: Interpolatable {
    static func linear(_ f0: Wiggle, _ f1: Wiggle, t: Real) -> Wiggle {
        let amplitude = Real.linear(f0.amplitude, f1.amplitude, t: t)
        let frequency = Real.linear(f0.frequency, f1.frequency, t: t)
        return Wiggle(amplitude: amplitude, frequency: frequency)
    }
    static func firstMonospline(_ f1: Wiggle, _ f2: Wiggle,
                                _ f3: Wiggle, with ms: Monospline) -> Wiggle {
        let amplitude = Real.firstMonospline(f1.amplitude, f2.amplitude, f3.amplitude, with: ms)
        let frequency = Real.firstMonospline(f1.frequency, f2.frequency, f3.frequency, with: ms)
        return Wiggle(amplitude: amplitude, frequency: frequency)
    }
    static func monospline(_ f0: Wiggle, _ f1: Wiggle,
                           _ f2: Wiggle, _ f3: Wiggle, with ms: Monospline) -> Wiggle {
        let amplitude = Real.monospline(f0.amplitude, f1.amplitude,
                                        f2.amplitude, f3.amplitude, with: ms)
        let frequency = Real.monospline(f0.frequency, f1.frequency,
                                        f2.frequency, f3.frequency, with: ms)
        return Wiggle(amplitude: amplitude, frequency: frequency)
    }
    static func lastMonospline(_ f0: Wiggle, _ f1: Wiggle,
                               _ f2: Wiggle, with ms: Monospline) -> Wiggle {
        let amplitude = Real.lastMonospline(f0.amplitude, f1.amplitude, f2.amplitude, with: ms)
        let frequency = Real.lastMonospline(f0.frequency, f1.frequency, f2.frequency, with: ms)
        return Wiggle(amplitude: amplitude, frequency: frequency)
    }
}
extension Wiggle: Referenceable {
    static let name = Text(english: "Wiggle", japanese: "振動")
}
extension Wiggle: KeyframeValue {}
extension Wiggle: CompactViewable {
    func thumbnail(withBounds bounds: Rect, _ sizeType: SizeType) -> View {
        return View(isForm: true)
    }
}

struct WiggleTrack: Track, Codable {
    private(set) var animation = Animation<Wiggle>() {
        didSet {
            updateKeyPhases()
        }
    }
    var animatable: Animatable {
        return animation
    }

    private var keyPhases = [Real]()
    private mutating func updateKeyPhases() {
        guard animation.loopFrames.count >= 2 else {
            keyPhases = []
            return
        }
        var phase = 0.0.cg
        keyPhases = (0..<animation.loopFrames.count).map { li in
            if li == animation.loopFrames.count - 1 {
                return phase
            } else {
                let p = phase
                phase += integralPhaseDifference(at: li)
                return p
            }
        }
    }
    
    func wigglePhase(withBeatTime time: Beat, defaultWiggle: Wiggle = Wiggle()) -> Real {
        guard animation.loopFrames.count >= 2 else {
            let wiggle = animation.interpolatedValue(atTime: time) ?? defaultWiggle
            return wiggle.frequency * Real(time)
        }
        for (li, loopFrame) in animation.loopFrames.enumerated().reversed() {
            guard loopFrame.time <= time else { continue }
            if li == animation.loopFrames.count - 1 {
                let wiggle = animation.keyframes[loopFrame.index].value
                return keyPhases[li] + wiggle.frequency * Real(time - loopFrame.time)
            } else {
                let i2t = animation.loopFrames[li + 1].time
                let d = i2t - loopFrame.time
                if d == 0 {
                    return keyPhases[li]
                } else {
                    let t = Real((time - loopFrame.time) / d)
                    return keyPhases[li] + integralPhaseDifference(at: li, maxT: t)
                }
            }
        }
        return 0
    }

    func integralPhaseDifference(at li: Int, minT: Real = 0, maxT: Real = 1,
                                 splitSecondCount: Int = 20) -> Real {
        let lf1 = animation.loopFrames[li], lf2 = animation.loopFrames[li + 1]
        let f1 = animation.keyframes[lf1.index].value.frequency
        let f2 = animation.keyframes[lf2.index].value.frequency
        let d = Real(lf2.time - lf1.time)
        func shc() -> Int {
            return max(2, Int(d) * splitSecondCount / 2)
        }

        var df = 0.0.cg
        func step(_ lf1: LoopFrame) {
            df = f1 * Real(maxT - minT)
        }
        func linear(_ lf1: LoopFrame, _ lf2: LoopFrame) {
            let easing = animation.keyframes[lf1.index].timing.easing
            if easing.isLinear {
                df = Real.integralLinear(f1, f2, a: minT, b: maxT)
            } else {
                df = Real.simpsonIntegral(splitHalfCount: shc(), a: minT, b: maxT) {
                    let t = easing.convertT($0)
                    return Real.linear(f1, f2, t: t)
                }
            }
        }
        func monospline(_ lf0: LoopFrame, _ lf1: LoopFrame,
                        _ lf2: LoopFrame, _ lf3: LoopFrame) {
            let f0 = animation.keyframes[lf0.index].value.frequency
            let f3 = animation.keyframes[lf3.index].value.frequency
            var ms = Monospline(x0: Real(lf0.time), x1: Real(lf1.time),
                                x2: Real(lf2.time), x3: Real(lf3.time), t: 0)
            let easing = animation.keyframes[lf1.index].timing.easing
            if easing.isLinear {
                df = ms.integralInterpolatedValue(f0, f1, f2, f3, a: minT, b: maxT)
            } else {
                df = Real.simpsonIntegral(splitHalfCount: shc(), a: minT, b: maxT) {
                    ms.t = easing.convertT($0)
                    return Real.monospline(f0, f1, f2, f3, with: ms)
                }
            }
        }
        func firstMonospline(_ lf1: LoopFrame, _ lf2: LoopFrame,
                             _ lf3: LoopFrame) {
            let f3 = animation.keyframes[lf3.index].value.frequency
            var ms = Monospline(x1: Real(lf1.time), x2: Real(lf2.time),
                                x3: Real(lf3.time), t: 0)
            let easing = animation.keyframes[lf1.index].timing.easing
            if easing.isLinear {
                df = ms.integralFirstInterpolatedValue(f1, f2, f3, a: minT, b: maxT)
            } else {
                df = Real.simpsonIntegral(splitHalfCount: shc(), a: minT, b: maxT) {
                    ms.t = easing.convertT($0)
                    return Real.firstMonospline(f1, f2, f3, with: ms)
                }
            }
        }
        func lastMonospline(_ lf0: LoopFrame, _ lf1: LoopFrame,
                            _ lf2: LoopFrame) {
            let f0 = animation.keyframes[lf0.index].value.frequency
            var ms = Monospline(x0: Real(lf0.time), x1: Real(lf1.time),
                                x2: Real(lf2.time), t: 0)
            let easing = animation.keyframes[lf1.index].timing.easing
            if easing.isLinear {
                df = ms.integralLastInterpolatedValue(f0, f1, f2, a: minT, b: maxT)
            } else {
                df = Real.simpsonIntegral(splitHalfCount: shc(), a: minT, b: maxT) {
                    ms.t = easing.convertT($0)
                    return Real.lastMonospline(f0, f1, f2, with: ms)
                }
            }
        }
        if f1 == f2 {
            step(lf1)
        } else {
            animation.interpolation(at: li,
                                    step: step, linear: linear,
                                    monospline: monospline,
                                    firstMonospline: firstMonospline, endMonospline: lastMonospline)
        }
        return df * d
    }
}


final class WiggleView: View {
    var wiggle = Wiggle() {
        didSet {
            if wiggle != oldValue {
                updateWithWiggle()
            }
        }
    }
    
    let classNameView: TextView
    let classAmplitudeNameView: TextView
    let amplitudeView: DiscreteRealView
    let classFrequencyNameView: TextView
    let frequencyView: DiscreteRealView
    
    init(sizeType: SizeType = .regular) {
        classNameView = TextView(text: Wiggle.name, font: Font.bold(with: sizeType))
        classAmplitudeNameView = TextView(text: "A:", font: Font.default(with: sizeType))
        amplitudeView = DiscreteRealView(model: wiggle.amplitude, option: Wiggle.amplitudeOption,
                                         frame: Layout.valueFrame(with: sizeType),
                                         sizeType: sizeType)
        classFrequencyNameView = TextView(text: "ƒ:")
        frequencyView = DiscreteRealView(model: wiggle.frequency, option: Wiggle.frequencyOption,
                                         frame: Layout.valueFrame(with: sizeType),
                                         sizeType: sizeType)
        
        super.init()
        children = [classNameView,
                    classAmplitudeNameView, amplitudeView,
                    classFrequencyNameView, frequencyView]
        
        amplitudeView.binding = { [unowned self] in self.setWiggle(with: $0) }
        frequencyView.binding = { [unowned self] in self.setWiggle(with: $0) }
    }
    
    override var defaultBounds: Rect {
        let w = MaterialView.defaultWidth + Layout.basicPadding * 2
        let h = Layout.basicHeight * 2 + Layout.basicPadding * 2
        return Rect(x: 0, y: 0, width: w, height: h)
    }
    override func updateLayout() {
        var y = bounds.height - Layout.basicPadding - classNameView.frame.height
        classNameView.frame.origin = Point(x: Layout.basicPadding, y: y)
        y = bounds.height - Layout.basicPadding - Layout.basicHeight
        _ = Layout.leftAlignment([.view(classFrequencyNameView), .view(frequencyView)],
                                 y: y, height: Layout.basicHeight)
        y -= Layout.basicHeight
        classFrequencyNameView.frame.origin.x
            = frequencyView.frame.minX - classFrequencyNameView.frame.width
    }
    private func updateWithWiggle() {
        amplitudeView.model = 10 * wiggle.amplitude / standardAmplitude
        frequencyView.model = wiggle.frequency
    }
    
    var standardAmplitude = 1.0.cg
    
    struct Binding {
        let wiggleView: WiggleView
        let wiggle: Wiggle, oldWiggle: Wiggle, phase: Phase
    }
    var binding: ((Binding) -> ())?
    
    private var oldWiggle = Wiggle()
    private func setWiggle(with obj: DiscreteRealView.Binding<Real>) {
        if obj.phase == .began {
            oldWiggle = wiggle
            binding?(Binding(wiggleView: self,
                             wiggle: oldWiggle, oldWiggle: oldWiggle, phase: .began))
        } else {
            switch obj.view {
            case amplitudeView:
                wiggle.amplitude = obj.model * standardAmplitude / 10
            case frequencyView:
                wiggle.frequency = obj.model
            default:
                fatalError("No case")
            }
            binding?(Binding(wiggleView: self,
                             wiggle: wiggle, oldWiggle: oldWiggle, phase: obj.phase))
        }
    }
    
    func push(_ wiggle: Wiggle) {
//        registeringUndoManager?.registerUndo(withTarget: self) {
//            $0.set(oldWiggle, oldWiggle: wiggle)
//        }
        self.wiggle = wiggle
    }
}
extension WiggleView: Localizable {
    func update(with locale: Locale) {
        updateLayout()
    }
}
extension WiggleView: Queryable {
    static let referenceableType: Referenceable.Type = Wiggle.self
}
extension WiggleView: Assignable {
    func delete(for p: Point) {
        push(Wiggle())
    }
    func copiedViewables(at p: Point) -> [Viewable] {
        return [wiggle]
    }
    func paste(_ objects: [Any], for p: Point) {
        for object in objects {
            if let wiggle = object as? Wiggle {
                if wiggle != self.wiggle {
                    push(wiggle)
                    return
                }
            }
        }
    }
}
