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

import struct Foundation.Locale

enum Focus {
    case main, zooming, versioning
}

struct Action {
    let name: Text, description: Text, quasimode: Quasimode
    
    init(name: Text = "", description: Text = "", quasimode: Quasimode) {
        self.name = name
        self.description = description
        self.quasimode = quasimode
    }
    
    func isSubset(of other: Action) -> Bool {
        let types = quasimode.allEventTypeProtocols
        let otherTypes = other.quasimode.allEventTypeProtocols
        for type in types {
            if !otherTypes.contains(where: { $0.name == type.name }) {
                return false
            }
        }
        return true
    }
}
extension Action: Equatable {
    static func ==(lhs: Action, rhs: Action) -> Bool {
        return lhs.name.base == rhs.name.base
    }
}
extension Action: Referenceable {
    static let name = Text(english: "Action", japanese: "アクション")
}
extension Action: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return name.thumbnailView(withFrame: frame, sizeType)
    }
}

protocol SubActionManagable: SubSendable {
    var actions: [Action] { get }
}

struct ActionManager {
    let selectableActionManager = SelectableActionManager()
    let zoomableActionManager = ZoomableActionManager()
    let versionableActionManager = VersionableActionManager()
    let assignableActionManager = AssignableActionManager()
    let runnableActionManager = RunnableActionManager()
    let strokableActionManager = StrokableActionManager()
    let movableActionManager = MovableActionManager()
    
    var actions: [Action] {
        return selectableActionManager.actions
            + zoomableActionManager.actions
            + versionableActionManager.actions
            + assignableActionManager.actions
            + runnableActionManager.actions
            + strokableActionManager.actions
            + movableActionManager.actions
        
//        return subActionManagers.flatMap { $0.actions }
    }
}
extension ActionManager: Referenceable {
    static let name = Text(english: "Action Manager", japanese: "アクション管理")
}

final class ActionView<T: BinderProtocol>: View, BindableGetterReceiver {
    typealias Model = Action
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((ActionView<Binder>, BasicNotification) -> ())]()
    
    var nameView: TextGetterView<Binder>, quasimodeView: QuasimodeView<Binder>
    
    init(binder: Binder, keyPath: BinderKeyPath,
         frame: Rect = Rect()) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        nameView = TextGetterView(binder: binder,
                                  keyPath: keyPath.appending(path: \Model.name))
        quasimodeView = QuasimodeView(binder: binder,
                                      keyPath: keyPath.appending(path: \Model.quasimode))
        
        super.init()
        self.frame = frame
        children = [nameView, quasimodeView]
    }
    
    override var defaultBounds: Rect {
        let padding = Layout.basicPadding
        let width = nameView.bounds.width + padding + quasimodeView.bounds.width
        let height = nameView.frame.height + Layout.smallPadding * 2
        return Rect(x: 0, y: 0, width: width, height: height)
    }
    override func updateLayout() {
        let padding = Layout.smallPadding
        nameView.frame.origin = Point(x: padding,
                                      y: bounds.height - nameView.frame.height - padding)
        quasimodeView.frame.origin = Point(x: bounds.width - quasimodeView.frame.width - padding,
                                           y: bounds.height - nameView.frame.height - padding)
    }
    func updateWithModel() {
        nameView.updateWithModel()
        quasimodeView.updateWithModel()
    }
}

final class SubActionManagableView<T: SubActionManagable, U: BinderProtocol>
: View, BindableGetterReceiver {

    typealias Model = T
    typealias Binder = U
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((ActionManagerView<Binder>, BasicNotification) -> ())]()
    
    init(binder: Binder, keyPath: BinderKeyPath,
         frame: Rect = Rect()) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        super.init()
        bounds = defaultBounds
    }
    
    static var defaultWidth: Real {
        return 80 + Layout.basicPadding * 2
    }
    
    override var defaultBounds: Rect {
        let padding = Layout.basicPadding
        let actionHeight = Layout.basicTextHeight + Layout.smallPadding * 2
        let height = actionHeight * Real(model.actions.count) + padding * 2
        return Rect(x: 0, y: 0, width: SubActionManagableView.defaultWidth, height: height)
    }
    override func updateLayout() {
        let padding = Layout.basicPadding
        let ah = Layout.basicTextHeight + Layout.smallPadding * 2
        let aw = bounds.width - padding * 2
        var y = bounds.height - padding
        children = (0..<model.actions.count).map {
            y -= ah
            return ActionView(binder: binder,
                              keyPath: keyPath.appending(path: \Model.actions[$0]),
                              frame: Rect(x: padding, y: y, width: aw, height: ah))
        }
    }
    func updateWithModel() {}
}

/**
 Issue: アクションの表示をキーボードに常に表示（ハードウェアの変更が必要）
 Issue: コマンドの編集自由化
 */
final class ActionManagerView<T: BinderProtocol>: View, BindableGetterReceiver {
    typealias Model = ActionManager
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((ActionManagerView<Binder>, BasicNotification) -> ())]()
    
    
    
    let classNameView = TextFormView(text: ActionManager.name, font: .bold)
    
    init(binder: Binder, keyPath: BinderKeyPath,
         frame: Rect = Rect()) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        actionManagableViews = model.subActionManagers.map {
            SubActionManagableView(actionMangable: $0)
        }
        
        super.init()
        children = [classNameView] + actionManagableViews
        self.frame = frame
    }
    
    override var defaultBounds: Rect {
        let padding = Layout.basicPadding
        let ah = actionManagableViews.reduce(0.0.cg) { $0 + $1.bounds.height }
        let height = classNameView.frame.height + padding * 3 + ah
        return Rect(x: 0, y: 0,
                    width: SubActionManagableView.defaultWidth + padding * 2, height: height)
    }
    override func updateLayout() {
        let padding = Layout.basicPadding
        let w = bounds.width - padding * 2
        var y = bounds.height - classNameView.frame.height - padding
        classNameView.frame.origin = Point(x: padding, y: y)
        y -= padding
        _ = actionManagableViews.reduce(y) {
            let ny = $0 - $1.frame.height
            $1.frame = Rect(x: padding, y: ny, width: w, height: $1.frame.height)
            return ny
        }
    }
    func updateWithModel() {
        actionManagableViews = model.subActionManagers.map {
            SubActionManagableView(actionMangable: $0)
        }
        children = [classNameView] + actionManagableViews
    }
}
extension ActionManagerView: Localizable {
    func update(with locale: Locale) {
        updateLayout()
    }
}
