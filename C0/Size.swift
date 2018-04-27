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

/**
 Issue: Core Graphicsとの置き換え
 */
struct _Size: Equatable {
    var width = 0.0.cg, height = 0.0.cg
    
    var isEmpty: Bool {
        return width == 0 && height == 0
    }
    
    static func *(lhs: _Size, rhs: Real) -> _Size {
        return _Size(width: lhs.width * rhs, height: lhs.height * rhs)
    }
}
extension _Size: Hashable {
    var hashValue: Int {
        return Hash.uniformityHashValue(with: [width.hashValue, height.hashValue])
    }
}
extension _Size: Codable {
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let width = try container.decode(Real.self)
        let height = try container.decode(Real.self)
        self.init(width: width, height: height)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(width)
        try container.encode(height)
    }
}
extension _Size: Referenceable {
    static let name = Text(english: "Size", japanese: "サイズ")
}

typealias Size = CGSize
extension Size {
    init(square: Real) {
        self.init(width: square, height: square)
    }
//    init(_ string: String) {
//        self = NSSizeToCGSize(NSSizeFromString(string))
//    }
    
    static func *(lhs: Size, rhs: Real) -> Size {
        return Size(width: lhs.width * rhs, height: lhs.height * rhs)
    }
    
//    var string: String {
//        return String(NSStringFromSize(NSSizeFromCGSize(self)))
//    }
    
    static let effectiveFieldSizeOfView = Size(width: tan(.pi * (30.0 / 2) / 180),
                                                 height: tan(.pi * (20.0 / 2) / 180))
    
}
extension Size: Referenceable {
    static let name = Text(english: "Size", japanese: "サイズ")
}
extension Size: ObjectViewExpression {
    func thumbnail(withBounds bounds: Rect, _ sizeType: SizeType) -> View {
        return (jsonString ?? "").view(withBounds: bounds, sizeType)
    }
}

final class DiscreteSizeView: View, Queryable, Assignable {
    var size = Size() {
        didSet {
            if size != oldValue {
                widthView.model = size.width
                heightView.model = size.height
            }
        }
    }
    var defaultSize = Size()
    
    var sizeType: SizeType
    let classWidthNameView: TextView
    let widthView: DiscreteRealView
    let classHeightNameView: TextView
    let heightView: DiscreteRealView
    init(size: Size = Size(), defaultSize: Size = Size(),
         minSize: Size = Size(width: 0, height: 0),
         maxSize: Size = Size(width: 10000, height: 10000),
         widthEXP: Real = 1, heightEXP: Real = 1,
         widthInterval: Real = 1, widthNumberOfDigits: Int = 0, widthUnit: String = "",
         heightInterval: Real = 1, heightNumberOfDigits: Int = 0, heightUnit: String = "",
         frame: Rect = Rect(),
         sizeType: SizeType) {
        
        self.sizeType = sizeType
        
        classWidthNameView = TextView(text: "w:", font: Font.default(with: sizeType))
        classHeightNameView = TextView(text: "h:", font: Font.default(with: sizeType))
        
        widthView = DiscreteRealView(model: size.width,
                                       option: RealOption(defaultModel: defaultSize.width,
                                                                minModel: minSize.width,
                                                                maxModel: maxSize.width,
                                                                modelInterval: widthInterval,
                                                                exp: widthEXP,
                                                                numberOfDigits: widthNumberOfDigits,
                                                                unit: widthUnit),
                                       frame: Layout.valueFrame(with: sizeType),
                                       sizeType: sizeType)
        heightView = DiscreteRealView(model: size.height,
                                       option: RealOption(defaultModel: defaultSize.height,
                                                                minModel: minSize.height,
                                                                maxModel: maxSize.height,
                                                                modelInterval: heightInterval,
                                                                exp: heightEXP,
                                                                numberOfDigits: heightNumberOfDigits,
                                                                unit: heightUnit),
                                       frame: Layout.valueFrame(with: sizeType),
                                       sizeType: sizeType)
        
        super.init()
        children = [classWidthNameView, widthView, classHeightNameView, heightView]
        widthView.binding = { [unowned self] in self.setSize(with: $0) }
        heightView.binding = { [unowned self] in self.setSize(with: $0) }
        updateLayout()
    }
    
    override var defaultBounds: Rect {
        let padding = Layout.padding(with: sizeType), height = Layout.height(with: sizeType)
        return Rect(x: 0, y: 0,
                      width: classWidthNameView.frame.width + widthView.frame.width + classHeightNameView.frame.width + heightView.frame.width + padding * 3,
                      height: height + padding * 2)
    }
    override var bounds: Rect {
        didSet {
            updateLayout()
        }
    }
    func updateLayout() {
        let padding = Layout.padding(with: sizeType)
        var x = padding
        classWidthNameView.frame.origin = Point(x: x, y: padding * 2)
        x += classWidthNameView.frame.width
        widthView.frame.origin = Point(x: x, y: padding)
        x += widthView.frame.width + padding
        classHeightNameView.frame.origin = Point(x: x, y: padding * 2)
        x += classHeightNameView.frame.width
        heightView.frame.origin = Point(x: x, y: padding)
        x += heightView.frame.width + padding
    }
    
    struct Binding {
        let view: DiscreteSizeView
        let size: Size, oldSize: Size, phase: Phase
    }
    var binding: ((Binding) -> ())?
    
    var disabledRegisterUndo = false
    
    private var oldSize = Size()
    private func setSize(with obj: DiscreteRealView.Binding<Real>) {
        if obj.phase == .began {
            oldSize = size
            binding?(Binding(view: self, size: oldSize, oldSize: oldSize, phase: .began))
        } else {
            if obj.view == widthView {
                size.width = obj.model
            } else {
                size.height = obj.model
            }
            binding?(Binding(view: self, size: size, oldSize: oldSize, phase: obj.phase))
        }
    }
    
    func delete(for p: Point) {
        let size = defaultSize
        if size != self.size {
            push(size, old: self.size)
        }
    }
    func copiedViewables(at p: Point) -> [Viewable] {
        return [size]
    }
    func paste(_ objects: [Any], for p: Point) {
        for object in objects {
            if let size = object as? Size {
                if size != self.size {
                    push(size, old: self.size)
                    return
                }
            } else if let string = object as? String, let size = Size(jsonString: string) {
                if size != self.size {
                    push(size, old: self.size)
                    return
                }
            }
        }
    }
    
    func push(_ size: Size, old oldSize: Size) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.push(oldSize, old: size) }
        binding?(Binding(view: self, size: size, oldSize: oldSize, phase: .began))
        self.size = size
        binding?(Binding(view: self, size: size, oldSize: oldSize, phase: .ended))
    }
    
    func reference(at p: Point) -> Reference {
        return Size.reference
    }
}
