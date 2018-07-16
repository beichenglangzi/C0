/*
 Copyright 2017 S
 
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

struct Action {
    let name: Localization, quasimode: Quasimode, isEditable: Bool
    
    init(name: Localization, quasimode: Quasimode, isEditable: Bool = true) {
        self.name = name
        self.quasimode = quasimode
        self.isEditable = isEditable
    }
}
extension Action: Equatable {
    static func ==(lhs: Action, rhs: Action) -> Bool {
        return lhs.name.base == rhs.name.base
    }
}

struct ActionMap {
    var action: Action, phase: Phase, events: [EventProtocol]
    
    init?<T: Event>(_ event: T, _ eventMap: EventMap, _ actions: [Action]) {
        func containsEventType(with algebraicEventTypes: [AlgebraicEventType]) -> Bool {
            for algebraicEventType in algebraicEventTypes {
                if algebraicEventType.contains(event.type) {
                    return true
                }
            }
            return false
        }
        func containsEvents(with algebraicEventTypes: [AlgebraicEventType]) -> Bool {
            for algebraicEventType in algebraicEventTypes {
                func containsEventType(_ eventProtocol: EventProtocol) -> Bool {
                    return algebraicEventType.contains(eventProtocol.protocolType)
                }
                if !eventMap.events.contains(where: containsEventType) {
                    return false
                }
            }
            return true
        }
        
        var hitActions = [Action]()
        for action in actions {
            guard containsEventType(with: action.quasimode.eventTypes) else { continue }
            if containsEvents(with: action.quasimode.allEventTypes) {
                hitActions.append(action)
            }
        }
        let maxAction = hitActions.max {
            $0.quasimode.allEventTypes.count < $1.quasimode.allEventTypes.count
        }
        guard let action = maxAction else {
            return nil
        }
        
        let actionEventTypes = action.quasimode.eventTypes
        var actionEvents = [EventProtocol]()
        actionEvents.reserveCapacity(actionEventTypes.count)
        for actionEventType in actionEventTypes {
            func containsEventType(_ eventProtocol: EventProtocol) -> Bool {
                return actionEventType.contains(eventProtocol.protocolType)
            }
            if let index = eventMap.events.index(where: containsEventType) {
                actionEvents.append(eventMap.events[index])
            } else {
                return nil
            }
        }
        self.action = action
        phase = event.value.phase
        events = actionEvents
    }
    
    func eventValuesWith<T: Event>(_ action: Action, _ type: T.Type) -> [T.Value] {
        if self.action == action {
            return events.compactMap { ($0 as? T)?.value }
        } else {
            return []
        }
    }
    func eventValues<T: Event>(with type: T.Type) -> [T.Value] {
        return events.compactMap { ($0 as? T)?.value }
    }
    func contains<T: Event>(_ event: T) -> Bool {
        func isEqual(_ lhsProtocol: EventProtocol) -> Bool {
            let rhs = event.type
            if let lhs = lhsProtocol.protocolType as? T.EventType {
                return lhs == rhs
            } else {
                return false
            }
        }
        return events.contains(where: isEqual)
    }
    mutating func replace<T: Event>(_ event: T) {
        func isEqual(_ lhsProtocol: EventProtocol) -> Bool {
            let rhs = event.type
            if let lhs = lhsProtocol.protocolType as? T.EventType {
                return lhs == rhs
            } else {
                return false
            }
        }
        if let index = events.index(where: isEqual) {
            events[index] = event
            phase = event.value.phase
        }
    }
}

struct ActionList {
    let zoomAction = Action(name: Localization(english: "Zoom", japanese: "ズーム"),
                            quasimode: Quasimode([.pinch(.pinch)]),
                            isEditable: false)
    
    //timeLeapAction
    let undoAction = Action(name: Localization(english: "Undo", japanese: "取り消す"),
                            quasimode: Quasimode(modifier: [.input(.command)],
                                                 [.input(.z)]))
    let redoAction = Action(name: Localization(english: "Redo", japanese: "やり直す"),
                            quasimode: Quasimode(modifier: [.input(.shift),
                                                            .input(.command)],
                                                 [.input(.z)]))
    
    //delete
    let cutAction = Action(name: Localization(english: "Cut", japanese: "カット"),
                           quasimode: Quasimode(modifier: [.input(.command)],
                                                [.input(.x)]))
    let copyAction = Action(name: Localization(english: "Copy", japanese: "コピー"),
                            quasimode: Quasimode(modifier: [.input(.command)],
                                                 [.input(.c)]))
    let pasteAction = Action(name: Localization(english: "Paste", japanese: "ペースト"),
                             quasimode: Quasimode(modifier: [.input(.command)],
                                                  [.input(.v)]))
    
    let lockAction = Action(name: Localization(english: "Lock", japanese: "ロック"),
                            quasimode: Quasimode(modifier: [.input(.command)],
                                                 [.input(.l)]))
    let newAction = Action(name: Localization(english: "New", japanese: "新規"),
                           quasimode: Quasimode(modifier: [.input(.command)],
                                                [.input(.d)]))
    let findAction = Action(name: Localization(english: "Find", japanese: "検索"),
                           quasimode: Quasimode(modifier: [.input(.command)],
                                                [.input(.f)]))
    let exportAction = Action(name: Localization(english: "Export", japanese: "書き出す"),
                              quasimode: Quasimode(modifier: [.input(.command)],
                                                   [.input(.e)]))
    
    let strokeAction = Action(name: Localization(english: "Stroke", japanese: "ストローク"),
                              quasimode: Quasimode([.drag(.drag)]))
    let moveAction = Action(name: Localization(english: "Move", japanese: "移動"),
                            quasimode: Quasimode(modifier: [.input(.shift)],
                                                 [.drag(.drag)]))
    //duplicateAction
    
    struct Sub {
        var actions: [Action]
    }
    
    let subs: [Sub], actions: [Action]
    init() {
        subs = [Sub(actions: [zoomAction]),
                Sub(actions: [undoAction, redoAction]),
                Sub(actions: [cutAction, copyAction, pasteAction]),
                Sub(actions: [lockAction, newAction, findAction, exportAction]),
                Sub(actions: [strokeAction, moveAction])]
        actions = subs.flatMap { $0.actions }
    }
}
extension ActionList {
    var layoutsAndSize: (layouts: [Layout<String>], size: Size) {
        var layouts = [Layout<String>]()
        var maxNameX = 0.0.cg, y = 0.0.cg
        for sub in subs {
            for action in sub.actions {
                let name = action.name.currentString
                let view = StringFormView(string: name)
                view.frame.origin.y = y
                layouts.append(Layout(name, transform: Transform(translation: Point(x: 0, y: y),
                                                                 z: 0)))
                maxNameX = max(maxNameX, view.minSize.width)
                y -= view.minSize.height
            }
            y -= Layouter.padding
        }
        y = 0
        let x = maxNameX + Layouter.padding * 2
        var maxQuasimodeX = 0.0.cg
        for sub in subs {
            for action in sub.actions {
                let quasimode = action.quasimode.displayText.currentString
                let view = StringFormView(string: quasimode)
                layouts.append(Layout(quasimode, transform: Transform(translation: Point(x: x, y: y),
                                                                      z: 0)))
                maxQuasimodeX = max(maxNameX, view.minSize.width)
                y -= view.minSize.height
            }
            y -= Layouter.padding
        }
        return (layouts, Size(width: x + maxQuasimodeX, height: -(y + Layouter.padding)))
    }
}
