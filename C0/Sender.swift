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

protocol SubSender {
    func send(_ actionMap: ActionMap, from sender: Sender)
}
protocol SubSendable {
    func makeSubSender() -> SubSender
}

/**
 Issue: プロトコルアクション設計の対応範囲を拡げる
 */
final class Sender {
    typealias UndoableView = View & Undoable
    typealias ZoomableView = View & Zoomable
    
    var rootView: ModelView & Undoable
    var mainIndicatedView: View {
        didSet {
            guard mainIndicatedView != oldValue else { return }
            
            if let view = mainIndicatedView.withSelfAndAllParents(with: UndoableView.self) {
                self.indicatedVersionView = view
            }
            if let view = mainIndicatedView.withSelfAndAllParents(with: ZoomableView.self) {
                self.indicatedZoomableView = view
            }
            
            oldValue.isIndicated = false
            mainIndicatedView.isIndicated = true
        }
    }
    var oldMainIndicatedViewColor: Color?
    var indicatedVersionView: UndoableView
    var indicatedZoomableView: ZoomableView?
    
    let actionManager = ActionManager()
    let subSenders: [SubSender]
    
    func updateIndicatedView(with frame: Rect) {
        if frame.contains(self.currentRootLocation) {
            mainIndicatedView = rootView.at(currentRootLocation) ?? rootView
            let receiverType = SelectableSender.IndicatableReceiver.self
            if let receiver = mainIndicatedView.withSelfAndAllParents(with: receiverType) {
                let p = receiver.convertFromRoot(currentRootLocation)
                receiver.indicate(at: p)
            }
        }
    }
    var currentRootLocation = Point()
    
    var eventMap = EventMap()
    var actionMaps = [ActionMap]()
    
    init(rootView: ModelView & Undoable) {
        self.rootView = rootView
        subSenders = actionManager.subActionManagers.map { $0.makeSubSender() }
        
        mainIndicatedView = rootView
        oldMainIndicatedViewColor = mainIndicatedView.lineColor
        indicatedVersionView = rootView
        
        rootView.changedFrame = { [unowned self] in self.updateIndicatedView(with: $0) }
    }
    
    var locale = Locale.current {
        didSet {
            if locale.languageCode != oldValue.languageCode {
                rootView.allChildrenAndSelf { ($0 as? TextViewProtocol)?.updateText() }
                rootView.allChildrenAndSelf { $0.updateLayout() }
            }
        }
    }
    
    func sendPointing(_ eventValue: DragEvent.Value) {
        let event = DragEvent(type: .pointing, value: eventValue)
        let action = actionManager.selectableActionManager.indicateAction
        changedOnlySend(event, action)
    }
    func changedOnlySend<T: Event>(_ event: T, _ action: Action) {
        let actionMap = ActionMap(action: action, phase: .changed, events: [event])
        subSenders.forEach { $0.send(actionMap, from: self) }
    }
    
    func send<T: Event>(_ event: T) {
        switch event.value.phase {
        case .began:
            eventMap.append(event)
            if let actionMap = eventMap.actionMapWith(event, actionManager.actions) {
                actionMaps.append(actionMap)
                subSenders.forEach { $0.send(actionMap, from: self) }
            }
        case .changed:
            eventMap.replace(event)
            if let index = actionMapIndex(with: event) {
                actionMaps[index].replace(event)
                let actionMap = actionMaps[index]
                subSenders.forEach { $0.send(actionMap, from: self) }
            }
        case .ended:
            eventMap.replace(event)
            if let index = actionMapIndex(with: event) {
                actionMaps[index].replace(event)
                let actionMap = actionMaps[index]
                subSenders.forEach { $0.send(actionMap, from: self) }
                actionMaps.remove(at: index)
            }
            eventMap.remove(event)
        }
    }
    
    func actionMapIndex<T: Event>(with event: T) -> Array<ActionMap>.Index? {
        return actionMaps.index(where: { $0.contains(event) })
    }
    
    func stopEditableEvents() {
        actionMaps.forEach {
            if $0.action.isEditable {
                var actionMap = $0
                actionMap.phase = .ended
                subSenders.forEach { $0.send(actionMap, from: self) }
            }
        }
        actionMaps = []
    }
    func stopAllEvents() {
        actionMaps.forEach {
            var actionMap = $0
            actionMap.phase = .ended
            subSenders.forEach { $0.send(actionMap, from: self) }
        }
        actionMaps = []
    }
}
