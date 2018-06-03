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

extension Bool: Referenceable {
    static let name = Text(english: "Bool", japanese: "ブール値")
}
extension Bool: AnyInitializable {
    init?(anyValue: Any) {
        switch anyValue {
        case let value as Bool: self = value
        case let value as Int: self = value > 0
        case let value as Real: self = value > 0
        case let value as String:
            if let model = Bool(value) {
                self = model
            } else {
                return nil
            }
        default: return nil
        }
    }
}
extension Bool: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return (self ? "true" : "false").thumbnailView(withFrame: frame, sizeType)
    }
}
extension Bool: AbstractViewable {
    func abstractViewWith<T>(binder: T, keyPath: ReferenceWritableKeyPath<T, Bool>,
                             frame: Rect, _ sizeType: SizeType,
                             type: AbstractType) -> ModelView where T : BinderProtocol {
        switch type {
        case .normal:
            return BoolView(binder: binder, keyPath: keyPath, option: BoolOption(),
                            frame: frame, sizeType: sizeType)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath, frame: frame, sizeType)
        }
    }
}
extension Bool: ObjectViewable {}

struct BoolOption {
    struct Info {
        var trueName = Text(english: "True", japanese: "真")
        var falseName = Text(english: "False", japanese: "偽")
        
        static let hidden = Info(trueName: Text(english: "Hidden", japanese: "隠し済み"),
                                 falseName: Text(english: "Shown", japanese: "表示済み"))
        static let locked = Info(trueName: Text(english: "Locked", japanese: "ロック済み"),
                                 falseName: Text(english: "Unlocked", japanese: "未ロック"))
    }
    
    var defaultModel = false
    var cationModel: Bool?
    var name = Text()
    var info = Info()
}

final class BoolView<Binder: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = Bool
    typealias ModelOption = BoolOption
    typealias BinderKeyPath = ReferenceWritableKeyPath<Binder, Model>
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((BoolView<Binder>, BasicPhaseNotification<Model>) -> ())]()
    
    var option: ModelOption {
        didSet {
            optionStringView.text = option.name
            optionTrueNameView.text = option.info.trueName
            optionFalseNameView.text = option.info.falseName
            updateWithModel()
        }
    }
    var defaultModel: Bool {
        return option.defaultModel
    }
    
    var sizeType: SizeType {
        didSet { updateLayout() }
    }
    let optionStringView: TextFormView
    let optionTrueNameView: TextFormView
    let optionFalseNameView: TextFormView
    let knobView: View
    
    init(binder: Binder, keyPath: BinderKeyPath, option: ModelOption = ModelOption(),
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        self.option = option
        
        self.sizeType = sizeType
        let font = Font.default(with: sizeType)
        optionStringView = TextFormView(text: option.name.isEmpty ? "" : option.name + ":",
                                        font: font)
        optionTrueNameView = TextFormView(text: option.info.trueName, font: font)
        optionFalseNameView = TextFormView(text: option.info.falseName, font: font)
        optionFalseNameView.fillColor = nil
        optionTrueNameView.fillColor = nil
        knobView = View.discreteKnob()
        
        super.init()
        children = [optionStringView, knobView, optionTrueNameView, optionFalseNameView]
        self.frame = frame
        updateWithModel()
    }
    
    override var defaultBounds: Rect {
        let padding = Layouter.padding(with: sizeType)
        if optionStringView.text.isEmpty {
            let width = optionFalseNameView.frame.width
                + optionTrueNameView.frame.width + padding * 3
            let height = optionFalseNameView.frame.height + padding * 2
            return Rect(x: 0, y: 0, width: width, height: height)
        } else {
            let width = optionStringView.frame.width
                + optionFalseNameView.frame.width + optionTrueNameView.frame.width + padding * 4
            let height = optionStringView.frame.height + padding * 2
            return Rect(x: 0, y: 0, width: width, height: height)
        }
    }
    override func updateLayout() {
        let padding = Layouter.padding(with: sizeType)
        optionStringView.frame.origin = Point(x: padding, y: padding)
        let x = optionStringView.text.isEmpty ? padding : optionStringView.frame.maxX + padding
        optionFalseNameView.frame.origin = Point(x: x, y: padding)
        optionTrueNameView.frame.origin = Point(x: optionFalseNameView.frame.maxX + padding,
                                                y: padding)
        updateKnobLayout()
    }
    private func updateKnobLayout() {
        knobView.frame = model ?
            optionTrueNameView.frame.inset(by: -1) :
            optionFalseNameView.frame.inset(by: -1)
    }
    func updateWithModel() {
        updateKnobLayout()
        if option.cationModel != nil {
            knobView.lineColor = knobLineColor
        }
        optionFalseNameView.lineColor = model ? .subContent : nil
        optionTrueNameView.lineColor = model ? nil : .subContent
        optionFalseNameView.textMaterial.color = model ? .subLocked : .locked
        optionTrueNameView.textMaterial.color = model ? .locked : .subLocked
    }
    
    var knobLineColor: Color {
        return option.cationModel == model ? .warning : .getSetBorder
    }
    func model(at p: Point) -> Bool {
        return optionFalseNameView.frame.distance²(p) > optionTrueNameView.frame.distance²(p)
    }
}
extension BoolView: Runnable {
    func run(for p: Point, _ version: Version) {
        let model = self.model(at: p)
        push(model, to: version)
    }
}
extension BoolView: BasicSlidablePointMovable {
    func didChangeFromMovePoint(_ phase: Phase, beganModel: Model) {
        notifications.forEach { $0(self, .didChangeFromPhase(phase, beginModel: beganModel)) }
    }
}
