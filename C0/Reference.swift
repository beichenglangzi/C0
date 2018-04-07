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
    static var name: Localization { get }
    static var classDescription: Localization { get }
    var instanceDescription: Localization { get }
    var viewDescription: Localization { get }
    var reference: Reference { get }
}
extension Referenceable {
    static var classDescription: Localization {
        return Localization()
    }
    var instanceDescription: Localization {
        return Localization()
    }
    var viewDescription: Localization {
        return Localization()
    }
    var reference: Reference {
        return Reference(name: Self.name,
                         classDescription: Self.classDescription,
                         instanceDescription: instanceDescription,
                         viewDescription: viewDescription)
    }
}

struct Reference {
    var name: Localization, classDescription: Localization
    var instanceDescription: Localization, viewDescription: Localization
    init(name: Localization = Localization(),
         classDescription: Localization = Localization(),
         instanceDescription: Localization = Localization(),
         viewDescription: Localization = Localization()) {
        self.name = name
        self.classDescription = classDescription
        self.instanceDescription = instanceDescription
        self.viewDescription = viewDescription
    }
}
extension Reference: Referenceable {
    static let name = Localization(english: "Reference", japanese: "情報")
}

/**
 # Issue
 - リファレンス表示の具体化
 */
final class ReferenceView: View {
    var reference = Reference() {
        didSet {
            updateWithReference()
        }
    }
    
    let minWidth = 200.0.cf
    let nameLabel = Label()
    
    init(reference: Reference = Reference()) {
        self.reference = reference
        super.init()
        fillColor = .background
        updateWithReference()
    }
    
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    private func updateLayout() {
        
    }
    private func updateWithReference() {
        nameLabel.localization = reference.name
    }
    
    func lookUp(with event: TapEvent) -> Reference? {
        return reference.reference
    }
}

final class ReferenceManagerView {
    func open() {
//        let p = event.location.integral
//        let responder = self.responder(with: indicatedLayer(with: event))
//        let referenceView = ReferenceView(reference: responder.lookUp(with: event))
//        let panel = Panel(isUseHedding: true)
//        panel.contents = [referenceView]
//        panel.openPoint = p.integral
//        panel.openViewPoint = rootView.point(from: event)
//        panel.subIndicatedParent = rootView
    }
//    description: Localization(english: "Close: Move cursor to outside",
//    japanese: "閉じる: カーソルを外に出す"))
}
