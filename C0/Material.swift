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

final class Material: NSObject, NSCoding {
    enum MaterialType: Int8, Codable {
        static let name = Localization(english: "Material Type", japanese: "マテリアルタイプ")
        case normal, lineless, blur, luster, add, subtract
        var isDrawLine: Bool {
            return self == .normal
        }
        var displayString: Localization {
            switch self {
            case .normal:
                return Localization(english: "Normal", japanese: "通常")
            case .lineless:
                return Localization(english: "Lineless", japanese: "線なし")
            case .blur:
                return Localization(english: "Blur", japanese: "ぼかし")
            case .luster:
                return Localization(english: "Luster", japanese: "光沢")
            case .add:
                return Localization(english: "Add", japanese: "加算")
            case .subtract:
                return Localization(english: "Subtract", japanese: "減算")
            }
        }
        static var displayStrings: [Localization] {
            return [normal.displayString,
                    lineless.displayString,
                    blur.displayString,
                    luster.displayString,
                    add.displayString,
                    subtract.displayString]
        }
    }
    
    let type: MaterialType
    let color: Color, lineColor: Color
    let lineWidth: CGFloat, opacity: CGFloat
    let id: UUID
    
    static let defaultLineWidth = 1.0.cf
    init(type: MaterialType = .normal,
         color: Color = Color(), lineColor: Color = .black,
         lineWidth: CGFloat = defaultLineWidth, opacity: CGFloat = 1) {
        
        self.color = color
        self.lineColor = lineColor
        self.type = type
        self.lineWidth = lineWidth
        self.opacity = opacity
        self.id = UUID()
        super.init()
    }
    
    private enum CodingKeys: String, CodingKey {
        case type, color, lineColor, lineWidth, opacity, id
    }
    init?(coder: NSCoder) {
        type = MaterialType(
            rawValue: Int8(coder.decodeInt32(forKey: CodingKeys.type.rawValue))) ?? .normal
        color = coder.decodeDecodable(Color.self, forKey: CodingKeys.color.rawValue) ?? Color()
        lineColor = coder.decodeDecodable(
            Color.self, forKey: CodingKeys.lineColor.rawValue) ?? Color()
        lineWidth = coder.decodeDouble(forKey: CodingKeys.lineWidth.rawValue).cf
        opacity = coder.decodeDouble(forKey: CodingKeys.opacity.rawValue).cf
        id = coder.decodeObject(forKey: CodingKeys.id.rawValue) as? UUID ?? UUID()
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(Int32(type.rawValue), forKey: CodingKeys.type.rawValue)
        coder.encodeEncodable(color, forKey: CodingKeys.color.rawValue)
        coder.encodeEncodable(lineColor, forKey: CodingKeys.lineColor.rawValue)
        coder.encode(lineWidth.d, forKey: CodingKeys.lineWidth.rawValue)
        coder.encode(opacity.d, forKey: CodingKeys.opacity.rawValue)
        coder.encode(id, forKey: CodingKeys.id.rawValue)
    }
    
    func with(_ type: MaterialType) -> Material {
        return Material(type: type,
                        color: color, lineColor: lineColor,
                        lineWidth: lineWidth, opacity: opacity)
    }
    func with(_ color: Color) -> Material {
        return Material(type: type,
                        color: color, lineColor: lineColor,
                        lineWidth: lineWidth, opacity: opacity)
    }
    func with(lineColor: Color) -> Material {
        return Material(type: type,
                        color: color, lineColor: lineColor,
                        lineWidth: lineWidth, opacity: opacity)
    }
    func with(lineWidth: CGFloat) -> Material {
        return Material(type: type,
                        color: color, lineColor: lineColor,
                        lineWidth: lineWidth, opacity: opacity)
    }
    func with(opacity: CGFloat) -> Material {
        return Material(type: type,
                        color: color, lineColor: lineColor,
                        lineWidth: lineWidth, opacity: opacity)
    }
    func withNewID() -> Material {
        return Material(type: type,
                        color: color, lineColor: lineColor,
                        lineWidth: lineWidth, opacity: opacity)
    }
}

