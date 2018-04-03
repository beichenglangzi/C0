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

/**
 # Issue
 - 数を包括するNumberオブジェクトを設計
 */
typealias Number = CGFloat

extension Number: Referenceable {
    static let name = Localization(english: "Number", japanese: "数値")
}

protocol Slidable {
    var number: Number { get set }
    var defaultNumber: Number { get }
    var minNumber: Number { get }
    var maxNumber: Number { get }
    var exp: Number { get }
}

final class NumberView: Layer, Respondable, Slidable {
    static let name = Number.name
    static let feature = Localization(english: "Slider", japanese: "スライダー")
    
    var number: Number {
        didSet {
            updateWithNumber()
        }
    }
    var defaultNumber: Number
    
    var minNumber: Number {
        didSet {
            updateWithNumber()
        }
    }
    var maxNumber: Number {
        didSet {
            updateWithNumber()
        }
    }
    var exp: Number {
        didSet {
            updateWithNumber()
        }
    }
    
    var numberInterval: CGFloat
    
    var isInverted: Bool {
        didSet {
            updateWithNumber()
        }
    }
    var isVertical: Bool {
        didSet {
            updateWithNumber()
        }
    }
    var padding: CGFloat {
        didSet {
            updateWithNumber()
        }
    }
    
    let knob: Knob
    var backgroundLayers = [Layer]() {
        didSet {
            replace(children: backgroundLayers + [knob])
        }
    }
    
    init(frame: CGRect = CGRect(),
         number: Number = 0, defaultNumber: Number = 0,
         min: Number = 0, max: Number = 1, exp: Number = 1,
         numberInterval: CGFloat = 0, isInverted: Bool = false, isVertical: Bool = false,
         isSmall: Bool = false) {
        
        self.number = number.clip(min: min, max: max)
        self.defaultNumber = defaultNumber
        self.minNumber = min
        self.maxNumber = max
        self.exp = exp
        self.numberInterval = numberInterval
        self.isInverted = isInverted
        self.isVertical = isVertical
        padding = isSmall ? 6.0.cf : 8.0.cf
        knob = isSmall ? Knob(radius: 4) : Knob()
        
        super.init()
        append(child: knob)
        self.frame = frame
    }
    
    override var bounds: CGRect {
        didSet {
            updateWithNumber()
        }
    }
    private func updateWithNumber() {
        guard minNumber < maxNumber else {
            return
        }
        let t = (number - minNumber) / (maxNumber - minNumber)
        if isVertical {
            let y = padding + (bounds.height - padding * 2)
                * pow(isInverted ? 1 - t : t, 1 / exp)
            knob.position = CGPoint(x: bounds.midX, y: y)
        } else {
            let x = padding + (bounds.width - padding * 2)
                * pow(isInverted ? 1 - t : t, 1 / exp)
            knob.position = CGPoint(x: x, y: bounds.midY)
        }
    }
    
    private func intervalNumber(withNumber n: Number) -> Number {
        if numberInterval == 0 {
            return n
        } else {
            let t = floor(n / numberInterval) * numberInterval
            if n - t > numberInterval / 2 {
                return t + numberInterval
            } else {
                return t
            }
        }
    }
    func number(at point: CGPoint) -> Number {
        let n: Number
        if isVertical {
            let h = bounds.height - padding * 2
            if h > 0 {
                let y = (point.y - padding).clip(min: 0, max: h)
                n = (maxNumber - minNumber) * pow((isInverted ? (h - y) : y) / h, exp) + minNumber
            } else {
                n = minNumber
            }
        } else {
            let w = bounds.width - padding * 2
            if w > 0 {
                let x = (point.x - padding).clip(min: 0, max: w)
                n = (maxNumber - minNumber) * pow((isInverted ? (w - x) : x) / w, exp) + minNumber
            } else {
                n = minNumber
            }
        }
        return intervalNumber(withNumber: n).clip(min: minNumber, max: maxNumber)
    }
    
    var disabledRegisterUndo = false
    
    struct Binding {
        let view: NumberView, number: Number, oldNumber: Number, type: Action.SendType
    }
    var binding: ((Binding) -> ())?
    
    func delete(with event: KeyInputEvent) -> Bool {
        let number = defaultNumber.clip(min: minNumber, max: maxNumber)
        guard number != self.number else {
            return false
        }
        set(number, oldNumber: self.number)
        return true
    }
    func copy(with event: KeyInputEvent) -> CopyManager? {
        return CopyManager(copiedObjects: [String(number.d)])
    }
    func paste(_ copyManager: CopyManager, with event: KeyInputEvent) -> Bool {
        for object in copyManager.copiedObjects {
            if let string = object as? String {
                if let number = Double(string)?.cf {
                    guard number != self.number else {
                        continue
                    }
                    set(number, oldNumber: self.number)
                    return true
                }
            }
        }
        return false
    }
    
