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

extension Optional: Referenceable {
    static var name: Text {
        return Text(english: "Optional", japanese: "オプショナル")
    }
}
extension Optional: AnyInitializable where Wrapped: ObjectDecodable {}
extension Optional: ObjectDecodable where Wrapped: ObjectDecodable {}
extension Optional: ThumbnailViewable where Wrapped: ThumbnailViewable {}
extension Optional: AbstractViewable where Wrapped: Object.Value & AbstractViewable {
    func abstractViewWith<T>(binder: T, keyPath: ReferenceWritableKeyPath<T, Optional>,
                             frame: Rect, _ sizeType: SizeType,
                             type: AbstractType) -> ModelView where T : BinderProtocol {
        switch type {
        case .normal:
            return OptionalView(binder: binder, keyPath: keyPath,
                                frame: frame, sizeType: sizeType)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath, frame: frame, sizeType)
        }
    }
}
extension Optional: ObjectViewable where Wrapped: Object.Value & AbstractViewable {}

final class OptionalView<Wrapped: Object.Value & AbstractViewable, U: BinderProtocol>
: ModelView, BindableReceiver {
    
    typealias Model = Optional<Wrapped>
    typealias Binder = U
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((OptionalView<Wrapped, Binder>, BasicNotification) -> ())]()
    
    var defaultModel: Optional<Wrapped> {
        return .none
    }
    
    var sizeType: SizeType {
        didSet { updateLayout() }
    }
    var type: AbstractType {
        didSet { updateLayout() }
    }
    
    var wrappedView: ModelView?
    var noneNameView: TextFormView
    
    init(binder: Binder, keyPath: BinderKeyPath,
         frame: Rect = Rect(), sizeType: SizeType = .regular, type: AbstractType = .normal) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        self.sizeType = sizeType
        self.type = type
        let name = Wrapped.name + ": " + Text(english: "None", japanese: "なし")
        noneNameView = TextFormView(text: name,
                                    textMaterial: TextMaterial(font: Font.default(with: sizeType)))
        
        super.init()
        if let wrapped = binder[keyPath: keyPath] {
            let wrappedView = wrapped.abstractViewWith(binder: binder,
                                                       keyPath: keyPath.appending(path: \Model.!),
                                                       frame: Rect(),
                                                       sizeType, type: type)
            self.wrappedView = wrappedView
            children = [wrappedView]
        } else {
            children = [noneNameView]
        }
        self.frame = frame
    }
    override func updateLayout() {
        let padding = Layouter.padding(with: sizeType)
        if let wrappedView = wrappedView {
            wrappedView.frame = bounds.inset(by: padding)
        } else {
            noneNameView.frame.origin = Point(x: padding,
                                              y: bounds.height - noneNameView.frame.height - padding)
        }
    }
    func updateWithModel() {
        if let wrapped = binder[keyPath: keyPath] {
            if children.first != wrappedView {
                let wrappedView
                    = wrapped.abstractViewWith(binder: binder,
                                               keyPath: keyPath.appending(path: \Model.!),
                                               frame: Rect(),
                                               sizeType, type: type)
                self.wrappedView = wrappedView
                children = [wrappedView]
                updateLayout()
            }
            wrappedView?.updateWithModel()
        } else {
            if children.first != noneNameView {
                children = [noneNameView]
                updateLayout()
            }
        }
    }
}
