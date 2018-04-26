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

typealias RPB = CGFloat
struct Wiggle: Codable, Equatable, Hashable {
    var amplitude = 0.0.cf, frequency = RPB(8)
    
    static let amplitudeOption = RealNumberOption(defaultModel: 0, minModel: 0, maxModel: 10000,
                                              modelInterval: 0.01, exp: 1,
                                              numberOfDigits: 2, unit: "")
    static let frequencyOption = RealNumberOption(defaultModel: 8, minModel: 0.1, maxModel: 100000,
                                              modelInterval: 0.1, exp: 1,
                                              numberOfDigits: 1, unit: "rpb")
    var isEmpty: Bool {
        return amplitude == 0
    }
    func phase(with value: CGFloat, phase: CGFloat) -> CGFloat {
        let x = sin(2 * (.pi) * phase)
        return value + amplitude * x
    }
}
extension Wiggle: Interpolatable {
    static func linear(_ f0: Wiggle, _ f1: Wiggle, t: CGFloat) -> Wiggle {
        let amplitude = CGFloat.linear(f0.amplitude, f1.amplitude, t: t)
        let frequency = CGFloat.linear(f0.frequency, f1.frequency, t: t)
        return Wiggle(amplitude: amplitude, frequency: frequency)
    }
    static func firstMonospline(_ f1: Wiggle, _ f2: Wiggle,
                                _ f3: Wiggle, with ms: Monospline) -> Wiggle {
        let amplitude = CGFloat.firstMonospline(f1.amplitude, f2.amplitude, f3.amplitude, with: ms)
        let frequency = CGFloat.firstMonospline(f1.frequency, f2.frequency, f3.frequency, with: ms)
        return Wiggle(amplitude: amplitude, frequency: frequency)
    }
    static func monospline(_ f0: Wiggle, _ f1: Wiggle,
                           _ f2: Wiggle, _ f3: Wiggle, with ms: Monospline) -> Wiggle {
        let amplitude = CGFloat.monospline(f0.amplitude, f1.amplitude,
                                           f2.amplitude, f3.amplitude, with: ms)
        let frequency = CGFloat.monospline(f0.frequency, f1.frequency,
                                           f2.frequency, f3.frequency, with: ms)
        return Wiggle(amplitude: amplitude, frequency: frequency)
    }
    static func lastMonospline(_ f0: Wiggle, _ f1: Wiggle,
                               _ f2: Wiggle, with ms: Monospline) -> Wiggle {
        let amplitude = CGFloat.lastMonospline(f0.amplitude, f1.amplitude, f2.amplitude, with: ms)
        let frequency = CGFloat.lastMonospline(f0.frequency, f1.frequency, f2.frequency, with: ms)
        return Wiggle(amplitude: amplitude, frequency: frequency)
    }
}
extension Wiggle: Referenceable {
    static let name = Localization(english: "Wiggle", japanese: "振動")
}
extension Wiggle: ObjectViewExpression {
    func thumbnail(withBounds bounds: CGRect, _ sizeType: SizeType) -> View {
        return View(isForm: true)
    }
}

final class WiggleView: View, Assignable {
    var wiggle = Wiggle() {
        didSet {
            if wiggle != oldValue {
                updateWithWiggle()
            }
        }
    }
    
    let classNameView: TextView
    let classAmplitudeNameView: TextView
    let amplitudeView: DiscreteRealNumberView
    let classFrequencyNameView: TextView
    let frequencyView: DiscreteRealNumberView
    
    init(sizeType: SizeType = .regular) {
        classNameView = TextView(text: Wiggle.name, font: Font.bold(with: sizeType))
        classAmplitudeNameView = TextView(text: Localization("A:"), font: Font.default(with: sizeType))
        amplitudeView = DiscreteRealNumberView(model: wiggle.amplitude, option: Wiggle.amplitudeOption,
                                               frame: Layout.valueFrame(with: sizeType),
                                               sizeType: sizeType)
        classFrequencyNameView = TextView(text: Localization("ƒ:"))
        frequencyView = DiscreteRealNumberView(model: wiggle.frequency, option: Wiggle.frequencyOption,
                                               frame: Layout.valueFrame(with: sizeType),
                                               sizeType: sizeType)
        
        super.init()
        children = [classNameView,
                    classAmplitudeNameView, amplitudeView,
                    classFrequencyNameView, frequencyView]
        
        amplitudeView.binding = { [unowned self] in self.setWiggle(with: $0) }
        frequencyView.binding = { [unowned self] in self.setWiggle(with: $0) }
    }
    
    override var locale: Locale {
        didSet {
            updateLayout()
        }
    }
    
    override var defaultBounds: CGRect {
        let w = MaterialView.defaultWidth + Layout.basicPadding * 2
        let h = Layout.basicHeight * 2 + Layout.basicPadding * 2
        return CGRect(x: 0, y: 0, width: w, height: h)
    }
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    private func updateLayout() {
        var y = bounds.height - Layout.basicPadding - classNameView.frame.height
        classNameView.frame.origin = CGPoint(x: Layout.basicPadding, y: y)
        y = bounds.height - Layout.basicPadding - Layout.basicHeight
        _ = Layout.leftAlignment([classFrequencyNameView, frequencyView],
                                 y: y, height: Layout.basicHeight)
        y -= Layout.basicHeight
        classFrequencyNameView.frame.origin.x
            = frequencyView.frame.minX - classFrequencyNameView.frame.width
    }
    private func updateWithWiggle() {
        amplitudeView.model = 10 * wiggle.amplitude / standardAmplitude
        frequencyView.model = wiggle.frequency
    }
    
    var standardAmplitude = 1.0.cf
    
    var disabledRegisterUndo = true
    
    struct Binding {
        let wiggleView: WiggleView
        let wiggle: Wiggle, oldWiggle: Wiggle, phase: Phase
    }
    var binding: ((Binding) -> ())?
    
    private var oldWiggle = Wiggle()
    private func setWiggle(with obj: DiscreteRealNumberView.Binding<RealNumber>) {
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
    
    func delete(for p: CGPoint) {
        let wiggle = Wiggle()
        guard wiggle != self.wiggle else {
            return
        }
        set(wiggle, oldWiggle: self.wiggle)
    }
    func copiedViewables(at p: CGPoint) -> [Viewable] {
        return [wiggle]
    }
    func paste(_ objects: [Any], for p: CGPoint) {
        for object in objects {
            if let wiggle = object as? Wiggle {
                if wiggle != self.wiggle {
                    set(wiggle, oldWiggle: self.wiggle)
                    return
                }
            }
        }
    }
    
    private func set(_ wiggle: Wiggle, oldWiggle: Wiggle) {
        registeringUndoManager?.registerUndo(withTarget: self) {
            $0.set(oldWiggle, oldWiggle: wiggle)
        }
        binding?(Binding(wiggleView: self, wiggle: oldWiggle, oldWiggle: oldWiggle, phase: .began))
        self.wiggle = wiggle
        binding?(Binding(wiggleView: self, wiggle: wiggle, oldWiggle: oldWiggle, phase: .ended))
    }
    
    func reference(at p: CGPoint) -> Reference {
        return Wiggle.reference
    }
}
