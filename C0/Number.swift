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
extension Int: ObjectViewExpression {
    func thumbnail(withBounds bounds: Rect, _ sizeType: SizeType) -> View {
        return String(self).view(withBounds: bounds, sizeType)
    }
}

struct IntGetterOption: NumberGetterOption {
    typealias Model = Int
    
    var unit: String
    
    func string(with model: Model) -> String {
        return "\(model)"
    }
    func text(with model: Model) -> Text {
        return Text("\(model)\(unit)")
    }
}
typealias IntView = NumberGetterView<Int, IntGetterOption>

struct IntOption: OneDimensionalOption {
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
            return Int(d >= 0 ? pow(d, exp) : -pow(abs(d), exp)).interval(scale: modelInterval)
        }
    }
    func model(withDelta delta: Real, oldModel: Model) -> Model {
        let v = oldModel.interval(scale: modelInterval) + model(withDelta: delta)
        return v.clip(min: minModel, max: maxModel)
    }
    func model(withRatio ratio: Real) -> Model {
        return Int(round(Real(maxModel - minModel) * pow(ratio, exp))) + minModel
    }
}
typealias DiscreteIntView = DiscreteOneDimensionalView<Int, IntOption>

/**
 Issue: 数を包括するNumberオブジェクトを設計
 */
typealias Real = CGFloat
extension Real: Referenceable {
    static let name = Text(english: "Real Number (\(MemoryLayout<Real>.size * 8)bit)",
                                   japanese: "実数 (\(MemoryLayout<Real>.size * 8)bit)")
}
extension Real: ObjectViewExpression {
    func thumbnail(withBounds bounds: Rect, _ sizeType: SizeType) -> View {
        return String(self).view(withBounds: bounds, sizeType)
    }
}

extension String {
    init(_ value: Real) {
        self = String(Double(value))
    }
}
extension Real {
    init?(_ string: String) {
        if let value = Double(string)?.cg {
            self = value
        } else {
            return nil
        }
    }
}

struct RealGetterOption: NumberGetterOption {
    typealias Model = Real
    
    var numberOfDigits: Int
    var unit: String
    
    func string(with model: Model) -> String {
        return "\(model)"
    }
    func text(with model: Model) -> Text {
        if numberOfDigits == 0 {
            let string = model - floor(model) > 0 ?
                String(format: "%g", model) + "\(unit)" :
                "\(Int(model))" + "\(unit)"
            return Text(string)
        } else {
            let string = String(format: "%.\(numberOfDigits)f", model) + "\(unit)"
            return Text(string)
        }
    }
}
typealias RealView = NumberGetterView<Real, RealGetterOption>

struct RealOption: OneDimensionalOption {
    typealias Model = Real
    
    var defaultModel: Model
    var minModel: Model
    var maxModel: Model
    var modelInterval: Model
    
    var exp = 1.0.cg
    var numberOfDigits: Int
    var unit: String
    
    func model(with string: String) -> Model? {
        return Real(string)
    }
    func string(with model: Model) -> String {
        return "\(model)"
    }
    func text(with model: Model) -> Text {
        if numberOfDigits == 0 {
            let string = model - floor(model) > 0 ?
                String(format: "%g", model) + "\(unit)" :
                "\(Int(model))" + "\(unit)"
            return Text(string)
        } else {
            let string = String(format: "%.\(numberOfDigits)f", model) + "\(unit)"
            return Text(string)
        }
    }
    func ratio(with model: Model) -> Real {
        return (model - minModel) / (maxModel - minModel)
    }
    func ratioFromDefaultModel(with model: Model) -> Real {
        if model < defaultModel {
            return ((model - minModel) / (defaultModel - minModel)) * 0.5
        } else {
            return ((model - defaultModel) / (maxModel - defaultModel)) * 0.5 + 0.5
        }
    }
    
    private func model(withDelta delta: Real) -> Model {
        let d = delta * modelInterval
        if exp == 1 {
            return d.interval(scale: modelInterval)
        } else {
            return (d >= 0 ? pow(d, exp) : -pow(abs(d), exp)).interval(scale: modelInterval)
        }
    }
    func model(withDelta delta: Real, oldModel: Model) -> Model {
        let v = oldModel.interval(scale: modelInterval) + model(withDelta: delta)
        return v.clip(min: minModel, max: maxModel)
    }
    func model(withRatio ratio: Real) -> Model {
        return (maxModel - minModel) * pow(ratio, exp) + minModel
    }
}
typealias DiscreteRealView = DiscreteOneDimensionalView<Real, RealOption>

