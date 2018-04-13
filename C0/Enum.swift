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

import Foundation

typealias EnumType = RawRepresentable & Referenceable & ViewExpression & Equatable

final class EnumView<T: EnumType>: View {
    var enumeratedType: T {
        didSet {
            index = indexClosure(enumeratedType.rawValue)
        }
    }
    private(set) var index = 0 {
        didSet {
            if index != oldValue {
                updateWithEnumeratedType()
                updateLayout()
            }
        }
    }
    var defaultEnumeratedType: T
    var cationEnumeratedType: T? {
        didSet {
            if let cationEnumeratedType = cationEnumeratedType {
                cationIndex = indexClosure(cationEnumeratedType.rawValue)
            } else {
                cationIndex = nil
            }
        }
    }
    private var cationIndex: Int?
    
    var indexClosure: ((T.RawValue) -> (Int))
    var rawValueClosure: ((Int) -> (T.RawValue?))
    
    var sizeType: SizeType
    
    let classNameView: TextView
    let knob: DiscreteKnob
    private let lineLayer: PathLayer = {
        let lineLayer = PathLayer()
        lineLayer.fillColor = .content
        return lineLayer
    } ()
    var nameViews: [TextView]
    
    init(enumeratedType: T, defaultEnumeratedType: T? = nil,
         cationEnumeratedType: T? = nil,
         indexClosure: @escaping ((T.RawValue) -> (Int)) = { $0 as? Int ?? 0 },
         rawValueClosure: @escaping ((Int) -> (T.RawValue?)) = { $0 as? T.RawValue },
         frame: CGRect = CGRect(),
         names: [Localization] = [], sizeType: SizeType = .regular) {
        
        classNameView = TextView(text: T.uninheritanceName, font: Font.bold(with: sizeType))
        self.enumeratedType = enumeratedType
        self.defaultEnumeratedType = defaultEnumeratedType ?? enumeratedType
        self.cationEnumeratedType = cationEnumeratedType
        self.indexClosure = indexClosure
        self.rawValueClosure = rawValueClosure
        index = indexClosure(enumeratedType.rawValue)
        if let cationEnumeratedType = cationEnumeratedType {
            cationIndex = indexClosure(cationEnumeratedType.rawValue)
        }
        
        nameViews = names.map { TextView(text: $0, font: Font.default(with: sizeType)) }
        self.knob = sizeType == .small ?
            DiscreteKnob(CGSize(square: 6), lineWidth: 1) :
            DiscreteKnob(CGSize(square: 8), lineWidth: 1)
        self.sizeType = sizeType
        
        super.init()
        self.frame = frame
        replace(children: [classNameView, lineLayer, knob] + nameViews)
        updateLayout()
        updateWithEnumeratedType()
    }
    
    override var locale: Locale {
        didSet {
            updateLayout()
        }
    }
    
    override var defaultBounds: CGRect {
        let padding = Layout.padding(with: sizeType), height = Layout.height(with: sizeType)
        let nw = nameViews.reduce(0.0.cf) { $0 + $1.frame.width }
        return CGRect(x: 0, y: 0, width: classNameView.frame.width + nw + padding * 2, height: height)
    }
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    private func updateLayout() {
        let padding = Layout.padding(with: sizeType)
        classNameView.frame.origin = CGPoint(x: padding,
                                             y: bounds.height - classNameView.frame.height - padding)
        let path = CGMutablePath()
        _ = nameViews.reduce(classNameView.frame.maxX + padding) {
            $1.frame.origin = CGPoint(x: $0, y: padding)
            path.addRect($1.frame)
            return $0 + $1.frame.width
        }
        lineLayer.path = path
        
        knob.frame = nameViews[index].frame.inset(by: -0.5)
    }
    private func updateWithEnumeratedType() {
        knob.frame = nameViews[index].frame.inset(by: -0.5)
        nameViews.forEach { $0.fillColor = .background }
        nameViews[index].fillColor = .knob
    }
    
