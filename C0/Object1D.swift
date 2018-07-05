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

import CoreGraphics

typealias Object1D = Object.Value

protocol Object1DOption: GetterOption {
    var minModel: Model { get }
    var maxModel: Model { get }
    func ratio(with model: Model) -> Real
    func model(withDelta delta: Real, oldModel: Model) -> Model
    func model(withRatio ratio: Real) -> Model
    func clippedDelta(withDelta delta: Real, oldModel: Model) -> Real
    func clippedModel(_ model: Model) -> Model
    func realValue(with model: Model) -> Real
    func model(with realValue: Real) -> Model
}

final class Assignable1DView<T: Object1DOption, U: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = T.Model
    typealias ModelOption = T
    typealias Binder = U
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((Assignable1DView<ModelOption, Binder>, BasicNotification) -> ())]()
    
    var model: Model {
        get { return binder[keyPath: keyPath] }
        set {
            binder[keyPath: keyPath] = newValue
            notifications.forEach { $0(self, ._didChange) }
            updateWithModel()
        }
    }
    
    var option: ModelOption {
        didSet { updateWithModel() }
    }
    
    let optionTextView: TextFormView
    
    var name: Text
    let nameView: TextFormView
    
    init(binder: Binder, keyPath: BinderKeyPath, name: Text = Text(), option: ModelOption) {
        self.binder = binder
        self.keyPath = keyPath
        self.option = option
        
        optionTextView = TextFormView(text: option.displayText(with: binder[keyPath: keyPath]),
                                      alignment: .right,
                                      paddingSize: Size(width: 3, height: 1))
        
        self.name = name
        nameView = TextFormView(text: name.isEmpty ? "" : name + ":")
        
        super.init(isLocked: false)
        isClipped = true
        children = [optionTextView, nameView]
    }
    
    var minSize: Size {
        return optionTextView.minSize
    }
    override func updateLayout() {
        let padding = Layouter.basicPadding
        if !name.isEmpty {
            let minStringSize = nameView.minSize
            nameView.frame = Rect(origin: Point(x: padding, y: 0), size: minStringSize)
        }
        updateTextPosition()
    }
    private func updateTextPosition() {
        let optionTextSize = optionTextView.minSize
        let optiontextOrigin = Point(x: bounds.width - optionTextSize.width,
                                     y: bounds.height - optionTextSize.height)
        optionTextView.frame = Rect(origin: optiontextOrigin, size: optionTextSize)
    }
    func updateWithModel() {
        updateString()
    }
    private func updateString() {
        optionTextView.text = option.displayText(with: model)
        updateTextPosition()
    }
    
    func clippedModel(_ model: Model) -> Model {
        return option.clippedModel(model)
    }
}

protocol Discrete {}

