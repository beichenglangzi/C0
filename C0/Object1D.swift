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

protocol Object1DOption {
    associatedtype Model: Object1D
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
        knobView = View.knob
        
        super.init(isLocked: false)
        append(child: knobView)
        updateWithModel()
    }
    
    var minSize: Size {
        switch xyOrientation {
        case .horizontal:
            return Size(width: Layouter.minWidth + padding,
                        height: Layouter.textPaddingHeight)
        case .vertical:
            return Size(width: Layouter.textPaddingHeight,
                        height: Layouter.minWidth + padding)
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
        knobView = View.knob
        
        super.init(path: Path(), isLocked: false)
        fillColor = nil
        append(child: knobView)
    }
    
    func circularPath(withBounds bounds: Rect) -> Path {
        let cp = Point(x: bounds.midX, y: bounds.midY), r = bounds.width / 2
        let mr = r + width
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
extension Circular1DView: BasicPointMovable {
    func didChangeFromMovePoint(_ phase: Phase, beganModel: Model) {
        notifications.forEach { $0(self, .didChangeFromPhase(phase, beginModel: beganModel)) }
    }
}