    func enumeratedType(at index: Int) -> T {
        if let rawValue = rawValueClosure(index) {
            return T(rawValue: rawValue) ?? defaultEnumeratedType
        } else {
            return defaultEnumeratedType
        }
    }
    func enumeratedType(at p: CGPoint) -> T {
        for (i, view) in nameViews.enumerated() {
            if view.frame.contains(p) {
                return enumeratedType(at: i)
            }
        }
        return defaultEnumeratedType
    }
    
    struct Binding {
        let view: EnumView, enumeratedType: T, oldEnumeratedType: T, type: Action.SendType
    }
    var binding: ((Binding) -> ())?
    
    var disabledRegisterUndo = false
    
    func delete(with event: KeyInputEvent) -> Bool {
        let enumeratedType = defaultEnumeratedType
        if enumeratedType != self.enumeratedType {
            push(enumeratedType, old: self.enumeratedType)
        }
        return true
    }
    func copiedObjects(with event: KeyInputEvent) -> [ViewExpression]? {
        return [enumeratedType]
    }
    func paste(_ objects: [Any], with event: KeyInputEvent) -> Bool {
        for object in objects {
            if let enumeratedType = object as? T {
                if enumeratedType != self.enumeratedType {
                    push(enumeratedType, old: self.enumeratedType)
                    return true
                }
            } else if let string = object as? String, let index = Int(string) {
                let enumeratedType = self.enumeratedType(at: index)
                if enumeratedType != self.enumeratedType {
                    push(enumeratedType, old: self.enumeratedType)
                    return true
                }
            }
        }
        return false
    }
    func push(_ enumeratedType: T, old oldEnumeratedType: T) {
        registeringUndoManager?.registerUndo(withTarget: self) {
            $0.push(oldEnumeratedType, old: enumeratedType)
        }
        binding?(Binding(view: self, enumeratedType: oldEnumeratedType,
                         oldEnumeratedType: oldEnumeratedType, type: .begin))
        self.enumeratedType = enumeratedType
        binding?(Binding(view: self, enumeratedType: enumeratedType,
                         oldEnumeratedType: oldEnumeratedType, type: .end))
    }
    
    func run(with event: ClickEvent) -> Bool {
        let p = point(from: event)
        let enumeratedType = self.enumeratedType(at: p)
        if enumeratedType != self.enumeratedType {
            push(enumeratedType, old: self.enumeratedType)
        }
        return true
    }
    
    private var oldEnumeratedType: T?, oldPoint = CGPoint()
    func move(with event: DragEvent) -> Bool {
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            knob.fillColor = .editing
            let oldEnumeratedType = enumeratedType
            self.oldEnumeratedType = oldEnumeratedType
            oldPoint = p
            binding?(Binding(view: self, enumeratedType: enumeratedType,
                             oldEnumeratedType: oldEnumeratedType, type: .begin))
            enumeratedType = self.enumeratedType(at: p)
            binding?(Binding(view: self, enumeratedType: enumeratedType,
                             oldEnumeratedType: oldEnumeratedType, type: .sending))
        case .sending:
            guard let oldEnumeratedType = oldEnumeratedType else {
                return true
            }
            enumeratedType = self.enumeratedType(at: p)
            binding?(Binding(view: self, enumeratedType: enumeratedType,
                             oldEnumeratedType: oldEnumeratedType, type: .sending))
        case .end:
            guard let oldEnumeratedType = oldEnumeratedType else {
                return true
            }
            enumeratedType = self.enumeratedType(at: p)
            if enumeratedType != oldEnumeratedType {
                registeringUndoManager?.registerUndo(withTarget: self) {
                    [enumeratedType, oldEnumeratedType] in
                    
                    $0.push(oldEnumeratedType, old: enumeratedType)
                }
            }
            binding?(Binding(view: self, enumeratedType: enumeratedType,
                             oldEnumeratedType: oldEnumeratedType, type: .end))
            knob.fillColor = .knob
        }
        return true
    }
    
    func reference(with event: TapEvent) -> Reference? {
        return enumeratedType.reference
    }
}
