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

typealias Z = Int

extension Int {
    func interval(scale: Int) -> Int {
        if scale == 0 {
            return self
        } else {
            let t = (self / scale) * scale
            return self - t > scale / 2 ? t + scale : t
        }
    }
}

struct IntOption: OneDimensionalOption {
    typealias Model = Int
    
    var defaultModel: Model
    var minModel: Model
    var maxModel: Model
    var modelInterval: Model
    
    var exp = 1.0.cf
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
    func ratio(with model: Model) -> CGFloat {
        return (model - minModel).cf / (maxModel - minModel).cf
    }
    func ratioFromDefaultModel(with model: Model) -> CGFloat {
        if model < defaultModel {
            return ((model - minModel).cf / (defaultModel - minModel).cf) * 0.5
        } else {
            return ((model - defaultModel).cf / (maxModel - defaultModel).cf) * 0.5 + 0.5
        }
    }
    
    private func model(withDelta delta: CGFloat) -> Model {
        let d = delta * modelInterval.cf
        if exp == 1 {
            return Int(d).interval(scale: modelInterval)
        } else {
            return Int(d >= 0 ? pow(d, exp) : -pow(abs(d), exp)).interval(scale: modelInterval)
        }
    }
    func model(withDelta delta: CGFloat, oldModel: Model) -> Model {
        let v = oldModel.interval(scale: modelInterval) + model(withDelta: delta)
        return v.clip(min: minModel, max: maxModel)
    }
    func model(withRatio ratio: CGFloat) -> Model {
        return Int(round((maxModel - minModel).cf * pow(ratio, exp))) + minModel
    }
}
typealias DiscreteIntView = DiscreteOneDimensionalView<Int, IntOption>

/**
 Issue: 数を包括するNumberオブジェクトを設計
 */
typealias RealNumber = CGFloat
typealias R = CGFloat

extension RealNumber: Referenceable {
    static let name = Localization(english: "Real Number", japanese: "実数")
}
extension RealNumber: ObjectViewExpression {
    func thumbnail(withBounds bounds: CGRect, sizeType: SizeType) -> Layer {
        return String(self.d).view(withBounds: bounds, sizeType: sizeType)
    }
}

struct RealNumberOption: OneDimensionalOption {
    typealias Model = RealNumber
    
    var defaultModel: Model
    var minModel: Model
    var maxModel: Model
    var modelInterval: Model
    
    var exp = 1.0.cf
    var numberOfDigits: Int
    var unit: String
    
    func model(with string: String) -> Model? {
        return Double(string)?.cf
    }
    func string(with model: Model) -> String {
        return "\(model)"
    }
    func text(with model: Model) -> Localization {
        if numberOfDigits == 0 {
            let string = model - floor(model) > 0 ?
                String(format: "%g", model) + "\(unit)" :
                "\(Int(model))" + "\(unit)"
            return Localization(string)
        } else {
            let string = String(format: "%.\(numberOfDigits)f", model) + "\(unit)"
            return Localization(string)
        }
    }
    func ratio(with model: Model) -> CGFloat {
        return (model - minModel) / (maxModel - minModel)
    }
    func ratioFromDefaultModel(with model: Model) -> CGFloat {
        if model < defaultModel {
            return ((model - minModel) / (defaultModel - minModel)) * 0.5
        } else {
            return ((model - defaultModel) / (maxModel - defaultModel)) * 0.5 + 0.5
        }
    }
    
    private func model(withDelta delta: CGFloat) -> Model {
        let d = delta * modelInterval
        if exp == 1 {
            return d.interval(scale: modelInterval)
        } else {
            return (d >= 0 ? pow(d, exp) : -pow(abs(d), exp)).interval(scale: modelInterval)
        }
    }
    func model(withDelta delta: CGFloat, oldModel: Model) -> Model {
        let v = oldModel.interval(scale: modelInterval) + model(withDelta: delta)
        return v.clip(min: minModel, max: maxModel)
    }
    func model(withRatio ratio: CGFloat) -> Model {
        return (maxModel - minModel) * pow(ratio, exp) + minModel
    }
}
typealias DiscreteRealNumberView = DiscreteOneDimensionalView<RealNumber, RealNumberOption>

