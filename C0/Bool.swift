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
    static let name = Text(english: "Bool", japanese: "ブール値")
}
extension Bool: ObjectViewExpression {
    func thumbnail(withBounds bounds: Rect, _ sizeType: SizeType) -> View {
        return (self ? "true" : "false").view(withBounds: bounds, sizeType)
    }
}

struct BoolInfo {
    var trueName = Text(), falseName = Text()
    static let `default` = BoolInfo(trueName: Text(english: "True", japanese: "真"),
                                    falseName: Text(english: "False", japanese: "偽"))
    static let hidden = BoolInfo(trueName: Text(english: "Hidden", japanese: "隠し済み"),
                                 falseName: Text(english: "Shown", japanese: "表示済み"))
    static let locked = BoolInfo(trueName: Text(english: "Locked", japanese: "ロック済み"),
                                 falseName: Text(english: "Unlocked", japanese: "未ロック"))
}

final class BoolView: View, Queryable, Assignable, Runnable, Movable {
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
            parentClassTrueNameView.text = boolInfo.trueName
            parentClassFalseNameView.text = boolInfo.falseName
        }
    }
    let parentClassTrueNameView: TextView
    let parentClassFalseNameView: TextView
    let knobView: DiscreteKnobView
    let lineView = View(path: CGMutablePath())
    
    init(bool: Bool = false, defaultBool: Bool = false, cationBool: Bool? = nil,
         name: Text = "", boolInfo: BoolInfo = BoolInfo(),
         sizeType: SizeType = .regular) {
        self.bool = bool
        self.defaultBool = bool
        self.cationBool = cationBool
        parentClassTextView = TextView(text: name.isEmpty ? "" : name + ":",
                                       font: Font.default(with: sizeType))
        self.boolInfo = boolInfo
        parentClassTrueNameView = TextView(text: boolInfo.trueName,
                                           font: Font.default(with: sizeType))
        parentClassFalseNameView = TextView(text: boolInfo.falseName,
                                            font: Font.default(with: sizeType))
        knobView = DiscreteKnobView()
        self.sizeType = sizeType
        lineView.lineColor = .content
        lineView.lineWidth = 1
        
        super.init()
        isLiteral = true
        children = [parentClassTextView, lineView, knobView,
                    parentClassTrueNameView, parentClassFalseNameView]
        updateLayout()
    }
    
    override var defaultBounds: Rect {
        let padding = Layout.padding(with: sizeType)
        return Rect(x: 0, y: 0,
                      width: parentClassTextView.frame.width + parentClassFalseNameView.frame.width + parentClassTrueNameView.frame.width + padding * 4,
                      height: parentClassTextView.frame.height + padding * 2)
    }
    override var bounds: Rect {
        didSet {
            updateLayout()
        }
    }
    func updateLayout() {
        let padding = Layout.padding(with: sizeType)
        parentClassTextView.frame.origin = Point(x: padding, y: padding)
        parentClassFalseNameView.frame.origin = Point(x: parentClassTextView.frame.maxX + padding, y: padding)
        parentClassTrueNameView.frame.origin = Point(x: parentClassFalseNameView.frame.maxX + padding,
                                                       y: padding)
        updateWithBool()
    }
    func updateWithBool() {
        knobView.frame = !bool ?
            parentClassFalseNameView.frame.inset(by: -1) :
            parentClassTrueNameView.frame.inset(by: -1)
        if let cationBool = cationBool {
            knobView.lineColor = cationBool == bool ? .warning : .getSetBorder
        }
        parentClassFalseNameView.fillColor = !bool ? .knob : .background
        parentClassTrueNameView.fillColor = bool ? .knob : .background
        parentClassFalseNameView.lineColor = !bool ? .knob : .subContent
        parentClassTrueNameView.lineColor = bool ? .knob : .subContent
        parentClassFalseNameView.textFrame.color = !bool ? .locked : .subLocked
        parentClassTrueNameView.textFrame.color = bool ? .locked : .subLocked
    }
    
    func bool(at p: Point) -> Bool {
        return parentClassFalseNameView.frame.distance²(p) >
            parentClassTrueNameView.frame.distance²(p)
    }
    
    var disabledRegisterUndo = false
    
    struct Binding {
        let view: BoolView
        let bool: Bool, oldBool: Bool, phase: Phase
    }
    var binding: ((Binding) -> ())?
    
    func delete(for p: Point) {
        let bool = defaultBool
        if bool != self.bool {
            push(bool, old: self.bool)
        }
    }
    func copiedViewables(at p: Point) -> [Viewable] {
        return [bool]
    }
    func paste(_ objects: [Any], for p: Point) {
        for object in objects {
            if let string = object as? String {
                if let bool = Bool(string) {
                    if bool != self.bool {
                        push(bool, old: self.bool)
                        return
                    }
                }
            }
        }
    }
    
    func run(for p: Point) {
        let bool = self.bool(at: p)
        if bool != self.bool {
            push(bool, old: self.bool)
        }
    }
    
    private var oldBool = false, oldPoint = Point()
    func move(for p: Point, pressure: Real, time: Second, _ phase: Phase) {
        switch phase {
        case .began:
            knobView.fillColor = .editing
            oldBool = bool
            oldPoint = p
            binding?(Binding(view: self, bool: bool, oldBool: oldBool, phase: .began))
            bool = self.bool(at: p)
            binding?(Binding(view: self, bool: bool, oldBool: oldBool, phase: .changed))
        case .changed:
            bool = self.bool(at: p)
            binding?(Binding(view: self, bool: bool, oldBool: oldBool, phase: .changed))
        case .ended:
            bool = self.bool(at: p)
            if bool != oldBool {
                registeringUndoManager?.registerUndo(withTarget: self) { [bool, oldBool] in
                    $0.push(oldBool, old: bool)
                }
            }
            binding?(Binding(view: self, bool: bool, oldBool: oldBool, phase: .ended))
            knobView.fillColor = .knob
        }
    }
    
    private func push(_ bool: Bool, old oldBool: Bool) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.push(oldBool, old: bool) }
        binding?(Binding(view: self, bool: oldBool, oldBool: oldBool, phase: .began))
        self.bool = bool
        binding?(Binding(view: self, bool: bool, oldBool: oldBool, phase: .ended))
    }
    
    func reference(at p: Point) -> Reference {
        return Bool.reference
    }
}
