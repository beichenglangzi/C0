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

import struct Foundation.UUID

extension UUID {
    static let zero = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
}

struct UU<Value: Object.Value & Viewable>: Codable {
    var value: Value
    var id: UUID
    
    init(_ value: Value, id: UUID = UUID()) {
        self.value = value
        self.id = id
    }
    mutating func newID() {
        id = UUID()
    }
}
extension UU: ValueChain {
    var chainValue: Any { return value }
}
extension UU: Equatable {
    static func == (lhs: UU<Value>, rhs: UU<Value>) -> Bool {
        return lhs.id == rhs.id
    }
}
extension UU: Viewable {
    func viewWith<T: BinderProtocol>
        (binder: T, keyPath: ReferenceWritableKeyPath<T, UU<Value>>) -> ModelView {
        
        return UUView(binder: binder, keyPath: keyPath)
    }
}
extension UU: ObjectViewable {}

final class UUView<Value: Object.Value & Viewable, Binder: BinderProtocol>
: ModelView, BindableReceiver {
    typealias Model = UU<Value>
    typealias BinderKeyPath = ReferenceWritableKeyPath<Binder, Model>
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((UUView<Value, Binder>, BasicPhaseNotification<Model>) -> ())]()
    
    var valueView: View
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        valueView = binder[keyPath: keyPath].value
            .viewWith(binder: binder,
                      keyPath: keyPath.appending(path: \Model.value))
        
        super.init(isLocked: false)
        children = [valueView]
    }
}