extension Material: Referenceable {
    static let name = Localization(english: "Material", japanese: "マテリアル")
}
extension Material: Interpolatable {
    static func linear(_ f0: Material, _ f1: Material, t: CGFloat) -> Material {
        guard f0.id != f1.id else {
            return f0
        }
        let type = f0.type
        let color = Color.linear(f0.color, f1.color, t: t)
        let lineColor = Color.linear(f0.lineColor, f1.lineColor, t: t)
        let lineWidth = CGFloat.linear(f0.lineWidth, f1.lineWidth, t: t)
        let opacity = CGFloat.linear(f0.opacity, f1.opacity, t: t)
        return Material(type: type,
                        color: color, lineColor: lineColor,
                        lineWidth: lineWidth, opacity: opacity)
    }
    static func firstMonospline(_ f1: Material, _ f2: Material, _ f3: Material,
                                with ms: Monospline) -> Material {
        guard f1.id != f2.id else {
            return f1
        }
        let type = f1.type
        let color = Color.firstMonospline(f1.color, f2.color, f3.color, with: ms)
        let lineColor = Color.firstMonospline(f1.lineColor, f2.lineColor, f3.lineColor, with: ms)
        let lineWidth = CGFloat.firstMonospline(f1.lineWidth, f2.lineWidth, f3.lineWidth, with: ms)
        let opacity = CGFloat.firstMonospline(f1.opacity, f2.opacity, f3.opacity, with: ms)
        return Material(type: type,
                        color: color, lineColor: lineColor,
                        lineWidth: lineWidth, opacity: opacity)
    }
    static func monospline(_ f0: Material, _ f1: Material, _ f2: Material, _ f3: Material,
                           with ms: Monospline) -> Material {
        guard f1.id != f2.id else {
            return f1
        }
        let type = f1.type
        let color = Color.monospline(f0.color, f1.color, f2.color, f3.color, with: ms)
        let lineColor = Color.monospline(f0.lineColor, f1.lineColor,
                                         f2.lineColor, f3.lineColor, with: ms)
        let lineWidth = CGFloat.monospline(f0.lineWidth, f1.lineWidth,
                                           f2.lineWidth, f3.lineWidth, with: ms)
        let opacity = CGFloat.monospline(f0.opacity, f1.opacity, f2.opacity, f3.opacity, with: ms)
        return Material(type: type,
                        color: color, lineColor: lineColor,
                        lineWidth: lineWidth, opacity: opacity)
    }
    static func lastMonospline(_ f0: Material, _ f1: Material, _ f2: Material,
                              with ms: Monospline) -> Material {
        guard f1.id != f2.id else {
            return f1
        }
        let type = f1.type
        let color = Color.lastMonospline(f0.color, f1.color, f2.color, with: ms)
        let lineColor = Color.lastMonospline(f0.lineColor, f1.lineColor, f2.lineColor, with: ms)
        let lineWidth = CGFloat.lastMonospline(f0.lineWidth, f1.lineWidth, f2.lineWidth, with: ms)
        let opacity = CGFloat.lastMonospline(f0.opacity, f1.opacity, f2.opacity, with: ms)
        return Material(type: type,
                        color: color, lineColor: lineColor,
                        lineWidth: lineWidth, opacity: opacity)
    }
}
extension Material: ResponderExpression {
    func responder(withBounds bounds: CGRect) -> Responder {
        let thumbnailView = Box()
        thumbnailView.bounds = bounds
        thumbnailView.fillColor = color
        return ObjectView(object: self, thumbnailView: thumbnailView, minFrame: bounds)
    }
}

extension Material.MaterialType {
    var blendMode: CGBlendMode {
        switch self {
        case .normal, .lineless, .blur:
            return .normal
        case .luster, .add:
            return .plusLighter
        case .subtract:
            return .plusDarker
        }
    }
}

