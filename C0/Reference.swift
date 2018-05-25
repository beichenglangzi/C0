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

protocol Referenceable {
    static var uninheritanceName: Text { get }
    static var name: Text { get }
    static var classDescription: Text { get }
}
extension Referenceable {
    static var uninheritanceName: Text {
        return name
    }
    static var classDescription: Text {
        return Text(english: "None", japanese: "なし")
    }
}

/**
 Issue: リファレンス表示の具体化
 */
struct Reference: Codable {
    let name: Text, classDescription: Text, viewDescription: Text
}
extension Reference {
    static func displayText(with keyPath: PartialKeyPath<Reference>) -> Text {
        switch keyPath {
        case \Reference.classDescription:
            return Text(english: "Class Description", japanese: "クラス説明")
        case \Reference.classDescription:
            return Text(english: "Class Description", japanese: "クラス説明")
        case \Reference.viewDescription:
            return Text(english: "View Description", japanese: "表示説明")
        default: fatalError("No case")
        }
    }
}
extension Reference: Referenceable {
    static let name = Text(english: "Reference", japanese: "リファレンス")
}
extension Reference: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return name.thumbnailView(withFrame: frame, sizeType)
    }
}
extension Reference: AbstractViewable {
    func abstractViewWith<T : BinderProtocol>(binder: T,
                                              keyPath: ReferenceWritableKeyPath<T, Reference>,
                                              frame: Rect, _ sizeType: SizeType,
                                              type: AbstractType) -> View {
        switch type {
        case .normal:
            return ReferenceView(binder: binder, keyPath: keyPath,
                                 frame: frame, sizeType: sizeType)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath, frame: frame, sizeType)
        }
    }
}

final class ReferenceView<T: BinderProtocol>: View, BindableReceiver {
    typealias Model = Reference
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((ReferenceView<Binder>, BasicNotification) -> ())]()
    
    let classNameView: TextFormView
    let nameView: StringGetterView<Binder>
    let classClassDescriptionView: TextFormView
    let classDescriptionView: StringGetterView<Binder>
    let classViewDescriptionView: TextFormView
    let viewDescriptionView: StringGetterView<Binder>
    
    init(binder: Binder, keyPath: BinderKeyPath,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        classNameView = TextFormView(text: Reference.name, font: .bold)
        
        let ntKeyPath = keyPath.appending(path: \Reference.name.currentString)
        nameView = StringGetterView(binder: binder, keyPath: ntKeyPath)
        
        let cdt = Reference.displayText(with: \Reference.classDescription)
        classClassDescriptionView = TextFormView(text: cdt, font: .small)
        let cdtKeyPath = keyPath.appending(path: \Reference.classDescription.currentString)
        classDescriptionView = StringGetterView(binder: binder, keyPath: cdtKeyPath)
        
        let vdt = Reference.displayText(with: \Reference.viewDescription)
        classViewDescriptionView = TextFormView(text: vdt, font: .small)
        let vdtKeyPath = keyPath.appending(path: \Reference.viewDescription.currentString)
        viewDescriptionView = StringGetterView(binder: binder, keyPath: vdtKeyPath)
        
        super.init()
        isClipped = true
        children = [classNameView, nameView,
                    classClassDescriptionView, classDescriptionView,
                    classViewDescriptionView, viewDescriptionView]
        updateWithModel()
    }
    
    override func updateLayout() {
        let padding = Layout.basicPadding
        classNameView.frame.origin = Point(x: padding,
                                           y: bounds.height - classNameView.frame.height - padding)
        
        let textFrameWidth = bounds.width
        classDescriptionView.frame.size.width = textFrameWidth
        viewDescriptionView.frame.size.width = textFrameWidth
        
        updateWithModel()
    }
    func updateWithModel() {
        nameView.updateWithModel()
        classDescriptionView.updateWithModel()
        viewDescriptionView.updateWithModel()
        
        let padding = Layout.basicPadding
        var y = bounds.height - nameView.frame.height - padding
        nameView.frame.origin = Point(x: classNameView.frame.maxX + padding, y: y)
        y = bounds.height - classNameView.frame.height - padding
        y -= classClassDescriptionView.frame.height
        classClassDescriptionView.frame.origin = Point(x: padding, y: y)
        y -= classDescriptionView.frame.height
        classDescriptionView.frame.origin = Point(x: padding, y: y)
        y -= padding + classViewDescriptionView.frame.height
        classViewDescriptionView.frame.origin = Point(x: padding, y: y)
        y -= viewDescriptionView.frame.height
        viewDescriptionView.frame.origin = Point(x: padding, y: y)
    }
}
extension ReferenceView: Localizable {
    func update(with locale: Locale) {
        updateWithModel()
    }
}
extension ReferenceView: Queryable {
    static var referenceableType: Referenceable.Type {
        return Reference.self
    }
}
