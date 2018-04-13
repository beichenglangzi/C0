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

import Foundation

extension Bool: Referenceable {
    static let name = Localization(english: "Bool", japanese: "ブール値")
}
extension Bool: ObjectViewExpression {
    func thumbnail(withBounds bounds: CGRect, sizeType: SizeType) -> Layer {
        return (self ? "true" : "false").view(withBounds: bounds, sizeType: sizeType)
    }
}

struct BoolInfo {
    var trueName = Localization(), falseName = Localization()
    static let `default` = BoolInfo(trueName: Localization(english: "True", japanese: "真"),
                                    falseName: Localization(english: "False", japanese: "偽"))
    static let hidden = BoolInfo(trueName: Localization(english: "Hidden", japanese: "隠し済み"),
                                 falseName: Localization(english: "Shown", japanese: "表示済み"))
    static let locked = BoolInfo(trueName: Localization(english: "Locked", japanese: "ロック済み"),
                                 falseName: Localization(english: "Unlocked", japanese: "未ロック"))
}

final class BoolView: View {
    var bool: Bool {
        didSet {
            updateWithBool()
        }
    }
    var defaultBool: Bool
    var cationBool: Bool?
    
    var sizeType: SizeType
    let parentClassTextView: TextView
    var boolInfo: BoolInfo {
        didSet {
            parentClassTrueNameView.localization = boolInfo.trueName
            parentClassFalseNameView.localization = boolInfo.falseName
        }
    }
    let parentClassTrueNameView: TextView
    let parentClassFalseNameView: TextView
    let knob: DiscreteKnob
    let lineLayer = PathLayer()
    
    init(bool: Bool = false, defaultBool: Bool = false, cationBool: Bool? = nil,
         name: Localization = Localization(), boolInfo: BoolInfo = BoolInfo(),
         sizeType: SizeType = .regular) {
        self.bool = bool
        self.defaultBool = bool
        self.cationBool = cationBool
        parentClassTextView = TextView(text: name + Localization(":"),
                                       font: Font.default(with: sizeType))
        self.boolInfo = boolInfo
        parentClassTrueNameView = TextView(text: boolInfo.trueName,
                                           font: Font.default(with: sizeType))
        parentClassFalseNameView = TextView(text: boolInfo.falseName,
                                            font: Font.default(with: sizeType))
        knob = DiscreteKnob()
        self.sizeType = sizeType
        lineLayer.lineColor = .content
        lineLayer.lineWidth = 1
        
        super.init()
        replace(children: [parentClassTextView, lineLayer, knob,
                           parentClassTrueNameView, parentClassFalseNameView])
        updateLayout()
    }
    
    override var defaultBounds: CGRect {
        let padding = Layout.padding(with: sizeType)
        return CGRect(x: 0, y: 0,
                      width: parentClassTextView.frame.width + parentClassFalseNameView.frame.width + parentClassTrueNameView.frame.width + padding * 3 + 1 * 4,
                      height: parentClassTextView.frame.height + padding * 2)
    }
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    func updateLayout() {
        let padding = Layout.padding(with: sizeType)
        parentClassTextView.frame.origin = CGPoint(x: padding, y: padding)
        parentClassFalseNameView.frame.origin = CGPoint(x: parentClassTextView.frame.maxX + padding + 1, y: padding)
        parentClassTrueNameView.frame.origin = CGPoint(x: parentClassFalseNameView.frame.maxX + 2,
                                                       y: padding)
        let path = CGMutablePath()
        path.addRect(parentClassFalseNameView.frame.inset(by: -0.5))
        path.addRect(parentClassTrueNameView.frame.inset(by: -0.5))
        lineLayer.path = path
        updateWithBool()
    }
    func updateWithBool() {
        knob.frame = !bool ?
            parentClassFalseNameView.frame.inset(by: -1) :
            parentClassTrueNameView.frame.inset(by: -1)
        if let cationBool = cationBool {
            parentClassTextView.textFrame.color = cationBool == bool ? .warning : .locked
        }
        parentClassFalseNameView.fillColor = !bool ? .knob : .background
        parentClassTrueNameView.fillColor = bool ? .knob : .background
    }
    
    func bool(at p: CGPoint) -> Bool {
        return !parentClassFalseNameView.frame.contains(p)
    }
    
    var disabledRegisterUndo = false
    
    struct Binding {
        let view: BoolView
        let bool: Bool, oldBool: Bool, type: Action.SendType
    }
    var binding: ((Binding) -> ())?
    
    func delete(with event: KeyInputEvent) -> Bool {
        let bool = defaultBool
        if bool != self.bool {
            push(bool, old: self.bool)
        }
        return true
    }
    func copiedObjects(with event: KeyInputEvent) -> [ViewExpression]? {
        return [bool]
    }
    func paste(_ objects: [Any], with event: KeyInputEvent) -> Bool {
        for object in objects {
            if let string = object as? String {
                if let bool = Bool(string) {
                    if bool != self.bool {
                        push(bool, old: self.bool)
                        return true
                    }
                }
            }
        }
        return false
    }
    
    func run(with event: ClickEvent) -> Bool {
        let p = point(from: event)
        let bool = self.bool(at: p)
        if bool != self.bool {
            push(bool, old: self.bool)
        }
        return true
    }
    
    private var oldBool = false, oldPoint = CGPoint()
    func move(with event: DragEvent) -> Bool {
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            knob.fillColor = .editing
            oldBool = bool
            oldPoint = p
            binding?(Binding(view: self, bool: bool, oldBool: oldBool, type: .begin))
            bool = self.bool(at: p)
            binding?(Binding(view: self, bool: bool, oldBool: oldBool, type: .sending))
        case .sending:
            bool = self.bool(at: p)
            binding?(Binding(view: self, bool: bool, oldBool: oldBool, type: .sending))
        case .end:
            bool = self.bool(at: p)
            if bool != oldBool {
                registeringUndoManager?.registerUndo(withTarget: self) { [bool, oldBool] in
                    $0.push(oldBool, old: bool)
                }
            }
            binding?(Binding(view: self, bool: bool, oldBool: oldBool, type: .end))
            knob.fillColor = .knob
        }
        return true
    }
    
    private func push(_ bool: Bool, old oldBool: Bool) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.push(oldBool, old: bool) }
        binding?(Binding(view: self, bool: oldBool, oldBool: oldBool, type: .begin))
        self.bool = bool
        binding?(Binding(view: self, bool: bool, oldBool: oldBool, type: .end))
    }
    
    func reference(with event: TapEvent) -> Reference? {
        return bool.reference
    }
}
