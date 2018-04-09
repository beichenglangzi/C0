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

//final class EnumView {
//
//}

/**
 # Issue
 - ノブの滑らかな移動
 */
final class EnumView<T: EnumType>: View {
    var enumeratedType: T {
        didSet {
            index = indexHandler(enumeratedType.rawValue)
        }
    }
    private var index = 0 {
        didSet {
            guard index != oldValue else {
                return
            }
            menu.selectedIndex = index
            if index != oldValue {
                updateLabel()
            }
        }
    }
    var defaultEnumeratedType: T
    var cationEnumeratedType: T? {
        didSet {
            if let cationEnumeratedType = cationEnumeratedType {
                cationIndex = indexHandler(cationEnumeratedType.rawValue)
            } else {
                cationIndex = nil
            }
        }
    }
    private var cationIndex: Int?

    var indexHandler: ((T.RawValue) -> (Int))
    var rawValueHandler: ((Int) -> (T.RawValue?))
    
    var sizeType: SizeType
    let classNameLabel: Label
    var knobPaddingWidth: CGFloat
    let valueLabel: Label
    let knob: DiscreteKnob
    private let lineLayer: PathLayer = {
        let lineLayer = PathLayer()
        lineLayer.fillColor = .content
        return lineLayer
    } ()
    
    init(enumeratedType: T, defaultEnumeratedType: T? = nil,
         cationEnumeratedType: T? = nil,
         indexHandler: @escaping ((T.RawValue) -> (Int)) = { $0 as? Int ?? 0 },
         rawValueHandler: @escaping ((Int) -> (T.RawValue?)) = { $0 as? T.RawValue },
         frame: CGRect = CGRect(),
         names: [Localization] = [], sizeType: SizeType = .regular) {
        
        classNameLabel = Label(text: T.uninheritanceName, font: Font.bold(with: sizeType))
        self.enumeratedType = enumeratedType
        self.defaultEnumeratedType = defaultEnumeratedType ?? enumeratedType
        self.cationEnumeratedType = cationEnumeratedType
        self.indexHandler = indexHandler
        self.rawValueHandler = rawValueHandler
        index = indexHandler(enumeratedType.rawValue)
        if let cationEnumeratedType = cationEnumeratedType {
            cationIndex = indexHandler(cationEnumeratedType.rawValue)
        }
        knobPaddingWidth = sizeType == .small ? 12.0 : 16.0
        self.menu = Menu(names: names,
                         knobPaddingX: classNameLabel.frame.maxX,
                         knobPaddingWidth: knobPaddingWidth,
                         width: frame.width, sizeType: sizeType)
        self.valueLabel = Label(font: Font.default(with: sizeType), color: .locked)
        self.knob = sizeType == .small ?
            DiscreteKnob(CGSize(square: 6), lineWidth: 1) :
            DiscreteKnob(CGSize(square: 8), lineWidth: 1)
        self.sizeType = sizeType
        super.init()
        self.frame = frame
        replace(children: [classNameLabel, valueLabel, lineLayer, knob])
        updateKnobPosition()
        updateLabel()
    }
    
    override var locale: Locale {
        didSet {
            menu.allChildrenAndSelf { $0.locale = locale }
            updateLayout()
        }
    }
    override var contentsScale: CGFloat {
        didSet {
            menu.contentsScale = contentsScale
        }
    }
    
