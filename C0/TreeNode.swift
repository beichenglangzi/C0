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

struct TreeIndex<T>: Codable, Hashable {
    var indexPath = IndexPath()
    
    func reversed() -> TreeIndex<T> {
        return TreeIndex(indexPath: IndexPath(indexes: indexPath.reversed()))
    }
    var removedFirst: TreeIndex<Membrane> {
        var indexPath = self.indexPath
        _ = indexPath.removeFirst()
        return TreeIndex<Membrane>(indexPath: indexPath)
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

protocol TreeNode: Sequence {
    var children: [Self] { get set }
    subscript(indexPath: IndexPath) -> Self { get set }
}
extension TreeNode {
    typealias Index = TreeIndex<Self>
    
    subscript(indexPath: IndexPath) -> Self {
        get { return at(indexPath: indexPath, at: 0) }
        set { self[keyPath: Self.keyPath(with: indexPath)] = newValue }
    }
    func at(indexPath: IndexPath, at i: Int) -> Self {
        guard i < indexPath.count else {
            return self
        }
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
    
    func makeIterator() -> TreeNodeIterator<Self> {
        return TreeNodeIterator(rootNode: self)
    }
    func treeIndexEnumerated() -> TreeIndexSequence<Self> {
        return TreeIndexSequence(rootNode: self)
    }
    
    subscript(treeIndex: Index) -> Self {
        get { return self[treeIndex.indexPath] }
        set { self[treeIndex.indexPath] = newValue }
    }
    
    func nodes(at treeIndex: Index) -> [Self] {
        guard !treeIndex.indexPath.isEmpty else { return [self] }
        var nodes = [Self]()
        nodes.reserveCapacity(treeIndex.indexPath.count)
        self.nodes(at: treeIndex, index: 0, nodes: &nodes)
        return nodes
    }
    private func nodes(at treeIndex: Index, index: Int, nodes: inout [Self]) {
        nodes.append(children[treeIndex.indexPath[index]])
        let newIndex = index + 1
        if newIndex < treeIndex.indexPath.count {
            self.nodes(at: treeIndex, index: newIndex, nodes: &nodes)
        }
    }
    
    func sortedIndexes(_ indexes: [Index]) -> [Index] {
        var sortedIndexes = [Index]()
        for (i, _) in treeIndexEnumerated() {
            if indexes.contains(i) {
                sortedIndexes.append(i)
            }
        }
        return sortedIndexes
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

struct TreeNodeIterator<T: TreeNode>: IteratorProtocol {
    typealias Element = T
    
    init(rootNode: T) {
        nodeIndexes = [(rootNode, 0)]
    }
    
    private var nodeIndexes = [(node: T, index: Int)]()
    mutating func next() -> T? {
        guard let lastNodeIndex = nodeIndexes.last else {
            return nil
        }
        if lastNodeIndex.index >= lastNodeIndex.node.children.count {
            nodeIndexes.removeLast()
            if !nodeIndexes.isEmpty {
                nodeIndexes[nodeIndexes.count - 1].index += 1
            }
            return lastNodeIndex.node
        } else {
            let child = lastNodeIndex.node.children[lastNodeIndex.index]
            if child.children.isEmpty {
                nodeIndexes[nodeIndexes.count - 1].index += 1
                return child
            } else {
                var aNode = child
                repeat {
                    nodeIndexes.append((aNode, 0))
                    aNode = aNode.children[0]
                } while !aNode.children.isEmpty
                nodeIndexes[nodeIndexes.count - 1].index += 1
                return aNode
            }
        }
    }
}

struct TreeIndexSequence<T: TreeNode>: Sequence, IteratorProtocol {
    typealias Element = (T.Index, T)
    
    init(rootNode: T) {
        nodes = [rootNode]
        indexPath = IndexPath(index: 0)
    }
    
    private var indexPath: IndexPath, nodes: [T]
    mutating func next() -> Element? {
        guard let lastNodeIndex = indexPath.last, let node = nodes.last else {
            return nil
        }
        if lastNodeIndex >= node.children.count {
            indexPath.removeLast()
            nodes.removeLast()
            let oldIndexPath = indexPath
            if !indexPath.isEmpty {
                indexPath[indexPath.count - 1] += 1
            }
            return (T.Index(indexPath: oldIndexPath), node)
        } else {
            let child = node.children[lastNodeIndex]
            if child.children.isEmpty {
                let oldIndexPath = indexPath
                indexPath[indexPath.count - 1] += 1
                return (T.Index(indexPath: oldIndexPath), child)
            } else {
                var aNode = child
                repeat {
                    indexPath.append(0)
                    nodes.append(aNode)
                    aNode = aNode.children[0]
                } while !aNode.children.isEmpty
                let oldIndexPath = indexPath
                indexPath[indexPath.count - 1] += 1
                return (T.Index(indexPath: oldIndexPath), aNode)
            }
        }
    }
}
