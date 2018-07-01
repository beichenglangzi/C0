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
    func captureSelections(to version: Version)
    var valueViews: [View] { get }
    var selectedIndexes: [Int] { get set }
    var selectedViews: [View] { get }
}
extension Selectable {
    var selectedViews: [View] {
        return selectedIndexes.map { valueViews[$0] }
    }
}

struct Selecting<Value: SelectionValue>: ValueChain, Codable {
    var value: Value
    var isSelected = false
    
    init(value: Value, isSelected: Bool = false) {
        self.value = value
        self.isSelected = isSelected
    }
    
    var chainValue: Any {
        return value
    }
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
    func thumbnailView(withFrame frame: Rect) -> View {
        return View()
    }
}
extension Selection: AbstractViewable {
    func abstractViewWith<T : BinderProtocol>(binder: T,
                                              keyPath: ReferenceWritableKeyPath<T, Selection<Value>>,
                                              type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return SelectionView(binder: binder, keyPath: keyPath, abstractType: type)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath)
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
    
    var defaultModel: Selection<Value> {
        return Selection()
    }
    
    let valuesView: ArrayView<Value, Binder>
    
    init(binder: Binder, keyPath: BinderKeyPath, abstractType: AbstractType = .normal) {
        self.binder = binder
        self.keyPath = keyPath
        
        valuesView = ArrayView(binder: binder,
                               keyPath: keyPath.appending(path: \Model.values),
                               abstractType: abstractType)
        
        super.init(isLocked: false)
        children = [valuesView]
    }
    
    var minSize: Size {
        let minSize = valuesView.minSize, padding = Layouter.basicPadding
        return Size(width: minSize.width + padding, height: minSize.height + padding)
    }
    override func updateLayout() {
        valuesView.bounds = bounds.inset(by: Layouter.basicPadding)
            * valuesView.transform.affineTransform.inverted()
    }
    func updateWithModel() {
        valuesView.updateWithModel()
    }
    
    func captureSelections(to version: Version) {
        capture(selectionIndexes: selectedIndexes, to: version)
    }
    func capture(selectionIndexes: [Selection<Value>.Index], to version: Version) {
        version.registerUndo(withTarget: self) {
            [oldIndexes = self.selectedIndexes, unowned version] in
            
            $0.capture(selectionIndexes: oldIndexes, to: version)
        }
    }
    var valueViews: [View] {
        return valuesView.rootView.children
    }
    var selectedIndexes: [Selection<Value>.Index] {
        get { return model.selectedIndexes }
        set {
            model.selectedIndexes.forEach {
                valueViews[$0].lineWidth = 0.5
                valueViews[$0].lineColor = .getSetBorder
            }
            binder[keyPath: keyPath].selectedIndexes = newValue
            newValue.forEach {
                valueViews[$0].lineWidth = 2
                valueViews[$0].lineColor = .selected
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
                                quasimode: Quasimode([.drag(.pointing)]),
                                isEditable: false)
    let selectAction = Action(name: Text(english: "Select", japanese: "選択"),
                              quasimode: Quasimode(modifier: [.input(.command)],
                                                   [.drag(.drag)]))
    let deselectAction = Action(name: Text(english: "Deselect", japanese: "選択を解除"),
                                quasimode: Quasimode(modifier: [.input(.shift),
                                                                .input(.command)],
                                                     [.drag(.drag)]))
    let selectAllAction = Action(name: Text(english: "Select All", japanese: "すべて選択"),
                                 quasimode: Quasimode(modifier: [.input(.command)],
                                                      [.input(.a)]))
    let deselectAllAction = Action(name: Text(english: "Deselect All", japanese: "すべての選択を解除"),
                                   quasimode: Quasimode(modifier: [.input(.shift),
                                                                   .input(.command)],
                                                        [.input(.a)]))
    var actions: [Action] {
        return [indicateAction,
                selectAction, deselectAction]
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
                
                guard let selectionReceiver = sender.mainIndicatedView
                    .withSelfAndAllParents(with: SelectableReceiver.self) else { return }
                var containsIndicatedViews = false
                let selectedViews = selectionReceiver.selectedViews
                sender.mainIndicatedView.selfAndAllParents { (view, stop) in
                    if selectedViews.contains(view) {
                        containsIndicatedViews = true
                        stop = true
                    }
                }
                if containsIndicatedViews {
                    sender.indictedViews = selectionReceiver.selectedViews
                } else {
                    sender.indictedViews = [sender.mainIndicatedView]
                }
            }
        case actionList.selectAction, actionList.deselectAction:
            if let eventValue = actionMap.eventValuesWith(DragEvent.self).first {
                selector.send(eventValue, actionMap.phase, from: sender,
                              isDeselect: actionMap.action == actionList.deselectAction)
            }
        case actionList.selectAllAction, actionList.deselectAllAction:
            guard actionMap.phase == .began else { break }
            if let receiver = sender.mainIndicatedView
                .withSelfAndAllParents(with: SelectableReceiver.self) {
                
                receiver.captureSelections(to: sender.indicatedVersionView.version)
                if actionMap.action == actionList.deselectAllAction {
                    receiver.selectedIndexes = []
                } else {
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
            return (0..<receiver.valueViews.count).filter {
                let view = receiver.valueViews[$0]
                let convertedRect = view.convert(rect, from: receiver)
                return view.contains(convertedRect)
            }
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

                if let receiver = sender.mainIndicatedView
                    .withSelfAndAllParents(with: SelectableReceiver.self) {
                    
                    startRootPoint = event.rootLocation
                    startPoint = receiver.convertFromRoot(event.rootLocation)
                    self.receiver = receiver
                    beganSeletedIndexes = receiver.selectedIndexes
                    
                    receiver.captureSelections(to: sender.indicatedVersionView.version)
                    
                    let rect = Rect(origin: startPoint, size: Size())
                    receiver.selectedIndexes = unionIndexesWith(oldIndexes: beganSeletedIndexes,
                                                                newIndexes: indexes(from: rect,
                                                                                    from: receiver))
                    oldIsDeselect = isDeselect
                }
            case .changed, .ended:
                guard let receiver = receiver else { return }
                if isDeselect != oldIsDeselect {
                    selectionView?.fillColorComposition = isDeselect ? .deselect : .select
                    selectionView?.lineColorComposition =
                        isDeselect ? .deselectBorder : .selectBorder
                    oldIsDeselect = isDeselect
                }
                let lp = event.rootLocation
                let rootAABB = AABB(minX: min(startRootPoint.x, lp.x),
                                    maxX: max(startRootPoint.x, lp.x),
                                    minY: min(startRootPoint.y, lp.y),
                                    maxY: max(startRootPoint.y, lp.y))
                selectionView?.frame = rootAABB.rect
                let p = receiver.convertFromRoot(event.rootLocation)
                let aabb = AABB(minX: min(startPoint.x, p.x), maxX: max(startPoint.x, p.x),
                                minY: min(startPoint.y, p.y), maxY: max(startPoint.y, p.y))
                let rect = aabb.rect
                
                receiver.selectedIndexes = unionIndexesWith(oldIndexes: beganSeletedIndexes,
                                                            newIndexes: indexes(from: rect,
                                                                                from: receiver))
                
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
