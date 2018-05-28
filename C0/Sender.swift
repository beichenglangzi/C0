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

protocol SubSender {
    func send(_ actionMap: ActionMap, from sender: Sender)
}
protocol SubSendable {
    func makeSubSender() -> SubSender
}

/**
 Issue: コピー・ペーストなどのアクション対応を拡大
 Issue: プロトコルアクション設計を拡大
 */
final class Sender {
    var rootView: View
    var mainIndicatedView: View {
        didSet {
            var allParents = [View]()
            mainIndicatedView.allSubIndicatedParentsAndSelf { allParents.append($0) }
            oldValue.allSubIndicatedParentsAndSelf { view in
                if let index = allParents.index(where: { $0 === view }) {
                    allParents.remove(at: index)
                } else {
                    view.isSubIndicated = false
                }
            }
            allParents.forEach { $0.isSubIndicated = true }
            
            oldValue.isIndicated = false
            mainIndicatedView.isIndicated = true
        }
    }
    var indicatedVersionView: View & Versionable
    var indicatedZoomableView: View
    var actionManager: ActionManager {
        didSet {
            actions = actionManager.actions
            subSenders = actionManager.subActionManagers.map { $0.makeSubSender() }
        }
    }
    var subSenders: [SubSender]
    
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
    
    private var actions: [Action]
    
    init(rootView: View = View(), actionManager: ActionManager = ActionManager()) {
        self.rootView = rootView
        rootView.changedFrame = { [unowned self] in self.updateIndicatedView(with: $0) }
        
        self.actionManager = actionManager
        actions = actionManager.actions
        subSenders = actionManager.subActionManagers.map { $0.makeSubSender() }
    }
    
    func send<T: Event>(_ event: T) {
        switch event.value.phase {
        case .began:
            eventMap.append(event)
            if let actionMap = eventMap.actionMapWith(event, actions) {
                subSenders.forEach { $0.send(actionMap, from: self) }
            }
        case .changed:
            eventMap.replace(event)
            if let actionMap = eventMap.actionMapWith(event, actions) {
                subSenders.forEach { $0.send(actionMap, from: self) }
            }
        case .ended:
            if let actionMap = eventMap.actionMapWith(event, actions) {
                subSenders.forEach { $0.send(actionMap, from: self) }
            }
            eventMap.remove(event)
        }
    }
    
    func stopEditableEvents() {
        
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
