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

struct Action {
    let name: Text, description: Text, quasimode: Quasimode, isEditable: Bool
    
    init(name: Text = "", description: Text = "", quasimode: Quasimode, isEditable: Bool = true) {
        self.name = name
        self.description = description
        self.quasimode = quasimode
        self.isEditable = isEditable
    }
    
    func isSubset(of other: Action) -> Bool {
        let types = quasimode.allEventTypes
        let otherTypes = other.quasimode.allEventTypes
        for type in types {
            if !otherTypes.contains(where: { $0.name.base == type.name.base }) {
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
    let undoableActionManager = UndoableActionManager()
    let assignableActionManager = AssignableActionManager()
    let runnableActionManager = RunnableActionManager()
    let strokableActionManager = StrokableActionManager()
    let movableActionManager = MovableActionManager()
    
    let subActionManagers: [SubActionManagable]
    let actions: [Action]
    
    init() {
        subActionManagers = [selectableActionManager, zoomableActionManager,
                             undoableActionManager, assignableActionManager,
                             runnableActionManager, strokableActionManager, movableActionManager]
        actions = subActionManagers.flatMap { $0.actions }
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
extension ActionView: Localizable {
    func update(with locale: Locale) {
        updateLayout()
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
    
    override var defaultBounds: Rect {
        let padding = Layout.basicPadding
        let actionHeight = Layout.basicTextHeight + Layout.smallPadding * 2
        let height = actionHeight * Real(model.actions.count) + padding * 2
        return Rect(x: 0, y: 0, width: Layout.propertyWidth, height: height)
    }
    override func updateLayout() {
        let padding = Layout.basicPadding
        let ah = Layout.basicTextHeight + Layout.smallPadding * 2
        let aw = bounds.width - padding * 2
        var y = bounds.height - padding
        children.forEach {
            y -= ah
            $0.frame = Rect(x: padding, y: y, width: aw, height: ah)
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
    
    let selectableActionManagerView: SubActionManagableView<SelectableActionManager, Binder>
    let zoomableActionManagerView: SubActionManagableView<ZoomableActionManager, Binder>
    let undoableActionManagerView: SubActionManagableView<UndoableActionManager, Binder>
    let assignableActionManagerView: SubActionManagableView<AssignableActionManager, Binder>
    let runnableActionManagerView: SubActionManagableView<RunnableActionManager, Binder>
    let strokableActionManagerView: SubActionManagableView<StrokableActionManager, Binder>
    let movableActionManagerView: SubActionManagableView<MovableActionManager, Binder>
    let subActionManagableViews: [View]
    
    let classNameView = TextFormView(text: ActionManager.name, font: .bold)
    var width = 200.0.cg
    
    init(binder: Binder, keyPath: BinderKeyPath,
         frame: Rect = Rect()) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        let selectableKeyPath = keyPath.appending(path: \.selectableActionManager)
        selectableActionManagerView = SubActionManagableView(binder: binder,
                                                             keyPath: selectableKeyPath)
        let zoomableKeyPath = keyPath.appending(path: \.zoomableActionManager)
        zoomableActionManagerView = SubActionManagableView(binder: binder,
                                                           keyPath: zoomableKeyPath)
        let undoableKeyPath = keyPath.appending(path: \.undoableActionManager)
        undoableActionManagerView = SubActionManagableView(binder: binder,
                                                              keyPath: undoableKeyPath)
        let assignableKeyPath = keyPath.appending(path: \.assignableActionManager)
        assignableActionManagerView = SubActionManagableView(binder: binder,
                                                             keyPath: assignableKeyPath)
        let runnableKeyPath = keyPath.appending(path: \.runnableActionManager)
        runnableActionManagerView = SubActionManagableView(binder: binder,
                                                           keyPath: runnableKeyPath)
        let strokableKeyPath = keyPath.appending(path: \.strokableActionManager)
        strokableActionManagerView = SubActionManagableView(binder: binder,
                                                            keyPath: strokableKeyPath)
        let movableKeyPath = keyPath.appending(path: \.movableActionManager)
        movableActionManagerView = SubActionManagableView(binder: binder,
                                                          keyPath: movableKeyPath)
        subActionManagableViews = [selectableActionManagerView, zoomableActionManagerView,
                                   undoableActionManagerView, assignableActionManagerView,
                                   runnableActionManagerView, strokableActionManagerView,
                                   movableActionManagerView]
        
        super.init()
        children = [classNameView] + subActionManagableViews
        self.frame = frame
    }
    
    override var defaultBounds: Rect {
        let padding = Layout.basicPadding
        let ah = subActionManagableViews.reduce(0.0.cg) { $0 + $1.bounds.height }
        let height = classNameView.frame.height + padding * 3 + ah
        return Rect(x: 0, y: 0,
                    width: width + padding * 2, height: height)
    }
    override func updateLayout() {
        let padding = Layout.basicPadding
        let w = bounds.width - padding * 2
        var y = bounds.height - classNameView.frame.height - padding
        classNameView.frame.origin = Point(x: padding, y: y)
        y -= padding
        _ = subActionManagableViews.reduce(y) {
            let ny = $0 - $1.frame.height
            $1.frame = Rect(x: padding, y: ny, width: w, height: $1.frame.height)
            return ny
        }
    }
    func updateWithModel() {}
}
extension ActionManagerView: Localizable {
    func update(with locale: Locale) {
        updateLayout()
    }
}
