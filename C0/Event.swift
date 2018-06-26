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

enum Phase: Int8, Codable {
    case began, changed, ended
}

protocol EventValueProtocol {
    var rootLocation: Point { get }
    var time: Real { get }
    var phase: Phase { get }
}
protocol EventTypeProtocol {
    var name: Text { get }
}
protocol EventProtocol {
    var protocolType: EventTypeProtocol { get }
    var protocolValue: EventValueProtocol { get }
}
protocol Event: EventProtocol {
    associatedtype EventType: EventTypeProtocol, Equatable
    associatedtype Value: EventValueProtocol
    var type: EventType { get }
    var value: Value { get }
}
extension Event {
    var protocolType: EventTypeProtocol {
        return type
    }
    var protocolValue: EventValueProtocol {
        return value
    }
}

struct InputEvent: Event {
    struct EventType: EventTypeProtocol, Equatable {
        static let click = EventType(name: Text(english: "Click", japanese: "クリック"))
        static let subClick = EventType(name: Text(english: "Sub Click", japanese: "副クリック"))
        static let tap = EventType(name: Text(english: "Tap", japanese: "タップ"))
        static let a = EventType(name: "A"), b = EventType(name: "B"), c = EventType(name: "C")
        static let d = EventType(name: "D"), e = EventType(name: "E"), f = EventType(name: "F")
        static let g = EventType(name: "G"), h = EventType(name: "H"), i = EventType(name: "I")
        static let j = EventType(name: "J"), k = EventType(name: "K"), l = EventType(name: "L")
        static let m = EventType(name: "M"), n = EventType(name: "N"), o = EventType(name: "O")
        static let p = EventType(name: "P"), q = EventType(name: "Q"), r = EventType(name: "R")
        static let s = EventType(name: "S"), t = EventType(name: "T"), u = EventType(name: "U")
        static let v = EventType(name: "V"), w = EventType(name: "W"), x = EventType(name: "X")
        static let y = EventType(name: "Y"), z = EventType(name: "Z")
        static let no0 = EventType(name: "0"), no1 = EventType(name: "1"), no2 = EventType(name: "2")
        static let no3 = EventType(name: "3"), no4 = EventType(name: "4"), no5 = EventType(name: "5")
        static let no6 = EventType(name: "6"), no7 = EventType(name: "7"), no8 = EventType(name: "8")
        static let no9 = EventType(name: "9")
        static let minus = EventType(name: "-"), equals = EventType(name: "=")
        static let leftBracket = EventType(name: "["), rightBracket = EventType(name: "]")
        static let backslash = EventType(name: "/"), frontslash = EventType(name: "\\")
        static let apostrophe = EventType(name: "`"), backApostrophe = EventType(name: "^")
        static let comma = EventType(name: ","), period = EventType(name: ".")
        static let semicolon = EventType(name: ";")
        static let space = EventType(name: "space"), `return` = EventType(name: "return")
        static let tab = EventType(name: "tab"), delete = EventType(name: "delete")
        static let escape = EventType(name: "esc")
        static let command = EventType(name: "command"), shift = EventType(name: "shift")
        static let option = EventType(name: "option"), control = EventType(name: "control")
        static let up = EventType(name: "↑"), down = EventType(name: "↓")
        static let left = EventType(name: "←"), right = EventType(name: "→")
        
        var name: Text
    }
    struct Value: EventValueProtocol {
        let rootLocation: Point, time: Real, pressure: Real, phase: Phase
    }
    
    var type: EventType, value: Value
}

struct DragEvent: Event {
    struct EventType: EventTypeProtocol, Equatable {
        static let pointing = EventType(name: Text(english: "Pointing", japanese: "ポインティング"))
        static let drag = EventType(name: Text(english: "Drag", japanese: "ドラッグ"))
        static let subDrag = EventType(name: Text(english: "Sub Drag", japanese: "副ドラッグ"))
        
        var name: Text
    }
    struct Value: EventValueProtocol {
        var rootLocation: Point, time: Real, pressure: Real, phase: Phase
    }
    
    var type: EventType, value: Value
}

struct ScrollEvent: Event {
    struct EventType: EventTypeProtocol, Equatable {
        static let scroll = EventType(name: Text(english: "Scroll", japanese: "スクロール"))
        static let upperScroll = EventType(name: Text(english: "Upper Scroll",
                                                      japanese: "上部スクロール"))
        
