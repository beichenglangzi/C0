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

import CoreGraphics
import Foundation.NSUUID
import QuartzCore

final class Material: NSObject, NSCoding {
    enum MaterialType: Int8, Codable {
        static var name: Localization {
            return Localization(english: "Material Type", japanese: "マテリアルタイプ")
        }
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
    }
    
    static let defaultLineWidth = 1.0.cf
    
    let color: Color, lineColor: Color, type: MaterialType
    let lineWidth: CGFloat, lineStrength: CGFloat, opacity: CGFloat, id: UUID
    
    init(color: Color = Color(), lineColor: Color? = nil, type: MaterialType = .normal,
         lineWidth: CGFloat = defaultLineWidth, lineStrength: CGFloat = 0,
         opacity: CGFloat = 1) {
        
        self.color = color
        self.lineColor = lineColor ?? Material.lineColorWith(color: color, lineStrength: lineStrength)
        self.type = type
        self.lineWidth = lineWidth
        self.lineStrength = lineStrength
        self.opacity = opacity
        self.id = UUID()
        super.init()
    }
    static func lineColorWith(color: Color, lineStrength: CGFloat) -> Color {
        if lineStrength == 0 {
            return Color()
        } else {
            let lightness = Double(CGFloat.linear(0, CGFloat(color.lightness), t: lineStrength))
            return color.with(lightness: lightness).with(alpha: 1)
        }
    }
    private init(color: Color = Color(), lineColor: Color, type: MaterialType = .normal,
                 lineWidth: CGFloat = defaultLineWidth, lineStrength: CGFloat = 0,
                 opacity: CGFloat = 1,
                 id: UUID = UUID()) {
        
        self.color = color
        self.lineColor = lineColor
        self.type = type
        self.lineWidth = lineWidth
        self.lineStrength = lineStrength
        self.opacity = opacity
        self.id = id
        super.init()
    }
    
    private enum CodingKeys: String, CodingKey {
        case color, lineColor, type, lineWidth, lineStrength, opacity, id
    }
    init?(coder: NSCoder) {
        color = coder.decodeDecodable(Color.self, forKey: CodingKeys.color.rawValue) ?? Color()
        lineColor = coder.decodeDecodable(
            Color.self, forKey: CodingKeys.lineColor.rawValue) ?? Color()
        type = MaterialType(
            rawValue: Int8(coder.decodeInt32(forKey: CodingKeys.type.rawValue))) ?? .normal
        lineWidth = coder.decodeDouble(forKey: CodingKeys.lineWidth.rawValue).cf
        lineStrength = coder.decodeDouble(forKey: CodingKeys.lineStrength.rawValue).cf
        opacity = coder.decodeDouble(forKey: CodingKeys.opacity.rawValue).cf
        id = coder.decodeObject(forKey: CodingKeys.id.rawValue) as? UUID ?? UUID()
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encodeEncodable(color, forKey: CodingKeys.color.rawValue)
        coder.encodeEncodable(lineColor, forKey: CodingKeys.lineColor.rawValue)
        coder.encode(Int32(type.rawValue), forKey: CodingKeys.type.rawValue)
        coder.encode(lineWidth.d, forKey: CodingKeys.lineWidth.rawValue)
        coder.encode(lineStrength.d, forKey: CodingKeys.lineStrength.rawValue)
        coder.encode(opacity.d, forKey: CodingKeys.opacity.rawValue)
        coder.encode(id, forKey: CodingKeys.id.rawValue)
    }
    
    func withNewID() -> Material {
        return Material(color: color, lineColor: lineColor,
                        type: type, lineWidth: lineWidth, lineStrength: lineStrength,
                        opacity: opacity, id: UUID())
    }
    func withColor(_ color: Color) -> Material {
        return Material(color: color,
                        type: type, lineWidth: lineWidth, lineStrength: lineStrength,
                        opacity: opacity)
    }
    func withType(_ type: MaterialType) -> Material {
        return Material(color: color, lineColor: lineColor,
                        type: type, lineWidth: lineWidth, lineStrength: lineStrength,
                        opacity: opacity, id: UUID())
    }
    func withLineWidth(_ lineWidth: CGFloat) -> Material {
        return Material(color: color, lineColor: lineColor,
                        type: type, lineWidth: lineWidth, lineStrength: lineStrength,
                        opacity: opacity, id: UUID())
    }
    func withLineStrength(_ lineStrength: CGFloat) -> Material {
        return Material(color: color,
                        lineColor: Material.lineColorWith(color: color, lineStrength: lineStrength),
                        type: type, lineWidth: lineWidth, lineStrength: lineStrength,
                        opacity: opacity, id: UUID())
    }
    func withOpacity(_ opacity: CGFloat) -> Material {
        return Material(color: color,
                        lineColor: Material.lineColorWith(color: color, lineStrength: lineStrength),
                        type: type, lineWidth: lineWidth, lineStrength: lineStrength,
                        opacity: opacity, id: UUID())
    }
    
