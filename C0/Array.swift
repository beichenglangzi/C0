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

import Foundation

final class TreeNode<T: Equatable>: Equatable {
    static func ==(lhs: TreeNode<T>, rhs: TreeNode<T>) -> Bool {
        return lhs === rhs
    }
    
    var object: T
    init(_ object: T, children: [TreeNode<T>] = []) {
        self.object = object
        self.children = children
        children.forEach { $0.parent = self }
    }
    
    private(set) weak var parent: TreeNode<T>?
    var children: [TreeNode<T>] {
        didSet {
            oldValue.forEach { $0.parent = nil }
            children.forEach { $0.parent = self }
        }
    }
    func allChildren(_ closure: (TreeNode<T>) -> Void) {
        func allChildrenRecursion(_ node: TreeNode<T>, _ closure: (TreeNode<T>) -> Void) {
            node.children.forEach { allChildrenRecursion($0, closure) }
            closure(node)
        }
        children.forEach { allChildrenRecursion($0, closure) }
    }
    func allChildrenAndSelf(_ closure: (TreeNode<T>) -> Void) {
        func allChildrenRecursion(_ node: TreeNode<T>, _ closure: (TreeNode<T>) -> Void) {
            node.children.forEach { allChildrenRecursion($0, closure) }
            closure(node)
        }
        allChildrenRecursion(self, closure)
    }
    func allChildren(_ closure: (TreeNode<T>, inout Bool) -> ()) {
        var stop = false
        func allChildrenRecursion(_ node: TreeNode<T>, _ closure: (TreeNode<T>, inout Bool) -> ()) {
            for child in node.children {
                allChildrenRecursion(child, closure)
                if stop {
                    return
                }
            }
            closure(node, &stop)
            if stop {
                return
            }
        }
        for child in children {
            allChildrenRecursion(child, closure)
            if stop {
                return
            }
        }
    }
    func allParentsAndSelf(_ closure: ((TreeNode<T>) -> ())) {
        closure(self)
        parent?.allParentsAndSelf(closure)
    }
    
    func at(_ object: T) -> TreeNode<T> {
        var node: TreeNode<T>?
        allChildren { (aNode, stop) in
            if aNode.object == object {
                node = aNode
                stop = true
            }
        }
        return node!
    }
    
    func remove(atAllIndex i: Int) {
        let node = at(allIndex: i)
        let parent = node.parent!
        parent.children.remove(at: parent.children.index(of: node)!)
        node.parent = nil
    }
    var allCount: Int {
        var count = 0
        func allChildrenRecursion(_ node: TreeNode<T>) {
            node.children.forEach { allChildrenRecursion($0) }
            count += node.children.count
        }
        allChildrenRecursion(self)
        return count
    }
    func at(allIndex ti: Int) -> TreeNode<T> {
        var i = 0, node: TreeNode<T>?
        allChildren { (aNode, stop) in
            if i == ti {
                node = aNode
                stop = true
            } else {
                i += 1
            }
        }
        return node!
    }
    func allIndex(with node: TreeNode<T>) -> Int {
        var i = 0
        allChildren { (aNode, stop) in
            if aNode === node {
                stop = true
            } else {
                i += 1
            }
        }
        return i
    }
    func allIndex(with object: T) -> Int {
        var i = 0
        allChildren { (aNode, stop) in
            if aNode.object == object {
                stop = true
            } else {
                i += 1
            }
        }
        return i
    }
    
    var movableCount: Int {
        var count = 0
        func allChildrenRecursion(_ node: TreeNode<T>) {
            node.children.forEach { allChildrenRecursion($0) }
            count += node.children.count + 1
        }
        allChildrenRecursion(self)
        return count
    }
    func movableIndexTuple(atMovableIndex mi: Int) -> (parent: TreeNode<T>, insertIndex: Int) {
        var i = 0
        func movableIndexTuple(with node: TreeNode<T>) -> (parent: TreeNode<T>, insertIndex: Int)? {
            for (ii, child) in node.children.enumerated() {
                if let result = movableIndexTuple(with: child) {
                    return result
                }
                if i == mi {
                    return (node, ii)
                } else {
                    i += 1
                }
            }
            if i == mi {
                return (node, node.children.count)
            } else {
                i += 1
                return nil
            }
        }
        return movableIndexTuple(with: self)!
    }
    func movableIndex(with object: T) -> Int {
        return movableIndex(with: at(object))
    }
    func movableIndex(with node: TreeNode<T>) -> Int {
        let aParent = node.parent!
        var ini = aParent.children.count == 1
            || aParent.children.index(of: node)! == aParent.children.count - 1 ? 0 : 1
        node.allParentsAndSelf { (aNode) in
            if let parent = aNode.parent {
                let i = parent.children.index(of: aNode)!
                (0..<i).forEach { ini += parent.children[$0].movableCount + 1 }
            }
        }
        return ini
    }
}

