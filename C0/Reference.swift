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
    var reference: Reference { get }
}
extension Referenceable {
    static var uninheritanceName: Localization {
        return name
    }
    static var classDescription: Localization {
        return Localization()
    }
    var reference: Reference {
        return Reference(name: Self.name, classDescription: Self.classDescription)
    }
}

/**
 Issue: リファレンス表示の具体化
 */
struct Reference {
    var name: Localization, classDescription: Localization, viewDescription: Localization
    init(name: Localization = Localization(),
         classDescription: Localization = Localization(),
         viewDescription: Localization = Localization()) {
        self.name = name
        self.classDescription = classDescription
        self.viewDescription = viewDescription
    }
}
extension Reference: Referenceable {
    static let name = Localization(english: "Reference", japanese: "情報")
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
    let classViewDescriptionView = TextView(text: Localization(english: "View Description:",
                                                               japanese: "表示説明:"),
                                            font: .small)
    let viewDescriptionView = TextView()
    
    init(reference: Reference = Reference()) {
        self.reference = reference
        super.init()
        isClipped = true
        replace(children: [classNameView, nameView,
                           classClassDescriptionView, classDescriptionView,
                           classViewDescriptionView, viewDescriptionView])
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
        
        let frameWidth = (bounds.width - padding * 2).d
        classDescriptionView.textFrame.frameWidth = frameWidth
        viewDescriptionView.textFrame.frameWidth = frameWidth
        
        var y = bounds.height - nameView.frame.height - padding
        nameView.frame.origin = CGPoint(x: classNameView.frame.maxX + padding,
                                         y: y)
        y = bounds.height - classNameView.frame.height - padding
        y -= classClassDescriptionView.frame.height
        classClassDescriptionView.frame.origin = CGPoint(x: padding, y: y)
        y -= classDescriptionView.frame.height
        classDescriptionView.frame.origin = CGPoint(x: padding, y: y)
        y -= padding + classViewDescriptionView.frame.height
        classViewDescriptionView.frame.origin = CGPoint(x: padding, y: y)
        y -= viewDescriptionView.frame.height
        viewDescriptionView.frame.origin = CGPoint(x: padding, y: y)
    }
    private func updateWithReference() {
        nameView.text = reference.name
        classDescriptionView.text = reference.classDescription
        viewDescriptionView.text = reference.viewDescription
        updateLayout()
    }
    
    func reference(with event: TapEvent) -> Reference? {
        return reference.reference
    }
}
