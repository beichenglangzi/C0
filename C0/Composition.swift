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

import CoreGraphics

enum BlendType: Int8, Codable, Hashable {
    case normal, addition, subtract
}
extension BlendType: Referenceable {
    static let name = Text(english: "Blend Type", japanese: "合成タイプ")
}
extension BlendType: DisplayableText {
    var displayText: Text {
        switch self {
        case .normal: return Text(english: "Normal", japanese: "通常")
        case .addition: return Text(english: "Addition", japanese: "加算")
        case .subtract: return Text(english: "Subtract", japanese: "減算")
        }
    }
    static var displayTexts: [Text] {
        return [normal.displayText,
                addition.displayText,
                subtract.displayText]
    }
}
extension BlendType {
    static var defaultOption: EnumOption<BlendType> {
        return EnumOption(cationModels: [],
                          indexClosure: { Int($0) },
                          rawValueClosure: { BlendType.RawValue($0) },
                          names: BlendType.displayTexts)
    }
}
extension BlendType: Viewable {
    func standardViewWith<T: BinderProtocol>
        (binder: T, keyPath: ReferenceWritableKeyPath<T, BlendType>) -> ModelView {
        
        return EnumView(binder: binder, keyPath: keyPath, option: BlendType.defaultOption)
    }
}
extension BlendType: ObjectViewable {}

struct Composition<T: Equatable>: Equatable {
    var value: T
    var opacity = 1.0.cg
    var blendType = BlendType.normal
    
    init(value: T, opacity: Real = 1, blendType: BlendType = .normal) {
        self.value = value
        self.opacity = opacity
        self.blendType = blendType
    }
}

extension Composition where T == Color {
    static let translucentEdit = Composition(value: Color(white: 0), opacity: 0.1)
    static let select = Composition(value: Color(red: 0, green: 0.7, blue: 1), opacity: 0.3)
    static let selectBorder = Composition(value: Color(red: 0, green: 0.5, blue: 1), opacity: 0.5)
    static let deselect = Composition(value: Color(red: 0.9, green: 0.3, blue: 0), opacity: 0.3)
    static let deselectBorder = Composition(value: Color(red: 1, green: 0, blue: 0), opacity: 0.5)
    
    func multiply(alpha: Real) -> Composition<Color> {
        return Composition(value: Color(hue: value.hue,
                                        saturation: value.saturation,
                                        lightness: value.lightness),
                           opacity: self.opacity * alpha)
    }
    
    var cgColor: CGColor {
        let rgb = value.rgb, rgbColorSpace = value.rgbColorSpace
        return CGColor.with(rgb: rgb, alpha: opacity, colorSpace: CGColorSpace.with(rgbColorSpace))
    }
}
