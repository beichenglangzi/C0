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
    static let name = Localization(english: "Bool", japanese: "真理値")
}

final class BoolView: View {
    var bool: Bool {
        didSet {
            updateWithBool()
        }
    }
    var defaultBool: Bool
    var cationBool: Bool?
    
    var isSmall: Bool
    let nameLabel: Label
    let knob: DiscreteKnob
    
    init(bool: Bool = false, defaultBool: Bool = false, cationBool: Bool? = nil,
         name: Localization = Localization(), isSmall: Bool = false) {
        self.bool = bool
        self.defaultBool = bool
        self.cationBool = cationBool
        nameLabel = Label(text: name, font: isSmall ? .small : .default)
        knob = DiscreteKnob()
        self.isSmall = isSmall
        
        super.init()
        replace(children: [nameLabel, knob])
        updateLayout()
    }
    
    override var defaultBounds: CGRect {
        let padding = isSmall ? Layout.smallPadding : Layout.basicPadding
        return CGRect(x: 0, y: 0,
                      width: nameLabel.frame.width + padding * 2,
                      height: nameLabel.frame.height + padding * 2)
    }
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    func updateLayout() {
        let padding = isSmall ? Layout.smallPadding : Layout.basicPadding
        nameLabel.frame.origin = CGPoint(x: padding, y: padding)
        updateWithBool()
    }
    func updateWithBool() {
        knob.position = !bool ?
            CGPoint(x: (bounds.minX + bounds.midX) / 2, y: 3) :
            CGPoint(x: (bounds.midX + bounds.maxX) / 2, y: 3)
        if let cationBool = cationBool {
            nameLabel.textFrame.color = cationBool == bool ? .warning : .locked
        }
    }
    
    func bool(at p: CGPoint) -> Bool {
        return p.x > bounds.midX
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
            set(bool, old: self.bool)
        }
        return true
    }
    func copiedObjects(with event: KeyInputEvent) -> [Any]? {
        return [bool]
    }
    func paste(_ objects: [Any], with event: KeyInputEvent) -> Bool {
        for object in objects {
            if let string = object as? String {
                if let bool = Bool(string) {
                    if bool != self.bool {
                        set(bool, old: self.bool)
                        break
                    }
                }
            }
        }
        return true
    }
    
    func run(with event: ClickEvent) -> Bool {
        let p = point(from: event)
        let bool = self.bool(at: p)
        if bool != self.bool {
            set(bool, old: self.bool)
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
                    $0.set(oldBool, old: bool)
                }
            }
            binding?(Binding(view: self, bool: bool, oldBool: oldBool, type: .end))
            knob.fillColor = .knob
        }
        return true
    }
    
    private func set(_ bool: Bool, old oldBool: Bool) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldBool, old: bool) }
        binding?(Binding(view: self, bool: oldBool, oldBool: oldBool, type: .begin))
        self.bool = bool
        binding?(Binding(view: self, bool: bool, oldBool: oldBool, type: .end))
    }
    
    func lookUp(with event: TapEvent) -> Reference? {
        return bool.reference
    }
}