extension Slider {
    static func opacityView(isSmall: Bool = false) -> Slider {
        return Slider(value: 1, defaultValue: 1, min: 0, max: 1,
                      description: Localization(english: "Opacity", japanese: "不透明度"),
                      isSmall: isSmall)
    }
    private static func opacitySliderLayers(with bounds: CGRect,
                                            checkerWidth: CGFloat, padding: CGFloat) -> [Layer] {
        let frame = CGRect(x: padding, y: bounds.height / 2 - checkerWidth,
                           width: bounds.width - padding * 2, height: checkerWidth * 2)
        
        let backgroundLayer = GradientLayer()
        backgroundLayer.gradient = Gradient(colors: [.subContent, .content],
                                            locations: [0, 1],
                                            startPoint: CGPoint(x: 0, y: 0),
                                            endPoint: CGPoint(x: 1, y: 0))
        backgroundLayer.frame = frame
        
        let checkerboardLayer = PathLayer()
        checkerboardLayer.fillColor = .content
        checkerboardLayer.path = CGPath.checkerboard(with: CGSize(square: checkerWidth), in: frame)
        
        return [backgroundLayer, checkerboardLayer]
    }
    func updateOpacityLayers(withFrame frame: CGRect) {
        if self.frame != frame {
            self.frame = frame
            backgroundLayers = Slider.opacitySliderLayers(with: frame,
                                                          checkerWidth: knob.radius, padding: padding)
        }
    }
}
extension Slider {
    static func widthViewWith(min: CGFloat, max: CGFloat, exp: CGFloat,
                              description: Localization, isSmall: Bool = false) -> Slider {
        return Slider(min: min, max: max, exp: exp, description: description, isSmall: isSmall)
    }
    private static func widthLayer(with bounds: CGRect,
                                   halfWidth: CGFloat, padding: CGFloat) -> Layer {
        let shapeLayer = PathLayer()
        shapeLayer.fillColor = .content
        shapeLayer.path = {
            let path = CGMutablePath()
            path.addLines(between: [CGPoint(x: padding,y: bounds.height / 2),
                                    CGPoint(x: bounds.width - padding,
                                            y: bounds.height / 2 - halfWidth),
                                    CGPoint(x: bounds.width - padding,
                                            y: bounds.height / 2 + halfWidth)])
            return path
        } ()
        return shapeLayer
    }
    func updateLineWidthLayers(withFrame frame: CGRect) {
        if self.frame != frame {
            self.frame = frame
            backgroundLayers = [Slider.widthLayer(with: frame,
                                                  halfWidth: knob.radius, padding: padding)]
        }
    }
}

/**
 # Issue
 - 「線の強さ」を追加
 */
final class MaterialView: Layer, Respondable, Localizable {
    static let name = Localization(english: "Material View", japanese: "マテリアル表示")
    
    var locale = Locale.current {
        didSet {
            updateLayout()
        }
    }
    
    var material: Material {
        didSet {
            guard material.id != oldValue.id else {
                return
            }
            typeView.selectedIndex = index(with: material.type)
            colorView.color = material.color
            lineColorView.color = material.lineColor
            lineWidthView.value = material.lineWidth
            opacityView.value = material.opacity
        }
    }
    var defaultMaterial = Material()
    
    static let defaultWidth = 140.0.cf
    
    private let nameLabel = Label(text: Material.name, font: .bold)
    private let typeView = EnumView(names: Material.MaterialType.displayStrings,
                                    description: Localization(english: "Type", japanese: "タイプ"))
    private let colorView = ColorView()
    private let lineWidthView = Slider.widthViewWith(min: Material.defaultLineWidth, max: 500, exp: 3,
                                                     description: Localization(english: "Line Width",
                                                                               japanese: "線の太さ"))
    private let opacityView = Slider.opacityView()
    private let lineColorLabel = Label(text: Localization(english: "Line Color:",
                                                          japanese: "線のカラー:"))
    private let lineColorView = ColorView(hLineWidth: 2,
                                          inPadding: 4, outPadding: 4, slPadding: 4, knobRadius: 4)
    
    override init() {
        material = defaultMaterial
        super.init()
        replace(children: [nameLabel,
                           typeView,
                           colorView, lineColorLabel, lineColorView,
                           lineWidthView, opacityView])
        
        typeView.binding = { [unowned self] in self.setMaterial(with: $0) }
        
        colorView.setColorHandler = { [unowned self] in self.setMaterial(with: $0) }
        lineColorView.setColorHandler = { [unowned self] in self.setMaterial(with: $0) }
        
        lineWidthView.binding = { [unowned self] in self.setMaterial(with: $0) }
        opacityView.binding = { [unowned self] in self.setMaterial(with: $0) }
    }
    
