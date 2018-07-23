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

protocol UserObjectProtocol: ChangeableDraft, Exportable, CollectionAssignable, Movable {}
protocol RootModeler: Modeler, Undoable, Zoomable, ChangeableDraft, Exportable, CollectionAssignable,
CopiableViewer, MakableStrokable, MakableChangeableColor {
    func userObject(at p: Point) -> UserObjectProtocol
}

final class Sender {
    typealias RootView = View & RootModeler
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
        }
    }
    
    typealias CopiedObjectViewer = View & CopiableViewer
    typealias AssignableReceiver = View & Assignable
    typealias CollectionReceiver = View & CollectionAssignable
    typealias CopiableReceiver = View & Copiable
    typealias ExportableReceiver = View & Exportable
    typealias PointMovableReceiver = View & PointMovable
    typealias MovableReceiver = View & Movable
    
    private var zoomableObject: ZoomableObject?
    private var rotatableObject: RotatableObject?
    private var strokableUserObject: Strokable?
    private var movableObject: Movable?
    private var changeableColorObject: ChangeableColor?
    
    private var fp = Point()
    private var layoutableViews = [(oldP: Point, reciever: MovableReceiver)]()
    private var viewPointMover: ViewPointMover?
    
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
        case actionList.rotateAction:
            guard let eventValue = actionMap.eventValues(with: RotateEvent.self).first else { return }
            if actionMap.phase == .began {
                rotatableObject = RotatableObject(zoomableView: rootView)
            }
            rotatableObject?.rotate(with: eventValue, actionMap.phase, rootView.version)
            if actionMap.phase == .ended {
                rotatableObject = nil
            }
        case actionList.resetViewAction:
            rootView.captureTransform(to: rootView.version)
            rootView.zoomingTransform = rootView.defaultTransform
        case actionList.strokeAction, actionList.lassoFillAction, actionList.lassoEraseAction:
            guard let eventValue = actionMap.eventValues(with: DragEvent.self).first else { return }
            if actionMap.phase == .began {
                strokableUserObject = rootView.strokable(withRootView: rootView)
            }
            let type: StrokableType = actionMap.action == actionList.lassoFillAction ?
                .surface : (actionMap.action == actionList.strokeAction ? .normal : .other)
            strokableUserObject?.stroke(with: eventValue, actionMap.phase,
                                        strokableType: type, rootView.version)
            if actionMap.phase == .ended {
                strokableUserObject = nil
            }
        case actionList.changeHueAction, actionList.changeSLAction:
            guard let eventValue = actionMap.eventValues(with: DragEvent.self).first else { return }
            if actionMap.phase == .began {
                changeableColorObject = rootView.changeableColor(with: eventValue,
                                                                 rootView: rootView)
            }
            if actionMap.action == actionList.changeHueAction {
                changeableColorObject?.changeHue(with: eventValue, actionMap.phase, rootView.version)
            } else {
                changeableColorObject?.changeSL(with: eventValue, actionMap.phase, rootView.version)
            }
            if actionMap.phase == .ended {
                changeableColorObject = nil
            }
        case actionList.moveAction:
            guard let eventValue = actionMap.eventValues(with: DragEvent.self).first else { return }
            if actionMap.phase == .began {
                movableObject = rootView.userObject(at: eventValue.rootLocation)
            }
            movableObject?.move(with: eventValue, actionMap.phase, rootView.version)
            if actionMap.phase == .ended {
                movableObject = nil
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
            let userObject = rootView.userObject(at: eventValue.rootLocation)
            let copiedObject = userObject.copiedObject
            stopEditableEvents()
            userObject.remove(with: eventValue, actionMap.phase, rootView.version)
            rootView.push(copiedObject, to: rootView.version)
        case actionList.copyAction:
            guard actionMap.phase == .began else { break }
            guard let eventValue = actionMap.eventValues(with: InputEvent.self).first else { break }
            let userObject = rootView.userObject(at: eventValue.rootLocation)
            let copiedObject = userObject.copiedObject
            stopEditableEvents()
            rootView.push(copiedObject, to: rootView.version)
        case actionList.pasteAction:
            guard actionMap.phase == .began else { break }
            guard let eventValue = actionMap.eventValues(with: InputEvent.self).first else { break }
            let userObject = rootView.userObject(at: eventValue.rootLocation)
            stopEditableEvents()
            userObject.paste(rootView.copiedObject,
                             with: eventValue, actionMap.phase, rootView.version)
        case actionList.changeToDraftAction:
            guard actionMap.phase == .began else { break }
            guard let eventValue = actionMap.eventValues(with: InputEvent.self).first else { break }
            let userObject = rootView.userObject(at: eventValue.rootLocation)
            stopEditableEvents()
            userObject.changeToDraft(with: eventValue, actionMap.phase, rootView.version)
        case actionList.cutDraftAction:
            guard actionMap.phase == .began else { break }
            guard let eventValue = actionMap.eventValues(with: InputEvent.self).first else { break }
            let userObject = rootView.userObject(at: eventValue.rootLocation)
            let copiedObject = Object(userObject.draftValue)
            stopEditableEvents()
            userObject.removeDraft(with: eventValue, actionMap.phase, rootView.version)
            rootView.push(copiedObject, to: rootView.version)
        case actionList.exportAction:
            guard actionMap.phase == .began else { break }
            guard let eventValue = actionMap.eventValues(with: InputEvent.self).first else { break }
            let userObject = rootView.userObject(at: eventValue.rootLocation)
            stopEditableEvents()
            userObject.export(with: eventValue, actionMap.phase, rootView.version)
        default: break
        }
    }
}

