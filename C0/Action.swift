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

import Foundation

struct Quasimode {
    var modifierKeys: ModifierKeys, key: Key?, gesture: Gesture
    init(_ modifierKeys: ModifierKeys = [], _ key: Key? = nil, gesture: Gesture = .keyInput) {
        self.modifierKeys = modifierKeys
        self.key = key
        self.gesture = gesture
    }
    struct ModifierKeys: OptionSet {
        var rawValue: Int32
        static let shift = ModifierKeys(rawValue: 1), command = ModifierKeys(rawValue: 2)
        static let control = ModifierKeys(rawValue:4), option = ModifierKeys(rawValue: 8)
        
        var displayString: String {
            func string(_ modifierKeys: ModifierKeys, _ name: String) -> String {
                return intersection(modifierKeys).isEmpty ? "" : name
            }
            return string(.shift, "shift")
                .union(string(.control, "control"))
                .union(string(.option, "option"))
                .union(string(.command, "command"))
        }
    }
    
    enum Key: String {
        case
        a = "A", b = "B", c = "C", d = "D", e = "E", f = "F", g = "G", h = "H", i = "I",
        j = "J", k = "K", l = "L", m = "M", n = "N", o = "O", p = "P", q = "Q", r = "R",
        s = "S", t = "T", u = "U", v = "V", w = "W", x = "X", y = "Y", z = "Z",
        no0 = "0", no1 = "1", no2 = "2", no3 = "3", no4 = "4",
        no5 = "5", no6 = "6", no7 = "7", no8 = "8", no9 = "9",
        minus = "-", equals = "=",
        leftBracket = "[", rightBracket = "]", backslash = "/", frontslash = "\\",
        apostrophe = "`", backApostrophe = "^", comma = ",", period = ".", semicolon = ";",
        space = "space", `return` = "return", tab = "tab", delete = "delete", escape = "esc",
        command = "command", shift = "shift", option = "option", control = "control",
        up = "↑", down = "↓", left = "←", right = "→"
    }
    
    enum Gesture: Int8 {
        case
        moveCursor,
        keyInput, click, subClick, tap, doubleTap,
        drag, subDrag, scroll, pinch, rotate
        
        var displayString: Localization {
            switch self {
            case .moveCursor:
                return Localization(english: "Pointing", japanese: "ポインティング")
            case .keyInput:
                return Localization()
            case .click:
                return Localization(english: "Click", japanese: "クリック")
            case .subClick:
                return Localization(english: "Sub Click", japanese: "副クリック")
            case .tap:
                return Localization(english: "Look Up Click", japanese: "調べるクリック")
            case .doubleTap:
                return Localization(english: "Smart Zoom Click", japanese: "スマートズームクリック")
            case .drag:
                return Localization(english: "Drag", japanese: "ドラッグ")
            case .subDrag:
                return Localization(english: "Sub Drag", japanese: "副ドラッグ")
            case .scroll:
                return Localization(english: "Scroll Drag", japanese: "スクロールドラッグ")
            case .pinch:
                return Localization(english: "Zoom Drag", japanese: "拡大／縮小ドラッグ")
            case .rotate:
                return Localization(english: "Rotate Drag", japanese: "回転ドラッグ")
            }
        }
    }
    
    func canTextKeyInput() -> Bool {
        return key != nil && !modifierKeys.contains(.command)
    }
    func canSend(with event: Event) -> Bool {
        func contains(with modifierKeys: ModifierKeys) -> Bool {
            let flippedModifierKeys =
                modifierKeys.symmetricDifference([.shift, .command, .control, .option])
            return event.modifierKeys.contains(modifierKeys) &&
                event.modifierKeys.intersection(flippedModifierKeys).isEmpty
        }
        if let key = key {
            return event.key == key && contains(with: modifierKeys)
        } else {
            return contains(with: modifierKeys)
        }
    }
    
    var displayString: Localization {
        var displayString = Localization(modifierKeys.displayString)
        if let keyDisplayString = key?.rawValue {
            displayString += Localization(displayString.isEmpty ?
                keyDisplayString : " " + keyDisplayString)
        }
        let gestureDisplayString = gesture.displayString
        if !gestureDisplayString.isEmpty {
            displayString += displayString.isEmpty ?
                gestureDisplayString : Localization(" ") + gestureDisplayString
        }
        return displayString
    }
}

/**
 # Issue
 - トラックパッドの環境設定を無効化または表示反映
 */
struct Action {
    enum SendType {
        case begin, sending, end
    }
    
