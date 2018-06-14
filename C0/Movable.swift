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
protocol Movable: class, Layoutable {
    var isInteger: Bool { get }
    func captureWillMoveObject(at p: Point, to version: Version)
    var movingOrigin: Point { get set }
}
extension Movable {
    var isInteger: Bool {
        return false
    }
}
protocol Transformable: Movable {
    func anchorPoint(from p: Point) -> Point
    func transform(with affineTransform: AffineTransform)
}

struct MovableActionList: SubActionList {
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
        return [moveEditPointAction, moveVertexAction,
                moveAction, transformAction, warpAction]
    }
}
extension MovableActionList: SubSendable {
    func makeSubSender() -> SubSender {
        return MovableSender(actionList: self)
    }
}

final class MovableSender: SubSender {
    typealias PointEditableReceiver = View & PointEditable
    typealias PointMovableReceiver = View & PointMovable
    typealias VertexMovableReceiver = View & VertexMovable
    typealias MovableReceiver = View & Movable
    typealias TransfomableReceiver = View & Transformable
    
    typealias ActionList = MovableActionList
    var actionList: ActionList
    
    init(actionList: ActionList) {
        self.actionList = actionList
    }
    
    var transformer: Transformer?, warper: Warper?
    
    private var fp = Point(), oldP = Point()
    private var layoutableView: MovableReceiver?
    private var viewPointMover: ViewPointMover?, viewVertexMover: ViewVertexMover?
    private var viewMover: ViewMover?, viewTransformer: ViewTransformer?
    
