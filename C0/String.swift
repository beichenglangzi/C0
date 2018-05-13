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

import Foundation

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
    static let name = Text(english: "String", japanese: "文字")
}
extension String: ObjectProtocol {
    var object: Object {
        return .string(self)
    }
}
extension String: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return TextFormView(text: Text(self), font: Font.default(with: sizeType),
                            frame: frame, isSizeToFit: false)
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

protocol Namable {
    var name: String { get }
}

final class TextGetterView<T: BinderProtocol>: View, BindableGetterReceiver {
    typealias Model = Text
    typealias ModelOption = TextOption
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
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
    var textFrame: TextFrame {
        didSet {
            if isSizeToFit { sizeToFit() }
            draw()
        }
    }
    
    init(binder: Binder, keyPath: BinderKeyPath, textMaterial: TextMaterial = TextMaterial(),
         frame: Rect = Rect(), padding: Real = 1, isSizeToFit: Bool = true) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        self.isSizeToFit = isSizeToFit
        self.padding = padding
        self.textMaterial = textMaterial
        textFrame = TextFrame(text: model, textMaterial: textMaterial, frameWidth: frameWidth)
        
        super.init(drawClosure: { $1.draw(in: $0) })
        
        noIndicatedLineColor = .getBorder
        indicatedLineColor = .indicated
        
        self.frame = frame
        if isSizeToFit { sizeToFit() }
    }
    
    override var defaultBounds: Rect {
        return textFrame.bounds(padding: padding)
    }
    override func updateLayout() {
        textFrame.frameWidth = frameWidth
    }
    func updateWithModel() {
        textFrame = TextFrame(text: model, textMaterial: textMaterial, frameWidth: frameWidth)
    }
    func sizeToFit() {
        frame = textMaterial.fitFrameWith(defaultBounds: defaultBounds, frame: frame)
    }
    
    var frameWidth: Real? {
        return frame.width == 0 ? nil : frame.width - padding * 2
    }
    
    override func draw(in ctx: CGContext) {
        textFrame.draw(in: bounds.inset(by: padding), in: ctx)
    }
}
extension TextGetterView: Localizable {
    func update(with locale: Locale) {
        updateWithModel()
        if isSizeToFit { sizeToFit() }
    }
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
    
    var markedRange = NSRange(location: NSNotFound, length: 0) {
        didSet{
            if !NSEqualRanges(markedRange, oldValue) { draw() }
        }
    }
    var selectedRange = NSRange(location: NSNotFound, length: 0) {
        didSet{
            if !NSEqualRanges(selectedRange, oldValue) { draw() }
        }
    }
    var defaultAttributes = NSAttributedString.attributesWith(font: .default, color: .font)
    var markedAttributes = NSAttributedString.attributesWith(font: .default, color: .gray)
    
    var option: ModelOption {
        didSet { updateWithModel() }
    }
    
    var textMaterial = TextMaterial() {
        didSet { updateWithModel() }
    }
    var isSizeToFit = false {
        didSet {
            if isSizeToFit { sizeToFit() }
        }
    }
    var padding: Real {
        didSet { updateLayout() }
    }
    var textFrame: TextFrame {
        didSet {
            if isSizeToFit { sizeToFit() }
            draw()
        }
    }
    
    init(binder: Binder, keyPath: BinderKeyPath, option: ModelOption = ModelOption(),
         frame: Rect = Rect(), padding: Real = 1, isSizeToFit: Bool = true) {
        
        self.binder = binder
        self.keyPath = keyPath
        self.option = option
        
        self.isSizeToFit = isSizeToFit
        self.padding = padding
        
        //        self.defaultAttributes = NSAttributedString.attributesWith(font: font, color: color,
        //                                                                   alignment: alignment)
        
        textFrame = TextFrame(text: model, textMaterial: textMaterial, frameWidth: frameWidth)
        
        super.init(drawClosure: { $1.draw(in: $0) }, isLocked: false)
        
        self.frame = frame
        if isSizeToFit { sizeToFit() }
    }
    
    func sizeToFit() {
        frame = textMaterial.fitFrameWith(defaultBounds: defaultBounds, frame: frame)
    }
    
    override var defaultBounds: Rect {
        return textFrame.bounds(padding: padding)
    }
    override func updateLayout() {
        textFrame.frameWidth = frameWidth
    }
    func updateWithModel() {
        textFrame = TextFrame(text: model, textMaterial: textMaterial, frameWidth: frameWidth)
        //        unmarkText()
        TextInputContext.invalidateCharacterCoordinates()
    }
    
    var frameWidth: Real? {
        return frame.width == 0 ? nil : frame.width - padding * 2
    }
    
    func convertToLocal(_ p: Point) -> Point {
        return p - Point(x: padding, y: bounds.height - textFrame.height - padding)
    }
    func convertFromLocal(_ p: Point) -> Point {
        return p + Point(x: padding, y: bounds.height - textFrame.height - padding)
    }
    
    override func draw(in ctx: CGContext) {
        textFrame.draw(in: bounds.inset(by: padding), in: ctx)
    }
    
    private let timer = RunTimer()
    private var oldModel = "", isinputting = false
}
extension TextView: Localizable {
    func update(with locale: Locale) {
        updateWithModel()
        if isSizeToFit {
            sizeToFit()
        }
    }
}
extension TextView: ViewQueryable {
    static var referenceableType: Referenceable.Type {
        return Model.self
    }
    static var viewDescription: Text {
        return Text(english: "Run (Verb sentence only): Click",
                    japanese: "実行 (動詞文のみ): クリック")
    }
}
extension TextView: Assignable {
    func delete(for p: Point, _ version: Version) {
        //        deleteBackward()
    }
    func copiedObjects(at p: Point) -> [Viewable] {
        return [model]
    }
    func paste(_ objects: [Object], for p: Point, _ version: Version) {
        for object in objects {
            if let model = object as? Text {
                self.model = model//undo
                return
            } else if let string = object as? String {
                self.model = Text(string)//undo
                return
            }
        }
    }
}
extension TextView: Indicatable {
    func indicate(at p: Point) {
        //        selectedRange = NSRange(location: editCharacterIndex(for: p), length: 0)
    }
}
extension TextView: KeyInputtable {
    func insert(_ string: String, for p: Point, _ version: Version) {
        let beginClosure: () -> () = { [unowned self] in
            if !self.isinputting {
                //capture
            } else {
                self.isinputting = true
            }
        }
        let endClosure: () -> () = { [unowned self] in
            self.isinputting = false
        }
        timer.run(after: 1, dispatchQueue: .main,
                  beginClosure: beginClosure,
                  waitClosure: {},
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
//    func definition(characterIndex: Int) -> String? {
//        let string = self.string as CFString
//        let range = DCSGetTermRangeInString(nil, string, characterIndex + 1)
//        if range.location != kCFNotFound {
//            return DCSCopyTextDefinition(nil, string, range)?.takeRetainedValue() as String?
//        } else {
//            return nil
//        }
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
