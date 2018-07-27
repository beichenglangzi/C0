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

protocol RootModeler: Modeler, Zoomable, MakableStrokable, MakableChangeableColor, MakableMovable,
Undoable, MakableCollectionAssignable, MakableChangeableDraft,
MakableUpdatableAutoFill, MakableExportable {}

final class ActionSender {
    typealias RootView = View & RootModeler
    var rootView: RootView
    let actionList = ActionList()
    var eventMap = EventMap()
    var actionMaps = [ActionMap]()
    
    init(rootView: RootView) {
        self.rootView = rootView
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
    func resetEventMap() {
        eventMap.events = []
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
    
    private var zoomableObject: ZoomableObject?
    private var rotatableObject: RotatableObject?
    private var strokableObject: Strokable?
    private var movableObject: Movable?
    private var changeableColorObject: ChangeableColor?
    
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
                strokableObject = rootView.strokable(at: eventValue.rootLocation)
            }
            let type: StrokableType = actionMap.action == actionList.lassoFillAction ?
                .surface : (actionMap.action == actionList.strokeAction ? .normal : .other)
            strokableObject?.stroke(with: eventValue, actionMap.phase,
                                        strokableType: type, rootView.version)
            if actionMap.phase == .ended {
                strokableObject = nil
            }
        case actionList.changeHueAction, actionList.changeSLAction:
            guard let eventValue = actionMap.eventValues(with: DragEvent.self).first else { return }
            if actionMap.phase == .began {
                changeableColorObject = rootView.changeableColor(at: eventValue.rootLocation)
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
                movableObject = rootView.movable(at: eventValue.rootLocation)
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
            let collectionAssignable = rootView.collectionAssignable(at: eventValue.rootLocation)
            let copiedObject = collectionAssignable.copiableObject
            stopEditableEvents()
            collectionAssignable.remove(with: eventValue, actionMap.phase, rootView.version)
            rootView.push(copiedObject: copiedObject, to: rootView.version)
        case actionList.copyAction:
            guard actionMap.phase == .began else { break }
            guard let eventValue = actionMap.eventValues(with: InputEvent.self).first else { break }
            let collectionAssignable = rootView.collectionAssignable(at: eventValue.rootLocation)
            let copiedObject = collectionAssignable.copiableObject
            stopEditableEvents()
            rootView.push(copiedObject: copiedObject, to: rootView.version)
        case actionList.pasteAction:
            guard actionMap.phase == .began else { break }
            guard let eventValue = actionMap.eventValues(with: InputEvent.self).first else { break }
            let collectionAssignable = rootView.collectionAssignable(at: eventValue.rootLocation)
            stopEditableEvents()
            collectionAssignable.paste(rootView.copiedObject,
                                       with: eventValue, actionMap.phase, rootView.version)
        case actionList.changeToDraftAction, actionList.cutDraftAction,
             actionList.exchangeWithDraftAction:
            
            guard actionMap.phase == .began else { break }
            guard let eventValue = actionMap.eventValues(with: InputEvent.self).first else { break }
            let changeableDraft = rootView.changeableDraft(at: eventValue.rootLocation)
            stopEditableEvents()
            switch actionMap.action {
            case actionList.changeToDraftAction:
                changeableDraft.changeToDraft(with: eventValue, actionMap.phase, rootView.version)
            case actionList.cutDraftAction:
                let copiedObject = Object(changeableDraft.draftValue)
                changeableDraft.removeDraft(with: eventValue, actionMap.phase, rootView.version)
                rootView.push(copiedObject: copiedObject, to: rootView.version)
            case actionList.exchangeWithDraftAction:
                changeableDraft.exchangeWithDraft(with: eventValue, actionMap.phase, rootView.version)
            default: break
            }
        case actionList.updateAutoFillAction:
            guard actionMap.phase == .began else { break }
            guard let eventValue = actionMap.eventValues(with: InputEvent.self).first else { break }
            let updatableAutoFill = rootView.updatableAutoFill(at: eventValue.rootLocation)
            updatableAutoFill.updateAutoFill(with: eventValue, actionMap.phase, rootView.version)
        case actionList.exportAction:
            guard actionMap.phase == .began else { break }
            guard let eventValue = actionMap.eventValues(with: InputEvent.self).first else { break }
            let exportable = rootView.exportable(at: eventValue.rootLocation)
            stopAllEvents()
            resetEventMap()
            exportable.export(with: eventValue, actionMap.phase, rootView.version)
        default: break
        }
    }
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
    var correction = 0.06.cg * 180 / .pi
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

protocol MakableStrokable {
    func strokable(at p: Point) -> Strokable
}
protocol Strokable: class {
    func stroke(with eventValue: DragEvent.Value,
                _ phase: Phase, strokableType: StrokableType, _ version: Version)
    func lassoErase(with eventValue: DragEvent.Value,
                    _ phase: Phase, _ version: Version)
}

protocol MakableChangeableColor {
    func changeableColor(at p: Point) -> ChangeableColor?
}
protocol ChangeableColor {
    func changeHue(with eventValue: DragEvent.Value, _ phase: Phase, _ version: Version)
    func changeSL(with eventValue: DragEvent.Value, _ phase: Phase, _ version: Version)
}
protocol ChangeableColorOwner: class {
    func captureUUColor(to version: Version)
    var uuColor: UU<Color> { get set }
}
final class ChangeableColorObject: ChangeableColor {
    typealias ColorOwnerView = View & ChangeableColorOwner
    
