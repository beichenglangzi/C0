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
    
    let optionStringView: TextFormView
    
    init(binder: Binder, keyPath: BinderKeyPath, option: ModelOption, isSizeToFit: Bool = true) {
        self.binder = binder
        self.keyPath = keyPath
        self.option = option
        
        optionStringView = TextFormView(text: option.displayText(with: binder[keyPath: keyPath]),
                                        alignment: .right,
                                        paddingSize: Size(width: 3, height: 1))
        
        super.init(isLocked: false)
        lineColor = .getBorder
        isClipped = true
        children = [optionStringView]
    }
    
    var minSize: Size {
        return optionStringView.minSize
    }
    override func updateLayout() {
        updateTextPosition()
    }
    private func updateTextPosition() {
        let optionStringMinSize = optionStringView.minSize
        let x = bounds.width - optionStringMinSize.width
        let y = ((bounds.height - optionStringMinSize.height) / 2).rounded()
        optionStringView.frame = Rect(origin: Point(x: x, y: y), size: optionStringMinSize)
    }
    func updateWithModel() {
        updateString()
    }
    private func updateString() {
        optionStringView.text = option.displayText(with: model)
        updateTextPosition()
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
    
    let classNameView: TextFormView
    var thumbnailView: View {
        didSet {
            children = [classNameView, thumbnailView]
        }
    }
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        classNameView = TextFormView(text: Model.name, font: .bold)
        
        thumbnailView = MiniView.thumbnailViewWith(model: binder[keyPath: keyPath], frame: Rect())
        thumbnailView.lineColor = .formBorder
        
        super.init(isLocked: false)
        children = [classNameView, thumbnailView]
    }
    
    static var defaultMinWidth: Real {
        return 80
    }
    static var defaultThumbnailWidth: Real {
        return 60
    }
    var minSize: Size {
        let padding = Layouter.smallPadding, minClassNameSize = classNameView.minSize
        let width = max(MiniView.defaultMinWidth,
                        minClassNameSize.width + padding + MiniView.defaultThumbnailWidth)
        return Size(width: width, height: minClassNameSize.height + padding * 2)
    }
    static func thumbnailFrame(withSize size: Size,
                               leftWidth: Real) -> Rect {
        let padding = Layouter.smallPadding
        return Rect(x: leftWidth,
                    y: padding,
                    width: size.width - leftWidth - padding,
                    height: size.height - padding * 2)
    }
    override func updateLayout() {
        let padding = Layouter.basicPadding
        let classNameSize = classNameView.minSize
        let classNameOrigin = Point(x: padding,
                                    y: bounds.height - classNameSize.height - padding)
        classNameView.frame = Rect(origin: classNameOrigin, size: classNameSize)
        thumbnailView.frame = MiniView.thumbnailFrame(withSize: bounds.size,
                                                      leftWidth: classNameView.frame.maxX + padding)
    }
    func updateWithModel() {
        let thumbnailFrame = MiniView.thumbnailFrame(withSize: bounds.size,
                                                     leftWidth: classNameView.frame.width)
        thumbnailView = MiniView.thumbnailViewWith(model: model, frame: thumbnailFrame)
    }
    static func thumbnailViewWith(model: Model, frame: Rect) -> View {
        return model.thumbnailView(withFrame: frame)
    }
}
