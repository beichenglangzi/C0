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
    var width = 0.0, height = 0.0
    
    var isEmpty: Bool {
        return width == 0 && height == 0
    }
    
    static func *(lhs: _Size, rhs: Double) -> _Size {
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
        let width = try container.decode(Double.self)
        let height = try container.decode(Double.self)
        self.init(width: width, height: height)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(width)
        try container.encode(height)
    }
}
extension _Size: Referenceable {
    static let name = Localization(english: "Size", japanese: "サイズ")
}

typealias Size = CGSize
extension CGSize {
    init(square: CGFloat) {
        self.init(width: square, height: square)
    }
    init(_ string: String) {
        self = NSSizeToCGSize(NSSizeFromString(string))
    }
    
    static func *(lhs: CGSize, rhs: CGFloat) -> CGSize {
        return CGSize(width: lhs.width * rhs, height: lhs.height * rhs)
    }
    
    var string: String {
        return String(NSStringFromSize(NSSizeFromCGSize(self)))
    }
    
    static let effectiveFieldSizeOfView = CGSize(width: tan(.pi * (30.0 / 2) / 180),
                                                 height: tan(.pi * (20.0 / 2) / 180))
    
}
extension CGSize: Referenceable {
    static let name = Localization(english: "Size", japanese: "サイズ")
}
extension CGSize: ObjectViewExpression {
    func thumbnail(withBounds bounds: CGRect, _ sizeType: SizeType) -> View {
        return string.view(withBounds: bounds, sizeType)
    }
}

final class DiscreteSizeView: View, Assignable {
    var size = CGSize() {
        didSet {
            if size != oldValue {
                widthView.model = size.width
                heightView.model = size.height
            }
        }
    }
    var defaultSize = CGSize()
    
    var sizeType: SizeType
    let classWidthNameView: TextView
    let widthView: DiscreteRealNumberView
    let classHeightNameView: TextView
    let heightView: DiscreteRealNumberView
    init(size: CGSize = CGSize(), defaultSize: CGSize = CGSize(),
         minSize: CGSize = CGSize(width: 0, height: 0),
         maxSize: CGSize = CGSize(width: 10000, height: 10000),
         widthEXP: RealNumber = 1, heightEXP: RealNumber = 1,
         widthInterval: RealNumber = 1, widthNumberOfDigits: Int = 0, widthUnit: String = "",
         heightInterval: RealNumber = 1, heightNumberOfDigits: Int = 0, heightUnit: String = "",
         frame: CGRect = CGRect(),
         sizeType: SizeType) {
        
        self.sizeType = sizeType
        
        classWidthNameView = TextView(text: Localization("w:"), font: Font.default(with: sizeType))
        classHeightNameView = TextView(text: Localization("h:"), font: Font.default(with: sizeType))
        
        widthView = DiscreteRealNumberView(model: size.width,
                                       option: RealNumberOption(defaultModel: defaultSize.width,
                                                                minModel: minSize.width,
                                                                maxModel: maxSize.width,
                                                                modelInterval: widthInterval,
                                                                exp: widthEXP,
                                                                numberOfDigits: widthNumberOfDigits,
                                                                unit: widthUnit),
                                       frame: Layout.valueFrame(with: sizeType),
                                       sizeType: sizeType)
        heightView = DiscreteRealNumberView(model: size.height,
                                       option: RealNumberOption(defaultModel: defaultSize.height,
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
    
    override var defaultBounds: CGRect {
        let padding = Layout.padding(with: sizeType), height = Layout.height(with: sizeType)
        return CGRect(x: 0, y: 0,
                      width: classWidthNameView.frame.width + widthView.frame.width + classHeightNameView.frame.width + heightView.frame.width + padding * 3,
                      height: height + padding * 2)
    }
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    func updateLayout() {
        let padding = Layout.padding(with: sizeType)
        var x = padding
        classWidthNameView.frame.origin = CGPoint(x: x, y: padding * 2)
        x += classWidthNameView.frame.width
        widthView.frame.origin = CGPoint(x: x, y: padding)
        x += widthView.frame.width + padding
        classHeightNameView.frame.origin = CGPoint(x: x, y: padding * 2)
        x += classHeightNameView.frame.width
        heightView.frame.origin = CGPoint(x: x, y: padding)
        x += heightView.frame.width + padding
    }
    
    struct Binding {
        let view: DiscreteSizeView
        let size: CGSize, oldSize: CGSize, phase: Phase
    }
    var binding: ((Binding) -> ())?
    
    var disabledRegisterUndo = false
    
    private var oldSize = CGSize()
    private func setSize(with obj: DiscreteRealNumberView.Binding<RealNumber>) {
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
    
    func delete(for p: CGPoint) {
        let size = defaultSize
        if size != self.size {
            push(size, old: self.size)
        }
    }
    func copiedViewables(at p: CGPoint) -> [Viewable] {
        return [size]
    }
    func paste(_ objects: [Any], for p: CGPoint) {
        for object in objects {
            if let size = object as? CGSize {
                if size != self.size {
                    push(size, old: self.size)
                    return
                }
            } else if let string = object as? String {
                let size = CGSize(string)
                if size != self.size {
                    push(size, old: self.size)
                    return
                }
            }
        }
    }
    
    func push(_ size: CGSize, old oldSize: CGSize) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.push(oldSize, old: size) }
        binding?(Binding(view: self, size: size, oldSize: oldSize, phase: .began))
        self.size = size
        binding?(Binding(view: self, size: size, oldSize: oldSize, phase: .ended))
    }
    
    func reference(at p: CGPoint) -> Reference {
        return _Size.reference
    }
}
