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

typealias SelectionValue = Object.Value & AbstractViewable

protocol Selectable: class {
//    func captureSelections(to version: Version)
//    func makeViewSelector() -> ViewSelector
//    func selectAll()
//    func deselectAll()
    
    var valueViews: [View] { get }
    var selectedIndexes: [Int] { get set }
}
struct Selection<Value: SelectionValue>: ValueChain, Codable {
    typealias Index = Array<Value>.Index
    
    var values = Array<Value>()
    var selectedIndexes = [Index]()
    
    var chainValue: Any {
        return values
    }
}
extension Selection: Referenceable {
    static var name: Text {
        return Text(english: "Selection", japanese: "セレクション") + "<" + Value.name + ">"
    }
}
extension Selection: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return View()
    }
}
extension Selection: AbstractViewable {
    func abstractViewWith<T : BinderProtocol>(binder: T,
                                              keyPath: ReferenceWritableKeyPath<T, Selection<Value>>,
                                              frame: Rect, _ sizeType: SizeType,
                                              type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return SelectionView(binder: binder, keyPath: keyPath,
                                 frame: frame, sizeType: sizeType, abstractType: type)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath, frame: frame, sizeType)
        }
    }
}
extension Selection: ObjectViewable {}

final class SelectionView<Value: Object.Value & AbstractViewable, T: BinderProtocol>
: ModelView, BindableReceiver, Selectable {
    
    typealias Model = Selection<Value>
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((SelectionView<Value, Binder>, BasicPhaseNotification<Model>) -> ())]()
    
    var sizeType: SizeType {
        didSet { updateLayout() }
    }
    
    var defaultModel: Selection<Value> {
        return Selection()
    }
    
    let valuesView: ArrayView<Value, Binder>
    
    init(binder: Binder, keyPath: BinderKeyPath,
         frame: Rect = Rect(), sizeType: SizeType = .regular, abstractType: AbstractType = .normal) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        self.sizeType = sizeType
        
        valuesView = ArrayView(binder: binder, keyPath: keyPath.appending(path: \Model.values),
                               sizeType: sizeType, abstractType: abstractType)
        
        super.init()
        children = [valuesView]
        self.frame = frame
    }
    
    override var defaultBounds: Rect {
        return valuesView.defaultBounds.inset(by: -Layouter.padding(with: sizeType))
    }
    override func updateLayout() {
        valuesView.frame = bounds.inset(by: Layouter.padding(with: sizeType))
    }
    func updateWithModel() {
        
    }
    
    var valueViews: [View] {
        return valuesView.children
    }
    var selectedIndexes: [Selection<Value>.Index] {
        get { return model.selectedIndexes }
        set {
            model.selectedIndexes.forEach {
                valuesView.children[$0].lineColor = .getSetBorder
            }
            model.selectedIndexes = newValue
            newValue.forEach {
                valuesView.children[$0].lineColor = .selected
            }
        }
    }
}

protocol ViewSelector: class {
    func select(from rect: Rect, _ phase: Phase)
    func deselect(from rect: Rect, _ phase: Phase)
}

protocol IndicatableResponder {
    var indicatedLineColor: Color? { get }
}
protocol Indicatable: IndicatableResponder {
    func indicate(at p: Point)
}

struct SelectableActionList: SubActionList {
    let indicateAction = Action(name: Text(english: "Indicate", japanese: "指し示す"),
                                quasimode: Quasimode([.drag(.pointing)]))
    let selectAction = Action(name: Text(english: "Select", japanese: "選択"),
                              quasimode: Quasimode(modifier: [.input(.command)],
                                                   [.drag(.drag)]))
    let deselectAction = Action(name: Text(english: "Deselect", japanese: "選択解除"),
                                quasimode: Quasimode(modifier: [.input(.shift),
                                                                .input(.command)],
                                                     [.drag(.drag)]))
    let selectAllAction = Action(name: Text(english: "Select All", japanese: "すべて選択"),
                                 quasimode: Quasimode(modifier: [.input(.command)],
                                                      [.input(.a)]))
    let deselectAllAction = Action(name: Text(english: "Deselect All", japanese: "すべて選択解除"),
                                   quasimode: Quasimode(modifier: [.input(.shift),
                                                                   .input(.command)],
                                                        [.input(.a)]))
    var actions: [Action] {
        return [indicateAction,
                selectAction, deselectAction,
                selectAllAction, deselectAllAction]
    }
}
extension SelectableActionList: SubSendable {
    func makeSubSender() -> SubSender {
        return SelectableSender(actionList: self)
    }
}

