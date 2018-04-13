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

protocol Referenceable {
    static var uninheritanceName: Localization { get }
    static var name: Localization { get }
    static var classDescription: Localization { get }
    var instanceDescription: Localization { get }
    static var comment: Localization { get }
    var reference: Reference { get }
}
extension Referenceable {
    static var uninheritanceName: Localization {
        return name
    }
    static var classDescription: Localization {
        return Localization()
    }
    var instanceDescription: Localization {
        return Localization()
    }
    static var comment: Localization {
        return Localization()
    }
    var reference: Reference {
        return Reference(name: Self.name,
                         classDescription: Self.classDescription,
                         instanceDescription: instanceDescription,
                         comment: Self.comment)
    }
}

struct Reference {
    var name: Localization, classDescription: Localization
    var instanceDescription: Localization, viewDescription: Localization, comment: Localization
    init(name: Localization = Localization(),
         classDescription: Localization = Localization(),
         instanceDescription: Localization = Localization(),
         viewDescription: Localization = Localization(),
         comment: Localization = Localization()) {
        self.name = name
        self.classDescription = classDescription
        self.instanceDescription = instanceDescription
        self.viewDescription = viewDescription
        self.comment = comment
    }
}
extension Reference: Referenceable {
    static let name = Localization(english: "Reference", japanese: "情報")
    static let comment = Localization("Issue: リファレンス表示の具体化")
}
extension Reference: ObjectViewExpression {
    func thumbnail(withBounds bounds: CGRect, sizeType: SizeType) -> Layer {
        return name.view(withBounds: bounds, sizeType: sizeType)
    }
}

final class ReferenceView: View {
    var reference = Reference() {
        didSet {
            updateWithReference()
        }
    }
    
    let classNameView = TextView(text: Reference.name, font: .bold)
    let nameView = TextView()
    let classClassDescriptionView = TextView(text: Localization(english: "Class Description:",
                                                                japanese: "クラス説明:"),
                                             font: .small)
    let classDescriptionView = TextView()
    let classInstanceDescriptionView = TextView(text: Localization(english: "Instance Description:",
                                                                   japanese: "インスタンス説明:"),
                                                font: .small)
    let instanceDescriptionView = TextView()
    let classViewDescriptionView = TextView(text: Localization(english: "View Description:",
                                                               japanese: "表示説明:"),
                                            font: .small)
    let viewDescriptionView = TextView()
    let classCommentView = TextView(text: Localization(english: "Comment:", japanese: "コメント:"),
                                    font: .small)
    let commentView = TextView()
    
    init(reference: Reference = Reference()) {
        self.reference = reference
        super.init()
        isClipped = true
        replace(children: [classNameView, nameView,
                           classClassDescriptionView, classDescriptionView,
                           classInstanceDescriptionView, instanceDescriptionView,
                           classViewDescriptionView, viewDescriptionView,
                           classCommentView, commentView])
        updateWithReference()
    }
    
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    private func updateLayout() {
        let padding = Layout.basicPadding
        classNameView.frame.origin = CGPoint(x: padding,
                                             y: bounds.height - classNameView.frame.height - padding)
        
        let frameWidth = (bounds.width - padding * 2 - instanceDescriptionView.padding * 2).d
        classDescriptionView.textFrame.frameWidth = frameWidth
        instanceDescriptionView.textFrame.frameWidth = frameWidth
        viewDescriptionView.textFrame.frameWidth = frameWidth
        commentView.textFrame.frameWidth = frameWidth
        
        var y = bounds.height - nameView.frame.height - padding
        nameView.frame.origin = CGPoint(x: classNameView.frame.maxX + padding,
                                         y: y)
        y = bounds.height - classNameView.frame.height - padding
        y -= classClassDescriptionView.frame.height
        classClassDescriptionView.frame.origin = CGPoint(x: padding, y: y)
        y -= classDescriptionView.frame.height
        classDescriptionView.frame.origin = CGPoint(x: padding, y: y)
        y -= padding + classInstanceDescriptionView.frame.height
        classInstanceDescriptionView.frame.origin = CGPoint(x: padding, y: y)
        y -= instanceDescriptionView.frame.height + padding
        instanceDescriptionView.frame.origin = CGPoint(x: padding, y: y)
        y -= padding + classViewDescriptionView.frame.height
        classViewDescriptionView.frame.origin = CGPoint(x: padding, y: y)
        y -= viewDescriptionView.frame.height + padding
        viewDescriptionView.frame.origin = CGPoint(x: padding, y: y)
        y -= padding + classCommentView.frame.height
        classCommentView.frame.origin = CGPoint(x: padding, y: y)
        y -= commentView.frame.height + padding
        commentView.frame.origin = CGPoint(x: padding, y: y)
    }
    private func updateWithReference() {
        nameView.localization = reference.name
        classDescriptionView.localization = reference.classDescription
        instanceDescriptionView.localization = reference.instanceDescription
        viewDescriptionView.localization = reference.viewDescription
        commentView.localization = reference.comment
        updateLayout()
    }
    
    func reference(with event: TapEvent) -> Reference? {
        return reference.reference
    }
}
