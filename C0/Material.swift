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

struct Material: Codable, Hashable {
    enum MaterialType: Int8, Codable {
        case normal, lineless, blur, luster, addition, subtract
        
        var isDrawLine: Bool {
            return self == .normal
        }
        var blendType: BlendType {
            switch self {
            case .normal, .lineless, .blur: return .normal
            case .luster, .addition: return .addition
            case .subtract: return .subtract
            }
        }
    }
    
    static let defaultLineWidth = 1.0.cg
    
    var type = MaterialType.normal
    var color = Color.random(), lineColor = Color.black
    var lineWidth = defaultLineWidth, opacity = 1.0.cg
}
extension Material: Referenceable {
    static let name = Text(english: "Material", japanese: "マテリアル")
}
extension Material: Interpolatable {
    static func linear(_ f0: Material, _ f1: Material, t: Real) -> Material {
        let type = f0.type
        let color = Color.linear(f0.color, f1.color, t: t)
        let lineColor = Color.linear(f0.lineColor, f1.lineColor, t: t)
        let lineWidth = Real.linear(f0.lineWidth, f1.lineWidth, t: t)
        let opacity = Real.linear(f0.opacity, f1.opacity, t: t)
        return Material(type: type,
                        color: color, lineColor: lineColor,
                        lineWidth: lineWidth, opacity: opacity)
    }
    static func firstMonospline(_ f1: Material, _ f2: Material, _ f3: Material,
                                with ms: Monospline) -> Material {
        let type = f1.type
        let color = Color.firstMonospline(f1.color, f2.color, f3.color, with: ms)
        let lineColor = Color.firstMonospline(f1.lineColor, f2.lineColor, f3.lineColor, with: ms)
        let lineWidth = Real.firstMonospline(f1.lineWidth, f2.lineWidth, f3.lineWidth, with: ms)
        let opacity = Real.firstMonospline(f1.opacity, f2.opacity, f3.opacity, with: ms)
        return Material(type: type,
                        color: color, lineColor: lineColor,
                        lineWidth: lineWidth, opacity: opacity)
    }
    static func monospline(_ f0: Material, _ f1: Material, _ f2: Material, _ f3: Material,
                           with ms: Monospline) -> Material {
        let type = f1.type
        let color = Color.monospline(f0.color, f1.color, f2.color, f3.color, with: ms)
        let lineColor = Color.monospline(f0.lineColor, f1.lineColor,
                                         f2.lineColor, f3.lineColor, with: ms)
        let lineWidth = Real.monospline(f0.lineWidth, f1.lineWidth,
                                        f2.lineWidth, f3.lineWidth, with: ms)
        let opacity = Real.monospline(f0.opacity, f1.opacity, f2.opacity, f3.opacity, with: ms)
        return Material(type: type,
                        color: color, lineColor: lineColor,
                        lineWidth: lineWidth, opacity: opacity)
    }
    static func lastMonospline(_ f0: Material, _ f1: Material, _ f2: Material,
                               with ms: Monospline) -> Material {
        let type = f1.type
        let color = Color.lastMonospline(f0.color, f1.color, f2.color, with: ms)
        let lineColor = Color.lastMonospline(f0.lineColor, f1.lineColor, f2.lineColor, with: ms)
        let lineWidth = Real.lastMonospline(f0.lineWidth, f1.lineWidth, f2.lineWidth, with: ms)
        let opacity = Real.lastMonospline(f0.opacity, f1.opacity, f2.opacity, with: ms)
        return Material(type: type,
                        color: color, lineColor: lineColor,
                        lineWidth: lineWidth, opacity: opacity)
    }
}
extension Material: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return View(frame: frame, fillColor: color, isLocked: true)
    }
}
extension Material.MaterialType: Referenceable {
    static let uninheritanceName = Text(english: "Type", japanese: "タイプ")
    static let name = Material.name.spacedUnion(uninheritanceName)
}
extension Material: Initializable {}
extension Material: KeyframeValue {}
extension Material.MaterialType: DisplayableText {
    var displayText: Text {
        switch self {
        case .normal: return Text(english: "Normal", japanese: "通常")
        case .lineless: return Text(english: "Lineless", japanese: "線なし")
        case .blur: return Text(english: "Blur", japanese: "ぼかし")
        case .luster: return Text(english: "Luster", japanese: "光沢")
        case .addition: return Text(english: "Addition", japanese: "加算")
        case .subtract: return Text(english: "Subtract", japanese: "減算")
        }
    }
    static var displayTexts: [Text] {
        return [normal.displayText,
                lineless.displayText,
                blur.displayText,
                luster.displayText,
                addition.displayText,
                subtract.displayText]
    }
}

struct MaterialTrack: Track, Codable {
    private(set) var animation = Animation<Material>()
    var animatable: Animatable {
        return animation
    }
}