    var name: Localization, instanceDescription: Localization
    var quasimode: Quasimode
    var viewQuasimode: ViewQuasimode
    var moveCursor: ((_ receiver: Respondable, MoveCursorEvent) -> Bool)?
    var keyInput: ((_ receiver: Respondable, KeyInputEvent) -> Bool)?
    var click: ((_ receiver: Respondable, ClickEvent) -> Bool)?
    var drag: ((_ receiver: Respondable, DragEvent) -> Bool)?
    var scroll: ((_ receiver: Respondable, ScrollEvent) -> Bool)?
    var pinch: ((_ receiver: Respondable, PinchEvent) -> Bool)?
    var rotate: ((_ receiver: Respondable, RotateEvent) -> Bool)?
    var tap: ((_ receiver: Respondable, TapEvent) -> Bool)?
    var doubleTap: ((_ receiver: Respondable, DoubleTapEvent) -> Bool)?
    
    init(name: Localization = Localization(), description: Localization = Localization(),
         quasimode: Quasimode = Quasimode(),
         viewQuasimode: ViewQuasimode = .move,
         moveCursor: ((_ receiver: Respondable, MoveCursorEvent) -> Bool)? = nil,
         keyInput: ((_ receiver: Respondable, KeyInputEvent) -> Bool)? = nil,
         click: ((_ receiver: Respondable, ClickEvent) -> Bool)? = nil,
         drag: ((_ receiver: Respondable, DragEvent) -> Bool)? = nil,
         scroll: ((_ receiver: Respondable, ScrollEvent) -> Bool)? = nil,
         pinch: ((_ receiver: Respondable, PinchEvent) -> Bool)? = nil,
         rotate: ((_ receiver: Respondable, RotateEvent) -> Bool)? = nil,
         tap: ((_ receiver: Respondable, TapEvent) -> Bool)? = nil,
         doubleTap: ((_ receiver: Respondable, DoubleTapEvent) -> Bool)? = nil) {
        
        self.name = name
        self.instanceDescription = description
        self.quasimode = quasimode
        self.viewQuasimode = viewQuasimode
        self.keyInput = keyInput
        self.click = click
        self.drag = drag
        self.scroll = scroll
        self.pinch = pinch
        self.rotate = rotate
        self.tap = tap
        self.doubleTap = doubleTap
    }
}
extension Action: Equatable {
    static func ==(lhs: Action, rhs: Action) -> Bool {
        return lhs.name == rhs.name
    }
}
extension Action: Referenceable {
    static let name = Localization(english: "Action", japanese: "アクション")
}