final class Discrete1DView<T: Object1DOption, U: BinderProtocol>
: ModelView, Discrete, BindableReceiver {

    typealias Model = T.Model
    typealias ModelOption = T
    typealias Binder = U
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((Discrete1DView<ModelOption, Binder>,
                           BasicPhaseNotification<Model>) -> ())]()
    
    var model: Model {
        get { return binder[keyPath: keyPath] }
        set {
            binder[keyPath: keyPath] = newValue
            notifications.forEach { $0(self, Notification.didChange) }
            updateWithModel()
        }
    }
    
    var option: ModelOption {
        didSet { updateWithModel() }
    }
    
    var xyOrientation: Orientation.XY {
        didSet { updateLayout() }
    }
    var xInterval = 1.5.cg
    private var knobLineFrame = Rect()
    let labelPaddingX: Real, knobPadding = 3.0.cg
    let knobView = View.discreteKnob(Size(square: 5), lineWidth: 1)
    let knobLineView: View = {
        let view = View()
        view.fillColor = .content
        return view
    } ()
    let optionStringView: TextFormView
    
    var name: Text
    let nameView: TextFormView
    
    init(binder: Binder, keyPath: BinderKeyPath, name: Text = Text(), option: ModelOption,
         xyOrientation: Orientation.XY = .horizontal(.leftToRight)) {
        
        self.binder = binder
        self.keyPath = keyPath
        self.option = option
        
        self.xyOrientation = xyOrientation
        labelPaddingX = Layouter.basicPadding
        optionStringView = TextFormView(font: .default, alignment: .right)
        
        self.name = name
        nameView = TextFormView(text: name.isEmpty ? "" : name + ":")
        
        super.init(isLocked: false)
        isClipped = true
        knobView.fillColor = .scroll
        children = [optionStringView, knobLineView, knobView, nameView]
        updateWithModel()
    }
    
    var minSize: Size {
        return Size(width: max(Layouter.basicValueWidth, optionStringView.minSize.width),
                    height: Layouter.basicHeight)
    }
    override func updateLayout() {
        let padding = Layouter.basicPadding
        let paddingX = knobView.bounds.width / 2 + padding
        knobLineFrame = Rect(x: paddingX, y: 2,
                             width: bounds.width - paddingX * 2, height: 1)
        knobLineView.frame = knobLineFrame
        updateTextPosition()
        updateknobLayout()
        
        if !name.isEmpty {
            let minNameSize = nameView.minSize
            let y = ((bounds.height - minNameSize.height) / 2).rounded()
            nameView.frame = Rect(origin: Point(x: padding, y: y), size: minNameSize)
        }
    }
    private func updateTextPosition() {
        let optionStringMinSize = optionStringView.minSize
        let x = bounds.width - optionStringMinSize.width - labelPaddingX
        let y = ((bounds.height - optionStringMinSize.height) / 2).rounded()
        optionStringView.frame = Rect(origin: Point(x: x, y: y), size: optionStringMinSize)
    }
    private func updateknobLayout() {
        let t = option.ratio(with: model)
        switch xyOrientation {
        case .horizontal(let horizontal):
            let tt = horizontal == .leftToRight ? t : 1 - t
            let x = knobLineFrame.width * tt + knobLineFrame.minX
            knobView.position = Point(x: x.interval(scale: 0.5), y: knobPadding)
        case .vertical(let vertical):
            let tt = vertical == .bottomToTop ? t : 1 - t
            let y = knobLineFrame.height * tt + knobLineFrame.minY
            knobView.position = Point(x: knobPadding, y: y.rounded())
        }
    }
    func updateWithModel() {
        updateString()
        updateknobLayout()
    }
    private func updateString() {
        optionStringView.text = option.displayText(with: model)
        updateTextPosition()
    }
    
    func model(at p: Point, first fp: Point, old oldModel: Model) -> Model {
        let delta: Real
        switch xyOrientation {
        case .horizontal(let horizontal):
            delta = horizontal == .leftToRight ? p.x - fp.x : fp.x - p.x
        case .vertical(let vertical):
            delta = vertical == .bottomToTop ? p.y - fp.y : fp.y - p.y
        }
        return option.model(withDelta: delta / xInterval, oldModel: oldModel)
    }
    
    func clippedModel(_ model: Model) -> Model {
        return option.clippedModel(model)
    }
}
extension Discrete1DView: BasicXSlidable {
    var xKnobView: View {
        return knobView
    }
    func xClippedDelta(withDelta delta: Real, oldModel: T.Model) -> Real {
        return option.clippedDelta(withDelta: delta, oldModel: oldModel)
    }
    func xModel(delta: Real, old oldModel: T.Model) -> T.Model {
        return option.model(withDelta: delta, oldModel: oldModel)
    }
    func didChangeFromXSlide(_ phase: Phase, beganModel: Model) {
        notifications.forEach { $0(self, .didChangeFromPhase(phase, beginModel: beganModel)) }
    }
}

