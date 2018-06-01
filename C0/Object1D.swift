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

import struct Foundation.Locale
import CoreGraphics

typealias Object1D = Object.Value

protocol Object1DOption: GetterOption {
    var defaultModel: Model { get }
    var minModel: Model { get }
    var maxModel: Model { get }
    var transformedModel: ((Model) -> (Model)) { get }
    func model(with object: Any) -> Model?
    func ratio(with model: Model) -> Real
    func ratioFromDefaultModel(with model: Model) -> Real
    func model(withDelta delta: Real, oldModel: Model) -> Model
    func model(withRatio ratio: Real) -> Model
    func clippedModel(_ model: Model) -> Model
}

final class Assignable1DView<T: Object1DOption, U: BinderProtocol>: View, BindableReceiver {
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
    
    var sizeType: SizeType
    let optionTextView: TextFormView
    
    init(binder: Binder, keyPath: BinderKeyPath, option: ModelOption,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        self.option = option
        
        self.sizeType = sizeType
        optionTextView = TextFormView(text: option.displayText(with: binder[keyPath: keyPath]),
                                      font: Font.default(with: sizeType),
                                      frameAlignment: .right, alignment: .right)
        
        super.init()
        noIndicatedLineColor = .getBorder
        indicatedLineColor = .indicated
        isClipped = true
        children = [optionTextView]
        self.frame = frame
    }
    
    override var defaultBounds: Rect {
        return optionTextView.defaultBounds
    }
    override func updateLayout() {
        optionTextView.frame.origin = Point(x: bounds.width - optionTextView.frame.width,
                                            y: bounds.height - optionTextView.frame.height)
    }
    func updateWithModel() {
        updateString()
    }
    private func updateString() {
        optionTextView.text = option.displayText(with: model)
    }
}
extension Assignable1DView: Assignable {
    func reset(for p: Point, _ version: Version) {
        push(option.defaultModel, to: version)
    }
    func copiedObjects(at p: Point) -> [Object] {
        return [Object(model)]
    }
    func paste(_ objects: [Any], for p: Point, _ version: Version) {
        for object in objects {
            if let model = option.model(with: object) {
                push(option.clippedModel(model), to: version)
                return
            }
        }
    }
}

protocol Discrete {}

/**
 Issue: スクロールによる値の変更
 */
final class Discrete1DView<T: Object1DOption, U: BinderProtocol>: View, Discrete, BindableReceiver {
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
    
    var sizeType: SizeType {
        didSet { updateLayout() }
    }
    var xyOrientation: Orientation.XY {
        didSet { updateLayout() }
    }
    var interval = 1.5.cg
    private var knobLineFrame = Rect()
    let labelPaddingX: Real, knobPadding: Real
    let knobView = View.discreteKnob(Size(width: 6, height: 4), lineWidth: 1)
    let linePathView: View = {
        let linePathView = View(isLocked: true)
        linePathView.lineColor = .content
        return linePathView
    } ()
    let optionStringView: TextFormView
    
    init(binder: Binder, keyPath: BinderKeyPath, option: ModelOption,
         xyOrientation: Orientation.XY = .horizontal(.leftToRight),
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        self.option = option
        
        self.sizeType = sizeType
        self.xyOrientation = xyOrientation
        knobPadding = sizeType == .small ? 2 : 3
        labelPaddingX = Layout.padding(with: sizeType)
        optionStringView = TextFormView(font: Font.default(with: sizeType),
                                      frameAlignment: .right, alignment: .right)
        
        super.init()
        isClipped = true
        children = [optionStringView, linePathView, knobView]
        self.frame = frame
    }
    
    override var defaultBounds: Rect {
        return Rect(x: 0, y: 0, width: 80, height: Layout.height(with: sizeType))
    }
    override func updateLayout() {
        let paddingX = sizeType == .small ? 3.0.cg : 5.0.cg
        knobLineFrame = Rect(x: paddingX, y: sizeType == .small ? 1 : 2,
                             width: bounds.width - paddingX * 2, height: 1)
        linePathView.frame = knobLineFrame
        let x = bounds.width - optionStringView.frame.width - labelPaddingX
        let y = ((bounds.height - optionStringView.frame.height) / 2).rounded()
        optionStringView.frame.origin = Point(x: x, y: y)
        
        updateknobLayout()
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
}
extension Discrete1DView: Assignable {
    func reset(for p: Point, _ version: Version) {
        push(option.defaultModel, to: version)
    }
    func copiedObjects(at p: Point) -> [Object] {
        return [Object(model)]
    }
    func paste(_ objects: [Any], for p: Point, _ version: Version) {
        for object in objects {
            if let model = option.model(with: object) {
                push(option.clippedModel(model), to: version)
                return
            }
        }
    }
}
extension Discrete1DView: BasicDiscretePointMovable {
    func didChangeFromMovePoint(_ phase: Phase, beganModel: Model) {
        notifications.forEach { $0(self, .didChangeFromPhase(phase, beginModel: beganModel)) }
    }
}

protocol Slidable {}

final class Slidable1DView<T: Object1DOption, U: BinderProtocol>: View, Slidable, BindableReceiver {
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
    
