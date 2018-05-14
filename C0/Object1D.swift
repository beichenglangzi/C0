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

typealias Object1D = ObjectProtocol & Referenceable

protocol Object1DOption: GetterOption {
    var defaultModel: Model { get }
    var minModel: Model { get }
    var maxModel: Model { get }
    func model(with string: String) -> Model?
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
        optionTextView = TextFormView(text: option.text(with: model),
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
        updateWithModel()
    }
    func updateWithModel() {
        updateString()
    }
    private func updateString() {
        optionTextView.text = option.text(with: model)
    }
}
extension Assignable1DView: ViewQueryable {
    static var referenceableType: Referenceable.Type {
        return Model.self
    }
    static var viewDescription: Text {
        return Text(english: "Assignable", japanese: "代入可能")
    }
}
extension Assignable1DView: Assignable {
    func delete(for p: Point, _ version: Version) {
        push(option.defaultModel, to: version)
    }
    func copiedObjects(at p: Point) -> [Viewable] {
        return [model]
    }
    func paste(_ objects: [Object], for p: Point, _ version: Version) {
        for object in objects {
            if let model = object as? Model {
                push(option.clippedModel(model), to: version)
                return
            } else if let string = object as? String, let model = option.model(with: string) {
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
    let optionTextView: TextFormView
    
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
        optionTextView = TextFormView(font: Font.default(with: sizeType),
                                      frameAlignment: .right, alignment: .right)
        
        super.init()
        isClipped = true
        children = [optionTextView, linePathView, knobView]
        self.frame = frame
    }
    
    override func updateLayout() {
        let paddingX = sizeType == .small ? 3.0.cg : 5.0.cg
        knobLineFrame = Rect(x: paddingX, y: sizeType == .small ? 1 : 2,
                             width: bounds.width - paddingX * 2, height: 1)
        linePathView.frame = knobLineFrame
        let x = bounds.width - optionTextView.frame.width - labelPaddingX
        let y = ((bounds.height - optionTextView.frame.height) / 2).rounded()
        optionTextView.frame.origin = Point(x: x, y: y)
        
        updateWithModel()
    }
    func updateWithModel() {
        updateString()
        updateknob()
    }
    private func updateString() {
        optionTextView.text = option.text(with: model)
    }
    private func updateknob() {
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
    
    private func model(at p: Point, first fp: Point, old oldModel: Model) -> Model {
        let delta: Real
        switch xyOrientation {
        case .horizontal(let horizontal):
            delta = horizontal == .leftToRight ? p.x - fp.x : fp.x - p.x
        case .vertical(let vertical):
            delta = vertical == .bottomToTop ? p.y - fp.y : fp.y - p.y
        }
        return option.model(withDelta: delta / interval, oldModel: oldModel)
    }
    
    private var pointMovableOldModel: Model?
}
extension Discrete1DView: ViewQueryable {
    static var referenceableType: Referenceable.Type {
        return Model.self
    }
    static var viewDescription: Text {
        return Text(english: "Discrete Slider", japanese: "離散スライダー")
    }
}
extension Discrete1DView: Assignable {
    func delete(for p: Point, _ version: Version) {
        push(option.defaultModel, to: version)
    }
    func copiedObjects(at p: Point) -> [Viewable] {
        return [model]
    }
    func paste(_ objects: [Object], for p: Point, _ version: Version) {
        for object in objects {
            if let model = object as? Model {
                push(option.clippedModel(model), to: version)
                return
            } else if let string = object as? String, let model = option.model(with: string) {
                push(option.clippedModel(model), to: version)
                return
            }
        }
    }
}
extension Discrete1DView: PointMovable {
    func captureWillMovePoint(at p: Point, to version: Version) {
        capture(model, to: version)
        self.pointMovableOldModel = model
    }
    func movePoint(for p: Point, first fp: Point, pressure: Real, time: Second, _ phase: Phase) {
        guard let oldModel = pointMovableOldModel else { return }
        switch phase {
        case .began: knobView.fillColor = .editing
        case .changed: break
        case .ended: knobView.fillColor = .knob
        }
        model = option.clippedModel(model(at: p, first: fp, old: oldModel))
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
        updateWithModel()
    }
    func updateWithModel() {
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
extension Slidable1DView: ViewQueryable {
    static var referenceableType: Referenceable.Type {
        return Real.self
    }
    static var viewDescription: Text {
        return Text(english: "Slider", japanese: "スライダー")
    }
}
extension Slidable1DView: Assignable {
    func delete(for p: Point, _ version: Version) {
        push(option.defaultModel, to: version)
    }
    func copiedObjects(at p: Point) -> [Viewable] {
        return [model]
    }
    func paste(_ objects: [Any], for p: Point, _ version: Version) {
        for object in objects {
            switch object {
            case let model as Model:
                push(model, to: version)
                return
            case let string as String:
                if let model = option.model(with: string) {
                    push(model, to: version)
                    return
                }
            default: break
            }
        }
    }
}
extension Slidable1DView: Runnable {
    func run(for p: Point, _ version: Version) {
        push(option.clippedModel(model(at: p)), to: version)
    }
}
extension Slidable1DView: PointMovable {
    func captureWillMovePoint(at p: Point, to version: Version) {
        capture(model, to: version)
    }
    func movePoint(for p: Point, first fp: Point, pressure: Real, time: Second, _ phase: Phase) {
        switch phase {
        case .began: knobView.fillColor = .editing
        case .changed: break
        case .ended: knobView.fillColor = .knob
        }
        model = option.clippedModel(model(at: p))
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
        
        super.init(path: CGMutablePath(), isLocked: false)
        fillColor = nil
        lineWidth = 0.5
        append(child: knobView)
        self.frame = frame
    }
    
    override func updateLayout() {
        let cp = Point(x: bounds.midX, y: bounds.midY), r = bounds.width / 2
        let path = CGMutablePath()
        path.addArc(center: cp, radius: r, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        path.move(to: cp + Point(x: r - width, y: 0))
        path.addArc(center: cp, radius: r - width, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
        self.path = path
        updateWithModel()
    }
    func updateWithModel() {
        let t = option.ratioFromDefaultModel(with: model)
        let theta = circularOrientation == .clockwise ?
            startAngle - t * (2 * .pi) : startAngle + t * (2 * .pi)
        let cp = Point(x: bounds.midX, y: bounds.midY), r = bounds.width / 2 - width / 2
        knobView.position = cp + r * Point(x: cos(theta), y: sin(theta))
    }
    func model(at p: Point) -> Model {
        guard !bounds.isEmpty else {
            return model
        }
        let cp = Point(x: bounds.midX, y: bounds.midY)
        let theta = cp.tangential(p)
        let ct = (theta > startAngle ? theta - startAngle : theta - startAngle + 2 * .pi) / (2 * .pi)
        let t = circularOrientation == .clockwise ? 1 - ct : ct
        return option.model(withRatio: t)
    }
}
extension Circular1DView: ViewQueryable {
    static var referenceableType: Referenceable.Type {
        return Model.self
    }
    static var viewDescription: Text {
        return Text(english: "Circular Slider", japanese: "円状スライダー")
    }
}
extension Circular1DView: Assignable {
    func delete(for p: Point, _ version: Version) {
        push(option.defaultModel, to: version)
    }
    func copiedObjects(at p: Point, _ version: Version) -> [Viewable] {
        return [model]
    }
    func paste(_ objects: [Object], for p: Point, _ version: Version) {
        for object in objects {
            if let model = object as? Model {
                push(option.clippedModel(model), to: version)
                return
            } else if let string = object as? String, let model = option.model(with: string) {
                push(option.clippedModel(model), to: version)
                return
            }
        }
    }
}
extension Circular1DView: Runnable {
    func run(for p: Point, _ version: Version) {
        push(option.clippedModel(model(at: p)), to: version)
    }
}
extension Circular1DView: PointMovable {
    func captureWillMovePoint(at p: Point, to version: Version) {
        capture(model, to: version)
    }
    func movePoint(for p: Point, first fp: Point, pressure: Real, time: Second, _ phase: Phase) {
        switch phase {
        case .began: knobView.fillColor = .editing
        case .changed: break
        case .ended: knobView.fillColor = .knob
        }
        model = option.clippedModel(model(at: p))
    }
}