protocol MakableKeyInputtable {
    func keyInputable(withRootView rootView: View, at p: Point) -> KeyInputtable
}

protocol Zoomable: class {
    func captureTransform(to version: Version)
    var zoomingView: View { get }
    var defaultTransform: Transform { get }
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
    var minZ = -15.0.cg, maxZ = 15.0.cg, zInterval = 0.0.cg
    var correction = 3.0.cg
    private var beganZ = 0.0.cg, z = 0.0.cg
    
    func zoom(with eventValue: PinchEvent.Value, _ phase: Phase, _ version: Version) {
        switch phase {
        case .began:
            zoomableView.captureTransform(to: version)
            beganZ = zoomableView.zoomingTransform.z
            z = 0
        case .changed:
            let p = zoomableView.zoomingView.convertFromRoot(eventValue.rootLocation)
            zoom(at: p) {
                z += eventValue.magnification * correction
                let newZ = (beganZ + z).interval(scale: zInterval).clip(min: minZ, max: maxZ)
                zoomableView.zoomingTransform.z = newZ
            }
        case .ended:
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
final class RotatableObject {
    typealias ZoomableView = View & Zoomable
    var zoomableView: ZoomableView
    
    init(zoomableView: ZoomableView) {
        self.zoomableView = zoomableView
    }
    
    var isEndSnap = true
    var rotationInterval = 0.0.cg
    var correction = 0.08.cg * 180 / .pi
    private var beganRotation = 0.0.cg, rotation = 0.0.cg
    
    func rotate(with eventValue: RotateEvent.Value, _ phase: Phase, _ version: Version) {
        switch phase {
        case .began:
            zoomableView.captureTransform(to: version)
            beganRotation = zoomableView.zoomingTransform.degreesRotation
            rotation = 0.0
        case .changed:
            let p = zoomableView.zoomingView.convertFromRoot(eventValue.rootLocation)
            rotate(at: p) {
                rotation += eventValue.rotationQuantity * correction
                let newRotation = (rotation + beganRotation).interval(scale: rotationInterval)
                    .clippedDegreesRotation
                zoomableView.zoomingTransform.degreesRotation = newRotation
            }
        case .ended:
            if isEndSnap {
                zoomableView.zoomingTransform.translation
                    = zoomableView.zoomingTransform.translation.rounded()
            }
        }
    }
    private func rotate(at p: Point, closure: () -> ()) {
        let point = zoomableView.convertZoomingLocalFromZoomingView(p)
        closure()
        let newPoint = zoomableView.convertZoomingLocalToZoomingView(point)
        zoomableView.zoomingTransform.translation -= (newPoint - p)
    }
}

protocol Strokable: class {
    func stroke(with eventValue: DragEvent.Value,
                _ phase: Phase, strokableType: StrokableType, _ version: Version)
    func lassoErase(with eventValue: DragEvent.Value,
                    _ phase: Phase, _ version: Version)
}

protocol MakableChangeableColor {
    func changeableColor(with eventValue: DragEvent.Value,
                         rootView: View) -> ChangeableColor?
}
protocol ChangeableColorOwner: class {
    func captureUUColor(to version: Version)
    var uuColor: UU<Color> { get set }
}
protocol ChangeableColor {
    func changeHue(with eventValue: DragEvent.Value, _ phase: Phase, _ version: Version)
    func changeSL(with eventValue: DragEvent.Value, _ phase: Phase, _ version: Version)
}
final class ChangeableColorObject: ChangeableColor {
    typealias ColorOwnerView = View & ChangeableColorOwner
    
    var views: [ColorOwnerView]
    var fp = Point(), firstUUColor = UU(Color())
    var hueCorrection = 0.002.cg, slCorrection = 0.002.cg
    
    init(views: [ColorOwnerView], firstUUColor: UU<Color>) {
        self.views = views
        self.firstUUColor = firstUUColor
    }
    
    func changeHue(with eventValue: DragEvent.Value, _ phase: Phase, _ version: Version) {
        guard !views.isEmpty else { return }
        if phase == .began {
            views.forEach { $0.captureUUColor(to: version) }
            fp = eventValue.rootLocation
        }
        let hue = ((eventValue.rootLocation.x - fp.x) * hueCorrection
            + firstUUColor.value.hue).loopValue()
        var uuColor = firstUUColor
        uuColor.value.hue = hue
        views.forEach { $0.uuColor = uuColor }
        if phase == .ended {
            views = []
        }
    }
    func changeSL(with eventValue: DragEvent.Value, _ phase: Phase, _ version: Version) {
        guard !views.isEmpty else { return }
        if phase == .began {
            views.forEach { $0.captureUUColor(to: version) }
            fp = eventValue.rootLocation
        }
        let lightness = ((eventValue.rootLocation.x - fp.x) * slCorrection
            + firstUUColor.value.lightness).clip(min: 0, max: 1)
        let saturation = ((eventValue.rootLocation.y - fp.y) * slCorrection
            + firstUUColor.value.saturation).clip(min: 0, max: 1)
        var uuColor = firstUUColor
        uuColor.value.ls = Point(x: lightness, y: saturation)
        views.forEach { $0.uuColor = uuColor }
        if phase == .ended {
            views = []
        }
    }
}

protocol Movable {
    func move(with eventValue: DragEvent.Value, _ phase: Phase, _ version: Version)
}
protocol ViewPointMover: class {
    var pointMovableView: View & PointMovable { get }
    func movePoint(for p: Point, first fp: Point, pressure: Real,
                   time: Real, _ phase: Phase)
}
protocol PointMovable {
    func captureWillMovePoint(at p: Point, to version: Version)
    func makeViewPointMover() -> ViewPointMover
}
protocol MovableOrigin: class {
    var movingOrigin: Point { get set }
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
            viewAndFirstOrigins = []
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

protocol ChangeableDraft {
    func changeToDraft(with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version)
    func removeDraft(with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version)
    var draftValue: Object.Value { get }
}
protocol Exportable {
    func export(with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version)
}
