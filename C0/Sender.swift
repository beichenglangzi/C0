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
import class Foundation.OperationQueue

final class Sender {
    typealias RootView = ModelView & Undoable & Zoomable & CopiableViewer & MakableStrokable & MakableKeyInputtable & Assignable
    
    var rootView: RootView
    let actionList = ActionList()
    var eventMap = EventMap()
    var actionMaps = [ActionMap]()
    var backgroundQueue = OperationQueue()
    
    init(rootView: RootView) {
        self.rootView = rootView
    }
    deinit {
        backgroundQueue.cancelAllOperations()
    }
    
    func actionMapIndex<T: Event>(with event: T) -> Array<ActionMap>.Index? {
        return actionMaps.index(where: { $0.contains(event) })
    }
    
    func stopEditableEvents() {
        actionMaps.forEach {
            if $0.action.isEditable {
                var actionMap = $0
                actionMap.phase = .ended
                send(actionMap)
            }
        }
        actionMaps = []
    }
    func stopAllEvents() {
        actionMaps.forEach {
            var actionMap = $0
            actionMap.phase = .ended
            send(actionMap)
        }
        actionMaps = []
    }
    
    func send<T: Event>(_ event: T) {
        switch event.value.phase {
        case .began:
            eventMap.append(event)
            if let actionMap = ActionMap(event, eventMap, actionList.actions) {
                actionMaps.append(actionMap)
                send(actionMap)
            } else if let inputEvent = event as? InputEvent {
                input(inputEvent)
            }
        case .changed:
            eventMap.replace(event)
            if let index = actionMapIndex(with: event) {
                actionMaps[index].replace(event)
                send(actionMaps[index])
            }
        case .ended:
            eventMap.replace(event)
            if let index = actionMapIndex(with: event) {
                actionMaps[index].replace(event)
                send(actionMaps[index])
                actionMaps.remove(at: index)
            }
            eventMap.remove(event)
        }
    }
    
    func input(_ inputEvent: InputEvent) {
        if let receiver = rootView.at(inputEvent.value.rootLocation, (View & KeyInputtable).self) {
            let p = receiver.convertFromRoot(inputEvent.value.rootLocation)
            receiver.insert(inputEvent.type.name.currentString, for: p, rootView.version)
        } else if let receiver = ((userObject as? MakableKeyInputtable)?.keyInputable(withRootView: rootView, at: inputEvent.value.rootLocation) ?? rootView.keyInputable(withRootView: rootView, at: inputEvent.value.rootLocation)) as? (View & KeyInputtable) {
            
            let p = receiver.convertFromRoot(inputEvent.value.rootLocation)
            receiver.insert(inputEvent.type.name.currentString, for: p, rootView.version)
        }
    }
    
    typealias CopiedObjectViewer = View & CopiableViewer
    typealias AssignableReceiver = View & Assignable
    typealias CollectionReceiver = View & CollectionAssignable
    typealias CopiableReceiver = View & Copiable
    typealias NewableReceiver = View & Newable
    typealias ExportableReceiver = View & Exportable
    typealias PointEditableReceiver = View & PointEditable
    typealias PointMovableReceiver = View & PointMovable
    typealias VertexMovableReceiver = View & VertexMovable
    typealias MovableReceiver = View & Movable
    
    private var zoomableObject: ZoomableObject?
    private var strokableUserObject: Strokable?
    private var movableObject: Movable?
    
    private var fp = Point()
    private var layoutableViews = [(oldP: Point, reciever: MovableReceiver)]()
    private var viewPointMover: ViewPointMover?, viewVertexMover: ViewVertexMover?
    
    func userObject(at p: Point) -> Newable & Lockable & Findable & Exportable & CollectionAssignable & Movable {
        let tmo: TransformingMovableObject?
        if let view = rootView.at(p, (View & MovableOrigin).self) {
            tmo = TransformingMovableObject(viewAndFirstOrigins: [(view, view.transform.translation)],
                                            rootView: rootView)
        } else {
            tmo = nil
        }
        let userObject = UserObject(rootView: rootView, transformingMovableObject: tmo)
        if let view = rootView.at(p, Copiable.self) {
            userObject.copiedObject = view.copiedObject
        }
        return userObject
    }
    
