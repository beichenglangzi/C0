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
        case normal, lineless, blur, luster, add, subtract
        var isDrawLine: Bool {
            return self == .normal
        }
        var displayText: Localization {
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
        static var displayTexts: [Localization] {
            return [normal.displayText,
                    lineless.displayText,
                    blur.displayText,
                    luster.displayText,
                    add.displayText,
                    subtract.displayText]
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
extension Material: ClassDeepCopiable {
}
extension Material: ObjectViewExpression {
    func thumbnail(withBounds bounds: CGRect, _ sizeType: SizeType) -> View {
        let view = View(isForm: true)
        view.bounds = bounds
        view.fillColor = color
        return view
    }
}
extension Material.MaterialType: Referenceable {
    static let uninheritanceName = Localization(english: "Type", japanese: "タイプ")
    static let name = Keyframe.name.spacedUnion(uninheritanceName)
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
extension Material.MaterialType: ObjectViewExpressionWithDisplayText {
}

extension SlidableNumberView {
    static func opacityView(_ sizeType: SizeType = .regular) -> SlidableNumberView {
        return SlidableNumberView(number: 1, defaultNumber: 1, min: 0, max: 1, sizeType: sizeType)
    }
    private static func opacityViewViews(with bounds: CGRect,
                                         checkerWidth: CGFloat, padding: CGFloat) -> [View] {
        let frame = CGRect(x: padding, y: bounds.height / 2 - checkerWidth,
                           width: bounds.width - padding * 2, height: checkerWidth * 2)
        
        let backgroundView = View(gradient: Gradient(colors: [.subContent, .content],
                                                     locations: [0, 1],
                                                     startPoint: CGPoint(x: 0, y: 0),
                                                     endPoint: CGPoint(x: 1, y: 0)))
        backgroundView.frame = frame
        
        let checkerboardView = View(path: CGPath.checkerboard(with: CGSize(square: checkerWidth),
                                                              in: frame))
        checkerboardView.fillColor = .content
        
        return [backgroundView, checkerboardView]
    }
    func updateOpacityViews(withFrame frame: CGRect) {
        if self.frame != frame {
            self.frame = frame
            backgroundViews = SlidableNumberView.opacityViewViews(with: frame,
                                                                  checkerWidth: knobView.radius,
                                                                  padding: padding)
        }
    }
}
extension SlidableNumberView {
    static func widthViewWith(min: CGFloat, max: CGFloat, exp: CGFloat,
                              _ sizeType: SizeType = .regular) -> SlidableNumberView {
        return SlidableNumberView(min: min, max: max, exp: exp, sizeType: sizeType)
    }
    private static func widthView(with bounds: CGRect,
                                   halfWidth: CGFloat, padding: CGFloat) -> View {
        let path = CGMutablePath()
        path.addLines(between: [CGPoint(x: padding,y: bounds.height / 2),
                                CGPoint(x: bounds.width - padding,
                                        y: bounds.height / 2 - halfWidth),
                                CGPoint(x: bounds.width - padding,
                                        y: bounds.height / 2 + halfWidth)])
        let shapeView = View(path: path)
        shapeView.fillColor = .content
        return shapeView
    }
    func updateLineWidthViews(withFrame frame: CGRect) {
        if self.frame != frame {
            self.frame = frame
            backgroundViews = [SlidableNumberView.widthView(with: frame,
                                                            halfWidth: knobView.radius,
                                                            padding: padding)]
        }
    }
}

/**
 Issue: 「線の強さ」を追加
 */
final class MaterialView: View, Assignable {
    var material: Material {
        didSet {
            guard material.id != oldValue.id else {
                return
            }
            typeView.enumeratedType = material.type
            colorView.color = material.color
            lineColorView.color = material.lineColor
            lineWidthView.number = material.lineWidth
            opacityView.number = material.opacity
        }
    }
    var defaultMaterial = Material()
    
    static let defaultWidth = 200.0.cf, defaultRightWidth = 60.0.cf
    
    private let classNameView = TextView(text: Material.name, font: .bold)
    private let typeView =
        EnumView<Material.MaterialType>(enumeratedType: .normal,
                                        indexClosure: { Int($0) },
                                        rawValueClosure: { Material.MaterialType.RawValue($0) },
                                        names: Material.MaterialType.displayTexts)
    private let colorView = ColorView()
    private let lineWidthView = SlidableNumberView.widthViewWith(min: Material.defaultLineWidth,
                                                                 max: 500,
                                                                 exp: 3)
    private let opacityView = SlidableNumberView.opacityView()
    private let classLineColorNameView = TextView(text: Localization(english: "Line Color:",
                                                                     japanese: "線のカラー:"))
    private let lineColorView = ColorView(hLineWidth: 2, hWidth: 8, slPadding: 4, sizeType: .small)
    
    override init() {
        material = defaultMaterial
        super.init()
        children = [classNameView,
                    typeView,
                    colorView, classLineColorNameView, lineColorView,
                    lineWidthView, opacityView]
        
        typeView.binding = { [unowned self] in self.setMaterial(with: $0) }
        
        colorView.setColorClosure = { [unowned self] in self.setMaterial(with: $0) }
        lineColorView.setColorClosure = { [unowned self] in self.setMaterial(with: $0) }
        
        lineWidthView.binding = { [unowned self] in self.setMaterial(with: $0) }
        opacityView.binding = { [unowned self] in self.setMaterial(with: $0) }
    }
    
    override var locale: Locale {
        didSet {
            updateLayout()
        }
    }
    
    override var defaultBounds: CGRect {
        let padding = Layout.basicPadding, h = Layout.basicHeight, cw = MaterialView.defaultWidth
        return CGRect(x: 0, y: 0,
                      width: cw + MaterialView.defaultRightWidth + padding * 2,
                      height: cw + classNameView.frame.height + h + padding * 2)
    }
    func defaultBounds(withWidth width: CGFloat) -> CGRect {
        let padding = Layout.basicPadding, h = Layout.basicHeight
        let cw = width - MaterialView.defaultRightWidth + padding * 2
        return CGRect(x: 0, y: 0,
                      width: cw + MaterialView.defaultRightWidth + padding * 2,
                      height: cw + classNameView.frame.height + h + padding * 2)
    }
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    private func updateLayout() {
        let padding = Layout.basicPadding, h = Layout.basicHeight, rw = MaterialView.defaultRightWidth
        let cw = bounds.width - rw - padding * 2
        classNameView.frame.origin = CGPoint(x: padding,
                                             y: bounds.height - classNameView.frame.height - padding)
        let tx = classNameView.frame.maxX + padding
        typeView.frame = CGRect(x: tx,
                                y: bounds.height - h * 2 - padding,
                                width: bounds.width - tx - padding, height: h * 2)
        colorView.frame = CGRect(x: padding, y: padding, width: cw, height: cw)
        classLineColorNameView.frame.origin = CGPoint(x: padding + cw,
                                                      y: padding + cw - classLineColorNameView.frame.height)
        lineColorView.frame = CGRect(x: padding + cw, y: classLineColorNameView.frame.minY - rw,
                                     width: rw, height: rw)
        let lineWidthFrame = CGRect(x: padding + cw, y: lineColorView.frame.minY - h,
                                    width: rw, height: h)
        lineWidthView.updateLineWidthViews(withFrame: lineWidthFrame)
        let opacityFrame = CGRect(x: padding + cw, y: lineColorView.frame.minY - h * 2,
                                  width: rw, height: h)
        opacityView.updateOpacityViews(withFrame: opacityFrame)
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
        let material: Material, oldMaterial: Material, phase: Phase
    }
    var binding: ((Binding) -> ())?
    
    struct TypeBinding {
        let view: MaterialView
        let type: Material.MaterialType, oldType: Material.MaterialType
        let material: Material, oldMaterial: Material, phase: Phase
    }
    var typeBinding: ((TypeBinding) -> ())?
    
    struct ColorBinding {
        let view: MaterialView
        let color: Color, oldColor: Color
        let material: Material, oldMaterial: Material, phase: Phase
    }
    var colorBinding: ((ColorBinding) -> ())?
    
    struct LineColorBinding {
        let view: MaterialView
        let lineColor: Color, oldLineColor: Color
        let material: Material, oldMaterial: Material, phase: Phase
    }
    var lineColorBinding: ((LineColorBinding) -> ())?
    
    struct LineWidthBinding {
        let view: MaterialView
        let lineWidth: CGFloat, oldLineWidth: CGFloat
        let material: Material, oldMaterial: Material, phase: Phase
    }
    var lineWidthBinding: ((LineWidthBinding) -> ())?
    
    struct OpacityBinding {
        let view: MaterialView
        let opacity: CGFloat, oldOpacity: CGFloat
        let material: Material, oldMaterial: Material, phase: Phase
    }
    var opacityBinding: ((OpacityBinding) -> ())?
    
    private var oldMaterial = Material()
    
    private func setMaterial(with binding: EnumView<Material.MaterialType>.Binding) {
        if binding.phase == .began {
            isEditing = true
            oldMaterial = material
            typeBinding?(TypeBinding(view: self,
                                     type: oldMaterial.type, oldType: oldMaterial.type,
                                     material: oldMaterial, oldMaterial: oldMaterial,
                                     phase: .began))
        } else {
            material = material.with(binding.enumeratedType)
            typeBinding?(TypeBinding(view: self,
                                     type: binding.enumeratedType, oldType: oldMaterial.type,
                                     material: material, oldMaterial: oldMaterial,
                                     phase: binding.phase))
            if binding.phase == .ended {
                isEditing = false
            }
        }
    }
    
    private func setMaterial(with obj: ColorView.Binding) {
        switch obj.colorView {
        case colorView:
            if obj.phase == .began {
                isEditing = true
                oldMaterial = material
                colorBinding?(ColorBinding(view: self,
                                           color: obj.color, oldColor: obj.oldColor,
                                           material: oldMaterial, oldMaterial: oldMaterial,
                                           phase: .began))
            } else {
                material = material.with(obj.color)
                colorBinding?(ColorBinding(view: self,
                                           color: obj.color, oldColor: obj.oldColor,
                                           material: material, oldMaterial: oldMaterial,
                                           phase: obj.phase))
                if obj.phase == .ended {
                    isEditing = false
                }
            }
        case lineColorView:
            if obj.phase == .began {
                isEditing = true
                oldMaterial = material
                lineColorBinding?(LineColorBinding(view: self,
                                                   lineColor: obj.color, oldLineColor: obj.oldColor,
                                                   material: oldMaterial, oldMaterial: oldMaterial,
                                                   phase: .began))
            } else {
                material = material.with(lineColor: obj.color)
                lineColorBinding?(LineColorBinding(view: self,
                                                   lineColor: obj.color, oldLineColor: obj.oldColor,
                                                   material: material, oldMaterial: oldMaterial,
                                                   phase: obj.phase))
                if obj.phase == .ended {
                    isEditing = false
                }
            }
        default:
            fatalError("No case")
        }
    }
    
    private func setMaterial(with obj: SlidableNumberView.Binding) {
        switch obj.view {
        case lineWidthView:
            if obj.phase == .began {
                isEditing = true
                oldMaterial = material
                lineWidthBinding?(LineWidthBinding(view: self,
                                                   lineWidth: obj.number, oldLineWidth: obj.oldNumber,
                                                   material: oldMaterial, oldMaterial: oldMaterial,
                                                   phase: .began))
            } else {
                material = material.with(lineWidth: obj.number)
                lineWidthBinding?(LineWidthBinding(view: self,
                                                   lineWidth: obj.number, oldLineWidth: obj.oldNumber,
                                                   material: material, oldMaterial: oldMaterial,
                                                   phase: obj.phase))
                if obj.phase == .ended {
                    isEditing = false
                }
            }
        case opacityView:
            if obj.phase == .began {
                isEditing = true
                oldMaterial = material
                opacityBinding?(OpacityBinding(view: self,
                                               opacity: obj.number, oldOpacity: obj.oldNumber,
                                               material: oldMaterial, oldMaterial: oldMaterial,
                                               phase: .began))
            } else {
                material = material.with(opacity: obj.number)
                opacityBinding?(OpacityBinding(view: self,
                                               opacity: obj.number, oldOpacity: obj.oldNumber,
                                               material: material, oldMaterial: oldMaterial,
                                               phase: obj.phase))
                if obj.phase == .ended {
                    isEditing = false
                }
            }
        default:
            fatalError("No case")
        }
    }
    
    func delete(for p: CGPoint) {
        let material = Material()
        set(material, old: self.material)
    }
    func copiedViewables(at p: CGPoint) -> [Viewable] {
        return [material]
    }
    func paste(_ objects: [Any], for p: CGPoint) {
        for object in objects {
            if let material = object as? Material {
                if material.id != self.material.id {
                    set(material, old: self.material)
                    return
                }
            }
        }
    }
    
    private func set(_ material: Material, old oldMaterial: Material) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldMaterial, old: material) }
        binding?(Binding(view: self,
                         material: oldMaterial, oldMaterial: oldMaterial, phase: .began))
        self.material = material
        binding?(Binding(view: self,
                         material: material, oldMaterial: oldMaterial, phase: .ended))
    }
    
    func reference(at p: CGPoint) -> Reference {
        return Material.reference
    }
}
