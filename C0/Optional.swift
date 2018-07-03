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
extension Optional: StandardViewable where Wrapped: Object.Value & Viewable {
    func standardViewWith<T: BinderProtocol>
        (binder: T, keyPath: ReferenceWritableKeyPath<T, Optional>) -> ModelView {
        
        return OptionalView(binder: binder, keyPath: keyPath)
    }
}
extension Optional: MiniViewable where Wrapped: Object.Value & Viewable {}
extension Optional: Viewable where Wrapped: Object.Value & Viewable {}
extension Optional: ObjectDecodable where Wrapped: ObjectDecodable {}
extension Optional: ThumbnailViewable where Wrapped: ThumbnailViewable {}
extension Optional: ObjectViewable where Wrapped: Object.Value & Viewable {}

final class OptionalView<Wrapped: Object.Value & Viewable, U: BinderProtocol>
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
    
    var viewableType: ViewableType {
        didSet { updateLayout() }
    }
    var wrappedView: ModelView?
    var noneNameView: TextFormView
    
    init(binder: Binder, keyPath: BinderKeyPath, viewableType: ViewableType = .standard) {
        self.binder = binder
        self.keyPath = keyPath
        
        self.viewableType = viewableType
        let name = Wrapped.name + ": " + Text(english: "None", japanese: "なし")
        noneNameView = TextFormView(text: name)
        
        super.init(isLocked: false)
        if let wrapped = binder[keyPath: keyPath] {
            let wrappedView = wrapped.viewWith(binder: binder,
                                               keyPath: keyPath.appending(path: \Model.!),
                                               type: viewableType)
            self.wrappedView = wrappedView
            children = [wrappedView]
        } else {
            children = [noneNameView]
        }
    }
    
    var minSize: Size {
        let padding = Layouter.basicPadding
        let size: Size
        if let wrappedView = wrappedView {
            size = wrappedView.minSize
        } else {
            size = noneNameView.minSize
        }
        return size + padding * 2
    }
    override func updateLayout() {
        let padding = Layouter.basicPadding
        if let wrappedView = wrappedView {
            wrappedView.frame = bounds.inset(by: padding)
        } else {
            let noneNameMinSize = noneNameView.minSize
            let origin =  Point(x: padding,
                                y: bounds.height - noneNameMinSize.height - padding)
            noneNameView.frame = Rect(origin: origin, size: noneNameMinSize)
        }
    }
    func updateWithModel() {
        if let wrapped = binder[keyPath: keyPath] {
            if children.first != wrappedView {
                let wrappedView
                    = wrapped.viewWith(binder: binder,
                                       keyPath: keyPath.appending(path: \Model.!),
                                       type: viewableType)
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
