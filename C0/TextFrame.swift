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

import struct Foundation.NSRange
import struct Foundation.NSAttributedStringKey
import class Foundation.NSAttributedString
import class Foundation.NSMutableAttributedString
import CoreText

enum TextAlignment {
    case left, center, right, natural, justified
    fileprivate var ct: CTTextAlignment {
        switch self {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        case .natural: return .natural
        case .justified: return .justified
        }
    }
}

extension NSAttributedStringKey {
    static let ctFont = NSAttributedStringKey(rawValue: String(kCTFontAttributeName))
    static let ctForegroundColor
        = NSAttributedStringKey(rawValue: String(kCTForegroundColorAttributeName))
    static let ctParagraphStyle
        = NSAttributedStringKey(rawValue: String(kCTParagraphStyleAttributeName))
    static let ctForegroundColorFromContext
        = NSAttributedStringKey(rawValue: String(kCTForegroundColorFromContextAttributeName))
    static let ctBorder = NSAttributedStringKey(rawValue: "ctBorder")
}
extension NSAttributedString {
    static func attributesWith(font: Font, color: Color, border: TextBorder?,
                               alignment: TextAlignment = .natural) -> [NSAttributedStringKey: Any] {
        var alignment = alignment.ct
        let settings = [CTParagraphStyleSetting(spec: .alignment,
                                                valueSize: MemoryLayout<CTTextAlignment>.size,
                                                value: &alignment)]
        let style = CTParagraphStyleCreate(settings, settings.count)
        if let border = border {
            return [.ctFont: font.ctFont,
                    .ctForegroundColor: color.cg,
                    .ctBorder: border,
                    .ctParagraphStyle: style]
        } else {
            return [.ctFont: font.ctFont,
                    .ctForegroundColor: color.cg,
                    .ctParagraphStyle: style]
        }
    }
}

struct TextMaterial {
    var font: Font, color: Color, lineColor: Color?, lineWidth: Real
    var frameAlignment: TextAlignment, alignment: TextAlignment
    
    init(font: Font = .default, color: Color = .locked,
         lineColor: Color? = nil, lineWidth: Real = 0,
         frameAlignment: TextAlignment = .left, alignment: TextAlignment = .natural) {
        
        self.font = font
        self.color = color
        self.lineColor = lineColor
        self.lineWidth = lineWidth
        self.frameAlignment = frameAlignment
        self.alignment = alignment
    }
    
    func fitFrameWith(defaultBounds: Rect, frame: Rect) -> Rect {
        let size = defaultBounds.size
        let y = frame.maxY - size.height
        let origin = frameAlignment == .right ?
            Point(x: frame.maxX - size.width, y: y) :
            Point(x: frame.origin.x, y: y)
        return Rect(origin: origin, size: size)
    }
}

struct TextBorder {
    var lineColor: CGColor, lineWidth = 0.0.cg
}

struct TextFrame {
    var attributedString = NSMutableAttributedString() {
        didSet {
            self.lines = TextFrame.lineWith(attributedString: attributedString,
                                            frameWidth: frameWidth)
            
            (baselineDelta, height) = TextFrame.baselineWith(lines, baseFont: baseFont)
        }
    }
    
    var baseFont: Font
    var baselineDelta: Real, height: Real
    
    var frameWidth: Real? {
        didSet {
            guard frameWidth != oldValue else { return }
            lines = TextFrame.lineWith(attributedString: attributedString, frameWidth: frameWidth)
        }
    }
    
    private(set) var typographicBounds = Rect()
    
    init(attributedString: NSMutableAttributedString, baseFont: Font, frameWidth: Real? = nil) {
        self.attributedString = attributedString
        self.baseFont = baseFont
        self.frameWidth = frameWidth
        lines = TextFrame.lineWith(attributedString: attributedString, frameWidth: frameWidth)
        typographicBounds = TextFrame.typographicBounds(with: lines)
        (baselineDelta, height) = TextFrame.baselineWith(lines, baseFont: baseFont)
    }
    init(string: String = "", textMaterial: TextMaterial, frameWidth: Real? = nil) {
        let border: TextBorder?
        if let borderColor = textMaterial.lineColor, textMaterial.lineWidth > 0 {
            border = TextBorder(lineColor: borderColor.cg, lineWidth: textMaterial.lineWidth)
        } else {
            border = nil
        }
        let attributes = NSAttributedString.attributesWith(font: textMaterial.font,
                                                           color: textMaterial.color,
                                                           border: border,
                                                           alignment: textMaterial.alignment)
        let attributedString = NSMutableAttributedString(string: string, attributes: attributes)
        self.init(attributedString: attributedString,
                  baseFont: textMaterial.font, frameWidth: frameWidth)
    }
    
