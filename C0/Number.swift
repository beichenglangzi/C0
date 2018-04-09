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
extension Number: ObjectViewExpression {
    func thumbnail(withBounds bounds: CGRect, sizeType: SizeType) -> Layer {
        return String(self.d).view(withBounds: bounds, sizeType: sizeType)
    }
}

protocol Slidable {
    var number: Number { get set }
    var defaultNumber: Number { get }
    var minNumber: Number { get }
    var maxNumber: Number { get }
    var exp: Number { get }
}

final class NumberView: View, Slidable {
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
         sizeType: SizeType = .regular) {
        
        self.number = number.clip(min: min, max: max)
        self.defaultNumber = defaultNumber
        self.minNumber = min
        self.maxNumber = max
        self.exp = exp
        self.numberInterval = numberInterval
        self.isInverted = isInverted
        self.isVertical = isVertical
        padding = sizeType == .small ? 6.0.cf : 8.0.cf
        knob = sizeType == .small ? Knob(radius: 4) : Knob()
        
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
        if number != self.number {
            set(number, old: self.number)
        }
        return true
    }
    func copiedObjects(with event: KeyInputEvent) -> [ViewExpression]? {
        return [number, String(number.d)]
    }
    func paste(_ objects: [Any], with event: KeyInputEvent) -> Bool {
        for object in objects {
            if let number = (object as? Number)?.clip(min: minNumber, max: maxNumber) {
                if number != self.number {
                    set(number, old: self.number)
                    return true
                }
            } else if let string = object as? String {
                if let number = Double(string)?.cf.clip(min: minNumber, max: maxNumber) {
                    if number != self.number {
                        set(number, old: self.number)
                        return true
                    }
                }
            }
        }
        return false
    }
    
    func run(with event: ClickEvent) -> Bool {
        let p = point(from: event)
        let number = self.number(at: p)
        if number != self.number {
            set(number, old: self.number)
        }
        return true
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
                    $0.set(oldNumber, old: number)
                }
            }
            binding?(Binding(view: self, number: number, oldNumber: oldNumber, type: .end))
            knob.fillColor = .knob
        }
        return true
    }
    
    private func set(_ number: Number, old oldNumber: Number) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldNumber, old: number) }
        binding?(Binding(view: self, number: oldNumber, oldNumber: oldNumber, type: .begin))
        self.number = number
        binding?(Binding(view: self, number: number, oldNumber: oldNumber, type: .end))
    }
    
    func reference(with event: TapEvent) -> Reference? {
        var reference = number.reference
        reference.viewDescription = Localization(english: "Slider", japanese: "スライダー")
        return reference
    }
}

/**
 # Issue
 - スクロールによる値の変更
 */
final class DiscreteNumberView: View, Slidable {
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
    private var numberX = 1.5.cf
    
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
    private func number(at p: CGPoint, old oldNumber: Number) -> Number {
        let d = isVertical ? p.y - oldPoint.y : p.x - oldPoint.x
        let v = oldNumber.interval(scale: numberInterval) + number(withDelta: isInverted ? -d : d)
        return v.clip(min: minNumber, max: maxNumber)
    }
    
    var disabledRegisterUndo = false
    
    struct Binding {
        let view: DiscreteNumberView, number: Number, oldNumber: Number, type: Action.SendType
    }
    var binding: ((Binding) -> ())?
    
    func delete(with event: KeyInputEvent) -> Bool {
        let number = defaultNumber.clip(min: minNumber, max: maxNumber)
        if number != self.number {
            set(number, old: self.number)
        }
        return true
    }
    func copiedObjects(with event: KeyInputEvent) -> [ViewExpression]? {
        return [number, String(number.d)]
    }
    func paste(_ objects: [Any], with event: KeyInputEvent) -> Bool {
        for object in objects {
            if let number = (object as? Number)?.clip(min: minNumber, max: maxNumber) {
                if number != self.number {
                    set(number, old: self.number)
                    return true
                }
            } else if let string = object as? String {
                if let number = Double(string)?.cf.clip(min: minNumber, max: maxNumber) {
                    if number != self.number {
                        set(number, old: self.number)
                        return true
                    }
                }
            }
        }
        return false
    }
    
    func run(with event: ClickEvent) -> Bool {
        let p = point(from: event)
        let number = self.number(at: p, old: self.number)
        if number != self.number {
            set(number, old: self.number)
        }
        return true
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
            number = self.number(at: p, old: oldNumber)
            binding?(Binding(view: self, number: number, oldNumber: oldNumber, type: .sending))
        case .sending:
            number = self.number(at: p, old: oldNumber)
            binding?(Binding(view: self, number: number, oldNumber: oldNumber, type: .sending))
        case .end:
            number = self.number(at: p, old: oldNumber)
            if number != oldNumber {
                registeringUndoManager?.registerUndo(withTarget: self) { [number, oldNumber] in
                    $0.set(oldNumber, old: number)
                }
            }
            binding?(Binding(view: self, number: number, oldNumber: oldNumber, type: .end))
            knob.fillColor = .knob
        }
        return true
    }
    
    private func set(_ number: Number, old oldNumber: Number) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldNumber, old: number) }
        binding?(Binding(view: self, number: oldNumber, oldNumber: oldNumber, type: .begin))
        self.number = number
        binding?(Binding(view: self, number: number, oldNumber: oldNumber, type: .end))
    }
    
    func reference(with event: TapEvent) -> Reference? {
        var reference = number.reference
        reference.viewDescription = Localization(english: "Discrete Slider", japanese: "離散スライダー")
        return reference
    }
}