    override var defaultBounds: CGRect {
        return valueLabel.textFrame.typographicBounds
    }
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    private func updateLayout() {
        let padding = Layout.padding(with: sizeType)
        classNameLabel.frame.origin = CGPoint(x: padding,
                                              y: bounds.height - classNameLabel.frame.height - padding)
        valueLabel.frame.origin.x = classNameLabel.frame.maxX + knobPaddingWidth
        valueLabel.frame.origin.y = round((bounds.height - valueLabel.frame.height) / 2)
        if menu.width != bounds.width {
            menu.width = bounds.width
        }
        updateKnobPosition()
    }
    private func updateKnobPosition() {
        let x = classNameLabel.frame.maxX + knobPaddingWidth / 2
        lineLayer.path = CGPath(rect: CGRect(x: x - 1, y: 0,
                                             width: 2, height: bounds.height / 2), transform: nil)
        knob.position = CGPoint(x: x, y: bounds.midY)
    }
    private var oldFontColor: Color?
    private func updateLabel() {
        valueLabel.localization = menu.names[index]
        valueLabel.frame.origin = CGPoint(x: classNameLabel.frame.maxX + knobPaddingWidth,
                                          y: round((frame.height - valueLabel.frame.height) / 2))
        if let cationIndex = cationIndex {
            if index != cationIndex {
                if let oldFontColor = oldFontColor {
                    valueLabel.textFrame.color = oldFontColor
                }
            } else {
                oldFontColor = valueLabel.textFrame.color
                valueLabel.textFrame.color = .warning
            }
        }
    }
    
    func enumeratedType(at index: Int) -> T {
        if let rawValue = rawValueHandler(index) {
            return T(rawValue: rawValue) ?? defaultEnumeratedType
        } else {
            return defaultEnumeratedType
        }
    }
    func index(withY y: CGFloat) -> Int {
        return Int(y / menu.menuHeight).clip(min: 0, max: menu.names.count - 1)
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
    
    var willOpenMenuHandler: ((EnumView) -> ())? = nil
    var menu: Menu
    private var isDrag = false, oldEnumeratedType: T?, beginPoint = CGPoint()
    func move(with event: DragEvent) -> Bool {
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            isDrag = false
            
            beginPoint = p
            let root = self.root
            if root !== self {
                willOpenMenuHandler?(self)
                valueLabel.isHidden = true
                lineLayer.isHidden = true
                knob.isHidden = true
                menu.frame.origin = root.convert(CGPoint(x: 0, y: -menu.frame.height + p.y),
                                                 from: self)
                root.append(child: menu)
            }
            
            let oldEnumeratedType = self.enumeratedType
            self.oldEnumeratedType = oldEnumeratedType
            binding?(Binding(view: self, enumeratedType: oldEnumeratedType,
                             oldEnumeratedType: oldEnumeratedType, type: .begin))
            
            let index = self.index(withY: -(p.y - beginPoint.y))
            let enumeratedType = self.enumeratedType(at: index)
            if enumeratedType != self.enumeratedType {
                self.enumeratedType = enumeratedType
                binding?(Binding(view: self, enumeratedType: enumeratedType,
                                 oldEnumeratedType: oldEnumeratedType, type: .sending))
            }
        case .sending:
            isDrag = true
            guard let oldEnumeratedType = oldEnumeratedType else {
                return true
            }
            let index = self.index(withY: -(p.y - beginPoint.y))
            let enumeratedType = self.enumeratedType(at: index)
            if enumeratedType != self.enumeratedType {
                self.enumeratedType = enumeratedType
                binding?(Binding(view: self, enumeratedType: enumeratedType,
                                 oldEnumeratedType: oldEnumeratedType, type: .sending))
            }
        case .end:
            guard let oldEnumeratedType = oldEnumeratedType else {
                return true
            }
            let index = self.index(withY: -(p.y - beginPoint.y))
            let enumeratedType = self.enumeratedType(at: index)
            guard isDrag else {
                if enumeratedType != oldEnumeratedType {
                    self.enumeratedType = enumeratedType
                }
                binding?(Binding(view: self, enumeratedType: enumeratedType,
                                 oldEnumeratedType: oldEnumeratedType, type: .end))
                valueLabel.isHidden = false
                lineLayer.isHidden = false
                knob.isHidden = false
                menu.removeFromParent()
                return true
            }
            if enumeratedType != self.enumeratedType {
                self.enumeratedType = enumeratedType
            }
            if enumeratedType != oldEnumeratedType {
                registeringUndoManager?.registerUndo(withTarget: self) {
                    [enumeratedType, oldEnumeratedType] in
                    
                    $0.push(oldEnumeratedType, old: enumeratedType)
                }
            }
            binding?(Binding(view: self, enumeratedType: enumeratedType,
                             oldEnumeratedType: oldEnumeratedType, type: .end))
            
            valueLabel.isHidden = false
            lineLayer.isHidden = false
            knob.isHidden = false
            menu.removeFromParent()
        }
        return true
    }
    
