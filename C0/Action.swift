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
    let name: Text, description: Text, quasimode: Quasimode, isEditable: Bool
    
    init(name: Text = "", description: Text = "", quasimode: Quasimode, isEditable: Bool = true) {
        self.name = name
        self.description = description
        self.quasimode = quasimode
        self.isEditable = isEditable
    }
    
    var quasimodeDisplayText: Text {
        return quasimode.displayText
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

protocol SubActionList: SubSendable {
    var actions: [Action] { get }
}

struct ActionList {
    let selectableActionList = SelectableActionList()
    let zoomableActionList = ZoomableActionList()
    let undoableActionList = UndoableActionList()
    let assignableActionList = AssignableActionList()
    let runnableActionList = RunnableActionList()
    let strokableActionList = StrokableActionList()
    let movableActionList = MovableActionList()
    
    let subActionLists: [SubActionList]
    let actions: [Action]
    
    init() {
        subActionLists = [selectableActionList, zoomableActionList,
                          undoableActionList, assignableActionList,
                          runnableActionList, strokableActionList, movableActionList]
        actions = subActionLists.flatMap { $0.actions }
    }
}
extension ActionList: Referenceable {
    static let name = Text(english: "Action List", japanese: "アクション一覧")
}

final class ActionFormView: View {
    var action: Action
    
    var nameView: TextFormView, quasimodeDisplayTextView: TextFormView
    
    init(action: Action, frame: Rect = Rect()) {
        self.action = action
        
        nameView = TextFormView(text: action.name)
        quasimodeDisplayTextView = TextFormView(text: action.quasimode.displayText,
                                                font: Font(monospacedSize: 10),
                                                frameAlignment: .right, alignment: .right)
        
        super.init(isLocked: true)
        lineColor = .formBorder
        self.frame = frame
        children = [nameView, quasimodeDisplayTextView]
    }
    
    override var defaultBounds: Rect {
        let padding = Layouter.basicPadding
        let width = nameView.bounds.width + padding + quasimodeDisplayTextView.bounds.width
        let height = nameView.frame.height + Layouter.smallPadding * 2
        return Rect(x: 0, y: 0, width: width, height: height)
    }
    override func updateLayout() {
        let padding = Layouter.smallPadding
        nameView.frame.origin = Point(x: padding,
                                      y: bounds.height - nameView.frame.height - padding)
        quasimodeDisplayTextView.frame.origin
            = Point(x: bounds.width - quasimodeDisplayTextView.frame.width - padding,
                    y: bounds.height - nameView.frame.height - padding)
    }
}

final class SubActionListFormView<T: SubActionList>: View {
    var subActionList: T
    
    init(_ subActionList: T) {
        self.subActionList = subActionList
        
        super.init(isLocked: true)
        lineColor = nil
        bounds = defaultBounds
        let padding = Layouter.basicPadding
        let ah = Layouter.basicTextHeight + Layouter.smallPadding * 2
        let aw = bounds.width - padding * 2
        var y = bounds.height - padding
        children = subActionList.actions.map {
            y -= ah
            return ActionFormView(action: $0,
                                  frame: Rect(x: padding, y: y, width: aw, height: ah))
        }
    }
    
    override var defaultBounds: Rect {
        let padding = Layouter.basicPadding
        let actionHeight = Layouter.basicTextHeight + Layouter.smallPadding * 2
        let height = actionHeight * Real(subActionList.actions.count) + padding * 2
        return Rect(x: 0, y: 0, width: Layouter.propertyWidth, height: height)
    }
    override func updateLayout() {
        let padding = Layouter.basicPadding
        let ah = Layouter.basicTextHeight + Layouter.smallPadding * 2
        let aw = bounds.width - padding * 2
        var y = bounds.height - padding
        children.forEach {
            y -= ah
            $0.frame = Rect(x: padding, y: y, width: aw, height: ah)
        }
    }
}

/**
 Hardware Issue: アクションをキーボードとトラックパッドに直接表示
 */
final class ActionListFormView: View {
    var actionList: ActionList
    
    let selectableActionListView = SubActionListFormView(SelectableActionList())
    let zoomableActionListView = SubActionListFormView(ZoomableActionList())
    let undoableActionListView = SubActionListFormView(UndoableActionList())
    let assignableActionListView = SubActionListFormView(AssignableActionList())
    let runnableActionListView = SubActionListFormView(RunnableActionList())
    let strokableActionListView = SubActionListFormView(StrokableActionList())
    let movableActionListView = SubActionListFormView(MovableActionList())
    let subActionListViews: [View]
    
    let classNameView = TextFormView(text: ActionList.name, font: .bold)
    var width = 200.0.cg
    
    init(actionList: ActionList = ActionList(), frame: Rect = Rect()) {
        self.actionList = actionList
        
        subActionListViews = [selectableActionListView, zoomableActionListView,
                              undoableActionListView, assignableActionListView,
                              runnableActionListView, strokableActionListView,
                              movableActionListView]
        
        super.init(isLocked: true)
        lineColor = nil
        children = [classNameView] + subActionListViews
        self.frame = frame
    }
    
    override var defaultBounds: Rect {
        let padding = Layouter.basicPadding
        let ah = subActionListViews.reduce(0.0.cg) { $0 + $1.bounds.height }
        let height = classNameView.frame.height + padding * 3 + ah
        return Rect(x: 0, y: 0,
                    width: width + padding * 2, height: height)
    }
    override func updateLayout() {
        let padding = Layouter.basicPadding
        let w = bounds.width - padding * 2
        var y = bounds.height - classNameView.frame.height - padding
        classNameView.frame.origin = Point(x: padding, y: y)
        y -= padding
        _ = subActionListViews.reduce(y) {
            let ny = $0 - $1.frame.height
            $1.frame = Rect(x: padding, y: ny, width: w, height: $1.frame.height)
            return ny
        }
    }
}
