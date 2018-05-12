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
extension Bool: Thumbnailable {
    func thumbnail(withBounds bounds: Rect, _ sizeType: SizeType) -> View {
        return (self ? "true" : "false").view(withBounds: bounds, sizeType)
    }
}
extension Bool: CompactViewable {}

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

final class BoolView<T: BinderProtocol>: View, BindableReceiver {
    typealias Model = Bool
    typealias ModelOption = BoolOption
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    
    var option: ModelOption {
        didSet {
            parentTextView.model = option.name
            parentTrueNameView.model = option.info.trueName
            parentFalseNameView.model = option.info.falseName
            updateWithModel()
        }
    }
    
    var sizeType: SizeType {
        didSet { updateLayout() }
    }
    let parentTextView: TextFormView
    let parentTrueNameView: TextFormView
    let parentFalseNameView: TextFormView
    let knobView: View
    
    init(binder: Binder, keyPath: BinderKeyPath, option: ModelOption = ModelOption(),
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        self.option = option
        
        self.sizeType = sizeType
        let font = Font.default(with: sizeType)
        parentTextView = TextFormView(text: option.name.isEmpty ? "" : option.name + ":", font: font)
        parentTrueNameView = TextFormView(text: option.info.trueName, font: font)
        parentFalseNameView = TextFormView(text: option.info.falseName, font: font)
        knobView = View.discreteKnob()
        
        super.init()
        isLiteral = true
        children = [parentTextView, knobView, parentTrueNameView, parentFalseNameView]
        self.frame = frame
    }
    
    override var defaultBounds: Rect {
        let padding = Layout.padding(with: sizeType)
        let width = parentTextView.frame.width
            + parentFalseNameView.frame.width + parentTrueNameView.frame.width + padding * 4
        return Rect(x: 0, y: 0,
                    width: width, height: parentTextView.frame.height + padding * 2)
    }
    override func updateLayout() {
        let padding = Layout.padding(with: sizeType)
        parentTextView.frame.origin = Point(x: padding, y: padding)
        parentFalseNameView.frame.origin = Point(x: parentTextView.frame.maxX + padding, y: padding)
        parentTrueNameView.frame.origin = Point(x: parentFalseNameView.frame.maxX + padding,
                                                y: padding)
        updateWithModel()
    }
    func updateWithModel() {
        knobView.frame = model ?
            parentTrueNameView.frame.inset(by: -1) :
            parentFalseNameView.frame.inset(by: -1)
        if option.cationModel != nil {
            knobView.lineColor = knobLineColor
        }
        parentFalseNameView.fillColor = model ? .background : .knob
        parentTrueNameView.fillColor = model ? .knob : .background
        parentFalseNameView.lineColor = model ? .subContent : .knob
        parentTrueNameView.lineColor = model ? .knob : .subContent
        parentFalseNameView.textFrame.color = model ? .subLocked : .locked
        parentTrueNameView.textFrame.color = model ? .locked : .subLocked
    }
    
    var knobLineColor: Color {
        return option.cationModel == model ? .warning : .getSetBorder
    }
    func model(at p: Point) -> Bool {
        return parentFalseNameView.frame.distance²(p) > parentTrueNameView.frame.distance²(p)
    }
}
extension BoolView: Queryable {
    static var referenceableType: Referenceable.Type {
        return Model.self
    }
}
extension BoolView: Assignable {
    func delete(for p: Point) {
        let model = option.defaultModel
        push(model)
    }
    func copiedViewables(at p: Point) -> [Viewable] {
        return [model]
    }
    func paste(_ objects: [Any], for p: Point) {
        for object in objects {
            if let model = object as? Model {
                push(model)
                return
            } else if let string = object as? String, let model = Model(string) {
                push(model)
                return
            }
        }
    }
}
extension BoolView: Runnable {
    func run(for p: Point) {
        let model = self.model(at: p)
        push(model)
    }
}
extension BoolView: PointMovable {
    func movePoint(for p: Point, first fp: Point, pressure: Real, time: Second, _ phase: Phase) {
        switch phase {
        case .began:
            capture(model)
            knobView.fillColor = .editing
            model = self.model(at: p)
        case .changed:
            model = self.model(at: p)
        case .ended:
            model = self.model(at: p)
            knobView.fillColor = knobLineColor
        }
    }
}