    func reference(with event: TapEvent) -> Reference? {
        var reference = enumeratedType.reference
        reference.viewDescription = Localization(english: "Select Index: Up and down drag",
                                                 japanese: "インデックスを選択: 上下ドラッグ")
        return reference
    }
}

final class Menu: View {
    var selectedIndex = 0 {
        didSet {
            guard selectedIndex != oldValue else {
                return
            }
            let selectedLabel = items[selectedIndex]
            selectedLayer.frame = selectedLabel.frame
            selectedKnob.position = CGPoint(x: Layout.padding(with: sizeType) + knobPaddingX + knobPaddingWidth / 2,
                                            y: selectedLabel.frame.midY)
        }
    }
    
    var width = 0.0.cf {
        didSet {
            updateItems()
        }
    }
    var menuHeight: CGFloat {
        didSet {
            updateItems()
        }
    }
    let knobPaddingX: CGFloat
    let knobPaddingWidth: CGFloat
    
    let selectedLayer: Layer = {
        let layer = Layer()
        layer.fillColor = .translucentEdit
        return layer
    } ()
    let lineLayer: PathLayer = {
        let lineLayer = PathLayer()
        lineLayer.fillColor = .content
        return lineLayer
    } ()
    let selectedKnob: DiscreteKnob
    
    var names = [Localization]() {
        didSet {
            updateItems()
        }
    }
    var sizeType: SizeType
    private(set) var items = [TextBox]()
    
    init(names: [Localization] = [],
         knobPaddingX: CGFloat = 0,
         knobPaddingWidth: CGFloat = 18.0.cf, width: CGFloat, sizeType: SizeType = .regular) {
        self.names = names
        self.knobPaddingX = knobPaddingX
        self.knobPaddingWidth = knobPaddingWidth
        self.width = width
        self.sizeType = sizeType
        menuHeight = Layout.height(with: sizeType)
        selectedKnob = sizeType == .small ?
            DiscreteKnob(CGSize(square: 6), lineWidth: 1) :
            DiscreteKnob(CGSize(square: 8), lineWidth: 1)
        super.init()
        fillColor = .background
        updateItems()
    }
    
    private func updateItems() {
        if names.isEmpty {
            self.frame.size = CGSize(width: 10, height: 10)
            self.items = []
            replace(children: [])
        } else {
            let padding = Layout.padding(with: sizeType)
            let x = padding + knobPaddingX + knobPaddingWidth / 2
            let h = menuHeight * names.count.cf
            var y = h
            let items: [TextBox] = names.map {
                y -= menuHeight
                return TextBox(frame: CGRect(x: 0, y: y, width: width, height: menuHeight),
                               name: $0,
                               sizeType: sizeType,
                               leftPadding: knobPaddingX + knobPaddingWidth)
            }
            let path = CGMutablePath()
            
            path.addRect(CGRect(x: x - 1, y: menuHeight / 2,
                                width: 2, height: h - menuHeight))
            items.forEach {
                path.addRect(CGRect(x: x - 2, y: $0.frame.midY - 2,
                                    width: 4, height: 4))
            }
            lineLayer.path = path
            let selectedLabel = items[selectedIndex]
            selectedLayer.frame = selectedLabel.frame
            selectedKnob.position = CGPoint(x: x, y: selectedLabel.frame.midY)
            frame.size = CGSize(width: width, height: h)
            self.items = items
            replace(children: items + [lineLayer, selectedKnob, selectedLayer])
        }
    }
    
    func reference(with event: TapEvent) -> Reference? {
        return Reference(name: Localization(english: "Menu", japanese: "メニュー"))
    }
}