final class Movable1DView<T: Object1DOption, U: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = T.Model
    typealias ModelOption = T
    typealias Binder = U
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((Movable1DView<ModelOption, Binder>,
                           BasicPhaseNotification<Model>) -> ())]()
    
    var model: Model {
        get { return binder[keyPath: keyPath] }
        set {
            binder[keyPath: keyPath] = newValue
            notifications.forEach { $0(self, .didChange) }
            updateWithModel()
        }
    }
    var option: ModelOption {
        didSet { updateWithModel() }
    }
    
    var xyOrientation: Orientation.XY {
        didSet { updateLayout() }
    }
    var padding = 8.0.cg {
        didSet { updateLayout() }
    }
    let knobView: View
    var backgroundViews = [View]() {
        didSet {
            children = backgroundViews + [knobView]
        }
    }
    
    init(binder: Binder, keyPath: BinderKeyPath, option: ModelOption,
         xyOrientation: Orientation.XY = .horizontal(.leftToRight)) {
        
        self.binder = binder
        self.keyPath = keyPath
        self.option = option
        
        self.xyOrientation = xyOrientation
        knobView = View.knob()
        
        super.init(isLocked: false)
        append(child: knobView)
        updateWithModel()
    }
    
    var minSize: Size {
        switch xyOrientation {
        case .horizontal:
            return Size(width: Layouter.defaultMinWidth + padding, height: Layouter.basicHeight)
        case .vertical:
            return Size(width: Layouter.basicHeight, height: Layouter.defaultMinWidth + padding)
        }
    }
    override func updateLayout() {
        updateKnobLayout()
    }
    private func updateKnobLayout() {
        let t = option.ratio(with: model)
        switch xyOrientation {
        case .horizontal(let horizontal):
            let tt = horizontal == .leftToRight ? t : 1 - t
            let x = (bounds.width - padding * 2) * tt + padding
            knobView.position = Point(x: x, y: bounds.midY)
        case .vertical(let vertical):
            let tt = vertical == .bottomToTop ? t : 1 - t
            let y = (bounds.height - padding * 2) * tt + padding
            knobView.position = Point(x: bounds.midX, y: y)
        }
    }
    func updateWithModel() {
        updateKnobLayout()
    }
    func model(at point: Point) -> Model {
        guard !bounds.isEmpty else {
            return option.model(withRatio: 0)
        }
        let t: Real
        switch xyOrientation {
        case .horizontal(let horizontal):
            let w = bounds.width - padding * 2
            t = horizontal == .leftToRight ?
                (point.x - padding) / w : (w - padding - point.x) / w
        case .vertical(let vertical):
            let h = bounds.height - padding * 2
            t = vertical == .bottomToTop ?
                (point.y - padding) / h : (h - padding - point.y) / h
        }
        return option.model(withRatio: t)
    }
    
    func clippedModel(_ model: Model) -> Model {
        return option.clippedModel(model)
    }
}
extension Movable1DView: Runnable {
    func run(for p: Point, _ version: Version) {
        push(option.clippedModel(model(at: p)), to: version)
    }
}
extension Movable1DView: BasicPointMovable {
    func didChangeFromMovePoint(_ phase: Phase, beganModel: Model) {
        notifications.forEach { $0(self, .didChangeFromPhase(phase, beginModel: beganModel)) }
    }
}