        var name: Text
    }
    struct Value: EventValueProtocol {
        var rootLocation: Point, time: Real, scrollDeltaPoint: Point
        var phase: Phase, momentumPhase: Phase?
    }
    
    var type: EventType, value: Value
}

struct PinchEvent: Event {
    struct EventType: EventTypeProtocol, Equatable {
        static let pinch = EventType(name: Text(english: "Pinch", japanese: "ピンチ"))
        
        var name: Text
    }
    struct Value: EventValueProtocol {
        var rootLocation: Point, time: Real, magnification: Real, phase: Phase
    }
    
    var type: EventType, value: Value
}

struct RotateEvent: Event {
    struct EventType: EventTypeProtocol, Equatable {
        static let rotate = EventType(name: Text(english: "Rotate", japanese: "回転"))
        
        var name: Text
    }
    struct Value: EventValueProtocol {
        var rootLocation: Point, time: Real, rotationQuantity: Real, phase: Phase
    }
    
    var type: EventType, value: Value
}

struct ActionMap {
    var action: Action, phase: Phase, events: [EventProtocol]
    
    func eventValuesWith<T: Event>(_ action: Action, _ type: T.Type) -> [T.Value] {
        if self.action == action {
            return events.compactMap { ($0 as? T)?.value }
        } else {
            return []
        }
    }
    func eventValuesWith<T: Event>(_ type: T.Type) -> [T.Value] {
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

enum AlgebraicEventType: EventTypeProtocol {
    case input(InputEvent.EventType)
    case drag(DragEvent.EventType)
    case scroll(ScrollEvent.EventType)
    case pinch(PinchEvent.EventType)
    case rotate(RotateEvent.EventType)
    
    var name: Text {
        switch self {
        case .input(let inputType): return inputType.name
        case .drag(let dragType): return dragType.name
        case .scroll(let scrollType): return scrollType.name
        case .pinch(let pinchType): return pinchType.name
        case .rotate(let rotateType): return rotateType.name
        }
    }
    
    func contains(_ eventType: EventTypeProtocol) -> Bool {
        func contains<T: Event>(_ algebraicEventType: T.EventType,
                                _ algebraicType: T.Type) -> Bool {
            if let eventType = eventType as? T.EventType {
                return algebraicEventType == eventType
            } else {
                return false
            }
        }
        switch self {
        case .input(let inputType): return contains(inputType, InputEvent.self)
        case .drag(let dragType): return contains(dragType, DragEvent.self)
        case .scroll(let scrollType): return contains(scrollType, ScrollEvent.self)
        case .pinch(let pinchType): return contains(pinchType, PinchEvent.self)
        case .rotate(let rotateType): return contains(rotateType, RotateEvent.self)
        }
    }
}

struct EventMap {
    var events = [EventProtocol]()

    mutating func append<T: Event>(_ event: T) {
        events.append(event)
    }
    mutating func replace<T: Event>(_ event: T) {
        if let i = indexWith(event.type, T.self) {
            events[i] = event
        }
    }
    mutating func remove<T: Event>(_ event: T) {
        if let i = indexWith(event.type, T.self) {
            events.remove(at: i)
        }
    }
    
    func indexWith<T: Event>(_ eventType: T.EventType, _ type: T.Type) -> Int? {
        for (i, event) in events.enumerated() {
            if let e = event as? T, e.type == eventType {
                return i
            }
        }
        return nil
    }
    func event<T: Event>(with eventType: T.EventType, type: T.Type) -> T.Value? {
        for event in events {
            if let e = event as? T, e.type == eventType {
                return e.value
            }
        }
        return nil
    }
    func events<T: Event>(_ type: T.Type) -> [T] {
        return events.compactMap { $0 as? T }
    }
    
    func actionMapWith<T: Event>(_ event: T, _ actions: [Action]) -> ActionMap? {
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
                if !events.contains(where: containsEventType) {
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
            if let index = events.index(where: containsEventType) {
                actionEvents.append(events[index])
            } else {
                return nil
            }
        }
        return ActionMap(action: action, phase: event.value.phase, events: actionEvents)
    }
}