final class SelectableSender: SubSender {
    typealias IndicatableReceiver = View & Indicatable
    typealias SelectableReceiver = View & Selectable
    
    typealias ActionList = SelectableActionList
    var actionList: ActionList
    
    init(actionList: ActionList) {
        self.actionList = actionList
    }
    
    private var selector = Selector()
    
    func send(_ actionMap: ActionMap, from sender: Sender) {
        switch actionMap.action {
        case actionList.indicateAction:
            if let eventValue = actionMap.eventValuesWith(DragEvent.self).first {
                sender.currentRootLocation = eventValue.rootLocation
                sender.mainIndicatedView
                    = sender.rootView.at(eventValue.rootLocation) ?? sender.rootView
                if let receiver = sender.mainIndicatedView as? IndicatableReceiver {
                    let p = receiver.convertFromRoot(eventValue.rootLocation)
                    receiver.indicate(at: p)
                }
            }
        case actionList.selectAction, actionList.deselectAction:
            if let eventValue = actionMap.eventValuesWith(DragEvent.self).first {
                selector.send(eventValue, actionMap.phase, from: sender,
                              isDeselect: actionMap.action == actionList.deselectAction)
            }
        case actionList.selectAllAction, actionList.deselectAllAction:
            guard actionMap.phase == .began else { break }
            if let receiver = sender.mainIndicatedView as? SelectableReceiver {
//                receiver.captureSelections(to: sender.indicatedVersionView.version)
                if actionMap.action == actionList.deselectAllAction {
//                    receiver.deselectAll()
                    receiver.selectedIndexes = []
                } else {
//                    receiver.selectedIndexes = receiver
                    receiver.selectedIndexes = Array(0..<receiver.valueViews.count)
                }
            }
        default: break
        }
    }
    
    private final class Selector {
        weak var receiver: SelectableReceiver?, viewSelector: ViewSelector?
        
        private var startPoint = Point(), startRootPoint = Point(), oldIsDeselect = false
        var selectionView: View?
        var beganSeletedIndexes = [Int]()
        
        func indexes(from rect: Rect, from receiver: SelectableReceiver) -> [Int] {
            return (0..<receiver.valueViews.count).filter { receiver.valueViews[$0].contains(rect) }
        }
        
