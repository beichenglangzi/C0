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

protocol Object2D: Object.Value {
    associatedtype XModel: Codable & Referenceable
    associatedtype YModel: Codable & Referenceable
    init(xModel: XModel, yModel: YModel)
    var xModel: XModel { get set }
    var yModel: YModel { get set }
    static var xDisplayText: Text { get }
    static var yDisplayText: Text { get }
}

struct Ratio2D {
    var x = 0.0.cg, y = 0.0.cg
}
protocol Object2DOption {
    associatedtype Model: Object2D
    associatedtype XOption: Object1DOption where XOption.Model == Model.XModel
    associatedtype YOption: Object1DOption where YOption.Model == Model.YModel
    var xOption: XOption { get }
    var yOption: YOption { get }
    
    var minModel: Model { get }
    var maxModel: Model { get }
    func ratio2D(with model: Model) -> Ratio2D
    func model(withDelta delta: Ratio2D, oldModel: Model) -> Model
    func model(withRatio ratio2D: Ratio2D) -> Model
    func clippedModel(_ model: Model) -> Model
}
extension Object2DOption {
    var minModel: Model {
        return Model(xModel: xOption.minModel, yModel: yOption.minModel)
    }
    var maxModel: Model {
        return Model(xModel: xOption.maxModel, yModel: yOption.maxModel)
    }
    func ratio2D(with model: Model) -> Ratio2D {
        return Ratio2D(x: xOption.ratio(with: model.xModel),
                       y: yOption.ratio(with: model.yModel))
    }
    func model(withDelta delta: Ratio2D, oldModel: Model) -> Model {
        return Model(xModel: xOption.model(withDelta: delta.x, oldModel: oldModel.xModel),
                     yModel: yOption.model(withDelta: delta.y, oldModel: oldModel.yModel))
    }
    func model(withRatio ratio2D: Ratio2D) -> Model {
        return Model(xModel: xOption.model(withRatio: ratio2D.x),
                     yModel: yOption.model(withRatio: ratio2D.y))
    }
    func clippedModel(_ model: Model) -> Model {
        return Model(xModel: xOption.clippedModel(model.xModel),
                     yModel: yOption.clippedModel(model.yModel))
    }
}

final class AssignableObject2DView<T: Object2DOption, U: BinderProtocol>
: ModelView, BindableReceiver {
    
    typealias Model = T.Model
    typealias ModelOption = T
    typealias Binder = U
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((AssignableObject2DView<ModelOption, Binder>,
                           BasicNotification) -> ())]()
    
    var option: ModelOption {
        didSet { updateWithModel() }
    }
    
    let xView: Assignable1DView<ModelOption.XOption, Binder>
    let yView: Assignable1DView<ModelOption.YOption, Binder>
    
    let xNameView: TextFormView
    let yNameView: TextFormView
    
    init(binder: Binder, keyPath: BinderKeyPath, option: ModelOption,
         xyOrientation: Orientation.XY = .horizontal(.leftToRight)) {
        
        self.binder = binder
        self.keyPath = keyPath
        self.option = option
        
        xNameView = TextFormView(text: Model.xDisplayText + ":")
        xView = Assignable1DView(binder: binder, keyPath: keyPath.appending(path: \Model.xModel),
                                 option: option.xOption)
        yNameView = TextFormView(text: Model.yDisplayText + ":")
        yView = Assignable1DView(binder: binder, keyPath: keyPath.appending(path: \Model.yModel),
                                 option: option.yOption)
        
        super.init(isLocked: false)
        children = [xNameView, xView, yNameView, yView]
    }
    
    var minSize: Size {
        let padding = Layouter.basicPadding
        let width = Layouter.basicValueWidth
        let height = Layouter.basicTextHeight
        let xNameSize = xNameView.minSize, yNameSize = yNameView.minSize
        var w = 0.0.cg
        w += xNameSize.width + width
        w += padding
        w += yNameSize.width + width
        let h = height
        return Size(width: w + padding * 2, height: h + padding * 2)
    }
    override func updateLayout() {
        let padding = Layouter.basicPadding
        let width = Layouter.basicValueWidth
        let height = Layouter.basicTextHeight
        let xNameSize = xNameView.minSize, yNameSize = yNameView.minSize
        var x = padding
        let y = padding
        xNameView.frame = Rect(origin: Point(x: x, y: y), size: xNameSize)
        x += xNameSize.width
        xView.frame = Rect(x: x, y: y, width: width, height: height)
        x += width + padding
        yNameView.frame = Rect(origin: Point(x: x, y: y), size: yNameSize)
        x += yNameSize.width
        yView.frame = Rect(x: x, y: y, width: width, height: height)
    }
    func updateWithModel() {
        xView.updateWithModel()
        yView.updateWithModel()
    }
    
    func clippedModel(_ model: Model) -> Model {
        return option.clippedModel(model)
    }
}

