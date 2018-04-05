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

protocol Quasimode {
}

/**
 # Issue
 - トラックパッドの環境設定を無効化または表示反映
 */
struct Action {
    struct ModifierKeys: OptionSet, Quasimode {
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
    
    enum Key: String, Quasimode {
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
    
    enum Gesture: Int8, Quasimode {
        case
        none, keyInput, moveCursor, click, rightClick,
        drag, scroll, pinch, rotate, tap, doubleTap, penDrag
        
        var displayString: Localization {
            switch self {
            case .none, .keyInput:
                return Localization()
            case .moveCursor:
                return Localization(english: "Pointing", japanese: "ポインティング")
            case .drag:
                return Localization(english: "Drag", japanese: "ドラッグ")
            case .penDrag:
                return Localization(english: "Pen Drag", japanese: "ペンドラッグ")
            case .click:
                return Localization(english: "Click", japanese: "クリック")
            case .rightClick:
                return Localization(english: "Secondary Click", japanese: "副ボタンクリック")
            case .scroll:
                return Localization(english: "Scroll Drag", japanese: "スクロールドラッグ")
            case .pinch:
                return Localization(english: "Zoom Drag", japanese: "拡大／縮小ドラッグ")
            case .rotate:
                return Localization(english: "Rotate Drag", japanese: "回転ドラッグ")
            case .tap:
                return Localization(english: "Look Up Click", japanese: "調べるクリック")
            case .doubleTap:
                return Localization(english: "Smart Zoom Click", japanese: "スマートズームクリック")
            }
        }
    }
    
    enum SendType {
        case begin, sending, end
    }
    
    var name: Localization, description: Localization
    var modifierKeys: ModifierKeys, key: Key?, gesture: Gesture
    var viewQuasimode: ViewQuasimode
    var keyInput: ((_ receiver: Respondable, KeyInputEvent) -> Bool)?
    var drag: ((_ receiver: Respondable, DragEvent) -> Bool)?
    
    init(name: Localization = Localization(), description: Localization = Localization(),
         modifierKeys: ModifierKeys = [], key: Key? = nil, gesture: Gesture = .none,
         viewQuasimode: ViewQuasimode = .move,
         keyInput: ((_ receiver: Respondable, KeyInputEvent) -> Bool)? = nil,
         drag: ((_ receiver: Respondable, DragEvent) -> Bool)? = nil) {
        
        self.name = name
        self.description = description
        self.modifierKeys = modifierKeys
        self.key = key
        self.viewQuasimode = viewQuasimode
        if keyInput != nil {
            self.gesture = .keyInput
        } else if drag != nil {
            if gesture != .rightClick && gesture != .penDrag {
                self.gesture = .drag
            } else {
                self.gesture = gesture
            }
        } else {
            self.gesture = gesture
        }
        self.keyInput = keyInput
        self.drag = drag
    }
    