final class ActionManager {
    var isHiddenActions = false
    var actions: [Action] = {
        let cutHandler: (Respondable, KeyInputEvent) -> (Bool) = {
            if let copiedObjects = $0.copiedObjects(with: $1), $0.delete(with: $1) {
                $0.copyManager?.push(copiedObjects: copiedObjects)
                return true
            } else {
                return false
            }
        }
        let copyHandler: (Respondable, KeyInputEvent) -> (Bool) = {
            if let copiedObjects = $0.copiedObjects(with: $1) {
                $0.copyManager?.push(copiedObjects: copiedObjects)
                return true
            } else {
                return false
            }
        }
        let pasteHandler: (Respondable, KeyInputEvent) -> (Bool) = {
            if let copiedObjects = $0.copyManager?.copiedObjects {
                return $0.paste(copiedObjects, with: $1)
            } else {
                return false
            }
        }
        let osPreferenceDescription = Localization(english: "Depends on system preference.",
                                                   japanese: "OSの環境設定に依存")
        
        return [Action(name: Localization(english: "Indicate", japanese: "指し示す"),
                       quasimode: Quasimode(gesture: .moveCursor),
                       moveCursor: { $0.moveCursor(with: $1) }),
                Action(name: Localization(english: "Select", japanese: "選択"),
                       quasimode: Quasimode([.command], gesture: .drag),
                       viewQuasimode: .select,
                       drag: { $0.select(with: $1) }),
                Action(name: Localization(english: "Deselect", japanese: "選択解除"),
                       quasimode: Quasimode([.command, .shift], gesture: .drag),
                       viewQuasimode: .deselect,
                       drag: { $0.deselect(with: $1) }),
                Action(name: Localization(english: "Select All", japanese: "すべて選択"),
                       quasimode: Quasimode([.command], .a, gesture: .keyInput),
                       keyInput: { $0.selectAll(with: $1) }),
                Action(name: Localization(english: "Deselect All", japanese: "すべて選択解除"),
                       quasimode: Quasimode([.command, .shift], .a, gesture: .keyInput),
                       keyInput: { $0.deselectAll(with: $1) }),
                Action(name: Localization(english: "Bind", japanese: "バインド"),
                       quasimode: Quasimode(gesture: .subClick),
                       click: { $0.bind(with: $1) }),
                Action(name: Localization(english: "Scroll", japanese: "スクロール"),
                       description: osPreferenceDescription,
                       quasimode: Quasimode(gesture: .scroll),
                       scroll: { $0.scroll(with: $1) }),
                Action(name: Localization(english: "Zoom", japanese: "ズーム"),
                       description: osPreferenceDescription,
                       quasimode: Quasimode(gesture: .pinch),
                       pinch: { $0.zoom(with: $1) }),
                Action(name: Localization(english: "Rotate", japanese: "回転"),
                       description: osPreferenceDescription,
                       quasimode: Quasimode(gesture: .rotate),
                       rotate: { $0.rotate(with: $1) }),
                Action(name: Localization(english: "Reset View", japanese: "表示を初期化"),
                       description: osPreferenceDescription,
                       quasimode: Quasimode(gesture: .doubleTap),
                       doubleTap: { $0.resetView(with: $1) }),
                Action(name: Localization(english: "Look Up", japanese: "調べる"),
                       description: osPreferenceDescription,
                       quasimode: Quasimode(gesture: .tap),
                       tap: {
                        let r = $0.lookUp(with: $1)
                        print(r?.instanceDescription)
                        return true
                }),
                Action(name: Localization(english: "Undo", japanese: "取り消す"),
                       quasimode: Quasimode([.command], .z, gesture: .keyInput),
                       keyInput: { (receiver, _) in receiver.undo() }),
                Action(name: Localization(english: "Redo", japanese: "やり直す"),
                       quasimode: Quasimode([.command, .shift], .z, gesture: .keyInput),
                       keyInput: { (receiver, _) in receiver.redo() }),
                Action(name: Localization(english: "Cut", japanese: "カット"),
                       quasimode: Quasimode([.command], .x, gesture: .keyInput),
                       keyInput: cutHandler),
                Action(name: Localization(english: "Copy", japanese: "コピー"),
                       quasimode: Quasimode([.command], .c, gesture: .keyInput),
                       keyInput: copyHandler),
                Action(name: Localization(english: "Paste", japanese: "ペースト"),
                       quasimode: Quasimode([.command], .v, gesture: .keyInput),
                       keyInput: pasteHandler),
                Action(name: Localization(english: "New", japanese: "新規"),
                       quasimode: Quasimode([.command], .d, gesture: .keyInput),
                       keyInput: { $0.new(with: $1) }),
                Action(name: Localization(english: "Run", japanese: "実行"),
                       quasimode: Quasimode(gesture: .click),
                       click: { $0.run(with: $1) }),
                Action(name: Localization(english: "Move", japanese: "移動"),
                       quasimode: Quasimode(gesture: .drag),
                       drag: { $0.move(with: $1) }),
                Action(name: Localization(english: "Transform", japanese: "変形"),
                       quasimode: Quasimode([.option], gesture: .drag),
                       viewQuasimode: .transform,
                       drag: { $0.transform(with: $1) }),
                Action(name: Localization(english: "Warp", japanese: "歪曲"),
                       quasimode: Quasimode([.option, .shift], gesture: .drag),
                       viewQuasimode: .warp,
                       drag: { $0.warp(with: $1) }),
                Action(name: Localization(english: "Move Z", japanese: "Z移動"),
                       quasimode: Quasimode([.option, .control], gesture: .drag),
                       viewQuasimode: .moveZ,
                       drag: { $0.moveZ(with: $1) }),
                Action(name: Localization(english: "Stroke", japanese: "ストローク"),
                       quasimode: Quasimode(gesture: .subDrag),
                       viewQuasimode: .stroke,
                       drag: { $0.stroke(with: $1) }),
                Action(name: Localization(english: "Lasso Erase", japanese: "囲み消し"),
                       quasimode: Quasimode([.shift], gesture: .drag),
                       viewQuasimode: .lassoErase,
                       drag: { $0.lassoErase(with: $1) }),
                Action(name: Localization(english: "Remove Edit Point", japanese: "編集点を削除"),
                       quasimode: Quasimode([.control], .x, gesture: .keyInput),
                       viewQuasimode: .movePoint,
                       keyInput: { $0.removePoint(with: $1) }),
                Action(name: Localization(english: "Insert Edit Point", japanese: "編集点を追加"),
                       quasimode: Quasimode([.control], .d, gesture: .keyInput),
                       viewQuasimode: .movePoint,
                       keyInput: { $0.insertPoint(with: $1) }),
                Action(name: Localization(english: "Move Edit Point", japanese: "編集点を移動"),
                       quasimode: Quasimode([.control], gesture: .drag),
                       viewQuasimode: .movePoint,
                       drag: { $0.movePoint(with: $1) }),
                Action(name: Localization(english: "Move Vertex", japanese: "頂点を移動"),
                       quasimode: Quasimode([.control, .shift], gesture: .drag),
                       viewQuasimode: .moveVertex,
                       drag: { $0.moveVertex(with: $1) })]
    } ()
    