    override var defaultBounds: CGRect {
        return CGRect(x: 0, y: 0,
                      width: MaterialView.defaultWidth,
                      height: MaterialView.defaultWidth + nameLabel.frame.height
                        + Layout.basicHeight * 4 + Layout.basicPadding * 3)
    }
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    private func updateLayout() {
        let padding = Layout.basicPadding, h = Layout.basicHeight
        let cw = bounds.width - padding * 2
        let leftWidth = cw - h * 3
        nameLabel.frame.origin = CGPoint(x: padding, y: padding * 2 + h * 4 + cw)
        typeView.frame = CGRect(x: padding, y: padding + h * 3 + cw, width: cw, height: h)
        colorView.frame = CGRect(x: padding, y: padding + h * 3, width: cw, height: cw)
        lineColorLabel.frame.origin = CGPoint(x: padding + leftWidth - lineColorLabel.frame.width,
                                              y: padding * 2)
        lineColorView.frame = CGRect(x: padding + leftWidth, y: padding, width: h * 3, height: h * 3)
        let lineWidthFrame = CGRect(x: padding, y: padding + h * 2, width: leftWidth, height: h)
        lineWidthView.updateLineWidthLayers(withFrame: lineWidthFrame)
        let opacityFrame = CGRect(x: padding, y: padding + h, width: leftWidth, height: h)
        opacityView.updateOpacityLayers(withFrame: opacityFrame)
    }
    
    private func materialType(withIndex index: Int) -> Material.MaterialType {
        return Material.MaterialType(rawValue: Int8(index)) ?? .normal
    }
    private func index(with type: Material.MaterialType) -> Int {
        return Int(type.rawValue)
    }
    
    var isEditingBinding: ((MaterialView, Bool) -> ())?
    var isEditing = false {
        didSet {
            isEditingBinding?(self, isEditing)
        }
    }
    
    var isSubIndicatedBinding: ((MaterialView, Bool) -> ())?
    override var isSubIndicated: Bool {
        didSet {
            isSubIndicatedBinding?(self, isSubIndicated)
        }
    }
    
    var disabledRegisterUndo = true
    
    struct Binding {
        let view: MaterialView
        let material: Material, oldMaterial: Material, type: Action.SendType
    }
    var binding: ((Binding) -> ())?
    
    struct TypeBinding {
        let view: MaterialView
        let type: Material.MaterialType, oldType: Material.MaterialType
        let material: Material, oldMaterial: Material, sendType: Action.SendType
    }
    var typeBinding: ((TypeBinding) -> ())?
    
    struct ColorBinding {
        let view: MaterialView
        let color: Color, oldColor: Color
        let material: Material, oldMaterial: Material, type: Action.SendType
    }
    var colorBinding: ((ColorBinding) -> ())?
    
    struct LineColorBinding {
        let view: MaterialView
        let lineColor: Color, oldLineColor: Color
        let material: Material, oldMaterial: Material, type: Action.SendType
    }
    var lineColorBinding: ((LineColorBinding) -> ())?
    
    struct LineWidthBinding {
        let view: MaterialView
        let lineWidth: CGFloat, oldLineWidth: CGFloat
        let material: Material, oldMaterial: Material, type: Action.SendType
    }
    var lineWidthBinding: ((LineWidthBinding) -> ())?
    
    struct OpacityBinding {
        let view: MaterialView
        let opacity: CGFloat, oldOpacity: CGFloat
        let material: Material, oldMaterial: Material, type: Action.SendType
    }
    var opacityBinding: ((OpacityBinding) -> ())?
    
    private var oldMaterial = Material()
    