    var quasimodeDisplayString: Localization {
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
    
    func canTextKeyInput() -> Bool {
        return key != nil && !modifierKeys.contains(.command)
    }
    func canSend(with event: Event) -> Bool {
        func contains(with quasimode: Action.ModifierKeys) -> Bool {
            let flipQuasimode = quasimode.symmetricDifference([.shift, .command, .control, .option])
            return event.quasimode.contains(quasimode) &&
                event.quasimode.intersection(flipQuasimode).isEmpty
        }
        if let key = key {
            return event.key == key && contains(with: modifierKeys)
        } else {
            return contains(with: modifierKeys)// && (event.isPen ? gesture == .penDrag : true)
        }
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
                $0.copyManager?.copiedObjects = copiedObjects
                return true
            } else {
                return false
            }
        }
        let copiedObjectsHandler: (Respondable, KeyInputEvent) -> (Bool) = {
            if let copiedObjects = $0.copiedObjects(with: $1) {
                $0.copyManager?.copiedObjects = copiedObjects
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
        return [Action(name: Localization(english: "Undo", japanese: "取り消す"),
                       modifierKeys: [.command], key: .z,
                       keyInput: { (receiver, _) in receiver.undo() }),
                Action(name: Localization(english: "Redo", japanese: "やり直す"),
                       modifierKeys: [.command, .shift], key: .z,
                       keyInput: { (receiver, _) in receiver.redo() }),
                Action(name: Localization(english: "Cut", japanese: "カット"),
                       modifierKeys: [.command], key: .x,
                       keyInput: cutHandler),
                Action(name: Localization(english: "Copy", japanese: "コピー"),
                       modifierKeys: [.command], key: .c,
                       keyInput: copiedObjectsHandler),
                Action(name: Localization(english: "Paste", japanese: "ペースト"),
                       modifierKeys: [.command], key: .v,
                       keyInput: pasteHandler),
                Action(name: Localization(english: "New", japanese: "新規"),
                       modifierKeys: [.command], key: .d,
                       keyInput: { $0.new(with: $1) }),
                Action(name: Localization(english: "Indicate", japanese: "指し示す"),
                       gesture: .moveCursor),
                Action(name: Localization(english: "Select", japanese: "選択"),
                       modifierKeys: [.command],
                       viewQuasimode: .select,
                       drag: { $0.select(with: $1) }),
                Action(name: Localization(english: "Deselect", japanese: "選択解除"),
                       modifierKeys: [.command, .shift],
                       viewQuasimode: .deselect,
                       drag: { $0.deselect(with: $1) }),
                Action(name: Localization(english: "Select All", japanese: "すべて選択"),
                       modifierKeys: [.command], key: .a,
                       keyInput: { $0.selectAll(with: $1) }),
                Action(name: Localization(english: "Deselect All", japanese: "すべて選択解除"),
                       modifierKeys: [.command, .shift], key: .a,
                       keyInput: { $0.deselectAll(with: $1) }),
                Action(name: Localization(english: "Bind", japanese: "バインド"),
                       gesture: .rightClick, drag: { $0.bind(with: $1) }),
                Action(name: Localization(english: "Run", japanese: "実行"),
                       gesture: .click),
                Action(name: Localization(english: "Move", japanese: "移動"),
                       drag: { $0.move(with: $1) }),
                Action(name: Localization(english: "Transform", japanese: "変形"),
                       modifierKeys: [.option],
                       viewQuasimode: .transform,
                       drag: { $0.transform(with: $1) }),
                Action(name: Localization(english: "Warp", japanese: "歪曲"),
                       modifierKeys: [.option, .shift],
                       viewQuasimode: .warp,
                       drag: { $0.warp(with: $1) }),
                Action(name: Localization(english: "Move Z", japanese: "Z移動"),
                       modifierKeys: [.option, .control],
                       viewQuasimode: .moveZ,
                       drag: { $0.moveZ(with: $1) }),
                Action(name: Localization(english: "Stroke", japanese: "ストローク"),
                       drag: { $0.stroke(with: $1) }),
                Action(name: Localization(english: "Lasso Erase", japanese: "囲み消し"),
                       modifierKeys: [.shift],
                       viewQuasimode: .lassoErase,
                       drag: { $0.lassoErase(with: $1) }),
                Action(name: Localization(english: "Remove Edit Point", japanese: "編集点を削除"),
                       modifierKeys: [.control], key: .x,
                       keyInput: { $0.removePoint(with: $1) }),
                Action(name: Localization(english: "Insert Edit Point", japanese: "編集点を追加"),
                       modifierKeys: [.control], key: .d,
                       keyInput: { $0.insertPoint(with: $1) }),
                Action(name: Localization(english: "Move Edit Point", japanese: "編集点を移動"),
                       modifierKeys: [.control],
                       viewQuasimode: .movePoint,
                       drag: { $0.movePoint(with: $1) }),
                Action(name: Localization(english: "Move Vertex", japanese: "頂点を移動"),
                       modifierKeys: [.control, .shift],
                       viewQuasimode: .moveVertex,
                       drag: { $0.moveVertex(with: $1) }),
                Action(name: Localization(english: "Scroll", japanese: "スクロール"),
                       description: Localization(english: "Depends on system preference.",
                                                 japanese: "OSの環境設定に依存"),
                       gesture: .scroll),
                Action(name: Localization(english: "Zoom", japanese: "ズーム"),
                       description: Localization(english: "Depends on system preference.",
                                                 japanese: "OSの環境設定に依存"),
                       gesture: .pinch),
                Action(name: Localization(english: "Rotate", japanese: "回転"),
                       description: Localization(english: "Depends on system preference.",
                                                 japanese: "OSの環境設定に依存"),
                       gesture: .rotate),
                Action(name: Localization(english: "Reset View", japanese: "表示を初期化"),
                       description: Localization(english: "Depends on system preference.",
                                                 japanese: "OSの環境設定に依存"),
                       gesture: .doubleTap),
                Action(name: Localization(english: "Look Up", japanese: "調べる"),
                       description: Localization(english: "Depends on system preference.",
                                                 japanese: "OSの環境設定に依存"),
                       gesture: .tap)]
    } ()
    
    func actionWith(_ gesture: Action.Gesture, _ event: Event) -> Action? {
        for action in actions {
            if action.gesture == gesture && action.canSend(with: event) {
                return action
            }
        }
        return nil
    }
}
extension ActionManager: Referenceable {
    static let name = Localization(english: "Action Manager", japanese: "アクション管理")
}

/**
 # Issue
 - アクションの表示をキーボードに常に表示（ハードウェアの変更が必要）
 */
final class ActionManagerView: Layer, Respondable {
    static let name = ActionManager.name
    