protocol Slidable {
    var number: Real { get set }
    var defaultNumber: Real { get }
    var minNumber: Real { get }
    var maxNumber: Real { get }
    var exp: Real { get }
}

final class SlidableNumberView: View, Queryable, Assignable, Runnable, Movable, Slidable {
    var number: Real {
        didSet {
            updateWithNumber()
        }
    }
    var defaultNumber: Real
    
    var minNumber: Real {
        didSet {
            updateWithNumber()
        }
    }
    var maxNumber: Real {
        didSet {
            updateWithNumber()
        }
    }
    var exp: Real {
        didSet {
            updateWithNumber()
        }
    }
    
    var numberInterval: Real
    
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
    var padding: Real {
        didSet {
            updateWithNumber()
        }
    }
    
    var sizeType: SizeType
    let knobView: KnobView
    var backgroundViews = [View]() {
        didSet {
            children = backgroundViews + [knobView]
        }
    }
    
    init(frame: Rect = Rect(),
         number: Real = 0, defaultNumber: Real = 0,
         min: Real = 0, max: Real = 1, exp: Real = 1,
         numberInterval: Real = 0, isInverted: Bool = false, isVertical: Bool = false,
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
        padding = sizeType == .small ? 6 : 8
        knobView = sizeType == .small ? KnobView(radius: 4) : KnobView()
        
        super.init()
        append(child: knobView)
        self.frame = frame
    }
    
    override var bounds: Rect {
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
            knobView.position = Point(x: bounds.midX, y: y)
        } else {
            let x = padding + (bounds.width - padding * 2)
                * pow(isInverted ? 1 - t : t, 1 / exp)
            knobView.position = Point(x: x, y: bounds.midY)
        }
    }
    
    private func intervalNumber(withNumber n: Real) -> Real {
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
    func number(at point: Point) -> Real {
        let n: Real
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
        let view: SlidableNumberView, number: Real, oldNumber: Real, phase: Phase
    }
    var binding: ((Binding) -> ())?
    
    func delete(for p: Point) {
        let number = defaultNumber.clip(min: minNumber, max: maxNumber)
        if number != self.number {
            set(number, old: self.number)
        }
    }
    func copiedViewables(at p: Point) -> [Viewable] {
        return [number]
    }
    func paste(_ objects: [Any], for p: Point) {
        for object in objects {
            if let number = (object as? Real)?.clip(min: minNumber, max: maxNumber) {
                if number != self.number {
                    set(number, old: self.number)
                    return
                }
            } else if let string = object as? String {
                if let number = Real(string)?.clip(min: minNumber, max: maxNumber) {
                    if number != self.number {
                        set(number, old: self.number)
                        return
                    }
                }
            }
        }
    }
    
    func run(for p: Point) {
        let number = self.number(at: p)
        if number != self.number {
            set(number, old: self.number)
        }
    }
    
    private var oldNumber = 0.0.cg, oldPoint = Point()
    func move(for p: Point, pressure: Real, time: Second, _ phase: Phase) {
        switch phase {
        case .began:
            knobView.fillColor = .editing
            oldNumber = number
            oldPoint = p
            binding?(Binding(view: self, number: number, oldNumber: oldNumber, phase: .began))
            number = self.number(at: p)
            binding?(Binding(view: self, number: number, oldNumber: oldNumber, phase: .changed))
        case .changed:
            number = self.number(at: p)
            binding?(Binding(view: self, number: number, oldNumber: oldNumber, phase: .changed))
        case .ended:
            number = self.number(at: p)
            if number != oldNumber {
                registeringUndoManager?.registerUndo(withTarget: self) { [number, oldNumber] in
                    $0.set(oldNumber, old: number)
                }
            }
            binding?(Binding(view: self, number: number, oldNumber: oldNumber, phase: .ended))
            knobView.fillColor = .knob
        }
    }
    
    private func set(_ number: Real, old oldNumber: Real) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldNumber, old: number) }
        binding?(Binding(view: self, number: oldNumber, oldNumber: oldNumber, phase: .began))
        self.number = number
        binding?(Binding(view: self, number: number, oldNumber: oldNumber, phase: .ended))
    }
    
    func reference(at p: Point) -> Reference {
        var reference = Real.reference
        reference.viewDescription = Text(english: "Slider", japanese: "スライダー")
        return reference
    }
}