    private func setMaterial(with binding: EnumView.Binding) {
        if binding.type == .begin {
            isEditing = true
            oldMaterial = material
            typeBinding?(TypeBinding(view: self,
                                     type: oldMaterial.type, oldType: oldMaterial.type,
                                     material: oldMaterial, oldMaterial: oldMaterial,
                                     sendType: .begin))
        } else {
            let type = materialType(withIndex: binding.index)
            material = material.with(type)
            typeBinding?(TypeBinding(view: self,
                                     type: type, oldType: oldMaterial.type,
                                     material: material, oldMaterial: oldMaterial,
                                     sendType: binding.type))
            if binding.type == .end {
                isEditing = false
            }
        }
    }
    
    private func setMaterial(with obj: ColorView.Binding) {
        switch obj.colorView {
        case colorView:
            if obj.type == .begin {
                isEditing = true
                oldMaterial = material
                colorBinding?(ColorBinding(view: self,
                                           color: obj.color, oldColor: obj.oldColor,
                                           material: oldMaterial, oldMaterial: oldMaterial,
                                           type: .begin))
            } else {
                material = material.with(obj.color)
                colorBinding?(ColorBinding(view: self,
                                           color: obj.color, oldColor: obj.oldColor,
                                           material: material, oldMaterial: oldMaterial,
                                           type: obj.type))
                if obj.type == .end {
                    isEditing = false
                }
            }
        case lineColorView:
            if obj.type == .begin {
                isEditing = true
                oldMaterial = material
                lineColorBinding?(LineColorBinding(view: self,
                                                   lineColor: obj.color, oldLineColor: obj.oldColor,
                                                   material: oldMaterial, oldMaterial: oldMaterial,
                                                   type: .begin))
            } else {
                material = material.with(lineColor: obj.color)
                lineColorBinding?(LineColorBinding(view: self,
                                                   lineColor: obj.color, oldLineColor: obj.oldColor,
                                                   material: material, oldMaterial: oldMaterial,
                                                   type: obj.type))
                if obj.type == .end {
                    isEditing = false
                }
            }
        default:
            fatalError("No case")
        }
    }
    
    private func setMaterial(with obj: Slider.Binding) {
        switch obj.slider {
        case lineWidthView:
            if obj.type == .begin {
                isEditing = true
                oldMaterial = material
                lineWidthBinding?(LineWidthBinding(view: self,
                                                   lineWidth: obj.value, oldLineWidth: obj.oldValue,
                                                   material: oldMaterial, oldMaterial: oldMaterial,
                                                   type: .begin))
            } else {
                material = material.with(lineWidth: obj.value)
                lineWidthBinding?(LineWidthBinding(view: self,
                                                   lineWidth: obj.value, oldLineWidth: obj.oldValue,
                                                   material: material, oldMaterial: oldMaterial,
                                                   type: obj.type))
                if obj.type == .end {
                    isEditing = false
                }
            }
        case opacityView:
            if obj.type == .begin {
                isEditing = true
                oldMaterial = material
                opacityBinding?(OpacityBinding(view: self,
                                               opacity: obj.value, oldOpacity: obj.oldValue,
                                               material: oldMaterial, oldMaterial: oldMaterial,
                                               type: .begin))
            } else {
                material = material.with(opacity: obj.value)
                opacityBinding?(OpacityBinding(view: self,
                                               opacity: obj.value, oldOpacity: obj.oldValue,
                                               material: material, oldMaterial: oldMaterial,
                                               type: obj.type))
                if obj.type == .end {
                    isEditing = false
                }
            }
        default:
            fatalError("No case")
        }
    }
    
    func copy(with event: KeyInputEvent) -> CopyManager? {
        return CopyManager(copiedObjects: [material])
    }
    func paste(_ copyManager: CopyManager, with event: KeyInputEvent) -> Bool {
        for object in copyManager.copiedObjects {
            if let material = object as? Material {
                guard material.id != self.material.id else {
                    continue
                }
                set(material, old: self.material)
                return true
            }
        }
        return false
    }
    func delete(with event: KeyInputEvent) -> Bool {
        let material = Material()
        set(material, old: self.material)
        return true
    }
    
    private func set(_ material: Material, old oldMaterial: Material) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldMaterial, old: material) }
        binding?(Binding(view: self, material: oldMaterial, oldMaterial: oldMaterial, type: .begin))
        self.material = material
        binding?(Binding(view: self, material: material, oldMaterial: oldMaterial, type: .end))
    }
}
