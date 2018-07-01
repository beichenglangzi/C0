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

protocol Zoomable: class {
    func captureTransform(to version: Version)
    var zoomingView: View { get }
    var zoomingTransform: Transform { get set }
    func convertZoomingLocalFromZoomingView(_ p: Point) -> Point
    func convertZoomingLocalToZoomingView(_ p: Point) -> Point
}

struct ZoomableActionList: SubActionList {
    let zoomAction = Action(name: Text(english: "Zoom", japanese: "ズーム"),
                            quasimode: Quasimode([.pinch(.pinch)]),
                            isEditable: false)
    let rotateAction = Action(name: Text(english: "Rotate", japanese: "回転"),
                              quasimode: Quasimode([.rotate(.rotate)]),
                              isEditable: false)
    var actions: [Action] {
        return [zoomAction, rotateAction]
    }
}
extension ZoomableActionList: SubSendable {
    func makeSubSender() -> SubSender {
        return ZoomableSender(actionList: self)
    }
}

final class ZoomableSender: SubSender {
    typealias ActionList = ZoomableActionList
    
    typealias ZoomableReceiver = View & Zoomable
    
    var actionList: ActionList
    
    init(actionList: ActionList) {
        self.actionList = actionList
    }
    
    var zoomers = [Zoomer](), rotaters = [Rotater]()
    
    func send(_ actionMap: ActionMap, from sender: Sender) {
        switch actionMap.action {
        case actionList.zoomAction:
            guard let eventValue = actionMap.eventValuesWith(PinchEvent.self).first else { return }
            if actionMap.phase == .began {
                let receiver = sender.indicatedZoomableView
                zoomers = [Zoomer(zoomableView: receiver)]
                receiver.captureTransform(to: sender.indicatedVersionView.version)
            }
            guard let zoomer = zoomers.first else { return }
            let p = zoomer.zoomableView.zoomingView.convertFromRoot(eventValue.rootLocation)
            zoomer.zoom(for: p, time: eventValue.time,
                        magnification: eventValue.magnification, actionMap.phase)
            if actionMap.phase == .ended {
                self.zoomers = []
            }
        case actionList.rotateAction:
            guard let eventValue = actionMap.eventValuesWith(RotateEvent.self).first else { return }
            if actionMap.phase == .began {
                let receiver = sender.indicatedZoomableView
                rotaters = [Rotater(zoomableView: receiver)]
                receiver.captureTransform(to: sender.indicatedVersionView.version)
            }
            guard let rotater = rotaters.first else { return }
            let p = rotater.zoomableView.convertFromRoot(eventValue.rootLocation)
            rotater.rotate(for: p, time: eventValue.time,
                           rotationQuantity: eventValue.rotationQuantity, actionMap.phase)
            if actionMap.phase == .ended {
                self.rotaters = []
            }
        default: break
        }
    }
    
    final class Zoomer {
        var zoomableView: View & Zoomable
        
        init(zoomableView: View & Zoomable) {
            self.zoomableView = zoomableView
        }
        
        var isEndSnap = true
        var minZ = -20.0.cg, maxZ = 20.0.cg, zInterval = 0.02.cg
        var correction = 3.0.cg
        
        private var beganZ = 0.0.cg, z = 0.0.cg
        
        func zoom(at p: Point, closure: () -> ()) {
            let point = zoomableView.convertZoomingLocalFromZoomingView(p)
            closure()
            let newPoint = zoomableView.convertZoomingLocalToZoomingView(point)
            zoomableView.zoomingTransform.translation -= (newPoint - p)
        }
        
        func zoom(for p: Point, time: Real, magnification: Real, _ phase: Phase) {
            switch phase {
            case .began:
                beganZ = zoomableView.zoomingTransform.z
                z = 0
            case .changed:
                zoom(at: p) {
                    z += magnification * correction
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
    }
    
    final class Rotater {
        var zoomableView: View & Zoomable
        
        init(zoomableView: View & Zoomable) {
            self.zoomableView = zoomableView
        }
        
        var isEndSnap = true
        var rotationInterval = 2.0.cg
        var correction = (1.0.cg / (3.2 * .pi)) * 180 / .pi
        
        private var beganRotation = 0.0.cg, rotation = 0.0.cg
        
        func rotate(at p: Point, closure: () -> ()) {
            let point = zoomableView.convertZoomingLocalFromZoomingView(p)
            closure()
            let newPoint = zoomableView.convertZoomingLocalToZoomingView(point)
            zoomableView.zoomingTransform.translation -= (newPoint - p)
        }
        
        func rotate(for p: Point, time: Real, rotationQuantity: Real, _ phase: Phase) {
            switch phase {
            case .began:
                beganRotation = zoomableView.zoomingTransform.degreesRotation
                rotation = 0.0
            case .changed:
                rotate(at: p) {
                    rotation += rotationQuantity * correction
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
    }
}
