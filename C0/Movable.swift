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

protocol ViewPointMover: class {
    var pointMovableView: View & PointMovable { get }
    func movePoint(for p: Point, first fp: Point, pressure: Real,
                   time: Second, _ phase: Phase)
}
protocol ViewVertexMover: class {
    var vertexMovableView: View & VertexMovable { get }
    func moveVertex(for p: Point, first fp: Point, pressure: Real,
                    time: Second, _ phase: Phase)
}
protocol ViewMover: class {
    var movableView: View & Movable { get }
    func move(for p: Point, first fp: Point, pressure: Real,
              time: Second, _ phase: Phase)
}
protocol ViewTransformer: class {
    var transformableView: View & Transformable { get }
    func transform(for p: Point, first fp: Point, pressure: Real,
                   time: Second, _ phase: Phase)
    func warp(for p: Point, first fp: Point, pressure: Real,
              time: Second, _ phase: Phase)
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
protocol Movable {
    func captureWillMoveObject(at p: Point, to version: Version)
    func makeViewMover() -> ViewMover
}
protocol Transformable: Movable {
    func makeViewTransformer() -> ViewTransformer
}

struct MovableActionManager: SubActionManagable {
    let removeEditPointAction = Action(name: Text(english: "Remove Edit Point",
                                                  japanese: "編集点を削除"),
                                       quasimode: Quasimode(modifier: [.input(.control)],
                                                            [.input(.x)]))
    let insertEditPointAction = Action(name: Text(english: "Insert Edit Point",
                                                  japanese: "編集点を追加"),
                                       quasimode: Quasimode(modifier: [.input(.control)],
                                                            [.input(.d)]))
    let moveEditPointAction = Action(name: Text(english: "Move Edit Point", japanese: "編集点を移動"),
                                     quasimode: Quasimode([.drag(.drag)]))
    let moveVertexAction = Action(name: Text(english: "Move Vertex", japanese: "頂点を移動"),
                                  quasimode: Quasimode(modifier: [.input(.control)],
                                                       [.drag(.drag)]))
    let moveAction = Action(name: Text(english: "Move", japanese: "移動"),
                            quasimode: Quasimode(modifier: [.input(.shift),
                                                            .input(.control)],
                                                 [.drag(.drag)]))
    let transformAction = Action(name: Text(english: "Transform", japanese: "変形"),
                                 quasimode: Quasimode(modifier: [.input(.option)],
                                                      [.drag(.drag)]))
    let warpAction = Action(name: Text(english: "Warp", japanese: "歪曲"),
                            quasimode: Quasimode(modifier: [.input(.shift),
                                                            .input(.option)],
                                                 [.drag(.drag)]))
    
    var actions: [Action] {
        return [removeEditPointAction, insertEditPointAction,
                moveEditPointAction, moveVertexAction,
                moveAction, transformAction, warpAction]
    }
}
extension MovableActionManager: SubSendable {
    func makeSubSender() -> SubSender {
        return MovableSender(actionManager: self)
    }
}

final class MovableSender: SubSender {
    typealias PointEditableReceiver = View & PointEditable
    typealias PointMovableReceiver = View & PointMovable
    typealias VertexMovableReceiver = View & VertexMovable
    typealias MovableReceiver = View & Movable
    typealias TransfomableReceiver = View & Transformable
    
    typealias ActionManager = MovableActionManager
    var actionManager: ActionManager
    
    init(actionManager: ActionManager) {
        self.actionManager = actionManager
    }
    
    private var fp = Point()
    private var viewPointMover: ViewPointMover?, viewVertexMover: ViewVertexMover?
    private var viewMover: ViewMover?, viewTransformer: ViewTransformer?
    