    private var oldNumber = 0.0.cf, oldPoint = CGPoint()
    func move(with event: DragEvent) -> Bool {
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            knob.fillColor = .editing
            oldNumber = number
            oldPoint = p
            binding?(Binding(view: self, number: number, oldNumber: oldNumber, type: .begin))
            number = self.number(at: p)
            binding?(Binding(view: self, number: number, oldNumber: oldNumber, type: .sending))
        case .sending:
            number = self.number(at: p)
            binding?(Binding(view: self, number: number, oldNumber: oldNumber, type: .sending))
        case .end:
            number = self.number(at: p)
            if number != oldNumber {
                registeringUndoManager?.registerUndo(withTarget: self) { [number, oldNumber] in
                    $0.set(oldNumber, oldNumber: number)
                }
            }
            binding?(Binding(view: self, number: number, oldNumber: oldNumber, type: .end))
            knob.fillColor = .knob
        }
        return true
    }
    
    private func set(_ number: Number, oldNumber: Number) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldNumber, oldNumber: number) }
        binding?(Binding(view: self, number: oldNumber, oldNumber: oldNumber, type: .begin))
        self.number = number
        binding?(Binding(view: self, number: number, oldNumber: oldNumber, type: .end))
    }
}

/**
 # Issue
 - スクロールによる値の変更
 */
final class RelativeNumberView: Responder, Slidable {
    static let name = Number.name
    static let feature = Localization(english: "Relative Slider", japanese: "離散スライダー")
    
    var number: Number {
        didSet {
            updateWithNumber()
        }
    }
    
    var unit: String {
        didSet {
            updateWithNumber()
        }
    }
    var numberOfDigits: Int {
        didSet {
            updateWithNumber()
        }
    }
    
    var defaultNumber: Number
    var minNumber: Number {
        didSet {
            updateWithNumber()
        }
    }
    var maxNumber: Number {
        didSet {
            updateWithNumber()
        }
    }
    var exp: Number
    
    var numberInterval: CGFloat, isInverted: Bool, isVertical: Bool
    
    private var knobLineFrame = CGRect()
    private let labelPaddingX = Layout.basicPadding, knobPadding = 3.0.cf
    private var numberX = 1.0.cf
    
    private let knob = DiscreteKnob(CGSize(width: 6, height: 4), lineWidth: 1)
    private let lineLayer: Layer = {
        let lineLayer = Layer()
        lineLayer.lineColor = .content
        return lineLayer
    } ()
    
    let label: Label
    
    init(frame: CGRect = CGRect(),
         number: Number = 0, defaultNumber: Number = 0,
         min: Number = 0, max: Number = 1, exp: Number = 1,
         numberInterval: Number = 1, isInverted: Bool = false, isVertical: Bool = false,
         numberOfDigits: Int = 0, unit: String = "", font: Font = .default) {
        
        self.number = number.clip(min: min, max: max)
        self.defaultNumber = defaultNumber
        self.minNumber = min
        self.maxNumber = max
        self.exp = exp
        self.numberInterval = numberInterval
        self.isInverted = isInverted
        self.isVertical = isVertical
        self.numberOfDigits = numberOfDigits
        self.unit = unit
        label = Label(font: font)
        label.frame.origin = CGPoint(x: labelPaddingX,
                                     y: round((frame.height - label.frame.height) / 2))
        
        super.init()
        isClipped = true
        replace(children: [label, lineLayer, knob])
        self.frame = frame
    }
    
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    private func updateLayout() {
        knobLineFrame = CGRect(x: 5, y: 2, width: bounds.width - 10, height: 1)
        lineLayer.frame = knobLineFrame
        label.frame.origin.y = round((bounds.height - label.frame.height) / 2)
        
        updateWithNumber()
    }
    private func updateWithNumber() {
        if number - floor(number) > 0 {
            label.localization = Localization(String(format: numberOfDigits == 0 ?
                "%g" : "%.\(numberOfDigits)f", number) + "\(unit)")
        } else {
            label.localization = Localization("\(Int(number))" + "\(unit)")
        }
        if number < defaultNumber {
            let x = (knobLineFrame.width / 2) * (number - minNumber) / (defaultNumber - minNumber)
                + knobLineFrame.minX
            knob.position = CGPoint(x: round(x), y: knobPadding)
        } else {
            let x = (knobLineFrame.width / 2) * (number - defaultNumber) / (maxNumber - defaultNumber)
                + knobLineFrame.midX
            knob.position = CGPoint(x: round(x), y: knobPadding)
        }
    }
    