        func send(_ event: DragEvent.Value, _ phase: Phase,
                  from sender: Sender, isDeselect: Bool) {
            func unionIndexesWith(oldIndexes: [Int], newIndexes: [Int]) -> [Int] {
                if isDeselect {
                    return Array(Set(oldIndexes).subtracting(Set(newIndexes)))
                } else {
                    return Array(Set(oldIndexes).union(Set(newIndexes)))
                }
            }
            switch phase {
            case .began:
                let selectionView = isDeselect ? View.deselection : View.selection
                sender.rootView.append(child: selectionView)
                selectionView.frame = Rect(origin: event.rootLocation, size: Size())
                self.selectionView = selectionView

                if let receiver = sender.mainIndicatedView.withSelfAndAllParents(with: SelectableReceiver.self) {
                    startRootPoint = event.rootLocation
                    startPoint = receiver.convertFromRoot(event.rootLocation)
                    self.receiver = receiver
                    beganSeletedIndexes = receiver.selectedIndexes
                    
//                    receiver.captureSelections(to: sender.indicatedVersionView.version)
//                    viewSelector = receiver.makeViewSelector()
                    
                    let rect = Rect(origin: startPoint, size: Size())
                    receiver.selectedIndexes = unionIndexesWith(oldIndexes: beganSeletedIndexes,
                                                                newIndexes: indexes(from: rect,
                                                                                    from: receiver))
                    
                    
                    
                    
//                    if isDeselect {
//                        viewSelector?.deselect(from: rect, phase)
//                    } else {
//                        viewSelector?.select(from: rect, phase)
//                    }
                    oldIsDeselect = isDeselect
                }
            case .changed, .ended:
                guard let receiver = receiver else { return }
                if isDeselect != oldIsDeselect {
                    selectionView?.fillColor = isDeselect ? .deselect : .select
                    selectionView?.lineColor = isDeselect ? .deselectBorder : .selectBorder
                    oldIsDeselect = isDeselect
                }
                let lp = event.rootLocation
                selectionView?.frame = Rect(origin: startRootPoint,
                                            size: Size(width: lp.x - startRootPoint.x,
                                                       height: lp.y - startRootPoint.y))
                let p = receiver.convertFromRoot(event.rootLocation)
                let aabb = AABB(minX: min(startPoint.x, p.x), maxX: max(startPoint.x, p.x),
                                minY: min(startPoint.y, p.y), maxY: max(startPoint.y, p.y))
                let rect = aabb.rect
                
                receiver.selectedIndexes = unionIndexesWith(oldIndexes: beganSeletedIndexes,
                                                            newIndexes: indexes(from: rect,
                                                                                from: receiver))
//
//                if isDeselect {
//                    viewSelector?.deselect(from: rect, phase)
//
//                } else {
////                    if let selectionView =
//
//                    viewSelector?.select(from: rect, phase)
//                }
                
                if phase == .ended {
                    selectionView?.removeFromParent()
                    selectionView = nil
                    self.receiver = nil
                    self.viewSelector = nil
                }
            }
        }
    }
}
//
//
//extension AnimationView: Selectable {
//    func captureSelections(to version: Version) {
//        version.registerUndo(withTarget: self) {
//            [oldSelectedKeyframeIndexes = model.selectedKeyframeIndexes, unowned version] in
//
//            $0.pushSelectedKeyframeIndexes(oldSelectedKeyframeIndexes, to: version)
//        }
//    }
//    func pushSelectedKeyframeIndexes(_ selectedKeyframeIndexes: [KeyframeIndex],
//                                     to version: Version) {
//        version.registerUndo(withTarget: self) {
//            [oldSelectedKeyframeIndexes = model.selectedKeyframeIndexes, unowned version] in
//
//            $0.pushSelectedKeyframeIndexes(oldSelectedKeyframeIndexes, to: version)
//        }
//        model.selectedKeyframeIndexes = selectedKeyframeIndexes
//        updateLayout()
//    }
//
//    func makeViewSelector() -> ViewSelector {
//        return AnimationViewSelector(animationView: self)
//    }
//
//    func selectAll() {
//        model.selectedKeyframeIndexes = Array(0..<model.keyframes.count)
//        updateLayout()
//    }
//    func deselectAll() {
//        model.selectedKeyframeIndexes = []
//        updateLayout()
//    }
//}
//final class AnimationViewSelector<Value: KeyframeValue, Binder: BinderProtocol>: ViewSelector {
//    var animationView: AnimationView<Value, Binder>
//    var model: Animation<Value> {
//        get { return animationView.model }
//        set { animationView.model = newValue }
//    }
//
//    init(animationView: AnimationView<Value, Binder>) {
//        self.animationView = animationView
//    }
//
//    var beginSelectedKeyframeIndexes = [KeyframeIndex]()
//
//    func select(from rect: Rect, _ phase: Phase) {
//        select(from: rect, phase, isDeselect: false)
//    }
//    func deselect(from rect: Rect, _ phase: Phase) {
//        select(from: rect, phase, isDeselect: true)
//    }
//    func select(from rect: Rect, _ phase: Phase, isDeselect: Bool) {
//        switch phase {
//        case .began:
//            beginSelectedKeyframeIndexes = model.selectedKeyframeIndexes
//        case .changed, .ended:
//            model.selectedKeyframeIndexes = selectedIndex(from: rect, isDeselect: isDeselect)
//            animationView.updateLayout()
//        }
//    }
//    private func indexes(from rect: Rect) -> [KeyframeIndex] {
//        let halfTimeInterval = animationView.baseTimeInterval / 2
//        let startTime = animationView.time(withX: rect.minX, isBased: false) + halfTimeInterval
//        let startIndexInfo = Keyframe.indexInfo(atTime: startTime,
//                                                with: animationView.model.keyframes)
//        let startIndex = startIndexInfo.index
//        let selectEndX = rect.maxX
//        let endTime = animationView.time(withX: selectEndX, isBased: false) + halfTimeInterval
//        let endIndexInfo = Keyframe.indexInfo(atTime: endTime,
//                                              with: animationView.model.keyframes)
//        let endIndex = endIndexInfo.index
//        return startIndex == endIndex ?
//            [startIndex] :
//            Array(startIndex < endIndex ? (startIndex...endIndex) : (endIndex...startIndex))
//    }
//    private func selectedIndex(from rect: Rect, isDeselect: Bool) -> [KeyframeIndex] {
//        let selectedIndexes = indexes(from: rect)
//        return isDeselect ?
//            Array(Set(beginSelectedKeyframeIndexes).subtracting(Set(selectedIndexes))).sorted() :
//            Array(Set(beginSelectedKeyframeIndexes).union(Set(selectedIndexes))).sorted()
//    }
//
//}
//
//extension CanvasView: Selectable {
//    func captureSelections(to version: Version) {
//        version.registerUndo(withTarget: self) {
//            [oldSelectedCellIndexes = model.editingCellGroup.selectedCellIndexes, unowned version] in
//
//            $0.pushSelectedCellIndexes(oldSelectedCellIndexes, to: version)
//        }
//    }
//    func pushSelectedCellIndexes(_ selectedCellIndexes: [Cell.Index],
//                                 to version: Version) {
//        version.registerUndo(withTarget: self) {
//            [oldSelectedCellIndexes = model.editingCellGroup.selectedCellIndexes, unowned version] in
//
//            $0.pushSelectedCellIndexes(oldSelectedCellIndexes, to: version)
//        }
//        model.editingCellGroup.selectedCellIndexes = selectedCellIndexes
//        updateLayout()
//    }
//
//    func makeViewSelector() -> ViewSelector {
//        return CanvasViewSelector<Binder>(canvasView: self)
//    }
//
//    func selectAll() {
//        model.editingCellGroup.selectedCellIndexes = []
//    }
//    func deselectAll() {
//        model.editingCellGroup.selectedCellIndexes
//            = model.editingCellGroup.rootCell.treeIndexEnumerated().map { (index, _) in index }
//    }
//}
//final class CanvasViewSelector<Binder: BinderProtocol>: ViewSelector {
//    var canvasView: CanvasView<Binder>
//    var cellGroup: CellGroup?, cellGroupIndex = CellGroup.Index()
//    var selectedLineIndexes = [Int]()
//    var drawing: Drawing?
//
//    init(canvasView: CanvasView<Binder>) {
//        self.canvasView = canvasView
//    }
//
//    func select(from rect: Rect, _ phase: Phase) {
//        select(from: rect, phase, isDeselect: false)
//    }
//    func deselect(from rect: Rect, _ phase: Phase) {
//        select(from: rect, phase, isDeselect: true)
//    }
//    func select(from rect: Rect, _ phase: Phase, isDeselect: Bool) {
//        func unionWithStrokeLine(with drawing: Drawing) -> [Array<Line>.Index] {
//            let affine = canvasView.screenToEditingCellGroupTransform.inverted()
//            let lines = [Line].rectangle(rect).map { $0 * affine }
//            let geometry = Geometry(lines: lines)
//            let lineIndexes = drawing.lines.enumerated().compactMap {
//                geometry.intersects($1) ? $0 : nil
//            }
//            if isDeselect {
//                return Array(Set(selectedLineIndexes).subtracting(Set(lineIndexes)))
//            } else {
//                return Array(Set(selectedLineIndexes).union(Set(lineIndexes)))
//            }
//        }
//
//        switch phase {
//        case .began:
//            cellGroup = canvasView.model.editingCellGroup
//            cellGroupIndex = canvasView.model.editingCellGroupTreeIndex
//            drawing = canvasView.model.editingCellGroup.drawing
//            selectedLineIndexes = canvasView.model.editingCellGroup.drawing.selectedLineIndexes
//        case .changed, .ended:
//            guard let drawing = drawing else { return }
//            //            drawing?.selectedLineIndexes = unionWithStrokeLine(with: drawing)
//        }
//    }
//}
