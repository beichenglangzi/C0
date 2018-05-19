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

import struct Foundation.IndexPath

protocol TreeNode: Sequence {
    var children: [Self] { get set }
    subscript(indexPath: IndexPath) -> Self { get set }
}
extension TreeNode {
    typealias Index = TreeIndex<Self>
    
    subscript(indexPath: IndexPath) -> Self {
        get {
            return at(indexPath: indexPath, at: 0)
        }
        set {
            self[keyPath: Self.keyPath(with: indexPath)] = newValue
        }
    }
    func at(indexPath: IndexPath, at i: Int) -> Self {
        let index = indexPath[i]
        let child = children[index]
        return child.at(indexPath: indexPath, at: i + 1)
    }
    
    static func keyPath(with indexPath: IndexPath) -> WritableKeyPath<Self, Self> {
        var indexPath = indexPath
        let keyPath: WritableKeyPath<Self, Self> = \Self.children[indexPath[0]]
        indexPath.removeFirst()
        return indexPath.reduce(keyPath) { $0.appending(path: \Self.children[indexPath[$1]]) }
    }
    
    var allCount: Int {
        return children.reduce(0) { $0 + $1.allCount } + children.count
    }
    
    func makeIterator() -> TreeNodeIterator<Self> {
        return TreeNodeIterator(rootNode: self)
    }
}

struct TreeNodeIterator<T: TreeNode>: IteratorProtocol {
    typealias Element = T
    
    init(rootNode: T) {
        parentIndexes = [(rootNode, 0)]
    }
    
    private var parentIndexes = [(parent: T, index: Int)]()
    mutating func next() -> T? {
        guard let lastParentIndex = parentIndexes.last else {
            return nil
        }
        if lastParentIndex.index >= lastParentIndex.parent.children.count {
            parentIndexes.removeLast()
            return lastParentIndex.parent
        } else {
            let child = lastParentIndex.parent.children[lastParentIndex.index]
            if child.children.isEmpty {
                parentIndexes[parentIndexes.count - 1].index += 1
                return child
            } else {
                var aParent = child
                repeat {
                    parentIndexes.append((aParent, 0))
                    aParent = aParent.children[0]
                } while !aParent.children.isEmpty
                parentIndexes[parentIndexes.count - 1].index += 1
                return aParent
            }
        }
    }
}

struct TreeIndexIterator<T: TreeNode>: IteratorProtocol {
    typealias Element = TreeIndex<T>
    
    init(rootNode: T) {
        parentIndexes = [(rootNode, 0)]
    }
    
    private var parentIndexes = [(parent: T, index: Int)]()
    mutating func next() -> Element? {
        guard let lastParentIndex = parentIndexes.last else {
            return nil
        }
        if lastParentIndex.index >= lastParentIndex.parent.children.count {
            parentIndexes.removeLast()
            return lastParentIndex.parent
        } else {
            let child = lastParentIndex.parent.children[lastParentIndex.index]
            if child.children.isEmpty {
                parentIndexes[parentIndexes.count - 1].index += 1
                return child
            } else {
                var aParent = child
                repeat {
                    parentIndexes.append((aParent, 0))
                    aParent = aParent.children[0]
                } while !aParent.children.isEmpty
                parentIndexes[parentIndexes.count - 1].index += 1
                return aParent
            }
        }
    }
}

extension TreeNode where Element: Namable {
    var unduplicatedIndexName: Text {
        var minIndex: Int?
        for node in self {
            guard let i = node.name.suffixNumber else { continue }
            if let minI = minIndex {
                if i > minI {
                    minIndex = i
                }
            } else {
                minIndex = 0
            }
        }
        let index = minIndex != nil ? minIndex! + 1 : 0
        return Text("\(index)")
    }
}

struct TreeReference<T> {
    var value: T
    var treeIndex: TreeIndex<T>
    init(_ value: T, _ treeIndex: TreeIndex<T>) {
        self.value = value
        self.treeIndex = treeIndex
    }
    
    func reversed() -> TreeReference<T> {
        return TreeReference(value, treeIndex.reversed())
    }
}
struct TreeIndex<T>: Codable, Hashable {
    var indexPath = IndexPath()
    
    func reversed() -> TreeIndex<T> {
        return TreeIndex(indexPath: IndexPath(indexes: indexPath.reversed()))
    }
    var removedFirst: TreeIndex<Cell> {
        var indexPath = self.indexPath
        _ = indexPath.removeFirst()
        return TreeIndex<Cell>(indexPath: indexPath)
    }
}
extension TreeNode {
    subscript(treeIndex: TreeIndex<Self>) -> Self {
        get {
            return self[treeIndex.indexPath]
        }
        set {
            self[treeIndex.indexPath] = newValue
        }
    }
    
    func nodes(at treeIndex: TreeIndex<Self>) -> [Self] {
        var nodes = [Self]()
        nodes.reserveCapacity(treeIndex.indexPath.count)
        self.nodes(at: treeIndex, index: 0, nodes: &nodes)
        return nodes
    }
    private func nodes(at treeIndex: TreeIndex<Self>, index: Int, nodes: inout [Self]) {
        nodes.append(children[treeIndex.indexPath[index]])
        let newIndex = index + 1
        if newIndex < treeIndex.indexPath.count {
            self.nodes(at: treeIndex, index: newIndex, nodes: &nodes)
        }
    }
    
    func sortedIndexes(_ indexes: [Index]) -> [Index] {
        var sortedIndexes = [Index]()
        for (i, node) in self {
            if indexes.contains(Index(indexPath: i)) {
                sortedIndexes.append(i)
            }
        }
        return sortedIndexes
    }
}
