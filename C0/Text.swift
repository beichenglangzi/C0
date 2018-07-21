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

struct Text: Codable {
    var stringLines: [StringLine]
}
extension Text: Viewable {
    func viewWith<T: BinderProtocol>
        (binder: T, keyPath: ReferenceWritableKeyPath<T, Text>) -> ModelView {
        
        return TextView(binder: binder, keyPath: keyPath)
    }
}
extension Text: ObjectViewable {}

final class TextView<T: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = Text
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((TextView<Binder>, BasicNotification) -> ())]()

    let stringLinesView: ArrayView<StringLine, Binder>
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        stringLinesView = ArrayView(binder: binder,
                                    keyPath: keyPath.appending(path: \Model.stringLines))
        
        super.init(isLocked: false)
        children = [stringLinesView]
    }
}