    var actionManager = ActionManager() {
        didSet {
            isHiddenActions = actionManager.isHiddenActions
            actionsView.array = actionManager.actions
        }
    }
    private var isHiddenActions = false {
        didSet {
            guard isHiddenActions != oldValue else {
                return
            }
            isHiddenActionsView.selectedIndex = isHiddenActions ? 0 : 1
            updateLayout()
        }
    }
    
    static let defaultWidth = 200 + Layout.basicPadding * 2
    
    let nameLabel = Label(text: ActionManager.name, font: .bold)
    let isHiddenActionsView = EnumView(names: [Localization(english: "Hidden Actions",
                                                            japanese: "アクションの表示なし"),
                                               Localization(english: "Shown Actions",
                                                            japanese: "アクションの表示あり")])
    let actionsView = ArrayView<Action>()
    
    override init() {
        super.init()
        isHiddenActionsView.selectedIndex = 1
        isHiddenActionsView.binding = { [unowned self] in
            self.isHiddenActions = $0.index == 0
            self.isHiddenActionsBinding?(self.isHiddenActions)
        }
        updateLayout()
    }
    
    override var locale: Locale {
        didSet {
            updateLayout()
        }
    }
    
    func updateLayout() {
        let padding = Layout.basicPadding, sPadding = Layout.smallPadding
        if isHiddenActions {
            let h = Layout.basicHeight + padding * 2
            nameLabel.frame.origin = CGPoint(x: padding, y: h - padding - nameLabel.frame.height)
            let ihw = actionWidth - nameLabel.frame.width - padding * 3
            isHiddenActionsView.frame = CGRect(x: nameLabel.frame.width + padding * 2, y: padding,
                                               width: ihw, height: Layout.basicHeight)
            actionsView.replace(children: [])
            replace(children: [nameLabel, isHiddenActionsView])
            frame.size = CGSize(width: actionWidth, height: h)
        } else {
            let aw = actionWidth - sPadding * 2 - padding * 2
            let aaf = ActionManagerView.actionViewsAndSizeWith(actionManager: actionManager,
                                                               origin: CGPoint(x: sPadding,
                                                                               y: sPadding),
                                                               actionWidth: aw)
            let ah = aaf.size.height + sPadding * 2
            let h = ah + Layout.basicHeight + padding * 3
            nameLabel.frame.origin = CGPoint(x: padding,
                                             y: h - padding - nameLabel.frame.height)
            isHiddenActionsView.frame = CGRect(x: nameLabel.frame.width + padding * 2,
                                        y: ah + padding * 2,
                                        width: actionWidth - nameLabel.frame.width - padding * 3,
                                        height: Layout.basicHeight)
            actionsView.replace(children: aaf.views)
            actionsView.frame = CGRect(x: padding, y: padding,
                                       width: aaf.size.width + sPadding * 2, height: ah)
            replace(children: [nameLabel, isHiddenActionsView, actionsView])
            frame.size = CGSize(width: actionWidth, height: h)
        }
    }
    