    private static func baselineWith(_ lines: [TextLine],
                                     baseFont: Font) -> (baselineDelta: Real, height: Real) {
        if let firstLine = lines.first, let lastLine = lines.last {
            return (-lastLine.origin.y - baseFont.descent,
                    firstLine.origin.y + baseFont.ascent)
        } else {
            return (-baseFont.descent, baseFont.ascent)
        }
    }
    
    func bounds(padding: Real) -> Rect {
        let w = frameWidth ?? ceil(typographicBounds.width)
        return Rect(x: 0, y: 0,
                    width: max(w + padding * 2, 5),
                    height: ceil(height + baselineDelta) + padding * 2)
    }
    
    var lines = [TextLine]() {
        didSet {
            self.typographicBounds = TextFrame.typographicBounds(with: lines)
        }
    }
    private static func lineWith(attributedString: NSAttributedString,
                                 frameWidth: Real?) -> [TextLine] {
        let width = Double(frameWidth ?? Real.infinity)
        let typesetter = CTTypesetterCreateWithAttributedString(attributedString)
        let length = attributedString.length
        var range = CFRange(), h = 0.0.cg
        var ls = [(ctLine: CTLine, ascent: Real, descent: Real, leading: Real)]()
        while range.maxLocation < length {
            range.length = CTTypesetterSuggestLineBreak(typesetter, range.location, width)
            let ctLine = CTTypesetterCreateLine(typesetter, range)
            var ascent = 0.0.cg, descent = 0.0.cg, leading =  0.0.cg
            _ = CTLineGetTypographicBounds(ctLine, &ascent, &descent, &leading)
            ls.append((ctLine, ascent, descent, leading))
            range = CFRange(location: range.maxLocation, length: 0)
            h += ascent + descent + leading
        }
        var origin = Point()
        return ls.reversed().map {
            origin.y += $0.descent + $0.leading
            let runs = $0.ctLine.runs.map { TextRun(ctRun: $0) }
            let result = TextLine(ctLine: $0.ctLine, origin: origin, runs: runs)
            origin.y += $0.ascent
            return result
        }.reversed()
    }
    
    func line(for point: Point) -> TextLine? {
        guard let lastLine = lines.last else {
            return nil
        }
        for line in lines {
            let bounds = line.typographicBounds
            let tb = Rect(origin: line.origin + bounds.origin, size: bounds.size)
            if point.y >= tb.minY {
                return line
            }
        }
        return lastLine
    }
    
    func editCharacterIndex(for point: Point) -> Int {
        guard !lines.isEmpty else {
            return 0
        }
        for line in lines {
            let bounds = line.typographicBounds
            let tb = Rect(origin: line.origin + bounds.origin, size: bounds.size)
            if point.y >= tb.minY {
                return line.editCharacterIndex(for: point - tb.origin)
            }
        }
        return attributedString.length - 1
    }
    func characterIndex(for point: Point) -> Int {
        guard !lines.isEmpty else {
            return 0
        }
        for line in lines {
            let bounds = line.typographicBounds
            let tb = Rect(origin: line.origin + bounds.origin, size: bounds.size)
            if point.y >= tb.minY {
                return line.characterIndex(for: point - tb.origin)
            }
        }
        return attributedString.length - 1
    }
    func characterFraction(for point: Point) -> Real {
        guard let line = self.line(for: point) else {
            return 0.0
        }
        return line.characterFraction(for: point - line.origin)
    }
    func characterOffset(at i: Int) -> Real {
        let lines = self.lines
        for line in lines {
            if line.contains(at: i) {
                return line.characterOffset(at: i)
            }
        }
        return 0.5
    }
    var imageBounds: Rect {
        let lineAndOrigins = self.lines
        return lineAndOrigins.reduce(into: Rect.null) {
            var imageBounds = $1.imageBounds
            imageBounds.origin += $1.origin
            $0.formUnion(imageBounds)
        }
    }
    static func typographicBounds(with lines: [TextLine]) -> Rect {
        return lines.reduce(into: Rect.null) {
            let bounds = $1.typographicBounds
            $0.formUnion(Rect(origin: $1.origin + bounds.origin, size: bounds.size))
        }
    }
    func typographicBounds(for range: NSRange) -> Rect {
        return lines.reduce(into: Rect.null) {
            let bounds = $1.typographicBounds(for: range)
            $0.formUnion(Rect(origin: $1.origin + bounds.origin, size: bounds.size))
        }
    }
    func baselineDelta(at i: Int) -> Real {
        for line in lines {
            if line.contains(at: i) {
                return line.baselineDelta(at: i)
            }
        }
        return 0.0
    }
    
    func draw(in bounds: Rect, in ctx: CGContext) {
        guard let firstLine = lines.first else { return }
        ctx.saveGState()
        let height = firstLine.origin.y + baseFont.ascent
        ctx.translateBy(x: bounds.origin.x, y: bounds.maxY - height)
        lines.forEach { $0.draw(in: ctx) }
        ctx.restoreGState()
    }
    func drawWithCenterOfImageBounds(in bounds: Rect, in ctx: CGContext) {
        let imageBounds = self.imageBounds
        ctx.saveGState()
        ctx.translateBy(x: bounds.midX - imageBounds.midX, y: bounds.midY - imageBounds.midY)
        lines.forEach { $0.draw(in: ctx) }
        ctx.restoreGState()
    }
}

