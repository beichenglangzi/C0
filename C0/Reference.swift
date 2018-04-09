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
    
    let classNameLabel = Label(text: Reference.name, font: .bold)
    let nameLabel = Label()
    let classDescriptionLabel = Label()
    let instanceDescriptionLabel = Label()
    let viewDescriptionLabel = Label()
    let commentLabel = Label()
    
    init(reference: Reference = Reference()) {
        self.reference = reference
        super.init()
        isClipped = true
        replace(children: [classNameLabel, nameLabel, instanceDescriptionLabel])
        updateWithReference()
    }
    
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    private func updateLayout() {
        let padding = Layout.basicPadding
        classNameLabel.frame.origin = CGPoint(x: padding,
                                              y: bounds.height - classNameLabel.frame.height - padding)
        var y = bounds.height - nameLabel.frame.height - padding
        nameLabel.frame.origin = CGPoint(x: classNameLabel.frame.maxX + padding,
                                         y: y)
        instanceDescriptionLabel.textFrame.frameWidth
            = (bounds.width - padding * 2 - instanceDescriptionLabel.padding * 2).d
        y -= instanceDescriptionLabel.frame.height + padding
        instanceDescriptionLabel.frame.origin = CGPoint(x: padding, y: y)
    }
    private func updateWithReference() {
        nameLabel.localization = reference.name
        instanceDescriptionLabel.localization = reference.instanceDescription
        updateLayout()
    }
    
    func reference(with event: TapEvent) -> Reference? {
        return reference.reference
    }
}
