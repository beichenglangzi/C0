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
protocol InternalZoomable: Zoomable {}

protocol Scrollable {
    func captureBindIndex(to version: Version)
    var bindIndex: Int { get set }
    var bindIndexRange: Range<Int> { get }
    func updateBindIndexRatio(_ ratio: Real)
}
protocol Bindable {
    func bind(for p: Point, _ verison: Version)
}

struct ZoomableActionList: SubActionList {
    let zoomAction = Action(name: Text(english: "Zoom", japanese: "ズーム"),
                            quasimode: Quasimode([.pinch(.pinch)]),
                            isEditable: false)
    let internalZoomAction = Action(name: Text(english: "Internal Zoom", japanese: "内部ズーム"),
                                    quasimode: Quasimode(modifier: [.input(.shift)],
                                                         [.pinch(.pinch)]),
                                    isEditable: false)
    let rotateAction = Action(name: Text(english: "Rotate", japanese: "回転"),
                              quasimode: Quasimode([.rotate(.rotate)]),
                              isEditable: false)
    let bindIndexAction = Action(name: Text(english: "Bind Index", japanese: "インデックスバインド"),
                                 quasimode: Quasimode([.scroll(.scroll)]),
                                 isEditable: false)
    let bindAction = Action(name: Text(english: "Bind", japanese: "バインド"),
                            quasimode: Quasimode([.input(.subClick)]),
                            isEditable: false)
    var actions: [Action] {
        return [zoomAction, internalZoomAction,
                rotateAction, bindIndexAction, bindAction]
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
    typealias InternalZoomableReceiver = View & InternalZoomable
    typealias ScrollableReceiver = View & Scrollable
    typealias BindableReceiver = View & Bindable
    
    var actionList: ActionList
    
    init(actionList: ActionList) {
        self.actionList = actionList
    }
    
    var zoomers = [Zoomer](), rotater: Rotater?, scroller: Scroller?
    
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
        case actionList.internalZoomAction:
            guard let eventValue = actionMap.eventValuesWith(PinchEvent.self).first else { return }
            guard let zoomingView = sender.mainIndicatedView
                .withSelfAndAllParents(with: InternalZoomableReceiver.self)?
                .zoomingView else { return }
            if actionMap.phase == .began {
                let receivers: [ZoomableReceiver] = sender.indictedViews.compactMap {
                    if let receiver = $0.withSelfAndAllParents(with: InternalZoomableReceiver.self) {
                        return receiver.zoomingView == zoomingView ? receiver : nil
                    } else {
                        return nil
                    }
                }
                
                zoomers = receivers.map { Zoomer(zoomableView: $0) }
                receivers.forEach {
                    $0.captureTransform(to: sender.indicatedVersionView.version)
                }
                if let views = zoomingView.children as? [View & Movable] {
                    sender.beganMovingOrigins = views.map { $0.movingOrigin }

                }
            }
            
            zoomers.forEach {
                let p = $0.zoomableView.zoomingView.convertFromRoot(eventValue.rootLocation)
                $0.zoom(for: p, time: eventValue.time,
                        magnification: eventValue.magnification, actionMap.phase)
            }
            
            if let views = zoomingView.children as? [View & Movable] {
                sender.updateLayout(withMovedViews: zoomers.map { $0.zoomableView }, from: views)
            }
            if actionMap.phase == .ended {
                self.zoomers = []
                sender.beganMovingOrigins = []
            }
        case actionList.rotateAction:
            guard let eventValue = actionMap.eventValuesWith(RotateEvent.self).first else { return }
            if actionMap.phase == .began {
                let receiver = sender.indicatedZoomableView
                rotater = Rotater(zoomableView: receiver)
                receiver.captureTransform(to: sender.indicatedVersionView.version)
            }
            guard let rotater = rotater else { return }
            let p = rotater.zoomableView.convertFromRoot(eventValue.rootLocation)
            rotater.rotate(for: p, time: eventValue.time,
                           rotationQuantity: eventValue.rotationQuantity, actionMap.phase)
            if actionMap.phase == .ended {
                self.rotater = nil
            }
        case actionList.bindIndexAction:
            guard let eventValue = actionMap.eventValuesWith(ScrollEvent.self).first else { return }
            if actionMap.phase == .began,
                let receiver = sender.mainIndicatedView as? ScrollableReceiver {
                
                scroller = Scroller(scrollableView: receiver)
                receiver.captureBindIndex(to: sender.indicatedVersionView.version)
            }
            guard let scroller = scroller else { return }
            let p = scroller.scrollableView.convertFromRoot(eventValue.rootLocation)
            scroller.bindIndex(for: p, time: eventValue.time,
                               scrollDeltaPoint: eventValue.scrollDeltaPoint,
                               eventValue.phase)
            if actionMap.phase == .ended {
                self.scroller = nil
            }
        case actionList.bindAction:
            guard actionMap.phase == .began else { break }
            guard let eventValue = actionMap.eventValuesWith(InputEvent.self).first,
                let receiver = sender.mainIndicatedView as? BindableReceiver else { return }
                
            let p = receiver.convertFromRoot(eventValue.rootLocation)
            receiver.bind(for: p, sender.indicatedVersionView.version)
        default: return
        }
    }
    
    final class Zoomer {
        var zoomableView: View & Zoomable
        
        init(zoomableView: View & Zoomable) {
            self.zoomableView = zoomableView
        }
        
        func zoom(at p: Point, closure: () -> ()) {
            let point = zoomableView.convertZoomingLocalFromZoomingView(p)
            closure()
            let newPoint = zoomableView.convertZoomingLocalToZoomingView(point)
            zoomableView.zoomingTransform.translation -= (newPoint - p)
        }
        
        var isEndSnap = true
        var minZ = -6.0.cg, maxZ = 6.0.cg, zInterval = 0.02.cg
        var correction = 3.0.cg
        
        private var beganZ = 0.0.cg, z = 0.0.cg
        
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
                //clipToScreen
            }
        }
    }
    
    final class Rotater {
        var zoomableView: View & Zoomable
        
        init(zoomableView: View & Zoomable) {
            self.zoomableView = zoomableView
        }
        
        func zoom(at p: Point, closure: () -> ()) {
            let point = zoomableView.convertZoomingLocalFromZoomingView(p)
            closure()
            let newPoint = zoomableView.convertZoomingLocalToZoomingView(point)
            zoomableView.zoomingTransform.translation -= (newPoint - p)
        }
        
        var snapRotations: [Real] = [-.pi, 0.0, .pi]
        var correction = 1.0.cg / (4.2 * .pi)
        private var isBlockRotation = false, blockRotation = 0.0.cg, oldRotation = 0.0.cg
        func rotate(for p: Point, time: Real, rotationQuantity: Real, _ phase: Phase) {
            let rotation = zoomableView.zoomingTransform.rotation
            switch phase {
            case .began:
                oldRotation = rotation
                isBlockRotation = false
            case .changed:
                guard !isBlockRotation else { return }
                zoom(at: p) {
                    let oldRotation = rotation
                    let newRotation = rotation + rotationQuantity * correction
                    for br in snapRotations {
                        if br.isOver(old: oldRotation, new: newRotation) {
                            isBlockRotation = true
                            blockRotation = br
                            break
                        }
                    }
                    zoomableView.zoomingTransform.rotation = newRotation.clipRotation
                }
            case .ended:
                guard isBlockRotation else { return }
                zoom(at: p) {
                    zoomableView.zoomingTransform.rotation = blockRotation
                }
            }
        }
    }
    
    final class Scroller {
        var scrollableView: View & Scrollable
        
        init(scrollableView: View & Scrollable) {
            self.scrollableView = scrollableView
        }
        
        func bindIndex(for p: Point, time: Real,
                       scrollDeltaPoint: Point, _ phase: Phase) {
            
        }
    }
}
