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

protocol ViewScroller {
    var scrollableView: View & Scrollable { get }
    func scroll(for p: Point, time: Second, scrollDeltaPoint: Point,
                phase: Phase, momentumPhase: Phase?)
}
protocol ViewZoomer {
    var zoomableView: View & Zoomable { get }
    func zoom(for p: Point, time: Second, magnification: Real, _ phase: Phase)
    func rotate(for p: Point, time: Second, rotationQuantity: Real, _ phase: Phase)
}

protocol Scrollable {
    func captureScrollPosition(to version: Version)
    func makeViewScroller() -> ViewScroller
}
protocol Zoomable {
    func convertToCurrentLocal(_ p: Point) -> Point
    func convertFromCurrentLocal(_ p: Point) -> Point
    var transform: Transform { get set }
    
    func resetView(for p: Point, _ version: Version)
    func captureTransform(to version: Version)
    func makeViewZoomer() -> ViewZoomer
}

protocol Bindable {
    func bind(for p: Point, _ verison: Version)
}

struct ZoomableActionManager: SubActionManagable {
    let scrollAction = Action(name: Text(english: "Scroll", japanese: "スクロール"),
                              quasimode: Quasimode([.scroll(.scroll)]),
                              isEditable: false)
    let zoomAction = Action(name: Text(english: "Zoom", japanese: "ズーム"),
                            quasimode: Quasimode([.pinch(.pinch)]),
                            isEditable: false)
    let rotateAction = Action(name: Text(english: "Rotate", japanese: "回転"),
                              quasimode: Quasimode([.rotate(.rotate)]),
                              isEditable: false)
    let resetViewAction = Action(name: Text(english: "Reset View", japanese: "表示を初期化"),
                                 quasimode: Quasimode(modifier: [.input(.command)],
                                                      [.input(.b)]),
                                 isEditable: false)
    let bindAction = Action(name: Text(english: "Bind", japanese: "バインド"),
                            quasimode: Quasimode([.input(.subClick)]),
                            isEditable: false)
    var actions: [Action] {
        return [scrollAction, zoomAction, rotateAction, resetViewAction, bindAction]
    }
}
extension ZoomableActionManager: SubSendable {
    func makeSubSender() -> SubSender {
        return ZoomableSender(actionManager: self)
    }
}

final class ZoomableSender: SubSender {
    typealias ActionManager = ZoomableActionManager
    
    typealias ScrollableReceiver = View & Scrollable
    typealias ZoomableReceiver = View & Zoomable
    typealias BindableReceiver = View & Bindable
    
    var actionManager: ActionManager
    
    init(actionManager: ActionManager) {
        self.actionManager = actionManager
    }
    
    private var viewScroller: ViewScroller?, viewZoomer: ViewZoomer?
    
