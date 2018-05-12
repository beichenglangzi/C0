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

struct Text: Codable, Equatable {
    var baseLanguageCode: String, base: String, values: [String: String]
    
    init() {
        baseLanguageCode = "en"
        base = ""
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
extension Text: Thumbnailable {
    func thumbnail(withBounds bounds: Rect, _ sizeType: SizeType) -> View {
        return TextView(text: self, font: Font.default(with: sizeType),
                        frame: bounds, isSizeToFit: false)
    }
}
extension Text: CompactViewable {}

protocol Namable {
    var name: Text { get }
}

extension String {
    var calculate: String {
        return (NSExpression(format: self)
            .expressionValue(with: nil, context: nil) as? NSNumber)?.stringValue ?? "Error"
    }
    var suffixNumber: Int? {
        if let numberString = components(separatedBy: NSCharacterSet.decimalDigits.inverted).last {
            return Int(numberString)
        } else {
            return nil
        }
    }
    func union(_ other: String, space: String = " ") -> String {
        return other.isEmpty ? self : (isEmpty ? other : self + space + other)
    }
}
extension String: Referenceable {
    static var  name: Text {
        return Text(english: "String", japanese: "文字")
    }
}
extension String: Viewable {
    func view(withBounds bounds: Rect, _ sizeType: SizeType) -> View {
        return TextView(text: Text(self), font: Font.default(with: sizeType),
                        frame: bounds, isSizeToFit: false, isForm: false)
    }
}
extension String: Interpolatable {
    static func linear(_ f0: String, _ f1: String, t: Real) -> String {
        return f0
    }
    static func firstMonospline(_ f1: String, _ f2: String,
                                _ f3: String, with ms: Monospline) -> String {
        return f1
    }
    static func monospline(_ f0: String, _ f1: String,
                           _ f2: String, _ f3: String, with ms: Monospline) -> String {
        return f1
    }
    static func lastMonospline(_ f0: String, _ f1: String,
                               _ f2: String, with ms: Monospline) -> String {
        return f1
    }
}

typealias TextBinder = BasicBinder<Text>
typealias TextFormView = TextView<TextBinder>

struct TextOption {
    var defaultModel = Text()
    var font = Font.default, color = Color.locked
    var frameAlignment = CTTextAlignment.left, alignment = CTTextAlignment.natural
}

/**
 Issue: モードレス文字入力
 */
final class TextView<T: BinderProtocol>: View, BindableReceiver {
    typealias Model = Text
    typealias ModelOption = TextOption
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    
//    var text: Text {
//        didSet {
//            string = text.currentString
//        }
//    }
//    var string: String {
//        get {
//            return backingStore.string
//        }
//        set {
//            let range = NSRange(location: 0, length: backingStore.length)
//            backingStore.replaceCharacters(in: range, with: newValue)
//            backingStore.setAttributes(defaultAttributes, range: range)
//            unmarkText()
//            selectedRange = NSRange(location: (newValue as NSString).length, length: 0)
//            TextInputContext.invalidateCharacterCoordinates()
//            updateTextFrame()
//        }
//    }
//    var backingStore = NSMutableAttributedString() {
//        didSet {
//            self.textFrame = TextFrame(attributedString: backingStore)
//        }
//    }
    var textFrame: TextFrame {
        didSet {
            if let firstLine = textFrame.lines.first, let lastLine = textFrame.lines.last {
                baselineDelta = -lastLine.origin.y - baseFont.descent
                height = firstLine.origin.y + baseFont.ascent
            } else {
                baselineDelta = -baseFont.descent
                height = baseFont.ascent
            }
            if isSizeToFit { sizeToFit() }
            draw()
        }
    }
    
    var markedRange = NSRange(location: NSNotFound, length: 0) {
        didSet{
            if !NSEqualRanges(markedRange, oldValue) {
                draw()
            }
        }
    }
    var selectedRange = NSRange(location: NSNotFound, length: 0) {
        didSet{
            if !NSEqualRanges(selectedRange, oldValue) {
                draw()
            }
        }
    }
    
    var option: ModelOption {
        didSet { updateWithModel() }
    }
    
    var isReadOnly = true
    var isSizeToFit = false
//    var frameAlignment = CTTextAlignment.left
    var baseFont: Font, baselineDelta: Real, height: Real, padding: Real
    var defaultAttributes = NSAttributedString.attributesWith(font: .default, color: .font)
    var markedAttributes = NSAttributedString.attributesWith(font: .default, color: .gray)
    
    init(text: Text = "",
         font: Font = .default, color: Color = .locked,
         frameAlignment: CTTextAlignment = .left, alignment: CTTextAlignment = .natural,
         frame: Rect = Rect(), padding: Real = 1, isSizeToFit: Bool = true) {
        
        binder = Binder()
        
    }
    
    init(binder: Binder, keyPath: BinderKeyPath, option: ModelOption = ModelOption(),
         frame: Rect = Rect(), padding: Real = 1, isSizeToFit: Bool = true) {
        
        self.binder = binder
        self.keyPath = keyPath
        self.option = option
        
        self.padding = padding
        self.baseFont = option.font
        self.defaultAttributes = NSAttributedString.attributesWith(font: font, color: color,
                                                                   alignment: alignment)
        self.backingStore = NSMutableAttributedString(string: text.currentString,
                                                      attributes: defaultAttributes)
        if frame.width == 0 {
            self.textFrame = TextFrame(attributedString: backingStore)
        } else {
            self.textFrame = TextFrame(attributedString: backingStore,
                                       frameWidth: frame.width - padding * 2)
        }
        if let firstLine = textFrame.lines.first, let lastLine = textFrame.lines.last {
            baselineDelta = -lastLine.origin.y - baseFont.descent
            height = firstLine.origin.y + baseFont.ascent
        } else {
            baselineDelta = -baseFont.descent
            height = baseFont.ascent
        }
        self.frameAlignment = frameAlignment
        self.isSizeToFit = isSizeToFit
        
        super.init(drawClosure: { $1.draw(in: $0) }, isForm: isForm)
        
        isLiteral = true
        
        if isSizeToFit {
            let w = frame.width == 0 ? ceil(textFrame.pathBounds.width) + padding * 2 : frame.width
            let h = frame.height == 0 ? ceil(height + baselineDelta) + padding * 2 : frame.height
            self.frame = Rect(x: frame.origin.x, y: frame.origin.y, width: w, height: h)
        } else {
            self.frame = frame
        }
        noIndicatedLineColor = isForm ? nil : (isReadOnly ? .getBorder : .getSetBorder)
        indicatedLineColor = isForm ? .noBorderIndicated : (isReadOnly ? .indicated : .indicated)
    }
    
    func sizeToFit() {
        let size = defaultBounds.size
        let y = frame.maxY - size.height
        let origin = frameAlignment == .right ?
            Point(x: frame.maxX - size.width, y: y) :
            Point(x: frame.origin.x, y: y)
        frame = Rect(origin: origin, size: size)
    }
    
    override var defaultBounds: Rect {
        let w = textFrame.frameWidth ?? ceil(textFrame.pathBounds.width)
        return Rect(x: 0, y: 0,
                    width: max(w + padding * 2, 5),
                    height: ceil(height + baselineDelta) + padding * 2)
    }
    override func updateLayout() {
        if textFrame.frameWidth != nil {
            textFrame.frameWidth = frame.width - padding * 2
        }
    }
    func updateWithModel() {
        let string = text.currentString
        let range = NSRange(location: 0, length: backingStore.length)
        backingStore.replaceCharacters(in: range, with: string)
        backingStore.setAttributes(defaultAttributes, range: range)
        unmarkText()
        selectedRange = NSRange(location: (string as NSString).length, length: 0)
        TextInputContext.invalidateCharacterCoordinates()
        self.textFrame = TextFrame(attributedString: backingStore)
        updateTextFrame()
    }
    
    func word(for p: Point) -> String {
        let characterIndex = self.characterIndex(for: convertToLocal(p))
        
        var range = NSRange()
        if characterIndex >= selectedRange.location
            && characterIndex < NSMaxRange(selectedRange) {
            
            range = selectedRange
        } else {
            let string = backingStore.string as NSString
            let allRange = NSRange(location: 0, length: string.length)
            string.enumerateSubstrings(in: allRange, options: .byWords)
            { substring, substringRange, enclosingRange, stop in
                if characterIndex >= substringRange.location
                    && characterIndex < NSMaxRange(substringRange) {
                    
                    range = substringRange
                    stop.pointee = true
                }
            }
        }
        return backingStore.attributedSubstring(from: range).string
    }
    func textDefinition(for p: Point) -> String? {
        let string = self.string as CFString
        let characterIndex = self.characterIndex(for: convertToLocal(p))
        let range = DCSGetTermRangeInString(nil, string, characterIndex + 1)
        if range.location != kCFNotFound {
            return DCSCopyTextDefinition(nil, string, range)?.takeRetainedValue() as String?
        } else {
            return nil
        }
    }
    
    func convertToLocal(_ point: Point) -> Point {
        return point - Point(x: padding, y: bounds.height - height - padding)
    }
    func convertFromLocal(_ point: Point) -> Point {
        return point + Point(x: padding, y: bounds.height - height - padding)
    }
    
//    func updateTextFrame() {
//        textFrame.attributedString = backingStore
//    }
    override func draw(in ctx: CGContext) {
        textFrame.draw(in: bounds.inset(by: padding), baseFont: baseFont, in: ctx)
    }
    
    private let timer = RunTimer()
    private var oldModel = ""
}
extension TextView: Localizable {
    func update(with locale: Locale) {
        updateWithModel()
//        string = text.string(with: locale)
        if isSizeToFit {
            sizeToFit()
        }
    }
}
extension TextView: ViewQueryable {
    static let referenceableType: Referenceable.Type = Text.self
    static let viewDescription = Text(english: "Run (Verb sentence only): Click",
                                      japanese: "実行 (動詞文のみ): クリック")
}
extension TextView: Runnable {
    func run(for p: Point) {
        let word = self.word(for: p)
        if word == "=" {
            string += string.calculate
        }
    }
}
extension TextView: Assignable {
    func delete(for p: Point) {
        guard !isReadOnly else { return }
        deleteBackward()
    }
    func copiedViewables(at p: Point) -> [Viewable] {
        guard let backingStore = backingStore.copy() as? NSAttributedString else {
            return []
        }
        return [backingStore.string]
    }
    func paste(_ objects: [Any], for p: Point) {
        guard !isReadOnly else { return }
        for object in objects {
            if let string = object as? String {
                self.string = string
                return
            }
        }
    }
}
extension TextView: Indicatable {
    func indicate(at p: Point) {
        selectedRange = NSRange(location: editCharacterIndex(for: p), length: 0)
    }
}
extension TextView: KeyInputtable {
    func insert(_ string: String, for p: Point) {
        guard !isReadOnly else { return }
        let beginClosure: () -> () = { [unowned self] in
            self.oldModel = self.string
            self.binding?(Binding(view: self,
                                  text: self.oldText, oldText: self.oldText, phase: .began))
        }
        let waitClosure: () -> () = { [unowned self] in
            self.binding?(Binding(view: self,
                                  text: self.string, oldText: self.oldText, phase: .changed))
        }
        let endClosure: () -> () = { [unowned self] in
            self.binding?(Binding(view: self,
                                  text: self.string, oldText: self.oldText, phase: .ended))
        }
        timer.run(after: 1, dispatchQueue: .main,
                  beginClosure: beginClosure,
                  waitClosure: waitClosure,
                  endClosure: endClosure)
    }
}
//protocol CocoaKeyInputtable {}
//extension TextView: CocoaKeyInputtable {
//    var backingStore: NSMutableAttributedString {
//        return textFrame.attributedString
//    }
//    var attributedString: NSAttributedString {
//        return backingStore
//    }
//    var hasMarkedText: Bool {
//        return markedRange.location != NSNotFound
//    }
//    func editCharacterIndex(for p: Point) -> Int {
//        return textFrame.editCharacterIndex(for: convertToLocal(p))
//    }
//    func characterIndex(for p: Point) -> Int {
//        return textFrame.characterIndex(for: convertToLocal(p))
//    }
//    func characterFraction(for p: Point) -> Real {
//        return textFrame.characterFraction(for: convertToLocal(p))
//    }
//    func characterOffset(for p: Point) -> Real {
//        let i = characterIndex(for: convertToLocal(p))
//        return textFrame.characterOffset(at: i)
//    }
//    func baselineDelta(at i: Int) -> Real {
//        return textFrame.baselineDelta(at: i)
//    }
//    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> Rect {
//        return textFrame.typographicBounds(for: range)
//    }
//
//    func insertNewline() {
//        insertText("\n", replacementRange: NSRange(location: NSNotFound, length: 0))
//    }
//    func insertTab() {
//        insertText("\t", replacementRange: NSRange(location: NSNotFound, length: 0))
//    }
//    func deleteBackward() {
//        var deleteRange = selectedRange
//        if deleteRange.length == 0 {
//            guard deleteRange.location > 0 else { return }
//            deleteRange.location -= 1
//            deleteRange.length = 1
//            deleteRange = (backingStore.string as NSString)
//                .rangeOfComposedCharacterSequences(for: deleteRange)
//        }
//        deleteCharacters(in: deleteRange)
//    }
//    func deleteForward() {
//        var deleteRange = selectedRange
//        if deleteRange.length == 0 {
//            guard deleteRange.location != backingStore.length else { return }
//            deleteRange.length = 1
//            deleteRange = (backingStore.string as NSString)
//                .rangeOfComposedCharacterSequences(for: deleteRange)
//        }
//        deleteCharacters(in: deleteRange)
//    }
//    func moveLeft() {
//        if selectedRange.length > 0 {
//            selectedRange.length = 0
//        } else if selectedRange.location > 0 {
//            selectedRange.location -= 1
//        }
//    }
//    func moveRight() {
//        if selectedRange.length > 0 {
//            selectedRange = NSRange(location: NSMaxRange(selectedRange), length: 0)
//        } else if selectedRange.location > 0 {
//            selectedRange.location += 1
//        }
//    }
//
//    func deleteCharacters(in range: NSRange) {
//        if NSLocationInRange(NSMaxRange(range), markedRange) {
//            self.markedRange = NSRange(location: range.location,
//                                       length: markedRange.length
//                                        - (NSMaxRange(range) - markedRange.location))
//        } else {
//            markedRange.location -= range.length
//        }
//        if markedRange.length == 0 {
//            unmarkText()
//        }
//
//        backingStore.deleteCharacters(in: range)
//
//        self.selectedRange = NSRange(location: range.location, length: 0)
//        TextInputContext.invalidateCharacterCoordinates()
//
//        updateTextFrame()
//    }
//
//    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
//        let aReplacementRange = markedRange.location != NSNotFound ? markedRange : selectedRange
//        if let attString = string as? NSAttributedString {
//            if attString.length == 0 {
//                backingStore.deleteCharacters(in: aReplacementRange)
//                unmarkText()
//            } else {
//                self.markedRange = NSRange(location: aReplacementRange.location,
//                                           length: attString.length)
//                backingStore.replaceCharacters(in: aReplacementRange, with: attString)
//                backingStore.addAttributes(markedAttributes, range: markedRange)
//            }
//        } else if let string = string as? String {
//            if (string as NSString).length == 0 {
//                backingStore.deleteCharacters(in: aReplacementRange)
//                unmarkText()
//            } else {
//                self.markedRange = NSRange(location: aReplacementRange.location,
//                                           length: (string as NSString).length)
//                backingStore.replaceCharacters(in: aReplacementRange, with: string)
//                backingStore.addAttributes(markedAttributes, range: markedRange)
//            }
//        }
//
//        self.selectedRange = NSRange(location: aReplacementRange.location + selectedRange.location,
//                                     length: selectedRange.length)
//        TextInputContext.invalidateCharacterCoordinates()
//
//        updateTextFrame()
//    }
//    func unmarkText() {
//        if markedRange.location != NSNotFound {
//            markedRange = NSRange(location: NSNotFound, length: 0)
//            TextInputContext.discardMarkedText()
//        }
//    }
//
//    func attributedSubstring(forProposedRange range: NSRange,
//                             actualRange: NSRangePointer?) -> NSAttributedString? {
//        actualRange?.pointee = range
//        return backingStore.attributedSubstring(from: range)
//    }
//    func insertText(_ string: Any, replacementRange: NSRange) {
//        let replaceRange = replacementRange.location != NSNotFound ?
//            replacementRange : (markedRange.location != NSNotFound ? markedRange : selectedRange)
//        if let attString = string as? NSAttributedString {
//            let range = NSRange(location: replaceRange.location, length: attString.length)
//            backingStore.replaceCharacters(in: replaceRange, with: attString)
//            backingStore.setAttributes(defaultAttributes, range: range)
//            selectedRange = NSRange(location: selectedRange.location + range.length, length: 0)
//        } else if let string = string as? String {
//            let range = NSRange(location: replaceRange.location, length: (string as NSString).length)
//            backingStore.replaceCharacters(in: replaceRange, with: string)
//            backingStore.setAttributes(defaultAttributes, range: range)
//            selectedRange = NSRange(location: selectedRange.location + range.length, length: 0)
//        }
//        unmarkText()
//        TextInputContext.invalidateCharacterCoordinates()
//        updateTextFrame()
//    }
//}