extension Array {
    func withRemovedFirst() -> Array {
        var array = self
        array.removeFirst()
        return array
    }
    func withRemovedLast() -> Array {
        var array = self
        array.removeLast()
        return array
    }
    func withRemoved(at i: Int) -> Array {
        var array = self
        array.remove(at: i)
        return array
    }
    func withAppend(_ element: Element) -> Array {
        var array = self
        array.append(element)
        return array
    }
    func withInserted(_ element: Element, at i: Int) -> Array {
        var array = self
        array.insert(element, at: i)
        return array
    }
    func withReplaced(_ element: Element, at i: Int) -> Array {
        var array = self
        array[i] = element
        return array
    }
}

extension Array: ViewExpression & Copiable & Referenceable
where Element: ViewExpression & Copiable & Referenceable {
    static var name: Localization {
        return Localization("[") + Element.name + Localization("]")
    }
    func view(withBounds bounds: CGRect, sizeType: SizeType) -> View {
        return ObjectView(object: self, thumbnailView: nil, minFrame: bounds, sizeType: sizeType)
    }
}

final class AnyArrayView: View {
    var array = [ViewExpression]()
    
    init(children: [Layer] = [], frame: CGRect = CGRect()) {
        super.init()
        isClipped = true
        self.frame = frame
        replace(children: children)
    }
    
    func copiedObjects(with event: KeyInputEvent) -> [ViewExpression]? {
        return array
    }
    
    func reference(with event: TapEvent) -> Reference? {
        return Reference(name: Localization(english: "Array", japanese: "配列"))
    }
}

final class ArrayView<T: Referenceable & ViewExpression & Copiable>: View {
    var array = [T]()
    
    init(children: [Layer] = [], frame: CGRect = CGRect()) {
        super.init()
        isClipped = true
        self.frame = frame
        replace(children: children)
    }
    
    func copiedObjects(with event: KeyInputEvent) -> [ViewExpression]? {
        return array
    }
    
    func reference(with event: TapEvent) -> Reference? {
        return array.reference
    }
}

/**
 # Issue
 - ツリー操作が複雑
 */
final class ListArrayView: View {
    private let nameLineLayer: PathLayer = {
        let lineLayer = PathLayer()
        lineLayer.fillColor = .subContent
        return lineLayer
    } ()
    private let knobLineLayer: PathLayer = {
        let lineLayer = PathLayer()
        lineLayer.fillColor = .content
        return lineLayer
    } ()
    private let knob = DiscreteKnob(CGSize(width: 8, height: 8), lineWidth: 1)
    private var nameViews = [TextView](), treeLevelTextViews = [TextView]()
    func set(selectedIndex: Int, count: Int) {
        let isUpdate = self.selectedIndex != selectedIndex || self.count != count
        self.selectedIndex = selectedIndex
        self.count = count
        if isUpdate {
            knob.isHidden = count <= 1
            updateLayout()
        }
    }
    private(set) var selectedIndex = 0
    private(set) var count = 0
    var nameClosure: ((Int) -> (Localization))? {
        didSet {
            updateLayout()
        }
    }
    var treeLevelClosure: ((Int) -> (Int))?
    private let knobPaddingWidth = 16.0.cf
    
    override init() {
        super.init()
        isClipped = true
        updateLayout()
    }
    
    private let indexHeight = Layout.basicHeight - Layout.basicPadding * 2
    