final class RealNumberView: View {
    var number: RealNumber {
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
    
    var sizeType: SizeType
    var formPropertyNameView: TextView?
    let formStringView: TextView
    
    init(number: RealNumber = 0,
         numberOfDigits: Int = 0, unit: String = "", font: Font = .default,
         frame: CGRect = CGRect(), sizeType: SizeType = .regular) {
        
        self.number = number
        self.numberOfDigits = numberOfDigits
        self.unit = unit
        self.sizeType = sizeType
        formStringView = TextView(font: font, frameAlignment: .right, alignment: .right, isForm: true)
        
        super.init()
        noIndicatedLineColor = .getBorder
        indicatedLineColor = .indicated
        isClipped = true
        replace(children: [formStringView])
        self.frame = frame
    }
    
    override var defaultBounds: CGRect {
        return formStringView.defaultBounds
    }
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    private func updateLayout() {
        formStringView.frame.origin = CGPoint(x: bounds.width - formStringView.frame.width,
                                          y: bounds.height - formStringView.frame.height)
        updateWithNumber()
    }
    private func updateWithNumber() {
        if numberOfDigits == 0 {
            let string = number - floor(number) > 0 ?
                String(format: "%g", number) + "\(unit)" :
                "\(Int(number))" + "\(unit)"
            formStringView.text = Localization(string)
        } else if numberOfDigits < 0 {
            let string = String(format: "%0\(-numberOfDigits)d", Int(number)) + "\(unit)"
            formStringView.text = Localization(string)
        } else {
            let string = String(format: "%.\(numberOfDigits)f", number) + "\(unit)"
            formStringView.text = Localization(string)
        }
    }
    
    func copiedObjects(with event: KeyInputEvent) -> [ViewExpression]? {
        return [number]
    }
    
    func reference(with event: TapEvent) -> Reference? {
        return number.reference
    }
}

protocol Slidable {
    var number: RealNumber { get set }
    var defaultNumber: RealNumber { get }
    var minNumber: RealNumber { get }
    var maxNumber: RealNumber { get }
    var exp: RealNumber { get }
}

final class SlidableNumberView: View, Slidable {
    var number: RealNumber {
        didSet {
            updateWithNumber()
        }
    }
    var defaultNumber: RealNumber
    