final class Circular1DView<T: Object1DOption, U: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = T.Model
    typealias ModelOption = T
    typealias Binder = U
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((Circular1DView<ModelOption, Binder>,
                           BasicPhaseNotification<Model>) -> ())]()
    
    var model: Model {
        get { return binder[keyPath: keyPath] }
        set {
            binder[keyPath: keyPath] = newValue
            notifications.forEach { $0(self, .didChange) }
            updateWithModel()
        }
    }
    var option: ModelOption {
        didSet { updateWithModel() }
    }
    
    var circularOrientation: Orientation.Circular {
        didSet { updateLayout() }
    }
    var startAngle: Real {
        didSet { updateLayout() }
    }
    var width: Real {
        didSet { updateLayout() }
    }
    
    let knobView: View
    var backgroundViews = [View]() {
        didSet {
            children = backgroundViews + [knobView]
        }
    }
    
    init(binder: Binder, keyPath: BinderKeyPath, option: ModelOption,
         circularOrientation: Orientation.Circular = .counterClockwise,
         startAngle: Real = -.pi, width: Real = 16) {
        
        self.binder = binder
        self.keyPath = keyPath
        self.option = option
        
        self.circularOrientation = circularOrientation
        self.startAngle = startAngle
        self.width = width
        knobView = View.knob()
        
        super.init(path: Path(), isLocked: false, lineColor: .getSetBorder)
        fillColor = nil
        lineWidth = 0.5
        append(child: knobView)
    }
    
    func circularPath(withBounds bounds: Rect) -> Path {
        let cp = Point(x: bounds.midX, y: bounds.midY), r = bounds.width / 2
        let mr = r - width
        let fp0 = cp + Point(x: r, y: 0)
        let arc0 = PathLine.Arc(radius: r, startAngle: 0, endAngle: 2 * .pi)
        let fp1 = cp + Point(x: mr, y: 0)
        let arc1 = PathLine.Arc(radius: mr, startAngle: 2 * .pi, endAngle: 0)
        var path = Path()
        path.append(PathLine(firstPoint: fp0, elements: [.arc(arc0)]))
        path.append(PathLine(firstPoint: fp1, elements: [.arc(arc1)]))
        return path
    }
    func circularInternalPath(withBounds bounds: Rect) -> Path {
        let cp = Point(x: bounds.midX, y: bounds.midY), r = bounds.width / 2
        let mr = r - width
        let fp1 = cp + Point(x: mr, y: 0)
        let arc1 = PathLine.Arc(radius: mr, startAngle: 2 * .pi, endAngle: 0)
        var path = Path()
        path.append(PathLine(firstPoint: fp1, elements: [.arc(arc1)]))
        return path
    }
    
    var minSize: Size {
        return Size(square: width * 2)
    }
    override func updateLayout() {
        updateKnobLayout()
    }
    private func updateKnobLayout() {
        let pathBounds = path.boundingBoxOfPath
        let t = option.ratio(with: model)
        let theta = circularOrientation == .clockwise ?
            startAngle - t * (2 * .pi) : startAngle + t * (2 * .pi)
        let cp = Point(x: pathBounds.midX, y: pathBounds.midY)
        let r = pathBounds.width / 2 - width / 2
        knobView.position = cp + r * Point(x: cos(theta), y: sin(theta))
    }
    func updateWithModel() {
        updateKnobLayout()
    }
    func model(at p: Point) -> Model {
        let pathBounds = path.boundingBoxOfPath
        guard !pathBounds.isEmpty else {
            return self.model
        }
        let cp = Point(x: pathBounds.midX, y: pathBounds.midY)
        let theta = cp.tangential(p)
        let ct = (theta > startAngle ?
            theta - startAngle : theta - startAngle + 2 * .pi) / (2 * .pi)
        let t = circularOrientation == .clockwise ? 1 - ct : ct
        let model = option.model(withRatio: t)
        return option.clippedModel(model)
    }
    
    func clippedModel(_ model: Model) -> Model {
        return option.clippedModel(model)
    }
}
extension Circular1DView: Runnable {
    func run(for p: Point, _ version: Version) {
        push(model(at: p), to: version)
    }
}
extension Circular1DView: BasicPointMovable {
    func didChangeFromMovePoint(_ phase: Phase, beganModel: Model) {
        notifications.forEach { $0(self, .didChangeFromPhase(phase, beginModel: beganModel)) }
    }
}

protocol IntervalObject1DOption {
    associatedtype Model: Object1D
    var zeroModel: Model { get }
    var intervalModel: Model { get }
    func model(with model: Model, applyingIntervalRatio: Real) -> Model
    func differenceIntervalRatio(with model: Model, other otherModel: Model) -> Real
    func int(with model: Model, rounded: FloatingPointRoundingRule) -> Int
    func model(with int: Int) -> Model
}