    private func number(withDelta delta: Number) -> Number {
        let d = (delta / numberX) * numberInterval
        if exp == 1 {
            return d.interval(scale: numberInterval)
        } else {
            return (d >= 0 ? pow(d, exp) : -pow(abs(d), exp)).interval(scale: numberInterval)
        }
    }
    private func number(at p: CGPoint, oldNumber: Number) -> Number {
        let d = isVertical ? p.y - oldPoint.y : p.x - oldPoint.x
        let v = oldNumber.interval(scale: numberInterval) + number(withDelta: isInverted ? -d : d)
        return v.clip(min: minNumber, max: maxNumber)
    }
    
    var isLocked = false {
        didSet {
            if isLocked != oldValue {
                opacity = isLocked ? 0.35 : 1
            }
        }
    }
    
    var disabledRegisterUndo = false
    
    struct Binding {
        let view: RelativeNumberView, number: Number, oldNumber: Number, type: Action.SendType
    }
    var binding: ((Binding) -> ())?
    
    func delete(with event: KeyInputEvent) -> Bool {
        let number = defaultNumber.clip(min: minNumber, max: maxNumber)
        guard number != self.number else {
            return false
        }
        set(number, oldNumber: self.number)
        return true
    }
    func copy(with event: KeyInputEvent) -> CopyManager? {
        return CopyManager(copiedObjects: [String(number.d)])
    }
    func paste(_ copyManager: CopyManager, with event: KeyInputEvent) -> Bool {
        guard !isLocked else {
            return false
        }
        for object in copyManager.copiedObjects {
            if let string = object as? String {
                if let v = Double(string)?.cf {
                    let number = v.clip(min: minNumber, max: maxNumber)
                    guard number != self.number else {
                        continue
                    }
                    set(number, oldNumber: self.number)
                    return true
                }
            }
        }
        return false
    }
    
    private var oldNumber = 0.0.cf, oldPoint = CGPoint()
    func move(with event: DragEvent) -> Bool {
        guard !isLocked else {
            return false
        }
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            knob.fillColor = .editing
            oldNumber = number
            oldPoint = p
            binding?(Binding(view: self, number: number, oldNumber: oldNumber, type: .begin))
            number = self.number(at: p, oldNumber: oldNumber)
            binding?(Binding(view: self, number: number, oldNumber: oldNumber, type: .sending))
        case .sending:
            number = self.number(at: p, oldNumber: oldNumber)
            binding?(Binding(view: self, number: number, oldNumber: oldNumber, type: .sending))
        case .end:
            number = self.number(at: p, oldNumber: oldNumber)
            if number != oldNumber {
                registeringUndoManager?.registerUndo(withTarget: self) { [number, oldNumber] in
                    $0.set(oldNumber, oldNumber: number)
                }
            }
            binding?(Binding(view: self, number: number, oldNumber: oldNumber, type: .end))
            knob.fillColor = .knob
        }
        return true
    }
    
    private func set(_ number: Number, oldNumber: Number) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldNumber, oldNumber: number) }
        binding?(Binding(view: self, number: oldNumber, oldNumber: oldNumber, type: .begin))
        self.number = number
        binding?(Binding(view: self, number: number, oldNumber: oldNumber, type: .end))
    }
}

final class CircularNumberView: PathLayer, Respondable, Slidable {
    static let name = Number.name
    static let feature = Localization(english: "Circular Slider", japanese: "円状スライダー")
    
    var number: Number {
        didSet {
            updateWithNumber()
        }
    }
    var defaultNumber: Number
    
    var minNumber: Number {
        didSet {
            updateWithNumber()
        }
    }
    var maxNumber: Number {
        didSet {
            updateWithNumber()
        }
    }
    var exp: Number {
        didSet {
            updateWithNumber()
        }
    }
    
    var isClockwise: Bool, beginAngle: CGFloat
    var numberInterval: CGFloat
    var width: CGFloat
    
    let knob: Knob
    var backgroundLayers = [Layer]() {
        didSet {
            replace(children: backgroundLayers + [knob])
        }
    }
    
    init(frame: CGRect = CGRect(),
         number: Number = 0, defaultNumber: Number = 0,
         min: Number = -.pi, max: Number = .pi, exp: Number = 1,
         isClockwise: Bool = false, beginAngle: CGFloat = 0,
         numberInterval: CGFloat = 0, width: CGFloat = 16,
         isSmall: Bool = false) {
        
        self.number = number
        self.defaultNumber = defaultNumber
        self.minNumber = min
        self.maxNumber = max
        self.exp = exp
        self.isClockwise = isClockwise
        self.beginAngle = beginAngle
        self.numberInterval = numberInterval
        self.width = width
        knob = isSmall ? Knob(radius: 4) : Knob()
        
        super.init()
        fillColor = nil
        lineWidth = 0.5
        append(child: knob)
        self.frame = frame
    }
    
