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

import struct Foundation.Locale
import class CoreGraphics.CGContext

protocol Referenceable {
    static var uninheritanceName: Text { get }
    static var name: Text { get }
}
extension Referenceable {
    static var uninheritanceName: Text {
        return name
    }
}

struct Text: Codable, Equatable {
    var baseLanguageCode: String, base: String, values: [String: String]
    
    init() {
        baseLanguageCode = "en"
        base = ""
        values = [:]
    }
    init(baseLanguageCode: String, base: String, values: [String: String]) {
        self.baseLanguageCode = baseLanguageCode
        self.base = base
        self.values = values
    }
    init(_ noLocalizeString: String) {
        baseLanguageCode = "en"
        base = noLocalizeString
        values = [:]
    }
    init(english: String, japanese: String) {
        baseLanguageCode = "en"
        base = english
        values = ["ja": japanese]
    }
    var currentString: String {
        return string(with: Locale.current)
    }
    func string(with locale: Locale) -> String {
        if let languageCode = locale.languageCode, let value = values[languageCode] {
            return value
        }
        return base
    }
    var isEmpty: Bool {
        return base.isEmpty
    }
    func spacedUnion(_ other: Text) -> Text {
        var values = self.values
        if other.values.isEmpty {
            self.values.forEach { values[$0.key] = (values[$0.key] ?? "") + other.base }
        } else {
            for v in other.values {
                values[v.key] = (self.values[v.key] ?? self.base) + v.value
            }
        }
        return Text(baseLanguageCode: baseLanguageCode,
                            base: base + " " + other.base,
                            values: values)
    }
    static func +(lhs: Text, rhs: Text) -> Text {
        var values = lhs.values
        if rhs.values.isEmpty {
            lhs.values.forEach { values[$0.key] = (values[$0.key] ?? "") + rhs.base }
        } else {
            for v in rhs.values {
                values[v.key] = (lhs.values[v.key] ?? lhs.base) + v.value
            }
        }
        return Text(baseLanguageCode: lhs.baseLanguageCode,
                            base: lhs.base + rhs.base,
                            values: values)
    }
    static func +=(lhs: inout Text, rhs: Text) {
        var values = lhs.values
        if rhs.values.isEmpty {
            lhs.values.forEach { values[$0.key] = (values[$0.key] ?? "") + rhs.base }
        } else {
            for v in rhs.values {
                values[v.key] = (lhs.values[v.key] ?? lhs.base) + v.value
            }
        }
        lhs.base = lhs.base + rhs.base
        lhs.values = values
    }
}
extension Text: ExpressibleByStringLiteral {
    typealias StringLiteralType = String
    init(stringLiteral value: String) {
        self.init(value)
    }
}
extension Text: Initializable {}
extension Text: Referenceable {
    static let name = Text(english: "Text", japanese: "テキスト")
}
extension Text: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect) -> View {
        let view = TextFormView(text: self, font: .small)
        view.frame = frame
        return view
    }
}
extension Text: AbstractViewable {
    func abstractViewWith<T : BinderProtocol>(binder: T,
                                              keyPath: ReferenceWritableKeyPath<T, Text>,
                                              type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return TextGetterView(binder: binder, keyPath: keyPath,
                                  textMaterial: TextMaterial(font: .default))
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath)
        }
    }
}
extension Text: ObjectViewable {}

protocol TextViewProtocol {
    var text: Text { get }
    func updateText()
}

final class TextFormView: View, TextViewProtocol, LayoutMinSize {
    var text: Text {
        didSet { updateText() }
    }
    
    var textMaterial: TextMaterial {
        didSet { updateText() }
    }
    var lineBreakWidth: Real? {
        didSet { updateText() }
    }
    var paddingSize: Size {
        didSet { updateText() }
    }
    private var textFrame: TextFrame {
        didSet { displayLinkDraw() }
    }
    
    convenience init(text: Text = "",
                     font: Font = .default, color: Color = .locked,
                     lineColor: Color? = nil, lineWidth: Real = 0,
                     alignment: TextAlignment = .natural,
                     lineBreakWidth: Real? = .infinity,
                     paddingSize: Size = Size(square: 1)) {
        let textMaterial = TextMaterial(font: font, color: color,
                                        lineColor: lineColor, lineWidth: lineWidth,
                                        alignment: alignment)
        self.init(text: text, textMaterial: textMaterial,
                  lineBreakWidth: lineBreakWidth, paddingSize: paddingSize)
    }
    init(text: Text = "", textMaterial: TextMaterial = TextMaterial(),
         lineBreakWidth: Real? = .infinity, paddingSize: Size = Size(square: 1)) {
        
        self.text = text
        self.textMaterial = textMaterial
        self.lineBreakWidth = lineBreakWidth
        self.paddingSize = paddingSize
        textFrame = TextFrame(string: text.currentString,
                              textMaterial: textMaterial,
                              lineBreakWidth: lineBreakWidth ?? 0,
                              paddingSize: paddingSize)
        
        super.init(drawClosure: { ctx, view, _ in view.draw(in: ctx) })
        lineColor = nil
    }
    
    var minSize: Size {
        if lineBreakWidth == nil {
            return Size(width: Layouter.defaultMinWidth, height: Layouter.basicTextHeight)
        } else {
            return textFrame.fitSize
        }
    }
    override func updateLayout() {
        updateText()
    }
    func updateText() {
        textFrame = TextFrame(string: text.currentString,
                              textMaterial: textMaterial,
                              lineBreakWidth: lineBreakWidth ?? frame.width - paddingSize.width * 2,
                              paddingSize: paddingSize)
    }
    
    override func draw(in ctx: CGContext) {
        textFrame.draw(in: bounds, in: ctx)
    }
}

final class TextGetterView<T: BinderProtocol>: ModelView, TextViewProtocol, BindableGetterReceiver {
    typealias Model = Text
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    
    var text: Text {
        return model
    }
    var textMaterial: TextMaterial {
        didSet { updateWithModel() }
    }
    var lineBreakWidth: Real? {
        didSet { updateText() }
    }
    var paddingSize: Size {
        didSet { updateText() }
    }
    private var textFrame: TextFrame {
        didSet { displayLinkDraw() }
    }
    
    init(binder: Binder, keyPath: BinderKeyPath, textMaterial: TextMaterial = TextMaterial(),
         lineBreakWidth: Real? = .infinity, paddingSize: Size = Size(square: 1)) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        self.textMaterial = textMaterial
        self.lineBreakWidth = lineBreakWidth
        self.paddingSize = paddingSize
        
        textFrame = TextFrame(string: binder[keyPath: keyPath].currentString,
                              textMaterial: textMaterial,
                              lineBreakWidth: lineBreakWidth ?? 0,
                              paddingSize: paddingSize)
        
        super.init(drawClosure: { ctx, view, _ in view.draw(in: ctx) }, isLocked: false)
        lineColor = .getBorder
    }
    
    var minSize: Size {
        if lineBreakWidth == nil {
            return Size(width: Layouter.defaultMinWidth, height: Layouter.basicTextHeight)
        } else {
            return textFrame.fitSize
        }
    }
    override func updateLayout() {
        updateText()
    }
    func updateText() {
        textFrame = TextFrame(string: model.currentString,
                              textMaterial: textMaterial,
                              lineBreakWidth: lineBreakWidth ?? frame.width - paddingSize.width * 2,
                              paddingSize: paddingSize)
    }
    func updateWithModel() {
        updateText()
    }
    
    override func draw(in ctx: CGContext) {
        textFrame.draw(in: bounds, in: ctx)
    }
}