    static func ==(lhs: Material, rhs: Material) -> Bool {
        return lhs === rhs
    }
}

extension Material: Referenceable {
    static let name = Localization(english: "Material", japanese: "マテリアル")
    var valueDescription: Localization {
        return Localization(english: "Type: ", japanese: "タイプ: ")
            + type.displayString + Localization("\nID: \(id.uuidString)")
    }
}
extension Material: Interpolatable {
    static func linear(_ f0: Material, _ f1: Material, t: CGFloat) -> Material {
        guard f0.id != f1.id else {
            return f0
        }
        let color = Color.linear(f0.color, f1.color, t: t)
        let type = f0.type
        let lineWidth = CGFloat.linear(f0.lineWidth, f1.lineWidth, t: t)
        let lineStrength = CGFloat.linear(f0.lineStrength, f1.lineStrength, t: t)
        let opacity = CGFloat.linear(f0.opacity, f1.opacity, t: t)
        return Material(color: color, type: type,
                        lineWidth: lineWidth, lineStrength: lineStrength, opacity: opacity)
    }
    static func firstMonospline(_ f1: Material, _ f2: Material, _ f3: Material,
                                with msx: MonosplineX) -> Material {
        guard f1.id != f2.id else {
            return f1
        }
        let color = Color.firstMonospline(f1.color, f2.color, f3.color, with: msx)
        let type = f1.type
        let lineWidth = CGFloat.firstMonospline(f1.lineWidth, f2.lineWidth, f3.lineWidth, with: msx)
        let lineStrength = CGFloat.firstMonospline(f1.lineStrength, f2.lineStrength, f3.lineStrength,
                                                   with: msx)
        let opacity = CGFloat.firstMonospline(f1.opacity, f2.opacity, f3.opacity, with: msx)
        return Material(color: color, type: type,
                        lineWidth: lineWidth, lineStrength: lineStrength, opacity: opacity)
    }
    static func monospline(_ f0: Material, _ f1: Material, _ f2: Material, _ f3: Material,
                           with msx: MonosplineX) -> Material {
        guard f1.id != f2.id else {
            return f1
        }
        let color = Color.monospline(f0.color, f1.color, f2.color, f3.color, with: msx)
        let type = f1.type
        let lineWidth = CGFloat.monospline(f0.lineWidth, f1.lineWidth,
                                           f2.lineWidth, f3.lineWidth, with: msx)
        let lineStrength = CGFloat.monospline(f0.lineStrength, f1.lineStrength,
                                              f2.lineStrength, f3.lineStrength, with: msx)
        let opacity = CGFloat.monospline(f0.opacity, f1.opacity, f2.opacity, f3.opacity, with: msx)
        return Material(color: color, type: type,
                        lineWidth: lineWidth, lineStrength: lineStrength, opacity: opacity)
    }
    static func endMonospline(_ f0: Material, _ f1: Material, _ f2: Material,
                              with msx: MonosplineX) -> Material {
        guard f1.id != f2.id else {
            return f1
        }
        let color = Color.endMonospline(f0.color, f1.color, f2.color, with: msx)
        let type = f1.type
        let lineWidth = CGFloat.endMonospline(f0.lineWidth, f1.lineWidth, f2.lineWidth, with: msx)
        let lineStrength = CGFloat.endMonospline(f0.lineStrength,
                                                 f1.lineStrength, f2.lineStrength, with: msx)
        let opacity = CGFloat.endMonospline(f0.opacity, f1.opacity, f2.opacity, with: msx)
        return Material(color: color, type: type,
                        lineWidth: lineWidth, lineStrength: lineStrength, opacity: opacity)
    }
}
extension Material: Drawable {
    func draw(with bounds: CGRect, in ctx: CGContext) {
        ctx.setFillColor(color.cgColor)
        ctx.fill(bounds.inset(by: Layout.basicPadding))
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

final class CellEditor: LayerRespondable {
    static let name = Localization(english: "Cell Editor", japanese: "セルエディタ")
    let hiddenBox = Button(frame: CGRect(x: Layout.basicPadding, y: Layout.basicPadding,
                                         width: 100, height: Layout.basicHeight),
                           name: Localization(english: "Hidden", japanese: "隠す"))
    let showAllBox = Button(frame: CGRect(x: Layout.basicPadding + 100, y: Layout.basicPadding,
                                          width: 100, height: Layout.basicHeight),
                            name: Localization(english: "Show All", japanese: "すべて表示"))
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    let layer = CALayer.interfaceLayer(backgroundColor: .background)
    init() {
        layer.frame = CGRect(x: 0,
                             y: 0,
                             width: 100 * 2 + Layout.basicPadding * 2,
                             height: Layout.basicHeight * 2 + Layout.basicPadding * 2)
        children = [hiddenBox, showAllBox]
        update(withChildren: children, oldChildren: [])
    }
    
    var copyHandler: ((KeyInputEvent) -> (CopiedObject))? = nil
    func copy(with event: KeyInputEvent) -> CopiedObject {
        return copyHandler?(event) ?? CopiedObject()
    }
}

final class MaterialEditor:
LayerRespondable, ColorPickerDelegate, SliderDelegate, PulldownButtonDelegate {
    static let name = Localization(english: "Material Editor", japanese: "マテリアルエディタ")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    var defaultBorderColor: CGColor? = Color.border.cgColor
    
    weak var sceneEditor: SceneEditor!
    
    static let leftWidth = 85.0.cf, colorPickerWidth = 140.0.cf
    let layer = CALayer.interfaceLayer(backgroundColor: .background)
    let label = Label(text: Localization(english: "Material", japanese: "マテリアル"))
    let colorPicker = ColorPicker(
        frame: CGRect(x: Layout.basicPadding, y: Layout.basicPadding,
                      width: colorPickerWidth, height: colorPickerWidth),
        description: Localization(english: "Material color", japanese: "マテリアルカラー")
    )
    let typeButton = PulldownButton(
        frame: CGRect(
            x: Layout.basicPadding + colorPickerWidth,
            y: colorPickerWidth + Layout.basicPadding - Layout.basicHeight,
            width: leftWidth, height: Layout.basicHeight
        ),
        names: [
            Material.MaterialType.normal.displayString,
            Material.MaterialType.lineless.displayString,
            Material.MaterialType.blur.displayString,
            Material.MaterialType.luster.displayString,
            Material.MaterialType.add.displayString,
            Material.MaterialType.subtract.displayString
        ],
        description: Localization(english: "Material Type", japanese: "マテリアルタイプ")
    )
    let lineWidthSlider: Slider = {
        let slider = Slider(
            frame: CGRect(
                x: Layout.basicPadding + colorPickerWidth,
                y: colorPickerWidth + Layout.basicPadding - Layout.basicHeight * 2,
                width: leftWidth,
                height: Layout.basicHeight
            ),
            min: Material.defaultLineWidth, max: 500, exp: 2,
            description: Localization(english: "Material Line Width", japanese: "マテリアルの線の太さ")
        )
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.fillColor = Color.content.cgColor
        shapeLayer.path = {
            let path = CGMutablePath(), halfWidth = 5.0.cf
            path.addLines(
                between: [
                    CGPoint(x: slider.viewPadding,y: slider.frame.height / 2),
                    CGPoint(x: slider.frame.width - slider.viewPadding,
                            y: slider.frame.height / 2 - halfWidth),
                    CGPoint(x: slider.frame.width - slider.viewPadding,
                            y: slider.frame.height / 2 + halfWidth)
                ]
            )
            return path
        } ()
        
        slider.layer.sublayers = [shapeLayer, slider.knobLayer]
        return slider
    } ()
    let lineStrengthSlider: Slider = {
        let slider = Slider(
            frame: CGRect(x: Layout.basicPadding + colorPickerWidth,
                          y: colorPickerWidth + Layout.basicPadding - Layout.basicHeight * 3,
                          width: leftWidth,
                          height: Layout.basicHeight),
            min: 0, max: 1,
            description: Localization(english: "Material Line Strength", japanese: "マテリアルの線の強さ")
        )
        let halfWidth = 5.0.cf, fillColor = Color.edit
        let width = slider.frame.width - slider.viewPadding * 2
        let frame = CGRect(x: slider.viewPadding,
                           y: slider.frame.height / 2 - halfWidth,
                           width: width,
                           height: halfWidth * 2)
        let size = CGSize(width: halfWidth, height: halfWidth)
        let count = Int(frame.width / (size.width * 2))
        
        let sublayers: [CALayer] = (0 ..< count).map { i in
            let lineLayer = CALayer()
            lineLayer.backgroundColor = fillColor.cgColor
            lineLayer.borderColor = Color.linear(.content, fillColor,
                                                 t: CGFloat(i) / CGFloat(count - 1)).cgColor
            lineLayer.borderWidth = 2
            lineLayer.frame = CGRect(x: frame.minX + CGFloat(i) * (size.width * 2 + 1),
                                     y: frame.minY,
                                     width: size.width * 2,
                                     height: size.height * 2)
            return lineLayer
        }
        
        slider.layer.sublayers = sublayers + [slider.knobLayer]
        return slider
    } ()
    let opacitySlider: Slider = {
        let slider = Slider(
            frame: CGRect(x: Layout.basicPadding + colorPickerWidth,
                          y: colorPickerWidth + Layout.basicPadding - Layout.basicHeight * 4,
                          width: leftWidth,
                          height: Layout.basicHeight),
            value: 1, defaultValue: 1, min: 0, max: 1, isInvert: true,
            description: Localization(english: "Material Opacity", japanese: "マテリアルの不透明度")
        )
        let halfWidth = 5.0.cf
        let width = slider.frame.width - slider.viewPadding * 2
        let frame = CGRect(x: slider.viewPadding, y: slider.frame.height / 2 - halfWidth,
                           width: width, height: halfWidth * 2)
        let size = CGSize(width: halfWidth, height: halfWidth)
        
        let backLayer = CALayer()
        backLayer.backgroundColor = Color.content.cgColor
        backLayer.frame = frame
        
        let checkerboardLayer = CAShapeLayer()
        checkerboardLayer.fillColor = Color.edit.cgColor
        checkerboardLayer.path = CGPath.checkerboard(with: size, in: frame)
        
        let colorLayer = CAGradientLayer()
        colorLayer.startPoint = CGPoint(x: 0, y: 0)
        colorLayer.endPoint = CGPoint(x: 1, y: 0)
        colorLayer.colors = [Color.content.cgColor, Color.content.with(alpha: 0).cgColor]
        colorLayer.frame = frame
        
        slider.layer.sublayers = [backLayer, checkerboardLayer, colorLayer, slider.knobLayer]
        return slider
    } ()
    let splitColorBox = Button(frame: CGRect(x: Layout.basicPadding + colorPickerWidth, y: 0,
                                             width: MaterialEditor.leftWidth,
                                             height: Layout.basicHeight),
                               name: Localization(english: "Split Color", japanese: "カラーを分割"))
    let splitOtherThanColorBox = Button(frame: CGRect(x: Layout.basicPadding + colorPickerWidth,
                                                      y: Layout.basicHeight,
                                                      width: MaterialEditor.leftWidth,
                                                      height: Layout.basicHeight),
                                        name: Localization(english: "Split Other Than Color",
                                                           japanese: "カラー以外を分割"))
    
    static let emptyMaterial = Material()
    init() {
        layer.frame = CGRect(
            x: 0,
            y: 0,
            width: MaterialEditor.leftWidth
                + MaterialEditor.colorPickerWidth + Layout.basicPadding * 2,
            height: MaterialEditor.colorPickerWidth + Layout.basicLargePadding * 2
        )
        colorPicker.delegate = self
        typeButton.delegate = self
        lineWidthSlider.delegate = self
        lineStrengthSlider.delegate = self
        opacitySlider.delegate = self
        splitColorBox.clickHandler = { [unowned self] _ in
            self.sceneEditor.canvas.splitColor(at: self.editPointInCanvas)
        }
        splitOtherThanColorBox.clickHandler = { [unowned self] _ in
            self.sceneEditor.canvas.splitOtherThanColor(at: self.editPointInCanvas)
        }
        
        children = [colorPicker, typeButton,
                    lineWidthSlider, lineStrengthSlider, opacitySlider, splitColorBox,
                    splitOtherThanColorBox]
        update(withChildren: children, oldChildren: [])
    }
    
    var material = MaterialEditor.emptyMaterial {
        didSet {
            if material.id != oldValue.id {
                sceneEditor.scene.editMaterial = material
                colorPicker.color = material.color
                typeButton.selectionIndex = Int(material.type.rawValue)
                lineWidthSlider.value = material.lineWidth
                opacitySlider.value = material.opacity
                lineStrengthSlider.value = material.lineStrength
                sceneEditor.canvas.setNeedsDisplay()
            }
        }
    }
    
    var editPointInCanvas = CGPoint()
    
    var isEditing = false {
        didSet {
            if isEditing != oldValue {
                CATransaction.disableAnimation {
                    layer.opacity = isEditing ? 0.5 : 1
                }
            }
            sceneEditor.canvas.materialEditorType = isEditing ?
                .preview : (isSubIndication ? .selection : .none)
        }
    }
    var isSubIndication = false {
        didSet {
            sceneEditor.canvas.materialEditorType = isEditing ?
                .preview : (isSubIndication ? .selection : .none)
//            if !isSubIndication {
//                removeFromParent()
//            }
        }
    }
    
    func contains(_ p: CGPoint) -> Bool {
        return layer.contains(p)
    }
    
    func copy(with event: KeyInputEvent) -> CopiedObject {
        return CopiedObject(objects: [material])
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) {
        for object in copiedObject.objects {
            if let material = object as? Material {
                paste(material, withSelection: self.material, useSelection: false)
                return
            }
        }
    }
    func paste(_ material: Material, withSelection selectionMaterial: Material, useSelection: Bool) {
        let materialTuples = materialTuplesWith(
            material: selectionMaterial, useSelection: useSelection,
            in: sceneEditor.scene.editCutItem, sceneEditor.scene.cutItems
        )
        for materialTuple in materialTuples.values {
            _setMaterial(material, in: materialTuple)
        }
    }
    func paste(_ color: Color, withSelection selectionMaterial: Material, useSelection: Bool) {
        let colorTuples = colorTuplesWith(
            color: selectionMaterial.color, useSelection: useSelection,
            in: sceneEditor.scene.editCutItem, sceneEditor.scene.cutItems
        )
        _setColor(color, in: colorTuples)
    }
    func splitMaterial(with cells: [Cell]) {
        let materialTuples = materialTuplesWith(cells: cells, isSelection: true,
                                                in: sceneEditor.scene.editCutItem)
        for materialTuple in materialTuples.values {
            _setMaterial(materialTuple.material.withColor(materialTuple.material.color.withNewID()),
                         in: materialTuple)
        }
    }
    func splitColor(with cells: [Cell]) {
        let colorTuples = colorTuplesWith(cells: cells, isSelection: true,
                                          in: sceneEditor.scene.editCutItem)
        for colorTuple in colorTuples {
            let newColor = colorTuple.color.withNewID()
            for materialTuple in colorTuple.materialTuples.values {
                _setMaterial(materialTuple.material.withColor(newColor), in: materialTuple)
            }
        }
        if let material =
            colorTuples.first?.materialTuples.first?.value.cutTuples.first?.cells.first?.material {
            _setMaterial(material, oldMaterial: self.material)
        }
    }
    func splitOtherThanColor(with cells: [Cell]) {
        let materialTuples = materialTuplesWith(cells: cells, isSelection: true,
                                                in: sceneEditor.scene.editCutItem)
        for materialTuple in materialTuples.values {
            _setMaterial(materialTuple.material.withColor(materialTuple.material.color),
                         in: materialTuple)
        }
        if let material = materialTuples.first?.value.cutTuples.first?.cells.first?.material {
            _setMaterial(material, oldMaterial: self.material)
        }
    }
    private func _setMaterial(_ material: Material, oldMaterial: Material,
                              in cells: [Cell], _ cutItem: CutItem) {
        undoManager?.registerUndo(withTarget: self) {
            $0._setMaterial(oldMaterial, oldMaterial: material, in: cells, cutItem)
        }
        for cell in cells {
            cell.material = material
        }
        cutItem.cutDataModel.isWrite = true
        if cutItem === sceneEditor.canvas.cutItem {
            sceneEditor.canvas.setNeedsDisplay()
        }
    }
    func select(_ material: Material) {
        _setMaterial(material, oldMaterial: self.material)
    }
    private func _setMaterial(_ material: Material, oldMaterial: Material) {
        undoManager?.registerUndo(withTarget: self) {
            $0._setMaterial(oldMaterial, oldMaterial: material)
        }
        self.material = material
        sceneEditor.sceneDataModel.isWrite = true
    }
    
    enum EditType {
        case color, material, correction
    }
    var editType = EditType.color {
        didSet{
            if editType != oldValue {
                sceneEditor.canvas.setNeedsDisplay()
            }
        }
    }
    
    var isAnimation: Bool {
        for materialItem in sceneEditor.canvas.cut.editNode.editTrack.materialItems {
            if materialItem.keyMaterials.contains(material) {
                return true
            }
        }
        return false
    }
    
    func cells(with cut: Cut) -> [Cell] {
        var cells = [Cell]()
        cut.rootNode.allChildren {
            cells += $0.rootCell.allCells
        }
        return cells
    }
    
    enum ViewType {
        case none, selection, preview
    }
    private struct ColorTuple {
        var color: Color, materialTuples: [UUID: MaterialTuple]
    }
    private struct MaterialTuple {
        var material: Material, cutTuples: [CutTuple]
    }
    private struct CutTuple {
        var cutItem: CutItem, cells: [Cell], materialItemTuples: [MaterialItemTuple]
    }
    private struct MaterialItemTuple {
        var track: NodeTrack, materialItem: MaterialItem, editIndexes: [Int]
        static func materialItemTuples(
            with materialItem: MaterialItem, isSelection: Bool, in track: NodeTrack
        ) -> [UUID: (material: Material, itemTupe: MaterialItemTuple)] {
            var materialItemTuples = [UUID: (material: Material, itemTupe: MaterialItemTuple)]()
            for (i, material) in materialItem.keyMaterials.enumerated() {
                if materialItemTuples[material.id] == nil {
                    let indexes: [Int]
                    if isSelection {
                        indexes = [track.animation.editKeyframeIndex]
                    } else {
                        indexes = (i ..< materialItem.keyMaterials.count)
                            .filter { materialItem.keyMaterials[$0].id == material.id }
                    }
                    materialItemTuples[material.id] = (material,
                                                       MaterialItemTuple(track: track,
                                                                         materialItem: materialItem,
                                                                         editIndexes: indexes))
                }
            }
            return materialItemTuples
        }
    }
    
    private var materialTuples = [UUID: MaterialTuple](), colorTuples = [ColorTuple](), oldMaterialTuple: MaterialTuple?, oldMaterial: Material?
    private func colorTuplesWith(color: Color?, useSelection: Bool = false, in cutItem: CutItem, _ cutItems: [CutItem]) -> [ColorTuple] {
//        if useSelection {
//            let allSelectionCells = cutItem.cut.editNode.allSelectionCellItemsWithNoEmptyGeometry
//            if !allSelectionCells.isEmpty {
//                return colorTuplesWith(cells: allSelectionCells,
//                                       isSelection: useSelection, in: cutItem)
//            }
//        }
        if let color = color {
            return colorTuplesWith(color: color, isSelection: useSelection, in: cutItems)
        } else {
            return colorTuplesWith(cells: cells(with: cutItem.cut),
                                   isSelection: useSelection, in: cutItem)
        }
    }
    private func colorTuplesWith(cells: [Cell], isSelection: Bool,
                                 in cutItem: CutItem) -> [ColorTuple] {
        struct ColorCell {
            var color: Color, cells: [Cell]
        }
        var colorDic = [UUID: ColorCell]()
        for cell in cells {
            if colorDic[cell.material.color.id] != nil {
                colorDic[cell.material.color.id]?.cells.append(cell)
            } else {
                colorDic[cell.material.color.id] = ColorCell(color: cell.material.color,
                                                             cells: [cell])
            }
        }
        return colorDic.map {
            ColorTuple(color: $0.value.color,
                       materialTuples: materialTuplesWith(cells: $0.value.cells,
                                                          isSelection: isSelection, in: cutItem))
        }
    }
    private func colorTuplesWith(color: Color, isSelection: Bool,
                                 in cutItems: [CutItem]) -> [ColorTuple] {
        var materialTuples = [UUID: MaterialTuple]()
        for cutItem in cutItems {
            let cells = self.cells(with: cutItem.cut).filter { $0.material.color == color }
            if !cells.isEmpty {
                let mts = materialTuplesWith(cells: cells, color: color,
                                             isSelection: isSelection, in: cutItem)
                for mt in mts {
                    if materialTuples[mt.key] != nil {
                        materialTuples[mt.key]?.cutTuples += mt.value.cutTuples
                    } else {
                        materialTuples[mt.key] = mt.value
                    }
                }
            }
        }
        return materialTuples.isEmpty ? [] : [ColorTuple(color: color,
                                                         materialTuples: materialTuples)]
    }
    
    private func materialTuplesWith(cells: [Cell], color: Color? = nil,
                                    isSelection: Bool, in cutItem: CutItem) -> [UUID: MaterialTuple] {
        var materialDic = [UUID: MaterialTuple]()
        for cell in cells {
            if materialDic[cell.material.id] != nil {
                materialDic[cell.material.id]?.cutTuples[0].cells.append(cell)
            } else {
                let cutTuples = [CutTuple(cutItem: cutItem, cells: [cell], materialItemTuples: [])]
                materialDic[cell.material.id] = MaterialTuple(material: cell.material,
                                                              cutTuples: cutTuples)
            }
        }
        
        for track in cutItem.cut.editNode.tracks {
            for materialItem in track.materialItems {
                if cells.contains(where: { materialItem.cells.contains($0) }) {
                    let materialItemTuples = MaterialItemTuple.materialItemTuples(
                        with: materialItem, isSelection: isSelection, in: track)
                    for materialItemTuple in materialItemTuples {
                        if let color = color {
                            if materialItemTuple.value.material.color != color {
                                continue
                            }
                        }
                        if materialDic[materialItemTuple.key] != nil {
                            materialDic[materialItemTuple.key]?.cutTuples[0]
                                .materialItemTuples.append(materialItemTuple.value.itemTupe)
                        } else {
                            let materialItemTuples = [materialItemTuple.value.itemTupe]
                            let cutTuples = [CutTuple(cutItem: cutItem, cells: [],
                                                      materialItemTuples: materialItemTuples)]
                            materialDic[materialItemTuple.key] = MaterialTuple(
                                material: materialItemTuple.value.material,
                                cutTuples: cutTuples
                            )
                        }
                    }
                }
            }
        }
        
        return materialDic
    }
    private func materialTuplesWith(material: Material?, useSelection: Bool = false,
                                    in cutItem: CutItem,
                                    _ cutItems: [CutItem]) -> [UUID: MaterialTuple] {
//        if useSelection {
//            let allSelectionCells = cutItem.cut.editNode.allSelectionCellItemsWithNoEmptyGeometry
//            if !allSelectionCells.isEmpty {
//                return materialTuplesWith(cells: allSelectionCells,
//                                          isSelection: useSelection, in: cutItem)
//            }
//        }
        if let material = material {
            let cutTuples: [CutTuple] = cutItems.flatMap { cutItem in
                let cells = self.cells(with: cutItem.cut).filter { $0.material.id == material.id }
                
                var materialItemTuples = [MaterialItemTuple]()
                for track in cutItem.cut.editNode.tracks {
                    for materialItem in track.materialItems {
                        let indexes = useSelection ?
                            [track.animation.editKeyframeIndex] :
                            materialItem.keyMaterials.enumerated().flatMap {
                                $0.element.id == material.id ? $0.offset : nil }
                        if !indexes.isEmpty {
                            materialItemTuples.append(MaterialItemTuple(track: track,
                                                                        materialItem: materialItem,
                                                                        editIndexes: indexes))
                        }
                    }
                }
                
                return cells.isEmpty && materialItemTuples.isEmpty ?
                    nil : CutTuple(cutItem: cutItem, cells: cells,
                                   materialItemTuples: materialItemTuples)
            }
            return cutTuples.isEmpty ? [:] : [material.id: MaterialTuple(material: material,
                                                                         cutTuples: cutTuples)]
        } else {
            return materialTuplesWith(cells: cells(with: cutItem.cut),
                                      isSelection: useSelection, in: cutItem)
        }
    }
    
    private func selectionMaterialTuple(with colorTuples: [ColorTuple]) -> MaterialTuple? {
        for colorTuple in colorTuples {
            if let tuple = colorTuple.materialTuples[material.id] {
                return tuple
            }
        }
        return nil
    }
    private func selectionMaterialTuple(with materialTuples: [UUID: MaterialTuple]) -> MaterialTuple? {
        return materialTuples[material.id]
    }
    
    private func changeMaterialWith(isColorTuple: Bool, type: Action.SendType) {
        switch type {
        case .begin:
            oldMaterialTuple = isColorTuple ?
                selectionMaterialTuple(with: colorTuples) :
                selectionMaterialTuple(with: materialTuples)
            if let oldMaterialTuple = oldMaterialTuple {
                material = oldMaterialTuple.cutTuples[0].cells[0].material
            }
        case .sending:
            if let oldMaterialTuple = oldMaterialTuple {
                material = oldMaterialTuple.cutTuples[0].cells[0].material
            }
        case .end:
            if let oldMaterialTuple = oldMaterialTuple {
                _setMaterial(oldMaterialTuple.cutTuples[0].cells[0].material,
                             oldMaterial: oldMaterialTuple.material)
            }
            oldMaterialTuple = nil
        }
        sceneEditor.canvas.setNeedsDisplay()
    }
    private func setMaterial(_ material: Material, in materialTuple: MaterialTuple) {
        for cutTuple in materialTuple.cutTuples {
            for cell in cutTuple.cells {
                cell.material = material
            }
            for materialItemTuple in cutTuple.materialItemTuples {
                var keyMaterials = materialItemTuple.materialItem.keyMaterials
                materialItemTuple.editIndexes.forEach { keyMaterials[$0] = material }
                materialItemTuple.track.setKeyMaterials(keyMaterials,
                                                        in: materialItemTuple.materialItem)
                materialItemTuple.materialItem.cells.forEach { $0.material = material }
            }
        }
    }
    private func _setMaterial(_ material: Material, in materialTuple: MaterialTuple) {
        for cutTuple in materialTuple.cutTuples {
            _setMaterial(material, oldMaterial: materialTuple.material,
                         in: cutTuple.cells, cutTuple.cutItem)
        }
    }
    
    func changeColor(_ colorPicker: ColorPicker,
                     color: Color, oldColor: Color, type: Action.SendType) {
        switch type {
        case .begin:
            isEditing = true
            colorTuples = colorTuplesWith(color: oldColor,
                                          in: sceneEditor.scene.editCutItem,
                                          sceneEditor.scene.cutItems)
            setColor(color, in: colorTuples)
        case .sending:
            setColor(color, in: colorTuples)
        case .end:
            _setColor(color, in: colorTuples)
            colorTuples = []
            isEditing = false
        }
        changeMaterialWith(isColorTuple: true, type: type)
    }
    private func setColor(_ color: Color, in colorTuples: [ColorTuple]) {
        for colorTuple in colorTuples {
            for materialTuple in colorTuple.materialTuples.values {
                setMaterial(materialTuple.material.withColor(color), in: materialTuple)
            }
        }
    }
    private func _setColor(_ color: Color, in colorTuples: [ColorTuple]) {
        for colorTuple in colorTuples {
            for materialTuple in colorTuple.materialTuples.values {
                _setMaterial(materialTuple.material.withColor(color), in: materialTuple)
            }
        }
    }
    
    private func append(_ materialItem: MaterialItem, in track: NodeTrack, _ cutItem: CutItem) {
        undoManager?.registerUndo(withTarget: self) { $0.removeMaterialItem(in: track, cutItem) }
        track.materialItems.append(materialItem)
        cutItem.cutDataModel.isWrite = true
    }
    private func removeMaterialItem(in track: NodeTrack, _ cutItem: CutItem) {
        undoManager?.registerUndo(withTarget: self) {
            $0.append(track.materialItems[track.materialItems.count - 1], in: track, cutItem)
        }
        track.materialItems.removeLast()
        cutItem.cutDataModel.isWrite = true
    }
    
    func changeValue(_ pulldownButton: PulldownButton,
                     index: Int, oldIndex: Int, type: Action.SendType) {
//        if pulldownButton == animationButton {
//            let isAnimation = self.isAnimation
//            if index == 0 && !isAnimation {
//                let cutItem =  sceneEditor.scene.editCutItem
//                let animation = cutItem.cut.editTrack
//                let keyMaterials = animation.emptyKeyMaterials(with: material)
//                let cells = cutItem.cut.cells.filter { $0.material == material }
//                append(MaterialItem(material: material, cells: cells, keyMaterials: keyMaterials),
//                       in: animation, cutItem)
//            } else if isAnimation {
//                let cutItem =  sceneEditor.scene.editCutItem
//                removeMaterialItem(in: cutItem.cut.editTrack, cutItem)
//            }
//        } else {
            let materialType = Material.MaterialType(rawValue: Int8(index)) ?? .normal
            switch type {
            case .begin:
                isEditing = true
                materialTuples = materialTuplesWith(material: material,
                                                    in: sceneEditor.scene.editCutItem,
                                                    sceneEditor.scene.cutItems)
                setMaterialType(materialType, in: materialTuples)
            case .sending:
                setMaterialType(materialType, in: materialTuples)
            case .end:
                _setMaterialType(materialType, in: materialTuples)
                materialTuples = [:]
                isEditing = false
            }
            changeMaterialWith(isColorTuple: false, type: type)
//        }
    }
    private func setMaterialType(_ type: Material.MaterialType,
                                 in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            setMaterial(materialTuple.material.withType(type), in: materialTuple)
        }
    }
    private func _setMaterialType(_ type: Material.MaterialType,
                                  in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            _setMaterial(materialTuple.material.withType(type), in: materialTuple)
        }
    }
    
