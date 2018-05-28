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

import struct Foundation.Locale

protocol Object2D: Codable & Referenceable {
    associatedtype XModel: Codable & Referenceable
    associatedtype YModel: Codable & Referenceable
    init(xModel: XModel, yModel: YModel)
    var xModel: XModel { get set }
    var yModel: YModel { get set }
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
    
    var defaultModel: Model { get }
    var minModel: Model { get }
    var maxModel: Model { get }
    func model(with object: Any) -> Model?
    func ratio2D(with model: Model) -> Ratio2D
    func ratio2DFromDefaultModel(with model: Model) -> Ratio2D
    func model(withDelta delta: Ratio2D, oldModel: Model) -> Model
    func model(withRatio ratio2D: Ratio2D) -> Model
    func clippedModel(_ model: Model) -> Model
}
extension Object2DOption {
    var defaultModel: Model {
        return Model(xModel: xOption.defaultModel, yModel: yOption.defaultModel)
    }
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
    func ratio2DFromDefaultModel(with model: Model) -> Ratio2D {
        return Ratio2D(x: xOption.ratioFromDefaultModel(with: model.xModel),
                       y: yOption.ratioFromDefaultModel(with: model.yModel))
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

final class Discrete2DView<T: Object2DOption, U: BinderProtocol>: View, Discrete, BindableReceiver {
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
    
    var sizeType: SizeType {
        didSet { updateLayout() }
    }
    var boundsPadding: Real {
        didSet { updateLayout() }
    }
    var interval = 1.5.cg, minDelta = 5.0.cg
    let knobView = View.discreteKnob()
    let boundsView: View
    let xNameView: TextFormView
    let yNameView: TextFormView
    
    init(binder: Binder, keyPath: BinderKeyPath, option: ModelOption,
         xyOrientation: Orientation.XY = .horizontal(.leftToRight),
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        self.option = option
        
        self.sizeType = sizeType
        boundsPadding = Layout.padding(with: sizeType)
        boundsView = View()
        boundsView.lineColor = .formBorder
        let font = Font.default(with: .small)
        xNameView = TextFormView(text: "x:", font: font)
        xView = Assignable1DView(binder: binder, keyPath: keyPath.appending(path: \Model.xModel),
                                 option: option.xOption, sizeType: .small)
        yNameView = TextFormView(text: "y:", font: font)
        yView = Assignable1DView(binder: binder, keyPath: keyPath.appending(path: \Model.yModel),
                                 option: option.yOption, sizeType: .small)
        
        super.init()
        boundsView.append(child: knobView)
        children = [boundsView, xNameView, xView, yNameView, yView]
        self.frame = frame
    }
    
    override var defaultBounds: Rect {
        let padding = Layout.padding(with: sizeType)
        let valueFrame = Layout.valueFrame(with: sizeType)
        let xWidth = xNameView.frame.width + valueFrame.width
        let yWidth = yNameView.frame.height + valueFrame.width
        return Rect(x: 0,
                    y: 0,
                    width: max(xWidth, yWidth) + padding * 2,
                    height: valueFrame.height * 2 + padding * 2)
    }
    override func updateLayout() {
        let padding = Layout.padding(with: sizeType)
        let valueFrame = Layout.valueFrame(with: sizeType)
        var x = bounds.width - padding, y = bounds.height - padding
        x -= valueFrame.width
        y -= valueFrame.height
        xView.frame.origin = Point(x: x, y: y)
        x -= xNameView.frame.width
        xNameView.frame.origin = Point(x: x, y: y + padding)
        x = bounds.width - padding
        x -= valueFrame.width
        y -= valueFrame.height
        yView.frame.origin = Point(x: x, y: y)
        x -= yNameView.frame.width
        yNameView.frame.origin = Point(x: x, y: y + padding)
        boundsView.frame = Rect(x: padding,
                                y: padding,
                                width: bounds.width - valueFrame.width - padding * 3,
                                height: bounds.height - padding * 2)
        updateWithModel()
    }
    func updateWithModel() {
        xView.updateWithModel()
        yView.updateWithModel()
        let inBounds = boundsView.bounds.inset(by: boundsPadding)
        let ratio2D = option.ratio2DFromDefaultModel(with: model)
        let x = inBounds.width * ratio2D.x + inBounds.minX
        let y = inBounds.height * ratio2D.y + inBounds.minY
        knobView.position = Point(x: x.rounded(), y: y.rounded())
    }
    
    func model(at p: Point, first fp: Point, old oldModel: Model) -> Model {
        func t(withDelta delta: Real) -> Real {
            guard abs(delta) > minDelta else {
                return 0
            }
            return (delta > 0 ? delta - minDelta : delta + minDelta) / interval
        }
        let xt =  t(withDelta: p.x - fp.x), yt = t(withDelta: p.y - fp.y)
        let ratio2D = Ratio2D(x: xt, y: yt)
        return option.model(withDelta: ratio2D, oldModel: oldModel)
    }
}
extension Discrete2DView: Assignable {
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
extension Discrete2DView: BasicDiscretePointMovable {
    func didChangeFromMovePoint(_ phase: Phase, beganModel: Model) {
        notifications.forEach { $0(self, .didChangeFromPhase(phase, beginModel: beganModel)) }
    }
}

final class Slidable2DView<T: Object2DOption, U: BinderProtocol>: View, Slidable, BindableReceiver {
    typealias Model = T.Model
    typealias ModelOption = T
    typealias Binder = U
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((Slidable2DView<ModelOption, Binder>,
                           BasicPhaseNotification<Model>) -> ())]()
    
    var option: ModelOption {
        didSet { updateWithModel() }
    }
    
    var padding = 5.0.cg {
        didSet { updateLayout() }
    }
    let knobView = View.knob()
    
    init(binder: Binder, keyPath: BinderKeyPath, option: ModelOption,
         frame: Rect = Rect()) {
        
        self.binder = binder
        self.keyPath = keyPath
        self.option = option
        
        super.init()
        self.frame = frame
        append(child: knobView)
    }
    
    override func updateLayout() {
        updateWithModel()
    }
    func updateWithModel() {
        knobView.position = position(from: model)
    }
    func model(at p: Point) -> Model {
        let inBounds = bounds.inset(by: padding)
        let x = (p.x - inBounds.origin.x) / inBounds.width
        let y = (p.y - inBounds.origin.y) / inBounds.height
        let model = option.model(withRatio: Ratio2D(x: x, y: y))
        return option.clippedModel(model)
    }
    func position(from model: Model) -> Point {
        let inBounds = bounds.inset(by: padding)
        let ratio2D = option.ratio2D(with: model)
        let x = inBounds.width * ratio2D.x + inBounds.origin.x
        let y = inBounds.height * ratio2D.y + inBounds.origin.y
        return Point(x: x, y: y)
    }
}
extension Slidable2DView: Assignable {
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
extension Slidable2DView: Runnable {
    func run(for p: Point, _ version: Version) {
        push(option.clippedModel(model(at: p)), to: version)
    }
}
extension Slidable2DView: BasicSlidablePointMovable {
    func didChangeFromMovePoint(_ phase: Phase, beganModel: Model) {
        notifications.forEach { $0(self, .didChangeFromPhase(phase, beginModel: beganModel)) }
    }
}