final class SlidableInterval1DView<T: Object1DOption, U: IntervalObject1DOption, V: BinderProtocol>
: ModelView, BindableReceiver where U.Model == T.Model {

    typealias Model = T.Model
    typealias ModelOption = T
    typealias IntervalModelOption = U
    typealias Binder = V
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((SlidableInterval1DView<ModelOption, IntervalModelOption, Binder>,
                           BasicPhaseNotification<Model>) -> ())]()
    
    var model: Model {
        get { return binder[keyPath: keyPath] }
        set {
            binder[keyPath: keyPath] = newValue
            notifications.forEach { $0(self, .didChange) }
            updateWithModel()
        }
    }
    var option: ModelOption {
        didSet { updateWithModel() }
    }
    var intervalOption: IntervalModelOption
    
    var xInterval = 1.5.cg
    var lineIntervalWidth = 120.0.cg
    var intervalLineWidth = 1.0.cg
    var centerLineWidth = 6.0.cg
    
    let linesView: View
    let knobView: View
    let knobLineView: View = {
        let view = View()
        view.fillColor = .content
        return view
    } ()
    let knobPadding = 3.0.cg
    let rootView: View
    let centerView: View
    
    init(binder: Binder, keyPath: BinderKeyPath, option: ModelOption,
         intervalOption: IntervalModelOption) {
        
        self.binder = binder
        self.keyPath = keyPath
        self.option = option
        self.intervalOption = intervalOption
        
        linesView = View(path: Path())
        linesView.fillColor = .content
        
        rootView = View(isLocked: false)
        rootView.lineWidth = 0
        
        centerView = View()
        centerView.lineWidth = 0
        centerView.fillColor = .editing
        
        knobView = View.discreteKnob(Size(square: centerLineWidth), lineWidth: 1)
        knobView.fillColor = .scroll
        
        super.init(isLocked: false)
        isClipped = true
        children = [centerView, linesView, rootView, knobLineView, knobView]
        updateWithModel()
    }
    
    func model(withX x: Real) -> Model {
        return intervalOption.model(with: model,
                                    applyingIntervalRatio: (x - bounds.midX) / lineIntervalWidth)
    }
    func x(with model: Model) -> Real {
        return intervalOption.differenceIntervalRatio(with: model, other: self.model)
            * lineIntervalWidth + bounds.midX
    }
    
    var minSize: Size {
        return Size(width: 10, height: 10)
    }
    override func updateLayout() {
        centerView.frame = Rect(x: bounds.midX - centerLineWidth / 2, y: 0,
                                width: centerLineWidth, height: bounds.height)
        rootView.position.y = Layouter.basicPadding * 2
        
        knobView.position = Point(x: bounds.midX, y: knobPadding)
        
        updateRootPosition()
        updateLines()
        updateknobLayout()
    }
    func updateWithModel() {
        updateRootPosition()
        updateLines()
        updateknobLayout()
    }
    private func updateknobLayout() {
        let paddingX = knobView.bounds.width / 2 + Layouter.basicPadding
        let size = Size(width: bounds.width / 2 - paddingX, height: 1)
        let t = option.ratio(with: model)
        let x = -size.width * t + bounds.midX
        knobLineView.frame = Rect(origin: Point(x: x, y: 2), size: size)
    }
    func updateRootPosition() {
        rootView.transform.translation.x
            = intervalOption.differenceIntervalRatio(with: intervalOption.zeroModel, other: model)
            * lineIntervalWidth + bounds.midX
    }
    func updateLines() {
        let minModel = model(withX: bounds.minX)
        let maxModel = model(withX: bounds.maxX)
        let minInt = intervalOption.int(with: minModel, rounded: .down)
        let maxInt = intervalOption.int(with: maxModel, rounded: .up)
        guard minInt < maxInt else {
            linesView.path = Path()
            return
        }
        let rects: [Rect] = (minInt...maxInt).map {
            let i0x = x(with: intervalOption.model(with: $0))
            let w = intervalLineWidth
            return Rect(x: i0x - w / 2, y: 0, width: w, height: bounds.height)
        }
        var path = Path()
        path.append(rects)
        linesView.path = path
    }
}
extension SlidableInterval1DView: BasicXSlidable {
    var horizontalOrientation: Orientation.Horizontal {
        return .rightToLeft
    }
    var xKnobView: View {
        return knobView
    }
    func xClippedDelta(withDelta delta: Real, oldModel: T.Model) -> Real {
        return option.clippedDelta(withDelta: delta, oldModel: oldModel)
    }
    func xModel(delta: Real, old oldModel: T.Model) -> T.Model {
        return option.model(withDelta: delta, oldModel: oldModel)
    }
    func didChangeFromXSlide(_ phase: Phase, beganModel: Model) {
        notifications.forEach { $0(self, .didChangeFromPhase(phase, beginModel: beganModel)) }
        updateLines()
    }
}