    func send(_ actionMap: ActionMap, from sender: Sender) {
        switch actionMap.action {
        case actionManager.scrollAction:
            if let eventValue = actionMap.eventValuesWith(ScrollEvent.self).first {
                if actionMap.phase == .began,
                    let receiver = sender.mainIndicatedView as? ScrollableReceiver {
                    
                    viewScroller = receiver.makeViewScroller()
                    receiver.captureScrollPosition(to: sender.indicatedVersionView.version)
                }
                guard let viewScroller = viewScroller else { return }
                let p = viewScroller.scrollableView.convertFromRoot(eventValue.rootLocation)
                viewScroller.scroll(for: p, time: eventValue.time,
                                    scrollDeltaPoint: eventValue.scrollDeltaPoint,
                                    phase: eventValue.phase,
                                    momentumPhase: eventValue.momentumPhase)
                if actionMap.phase == .ended {
                    self.viewScroller = nil
                }
            }
        case actionManager.zoomAction:
            if let eventValue = actionMap.eventValuesWith(PinchEvent.self).first {
                if actionMap.phase == .began,
                    let receiver = sender.mainIndicatedView as? ZoomableReceiver {
                    
                    viewZoomer = receiver.makeViewZoomer()
                    receiver.captureTransform(to: sender.indicatedVersionView.version)
                }
                guard let viewZoomer = viewZoomer else { return }
                let p = viewZoomer.zoomableView.convertFromRoot(eventValue.rootLocation)
                viewZoomer.zoom(for: p, time: eventValue.time,
                                magnification: eventValue.magnification, actionMap.phase)
                if actionMap.phase == .ended {
                    self.viewZoomer = nil
                }
            }
        case actionManager.rotateAction:
            if let eventValue = actionMap.eventValuesWith(RotateEvent.self).first {
                if actionMap.phase == .began,
                    let receiver = sender.mainIndicatedView as? ZoomableReceiver {
                    
                    viewZoomer = receiver.makeViewZoomer()
                    receiver.captureTransform(to: sender.indicatedVersionView.version)
                }
                guard let viewZoomer = viewZoomer else { return }
                let p = viewZoomer.zoomableView.convertFromRoot(eventValue.rootLocation)
                viewZoomer.rotate(for: p, time: eventValue.time,
                                  rotationQuantity: eventValue.rotationQuantity, actionMap.phase)
                if actionMap.phase == .ended {
                    self.viewZoomer = nil
                }
            }
        case actionManager.resetViewAction:
            guard actionMap.phase == .began else { break }
            if let eventValue = actionMap.eventValuesWith(InputEvent.self).first,
                let receiver = sender.mainIndicatedView as? ZoomableReceiver {
                
                let p = receiver.convertFromRoot(eventValue.rootLocation)
                receiver.resetView(for: p, sender.indicatedVersionView.version)
            }
        case actionManager.bindAction:
            guard actionMap.phase == .began else { break }
            if let eventValue = actionMap.eventValuesWith(InputEvent.self).first,
                let receiver = sender.mainIndicatedView as? BindableReceiver {
                
                let p = receiver.convertFromRoot(eventValue.rootLocation)
                receiver.bind(for: p, sender.indicatedVersionView.version)
            }
        default: break
        }
    }
}

final class BasicViewZomer: ViewZoomer {
    var zoomableView: View & Zoomable
    
    init(zoomableView: View & Zoomable) {
        self.zoomableView = zoomableView
    }
    
    func zoom(at p: Point, closure: () -> ()) {
        let point = zoomableView.convertToCurrentLocal(p)
        closure()
        let newPoint = zoomableView.convertFromCurrentLocal(point)
        zoomableView.transform.translation -= (newPoint - p)
    }
    
    var minScale = 0.00001.cg, blockScale = 1.0.cg, maxScale = 64.0.cg
    var correctionScale = 1.28.cg, correctionRotation = 1.0.cg / (4.2 * .pi)
    private var isBlockScale = false, oldScale = 0.0.cg
    func zoom(for p: Point, time: Second, magnification: Real, _ phase: Phase) {
        let scale = zoomableView.transform.scale.x
        switch phase {
        case .began:
            oldScale = scale
            isBlockScale = false
        case .changed:
            guard !isBlockScale else { return }
            zoom(at: p) {
                let newScale = (scale * ((magnification * correctionScale + 1) ** 2))
                    .clip(min: minScale, max: maxScale)
                if blockScale.isOver(old: scale, new: newScale) {
                    isBlockScale = true
                }
                zoomableView.transform.scale = Point(x: newScale, y: newScale)
            }
        case .ended:
            guard isBlockScale else { return }
            zoom(at: p) {
                zoomableView.transform.scale = Point(x: blockScale, y: blockScale)
            }
        }
    }
    
    var blockRotations: [Real] = [-.pi, 0.0, .pi]
    private var isBlockRotation = false, blockRotation = 0.0.cg, oldRotation = 0.0.cg
    func rotate(for p: Point, time: Second, rotationQuantity: Real, _ phase: Phase) {
        let rotation = zoomableView.transform.rotation
        switch phase {
        case .began:
            oldRotation = rotation
            isBlockRotation = false
        case .changed:
            guard !isBlockRotation else { return }
            zoom(at: p) {
                let oldRotation = rotation
                let newRotation = rotation + rotationQuantity * correctionRotation
                for br in blockRotations {
                    if br.isOver(old: oldRotation, new: newRotation) {
                        isBlockRotation = true
                        blockRotation = br
                        break
                    }
                }
                zoomableView.transform.rotation = newRotation.clipRotation
            }
        case .ended:
            guard isBlockRotation else { return }
            zoom(at: p) {
                zoomableView.transform.rotation = blockRotation
            }
        }
    }
}
