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

protocol NotificationBinderProtocol {
    var notification: ((Object.Value, BasicNotification) -> ())? { get set }
}
final class BasicBinder<Model: Object.Value>: BinderProtocol, NotificationBinderProtocol {
    var rootModel: Model {
        didSet { notification?(rootModel, .didChange) }
    }
    init(rootModel: Model) {
        self.rootModel = rootModel
    }
    var notification: ((Object.Value, BasicNotification) -> ())?
}

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

protocol Viewable {
    func viewWith<T: BinderProtocol>(binder: T,
                                     keyPath: ReferenceWritableKeyPath<T, Self>) -> ModelView
}

protocol Modeler: class {
    func updateWithModel()
}
typealias ModelView = View & Modeler
extension Modeler where Self: View {
    func updateWithModel() {
        children.forEach { ($0 as? ModelView)?.updateWithModel() }
    }
}

protocol BindableReceiver: Modeler, Assignable {
    associatedtype Model: Object.Value
    associatedtype Binder: BinderProtocol
    associatedtype Notification: NotificationProtocol
    var model: Model { get set }
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
    func clippedModel(_ model: Model) -> Model {
        return model
    }
    func reset(for p: Point, _ version: Version) {}
    
    var copiedObject: Object {
        if let valueChain = model as? ValueChain,
            let value = valueChain.rootChainValue as? Object.Value {
            
            return Object(value)
        } else {
            return Object(model)
        }
    }
    func paste(_ object: Object,
               with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version) {
        if let model = object.value as? Model {
            push(clippedModel(model), to: version)
            return
        }
    }
}
