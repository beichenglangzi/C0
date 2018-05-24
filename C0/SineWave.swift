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

import struct Foundation.Locale
import CoreGraphics

struct SineWave: Codable, Hashable, Initializable {
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
extension SineWave: Interpolatable {
    static func linear(_ f0: SineWave, _ f1: SineWave, t: Real) -> SineWave {
        let amplitude = Real.linear(f0.amplitude, f1.amplitude, t: t)
        let frequency = Real.linear(f0.frequency, f1.frequency, t: t)
        return SineWave(amplitude: amplitude, frequency: frequency)
    }
    static func firstMonospline(_ f1: SineWave, _ f2: SineWave,
                                _ f3: SineWave, with ms: Monospline) -> SineWave {
        let amplitude = Real.firstMonospline(f1.amplitude, f2.amplitude, f3.amplitude, with: ms)
        let frequency = Real.firstMonospline(f1.frequency, f2.frequency, f3.frequency, with: ms)
        return SineWave(amplitude: amplitude, frequency: frequency)
    }
    static func monospline(_ f0: SineWave, _ f1: SineWave,
                           _ f2: SineWave, _ f3: SineWave, with ms: Monospline) -> SineWave {
        let amplitude = Real.monospline(f0.amplitude, f1.amplitude,
                                        f2.amplitude, f3.amplitude, with: ms)
        let frequency = Real.monospline(f0.frequency, f1.frequency,
                                        f2.frequency, f3.frequency, with: ms)
        return SineWave(amplitude: amplitude, frequency: frequency)
    }
    static func lastMonospline(_ f0: SineWave, _ f1: SineWave,
                               _ f2: SineWave, with ms: Monospline) -> SineWave {
        let amplitude = Real.lastMonospline(f0.amplitude, f1.amplitude, f2.amplitude, with: ms)
        let frequency = Real.lastMonospline(f0.frequency, f1.frequency, f2.frequency, with: ms)
        return SineWave(amplitude: amplitude, frequency: frequency)
    }
}
extension SineWave: Referenceable {
    static let name = Text(english: "Sine Wave", japanese: "サイン波")
}
extension SineWave: AbstractViewable {
    func abstractViewWith<T : BinderProtocol>(binder: T,
                                              keyPath: ReferenceWritableKeyPath<T, SineWave>,
                                              frame: Rect, _ sizeType: SizeType,
                                              type: AbstractType) -> View {
        switch type {
        case .normal:
            return SineWaveView(binder: binder, keyPath: keyPath, option: SineWaveOption(),
                                frame: frame, sizeType: sizeType)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath, frame: frame, sizeType)
        }
    }
}
extension SineWave: KeyframeValue {}
extension SineWave: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return View(frame: frame, isLocked: true)
    }
}

struct SineWaveTrack: Track, Codable {
    private(set) var animation = Animation<SineWave>() {
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
    
    func sineWavePhase(withBeatTime time: Beat, defaultSineWave: SineWave = SineWave()) -> Real {
        guard animation.loopFrames.count >= 2 else {
            let sineWave = animation.interpolatedValue(atTime: time) ?? defaultSineWave
            return sineWave.frequency * Real(time)
        }
        for (li, loopFrame) in animation.loopFrames.enumerated().reversed() {
            guard loopFrame.time <= time else { continue }
            if li == animation.loopFrames.count - 1 {
                let sineWave = animation.keyframes[loopFrame.index].value
                return keyPhases[li] + sineWave.frequency * Real(time - loopFrame.time)
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
            switch animation.interpolation(atLoopFrameIndex: li) {
            case .step(let lf1): step(lf1)
            case .linear(let lf1, let lf2): linear(lf1, lf2)
            case .monospline(let lf0, let lf1, let lf2, let lf3): monospline(lf0, lf1, lf2, lf3)
            case .firstMonospline(let lf1, let lf2, let lf3): firstMonospline(lf1, lf2, lf3)
            case .endMonospline(let lf0, let lf1, let lf2): lastMonospline(lf0, lf1, lf2)
            }
        }
        return df * d
    }
}

struct SineWaveOption {
    var defaultModel = SineWave()
    var amplitudeOption = RealOption(defaultModel: 0, minModel: 0, maxModel: 10000,
                                     modelInterval: 0.01, numberOfDigits: 2)
    var frequencyOption = RealOption(defaultModel: 8, minModel: 0.1, maxModel: 100000,
                                     modelInterval: 0.1, numberOfDigits: 1, unit: "rpb")
}

final class SineWaveView<T: BinderProtocol>: View, BindableReceiver {
    typealias Model = SineWave
    typealias ModelOption = SineWaveOption
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((SineWaveView<Binder>, BasicNotification) -> ())]()
    
    var option: ModelOption {
        didSet {
            amplitudeView.option = option.amplitudeOption
            frequencyView.option = option.frequencyOption
            updateWithModel()
        }
    }
    
    let amplitudeView: DiscreteRealView<Binder>
    let frequencyView: DiscreteRealView<Binder>
    
    var sizeType: SizeType {
        didSet {
            amplitudeView.sizeType = sizeType
            frequencyView.sizeType = sizeType
            updateLayout()
        }
    }
    let classNameView: TextFormView
    let classAmplitudeNameView: TextFormView
    let classFrequencyNameView: TextFormView
    
    init(binder: Binder, keyPath: BinderKeyPath, option: ModelOption,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        self.option = option
        
        amplitudeView = DiscreteRealView(binder: binder,
                                         keyPath: keyPath.appending(path: \SineWave.amplitude),
                                         option: option.amplitudeOption,
                                         frame: Layout.valueFrame(with: sizeType),
                                         sizeType: sizeType)
        frequencyView = DiscreteRealView(binder: binder,
                                         keyPath: keyPath.appending(path: \SineWave.frequency),
                                         option: option.frequencyOption,
                                         frame: Layout.valueFrame(with: sizeType),
                                         sizeType: sizeType)
        
        self.sizeType = sizeType
        classNameView = TextFormView(text: SineWave.name, font: Font.bold(with: sizeType))
        classAmplitudeNameView = TextFormView(text: "A:", font: Font.default(with: sizeType))
        classFrequencyNameView = TextFormView(text: "ƒ:")
        
        super.init()
        children = [classNameView,
                    classAmplitudeNameView, amplitudeView,
                    classFrequencyNameView, frequencyView]
        self.frame = frame
    }
    
    override var defaultBounds: Rect {
        let w = Layout.propertyWidth + Layout.basicPadding * 2
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
    func updateWithModel() {
        amplitudeView.updateWithModel()
        frequencyView.updateWithModel()
    }
}
extension SineWaveView: Localizable {
    func update(with locale: Locale) {
        updateLayout()
    }
}
extension SineWaveView: Queryable {
    static var referenceableType: Referenceable.Type {
        return Model.self
    }
}
extension SineWaveView: Assignable {
    func reset(for p: Point, _ version: Version) {
        push(option.defaultModel, to: version)
    }
    func copiedObjects(at p: Point) -> [Object] {
        return [Object(model)]
    }
    func paste(_ objects: [Any], for p: Point, _ version: Version) {
        for object in objects {
            if let model = object as? Model {
                push(model, to: version)
                return
            }
        }
    }
}
