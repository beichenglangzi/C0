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

typealias Object0D = Object.Value

protocol GetterOption {
    associatedtype Model: Object0D
    var reverseTransformedModel: ((Model) -> (Model)) { get }
    func string(with model: Model) -> String
    func displayText(with model: Model) -> Text
}

final class GetterView<T: GetterOption, U: BinderProtocol>
: ModelView, BindableGetterReceiver {

    typealias Model = T.Model
    typealias ModelOption = T
    typealias Binder = U
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    
    var model: Model {
        return option.reverseTransformedModel(binder[keyPath: keyPath])
    }
    
    var option: ModelOption {
        didSet { updateWithModel() }
    }
    
    var sizeType: SizeType
    let optionStringView: TextFormView
    
    init(binder: Binder, keyPath: BinderKeyPath, option: ModelOption,
         frame: Rect = Rect(), sizeType: SizeType = .regular, isSizeToFit: Bool = true) {
        
        self.binder = binder
        self.keyPath = keyPath
        self.option = option
        
        self.sizeType = sizeType
        optionStringView = TextFormView(text: option.displayText(with: binder[keyPath: keyPath]),
                                        font: Font.default(with: sizeType),
                                        frameAlignment: .right, alignment: .right,
                                        paddingSize: Size(width: 3, height: 1),
                                        isSizeToFit: isSizeToFit)
        
        super.init()
        lineColor = .getBorder
        isClipped = true
        children = [optionStringView]
        self.frame = frame
    }
    
    override var defaultBounds: Rect {
        return Rect(origin: Point(), size: optionStringView.defaultBounds.size)
    }
    override func updateLayout() {
        if optionStringView.isSizeToFit {
            optionStringView.frame.origin
                = Point(x: bounds.width - optionStringView.frame.width,
                        y: bounds.height - optionStringView.frame.height)
        } else {
            optionStringView.frame = bounds
        }
    }
    func updateWithModel() {
        updateString()
    }
    private func updateString() {
        optionStringView.text = option.displayText(with: model)
        if optionStringView.isSizeToFit {
            bounds.size = optionStringView.bounds.size
        }
    }
}

final class MiniView<T: Object0D, U: BinderProtocol>: ModelView, BindableGetterReceiver {
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
        
        let thumbnailFrame = MiniView.thumbnailFrame(withBounds: Rect(origin: Point(),
                                                                      size: frame.size),
                                                     leftWidth: classNameView.frame.width,
                                                     sizeType: sizeType)
        thumbnailView = MiniView.thumbnailViewWith(model: binder[keyPath: keyPath],
                                                   frame: thumbnailFrame, sizeType: sizeType)
        
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
        let padding = Layouter.padding(with: sizeType)
        let width = max(MiniView.defaultMinWidth,
                        classNameView.frame.width + MiniView.defaultThumbnailWidth)
        return Rect(x: 0, y: 0, width: width, height: classNameView.frame.height + padding * 2)
    }
    static func thumbnailFrame(withBounds bounds: Rect,
                               leftWidth: Real, sizeType: SizeType) -> Rect {
        let padding = Layouter.padding(with: sizeType)
        return Rect(x: leftWidth + padding,
                    y: padding,
                    width: bounds.width - leftWidth - padding * 3,
                    height: bounds.height - padding * 2)
    }
    override func updateLayout() {
        let padding = Layouter.padding(with: sizeType)
        classNameView.frame.origin = Point(x: padding,
                                           y: bounds.height - classNameView.frame.height - padding)
        thumbnailView.frame = MiniView.thumbnailFrame(withBounds: bounds,
                                                      leftWidth: classNameView.frame.width,
                                                      sizeType: sizeType)
    }
    func updateWithModel() {
        let thumbnailFrame = MiniView.thumbnailFrame(withBounds: bounds,
                                                     leftWidth: classNameView.frame.width,
                                                     sizeType: sizeType)
        thumbnailView = MiniView.thumbnailViewWith(model: model,
                                                   frame: thumbnailFrame, sizeType: sizeType)
    }
    static func thumbnailViewWith(model: Model, frame: Rect, sizeType: SizeType) -> View {
        return model.thumbnailView(withFrame: frame, sizeType)
    }
}