    var isHiddenActionsBinding: ((Bool) -> (Void))? = nil
    
    var actionWidth = ActionManagerView.defaultWidth
    
    static func actionViewsAndSizeWith(actionManager: ActionManager,
                                       origin: CGPoint,
                                       actionWidth: CGFloat) -> (views: [ActionView], size: CGSize) {
        var y = origin.y
        let actionViews: [ActionView] = actionManager.actions.reversed().compactMap {
            guard $0.gesture != .none else {
                y += Layout.basicPadding
                return nil
            }
            let actionView = ActionView(action: $0, frame: CGRect(x: origin.x, y: y,
                                                                  width: actionWidth, height: 0))
            y += actionView.frame.height
            return actionView
        }
        return (actionViews, CGSize(width: actionWidth, height: y - origin.y))
    }
}

final class ActionView: Layer, Respondable {
    static let name = Action.name
    var instanceDescription: Localization {
        return action.description
    }
    
    var action: Action
    
    var nameLabel: Label, quasimodeLabel: Label
    
    init(action: Action, frame: CGRect) {
        self.action = action
        let nameLabel = Label(text: action.name)
        let quasimodeLabel = Label(text: action.quasimodeDisplayString, font: .action,
                                 frameAlignment: .right)
        self.nameLabel = nameLabel
        self.quasimodeLabel = quasimodeLabel
        let padding = Layout.basicPadding
        nameLabel.frame.origin = CGPoint(x: padding, y: padding)
        quasimodeLabel.frame.origin = CGPoint(x: frame.width - quasimodeLabel.frame.width - padding,
                                              y: padding)
        super.init()
        self.frame = CGRect(x: frame.minX, y: frame.minY,
                            width: frame.width, height: nameLabel.frame.height + padding * 2)
        replace(children: [nameLabel, quasimodeLabel])
    }
    
    func copiedObjects(with event: KeyInputEvent) -> [Any]? {
        return [action]
    }
}

protocol Event {
    var sendType: Action.SendType { get }
    var location: CGPoint { get }
    var time: Double { get }
    var quasimode: Action.ModifierKeys { get }
    var key: Action.Key? { get }
    var isPen: Bool { get }
}
extension Event {
    var isPen: Bool {
        return false
    }
}
struct BasicEvent: Event {
    let sendType: Action.SendType, location: CGPoint, time: Second
    let quasimode: Action.ModifierKeys, key: Action.Key?
}
typealias MoveEvent = BasicEvent
typealias TapEvent = BasicEvent
typealias DoubleTapEvent = BasicEvent
struct KeyInputEvent: Event {
    var sendType: Action.SendType, location: CGPoint, time: Second
    var quasimode: Action.ModifierKeys, key: Action.Key?
    func with(sendType: Action.SendType) -> KeyInputEvent {
        return KeyInputEvent(sendType: sendType, location: location,
                             time: time, quasimode: quasimode, key: key)
    }
}
struct DragEvent: Event {
    var sendType: Action.SendType, location: CGPoint, time: Second
    var quasimode: Action.ModifierKeys, key: Action.Key?, isPen: Bool
    var pressure: CGFloat
}
typealias ClickEvent = DragEvent
typealias RightClickEvent = DragEvent
struct ScrollEvent: Event {
    var sendType: Action.SendType, location: CGPoint, time: Second
    var quasimode: Action.ModifierKeys, key: Action.Key?
    var scrollDeltaPoint: CGPoint, scrollMomentumType: Action.SendType?
    var beginNormalizedPosition: CGPoint
}
struct PinchEvent: Event {
    var sendType: Action.SendType, location: CGPoint, time: Second
    var quasimode: Action.ModifierKeys, key: Action.Key?
    var magnification: CGFloat
}
struct RotateEvent: Event {
    var sendType: Action.SendType, location: CGPoint, time: Second
    var quasimode: Action.ModifierKeys, key: Action.Key?
    var rotation: CGFloat
}
