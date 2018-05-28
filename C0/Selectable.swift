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

protocol ViewSelector: class {
    func select(from rect: Rect, _ phase: Phase)
    func deselect(from rect: Rect, _ phase: Phase)
}

protocol Indicatable {
    func indicate(at p: Point)
}
protocol Selectable {
    func captureSelections(to version: Version)
    func makeViewSelector() -> ViewSelector
    func selectAll()
    func deselectAll()
}

struct SelectableActionManager: SubActionManagable {
    let indicateAction = Action(name: Text(english: "Indicate", japanese: "指し示す"),
                                quasimode: Quasimode([DragEvent.EventType.pointing]))
    let selectAction = Action(name: Text(english: "Select", japanese: "選択"),
                              quasimode: Quasimode(modifier: [InputEvent.EventType.command],
                                                   [DragEvent.EventType.drag]))
    let selectAllAction = Action(name: Text(english: "Select All", japanese: "すべて選択"),
                                 quasimode: Quasimode(modifier: [InputEvent.EventType.command],
                                                      [InputEvent.EventType.a]))
    let deselectAction = Action(name: Text(english: "Deselect", japanese: "選択解除"),
                                quasimode: Quasimode(modifier: [InputEvent.EventType.shift,
                                                                InputEvent.EventType.command],
                                                     [DragEvent.EventType.drag]))
    let deselectAllAction = Action(name: Text(english: "Deselect All", japanese: "すべて選択解除"),
                                   quasimode: Quasimode(modifier: [InputEvent.EventType.shift,
                                                                   InputEvent.EventType.command],
                                                        [InputEvent.EventType.a]))
    var actions: [Action] {
        return [indicateAction,
                selectAction, selectAllAction, deselectAction, deselectAllAction]
    }
}
extension SelectableActionManager: SubSendable {
    func makeSubSender() -> SubSender {
        return SelectableSender(actionManager: self)
    }
}

final class SelectableSender: SubSender {
    typealias IndicatableReceiver = View & Indicatable
    typealias SelectableReceiver = View & Selectable
    
    typealias ActionManager = SelectableActionManager
    var actionManager: ActionManager
    
    init(actionManager: ActionManager) {
        self.actionManager = actionManager
    }
    
    private var selector = Selector()
    
    func send(_ actionMap: ActionMap, from sender: Sender) {
        switch actionMap.action {
        case actionManager.indicateAction:
            if let eventValue = actionMap.eventValuesWith(DragEvent.self).first {
                sender.currentRootLocation = eventValue.rootLocation
                sender.mainIndicatedView
                    = sender.rootView.at(eventValue.rootLocation) ?? sender.rootView
                
                if let receiver = sender.mainIndicatedView as? IndicatableReceiver {
                    let p = receiver.convertFromRoot(eventValue.rootLocation)
                    receiver.indicate(at: p)
                }
            }
        case actionManager.selectAction, actionManager.deselectAction:
            if let eventValue = actionMap.eventValuesWith(DragEvent.self).first {
                selector.send(eventValue, actionMap.phase, from: sender,
                              isDeselect: actionMap.action == actionManager.deselectAction)
            }
        case actionManager.selectAllAction, actionManager.deselectAllAction:
            if let receiver = sender.mainIndicatedView as? SelectableReceiver {
                receiver.captureSelections(to: sender.indicatedVersionView.version)
                if actionMap.action == actionManager.deselectAllAction {
                    receiver.deselectAll()
                } else {
                    receiver.selectAll()
                }
            }
        default: break
        }
    }
    
    private final class Selector {
        weak var receiver: SelectableReceiver?, viewSelector: ViewSelector?
        
        private var startPoint = Point(), startRootPoint = Point(), oldIsDeselect = false
        var selectionView: View?
        
        func send(_ event: DragEvent.Value, _ phase: Phase,
                  from sender: Sender, isDeselect: Bool) {
            switch phase {
            case .began:
                let selectionView = isDeselect ? View.deselection : View.selection
                sender.rootView.append(child: selectionView)
                selectionView.frame = Rect(origin: event.rootLocation, size: Size())
                self.selectionView = selectionView
                if let receiver = sender.mainIndicatedView as? SelectableReceiver {
                    startRootPoint = event.rootLocation
                    startPoint = receiver.convertFromRoot(event.rootLocation)
                    self.receiver = receiver
                    
                    receiver.captureSelections(to: sender.indicatedVersionView.version)
                    viewSelector = receiver.makeViewSelector()
                    
                    let rect = Rect(origin: startPoint, size: Size())
                    if isDeselect {
                        viewSelector?.deselect(from: rect, phase)
                    } else {
                        viewSelector?.select(from: rect, phase)
                    }
                    oldIsDeselect = isDeselect
                }
            case .changed, .ended:
                guard let receiver = receiver else { return }
                if isDeselect != oldIsDeselect {
                    selectionView?.fillColor = isDeselect ? .deselect : .select
                    selectionView?.lineColor = isDeselect ? .deselectBorder : .selectBorder
                    oldIsDeselect = isDeselect
                }
                let lp = event.rootLocation
                selectionView?.frame = Rect(origin: startRootPoint,
                                            size: Size(width: lp.x - startRootPoint.x,
                                                       height: lp.y - startRootPoint.y))
                let p = receiver.convertFromRoot(event.rootLocation)
                let aabb = AABB(minX: min(startPoint.x, p.x), maxX: max(startPoint.x, p.x),
                                minY: min(startPoint.y, p.y), maxY: max(startPoint.y, p.y))
                let rect = aabb.rect
                if isDeselect {
                    viewSelector?.deselect(from: rect, phase)
                    
                } else {
                    viewSelector?.select(from: rect, phase)
                }
                
                if phase == .ended {
                    selectionView?.removeFromParent()
                    selectionView = nil
                    self.receiver = nil
                    self.viewSelector = nil
                }
            }
        }
    }
}