    func actionWith(_ gesture: Quasimode.Gesture, _ event: Event) -> Action? {
        for action in actions {
            if action.quasimode.gesture == gesture && action.quasimode.canSend(with: event) {
                return action
            }
        }
        return nil
    }
}
extension ActionManager: Referenceable {
    static let name = Localization(english: "Action Manager", japanese: "アクション管理")
}

protocol Event {
    var sendType: Action.SendType { get }
    var location: CGPoint { get }
    var time: Double { get }
    var modifierKeys: Quasimode.ModifierKeys { get }
    var key: Quasimode.Key? { get }
    var isPen: Bool { get }
}
extension Event {
    var isPen: Bool {
        return false
    }
}
struct BasicEvent: Event {
    let sendType: Action.SendType, location: CGPoint, time: Second
    let modifierKeys: Quasimode.ModifierKeys, key: Quasimode.Key?
}
typealias MoveCursorEvent = BasicEvent
typealias TapEvent = BasicEvent
typealias DoubleTapEvent = BasicEvent
struct KeyInputEvent: Event {
    var sendType: Action.SendType, location: CGPoint, time: Second
    var modifierKeys: Quasimode.ModifierKeys, key: Quasimode.Key?
    func with(sendType: Action.SendType) -> KeyInputEvent {
        return KeyInputEvent(sendType: sendType, location: location,
                             time: time, modifierKeys: modifierKeys, key: key)
    }
}
struct DragEvent: Event {
    var sendType: Action.SendType, location: CGPoint, time: Second
    var modifierKeys: Quasimode.ModifierKeys, key: Quasimode.Key?, isPen: Bool
    var pressure: CGFloat
}
typealias ClickEvent = DragEvent
typealias SubClickEvent = DragEvent
typealias SubDragEvent = DragEvent
struct ScrollEvent: Event {
    var sendType: Action.SendType, location: CGPoint, time: Second
    var modifierKeys: Quasimode.ModifierKeys, key: Quasimode.Key?
    var scrollDeltaPoint: CGPoint, scrollMomentumType: Action.SendType?
    var beginNormalizedPosition: CGPoint
}
struct PinchEvent: Event {
    var sendType: Action.SendType, location: CGPoint, time: Second
    var modifierKeys: Quasimode.ModifierKeys, key: Quasimode.Key?
    var magnification: CGFloat
}
struct RotateEvent: Event {
    var sendType: Action.SendType, location: CGPoint, time: Second
    var modifierKeys: Quasimode.ModifierKeys, key: Quasimode.Key?
    var rotation: CGFloat
}

final class ActionView: View {
    var action: Action {
        didSet {
            nameLabel.localization = action.name
            quasimodeLabel.localization = action.quasimode.displayString
        }
    }
    
    var nameLabel: Label, quasimodeLabel: Label
    
    init(action: Action, frame: CGRect) {
        self.action = action
        nameLabel = Label(text: action.name)
        quasimodeLabel = Label(text: action.quasimode.displayString,
                               font: .action, frameAlignment: .right)
        
        super.init()
        self.frame = frame
        replace(children: [nameLabel, quasimodeLabel])
    }
    
    func copiedObjects(with event: KeyInputEvent) -> [Any]? {
        return [action]
    }
    
    override var defaultBounds: CGRect {
        let padding = Layout.basicPadding
        let width = nameLabel.bounds.width + padding + quasimodeLabel.bounds.width
        let height = nameLabel.frame.height + padding * 2
        return CGRect(x: 0, y: 0, width: width, height: height)
    }
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    func updateLayout() {
        let padding = Layout.basicPadding
        nameLabel.frame.origin = CGPoint(x: padding,
                                         y: bounds.height - nameLabel.frame.height - padding)
        quasimodeLabel.frame.origin = CGPoint(x: bounds.width - quasimodeLabel.frame.width - padding,
                                              y: nameLabel.frame.origin.y)
    }
    
