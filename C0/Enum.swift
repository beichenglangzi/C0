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
    var cationModels: [Model]
    let indexClosure: ((Model.RawValue) -> (Int))
    let rawValueClosure: ((Int) -> (Model.RawValue?))
    let title: Localization
    let names: [Localization]
    
    func index(with model: Model) -> Int {
        return indexClosure(model.rawValue)
    }
    func model(at index: Int) -> Model? {
        if let rawValue = rawValueClosure(index) {
            return Model(rawValue: rawValue)
        } else {
            return nil
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
    
    let stringView: StringFormView
    let nameViews: [StringFormView]
    
    init(binder: Binder, keyPath: BinderKeyPath, option: ModelOption,
         isUninheritance: Bool = false) {
        
        self.binder = binder
        self.keyPath = keyPath
        self.option = option
        
        stringView = StringFormView(string: option.title.currentString, font: .bold)
        nameViews = option.names.map {
            StringFormView(string: $0.currentString, paddingSize: Size(width: 4, height: 1))
        }
        
        super.init(isLocked: false)
        nameViews.forEach { $0.fillColor = nil }
        children = [stringView] + nameViews
        updateWithModel()
    }
    
    var minSize: Size {
        let padding = Layouter.padding, height = Layouter.textPaddingHeight
        let np = Real(nameViews.count - 1) * padding
        let nw = nameViews.reduce(0.0.cg) { $0 + $1.minSize.width } + np
        return Size(width: stringView.minSize.width + nw + padding * 3, height: height)
    }
    override func updateLayout() {
        let padding = Layouter.padding
        let classNameSize = stringView.minSize
        let classNameOrigin = Point(x: padding,
                                    y: bounds.height - classNameSize.height - padding)
        stringView.frame = Rect(origin: classNameOrigin, size: classNameSize)
        
        let h = Layouter.textPaddingHeight - padding * 2
        var y = bounds.height - padding - h
        _ = nameViews.reduce(stringView.frame.maxX + padding) {
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
    }
    func updateWithModel() {
        let index = option.index(with: model)
        nameViews.forEach { $0.lineColor = nil }
        nameViews[index].lineColor = editingLineColor
    }
    
    var editingLineColor: Color {
        return option.cationModels.contains(model) ? .warning : .content
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
        return option.model(at: minI) ?? model
    }
}
extension EnumView: BasicPointMovable {
    func didChangeFromMovePoint(_ phase: Phase, beganModel: Model) {
        notifications.forEach {
            $0(self, .didChangeFromPhase(phase, beginModel: beganModel))
        }
    }
}