    func send(_ actionMap: ActionMap) {
        switch actionMap.action {
        case actionList.zoomAction:
            guard let eventValue = actionMap.eventValues(with: PinchEvent.self).first else { return }
            if actionMap.phase == .began {
                zoomableObject = ZoomableObject(zoomableView: rootView)
            }
            zoomableObject?.zoom(with: eventValue, actionMap.phase, rootView.version)
            if actionMap.phase == .ended {
                zoomableObject = nil
            }
        case actionList.undoAction:
            guard actionMap.phase == .began else { break }
            stopAllEvents()
            rootView.version.undo()
        case actionList.redoAction:
            guard actionMap.phase == .began else { break }
            stopAllEvents()
            rootView.version.redo()
        case actionList.cutAction:
            guard actionMap.phase == .began else { break }
            guard let eventValue = actionMap.eventValues(with: InputEvent.self).first else { break }
            let userObject = self.userObject(at: eventValue.rootLocation)
            let copiedObject = userObject.copiedObject
            stopEditableEvents()
            userObject.remove(with: eventValue, actionMap.phase, rootView.version)
            rootView.push(copiedObject, to: rootView.version)
        case actionList.copyAction:
            guard actionMap.phase == .began else { break }
            guard let eventValue = actionMap.eventValues(with: InputEvent.self).first else { break }
            let userObject = self.userObject(at: eventValue.rootLocation)
            let copiedObject = userObject.copiedObject
            stopEditableEvents()
            rootView.push(copiedObject, to: rootView.version)
        case actionList.pasteAction:
            guard actionMap.phase == .began else { break }
            guard let eventValue = actionMap.eventValues(with: InputEvent.self).first else { break }
            let userObject = self.userObject(at: eventValue.rootLocation)
            stopEditableEvents()
            userObject.paste(rootView.copiedObject,
                             with: eventValue, actionMap.phase, rootView.version)
        case actionList.lockAction:
            guard actionMap.phase == .began else { break }
            guard let eventValue = actionMap.eventValues(with: InputEvent.self).first else { break }
            let userObject = self.userObject(at: eventValue.rootLocation)
            stopEditableEvents()
            userObject.lock(with: eventValue, actionMap.phase, rootView.version)
        case actionList.newAction:
            guard actionMap.phase == .began else { break }
            guard let eventValue = actionMap.eventValues(with: InputEvent.self).first else { break }
            let userObject = self.userObject(at: eventValue.rootLocation)
            stopEditableEvents()
            userObject.new(with: eventValue, actionMap.phase, rootView.version)
        case actionList.findAction:
            guard actionMap.phase == .began else { break }
            guard let eventValue = actionMap.eventValues(with: InputEvent.self).first else { break }
            let userObject = self.userObject(at: eventValue.rootLocation)
            stopEditableEvents()
            userObject.find(with: eventValue, actionMap.phase, rootView.version)
        case actionList.exportAction:
            guard actionMap.phase == .began else { break }
            guard let eventValue = actionMap.eventValues(with: InputEvent.self).first else { break }
            let userObject = self.userObject(at: eventValue.rootLocation)
            stopEditableEvents()
            userObject.export(with: eventValue, actionMap.phase, rootView.version)
        case actionList.strokeAction, actionList.lassoFillAction:
            guard let eventValue = actionMap.eventValues(with: DragEvent.self).first else { return }
            if actionMap.phase == .began {
                let userObject = self.userObject(at: eventValue.rootLocation)
                strokableUserObject = (userObject as? MakableStrokable)?
                    .strokable(withRootView: rootView) ?? rootView.strokable(withRootView: rootView)
            }
            strokableUserObject?.stroke(with: eventValue, actionMap.phase,
                                        isSurface: actionMap.action == actionList.lassoFillAction,
                                        rootView.version)
            if actionMap.phase == .ended {
                strokableUserObject = nil
            }
        case actionList.moveAction:
            guard let eventValue = actionMap.eventValues(with: DragEvent.self).first else { return }
            if actionMap.phase == .began {
                movableObject = userObject(at: eventValue.rootLocation)
            }
            movableObject?.move(with: eventValue, actionMap.phase, rootView.version)
            if actionMap.phase == .ended {
                movableObject = nil
            }
        default: break
        }
    }
}

final class UserObject: Newable, Lockable, Findable, Exportable, CollectionAssignable, Movable {
    var copiedObject = Object(Text(stringLines: [StringLine(string: "None", origin: Point())]))
    
    var rootView: Sender.RootView
//    var views: [View & Layoutable]
    
    var transformingMovableObject: TransformingMovableObject?
    
    init(rootView: Sender.RootView, transformingMovableObject: TransformingMovableObject?) {
        self.rootView = rootView
        self.transformingMovableObject = transformingMovableObject
    }
    
    func move(with eventValue: DragEvent.Value, _ phase: Phase, _ version: Version) {
        transformingMovableObject?.move(with: eventValue, phase, version)
    }
    
    func remove(with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version) {
        
    }
    func paste(_ object: Object,
               with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version) {
        rootView.paste(object, with: eventValue, phase, version)
    }
    
    func new(with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version) {
        
    }
    func lock(with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version) {
        
    }
    func find(with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version) {
        
    }
    func export(with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version) {
        
    }
}

protocol MakableKeyInputtable {
    func keyInputable(withRootView rootView: View, at p: Point) -> KeyInputtable
}

protocol Zoomable: class {
    func captureTransform(to version: Version)
    var zoomingView: View { get }
    var zoomingTransform: Transform { get set }
    func convertZoomingLocalFromZoomingView(_ p: Point) -> Point
    func convertZoomingLocalToZoomingView(_ p: Point) -> Point
}
final class ZoomableObject {
    typealias ZoomableView = View & Zoomable
    var zoomableView: ZoomableView
    
