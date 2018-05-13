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

protocol BinderProtocol: class {
    associatedtype Model
    var rootModel: Model { get set }
    init(rootModel: Model)
}

final class BasicBinder<Model>: BinderProtocol {
    var rootModel: Model
    init(rootModel: Model) {
        self.rootModel = rootModel
    }
}

protocol BindableReceiver: class {
    associatedtype Model
    associatedtype Binder: BinderProtocol
    associatedtype BinderKeyPath: ReferenceWritableKeyPath<Binder, Model>
    var model: Model { get set }
    var binder: Binder { get set }
    var keyPath: BinderKeyPath { get set }
    func updateWithModel()
    func push(_ model: Model, to version: Version)
    func capture(_ model: Model, to version: Version)
}
extension BindableReceiver {
    typealias BinderKeyPath = ReferenceWritableKeyPath<Binder, Model>
    var model: Model {
        get {
            return binder[keyPath: keyPath]
        }
        set {
            binder[keyPath: keyPath] = newValue
            updateWithModel()
        }
    }
    
    func push(_ model: Model, to version: Version) {
        version.registerUndo(withTarget: self) { [oldModel = model, unowned version] in
            $0.push(oldModel, to: version)
        }
        self.model = model
    }
    func capture(_ model: Model, to version: Version) {
        version.registerUndo(withTarget: self) { [oldModel = model, unowned version] in
            $0.push(oldModel, to: version)
        }
    }
}

protocol BindableGetterReceiver: class {
    associatedtype Model
    associatedtype Binder: BinderProtocol
    associatedtype BinderKeyPath: KeyPath<Binder, Model>
    var model: Model { get }
    var binder: Binder { get set }
    var keyPath: BinderKeyPath { get set }
    func updateWithModel()
}
extension BindableGetterReceiver {
    typealias BinderKeyPath = KeyPath<Binder, Model>
    var model: Model {
        return binder[keyPath: keyPath]
    }
}