final class Discrete2DView<T: Object2DOption, U: BinderProtocol>
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
    var notifications = [((Discrete2DView<ModelOption, Binder>,
                           BasicPhaseNotification<Model>) -> ())]()
    
    var option: ModelOption {
        didSet { updateWithModel() }
    }
    
    let xView: Assignable1DView<ModelOption.XOption, Binder>
    let yView: Assignable1DView<ModelOption.YOption, Binder>
    
    var interval = 1.5.cg, minDelta = 5.0.cg
    
    let xNameView: TextFormView
    let xKnobView = View.discreteKnob(Size(square: 5), lineWidth: 1)
    let xKnobLineView: View = {
        let view = View()
        view.fillColor = .content
        return view
    } ()
    
    let yNameView: TextFormView
    let yKnobView = View.discreteKnob(Size(square: 5), lineWidth: 1)
    let yKnobLineView: View = {
        let view = View()
        view.fillColor = .content
        return view
    } ()
    
    init(binder: Binder, keyPath: BinderKeyPath, option: ModelOption,
         xyOrientation: Orientation.XY = .horizontal(.leftToRight)) {
        
        self.binder = binder
        self.keyPath = keyPath
        self.option = option
        
        xNameView = TextFormView(text: Model.xDisplayText + ":")
        xView = Assignable1DView(binder: binder, keyPath: keyPath.appending(path: \Model.xModel),
                                 name: Model.xDisplayText,
                                 option: option.xOption)
        yNameView = TextFormView(text: Model.yDisplayText + ":")
        yView = Assignable1DView(binder: binder, keyPath: keyPath.appending(path: \Model.yModel),
                                 name: Model.yDisplayText,
                                 option: option.yOption)
        
        super.init(isLocked: false)
        xKnobView.fillColor = .scroll
        yKnobView.fillColor = .scroll
        children = [xView, yView,
                    xKnobLineView, yKnobLineView, xKnobView, yKnobView]
    }
    
    var minSize: Size {
        let padding = Layouter.basicPadding
        let width = Layouter.basicValueWidth
        let height = Layouter.basicTextHeight
        var w = 0.0.cg
        w += width
        w += padding
        w += width
        w += padding
        w += height + padding * 4
        return Size(width: w + padding * 2, height: height + padding * 2)
    }
    override func updateLayout() {
        let padding = Layouter.basicPadding
        let width = Layouter.basicValueWidth
        let height = Layouter.basicTextHeight
        var x = padding
        let y = padding
        xView.frame = Rect(x: x, y: y, width: width, height: height)
        x += width + padding
        yView.frame = Rect(x: x, y: y, width: width, height: height)
        x += width + padding
        xKnobLineView.frame = Rect(x: x, y: bounds.midY - 0.5, width: height, height: 1)
        x += height + padding * 2
        yKnobLineView.frame = Rect(x: x, y: padding, width: 1, height: height)
        updateKnobLayout()
    }
    private func updateKnobLayout() {
        let ratio2D = option.ratio2D(with: model)
        let xb = xKnobLineView.frame, yb = yKnobLineView.frame
        let x = (xb.width * ratio2D.x + xb.minX).interval(scale: 0.5)
        let y = (yb.height * ratio2D.y + yb.minY).interval(scale: 0.5)
        xKnobView.position = Point(x: x, y: xb.midY)
        yKnobView.position = Point(x: yb.midX, y: y)
    }
    func updateWithModel() {
        updateKnobLayout()
        xView.updateWithModel()
        yView.updateWithModel()
    }
    
    func t(withDelta delta: Real) -> Real {
        guard abs(delta) > minDelta else {
            return 0
        }
        return (delta > 0 ? delta - minDelta : delta + minDelta) / interval
    }
    func model(at p: Point, first fp: Point, old oldModel: Model) -> Model {
        let xt =  t(withDelta: p.x - fp.x), yt = t(withDelta: p.y - fp.y)
        let ratio2D = Ratio2D(x: xt, y: yt)
        return option.model(withDelta: ratio2D, oldModel: oldModel)
    }
    
    func clippedModel(_ model: Model) -> Model {
        return option.clippedModel(model)
    }
}
extension Discrete2DView: BasicXSlidable {
    var xInterval: Real {
        return interval
    }
    func xClippedDelta(withDelta delta: Real, oldModel: T.Model) -> Real {
        return option.xOption.clippedDelta(withDelta: delta, oldModel: oldModel.xModel)
    }
    func xModel(delta: Real, old oldModel: T.Model) -> T.Model {
        let ratio2D = Ratio2D(x: t(withDelta: delta), y: 0)
        return option.model(withDelta: ratio2D, oldModel: oldModel)
    }
    func didChangeFromXSlide(_ phase: Phase, beganModel: Model) {
        notifications.forEach { $0(self, .didChangeFromPhase(phase, beginModel: beganModel)) }
    }
}