struct TextLine {
    let ctLine: CTLine
    let origin: Point
    let runs: [TextRun]
    
    func contains(at i: Int) -> Bool {
        let range = CTLineGetStringRange(ctLine)
        return i >= range.location && i < range.location + range.length
    }
    func contains(for range: NSRange) -> Bool {
        let lineRange = CTLineGetStringRange(ctLine)
        return !(range.location >= lineRange.location + lineRange.length
            || range.location + range.length <= lineRange.location)
    }
    var typographicBounds: Rect {
        var ascent = 0.0.cg, descent = 0.0.cg, leading = 0.0.cg
        let width = CTLineGetTypographicBounds(ctLine, &ascent, &descent, &leading).cg
            + CTLineGetTrailingWhitespaceWidth(ctLine).cg
        return Rect(x: 0, y: -descent - leading,
                    width: width, height: ascent + descent + leading)
    }
    func typographicBounds(for range: NSRange) -> Rect {
        guard contains(for: range) else {
            return Rect.null
        }
        return ctLine.runs.reduce(into: Rect.null) {
            var origin = Point()
            CTRunGetPositions($1, CFRange(location: range.location, length: 1), &origin)
            let bounds = $1.typographicBounds(for: range)
            $0.formUnion(Rect(origin: origin + bounds.origin, size: bounds.size))
        }
    }
    func editCharacterIndex(for point: Point) -> Int {
        return CTLineGetStringIndexForPosition(ctLine, point)
    }
    func characterIndex(for point: Point) -> Int {
        let range = CTLineGetStringRange(ctLine)
        guard range.length > 0 else {
            return range.location
        }
        for i in range.location..<range.maxLocation {
            var offset = 0.0.cg
            CTLineGetOffsetForStringIndex(ctLine, i + 1, &offset)
            if point.x < offset {
                return i
            }
        }
        return range.maxLocation - 1
    }
    func characterFraction(for point: Point) -> Real {
        let i = characterIndex(for: point)
        if i < CTLineGetStringRange(ctLine).maxLocation {
            let x = characterOffset(at: i)
            let nextX = characterOffset(at: i + 1)
            return (point.x - x) / (nextX - x)
        }
        return 0.0
    }
    func characterOffset(at i: Int) -> Real {
        var offset = 0.0.cg
        CTLineGetOffsetForStringIndex(ctLine, i, &offset)
        return offset
    }
    func baselineDelta(at i: Int) -> Real {
        var descent = 0.0.cg, leading = 0.0.cg
        _ = CTLineGetTypographicBounds(ctLine, nil, &descent, &leading)
        return descent + leading
    }
    var imageBounds: Rect {
        return CTLineGetImageBounds(ctLine, nil)
    }
    
    func draw(in ctx: CGContext) {
        ctx.textPosition = origin
        runs.forEach { $0.draw(in: ctx) }
    }
}

struct TextRun {
    let ctRun: CTRun
    
    var color: CGColor? {
        let attributes = CTRunGetAttributes(ctRun) as? [NSAttributedStringKey: Any] ?? [:]
        let colorAttribute = attributes[.foregroundColor]
        return colorAttribute != nil ? colorAttribute as! CGColor : CGColor.black
    }
    
    func draw(in ctx: CGContext) {
        let attributes = CTRunGetAttributes(ctRun) as? [NSAttributedStringKey: Any] ?? [:]
        if let textBorder = attributes[.ctBorder] as? TextBorder {
            ctx.saveGState()
            ctx.setAllowsFontSmoothing(false)
            ctx.setTextDrawingMode(.stroke)
            ctx.setLineWidth(textBorder.lineWidth)
            ctx.setStrokeColor(textBorder.lineColor)
            CTRunDraw(ctRun, ctx, CTRunGetStringRange(ctRun))
            ctx.restoreGState()
        }
        CTRunDraw(ctRun, ctx, CTRunGetStringRange(ctRun))
    }
}

extension CFRange {
    var maxLocation: Int {
        return location + length
    }
}
extension CTLine {
    var runs: [CTRun] {
        return CTLineGetGlyphRuns(self) as? [CTRun] ?? []
    }
}
extension CTRun {
    func typographicBounds(for range: NSRange) -> Rect {
        var ascent = 0.0.cg, descent = 0.0.cg, leading = 0.0.cg
        let range = CFRange(location: range.location, length: range.length)
        let width = CTRunGetTypographicBounds(self, range, &ascent, &descent, &leading).cg
        return Rect(x: 0, y: -descent, width: width, height: ascent + descent)
    }
}
