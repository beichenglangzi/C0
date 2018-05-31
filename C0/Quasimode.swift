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

struct Quasimode {
    var modifierEventTypes: [AlgebraicEventType] {
        didSet { updateAllEventableTypes() }
    }
    var eventTypes: [AlgebraicEventType] {
        didSet { updateAllEventableTypes() }
    }
    
    private(set) var allEventTypes: [AlgebraicEventType]
    private mutating func updateAllEventableTypes() {
        allEventTypes = modifierEventTypes + eventTypes
    }
    
    init(modifier modifierEventTypes: [AlgebraicEventType] = [],
         _ eventTypes: [AlgebraicEventType]) {
        
        self.modifierEventTypes = modifierEventTypes
        self.eventTypes = eventTypes
        allEventTypes = modifierEventTypes + eventTypes
    }
    
    var displayText: Text {
        let mets = modifierEventTypes
        let mt = mets.reduce(into: Text()) { $0 += $0.isEmpty ? $1.name : " " + $1.name }
        let ets = eventTypes
        let t = ets.reduce(into: Text()) { $0 += $0.isEmpty ? $1.name : " " + $1.name }
        return mt.isEmpty ? t : "[" + mt + "] " + t
    }
}
extension Quasimode: Referenceable {
    static let name = Text(english: "Quasimode", japanese: "擬似モード")
}
extension Quasimode: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return displayText.thumbnailView(withFrame: frame, sizeType)
    }
}

final class QuasimodeView<T: BinderProtocol>: View, BindableGetterReceiver {
    typealias Model = Quasimode
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((QuasimodeView<Binder>, BasicNotification) -> ())]()
    
    var isSizeToFit: Bool
    var textView: TextFormView
    
    init(binder: Binder, keyPath: BinderKeyPath,
         frame: Rect = Rect(), isSizeToFit: Bool = true) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        self.isSizeToFit = isSizeToFit
        textView = TextFormView(text: binder[keyPath: keyPath].displayText,
                                font: Font(monospacedSize: 10), frameAlignment: .right)
        
        super.init()
        if isSizeToFit {
            bounds = defaultBounds
        } else {
            self.frame = frame
        }
        children = [textView]
        updateLayout()
    }
    
    override var defaultBounds: Rect {
        return Rect(x: 0, y: 0,
                    width: textView.bounds.width, height: textView.bounds.height)
    }
    override func updateLayout() {
        textView.frame.origin = Point(x: 0,
                                      y: bounds.height - textView.frame.height)
    }
    func updateWithModel() {
        textView.text = model.displayText
        if isSizeToFit {
            bounds = defaultBounds
            updateLayout()
        }
    }
}
extension QuasimodeView: Localizable {
    func update(with locale: Locale) {
        if isSizeToFit {
            bounds = defaultBounds
        }
        updateLayout()
    }
}