final class CircularNumberView: View, Queryable, Assignable, Runnable, Movable, Slidable {
    var number: Real {
        didSet {
            updateWithNumber()
        }
    }
    var defaultNumber: Real
    
    var minNumber: Real {
        didSet {
            updateWithNumber()
        }
    }
    var maxNumber: Real {
        didSet {
            updateWithNumber()
        }
    }
    var exp: Real {
        didSet {
            updateWithNumber()
        }
    }
    
    var isClockwise: Bool, beginAngle: Real
    var numberInterval: Real
    var width: Real
    
    let knobView: KnobView
    var backgroundViews = [View]() {
        didSet {
            children = backgroundViews + [knobView]
        }
    }
    
    init(frame: Rect = Rect(),
         number: Real = 0, defaultNumber: Real = 0,
         min: Real = -.pi, max: Real = .pi, exp: Real = 1,
         isClockwise: Bool = false, beginAngle: Real = -.pi,
         numberInterval: Real = 0, width: Real = 16,
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
        knobView = sizeType == .small ? KnobView(radius: 4) : KnobView()
        
        super.init(path: CGMutablePath(), isForm: false)
        fillColor = nil
        lineWidth = 0.5
        append(child: knobView)
        self.frame = frame
    }
    
    override var bounds: Rect {
        didSet {
            updateLayout()
        }
    }
    private func updateLayout() {
        let cp = Point(x: bounds.midX, y: bounds.midY), r = bounds.width / 2
        let path = CGMutablePath()
        path.addArc(center: cp, radius: r, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        path.move(to: cp + Point(x: r - width, y: 0))
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
        let cp = Point(x: bounds.midX, y: bounds.midY), r = bounds.width / 2 - width / 2
        knobView.position = cp + r * Point(x: cos(theta), y: sin(theta))
    }
    
    private func intervalNumber(withNumber n: Real) -> Real {
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
    func number(at p: Point) -> Real {
        guard !bounds.isEmpty else {
            return intervalNumber(withNumber: number).clip(min: minNumber, max: maxNumber)
        }
        let cp = Point(x: bounds.midX, y: bounds.midY)
        let theta = cp.tangential(p)
        let t = (theta > beginAngle ? theta - beginAngle : theta - beginAngle + 2 * .pi) / (2 * .pi)
        let ct = isClockwise ? 1 - t : t
        let n = (maxNumber - minNumber) * pow(ct, exp) + minNumber
        return intervalNumber(withNumber: n).clip(min: minNumber, max: maxNumber)
    }
    
    var disabledRegisterUndo = false
    
    struct Binding {
        let view: CircularNumberView, number: Real, oldNumber: Real, phase: Phase
    }
    var binding: ((Binding) -> ())?
    
    func delete(for p: Point) {
        let number = defaultNumber.clip(min: minNumber, max: maxNumber)
        if number != self.number {
            set(number, old: self.number)
        }
    }
    func copiedViewables(at p: Point) -> [Viewable] {
        return [number]
    }
    func paste(_ objects: [Any], for p: Point) {
        for object in objects {
            if let number = (object as? Real)?.clip(min: minNumber, max: maxNumber) {
                if number != self.number {
                    set(number, old: self.number)
                    return
                }
            } else if let string = object as? String {
                if let number = Real(string)?.clip(min: minNumber, max: maxNumber) {
                    if number != self.number {
                        set(number, old: self.number)
                        return
                    }
                }
            }
        }
    }
    
    func run(for p: Point) {
        let number = self.number(at: p)
        if number != self.number {
            set(number, old: self.number)
        }
    }
    
    private var oldNumber = 0.0.cg, oldPoint = Point()
    func move(for p: Point, pressure: Real, time: Second, _ phase: Phase) {
        switch phase {
        case .began:
            knobView.fillColor = .editing
            oldNumber = number
            oldPoint = p
            binding?(Binding(view: self, number: number, oldNumber: oldNumber, phase: .began))
            number = self.number(at: p)
            binding?(Binding(view: self, number: number, oldNumber: oldNumber, phase: .changed))
        case .changed:
            number = self.number(at: p)
            binding?(Binding(view: self, number: number, oldNumber: oldNumber, phase: .changed))
        case .ended:
            number = self.number(at: p)
            if number != oldNumber {
                registeringUndoManager?.registerUndo(withTarget: self) { [number, oldNumber] in
                    $0.set(oldNumber, old: number)
                }
            }
            binding?(Binding(view: self, number: number, oldNumber: oldNumber, phase: .ended))
            knobView.fillColor = .knob
        }
    }
    
    private func set(_ number: Real, old oldNumber: Real) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldNumber, old: number) }
        binding?(Binding(view: self, number: oldNumber, oldNumber: oldNumber, phase: .began))
        self.number = number
        binding?(Binding(view: self, number: number, oldNumber: oldNumber, phase: .ended))
    }
    
    func reference(at p: Point) -> Reference {
        var reference = Real.reference
        reference.viewDescription = Text(english: "Circular Slider", japanese: "円状スライダー")
        return reference
    }
}

