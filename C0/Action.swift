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
    let rotateAction = Action(name: Localization(english: "Rotate", japanese: "回転"),
                            quasimode: Quasimode([.rotate(.rotate)]),
                            isEditable: false)
    let resetViewAction = Action(name: Localization(english: "Reset View", japanese: "表示を初期化"),
                              quasimode: Quasimode([.input(.doubleTap)]),
                              isEditable: false)
    let strokeAction = Action(name: Localization(english: "Stroke", japanese: "ストローク"),
                              quasimode: Quasimode([.drag(.drag)]))
    let lassoFillAction = Action(name: Localization(english: "Lasso Fill", japanese: "囲み塗る"),
                                 quasimode: Quasimode(modifier: [.input(.command)],
                                                      [.drag(.drag)]))
    let lassoEraseAction = Action(name: Localization(english: "Lasso Erase", japanese: "囲み消す"),
                                  quasimode: Quasimode(modifier: [.input(.option)],
                                                       [.drag(.drag)]))
    let moveAction = Action(name: Localization(english: "Move", japanese: "移動"),
                            quasimode: Quasimode(modifier: [.input(.shift)],
                                                 [.drag(.drag)]))
    let changeHueAction = Action(name: Localization(english: "Change Hue", japanese: "色相を変更"),
                            quasimode: Quasimode(modifier: [.input(.control)],
                                                 [.drag(.drag)]))
    let changeSLAction = Action(name: Localization(english: "Change Saturation and Lightness",
                                                   japanese: "彩度と色相を変更"),
                                 quasimode: Quasimode(modifier: [.input(.control), .input(.shift)],
                                                      [.drag(.drag)]))
    
    let undoAction = Action(name: Localization(english: "Undo", japanese: "取り消す"),
                            quasimode: Quasimode(modifier: [.input(.command)],
                                                 [.input(.z)]))
    let redoAction = Action(name: Localization(english: "Redo", japanese: "やり直す"),
                            quasimode: Quasimode(modifier: [.input(.shift),
                                                            .input(.command)],
                                                 [.input(.z)]))
    
    let cutAction = Action(name: Localization(english: "Cut", japanese: "カット"),
                           quasimode: Quasimode(modifier: [.input(.command)],
                                                [.input(.x)]))
    let copyAction = Action(name: Localization(english: "Copy", japanese: "コピー"),
                            quasimode: Quasimode(modifier: [.input(.command)],
                                                 [.input(.c)]))
    let pasteAction = Action(name: Localization(english: "Paste", japanese: "ペースト"),
                             quasimode: Quasimode(modifier: [.input(.command)],
                                                  [.input(.v)]))
    
    let changeToDraftAction = Action(name: Localization(english: "Change to Draft",
                                                        japanese: "下書き化"),
                                     quasimode: Quasimode(modifier: [.input(.command)],
                                                          [.input(.d)]))
    let cutDraftAction = Action(name: Localization(english: "Cut Draft",
                                                   japanese: "下書きをカット"),
                                quasimode: Quasimode(modifier: [.input(.command), .input(.shift)],
                                                     [.input(.d)]))
    
    let exportAction = Action(name: Localization(english: "Export", japanese: "書き出す"),
                              quasimode: Quasimode(modifier: [.input(.command)],
                                                   [.input(.e)]))
    
    let actions: [Action]
    init() {
        actions = [zoomAction, rotateAction, resetViewAction,
                   strokeAction, lassoFillAction, lassoEraseAction,
                   moveAction, changeHueAction, changeSLAction,
                   undoAction, redoAction,
                   cutAction, copyAction, pasteAction,
                   changeToDraftAction, cutDraftAction, exportAction]
    }
}
extension ActionList {
    var textAndSize: (text: Text, size: Size) {
        var stringLines = [StringLine]()
        var maxNameX = 0.0.cg, y = 0.0.cg
        for action in actions {
            let name = action.name.currentString
            let view = StringFormView(string: name)
            view.frame.origin.y = y
            stringLines.append(StringLine(string: name, origin: Point(x: 0, y: y)))
            maxNameX = max(maxNameX, view.minSize.width)
            y -= view.minSize.height
        }
        y = 0
        let x = maxNameX + Layouter.padding * 2
        var maxQuasimodeX = 0.0.cg
        for action in actions {
            let quasimode = action.quasimode.displayText.currentString
            let view = StringFormView(string: quasimode)
            stringLines.append(StringLine(string: quasimode, origin: Point(x: x, y: y)))
            maxQuasimodeX = max(maxNameX, view.minSize.width)
            y -= view.minSize.height
        }
        
        return (Text(stringLines: stringLines),
                Size(width: x + maxQuasimodeX, height: -(y + Layouter.padding)))
    }
}
