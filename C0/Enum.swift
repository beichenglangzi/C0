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

typealias EnumType = RawRepresentable & Codable & Referenceable & Equatable

struct EnumOption<Model: EnumType> {
    var defaultModel: Model
    var cationModels: [Model]
    let indexClosure: ((Model.RawValue) -> (Int))
    let rawValueClosure: ((Int) -> (Model.RawValue?))
    let names: [Text]
    
    func model(with object: Any) -> Model? {
        if let model = object as? Model {
            return model
        } else if let string = object as? String, let index = Int(string) {
            return model(at: index)
        } else {
            return nil
        }
    }
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

final class EnumView<T: EnumType, U: BinderProtocol>: View, BindableReceiver {
    typealias Model = T
    typealias ModelOption = EnumOption<Model>
    typealias Binder = U
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((EnumView<Model, Binder>) -> ())]()
    
    var option: ModelOption {
        didSet { updateWithModel() }
    }
    
    var sizeType: SizeType {
        didSet { updateLayout() }
    }
    let classNameView: TextFormView
    let nameViews: [TextFormView]
    let knobView: View
    
    init(binder: Binder, keyPath: BinderKeyPath, option: ModelOption,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        self.option = option
        
        self.sizeType = sizeType
        classNameView = TextFormView(text: Model.uninheritanceName, font: Font.bold(with: sizeType))
        nameViews = option.names.map { TextFormView(text: $0, font: Font.default(with: sizeType)) }
        knobView = sizeType == .small ?
            View.discreteKnob(Size(square: 6), lineWidth: 1) :
            View.discreteKnob(Size(square: 8), lineWidth: 1)
        
        super.init()
        children = [classNameView, knobView] + nameViews
        self.frame = frame
    }
    
    override var defaultBounds: Rect {
        let padding = Layout.padding(with: sizeType), height = Layout.height(with: sizeType)
        let np = Real(nameViews.count - 1) * padding
        let nw = nameViews.reduce(0.0.cg) { $0 + $1.frame.width } + np
        return Rect(x: 0, y: 0, width: classNameView.frame.width + nw + padding * 2, height: height)
    }
    override func updateLayout() {
        let padding = Layout.padding(with: sizeType)
        classNameView.frame.origin = Point(x: padding,
                                           y: bounds.height - classNameView.frame.height - padding)
        
        let h = Layout.height(with: sizeType) - padding * 2
        var y = bounds.height - padding - h
        _ = nameViews.reduce(classNameView.frame.maxX + padding) {
            let x: Real
            if $0 + $1.frame.width + padding > bounds.width {
                x = padding
                y -= h + padding
            } else {
                x = $0
            }
            $1.frame.origin = Point(x: x, y: y)
            return x + $1.frame.width + padding
        }
        
        updateWithModel()
    }
    func updateWithModel() {
        let index = option.index(with: model)
        knobView.frame = nameViews[index].frame.inset(by: -1)
        nameViews.forEach {
            $0.fillColor = .background
            $0.lineColor = .subContent
        }
        if !option.cationModels.isEmpty {
            knobView.lineColor = knobLineColor
        }
        nameViews[index].fillColor = .knob
        nameViews[index].lineColor = .knob
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
extension EnumView: Localizable {
    func update(with locale: Locale) {
        updateLayout()
    }
}
extension EnumView: Queryable {
    static var referenceableType: Referenceable.Type {
        return Model.self
    }
}
extension EnumView: Assignable {
    func reset(for p: Point, _ version: Version) {
        push(option.defaultModel, to:  version)
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
extension EnumView: Runnable {
    func run(for p: Point, _ version: Version) {
        push(model(at: p), to: version)
    }
}
extension EnumView: PointMovable {
    func captureWillMovePoint(at p: Point, to version: Version) {
        capture(model, to: version)
    }
    func movePoint(for p: Point, first fp: Point, pressure: Real, time: Second, _ phase: Phase) {
        switch phase {
        case .began: knobView.fillColor = .editing
        case .changed: break
        case .ended: knobView.fillColor = knobLineColor
        }
        model = self.model(at: p)
    }
}