    private var oldColor = Color()
    func changeValue(_ slider: Slider, value: CGFloat, oldValue: CGFloat, type: Action.SendType) {
        let scene = sceneEditor.scene
        switch slider {
        case lineWidthSlider:
            switch type {
            case .begin:
                isEditing = true
                materialTuples = materialTuplesWith(material: material,
                                                    in: scene.editCutItem, scene.cutItems)
                setLineWidth(value, in: materialTuples)
            case .sending:
                setLineWidth(value, in: materialTuples)
            case .end:
                _setLineWidth(value, in: materialTuples)
                materialTuples = [:]
                isEditing = false
            }
        case lineStrengthSlider:
            switch type {
            case .begin:
                isEditing = true
                materialTuples = materialTuplesWith(material: material,
                                                    in: scene.editCutItem, scene.cutItems)
                setLineStrength(value, in: materialTuples)
            case .sending:
                setLineStrength(value, in: materialTuples)
            case .end:
                _setLineStrength(value, in: materialTuples)
                materialTuples = [:]
                isEditing = false
            }
        case opacitySlider:
            switch type {
            case .begin:
                isEditing = true
                materialTuples = materialTuplesWith(material: material,
                                                    in: scene.editCutItem, scene.cutItems)
                setOpacity(value, in: materialTuples)
            case .sending:
                setOpacity(value, in: materialTuples)
            case .end:
                _setOpacity(value, in: materialTuples)
                materialTuples = [:]
                isEditing = false
            }
        default:
            break
        }
        changeMaterialWith(isColorTuple: false, type: type)
    }
    private func setLineWidth(_ lineWidth: CGFloat, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            setMaterial(materialTuple.material.withLineWidth(lineWidth), in: materialTuple)
        }
    }
    private func _setLineWidth(_ lineWidth: CGFloat, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            _setMaterial(materialTuple.material.withLineWidth(lineWidth), in: materialTuple)
        }
    }
    private func setLineStrength(_ lineStrength: CGFloat, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            setMaterial(materialTuple.material.withLineStrength(lineStrength), in: materialTuple)
        }
    }
    private func _setLineStrength(_ lineStrength: CGFloat, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            _setMaterial(materialTuple.material.withLineStrength(lineStrength), in: materialTuple)
        }
    }
    private func setOpacity(_ opacity: CGFloat, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            setMaterial(materialTuple.material.withOpacity(opacity), in: materialTuple)
        }
    }
    private func _setOpacity(_ opacity: CGFloat, in materialTuples: [UUID: MaterialTuple]) {
        for materialTuple in materialTuples.values {
            _setMaterial(materialTuple.material.withOpacity(opacity), in: materialTuple)
        }
    }
}
