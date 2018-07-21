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

import class Foundation.NSExpression
import class Foundation.NSNumber
import struct Foundation.CharacterSet
import class CoreGraphics.CGContext

extension String {
    func union(_ other: String, space: String = " ") -> String {
        return other.isEmpty ? self : (isEmpty ? other : self + space + other)
    }
    var calculate: String {
        let expressionValue = NSExpression(format: self).expressionValue(with: nil, context: nil)
        return (expressionValue as? NSNumber)?.stringValue ?? "Error"
    }
    var suffixNumber: Int? {
        if let numberString = components(separatedBy: CharacterSet.decimalDigits.inverted).last {
            return Int(numberString)
        } else {
            return nil
        }
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

protocol KeyInputtable {
    func insert(_ string: String, for p: Point, _ version: Version)
}

final class StringFormView: View {
    var string: String {
        didSet { updateTextFrame() }
    }
    
    var textMaterial: TextMaterial {
        didSet { updateTextFrame() }
    }
    var lineBreakWidth: Real? {
        didSet { updateTextFrame() }
    }
    var paddingSize: Size {
        didSet { updateTextFrame() }
    }
    private var textFrame: TextFrame {
        didSet { displayLinkDraw() }
    }
    
    convenience init(string: String = "",
                     font: Font = .default, color: Color = .content,
                     lineColor: Color? = nil, lineWidth: Real = 0,
                     alignment: TextAlignment = .natural,
                     lineBreakWidth: Real? = .infinity,
                     paddingSize: Size = Size(square: 1)) {
        let textMaterial = TextMaterial(font: font, color: color,
                                        lineColor: lineColor, lineWidth: lineWidth,
                                        alignment: alignment)
        self.init(string: string, textMaterial: textMaterial,
                  lineBreakWidth: lineBreakWidth, paddingSize: paddingSize)
    }
    init(string: String = "", textMaterial: TextMaterial = TextMaterial(),
         lineBreakWidth: Real? = .infinity, paddingSize: Size = Size(square: 1)) {
        
        self.string = string
        self.textMaterial = textMaterial
        self.lineBreakWidth = lineBreakWidth
        self.paddingSize = paddingSize
        textFrame = TextFrame(string: string,
                              textMaterial: textMaterial,
                              lineBreakWidth: lineBreakWidth ?? 0,
                              paddingSize: paddingSize)
        
        super.init(drawClosure: { ctx, view, _ in view.draw(in: ctx) })
        lineColor = nil
    }
    
    var minSize: Size {
        if lineBreakWidth == nil {
            return Size(width: Layouter.minWidth, height: Layouter.textHeight)
        } else {
            return textFrame.fitSize
        }
    }
    override func updateLayout() {
        updateTextFrame()
    }
    private func updateTextFrame() {
        textFrame = TextFrame(string: string,
                              textMaterial: textMaterial,
                              lineBreakWidth: lineBreakWidth ?? frame.width - paddingSize.width * 2,
                              paddingSize: paddingSize)
    }
    
    override func draw(in ctx: CGContext) {
        textFrame.draw(in: bounds, in: ctx)
    }
}

struct StringLine: Codable {
    var string: String
    var origin: Point
}
extension StringLine: Viewable {
    func viewWith<T: BinderProtocol>
        (binder: T, keyPath: ReferenceWritableKeyPath<T, StringLine>) -> ModelView {
        
        return StringLineView(binder: binder, keyPath: keyPath)
    }
}
extension StringLine: ObjectViewable {}

final class StringLineView<T: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = StringLine
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((StringLineView<Binder>, BasicNotification) -> ())]()

    var markedRange: Range<String.Index>? {
        didSet{
            if markedRange != oldValue { displayLinkDraw() }
        }
    }
    var selectedRange: Range<String.Index>? {
        didSet{
            if selectedRange != oldValue { displayLinkDraw() }
        }
    }
    var textMaterial: TextMaterial {
        didSet { updateWithModel() }
    }
    var lineBreakWidth: Real? {
        didSet { updateText() }
    }
    var paddingSize: Size {
        didSet { updateLayout() }
    }
    private var textFrame: TextFrame {
        didSet { displayLinkDraw() }
    }

    init(binder: Binder, keyPath: BinderKeyPath,
         textMaterial: TextMaterial = TextMaterial(color: .content),
         lineBreakWidth: Real? = .infinity, paddingSize: Size = Size(square: 1)) {

        self.binder = binder
        self.keyPath = keyPath

        self.textMaterial = textMaterial
        self.lineBreakWidth = lineBreakWidth
        self.paddingSize = paddingSize
        
        textFrame = TextFrame(string: binder[keyPath: keyPath].string,
                              textMaterial: textMaterial,
                              lineBreakWidth: lineBreakWidth ?? 0,
                              paddingSize: paddingSize)

        super.init(drawClosure: { ctx, view, _ in view.draw(in: ctx) }, isLocked: false)
        bounds = Rect(origin: model.origin, size: textFrame.fitSize)
    }
    deinit {
        timer.cancel()
    }
    
    var defaultSize: Size {
        if lineBreakWidth == nil {
            return Size(width: Layouter.minWidth, height: Layouter.textHeight)
        } else {
            return textFrame.fitSize
        }
    }
    override func updateLayout() {
        updateText()
    }
    func updateWithModel() {
        position = model.origin
        updateText()
    }
    func updateText() {
        textFrame = TextFrame(string: model.string,
                              textMaterial: textMaterial,
                              lineBreakWidth: lineBreakWidth ?? frame.width - paddingSize.width * 2)
        bounds = Rect(origin: model.origin, size: textFrame.fitSize)
    }
    
    func convertToLocal(_ p: Point) -> Point {
        return p - Point(x: paddingSize.width,
                         y: bounds.height - textFrame.height - paddingSize.height)
    }
    func convertFromLocal(_ p: Point) -> Point {
        return p + Point(x: paddingSize.width,
                         y: bounds.height - textFrame.height - paddingSize.height)
    }

    func editingCharacterIndex(for p: Point) -> String.Index? {
        guard !model.string.isEmpty else { return nil }
        let index = textFrame.editCharacterIndex(for: convertToLocal(p))
        return String.Index(encodedOffset: index)
    }
    
    override func draw(in ctx: CGContext) {
        textFrame.draw(in: bounds, in: ctx)
    }

    private let timer = RunTimer()
    private var oldModel = "", isinputting = false
}
extension StringLineView: MovableOrigin {
    var movingOrigin: Point {
        get { return model.origin }
        set {
            binder[keyPath: keyPath].origin = newValue
            self.position = newValue
        }
    }
}
extension StringLineView: KeyInputtable {
    func insert(_ string: String, for p: Point, _ version: Version) {
        let beginClosure: () -> () = { [unowned self] in
            if !self.isinputting {
                self.capture(self.model, to: version)
            } else {
                self.isinputting = true
            }
            
            self.model.string.append(string)
        }
        let waitClosure: () -> () = { [unowned self] in
            self.model.string.append(string)
        }
        let endClosure: () -> () = { [unowned self] in
            self.isinputting = false
        }
        timer.run(afterTime: 1, dispatchQueue: .main,
                  beginClosure: beginClosure,
                  waitClosure: waitClosure,
                  endClosure: endClosure)
    }
}