    func send(_ actionMap: ActionMap, from sender: Sender) {
        switch actionMap.action {
        case actionManager.removeEditPointAction:
            guard actionMap.phase == .began else { break }
            if let eventValue = actionMap.eventValuesWith(InputEvent.self).first,
                let receiver = sender.mainIndicatedView as? PointEditableReceiver {
                
                sender.stopEditableEvents()
                let p = receiver.convertFromRoot(eventValue.rootLocation)
                receiver.removeNearestPoint(for: p, sender.indicatedVersionView.version)
            }
        case actionManager.insertEditPointAction:
            guard actionMap.phase == .began else { break }
            if let eventValue = actionMap.eventValuesWith(InputEvent.self).first,
                let receiver = sender.mainIndicatedView as? PointEditableReceiver {
                
                sender.stopEditableEvents()
                let p = receiver.convertFromRoot(eventValue.rootLocation)
                receiver.insert(p, sender.indicatedVersionView.version)
            }
        case actionManager.moveEditPointAction:
            if let eventValue = actionMap.eventValuesWith(DragEvent.self).first {
                if actionMap.phase == .began,
                    let receiver = sender.mainIndicatedView as? PointMovableReceiver {
                    
                    fp = receiver.convertFromRoot(eventValue.rootLocation)
                    viewPointMover = receiver.makeViewPointMover()
                    receiver.captureWillMovePoint(at: fp, to: sender.indicatedVersionView.version)
                }
                guard let viewPointMover = viewPointMover else { return }
                let p = viewPointMover.pointMovableView.convertFromRoot(eventValue.rootLocation)
                viewPointMover.movePoint(for: p, first: fp, pressure: eventValue.pressure,
                                         time: eventValue.time, actionMap.phase)
                if actionMap.phase == .ended {
                    self.viewPointMover = nil
                }
            }
        case actionManager.moveVertexAction:
            if let eventValue = actionMap.eventValuesWith(DragEvent.self).first {
                if actionMap.phase == .began,
                    let receiver = sender.mainIndicatedView as? VertexMovableReceiver {
                    
                    fp = receiver.convertFromRoot(eventValue.rootLocation)
                    viewVertexMover = receiver.makeViewVertexMover()
                    receiver.captureWillMovePoint(at: fp, to: sender.indicatedVersionView.version)
                }
                guard let viewVertexMover = viewVertexMover else { return }
                let p = viewVertexMover.vertexMovableView.convertFromRoot(eventValue.rootLocation)
                viewVertexMover.moveVertex(for: p, first: fp, pressure: eventValue.pressure,
                                           time: eventValue.time, actionMap.phase)
                if actionMap.phase == .ended {
                    self.viewVertexMover = nil
                }
            }
        case actionManager.moveAction:
            if let eventValue = actionMap.eventValuesWith(DragEvent.self).first {
                if actionMap.phase == .began,
                    let receiver = sender.mainIndicatedView as? MovableReceiver {
                    
                    fp = receiver.convertFromRoot(eventValue.rootLocation)
                    viewMover = receiver.makeViewMover()
                    receiver.captureWillMoveObject(at: fp, to: sender.indicatedVersionView.version)
                }
                guard let viewMover = viewMover else { return }
                let p = viewMover.movableView.convertFromRoot(eventValue.rootLocation)
                viewMover.move(for: p, first: fp, pressure: eventValue.pressure,
                               time: eventValue.time, actionMap.phase)
                if actionMap.phase == .ended {
                    self.viewMover = nil
                }
            }
        case actionManager.transformAction, actionManager.warpAction:
            if let eventValue = actionMap.eventValuesWith(DragEvent.self).first {
                if actionMap.phase == .began,
                    let receiver = sender.mainIndicatedView as? TransfomableReceiver {
                    
                    fp = receiver.convertFromRoot(eventValue.rootLocation)
                    viewTransformer = receiver.makeViewTransformer()
                    receiver.captureWillMoveObject(at: fp, to: sender.indicatedVersionView.version)
                }
                guard let viewTransformer = viewTransformer else { return }
                let p = viewTransformer.transformableView.convertFromRoot(eventValue.rootLocation)
                if actionMap.action == actionManager.transformAction {
                    viewTransformer.transform(for: p, first: fp, pressure: eventValue.pressure,
                                              time: eventValue.time, actionMap.phase)
                } else {
                    viewTransformer.warp(for: p, first: fp, pressure: eventValue.pressure,
                                         time: eventValue.time, actionMap.phase)
                }
                if actionMap.phase == .ended {
                    self.viewTransformer = nil
                }
            }
        default: break
        }
    }
}

protocol BasicDiscretePointMovable: BindableReceiver, PointMovable {
    var knobView: View { get }
    var knobFillColor: Color { get }
    func model(at p: Point, first fp: Point, old: Model) -> Model
    func didChangeFromMovePoint(_ phase: Phase, beganModel: Model)
}
extension BasicDiscretePointMovable {
    func captureWillMovePoint(at p: Point, to version: Version) {
        capture(model, to: version)
    }
    var knobFillColor: Color {
        return .knob
    }
}
extension BasicDiscretePointMovable where Self: View {
    func makeViewPointMover() -> ViewPointMover {
        return BasicDiscreteViewPointMover(view: self)
    }
}
final class BasicDiscreteViewPointMover<T: View & BasicDiscretePointMovable>: ViewPointMover {
    var view: T
    var pointMovableView: View & PointMovable {
        return view
    }
    
    init(view: T) {
        self.view = view
        beganModel = view.model
    }
    
    private var beganModel: T.Model
    
    func movePoint(for p: Point, first fp: Point, pressure: Real, time: Second, _ phase: Phase) {
        switch phase {
        case .began: view.knobView.fillColor = .editing
        case .changed: break
        case .ended: view.knobView.fillColor = view.knobFillColor
        }
        
        view.binder[keyPath: view.keyPath] = view.model(at: p, first: fp, old: beganModel)
        view.updateWithModel()
        view.didChangeFromMovePoint(phase, beganModel: beganModel)
    }
}

protocol BasicSlidablePointMovable: BindableReceiver, PointMovable {
    var knobView: View { get }
    var knobFillColor: Color { get }
    func model(at p: Point) -> Model
    func didChangeFromMovePoint(_ phase: Phase, beganModel: Model)
}
extension BasicSlidablePointMovable {
    func captureWillMovePoint(at p: Point, to version: Version) {
        capture(model, to: version)
    }
    var knobFillColor: Color {
        return .knob
    }
}
extension BasicSlidablePointMovable where Self: View {
    func makeViewPointMover() -> ViewPointMover {
        return BasicSlidableViewPointMover(view: self)
    }
}
final class BasicSlidableViewPointMover<T: View & BasicSlidablePointMovable>: ViewPointMover {
    var view: T
    var pointMovableView: View & PointMovable {
        return view
    }
    
    init(view: T) {
        self.view = view
        beganModel = view.model
    }
    
    private var beganModel: T.Model
    
    func movePoint(for p: Point, first fp: Point, pressure: Real, time: Second, _ phase: Phase) {
        switch phase {
        case .began: view.knobView.fillColor = .editing
        case .changed: break
        case .ended: view.knobView.fillColor = view.knobFillColor
        }
        
        view.binder[keyPath: view.keyPath] = view.model(at: p)
        view.updateWithModel()
        view.didChangeFromMovePoint(phase, beganModel: beganModel)
    }
}
