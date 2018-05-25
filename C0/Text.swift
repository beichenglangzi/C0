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
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return TextFormView(text: self, font: Font.default(with: sizeType),
                            frame: frame, isSizeToFit: false)
    }
}

struct TextOption {
    var defaultModel = Text()
}

final class TextFormView: View {
    var text: Text {
        didSet { updateWithModel() }
    }
    
    var textMaterial: TextMaterial {
        didSet { updateWithModel() }
    }
    var isSizeToFit: Bool {
        didSet {
            if isSizeToFit { sizeToFit() }
        }
    }
    var padding: Real {
        didSet { updateLayout() }
    }
    private var textFrame: TextFrame
    
    convenience init(text: Text = "",
                     font: Font = .default, color: Color = .locked,
                     lineColor: Color? = nil, lineWidth: Real = 0,
                     frameAlignment: TextAlignment = .left, alignment: TextAlignment = .natural,
                     frame: Rect = Rect(), padding: Real = 1, isSizeToFit: Bool = true) {
        
        let textMaterial = TextMaterial(font: font, color: color,
                                        lineColor: lineColor, lineWidth: lineWidth,
                                        frameAlignment: frameAlignment, alignment: alignment)
        self.init(text: text, textMaterial: textMaterial,
                  frame: frame, padding: padding, isSizeToFit: isSizeToFit)
    }
    init(text: Text = "", textMaterial: TextMaterial = TextMaterial(),
         frame: Rect = Rect(), padding: Real = 1, isSizeToFit: Bool = true) {
        
        self.text = text
        self.textMaterial = textMaterial
        self.isSizeToFit = isSizeToFit
        self.padding = padding
        let textFrameWidth = TextFormView.textFrameWidthWith(frame: frame, padding: padding)
        textFrame = TextFrame(string: text.currentString, textMaterial: textMaterial,
                              frameWidth: textFrameWidth)
        
        super.init(drawClosure: { $1.draw(in: $0) }, isLocked: true)
        noIndicatedLineColor = nil
        indicatedLineColor = .noBorderIndicated
        
        if isSizeToFit {
            sizeToFit()
        } else {
            self.frame = frame
            displayLinkDraw()
        }
    }
    
    override var defaultBounds: Rect {
        return textFrame.bounds(padding: padding)
    }
    override func updateLayout() {
        updateWithModel()
    }
    func updateWithModel() {
        textFrame = TextFrame(string: text.currentString, textMaterial: textMaterial,
                              frameWidth: textFrameWidth)
        if isSizeToFit { sizeToFit() }
        displayLinkDraw()
    }
    func sizeToFit() {
        frame = textMaterial.fitFrameWith(defaultBounds: defaultBounds, frame: frame)
    }
    
    var textFrameWidth: Real? {
        return TextFormView.textFrameWidthWith(frame: frame, padding: padding)
    }
    private static func textFrameWidthWith(frame: Rect, padding: Real) -> Real? {
        return frame.width == 0 ? nil : frame.width - padding * 2
    }
    
    override func draw(in ctx: CGContext) {
        textFrame.draw(in: bounds.inset(by: padding), in: ctx)
    }
}
extension TextFormView: Localizable {
    func update(with locale: Locale) {
        updateWithModel()
        sizeToFit()
    }
}
