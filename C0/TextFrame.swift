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

struct Font {
    static let small = Font(monospacedSize: 8)
    static let `default` = Font(monospacedSize: 11)
    static let smallBold = Font(boldMonospacedSize: 8)
    static let bold = Font(boldMonospacedSize: 11)
    static let smallItalic = Font(italicMonospacedSize: 8)
    static let italic = Font(italicMonospacedSize: 11)
    
    static let action = Font(boldMonospacedSize: 9)
    static let subtitle = Font(boldMonospacedSize: 20)
    
    var name: String {
        didSet {
            updateWith(name: name, size: size)
        }
    }
    var size: Real {
        didSet {
            updateWith(name: name, size: size)
        }
    }
    private(set) var ascent: Real, descent: Real, leading: Real, ctFont: CTFont
    
    init(size: Real) {
        self.init(CTFont.systemFont(ofSize: size))
    }
    init(boldSize size: Real) {
        self.init(CTFont.boldSystemFont(ofSize: size))
    }
    init(monospacedSize size: Real) {
        self.init(CTFont.monospacedSystemFont(ofSize: size))
    }
    init(boldMonospacedSize size: Real) {
        self.init(CTFont.boldMonospacedSystemFont(ofSize: size))
    }
    init(italicMonospacedSize size: Real) {
        self.init(CTFont.italicMonospacedSystemFont(ofSize: size))
    }
    init(boldItalicMonospacedSize size: Real) {
        self.init(CTFont.boldItalicMonospacedSystemFont(ofSize: size))
    }
    init(name: String, size: Real) {
        self.init(CTFontCreateWithName(name as CFString, size, nil))
    }
    init(_ ctFont: CTFont) {
        name = CTFontCopyFullName(ctFont) as String
        size = CTFontGetSize(ctFont)
        ascent = CTFontGetAscent(ctFont)
        descent = -CTFontGetDescent(ctFont)
        leading = -CTFontGetLeading(ctFont)
        self.ctFont = ctFont
    }
    
    private mutating func updateWith(name: String, size: Real) {
        ctFont = CTFontCreateWithName(name as CFString, size, nil)
        ascent = CTFontGetAscent(ctFont)
        descent = -CTFontGetDescent(ctFont)
        leading = -CTFontGetLeading(ctFont)
    }
    
    func ceilHeight(withPadding padding: Real) -> Real {
        return ceil(ascent - descent) + padding * 2
    }
}

enum TextAlignment {
    case left, center, right, natural, justified
}

extension NSAttributedStringKey {
    static let ctFont = NSAttributedStringKey(rawValue: String(kCTFontAttributeName))
    static let ctForegroundColor
        = NSAttributedStringKey(rawValue: String(kCTForegroundColorAttributeName))
    static let ctAlignment = NSAttributedStringKey(rawValue: "ctAlignment")
    static let ctForegroundColorFromContext
        = NSAttributedStringKey(rawValue: String(kCTForegroundColorFromContextAttributeName))
    static let ctBorder = NSAttributedStringKey(rawValue: "ctBorder")
}
extension NSAttributedString {
    static func attributesWith(font: Font, color: Color, border: TextBorder?,
                               alignment: TextAlignment = .natural) -> [NSAttributedStringKey: Any] {
        if let border = border {
            return [.ctFont: font.ctFont,
                    .ctForegroundColor: color.cg,
                    .ctBorder: border,
                    .ctAlignment: alignment]
        } else {
            return [.ctFont: font.ctFont,
                    .ctForegroundColor: color.cg,
                    .ctAlignment: alignment]
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
            lines = TextFrame.lineWith(attributedString: attributedString,
                                       lineBreakWidth: lineBreakWidth)
            (baselineDelta, height) = TextFrame.baselineWith(lines, baseFont: baseFont)
        }
    }
    var paddingSize: Size
    var baseFont: Font
    var baselineDelta: Real, height: Real
    var lineBreakWidth: Real {
        didSet {
            guard lineBreakWidth != oldValue else { return }
            lines = TextFrame.lineWith(attributedString: attributedString,
                                       lineBreakWidth: lineBreakWidth)
        }
    }
    