    func lookUp(with event: TapEvent) -> Reference? {
        return action.reference
    }
}

/**
 # Issue
 - アクションの表示をキーボードに常に表示（ハードウェアの変更が必要）
 */
final class ActionManagerView: View {
    var actionManager = ActionManager() {
        didSet {
            isHiddenActions = actionManager.isHiddenActions
            actionsView.array = actionManager.actions
        }
    }
    var isHiddenActions = false {
        didSet {
            guard isHiddenActions != oldValue else {
                return
            }
            actionManager.isHiddenActions = isHiddenActions
            isHiddenActionsView.bool = isHiddenActions
            updateWithIsHiddenActions()
            isHiddenActionsBinding?(isHiddenActions)
        }
    }
    
    static let defaultWidth = 200 + Layout.basicPadding * 2
    let classNameLabel = Label(text: ActionManager.name, font: .bold)
    let isHiddenActionsLabel = Label(text: Localization(english: "Hidden Actions",
                                                        japanese: "アクションの表示なし"))
    let isHiddenActionsView = BoolView(name: Localization(english: "Hidden Actions",
                                                          japanese: "アクションの表示なし"))
    let actionsView = ArrayView<Action>()
    
    override init() {
        super.init()
        isHiddenActionsView.binding = { [unowned self] in self.isHiddenActions = $0.bool }
        updateWithIsHiddenActions()
    }
    
    override var locale: Locale {
        didSet {
            updateLayout()
        }
    }
    
    override var defaultBounds: CGRect {
        let height = Layout.basicHeight + Layout.basicPadding * 2
            + (isHiddenActions ? 0 : actionsView.bounds.height + Layout.basicPadding)
        return CGRect(x: 0, y: 0, width: ActionManagerView.defaultWidth, height: height)
    }
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    func updateLayout() {
        let padding = Layout.basicPadding, sPadding = Layout.smallPadding
        classNameLabel.frame.origin = CGPoint(x: padding,
                                              y: bounds.height - classNameLabel.frame.height - padding)
        let ihw = bounds.width - classNameLabel.frame.width - padding * 3
        if isHiddenActions {
            isHiddenActionsView.frame = CGRect(x: classNameLabel.frame.width + padding * 2, y: padding,
                                               width: ihw, height: Layout.basicHeight)
        } else {
            let aw = bounds.width - padding * 2
            let asw = aw - sPadding * 2
            let ah = bounds.height - Layout.basicHeight - padding * 3
            isHiddenActionsView.frame = CGRect(x: classNameLabel.frame.width + padding * 2,
                                               y: ah + padding * 2,
                                               width: ihw,
                                               height: Layout.basicHeight)
            actionsView.frame = CGRect(x: padding, y: padding, width: aw, height: ah)
            actionsView.children.forEach { $0.frame.size.width = asw }
        }
    }
    func updateWithIsHiddenActions() {
        let padding = Layout.basicPadding, sPadding = Layout.smallPadding
        if isHiddenActions {
            actionsView.replace(children: [])
            replace(children: [classNameLabel, isHiddenActionsView])
        } else {
            let aw = bounds.width - sPadding * 2 - padding * 2
            let aaf = ActionManagerView.actionViewsAndSizeWith(actionManager: actionManager,
                                                               origin: CGPoint(x: sPadding,
                                                                               y: sPadding),
                                                               actionWidth: aw)
            actionsView.replace(children: aaf.views)
            actionsView.frame.size.height = aaf.size.height + sPadding * 2
            replace(children: [classNameLabel, isHiddenActionsView, actionsView])
        }
    }
    
    static func actionViewsAndSizeWith(actionManager: ActionManager,
                                       origin: CGPoint,
                                       actionWidth: CGFloat) -> (views: [ActionView], size: CGSize) {
        var y = origin.y
        let actionViews: [ActionView] = actionManager.actions.reversed().compactMap {
            guard $0.quasimode.gesture != .none else {
                y += Layout.basicPadding
                return nil
            }
            let actionFrame = CGRect(x: origin.x, y: y, width: actionWidth, height: 0)
            let actionView = ActionView(action: $0, frame: actionFrame)
            actionView.frame.size.height = actionView.defaultBounds.height
            y += actionView.frame.height
            return actionView
        }
        return (actionViews, CGSize(width: actionWidth, height: y - origin.y))
    }
    
    var isHiddenActionsBinding: ((Bool) -> (Void))? = nil
    
    func lookUp(with event: TapEvent) -> Reference? {
        return actionManager.reference
    }
}