struct MaterialOption {
    var typeOption = EnumOption(defaultModel: Material.MaterialType.normal, cationModels: [],
                                     indexClosure: { Int($0) },
                                     rawValueClosure: { Material.MaterialType.RawValue($0) },
                                     names: Material.MaterialType.displayTexts)
    var lineWidthOption = RealOption(defaultModel: 0, minModel: 0, maxModel: 1000,
                                      modelInterval: 0.1, exp: 3, numberOfDigits: 0, unit: "")
    var opacityOption = RealOption.opacity
}

struct MaterialLayout {
    static let width = 200.0.cg, rightWidth = 60.0.cg
}

final class MaterialView<T: BinderProtocol>: View, BindableReceiver {
    typealias Model = Material
    typealias ModelOption = MaterialOption
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var defaultModel = Model()
    
    var option: ModelOption {
        didSet {
            typeView.option = option.typeOption
            lineWidthView.option = option.lineWidthOption
            opacityView.option = option.opacityOption
            updateWithModel()
        }
    }
    
    let typeView: EnumView<Material.MaterialType, Binder>
    let colorView: ColorView<Binder>
    let lineWidthView: DiscreteRealView<Binder>
    let opacityView: SlidableRealView<Binder>
    let lineColorView: ColorView<Binder>
    
    let classNameView = TextFormView(text: Material.name, font: .bold)
    private let lineColorNameView = TextFormView(text: Text(english: "Line Color:",
                                                            japanese: "線のカラー:"))
    
    init(binder: T, keyPath: BinderKeyPath,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        typeView = EnumView(binder: binder, keyPath: keyPath.appending(path: \Model.type),
                            option: option.typeOption, sizeType: sizeType)
        colorView = ColorView(binder: binder, keyPath: keyPath.appending(path: \Model.color),
                              sizeType: sizeType)
        lineWidthView = DiscreteRealView(binder: binder,
                                         keyPath: keyPath.appending(path: \Model.lineWidth),
                                         option: option.lineWidthOption, sizeType: sizeType)
        opacityView = SlidableRealView(binder: binder,
                                       keyPath: keyPath.appending(path: \Model.opacity),
                                       option: option.opacityOption, sizeType: sizeType)
        lineColorView = ColorView(binder: binder, keyPath: keyPath.appending(path: \Model.lineColor),
                                  hLineWidth: 2, hWidth: 8, slPadding: 4, sizeType: .small)
        
        super.init()
        children = [classNameView,
                    typeView,
                    colorView, lineColorNameView, lineColorView,
                    lineWidthView, opacityView]
        self.frame = frame
    }
    
    override var defaultBounds: Rect {
        let padding = Layout.basicPadding, h = Layout.basicHeight, cw = MaterialLayout.width
        return Rect(x: 0, y: 0,
                    width: cw + MaterialLayout.rightWidth + padding * 2,
                    height: cw + classNameView.frame.height + h + padding * 2)
    }
    func defaultBounds(withWidth width: Real) -> Rect {
        let padding = Layout.basicPadding, h = Layout.basicHeight
        let cw = width - MaterialLayout.rightWidth + padding * 2
        return Rect(x: 0, y: 0,
                    width: cw + MaterialLayout.rightWidth + padding * 2,
                    height: cw + classNameView.frame.height + h + padding * 2)
    }
    override func updateLayout() {
        let padding = Layout.basicPadding, h = Layout.basicHeight, rw = MaterialLayout.rightWidth
        let cw = bounds.width - rw - padding * 2
        classNameView.frame.origin = Point(x: padding,
                                           y: bounds.height - classNameView.frame.height - padding)
        let tx = classNameView.frame.maxX + padding
        typeView.frame = Rect(x: tx,
                              y: bounds.height - h * 2 - padding,
                              width: bounds.width - tx - padding, height: h * 2)
        colorView.frame = Rect(x: padding, y: padding, width: cw, height: cw)
        lineColorNameView.frame.origin = Point(x: padding + cw,
                                                    y: padding + cw - lineColorNameView.frame.height)
        lineColorView.frame = Rect(x: padding + cw, y: lineColorNameView.frame.minY - rw,
                                   width: rw, height: rw)
        lineWidthView.frame = Rect(x: padding + cw, y: lineColorView.frame.minY - h,
                                   width: rw, height: h)
        let opacityFrame = Rect(x: padding + cw, y: lineColorView.frame.minY - h * 2,
                                width: rw, height: h)
        opacityView.updateOpacityViews(withFrame: opacityFrame)
    }
    func updateWithModel() {
        typeView.updateWithModel()
        colorView.updateWithModel()
        lineColorView.updateWithModel()
        lineWidthView.updateWithModel()
        opacityView.updateWithModel()
    }
}
extension MaterialView: Localizable {
    func update(with locale: Locale) {
        updateLayout()
    }
}
extension MaterialView: Queryable {
    static var referenceableType: Referenceable.Type {
        return Model.self
    }
}
extension MaterialView: Assignable {
    func delete(for p: Point, _ version: Version) {
        push(defaultModel, to: version)
    }
    func copiedObjects(at p: Point) -> [Object] {
        return [Object(model)]
    }
    func paste(_ objects: [Any], for p: Point, _ version: Version) {
        for object in objects {
            if let model = object as? Model {
                push(model, to: version)
                return
            }
        }
    }
}