    var views: [ColorOwnerView]
    var fp = Point(), firstUUColor = UU(Color())
    var hueCorrection = 0.004.cg, slCorrection = 0.004.cg
    
    init(views: [ColorOwnerView], firstUUColor: UU<Color>) {
        self.views = views
        self.firstUUColor = firstUUColor
    }
    
    func changeHue(with eventValue: DragEvent.Value, _ phase: Phase, _ version: Version) {
        guard !views.isEmpty else { return }
        switch phase {
        case .began:
            views.forEach { $0.captureUUColor(to: version) }
            fp = eventValue.rootLocation
        case .changed:
            let hue = ((eventValue.rootLocation.x - fp.x) * hueCorrection
                + firstUUColor.value.hue).loopValue()
            var uuColor = firstUUColor
            uuColor.value.hue = hue
            uuColor.newID()
            views.forEach { $0.uuColor = uuColor }
        case .ended:
            views = []
        }
    }
    func changeSL(with eventValue: DragEvent.Value, _ phase: Phase, _ version: Version) {
        guard !views.isEmpty else { return }
        switch phase {
        case .began:
            views.forEach { $0.captureUUColor(to: version) }
            fp = eventValue.rootLocation
        case .changed:
            let lightness = ((eventValue.rootLocation.x - fp.x) * slCorrection
                + firstUUColor.value.lightness).clip(min: 0, max: 1)
            let saturation = ((eventValue.rootLocation.y - fp.y) * slCorrection
                + firstUUColor.value.saturation).clip(min: 0, max: 1)
            var uuColor = firstUUColor
            uuColor.value.ls = Point(x: lightness, y: saturation)
            uuColor.newID()
            views.forEach { $0.uuColor = uuColor }
        case .ended:
            views = []
        }
    }
}

protocol MakableMovable {
    func movable(at p: Point) -> Movable
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
        switch phase {
        case .began:
            break
        case .changed:
            viewAndFirstOrigins.forEach { (receiver, oldP) in
                let p = rootView.convertFromRoot(eventValue.rootLocation)
                receiver.movingOrigin = (oldP + p - fp).rounded()
            }
        case .ended:
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

protocol MakableCollectionAssignable {
    func collectionAssignable(at p: Point) -> CollectionAssignable
    func push(copiedObject: Object, to version: Version)
    var copiedObject: Object { get }
}
protocol Copiable {
    var copiableObject: Object { get }
}
protocol Assignable: Copiable {
    func paste(_ object: Object,
               with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version)
}
protocol CollectionAssignable: Assignable {
    func remove(with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version)
}

protocol MakableChangeableDraft {
    func changeableDraft(at p: Point) -> ChangeableDraft
}
protocol ChangeableDraft {
    func changeToDraft(with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version)
    func removeDraft(with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version)
    func exchangeWithDraft(with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version)
    var draftValue: Object.Value { get }
}

protocol MakableUpdatableAutoFill {
    func updatableAutoFill(at p: Point) -> UpdatableAutoFill
}
protocol UpdatableAutoFill {
    func updateAutoFill(with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version)
}

protocol MakableExportable {
    func exportable(at p: Point) -> Exportable
}
protocol Exportable {
    func export(with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version)
}