    init(zoomableView: ZoomableView) {
        self.zoomableView = zoomableView
    }
    
    var isEndSnap = true
    var minZ = -20.0.cg, maxZ = 20.0.cg, zInterval = 0.02.cg
    var correction = 3.0.cg
    private var beganZ = 0.0.cg, z = 0.0.cg
    
    func zoom(with eventValue: PinchEvent.Value, _ phase: Phase, _ version: Version) {
        if phase == .began {
            beganZ = zoomableView.zoomingTransform.z
            z = 0
            zoomableView.captureTransform(to: version)
        }
        let p = zoomableView.zoomingView.convertFromRoot(eventValue.rootLocation)
        zoom(at: p) {
            z += eventValue.magnification * correction
            let newZ = (beganZ + z).interval(scale: zInterval).clip(min: minZ, max: maxZ)
            zoomableView.zoomingTransform.z = newZ
        }
        if phase == .ended {
            if isEndSnap {
                zoomableView.zoomingTransform.translation
                    = zoomableView.zoomingTransform.translation.rounded()
            }
        }
    }
    private func zoom(at p: Point, closure: () -> ()) {
        let point = zoomableView.convertZoomingLocalFromZoomingView(p)
        closure()
        let newPoint = zoomableView.convertZoomingLocalToZoomingView(point)
        zoomableView.zoomingTransform.translation -= (newPoint - p)
    }
}

protocol Undoable {
    var version: Version { get }
}

protocol CopiableViewer: class {
    var copiedObject: Object { get }
    func push(_ copiedObject: Object, to version: Version)
}
protocol Copiable {
    var copiedObject: Object { get }
}
protocol Assignable: Copiable {
    func paste(_ object: Object,
               with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version)
}
protocol CollectionAssignable: Assignable {
    func remove(with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version)
}

protocol Newable {
    func new(with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version)
}
protocol Lockable {
    func lock(with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version)
}
protocol Findable {
    func find(with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version)
}
protocol Exportable {
    func export(with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version)
}

protocol Strokable: class {
    func stroke(with eventValue: DragEvent.Value, _ phase: Phase, isSurface: Bool, _ version: Version)
}

protocol ViewPointMover: class {
    var pointMovableView: View & PointMovable { get }
    func movePoint(for p: Point, first fp: Point, pressure: Real,
                   time: Real, _ phase: Phase)
}
protocol ViewVertexMover: class {
    var vertexMovableView: View & VertexMovable { get }
    func moveVertex(for p: Point, first fp: Point, pressure: Real,
                    time: Real, _ phase: Phase)
}
protocol PointMovable {
    func captureWillMovePoint(at p: Point, to version: Version)
    func makeViewPointMover() -> ViewPointMover
}
protocol VertexMovable: PointMovable {
    func makeViewVertexMover() -> ViewVertexMover
}
protocol PointEditable: VertexMovable {
    func insert(_ p: Point, _ version: Version)
    func removeNearestPoint(for p: Point, _ version: Version)
}

protocol MovableOrigin: class {
    var movingOrigin: Point { get set }
}
protocol Movable {
    func move(with eventValue: DragEvent.Value, _ phase: Phase, _ version: Version)
}
final class TransformingMovableObject: Movable {
    var viewAndFirstOrigins: [(View & MovableOrigin, Point)]
    var rootView: View
    var fp = Point()
    
    init(viewAndFirstOrigins: [(View & MovableOrigin, Point)], rootView: View) {
        self.viewAndFirstOrigins = viewAndFirstOrigins
        self.rootView = rootView
    }
    
    func move(with eventValue: DragEvent.Value, _ phase: Phase, _ version: Version) {
        guard !viewAndFirstOrigins.isEmpty else { return }
        viewAndFirstOrigins.forEach { (receiver, oldP) in
            let p = rootView.convertFromRoot(eventValue.rootLocation)
            receiver.movingOrigin = (oldP + p - fp).rounded()
        }
        
        if phase == .ended {
            self.viewAndFirstOrigins = []
        }
    }
}

protocol BasicPointMovable: BindableReceiver, PointMovable {
    func model(at p: Point) -> Model
    func didChangeFromMovePoint(_ phase: Phase, beganModel: Model)
}
extension BasicPointMovable {
    func captureWillMovePoint(at p: Point, to version: Version) {
        capture(model, to: version)
    }
}
extension BasicPointMovable where Self: View {
    func makeViewPointMover() -> ViewPointMover {
        return BasicViewPointMover(view: self)
    }
}
final class BasicViewPointMover<T: View & BasicPointMovable>: ViewPointMover {
    var view: T
    var pointMovableView: View & PointMovable {
        return view
    }
    
    init(view: T) {
        self.view = view
        beganModel = view.model
    }
    
    private var beganModel: T.Model
    
    func movePoint(for p: Point, first fp: Point, pressure: Real, time: Real, _ phase: Phase) {
        view.binder[keyPath: view.keyPath] = view.model(at: p)
        view.updateWithModel()
        view.didChangeFromMovePoint(phase, beganModel: beganModel)
    }
}