    var sizeType: SizeType {
        didSet { updateLayout() }
    }
    var xyOrientation: Orientation.XY {
        didSet { updateLayout() }
    }
    var padding: Real {
        didSet { updateLayout() }
    }
    let knobView: View
    var backgroundViews = [View]() {
        didSet {
            children = backgroundViews + [knobView]
        }
    }
    
    init(binder: Binder, keyPath: BinderKeyPath, option: ModelOption,
         xyOrientation: Orientation.XY = .horizontal(.leftToRight),
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        self.option = option
        
        self.sizeType = sizeType
        self.xyOrientation = xyOrientation
        padding = sizeType == .small ? 6 : 8
        knobView = sizeType == .small ? View.knob(radius: 4) : View.knob()
        
        super.init()
        append(child: knobView)
        self.frame = frame
    }
    
    override func updateLayout() {
        updateKnobLayout()
    }
    private func updateKnobLayout() {
        let t = option.ratioFromDefaultModel(with: model)
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
}
extension Slidable1DView: Assignable {
    func reset(for p: Point, _ version: Version) {
        push(option.defaultModel, to: version)
    }
    func copiedObjects(at p: Point) -> [Object] {
        return [Object(model)]
    }
    func paste(_ objects: [Any], for p: Point, _ version: Version) {
        for object in objects {
            if let model = option.model(with: object) {
                push(option.clippedModel(model), to: version)
                return
            }
        }
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
extension Slidable1DView {
    private static func opacityViewViews(with bounds: Rect,
                                         checkerWidth: Real, padding: Real) -> [View] {
        let frame = Rect(x: padding, y: bounds.height / 2 - checkerWidth,
                         width: bounds.width - padding * 2, height: checkerWidth * 2)
        
        let values = [Gradient.Value(color: .subContent, location: 0),
                      Gradient.Value(color: .content, location: 1)]
        let backgroundView = View(gradient: Gradient(values: values,
                                                     startPoint: Point(x: 0, y: 0),
                                                     endPoint: Point(x: 1, y: 0)))
        backgroundView.frame = frame
        
        let checkerboardView = View(path: Path.checkerboard(with: Size(square: checkerWidth),
                                                            in: frame))
        checkerboardView.fillColor = .content
        
        return [backgroundView, checkerboardView]
    }
    func updateOpacityViews(withFrame frame: Rect) {
        guard self.frame != frame else { return }
        self.frame = frame
        backgroundViews = Slidable1DView.opacityViewViews(with: frame,
                                                          checkerWidth: knobView.radius,
                                                          padding: padding)
    }
}

final class Circular1DView<T: Object1DOption, U: BinderProtocol>: View, Slidable, BindableReceiver {
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
    
    var sizeType: SizeType {
        didSet { updateLayout() }
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
         startAngle: Real = -.pi, width: Real = 16,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        self.option = option
        
        self.sizeType = sizeType
        self.circularOrientation = circularOrientation
        self.startAngle = startAngle
        self.width = width
        knobView = sizeType == .small ? View.knob(radius: 4) : View.knob()
        
        super.init(path: Path(), isLocked: false)
        fillColor = nil
        lineWidth = 0.5
        append(child: knobView)
        self.frame = frame
    }
    
    override func updateLayout() {
        let cp = Point(x: bounds.midX, y: bounds.midY), r = bounds.width / 2
        let fp0 = cp + Point(x: r, y: 0)
        let arc0 = PathLine.Arc(centerPoint: cp, endAngle: 2 * .pi,
                                circularOrientation: .clockwise)
        let fp1 = cp + Point(x: r - width, y: 0)
        let arc1 = PathLine.Arc(centerPoint: cp, endAngle: 2 * .pi,
                                circularOrientation: .counterClockwise)
        var path = Path()
        path.append(PathLine(firstPoint: fp0, elements: [.arc(arc0)]))
        path.append(PathLine(firstPoint: fp1, elements: [.arc(arc1)]))
        self.path = path
        updateKnobLayout()
    }
    private func updateKnobLayout() {
        let t = option.ratioFromDefaultModel(with: model)
        let theta = circularOrientation == .clockwise ?
            startAngle - t * (2 * .pi) : startAngle + t * (2 * .pi)
        let cp = Point(x: bounds.midX, y: bounds.midY), r = bounds.width / 2 - width / 2
        knobView.position = cp + r * Point(x: cos(theta), y: sin(theta))
    }
    func updateWithModel() {
        updateKnobLayout()
    }
    func model(at p: Point) -> Model {
        guard !bounds.isEmpty else {
            return self.model
        }
        let cp = Point(x: bounds.midX, y: bounds.midY)
        let theta = cp.tangential(p)
        let ct = (theta > startAngle ?
            theta - startAngle : theta - startAngle + 2 * .pi) / (2 * .pi)
        let t = circularOrientation == .clockwise ? 1 - ct : ct
        let model = option.model(withRatio: t)
        return option.clippedModel(model)
    }
}
extension Circular1DView: Assignable {
    func reset(for p: Point, _ version: Version) {
        push(option.defaultModel, to: version)
    }
    func copiedObjects(at p: Point) -> [Object] {
        return [Object(model)]
    }
    func paste(_ objects: [Any], for p: Point, _ version: Version) {
        for object in objects {
            if let model = option.model(with: object) {
                push(model, to: version)
                return
            }
        }
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