    func send(_ actionMap: ActionMap, from sender: Sender) {
        switch actionMap.action {
        case actionList.moveEditPointAction:
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
        case actionList.moveVertexAction:
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
        case actionList.moveAction:
            if let eventValue = actionMap.eventValuesWith(DragEvent.self).first {
                if actionMap.phase == .began,
                    let receiver = sender.mainIndicatedView
                        .withSelfAndAllParents(with: MovableReceiver.self) {
                    
                    oldP = receiver.movingOrigin
                    fp = receiver.parent?.convertFromRoot(eventValue.rootLocation) ?? Point()
                    layoutableView = receiver
                    if let views = receiver.parent?.children as? [View & Movable] {
                        sender.beganMovingOrigins = views.map { $0.movingOrigin }
                    }
//                    viewMover = receiver.makeViewMover()
//                    receiver.captureWillMoveObject(at: fp, to: sender.indicatedVersionView.version)
                }
                guard let viewMover = layoutableView else { return }
                let p = viewMover.parent?.convertFromRoot(eventValue.rootLocation) ?? Point()
                viewMover.movingOrigin = (oldP + p - fp).rounded()
//                viewMover.move(for: p, first: fp, pressure: eventValue.pressure,
//                               time: eventValue.time, actionMap.phase)
                
                if let views = viewMover.parent?.children as? [View & Movable] {
                    sender.updateLayout(withMovedViews: [viewMover], from: views)
                }
                
                if actionMap.phase == .ended {
                    self.layoutableView = nil
                    sender.beganMovingOrigins = []
                }
            }
        case actionList.transformAction:
            if let eventValue = actionMap.eventValuesWith(DragEvent.self).first {
                if actionMap.phase == .began,
                    let receiver = sender.mainIndicatedView.withSelfAndAllParents(with: TransfomableReceiver.self) {
                    
                    fp = receiver.convertFromRoot(eventValue.rootLocation)
                    transformer = Transformer(transformableView: receiver)
                    transformer?.anchorPoint = receiver.anchorPoint(from: fp)
                    receiver.captureWillMoveObject(at: fp, to: sender.indicatedVersionView.version)
                    if let views = receiver.parent?.children as? [View & Movable] {
                        sender.beganMovingOrigins = views.map { $0.movingOrigin }
                    }
                }
                guard let viewTransformer = transformer else { return }
                let p = viewTransformer.transformableView.convertFromRoot(eventValue.rootLocation)
                viewTransformer.transform(for: p, pressure: eventValue.pressure,
                                          time: eventValue.time, actionMap.phase)
                
                if let views = viewTransformer.transformableView.parent?.children as? [View & Movable] {
                    sender.updateLayout(withMovedViews: [viewTransformer.transformableView],
                                 from: views)
                }
                if actionMap.phase == .ended {
                    self.viewTransformer = nil
                    sender.beganMovingOrigins = []
                }
            }
        case actionList.transformAction, actionList.warpAction:
            if let eventValue = actionMap.eventValuesWith(DragEvent.self).first {
                if actionMap.phase == .began,
                    let receiver = sender.mainIndicatedView.withSelfAndAllParents(with: TransfomableReceiver.self) {
                    
                    fp = receiver.convertFromRoot(eventValue.rootLocation)
                    warper = Warper(warpableView: receiver)
                    warper?.anchorPoint = receiver.anchorPoint(from: fp)
                    receiver.captureWillMoveObject(at: fp, to: sender.indicatedVersionView.version)
                    if let views = receiver.parent?.children as? [View & Movable] {
                        sender.beganMovingOrigins = views.map { $0.movingOrigin }
                    }
                }
                guard let viewTransformer = warper else { return }
                let p = viewTransformer.warpableView.convertFromRoot(eventValue.rootLocation)
                viewTransformer.warp(for: p, pressure: eventValue.pressure,
                                     time: eventValue.time, actionMap.phase)
                
                if let views = viewTransformer.warpableView.parent?.children as? [View & Movable] {
                    sender.updateLayout(withMovedViews: [viewTransformer.warpableView], from: views)
                }
                if actionMap.phase == .ended {
                    self.viewTransformer = nil
                    sender.beganMovingOrigins = []
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

extension CanvasView: VertexMovable {
    func captureWillMovePoint(at p: Point, to version: Version) {
        
    }
    
    func insert(_ point: Point) {
        let p = convertToCurrentLocal(point), inNode = model.editingCellGroup
        guard let nearest = inNode.nearestLineItem(at: p) else { return }
        
    }
    func removeNearestPoint(for point: Point) {
        let p = convertToCurrentLocal(point), inNode = model.editingCellGroup
        guard let nearest = inNode.nearestLineItem(at: p) else { return }
        if nearest.linePoint.line.controls.count > 2 {
            model.editingCellGroup.drawing.lines[nearest.linePoint.lineIndex]
                .controls.remove(at: nearest.linePoint.pointIndex)
        } else {
            model.editingCellGroup.drawing.lines.remove(at: nearest.linePoint.lineIndex)
        }
    }
    
    func makeViewPointMover() -> ViewPointMover {
        return CanvasViewPointMover(canvasView: self)
    }
    func makeViewVertexMover() -> ViewVertexMover {
        return CanvasViewPointMover(canvasView: self)
    }
}



final class AnimationViewPointMover<Value: KeyframeValue, Binder: BinderProtocol> {
    var animationView: AnimationView<Value, Binder>
    var model: Animation<Value> {
        get { return animationView.model }
        set { animationView.model = newValue }
    }
    
    init(animationView: AnimationView<Value, Binder>) {
        self.animationView = animationView
    }
    
    var editingKeyframeIndex: Int?
    
    var oldRealBaseTime = RealBaseTime(0), oldKeyframeIndex: Int?
    var clipDeltaTime = Rational(0), minDeltaTime = Rational(0), oldTime = Rational(0)
    var oldAnimation = Animation<Value>()
    
    func move(for point: Point, pressure: Real,
              time: Second, _ phase: Phase) {
        let p = point
        switch phase {
        case .began:
            oldRealBaseTime = animationView.realBaseTime(withX: p.x)
            if let ki = animationView.nearestKeyframeIndex(at: p), model.keyframes.count > 1 {
                let keyframeIndex = ki > 0 ? ki : 1
                oldKeyframeIndex = keyframeIndex
                moveKeyframe(withDeltaTime: 0, keyframeIndex: keyframeIndex, phase: phase)
            } else {
                oldKeyframeIndex = nil
                moveDuration(withDeltaTime: 0, phase)
            }
        case .changed, .ended:
            let t = animationView.realBaseTime(withX: point.x)
            let fdt = t - oldRealBaseTime + (t - oldRealBaseTime >= 0 ? 0.5 : -0.5)
            let dt = animationView.basedRationalTime(withRealBaseTime: fdt)
            let deltaTime = max(minDeltaTime, dt + clipDeltaTime)
            if let keyframeIndex = oldKeyframeIndex, keyframeIndex < model.keyframes.count {
                moveKeyframe(withDeltaTime: deltaTime, keyframeIndex: keyframeIndex, phase: phase)
            } else {
                moveDuration(withDeltaTime: deltaTime, phase)
            }
        }
    }
    func move(withDeltaTime deltaTime: Rational, keyframeIndex: Int?, _ phase: Phase) {
        if let keyframeIndex = keyframeIndex, keyframeIndex < model.keyframes.count {
            moveKeyframe(withDeltaTime: deltaTime, keyframeIndex: keyframeIndex, phase: phase)
        } else {
            moveDuration(withDeltaTime: deltaTime, phase)
        }
    }
    func moveKeyframe(withDeltaTime deltaTime: Rational,
                      keyframeIndex: Int, phase: Phase) {
        switch phase {
        case .began:
            editingKeyframeIndex = keyframeIndex
            let preTime = model.keyframes[keyframeIndex - 1].timing.time
            let time = model.keyframes[keyframeIndex].timing.time
            clipDeltaTime = animationView.clipDeltaTime(withTime: time + animationView.beginBaseTime)
            minDeltaTime = preTime - time
            oldAnimation = model
            oldTime = time
        case .changed, .ended:
            var nks = oldAnimation.keyframes
            (keyframeIndex..<nks.count).forEach {
                nks[$0].timing.time += deltaTime
            }
            model.keyframes = nks
            model.duration = oldAnimation.duration + deltaTime
            animationView.updateLayout()
        }
    }
    func moveDuration(withDeltaTime deltaTime: Rational, _ phase: Phase) {
        switch phase {
        case .began:
            editingKeyframeIndex = model.keyframes.count
            let preTime = model.keyframes[model.keyframes.count - 1].timing.time
            let time = model.duration
            clipDeltaTime = animationView.clipDeltaTime(withTime: time + animationView.beginBaseTime)
            minDeltaTime = preTime - time
            oldAnimation = model
            oldTime = time
        case .changed, .ended:
            model.duration = oldAnimation.duration + deltaTime
            animationView.updateLayout()
        }
    }
}

final class Mover {
    typealias MovableView = View & Movable
    
    var movableView: MovableView
    
    init(movableView: MovableView) {
        self.movableView = movableView
    }
    
    var beginPoint = Point()
    
    func move(for point: Point, pressure: Real, time: Second, _ phase: Phase) {
        let p = movableView.convertFromRoot(point)
        switch phase {
        case .began:
            beginPoint = p
        case .changed, .ended:
            let affine = AffineTransform(translation: p - beginPoint)
        }
    }
}
final class Transformer {
    typealias TransformableView = View & Transformable
    
    var transformableView: TransformableView
    
    init(transformableView: TransformableView) {
        self.transformableView = transformableView
    }
    
    var transformBounds = Rect(), beginPoint = Point(), anchorPoint = Point()
    let transformAngleTime = Second(0.1)
    var transformAngleOldTime = Second(0.0)
    var transformAnglePoint = Point(), transformAngleOldPoint = Point()
    var isTransformAngle = false
    var cellGroup: CellGroup?
    func transform(for point: Point, pressure: Real, time: Second, _ phase: Phase) {
        let p = transformableView.convertFromRoot(point)
        switch phase {
        case .began:
            transformAngleOldTime = time
            transformAngleOldPoint = p
            isTransformAngle = false
//            cellGroup = canvasView.model.editingCellGroup
            beginPoint = p
        case .changed, .ended:
//            guard let cellGroup = cellGroup else { return }
            
            func transformAffineTransformWith(point: Point, oldPoint: Point,
                                              anchorPoint: Point) -> AffineTransform {
                guard oldPoint != anchorPoint else {
                    return AffineTransform.identity
                }
                let r = point.distance(anchorPoint), oldR = oldPoint.distance(anchorPoint)
                let angle = anchorPoint.tangential(point)
                let oldAngle = anchorPoint.tangential(oldPoint)
                let scale = r / oldR
                var affine = AffineTransform(translation: anchorPoint)
                affine.rotate(by: angle.differenceRotation(oldAngle))
                affine.scale(by: scale)
                affine.translate(by: -anchorPoint)
                return affine
            }
            let affine = transformAffineTransformWith(point: p, oldPoint: beginPoint,
                                                      anchorPoint: anchorPoint)
            transformableView.transform(with: affine)
        }
    }
}
final class Warper {
    typealias WarpableView = View & Transformable
    
    var warpableView: WarpableView
    
    init(warpableView: WarpableView) {
        self.warpableView = warpableView
    }
    
    var transformBounds = Rect(), beginPoint = Point(), anchorPoint = Point()
    let transformAngleTime = Second(0.1)
    var transformAngleOldTime = Second(0.0)
    var transformAnglePoint = Point(), transformAngleOldPoint = Point()
    var isTransformAngle = false
    var cellGroup: CellGroup?
    func warp(for point: Point, pressure: Real, time: Second, _ phase: Phase) {
        let p = warpableView.convertFromRoot(point)
        switch phase {
        case .began:
            //selectedLines
            self.transformAngleOldTime = time
            self.transformAngleOldPoint = p
            self.isTransformAngle = false
//            cellGroup = canvasView.model.editingCellGroup
            beginPoint = p
        case .changed, .ended:
            func warpAffineTransformWith(point: Point, oldPoint: Point,
                                         anchorPoint: Point) -> AffineTransform {
                guard oldPoint != anchorPoint else {
                    return AffineTransform.identity
                }
                let theta = oldPoint.tangential(anchorPoint)
                let angle = theta < 0 ? theta + .pi : theta - .pi
                var pAffine = AffineTransform(rotationAngle: -angle)
                pAffine.translate(by: -anchorPoint)
                let newOldP = oldPoint * pAffine, newP = point * pAffine
                let scaleX = newP.x / newOldP.x, skewY = (newP.y - newOldP.y) / newOldP.x
                var affine = AffineTransform(translation: anchorPoint)
                affine.rotate(by: angle)
                affine.scale(by: Point(x: scaleX, y: 1))
                if skewY != 0 {
                    let skewAffine = AffineTransform(a: 1, b: skewY,
                                                     c: 0, d: 1,
                                                     tx: 0, ty: 0)
                    affine = skewAffine * affine
                }
                affine.rotate(by: -angle)
                affine.translate(by: -anchorPoint)
                return affine
            }
            
            let affine = warpAffineTransformWith(point: p, oldPoint: beginPoint,
                                                 anchorPoint: anchorPoint)
            warpableView.transform(with: affine)
        }
    }
}


//final class ImageViewMover<Binder: BinderProtocol>: ViewMover {
//    private enum DragType {
//        case move, resizeMinXMinY, resizeMaxXMinY, resizeMinXMaxY, resizeMaxXMaxY
//    }
//    private var dragType = DragType.move, downPosition = Point(), oldFrame = Rect()
//    private var resizeWidth = 10.0.cg, ratio = 1.0.cg
//
//    func move(for point: Point, first fp: Point, pressure: Real,
//              time: Second, _ phase: Phase) {
//        guard let parent = imageView.parent else { return }
//        let p = parent.convert(point, from: imageView), ip = point
//        switch phase {
//        case .began:
//            if Rect(x: 0, y: 0, width: resizeWidth, height: resizeWidth).contains(ip) {
//                dragType = .resizeMinXMinY
//            } else if Rect(x: imageView.bounds.width - resizeWidth, y: 0,
//                           width: resizeWidth, height: resizeWidth).contains(ip) {
//                dragType = .resizeMaxXMinY
//            } else if Rect(x: 0, y: imageView.bounds.height - resizeWidth,
//                           width: resizeWidth, height: resizeWidth).contains(ip) {
//                dragType = .resizeMinXMaxY
//            } else if Rect(x: imageView.bounds.width - resizeWidth,
//                           y: imageView.bounds.height - resizeWidth,
//                           width: resizeWidth, height: resizeWidth).contains(ip) {
//                dragType = .resizeMaxXMaxY
//            } else {
//                dragType = .move
//            }
//            downPosition = p
//            oldFrame = imageView.frame
//            ratio = imageView.frame.height / imageView.frame.width
//        case .changed, .ended:
//            let dp =  p - downPosition
//            var frame = imageView.frame
//            switch dragType {
//            case .move:
//                frame.origin = Point(x: oldFrame.origin.x + dp.x, y: oldFrame.origin.y + dp.y)
//            case .resizeMinXMinY:
//                frame.origin.x = oldFrame.origin.x + dp.x
//                frame.origin.y = oldFrame.origin.y + dp.y
//                frame.size.width = oldFrame.width - dp.x
//                frame.size.height = frame.size.width * ratio
//            case .resizeMaxXMinY:
//                frame.origin.y = oldFrame.origin.y + dp.y
//                frame.size.width = oldFrame.width + dp.x
//                frame.size.height = frame.size.width * ratio
//            case .resizeMinXMaxY:
//                frame.origin.x = oldFrame.origin.x + dp.x
//                frame.size.width = oldFrame.width - dp.x
//                frame.size.height = frame.size.width * ratio
//            case .resizeMaxXMaxY:
//                frame.size.width = oldFrame.width + dp.x
//                frame.size.height = frame.size.width * ratio
//            }
//            imageView.frame = phase == .ended ? frame.integral : frame
//        }
//    }
//}

final class CanvasViewPointMover<Binder: BinderProtocol>: ViewPointMover, ViewVertexMover {
    var canvasView: CanvasView<Binder>
    
    var pointMovableView: View & PointMovable {
        return canvasView
    }
    var vertexMovableView: View & VertexMovable {
        return canvasView
    }
    
    init(canvasView: CanvasView<Binder>) {
        self.canvasView = canvasView
    }
    
    private var nearest: CellGroup.Nearest?
    private var oldPoint = Point(), isSnap = false
    private var cellGroup: CellGroup?
    private let snapDistance = 8.0.cg
    
    func movePoint(for p: Point, first fp: Point, pressure: Real, time: Second, _ phase: Phase) {
        movePoint(for: p, first: fp, pressure: pressure, time: time, phase, isVertex: false)
    }
    func moveVertex(for p: Point, first fp: Point, pressure: Real, time: Second, _ phase: Phase) {
        movePoint(for: p, first: fp, pressure: pressure, time: time, phase, isVertex: true)
    }
    func movePoint(for point: Point, first fp: Point, pressure: Real,
                   time: Second, _ phase: Phase, isVertex: Bool) {
        let p = canvasView.convertToCurrentLocal(point)
        switch phase {
        case .began:
            let cellGroup = canvasView.model.editingCellGroup
            guard let nearest = cellGroup.nearest(at: p, isVertex: isVertex) else { return }
            self.nearest = nearest
            isSnap = false
            self.cellGroup = cellGroup
            oldPoint = p
        case .changed, .ended:
            guard let nearest = nearest else { return }
            let dp = p - oldPoint
            
            isSnap = isSnap ? true : pressure == 1//speed
            
            switch nearest.result {
            case .lineItem(let lineItem):
                movingPoint(with: lineItem, fp: nearest.point, dp: dp)
            case .lineCapResult(let lineCapResult):
                if isSnap {
                    movingPoint(with: lineCapResult,
                                fp: nearest.point, dp: dp, isVertex: isVertex)
                } else {
                    movingLineCap(with: lineCapResult,
                                  fp: nearest.point, dp: dp, isVertex: isVertex)
                }
            }
        }
    }
    private func movingPoint(with lineItem: CellGroup.LineItem, fp: Point, dp: Point) {
        let snapD = snapDistance / canvasView.model.scale
        let e = lineItem.linePoint
        switch lineItem.drawingOrCell {
        case .drawing(let drawing):
            var control = e.line.controls[e.pointIndex]
            control.point = e.line.mainPoint(withMainCenterPoint: fp + dp,
                                             at: e.pointIndex)
            if isSnap && (e.pointIndex == 1 || e.pointIndex == e.line.controls.count - 2) {
                let cellGroup = canvasView.model.editingCellGroup
                control.point = cellGroup.snappedPoint(control.point,
                                                       editLine: drawing.lines[e.lineIndex],
                                                       editingMaxPointIndex: e.pointIndex,
                                                       snapDistance: snapD)
            }
        //            drawing.lines[e.lineIndex].controls[e.pointIndex] = control
        default: break
        }
    }
    private func movingPoint(with lcr: CellGroup.Nearest.Result.LineCapResult,
                             fp: Point, dp: Point, isVertex: Bool) {
        let snapD = snapDistance * canvasView.model.reciprocalScale
        let grid = 5 * canvasView.model.reciprocalScale
        
        let b = lcr.bezierSortedLineCapItem
        let cellGroup = canvasView.model.editingCellGroup
        var np = cellGroup.snappedPoint(fp + dp, with: b,
                                        snapDistance: snapD, grid: grid)
        switch b.drawingOrCell {
        case .drawing(let drawing):
            var newLines = drawing.lines
            if b.lineCap.line.controls.count == 2 {
                let pointIndex = b.lineCap.pointIndex
                var control = b.lineCap.line.controls[pointIndex]
                control.point = cellGroup.snappedPoint(np,
                                                       editLine: drawing.lines[b.lineCap.lineIndex],
                                                       editingMaxPointIndex: pointIndex,
                                                       snapDistance: snapD)
                newLines[b.lineCap.lineIndex].controls[pointIndex] = control
                np = control.point
            } else if isVertex {
                newLines[b.lineCap.lineIndex]
                    = b.lineCap.line.warpedWith(deltaPoint: np - fp,
                                                isFirst: b.lineCap.orientation == .first)
            } else {
                let pointIndex = b.lineCap.pointIndex
                var control = b.lineCap.line.controls[pointIndex]
                control.point = np
                newLines[b.lineCap.lineIndex].controls[b.lineCap.pointIndex] = control
            }
        //            drawing.lines = newLines
        default: break
        }
    }
    func movingLineCap(with lcr: CellGroup.Nearest.Result.LineCapResult,
                       fp: Point, dp: Point, isVertex: Bool) {
        let np = fp + dp
        
        if let dc = lcr.lineCapsItem.drawingCap {
            var newLines = dc.drawing.lines
            if isVertex {
                dc.drawingLineCaps.forEach {
                    newLines[$0.lineIndex] = $0.line.warpedWith(deltaPoint: dp,
                                                                isFirst: $0.orientation == .first)
                }
            } else {
                for cap in dc.drawingLineCaps {
                    var control = cap.orientation == .first ?
                        cap.line.controls[0] : cap.line.controls[cap.line.controls.count - 1]
                    control.point = np
                    switch cap.orientation {
                    case .first:
                        newLines[cap.lineIndex].controls[0] = control
                    case .last:
                        newLines[cap.lineIndex].controls[cap.line.controls.count - 1] = control
                    }
                }
            }
            //            e.drawing.lines = newLines
        }
    }
}
