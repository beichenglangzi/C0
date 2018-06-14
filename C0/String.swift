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
extension String: Referenceable {
    static let name = Text(english: "String", japanese: "文字")
}
extension String: AnyInitializable {
    init?(anyValue: Any) {
        switch anyValue {
        case let value as String: self = value
        case let value as Bool: self = String(value)
        case let value as Int: self = String(value)
        case let value as Rational: self = String(value)
        case let value as Real: self = String(value)
        default: return nil
        }
    }
}
extension String: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect) -> View {
        let view = TextFormView(text: Text(self), font: .small)
        view.frame = frame
        return view
    }
}
extension String: AbstractViewable {
    var defaultAbstractConstraintSize: Size {
        return Size(width: 400, height: Layouter.basicTextHeight)
    }
    func abstractViewWith<T : BinderProtocol>(binder: T,
                                              keyPath: ReferenceWritableKeyPath<T, String>,
                                              type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return StringView(binder: binder, keyPath: keyPath, option: StringOption(),
                              lineBreakWidth: 400)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath)
        }
    }
}
extension String: ObjectViewable {}
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

struct StringOption {
    var defaultModel = ""
}

protocol Namable {
    var name: String { get }
}

final class StringGetterView<T: BinderProtocol>: ModelView, BindableGetterReceiver {
    typealias Model = String
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
    var lineBreakWidth: Real? {
        didSet { updateText() }
    }
    var paddingSize: Size {
        didSet { updateLayout() }
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
        
        textFrame = TextFrame(string: binder[keyPath: keyPath],
                              textMaterial: textMaterial,
                              lineBreakWidth: 0,
                              paddingSize: paddingSize)
        
        super.init(drawClosure: { ctx, view, _ in view.draw(in: ctx) }, isLocked: false)
        lineColor = .getBorder
    }
    
    var minSize: Size {
        return Size(width: Layouter.defaultMinWidth, height: Layouter.basicTextHeight)
    }
    var fitSize: Size {
        return textFrame.fitSize
    }
    override func updateLayout() {
        updateText()
    }
    func updateText() {
        textFrame = TextFrame(string: model,
                              textMaterial: textMaterial,
                              lineBreakWidth: lineBreakWidth ?? frame.width - paddingSize.width * 2)
    }
    
    override func draw(in ctx: CGContext) {
        textFrame.draw(in: bounds, in: ctx)
    }
}

protocol KeyInputtable {
    func insert(_ string: String, for p: Point, _ version: Version)
}

/**
 Issue: モードレス文字入力
 */
final class StringView<T: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = String
    typealias ModelOption = StringOption
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((StringView<Binder>, BasicNotification) -> ())]()

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

    var option: ModelOption {
        didSet { updateWithModel() }
    }
    var defaultModel: Model {
        return option.defaultModel
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

    init(binder: Binder, keyPath: BinderKeyPath, option: ModelOption = ModelOption(),
         textMaterial: TextMaterial = TextMaterial(),
         lineBreakWidth: Real? = .infinity, paddingSize: Size = Size(square: 1)) {

        self.binder = binder
        self.keyPath = keyPath
        self.option = option

        self.textMaterial = textMaterial
        self.lineBreakWidth = lineBreakWidth
        self.paddingSize = paddingSize
        
        textFrame = TextFrame(string: binder[keyPath: keyPath],
                              textMaterial: textMaterial,
                              lineBreakWidth: lineBreakWidth ?? 0,
                              paddingSize: paddingSize)

        super.init(drawClosure: { ctx, view, _ in view.draw(in: ctx) }, isLocked: false)
    }
    deinit {
        timer.cancel()
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
    func updateWithModel() {
        updateText()
    }
    func updateText() {
        textFrame = TextFrame(string: model,
                              textMaterial: textMaterial,
                              lineBreakWidth: lineBreakWidth ?? frame.width - paddingSize.width * 2)
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
        guard !model.isEmpty else { return nil }
        let index = textFrame.editCharacterIndex(for: convertToLocal(p))
        return String.Index(encodedOffset: index)
    }
    
    override func draw(in ctx: CGContext) {
        textFrame.draw(in: bounds, in: ctx)
    }

    private let timer = RunTimer()
    private var oldModel = "", isinputting = false
}
extension StringView: Indicatable {
    func indicate(at p: Point) {
        guard let index = editingCharacterIndex(for: p) else { return }
        selectedRange = model.rangeOfComposedCharacterSequence(at: index)
    }
}
extension StringView: KeyInputtable {
    func insert(_ string: String, for p: Point, _ version: Version) {
        let beginClosure: () -> () = { [unowned self] in
            if !self.isinputting {
                self.capture(self.model, to: version)
            } else {
                self.isinputting = true
            }
            
            self.model.append(string)
        }
        let waitClosure: () -> () = { [unowned self] in
            self.model.append(string)
        }
        let endClosure: () -> () = { [unowned self] in
            self.isinputting = false
        }
        timer.run(after: 1, dispatchQueue: .main,
                  beginClosure: beginClosure,
                  waitClosure: waitClosure,
                  endClosure: endClosure)
    }
}