final class Movable2DView<T: Object2DOption, U: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = T.Model
    typealias ModelOption = T
    typealias Binder = U
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((Movable2DView<ModelOption, Binder>,
                           BasicPhaseNotification<Model>) -> ())]()
    
    var option: ModelOption {
        didSet { updateWithModel() }
    }
    
    var padding = 5.0.cg {
        didSet { updateLayout() }
    }
    let knobView = View.knob()
    
    init(binder: Binder, keyPath: BinderKeyPath, option: ModelOption) {
        self.binder = binder
        self.keyPath = keyPath
        self.option = option
        
        super.init(isLocked: false)
        append(child: knobView)
    }
    
    var minSize: Size {
        return Size(square: Layouter.defaultMinWidth + padding)
    }
    override func updateLayout() {
        updateKnobLayout()
    }
    private func updateKnobLayout() {
        knobView.position = position(from: model)
    }
    func updateWithModel() {
        updateKnobLayout()
    }
    func model(at p: Point) -> Model {
        let inBounds = bounds.inset(by: padding)
        guard !inBounds.isEmpty else {
            let model = option.model(withRatio: Ratio2D(x: 0, y: 0))
            return option.clippedModel(model)
        }
        let x = (p.x - inBounds.origin.x) / inBounds.width
        let y = (p.y - inBounds.origin.y) / inBounds.height
        let model = option.model(withRatio: Ratio2D(x: x, y: y))
        return option.clippedModel(model)
    }
    func position(from model: Model) -> Point {
        let inBounds = bounds.inset(by: padding)
        guard !inBounds.isEmpty else {
            return Point()
        }
        let ratio2D = option.ratio2D(with: model)
        let x = inBounds.width * ratio2D.x + inBounds.origin.x
        let y = inBounds.height * ratio2D.y + inBounds.origin.y
        return Point(x: x, y: y)
    }
    
    func clippedModel(_ model: Model) -> Model {
        return option.clippedModel(model)
    }
}
extension Movable2DView: Runnable {
    func run(for p: Point, _ version: Version) {
        push(option.clippedModel(model(at: p)), to: version)
    }
}
extension Movable2DView: BasicPointMovable {
    func didChangeFromMovePoint(_ phase: Phase, beganModel: Model) {
        notifications.forEach { $0(self, .didChangeFromPhase(phase, beginModel: beganModel)) }
    }
}