final class CircularNumberView: PathView, Slidable {
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
         isClockwise: Bool = false, beginAngle: CGFloat = -.pi,
         numberInterval: CGFloat = 0, width: CGFloat = 16,
         sizeType: SizeType = .regular) {
        
        self.number = number
        self.defaultNumber = defaultNumber
        self.minNumber = min
        self.maxNumber = max
        self.exp = exp
        self.isClockwise = isClockwise
        self.beginAngle = beginAngle
        self.numberInterval = numberInterval
        self.width = width
        knob = sizeType == .small ? Knob(radius: 4) : Knob()
        
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
        if number != self.number {
            set(number, old: self.number)
        }
        return true
    }
    func copiedObjects(with event: KeyInputEvent) -> [ViewExpression]? {
        return [number, String(number.d)]
    }
    func paste(_ objects: [Any], with event: KeyInputEvent) -> Bool {
        for object in objects {
            if let number = (object as? Number)?.clip(min: minNumber, max: maxNumber) {
                if number != self.number {
                    set(number, old: self.number)
                    return true
                }
            } else if let string = object as? String {
                if let number = Double(string)?.cf.clip(min: minNumber, max: maxNumber) {
                    if number != self.number {
                        set(number, old: self.number)
                        return true
                    }
                }
            }
        }
        return false
    }
    
    func run(with event: ClickEvent) -> Bool {
        let p = point(from: event)
        let number = self.number(at: p)
        if number != self.number {
            set(number, old: self.number)
        }
        return true
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
                    $0.set(oldNumber, old: number)
                }
            }
            binding?(Binding(view: self, number: number, oldNumber: oldNumber, type: .end))
            knob.fillColor = .knob
        }
        return true
    }
    
    private func set(_ number: Number, old oldNumber: Number) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldNumber, old: number) }
        binding?(Binding(view: self, number: oldNumber, oldNumber: oldNumber, type: .begin))
        self.number = number
        binding?(Binding(view: self, number: number, oldNumber: oldNumber, type: .end))
    }
    
    func reference(with event: TapEvent) -> Reference? {
        var reference = number.reference
        reference.viewDescription = Localization(english: "Circular Slider", japanese: "円状スライダー")
        return reference
    }
}

final class ProgressNumberView: View {
    let barLayer = Layer()
    let barBackgroundLayer = Layer()
    let nameLabel: Label
    
    init(frame: CGRect = CGRect(), backgroundColor: Color = .background,
         name: String = "", type: String = "", state: Localization? = nil) {
        
        self.name = name
        self.type = type
        self.state = state
        nameLabel = Label()
        nameLabel.frame.origin = CGPoint(x: Layout.basicPadding,
                                         y: round((frame.height - nameLabel.frame.height) / 2))
        barLayer.frame = CGRect(x: 0, y: 0, width: 0, height: frame.height)
        barBackgroundLayer.fillColor = .editing
        barLayer.fillColor = .content
        
        super.init()
        self.frame = frame
        isClipped = true
        replace(children: [nameLabel, barBackgroundLayer, barLayer])
        updateLayout()
    }
    
    var value = 0.0.cf {
        didSet {
            updateLayout()
        }
    }
    func begin() {
        startDate = Date()
    }
    func end() {}
    var startDate: Date?
    var remainingTime: Double? {
        didSet {
            updateString(with: Locale.current)
        }
    }
    var computationTime = 5.0
    var name = "" {
        didSet {
            updateString(with: locale)
        }
    }
    var type = "" {
        didSet {
            updateString(with: locale)
        }
    }
    var state: Localization? {
        didSet {
            updateString(with: locale)
        }
    }
    
    override var locale: Locale {
        didSet {
            updateLayout()
        }
    }
    
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    func updateLayout() {
        let padding = Layout.basicPadding
        barBackgroundLayer.frame = CGRect(x: padding, y: padding - 1,
                                          width: (bounds.width - padding * 2), height: 1)
        barLayer.frame = CGRect(x: padding, y: padding - 1,
                                width: floor((bounds.width - padding * 2) * value), height: 1)
        updateString(with: locale)
    }
    func updateString(with locale: Locale) {
        var string = ""
        if let state = state {
            string += state.string(with: locale)
        } else if let remainingTime = remainingTime {
            let minutes = Int(ceil(remainingTime)) / 60
            let seconds = Int(ceil(remainingTime)) - minutes * 60
            if minutes == 0 {
                let translator = Localization(english: "%@sec left",
                                              japanese: "あと%@秒").string(with: locale)
                string += (string.isEmpty ? "" : " ") + String(format: translator, String(seconds))
            } else {
                let translator = Localization(english: "%@min %@sec left",
                                              japanese: "あと%@分%@秒").string(with: locale)
                string += (string.isEmpty ? "" : " ") + String(format: translator,
                                                               String(minutes), String(seconds))
            }
        }
        nameLabel.string = type + "(" + name + "), "
            + string + (string.isEmpty ? "" : ", ") + "\(Int(value * 100)) %"
        nameLabel.frame.origin = CGPoint(x: Layout.basicPadding,
                                         y: round((frame.height - nameLabel.frame.height) / 2))
    }
    
    var deleteHandler: ((ProgressNumberView) -> (Bool))?
    weak var operation: Operation?
    func delete(with event: KeyInputEvent) -> Bool {
        if let operation = operation {
            operation.cancel()
        }
        return deleteHandler?(self) ?? false
    }
    
    func reference(with event: TapEvent) -> Reference? {
        return Reference(name: Localization(english: "Progress", japanese: "進捗"),
                         viewDescription: Localization(english: "Stop: Send \"Cut\" action",
                                                       japanese: "停止: \"カット\"アクションを送信"))
    }
}

