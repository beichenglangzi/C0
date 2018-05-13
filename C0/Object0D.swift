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

import struct Foundation.Locale

typealias Object0D = ObjectProtocol & Referenceable

protocol GetterOption {
    associatedtype Model: Object0D
    func string(with model: Model) -> String
    func text(with model: Model) -> Text
}

final class GetterView<T: GetterOption, U: BinderProtocol>: View, BindableGetterReceiver {
    typealias Model = T.Model
    typealias ModelOption = T
    typealias Binder = U
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    
    var option: ModelOption {
        didSet { updateWithModel() }
    }
    
    var sizeType: SizeType
    let optionTextView: TextFormView
    
    init(binder: Binder, keyPath: BinderKeyPath, option: ModelOption,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        self.option = option
        
        self.sizeType = sizeType
        optionTextView = TextFormView(text: option.text(with: model),
                                      font: Font.default(with: sizeType),
                                      frameAlignment: .right, alignment: .right)
        
        super.init()
        noIndicatedLineColor = .getBorder
        indicatedLineColor = .indicated
        isClipped = true
        children = [optionTextView]
        self.frame = frame
    }
    
    override var defaultBounds: Rect {
        return optionTextView.defaultBounds
    }
    override func updateLayout() {
        optionTextView.frame.origin = Point(x: bounds.width - optionTextView.frame.width,
                                            y: bounds.height - optionTextView.frame.height)
        updateWithModel()
    }
    func updateWithModel() {
        updateString()
    }
    private func updateString() {
        optionTextView.text = option.text(with: model)
    }
}
extension GetterView: Queryable {
    static var referenceableType: Referenceable.Type {
        return Model.self
    }
}
extension GetterView: Copiable {
    func copiedObjects(at p: Point) -> [Object] {
        return [model.object]
    }
}

final class MiniView<T: Object0D, U: BinderProtocol>: View, BindableGetterReceiver {
    typealias Model = T
    typealias Binder = U
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    
    var sizeType: SizeType {
        didSet { updateWithModel() }
    }
    let classNameView: TextFormView
    var thumbnailView: View {
        didSet {
            children = [classNameView, thumbnailView]
        }
    }
    
    init(binder: Binder, keyPath: BinderKeyPath,
         frame: Rect = Rect(), _ sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        self.sizeType = sizeType
        classNameView = TextFormView(text: Model.name, font: Font.bold(with: sizeType))
        
        super.init()
        children = [classNameView, thumbnailView]
        self.frame = frame
    }
    
    static var defaultMinWidth: Real {
        return 80
    }
    static var defaultThumbnailWidth: Real {
        return 40
    }
    override var defaultBounds: Rect {
        let padding = Layout.padding(with: sizeType)
        let width = max(MiniView.defaultMinWidth,
                        classNameView.frame.width + MiniView.defaultThumbnailWidth)
        return Rect(x: 0, y: 0, width: width, height: classNameView.frame.height + padding * 2)
    }
    func thumbnailFrame(withBounds bounds: Rect) -> Rect {
        let padding = Layout.padding(with: sizeType)
        return Rect(x: classNameView.frame.maxX + padding,
                    y: padding,
                    width: bounds.width - classNameView.frame.width - padding * 3,
                    height: bounds.height - padding * 2)
    }
    override func updateLayout() {
        let padding = Layout.padding(with: sizeType)
        classNameView.frame.origin = Point(x: padding,
                                           y: bounds.height - classNameView.frame.height - padding)
        thumbnailView.frame = thumbnailFrame(withBounds: bounds)
    }
    func updateWithModel() {
        let thumbnailFrame = self.thumbnailFrame(withBounds: bounds)
        if let thumbnailViewable = model as? ThumbnailViewable {
            thumbnailView = thumbnailViewable.thumbnailView(withFrame: thumbnailFrame, sizeType)
        } else {
            let view = View(isLocked: true)
            view.frame = thumbnailFrame
            view.lineColor = .formBorder
            thumbnailView = view
        }
    }
}
extension MiniView: Localizable {
    func update(with locale: Locale) {
        updateLayout()
    }
}
extension MiniView: Queryable {
    static var referenceableType: Referenceable.Type {
        return Model.self
    }
}
extension MiniView: Copiable {
    func copiedObjects(at p: Point) -> [Object] {
        return [model.object]
    }
}
