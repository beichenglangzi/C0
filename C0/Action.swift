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

final class ActionFormView: View, LayoutMinSize {
    var action: Action
    
    var nameView: TextFormView, quasimodeDisplayTextView: TextFormView
    
    init(action: Action) {
        self.action = action
        
        nameView = TextFormView(text: action.name)
        quasimodeDisplayTextView = TextFormView(text: action.quasimode.displayText,
                                                font: Font(monospacedSize: 10),
                                                alignment: .right)
        
        super.init()
        lineColor = .formBorder
        children = [nameView, quasimodeDisplayTextView]
    }
    
    var minSize: Size {
        let nameViewMinSize = nameView.minSize
        let quasimodeDisplayTextMinSize = quasimodeDisplayTextView.minSize
        let padding = Layouter.basicPadding, smallPadding = Layouter.smallPadding
        let width = nameViewMinSize.width + padding + quasimodeDisplayTextMinSize.width
        let height = nameViewMinSize.height + smallPadding * 2
        return Size(width: width, height: height)
    }
    override func updateLayout() {
        let padding = Layouter.basicPadding, smallPadding = Layouter.smallPadding
        let nameSize = nameView.minSize, quasimodeSize = quasimodeDisplayTextView.minSize
        let nameOrigin = Point(x: padding,
                               y: bounds.height - nameSize.height - smallPadding)
        nameView.frame = Rect(origin: nameOrigin, size: nameSize)
        
        let qx = bounds.width - quasimodeSize.width - padding
        let qy = bounds.height - nameSize.height - smallPadding
        quasimodeDisplayTextView.frame = Rect(origin: Point(x: qx, y: qy), size: quasimodeSize)
    }
}

final class SubActionListFormView<T: SubActionList>: View, LayoutMinSize {
    var subActionList: T
    
    init(_ subActionList: T) {
        self.subActionList = subActionList
        
        super.init()
        lineColor = .formBorder
        children = subActionList.actions.map { ActionFormView(action: $0) }
    }
    
    var minSize: Size {
        let padding = Layouter.basicPadding
        let actionHeight = Layouter.basicTextHeight + Layouter.smallPadding * 2
        let height = actionHeight * Real(subActionList.actions.count) + padding * 2
        return Size(width: Layouter.propertyWidth, height: height)
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
    let movableActionListView = SubActionListFormView(MovableActionList())
    let strokableActionListView = SubActionListFormView(StrokableActionList())
    let subActionListViews: [View & LayoutMinSize]
    
    let classNameView = TextFormView(text: ActionList.name, font: .bold)
    var width = 210.0.cg
    
    init(actionList: ActionList = ActionList()) {
        self.actionList = actionList
        
        subActionListViews = [selectableActionListView, zoomableActionListView,
                              undoableActionListView, assignableActionListView,
                              runnableActionListView, movableActionListView,
                              strokableActionListView]
        
        super.init()
        lineColor = .formBorder
        children = [classNameView] + subActionListViews
    }
    
    var minSize: Size {
        let padding = Layouter.basicPadding
        let ah = subActionListViews.reduce(0.0.cg) { $0 + $1.minSize.height }
        let height = classNameView.minSize.height + padding * 3 + ah
        return Size(width: width + padding * 2, height: height)
    }
    override func updateLayout() {
        let padding = Layouter.basicPadding
        let w = bounds.width - padding * 2
        let classNameFitSize = classNameView.minSize
        var y = bounds.height - classNameFitSize.height - padding
        classNameView.frame = Rect(origin: Point(x: padding, y: y), size: classNameFitSize)
        y -= padding
        _ = subActionListViews.reduce(y) {
            let h = $1.minSize.height
            let ny = $0 - h
            $1.frame = Rect(x: padding, y: ny, width: w, height: h)
            return ny
        }
    }
}