    func flootIndex(atY y: CGFloat) -> CGFloat {
        let selectedY = bounds.midY - indexHeight / 2
        return (y - selectedY) / indexHeight + selectedIndex.cf
    }
    func index(atY y: CGFloat) -> Int {
        return Int(flootIndex(atY: y))
    }
    func y(at index: Int) -> CGFloat {
        let selectedY = bounds.midY - indexHeight / 2
        return CGFloat(index - selectedIndex) * indexHeight + selectedY
    }
    
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    
    func updateLayout() {
        guard selectedIndex < count, count > 0, let nameClosure = nameClosure else {
            return
        }
        let minI = Int(floor(flootIndex(atY: bounds.minY)))
        let minIndex = max(minI, 0)
        let maxI = Int(floor(flootIndex(atY: bounds.maxY)))
        let maxIndex = min(maxI, count - 1)
        let knobLineX = knobPaddingWidth / 2
        
        let nameLinePath = CGMutablePath(), llh = 1.0.cf
        (minIndex - 1...maxIndex + 1).forEach {
            nameLinePath.addRect(CGRect(x: 0, y: y(at: $0) - llh / 2,
                                        width: bounds.width, height: llh))
        }
        
        let knobLinePath = CGMutablePath(), lw = 2.0.cf
        let knobLineMinY = max(y(at: 0) + (selectedIndex > 0 ? -indexHeight : indexHeight / 2),
                               bounds.minY)
        let knobLineMaxY = min(y(at: maxIndex)
            + (selectedIndex < count - 1 ? indexHeight : indexHeight / 2),
                               bounds.maxY)
        knobLinePath.addRect(CGRect(x: knobLineX - lw / 2, y: knobLineMinY,
                                    width: lw, height: knobLineMaxY - knobLineMinY))
        let linePointMinIndex = minI < 0 ? minIndex + 1 : minIndex
        if linePointMinIndex <= maxIndex {
            (linePointMinIndex...maxIndex).forEach {
                knobLinePath.addRect(CGRect(x: knobPaddingWidth / 2 - 2,
                                            y: y(at: $0) - 2,
                                            width: 4,
                                            height: 4))
            }
        }
        
        let padding = treeLevelClosure != nil ? 12.0.cf : 0.0.cf
        nameViews = (minIndex...maxIndex).map {
            let nameView = TextView(text: nameClosure($0))
            nameView.fillColor = nil
            nameView.frame.origin = CGPoint(x: knobPaddingWidth + padding, y: y(at: $0))
            return nameView
        }
        
        if let treeLevelClosure = treeLevelClosure {
            treeLevelTextViews = (minIndex...maxIndex).map {
                let treeLevelTextView = TextView(text: Localization("\(treeLevelClosure($0))"))
                treeLevelTextView.fillColor = nil
                treeLevelTextView.frame.origin = CGPoint(x: knobPaddingWidth, y: y(at: $0))
                knobLinePath.addRect(CGRect(x: knobPaddingWidth / 2 - 2,
                                            y: treeLevelTextView.frame.midY - 2,
                                            width: 4,
                                            height: 4))
                return treeLevelTextView
            }
        } else {
            treeLevelTextViews = []
        }
        
        nameLineLayer.path = nameLinePath
        knobLineLayer.path = knobLinePath
        
        knob.position = CGPoint(x: knobLineX, y: bounds.midY)
        
        replace(children: [nameLineLayer, knobLineLayer, knob]
            + treeLevelTextViews as [Layer] + nameViews as [Layer])
    }
    
    var deleteClosure: ((ListArrayView, KeyInputEvent) -> (Bool))?
    func delete(with event: KeyInputEvent) -> Bool {
        return deleteClosure?(self, event) ?? false
    }
    var copiedObjectsClosure: ((ListArrayView, KeyInputEvent) -> ([ViewExpression]))?
    func copiedObjects(with event: KeyInputEvent) -> [ViewExpression]? {
        return copiedObjectsClosure?(self, event)
    }
    var pasteClosure: ((ListArrayView, [Any], KeyInputEvent) -> (Bool))?
    func paste(_ objects: [Any], with event: KeyInputEvent) -> Bool {
        return pasteClosure?(self, objects, event) ?? false
    }
    var newClosure: ((ListArrayView, KeyInputEvent) -> (Bool))?
    func new(with event: KeyInputEvent) -> Bool {
        return newClosure?(self, event) ?? false
    }
    
    var moveClosure: ((ListArrayView, DragEvent) -> (Bool))?
    func move(with event: DragEvent) -> Bool {
        return moveClosure?(self, event) ?? false
    }
}
