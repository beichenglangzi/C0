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
    associatedtype XModel: Object1D
    associatedtype YModel: Object1D
    init(xModel: XModel, yModel: YModel)
    var xModel: XModel { get set }
    var yModel: YModel { get set }
    static var xDisplayText: Localization { get }
    static var yDisplayText: Localization { get }
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
    
    let knobView = View.knob
    
    init(binder: Binder, keyPath: BinderKeyPath, option: ModelOption) {
        self.binder = binder
        self.keyPath = keyPath
        self.option = option
        
        super.init(isLocked: false)
        append(child: knobView)
    }
    
    var minSize: Size {
        return Size(square: Layouter.minWidth + Layouter.movablePadding)
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
        let inBounds = bounds.inset(by: Layouter.movablePadding)
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
        let inBounds = bounds.inset(by: Layouter.movablePadding)
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
extension Movable2DView: BasicPointMovable {
    func didChangeFromMovePoint(_ phase: Phase, beganModel: Model) {
        notifications.forEach { $0(self, .didChangeFromPhase(phase, beginModel: beganModel)) }
    }
}
