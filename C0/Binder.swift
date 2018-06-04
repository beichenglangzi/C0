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
    var rootModel: Model {
        didSet { notification?(self, .didChange) }
    }
    init(rootModel: Model) {
        self.rootModel = rootModel
    }
    var notification: ((BasicBinder<Model>, BasicNotification) -> ())?
}

/**
 Compiler Issue: Protocolとenumのcaseが衝突する
 */
protocol NotificationProtocol {
    static var _didChange: Self { get }
}
enum BasicNotification: NotificationProtocol {
    case didChange
    
    static var _didChange: BasicNotification {
        return .didChange
    }
}
enum BasicPhaseNotification<Model>: NotificationProtocol {
    case didChange
    case didChangeFromPhase(Phase, beginModel: Model)
    
    static var _didChange: BasicPhaseNotification {
        return .didChange
    }
}

protocol Modeler: class {
    func updateWithModel()
}
typealias ModelView = View & Modeler

protocol BindableReceiver: Modeler, Assignable, IndicatableResponder {
    associatedtype Model: Object.Value
    associatedtype Binder: BinderProtocol
    associatedtype Notification: NotificationProtocol
    var model: Model { get set }
    var defaultModel: Model { get }
    func clippedModel(_ model: Model) -> Model
    var binder: Binder { get set }
    var keyPath: ReferenceWritableKeyPath<Binder, Model> { get set }
    var notifications: [((Self, Notification) -> ())] { get }
    func push(_ model: Model, to version: Version)
    func capture(_ model: Model, to version: Version)
}
extension BindableReceiver {
    typealias BinderKeyPath = ReferenceWritableKeyPath<Binder, Model>
    var model: Model {
        get { return binder[keyPath: keyPath] }
        set {
            binder[keyPath: keyPath] = newValue
            notifications.forEach { $0(self, ._didChange) }
            updateWithModel()
        }
    }
    
    func push(_ model: Model, to version: Version) {
        version.registerUndo(withTarget: self) { [oldModel = self.model, unowned version] in
            $0.push(oldModel, to: version)
        }
        self.model = model
    }
    func capture(_ model: Model, to version: Version) {
        version.registerUndo(withTarget: self) { [oldModel = self.model, unowned version] in
            $0.push(oldModel, to: version)
        }
    }
}
extension BindableReceiver {
    var indicatedLineColor: Color? {
        return .indicated
    }
}
extension BindableReceiver {
    func clippedModel(_ model: Model) -> Model {
        return model
    }
    func reset(for p: Point, _ version: Version) {
        push(defaultModel, to: version)
    }
    func copiedObjects(at p: Point) -> [Object] {
        return [Object(model)]
    }
    func paste(_ values: [Any], for p: Point, _ version: Version) {
        for value in values {
            if let model = Model(anyValue: value) {
                push(clippedModel(model), to: version)
                return
            }
        }
    }
}

protocol BindableGetterReceiver: Modeler, Copiable, IndicatableResponder {
    associatedtype Model: Object.Value
    associatedtype Binder: BinderProtocol
    var model: Model { get }
    var binder: Binder { get set }
    var keyPath: KeyPath<Binder, Model> { get set }
}
extension BindableGetterReceiver {
    typealias BinderKeyPath = KeyPath<Binder, Model>
    var model: Model {
        return binder[keyPath: keyPath]
    }
}
extension BindableGetterReceiver {
    var indicatedLineColor: Color? {
        return .indicated
    }
}
extension BindableGetterReceiver {
    func copiedObjects(at p: Point) -> [Object] {
        return [Object(model)]
    }
}