    var minNumber: RealNumber {
        didSet {
            updateWithNumber()
        }
    }
    var maxNumber: RealNumber {
        didSet {
            updateWithNumber()
        }
    }
    var exp: RealNumber {
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
    
    var sizeType: SizeType
    let knob: Knob
    var backgroundLayers = [Layer]() {
        didSet {
            replace(children: backgroundLayers + [knob])
        }
    }
    
    init(frame: CGRect = CGRect(),
         number: RealNumber = 0, defaultNumber: RealNumber = 0,
         min: RealNumber = 0, max: RealNumber = 1, exp: RealNumber = 1,
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
        self.sizeType = sizeType
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
    
    private func intervalNumber(withNumber n: RealNumber) -> RealNumber {
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
    func number(at point: CGPoint) -> RealNumber {
        let n: RealNumber
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
        let view: SlidableNumberView, number: RealNumber, oldNumber: RealNumber, type: Action.SendType
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
            if let number = (object as? RealNumber)?.clip(min: minNumber, max: maxNumber) {
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
    
    private func set(_ number: RealNumber, old oldNumber: RealNumber) {
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

///**
// Issue: スクロールによる値の変更
// */
//final class DiscreteRealNumberView: View, Slidable {
//    var number: RealNumber {
//        didSet {
//            updateWithNumber()
//        }
//    }
//
//    var unit: String {
//        didSet {
//            updateWithNumber()
//        }
//    }
//    var numberOfDigits: Int {
//        didSet {
//            updateWithNumber()
//        }
//    }
//
//    var defaultNumber: RealNumber
//    var minNumber: RealNumber {
//        didSet {
//            updateWithNumber()
//        }
//    }
//    var maxNumber: RealNumber {
//        didSet {
//            updateWithNumber()
//        }
//    }
//    var exp: RealNumber
//
//    var numberInterval: CGFloat, isInverted: Bool, isVertical: Bool
//
//    var sizeType: SizeType
//    private var knobLineFrame = CGRect()
//    private let labelPaddingX: CGFloat, knobPadding: CGFloat
//    private var numberX = 1.5.cf
//
//    private let knob = DiscreteKnob(CGSize(width: 6, height: 4), lineWidth: 1)
//    private let lineLayer: Layer = {
//        let lineLayer = Layer()
//        lineLayer.lineColor = .content
//        return lineLayer
//    } ()
//
//    let stringView: TextView
//
//    init(number: RealNumber = 0, defaultNumber: RealNumber = 0,
//         min: RealNumber = 0, max: RealNumber = 1, exp: RealNumber = 1,
//         numberInterval: RealNumber = 1, isInverted: Bool = false, isVertical: Bool = false,
//         numberOfDigits: Int = 0, unit: String = "",
//         frame: CGRect = CGRect(),
//         sizeType: SizeType = .regular) {
//
//        self.number = number.clip(min: min, max: max)
//        self.defaultNumber = defaultNumber
//        self.minNumber = min
//        self.maxNumber = max
//        self.exp = exp
//        self.numberInterval = numberInterval
//        self.isInverted = isInverted
//        self.isVertical = isVertical
//        self.numberOfDigits = numberOfDigits
//        self.unit = unit
//        self.knobPadding = sizeType == .small ? 2.0.cf : 3.0.cf
//        labelPaddingX = Layout.padding(with: sizeType)
//        stringView = TextView(font: Font.default(with: sizeType),
//                              frameAlignment: .right, alignment: .right)
//        self.sizeType = sizeType
//
//        super.init()
//        updateWithNumber()
//        isClipped = true
//        replace(children: [stringView, lineLayer, knob])
//        self.frame = frame
//    }
//
//    override var bounds: CGRect {
//        didSet {
//            updateLayout()
//        }
//    }
//    private func updateLayout() {
//        let paddingX = sizeType == .small ? 3.0.cf : 5.0.cf
//        knobLineFrame = CGRect(x: paddingX, y: sizeType == .small ? 1 : 2,
//                               width: bounds.width - paddingX * 2, height: 1)
//        // triangle
//        lineLayer.frame = knobLineFrame
//        stringView.frame.origin = CGPoint(x: bounds.width - stringView.frame.width - labelPaddingX,
//                                          y: round((bounds.height - stringView.frame.height) / 2))
//
//    }
//    private func updateWithNumber() {
//        if numberOfDigits == 0 {
//            let string = number - floor(number) > 0 ?
//                String(format: "%g", number) + "\(unit)" :
//                "\(Int(number))" + "\(unit)"
//            stringView.text = Localization(string)
//        } else {
//            let string = String(format: "%.\(numberOfDigits)f", number) + "\(unit)"
//            stringView.text = Localization(string)
//        }
//        if number < defaultNumber {
//            let x = (knobLineFrame.width / 2) * (number - minNumber) / (defaultNumber - minNumber)
//                + knobLineFrame.minX
//            knob.position = CGPoint(x: round(x), y: knobPadding)
//        } else {
//            let x = (knobLineFrame.width / 2) * (number - defaultNumber) / (maxNumber - defaultNumber)
//                + knobLineFrame.midX
//            knob.position = CGPoint(x: round(x), y: knobPadding)
//        }
//    }
//
//    private func number(withDelta delta: CGFloat) -> RealNumber {
//        let d = (delta / numberX) * numberInterval
//        if exp == 1 {
//            return d.interval(scale: numberInterval)
//        } else {
//            return (d >= 0 ? pow(d, exp) : -pow(abs(d), exp)).interval(scale: numberInterval)
//        }
//    }
//    private func number(at p: CGPoint, old oldNumber: RealNumber) -> RealNumber {
//        let d = isVertical ? p.y - oldPoint.y : p.x - oldPoint.x
//        let v = oldNumber.interval(scale: numberInterval) + number(withDelta: isInverted ? -d : d)
//        return v.clip(min: minNumber, max: maxNumber)
//    }
//
//    var disabledRegisterUndo = false
//
//    struct Binding {
//        let view: DiscreteRealNumberView, number: RealNumber, oldNumber: RealNumber, type: Action.SendType
//    }
//    var binding: ((Binding) -> ())?
//
//    func delete(with event: KeyInputEvent) -> Bool {
//        let number = defaultNumber.clip(min: minNumber, max: maxNumber)
//        if number != self.number {
//            set(number, old: self.number)
//        }
//        return true
//    }
//    func copiedObjects(with event: KeyInputEvent) -> [ViewExpression]? {
//        return [number, String(number.d)]
//    }
//    func paste(_ objects: [Any], with event: KeyInputEvent) -> Bool {
//        for object in objects {
//            if let number = (object as? RealNumber)?.clip(min: minNumber, max: maxNumber) {
//                if number != self.number {
//                    set(number, old: self.number)
//                    return true
//                }
//            } else if let string = object as? String {
//                if let number = Double(string)?.cf.clip(min: minNumber, max: maxNumber) {
//                    if number != self.number {
//                        set(number, old: self.number)
//                        return true
//                    }
//                }
//            }
//        }
//        return false
//    }
//
//    func run(with event: ClickEvent) -> Bool {
//        let p = point(from: event)
//        let number = self.number(at: p, old: self.number)
//        if number != self.number {
//            set(number, old: self.number)
//        }
//        return true
//    }
//
//    private var oldNumber = 0.0.cf, oldPoint = CGPoint()
//    func move(with event: DragEvent) -> Bool {
//        let p = point(from: event)
//        switch event.sendType {
//        case .begin:
//            knob.fillColor = .editing
//            oldNumber = number
//            oldPoint = p
//            binding?(Binding(view: self, number: number, oldNumber: oldNumber, type: .begin))
//            number = self.number(at: p, old: oldNumber)
//            binding?(Binding(view: self, number: number, oldNumber: oldNumber, type: .sending))
//        case .sending:
//            number = self.number(at: p, old: oldNumber)
//            binding?(Binding(view: self, number: number, oldNumber: oldNumber, type: .sending))
//        case .end:
//            number = self.number(at: p, old: oldNumber)
//            if number != oldNumber {
//                registeringUndoManager?.registerUndo(withTarget: self) { [number, oldNumber] in
//                    $0.set(oldNumber, old: number)
//                }
//            }
//            binding?(Binding(view: self, number: number, oldNumber: oldNumber, type: .end))
//            knob.fillColor = .knob
//        }
//        return true
//    }
//
//    private func set(_ number: RealNumber, old oldNumber: RealNumber) {
//        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldNumber, old: number) }
//        binding?(Binding(view: self, number: oldNumber, oldNumber: oldNumber, type: .begin))
//        self.number = number
//        binding?(Binding(view: self, number: number, oldNumber: oldNumber, type: .end))
//    }
//
//    func reference(with event: TapEvent) -> Reference? {
//        var reference = number.reference
//        reference.viewDescription = Localization(english: "Discrete Slider", japanese: "離散スライダー")
//        return reference
//    }
//}

final class CircularNumberView: PathView, Slidable {
    var number: RealNumber {
        didSet {
            updateWithNumber()
        }
    }
    var defaultNumber: RealNumber
    
    var minNumber: RealNumber {
        didSet {
            updateWithNumber()
        }
    }
    var maxNumber: RealNumber {
        didSet {
            updateWithNumber()
        }
    }
    var exp: RealNumber {
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
         number: RealNumber = 0, defaultNumber: RealNumber = 0,
         min: RealNumber = -.pi, max: RealNumber = .pi, exp: RealNumber = 1,
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
    
    private func intervalNumber(withNumber n: RealNumber) -> RealNumber {
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
    func number(at p: CGPoint) -> RealNumber {
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
        let view: CircularNumberView, number: RealNumber, oldNumber: RealNumber, type: Action.SendType
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
            if let number = (object as? RealNumber)?.clip(min: minNumber, max: maxNumber) {
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
    
    private func set(_ number: RealNumber, old oldNumber: RealNumber) {
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
    let nameView: TextView
    
    init(frame: CGRect = CGRect(), backgroundColor: Color = .background,
         name: String = "", type: String = "", state: Localization? = nil) {
        
        self.name = name
        self.type = type
        self.state = state
        nameView = TextView()
        nameView.frame.origin = CGPoint(x: Layout.basicPadding,
                                        y: round((frame.height - nameView.frame.height) / 2))
        barLayer.frame = CGRect(x: 0, y: 0, width: 0, height: frame.height)
        barBackgroundLayer.fillColor = .editing
        barLayer.fillColor = .content
        
        super.init()
        self.frame = frame
        isClipped = true
        replace(children: [nameView, barBackgroundLayer, barLayer])
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
        nameView.string = type + "(" + name + "), "
            + string + (string.isEmpty ? "" : ", ") + "\(Int(value * 100)) %"
        nameView.frame.origin = CGPoint(x: Layout.basicPadding,
                                         y: round((frame.height - nameView.frame.height) / 2))
    }
    
    var deleteClosure: ((ProgressNumberView) -> (Bool))?
    weak var operation: Operation?
    func delete(with event: KeyInputEvent) -> Bool {
        if let operation = operation {
            operation.cancel()
        }
        return deleteClosure?(self) ?? false
    }
    
    func reference(with event: TapEvent) -> Reference? {
        return Reference(name: Localization(english: "Progress", japanese: "進捗"),
                         viewDescription: Localization(english: "Stop: Send \"Cut\" action",
                                                       japanese: "停止: \"カット\"アクションを送信"))
    }
}