    override func contains(_ p: CGPoint) -> Bool {
        let cp = CGPoint(x: bounds.midX, y: bounds.midY), r = bounds.width / 2
        let d = cp.distance(p)
        return d >= r - width && d <= r
    }
    
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    private func updateLayout() {
        let cp = CGPoint(x: bounds.midX, y: bounds.midY), r = bounds.width / 2
        let path = CGMutablePath()
        path.addArc(center: cp, radius: r, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        path.move(to: cp + CGPoint(x: r - width, y: 0))
        path.addArc(center: cp, radius: r - width, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
        self.path = path
        updateWithNumber()
    }
    private func updateWithNumber() {
        guard minNumber < maxNumber else {
            return
        }
        let t = pow((number - minNumber) / (maxNumber - minNumber), 1 / exp)
        let theta = isClockwise ? beginAngle - t * (2 * .pi) : beginAngle + t * (2 * .pi)
        let cp = CGPoint(x: bounds.midX, y: bounds.midY), r = bounds.width / 2 - width / 2
        knob.position = cp + r * CGPoint(x: cos(theta), y: sin(theta))
    }
    
    private func intervalNumber(withNumber n: Number) -> Number {
        if numberInterval == 0 {
            return n
        } else {
            let t = floor(n / numberInterval) * numberInterval
            if n - t > numberInterval / 2 {
                return t + numberInterval
            } else {
                return t
            }
        }
    }
    func number(at p: CGPoint) -> Number {
        guard !bounds.isEmpty else {
            return intervalNumber(withNumber: number).clip(min: minNumber, max: maxNumber)
        }
        let cp = CGPoint(x: bounds.midX, y: bounds.midY)
        let theta = cp.tangential(p)
        let t = (theta > beginAngle ? theta - beginAngle : theta - beginAngle + 2 * .pi) / (2 * .pi)
        let ct = isClockwise ? 1 - t : t
        let n = (maxNumber - minNumber) * pow(ct, exp) + minNumber
        return intervalNumber(withNumber: n).clip(min: minNumber, max: maxNumber)
    }
    
    var disabledRegisterUndo = false
    
    struct Binding {
        let view: CircularNumberView, number: Number, oldNumber: Number, type: Action.SendType
    }
    var binding: ((Binding) -> ())?
    
    func delete(with event: KeyInputEvent) -> Bool {
        let number = defaultNumber.clip(min: minNumber, max: maxNumber)
        guard number != self.number else {
            return false
        }
        set(number, oldNumber: self.number)
        return true
    }
    func copy(with event: KeyInputEvent) -> CopyManager? {
        return CopyManager(copiedObjects: [String(number.d)])
    }
    func paste(_ copyManager: CopyManager, with event: KeyInputEvent) -> Bool {
        for object in copyManager.copiedObjects {
            if let string = object as? String {
                if let number = Double(string)?.cf {
                    guard number != self.number else {
                        continue
                    }
                    set(number, oldNumber: self.number)
                    return true
                }
            }
        }
        return false
    }
    
    private var oldNumber = 0.0.cf, oldPoint = CGPoint()
    func move(with event: DragEvent) -> Bool {
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            knob.fillColor = .editing
            oldNumber = number
            oldPoint = p
            binding?(Binding(view: self, number: number, oldNumber: oldNumber, type: .begin))
            number = self.number(at: p)
            binding?(Binding(view: self, number: number, oldNumber: oldNumber, type: .sending))
        case .sending:
            number = self.number(at: p)
            binding?(Binding(view: self, number: number, oldNumber: oldNumber, type: .sending))
        case .end:
            number = self.number(at: p)
            if number != oldNumber {
                registeringUndoManager?.registerUndo(withTarget: self) { [number, oldNumber] in
                    $0.set(oldNumber, oldNumber: number)
                }
            }
            binding?(Binding(view: self, number: number, oldNumber: oldNumber, type: .end))
            knob.fillColor = .knob
        }
        return true
    }
    
    private func set(_ number: Number, oldNumber: Number) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldNumber, oldNumber: number) }
        binding?(Binding(view: self, number: oldNumber, oldNumber: oldNumber, type: .begin))
        self.number = number
        binding?(Binding(view: self, number: number, oldNumber: oldNumber, type: .end))
    }
}
