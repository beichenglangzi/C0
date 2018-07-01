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

typealias EnumType = RawRepresentable & Equatable & Object.Value

struct EnumOption<Model: EnumType> {
    var defaultModel: Model
    var cationModels: [Model]
    let indexClosure: ((Model.RawValue) -> (Int))
    let rawValueClosure: ((Int) -> (Model.RawValue?))
    let names: [Text]
    
    func index(with model: Model) -> Int {
        return indexClosure(model.rawValue)
    }
    func model(at index: Int) -> Model {
        if let rawValue = rawValueClosure(index) {
            return Model(rawValue: rawValue) ?? defaultModel
        } else {
            return defaultModel
        }
    }
}

final class EnumView<T: EnumType, U: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = T
    typealias ModelOption = EnumOption<Model>
    typealias Binder = U
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((EnumView<Model, Binder>,
                           BasicPhaseNotification<Model>) -> ())]()
    
    var option: ModelOption {
        didSet { updateWithModel() }
    }
    var defaultModel: Model {
        return option.defaultModel
    }
    
    let classNameView: TextFormView
    let nameViews: [TextFormView]
    let knobView: View
    
    init(binder: Binder, keyPath: BinderKeyPath, option: ModelOption,
         isUninheritance: Bool = false) {
        
        self.binder = binder
        self.keyPath = keyPath
        self.option = option
        
        let className = isUninheritance ? Model.uninheritanceName : Model.name
        classNameView = TextFormView(text: className, font: .bold)
        nameViews = option.names.map {
            TextFormView(text: $0, paddingSize: Size(width: 4, height: 1))
        }
        knobView = View.discreteKnob(Size(square: 8), lineWidth: 1)
        
        super.init(isLocked: false)
        nameViews.forEach { $0.fillColor = nil }
        children = [classNameView, knobView] + nameViews
        updateWithModel()
    }
    
    var minSize: Size {
        let padding = Layouter.basicPadding, height = Layouter.basicHeight
        let np = Real(nameViews.count - 1) * padding
        let nw = nameViews.reduce(0.0.cg) { $0 + $1.minSize.width } + np
        return Size(width: classNameView.minSize.width + nw + padding * 3, height: height)
    }
    override func updateLayout() {
        let padding = Layouter.basicPadding
        let classNameSize = classNameView.minSize
        let classNameOrigin = Point(x: padding,
                                    y: bounds.height - classNameSize.height - padding)
        classNameView.frame = Rect(origin: classNameOrigin, size: classNameSize)
        
        let h = Layouter.basicHeight - padding * 2
        var y = bounds.height - padding - h
        _ = nameViews.reduce(classNameView.frame.maxX + padding) {
            let x: Real
            let minSize = $1.minSize
            if $0 + minSize.width + padding > bounds.width {
                x = padding
                y -= h + padding
            } else {
                x = $0
            }
            $1.frame = Rect(origin: Point(x: x, y: y), size: minSize)
            return x + minSize.width + padding
        }
        
        updateKnobLayout()
    }
    private func updateKnobLayout() {
        let index = option.index(with: model)
        knobView.frame = nameViews[index].frame
    }
    func updateWithModel() {
        updateKnobLayout()
        let index = option.index(with: model)
        nameViews.forEach {
            $0.lineColor = .subContent
        }
        if !option.cationModels.isEmpty {
            knobView.lineColor = knobLineColor
        }
        nameViews[index].lineColor = nil
        nameViews.enumerated().forEach {
            $0.element.textMaterial.color = $0.offset == index ? .locked : .subLocked
        }
    }
    
    var knobLineColor: Color {
        return option.cationModels.contains(model) ? .warning : .getSetBorder
    }
    func model(at p: Point) -> T {
        var minI = 0, minD = Real.infinity
        for (i, view) in nameViews.enumerated() {
            let d = view.frame.distance²(p)
            if d < minD {
                minI = i
                minD = d
            }
        }
        return option.model(at: minI)
    }
}
extension EnumView: Runnable {
    func run(for p: Point, _ version: Version) {
        push(model(at: p), to: version)
    }
}
extension EnumView: BasicSlidablePointMovable {
    func didChangeFromMovePoint(_ phase: Phase, beganModel: Model) {
        notifications.forEach { $0(self, .didChangeFromPhase(phase, beginModel: beganModel)) }
    }
}
