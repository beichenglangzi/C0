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
    var defaultModel: Model { get }
    var minModel: Model { get }
    var maxModel: Model { get }
    var transformedModel: ((Model) -> (Model)) { get }
    func ratio(with model: Model) -> Real
    func ratioFromDefaultModel(with model: Model) -> Real
    func model(withDelta delta: Real, oldModel: Model) -> Model
    func model(withRatio ratio: Real) -> Model
    func clippedModel(_ model: Model) -> Model
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
            binder[keyPath: keyPath] = option.transformedModel(newValue)
            notifications.forEach { $0(self, ._didChange) }
            updateWithModel()
        }
    }
    
    var option: ModelOption {
        didSet { updateWithModel() }
    }
    var defaultModel: Model {
        return option.defaultModel
    }
    
    let optionTextView: TextFormView
    
    init(binder: Binder, keyPath: BinderKeyPath, option: ModelOption) {
        self.binder = binder
        self.keyPath = keyPath
        self.option = option
        
        optionTextView = TextFormView(text: option.displayText(with: binder[keyPath: keyPath]),
                                      alignment: .right,
                                      paddingSize: Size(width: 3, height: 1))
        
        super.init(isLocked: false)
        isClipped = true
        children = [optionTextView]
    }
    
    var minSize: Size {
        return optionTextView.minSize
    }
    override func updateLayout() {
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

/**
 Issue: スクロールによる値の変更
 */
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
    var defaultModel: Model {
        return option.defaultModel
    }
    
    var xyOrientation: Orientation.XY {
        didSet { updateLayout() }
    }
    var interval = 1.5.cg
    private var knobLineFrame = Rect()
    let labelPaddingX: Real, knobPadding = 3.0.cg
    let knobView = View.discreteKnob(Size(width: 6, height: 5), lineWidth: 1)
    let linePathView: View = {
        let linePathView = View()
        linePathView.lineColor = .content
        return linePathView
    } ()
    let optionStringView: TextFormView
    
    init(binder: Binder, keyPath: BinderKeyPath, option: ModelOption,
         xyOrientation: Orientation.XY = .horizontal(.leftToRight)) {
        
        self.binder = binder
        self.keyPath = keyPath
        self.option = option
        
        self.xyOrientation = xyOrientation
        labelPaddingX = Layouter.basicPadding
        optionStringView = TextFormView(font: .default, alignment: .right)
        
        super.init(isLocked: false)
        isClipped = true
        children = [optionStringView, linePathView, knobView]
        updateWithModel()
    }
    
    var minSize: Size {
        return Size(width: max(80, optionStringView.minSize.width),
                    height: Layouter.basicHeight)
    }
    override func updateLayout() {
        let paddingX = 5.0.cg
        knobLineFrame = Rect(x: paddingX, y: 2,
                             width: bounds.width - paddingX * 2, height: 1)
        linePathView.frame = knobLineFrame
        updateTextPosition()
        updateknobLayout()
    }
    private func updateTextPosition() {
        let optionStringMinSize = optionStringView.minSize
        let x = bounds.width - optionStringMinSize.width - labelPaddingX
        let y = ((bounds.height - optionStringMinSize.height) / 2).rounded()
        optionStringView.frame = Rect(origin: Point(x: x, y: y), size: optionStringMinSize)
    }
    private func updateknobLayout() {
        let t = option.ratioFromDefaultModel(with: model)
        switch xyOrientation {
        case .horizontal(let horizontal):
            let tt = horizontal == .leftToRight ? t : 1 - t
            let x = knobLineFrame.width * tt + knobLineFrame.minX
            knobView.position = Point(x: x.rounded(), y: knobPadding)
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
        return option.model(withDelta: delta / interval, oldModel: oldModel)
    }
    
    func clippedModel(_ model: Model) -> Model {
        return option.clippedModel(model)
    }
}
extension Discrete1DView: BasicDiscretePointMovable {
    func didChangeFromMovePoint(_ phase: Phase, beganModel: Model) {
        notifications.forEach { $0(self, .didChangeFromPhase(phase, beginModel: beganModel)) }
    }
}

protocol Slidable {}

final class Slidable1DView<T: Object1DOption, U: BinderProtocol>
: ModelView, Slidable, BindableReceiver {

    typealias Model = T.Model
    typealias ModelOption = T
    typealias Binder = U
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((Slidable1DView<ModelOption, Binder>,
                           BasicPhaseNotification<Model>) -> ())]()
    
    var model: Model {
        get { return binder[keyPath: keyPath] }
        set {
            binder[keyPath: keyPath] = option.transformedModel(newValue)
            notifications.forEach { $0(self, .didChange) }
            updateWithModel()
        }
    }
    
    var option: ModelOption {
        didSet { updateWithModel() }
    }
    var defaultModel: Model {
        return option.defaultModel
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
extension Slidable1DView: Runnable {
    func run(for p: Point, _ version: Version) {
        push(option.clippedModel(model(at: p)), to: version)
    }
}
extension Slidable1DView: BasicSlidablePointMovable {
    func didChangeFromMovePoint(_ phase: Phase, beganModel: Model) {
        notifications.forEach { $0(self, .didChangeFromPhase(phase, beginModel: beganModel)) }
    }
}

final class Circular1DView<T: Object1DOption, U: BinderProtocol>
: ModelView, Slidable, BindableReceiver {

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
            binder[keyPath: keyPath] = option.transformedModel(newValue)
            notifications.forEach { $0(self, .didChange) }
            updateWithModel()
        }
    }
    
    var option: ModelOption {
        didSet { updateWithModel() }
    }
    var defaultModel: Model {
        return option.defaultModel
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
        let t = option.ratioFromDefaultModel(with: model)
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
extension Circular1DView: BasicSlidablePointMovable {
    func didChangeFromMovePoint(_ phase: Phase, beganModel: Model) {
        notifications.forEach { $0(self, .didChangeFromPhase(phase, beginModel: beganModel)) }
    }
}
