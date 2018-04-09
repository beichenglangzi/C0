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
    var amplitude = CGPoint(), frequency = RPB(8)
    
    func with(amplitude: CGPoint) -> Wiggle {
        return Wiggle(amplitude: amplitude, frequency: frequency)
    }
    func with(frequency: RPB) -> Wiggle {
        return Wiggle(amplitude: amplitude, frequency: frequency)
    }
    
    var isEmpty: Bool {
        return amplitude == CGPoint()
    }
    func phasePosition(with position: CGPoint, phase: CGFloat) -> CGPoint {
        let x = sin(2 * (.pi) * phase)
        return CGPoint(x: position.x + amplitude.x * x, y: position.y + amplitude.y * x)
    }
}
extension Wiggle: Interpolatable {
    static func linear(_ f0: Wiggle, _ f1: Wiggle, t: CGFloat) -> Wiggle {
        let amplitude = CGPoint.linear(f0.amplitude, f1.amplitude, t: t)
        let frequency = CGFloat.linear(f0.frequency, f1.frequency, t: t)
        return Wiggle(amplitude: amplitude, frequency: frequency)
    }
    static func firstMonospline(_ f1: Wiggle, _ f2: Wiggle,
                                _ f3: Wiggle, with ms: Monospline) -> Wiggle {
        let amplitude = CGPoint.firstMonospline(f1.amplitude, f2.amplitude, f3.amplitude, with: ms)
        let frequency = CGFloat.firstMonospline(f1.frequency, f2.frequency, f3.frequency, with: ms)
        return Wiggle(amplitude: amplitude, frequency: frequency)
    }
    static func monospline(_ f0: Wiggle, _ f1: Wiggle,
                           _ f2: Wiggle, _ f3: Wiggle, with ms: Monospline) -> Wiggle {
        let amplitude = CGPoint.monospline(f0.amplitude, f1.amplitude,
                                           f2.amplitude, f3.amplitude, with: ms)
        let frequency = CGFloat.monospline(f0.frequency, f1.frequency,
                                           f2.frequency, f3.frequency, with: ms)
        return Wiggle(amplitude: amplitude, frequency: frequency)
    }
    static func lastMonospline(_ f0: Wiggle, _ f1: Wiggle,
                               _ f2: Wiggle, with ms: Monospline) -> Wiggle {
        let amplitude = CGPoint.lastMonospline(f0.amplitude, f1.amplitude, f2.amplitude, with: ms)
        let frequency = CGFloat.lastMonospline(f0.frequency, f1.frequency, f2.frequency, with: ms)
        return Wiggle(amplitude: amplitude, frequency: frequency)
    }
}
extension Wiggle: Referenceable {
    static let name = Localization(english: "Wiggle", japanese: "振動")
}
extension Wiggle: ObjectViewExpression {
    func thumbnail(withBounds bounds: CGRect, sizeType: SizeType) -> Layer {
        return Layer()
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
    
    private let classNameLabel = Label(text: Wiggle.name, font: .bold)
    private let xLabel = Label(text: Localization("x:"))
    private let xView = DiscreteNumberView(frame: Layout.valueFrame,
                                           min: 0, max: 1000, numberInterval: 0.01)
    private let yLabel = Label(text: Localization("y:"))
    private let yView = DiscreteNumberView(frame: Layout.valueFrame,
                                           min: 0, max: 1000, numberInterval: 0.01)
    private let frequencyLabel = Label(text: Localization("ƒ:"))
    private let frequencyView = DiscreteNumberView(frame: Layout.valueFrame,
                                                   min: 0.1, max: 100000,
                                                   numberInterval: 0.1, unit: " rpb")
    override init() {
        frequencyView.defaultNumber = wiggle.frequency
        frequencyView.number = wiggle.frequency
        
        super.init()
        replace(children: [classNameLabel, xLabel, xView, yLabel, yView,
                           frequencyLabel, frequencyView])
        
        xView.binding = { [unowned self] in self.setWiggle(with: $0) }
        yView.binding = { [unowned self] in self.setWiggle(with: $0) }
        frequencyView.binding = { [unowned self] in self.setWiggle(with: $0) }
    }
    
    override var locale: Locale {
        didSet {
            updateLayout()
        }
    }
    
    var isHorizontal = false
    override var defaultBounds: CGRect {
        if isHorizontal {
            let children = [classNameLabel, Padding(), xLabel, xView, Padding(),
                            yLabel, yView, frequencyLabel, frequencyView]
            return CGRect(x: 0,
                          y: 0,
                          width: Layout.leftAlignmentWidth(children) + Layout.basicPadding,
                          height: Layout.basicHeight)
        } else {
            let w = MaterialView.defaultWidth + Layout.basicPadding * 2
            let h = Layout.basicHeight * 2 + Layout.basicPadding * 2
            return CGRect(x: 0, y: 0, width: w, height: h)
        }
    }
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    private func updateLayout() {
        if isHorizontal {
            let children = [classNameLabel, Padding(), xLabel, xView, Padding(),
                            yLabel, yView, frequencyView]
            _ = Layout.leftAlignment(children, height: frame.height)
        } else {
            var y = bounds.height - Layout.basicPadding - classNameLabel.frame.height
            classNameLabel.frame.origin = CGPoint(x: Layout.basicPadding, y: y)
            y = bounds.height - Layout.basicPadding - Layout.basicHeight
            _ = Layout.leftAlignment([frequencyLabel, frequencyView],
                                     y: y, height: Layout.basicHeight)
            y -= Layout.basicHeight
            _ = Layout.leftAlignment([xLabel, xView, Padding(), yLabel, yView],
                                     y: y, height: Layout.basicHeight)
            if yView.frame.maxX < bounds.width - Layout.basicPadding {
                yView.frame.origin.x = bounds.width - Layout.basicPadding - yView.frame.width
            }
            frequencyView.frame.origin.x = yView.frame.minX
            frequencyLabel.frame.origin.x = frequencyView.frame.minX - frequencyLabel.frame.width
        }
    }
    private func updateWithWiggle() {
        xView.number = 10 * wiggle.amplitude.x / standardAmplitude.x
        yView.number = 10 * wiggle.amplitude.y / standardAmplitude.y
        frequencyView.number = wiggle.frequency
    }
    
    var standardAmplitude = CGPoint(x: 1, y: 1)
    
    var disabledRegisterUndo = true
    
    struct Binding {
        let wiggleView: WiggleView
        let wiggle: Wiggle, oldWiggle: Wiggle, type: Action.SendType
    }
    var binding: ((Binding) -> ())?
    
    private var oldWiggle = Wiggle()
    private func setWiggle(with obj: DiscreteNumberView.Binding) {
        if obj.type == .begin {
            oldWiggle = wiggle
            binding?(Binding(wiggleView: self,
                             wiggle: oldWiggle, oldWiggle: oldWiggle, type: .begin))
        } else {
            switch obj.view {
            case xView:
                wiggle = wiggle.with(amplitude: CGPoint(x: obj.number * standardAmplitude.x / 10,
                                                        y: wiggle.amplitude.y))
            case yView:
                wiggle = wiggle.with(amplitude: CGPoint(x: wiggle.amplitude.x,
                                                        y: obj.number * standardAmplitude.y / 10))
            case frequencyView:
                wiggle = wiggle.with(frequency: obj.number)
            default:
                fatalError("No case")
            }
            binding?(Binding(wiggleView: self,
                             wiggle: wiggle, oldWiggle: oldWiggle, type: obj.type))
        }
    }
    
    func delete(with event: KeyInputEvent) -> Bool {
        let wiggle = Wiggle()
        guard wiggle != self.wiggle else {
            return false
        }
        set(wiggle, oldWiggle: self.wiggle)
        return true
    }
    func copiedObjects(with event: KeyInputEvent) -> [ViewExpression]? {
        return [wiggle]
    }
    func paste(_ objects: [Any], with event: KeyInputEvent) -> Bool {
        for object in objects {
            if let wiggle = object as? Wiggle {
                if wiggle != self.wiggle {
                    set(wiggle, oldWiggle: self.wiggle)
                    return true
                }
            }
        }
        return false
    }
    
    private func set(_ wiggle: Wiggle, oldWiggle: Wiggle) {
        registeringUndoManager?.registerUndo(withTarget: self) {
            $0.set(oldWiggle, oldWiggle: wiggle)
        }
        binding?(Binding(wiggleView: self, wiggle: oldWiggle, oldWiggle: oldWiggle, type: .begin))
        self.wiggle = wiggle
        binding?(Binding(wiggleView: self, wiggle: wiggle, oldWiggle: oldWiggle, type: .end))
    }
    
    func reference(with event: TapEvent) -> Reference? {
        return wiggle.reference
    }
}