    private(set) var lines = [TextLine]() {
        didSet {
            typographicBounds = TextFrame.typographicBounds(with: lines)
        }
    }
    private(set) var typographicBounds = Rect()
    var fitSize: Size {
        return Size(width: (typographicBounds.width + paddingSize.width * 2).rounded(),
                    height: (height + baselineDelta + paddingSize.height * 2).rounded())
    }
    
    init(attributedString: NSMutableAttributedString, baseFont: Font,
         lineBreakWidth: Real = .infinity, paddingSize: Size = Size(square: 1)) {
        
        self.attributedString = attributedString
        self.baseFont = baseFont
        self.lineBreakWidth = lineBreakWidth
        self.paddingSize = paddingSize
        lines = TextFrame.lineWith(attributedString: attributedString,
                                   lineBreakWidth: lineBreakWidth)
        typographicBounds = TextFrame.typographicBounds(with: lines)
        (baselineDelta, height) = TextFrame.baselineWith(lines, baseFont: baseFont)
    }
    init(string: String = "", textMaterial: TextMaterial,
         lineBreakWidth: Real = .infinity, paddingSize: Size = Size(square: 1)) {
        
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
                  baseFont: textMaterial.font,
                  lineBreakWidth: lineBreakWidth, paddingSize: paddingSize)
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
    private static func lineWith(attributedString: NSAttributedString,
                                 lineBreakWidth: Real) -> [TextLine] {
        let typesetter = CTTypesetterCreateWithAttributedString(attributedString)
        let length = attributedString.length
        var range = CFRange(), h = 0.0.cg, maxWidth = 0.0.cg
        var ls = [(ctLine: CTLine, ascent: Real, descent: Real, leading: Real, width: Real)]()
        while range.maxLocation < length {
            range.length = CTTypesetterSuggestLineBreak(typesetter, range.location,
                                                        Double(lineBreakWidth))
            let ctLine = CTTypesetterCreateLine(typesetter, range)
            var ascent = 0.0.cg, descent = 0.0.cg, leading =  0.0.cg
            let lineWidth = CTLineGetTypographicBounds(ctLine, &ascent, &descent, &leading).cg
            maxWidth = max(lineWidth, maxWidth)
            ls.append((ctLine, ascent, descent, leading, lineWidth))
            range = CFRange(location: range.maxLocation, length: 0)
            h += ascent + descent + leading
        }
        maxWidth = maxWidth.rounded()
        let width = lineBreakWidth.isInfinite ? maxWidth : lineBreakWidth
        var origin = Point()
        return ls.reversed().map {
            origin.y += $0.descent + $0.leading
            let runs = $0.ctLine.runs.map { TextRun(ctRun: $0) }
            var lineOrigin = origin
            if let run = runs.first {
                if let attributes = CTRunGetAttributes(run.ctRun) as? [NSAttributedStringKey: Any],
                    let textAlignment = attributes[.ctAlignment] as? TextAlignment {
                    
                    if textAlignment == .right {
                        lineOrigin.x += width - $0.width
                    }
                }
            }
            let result = TextLine(ctLine: $0.ctLine, origin: lineOrigin, runs: runs)
            origin.y += $0.ascent
            return result
        }.reversed()
    }
    static func typographicBounds(with lines: [TextLine]) -> Rect {
        return lines.reduce(into: Rect.null) {
            let bounds = $1.typographicBounds
            $0.formUnion(Rect(origin: $1.origin + bounds.origin, size: bounds.size))
        }
    }
}
extension TextFrame {
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
        let bounds = bounds.insetBy(dx: paddingSize.width, dy: paddingSize.height)
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
}
extension TextLine {
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
            return .null
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
        CTRunDraw(ctRun, ctx, CFRangeMake(0, 0))
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