final class ProgressNumberView: View {
    let barView = View(isForm: true)
    let barBackgroundView = View(isForm: true)
    let nameView: TextView
    let stopView = ClosureView(closure: {}, name: Text(english: "Stop", japanese: "中止"))
    
    init(frame: Rect = Rect(), backgroundColor: Color = .background,
         name: String = "", type: String = "", state: Text? = nil) {
        
        self.name = name
        self.type = type
        self.state = state
        nameView = TextView()
        nameView.frame.origin = Point(x: Layout.basicPadding,
                                        y: round((frame.height - nameView.frame.height) / 2))
        barView.frame = Rect(x: 0, y: 0, width: 0, height: frame.height)
        barBackgroundView.fillColor = .editing
        barView.fillColor = .content
        
        super.init()
        stopView.closure = { [unowned self] in self.stop() }
        self.frame = frame
        isClipped = true
        children = [nameView, barBackgroundView, barView, stopView]
        updateLayout()
    }
    
    var value = 0.0.cg {
        didSet {
            updateLayout()
        }
    }
    func begin() {
        startDate = Date()
    }
    func end() {}
    var startDate: Date?
    var remainingTime: Real? {
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
    var state: Text? {
        didSet {
            updateString(with: locale)
        }
    }
    
    override var locale: Locale {
        didSet {
            updateLayout()
        }
    }
    
    override var bounds: Rect {
        didSet {
            updateLayout()
        }
    }
    func updateLayout() {
        let padding = Layout.basicPadding
        let db = stopView.defaultBounds
        let w = bounds.width - db.width - padding
        stopView.frame = Rect(x: w, y: padding,
                                width: db.width, height: bounds.height - padding * 2)
        
        barBackgroundView.frame = Rect(x: padding, y: padding - 1,
                                          width: (w - padding * 2), height: 1)
        barView.frame = Rect(x: padding, y: padding - 1,
                                width: floor((w - padding * 2) * value), height: 1)
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
                let translator = Text(english: "%@sec left",
                                              japanese: "あと%@秒").string(with: locale)
                string += (string.isEmpty ? "" : " ") + String(format: translator, String(seconds))
            } else {
                let translator = Text(english: "%@min %@sec left",
                                              japanese: "あと%@分%@秒").string(with: locale)
                string += (string.isEmpty ? "" : " ") + String(format: translator,
                                                               String(minutes), String(seconds))
            }
        }
        nameView.string = type + "(" + name + "), "
            + string + (string.isEmpty ? "" : ", ") + "\(Int(value * 100)) %"
        nameView.frame.origin = Point(x: Layout.basicPadding,
                                         y: round((frame.height - nameView.frame.height) / 2))
    }
    
    var deleteClosure: ((ProgressNumberView) -> ())?
    weak var operation: Operation?
    func stop() {
        if let operation = operation {
            operation.cancel()
        }
        deleteClosure?(self)
    }
    
    func reference(at p: Point) -> Reference {
        return Reference(name: Text(english: "Progress", japanese: "進捗"),
                         viewDescription: Text(english: "Stop: Send \"Cut\" action",
                                                       japanese: "停止: \"カット\"アクションを送信"))
    }
}
