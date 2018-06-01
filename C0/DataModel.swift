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

import struct Foundation.Data
import class Foundation.ByteCountFormatter
import class Foundation.FileWrapper
import class Foundation.JSONDecoder
import class Foundation.JSONEncoder

extension Data {
    var bytesString: String {
        return ByteCountFormatter().string(fromByteCount: Int64(count))
    }
}
extension Data: Referenceable {
    static let name = Text(english: "Data", japanese: "データ")
}

extension Decodable {
    init?(jsonData: Data) {
        if let obj = try? JSONDecoder().decode(Self.self, from: jsonData) {
            self = obj
        } else {
            return nil
        }
    }
    init?(jsonString: String) {
        guard let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }
        self.init(jsonData: jsonData)
    }
}
extension Decodable {
    static func decode<Key>(values: KeyedDecodingContainer<Key>,
                            forKey key: Key) throws -> Self where Key: CodingKey {
        return try values.decode(Self.self, forKey: key)
    }
}

extension Encodable {
    var jsonData: Data? {
        return try? JSONEncoder().encode(self)
    }
    var jsonString: String? {
        guard let data = try? JSONEncoder().encode(self) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
extension Encodable {
    func encode<CodingKeys>(forKey key: KeyedEncodingContainer<CodingKeys>.Key,
                            in container: inout KeyedEncodingContainer<CodingKeys>) throws
        where CodingKeys: CodingKey {
            try container.encode(self, forKey: key)
    }
}

final class DataModel {
    let key: String, isDirectory: Bool
    var fileWrapper: FileWrapper
    
    init(key: String) {
        self.key = key
        fileWrapper = FileWrapper()
        fileWrapper.preferredFilename = key
        isDirectory = false
        children = [:]
    }
    init(key: String, directoryWith dataModels: [DataModel]) {
        self.key = key
        let fws = dataModels.reduce(into: [String: FileWrapper]()) { $0[$1.key] = $1.fileWrapper }
        fileWrapper = FileWrapper(directoryWithFileWrappers: fws)
        isDirectory = true
        children = dataModels.reduce(into: [String: DataModel]()) { $0[$1.key] = $1 }
        children.forEach { $0.value.parent = self }
    }
    init(key: String, fileWrapper: FileWrapper) {
        self.key = key
        self.fileWrapper = fileWrapper
        guard fileWrapper.isDirectory else {
            isDirectory = false
            children = [:]
            return
        }
        isDirectory = true
        guard let fileWrappers = fileWrapper.fileWrappers else {
            children = [:]
            return
        }
        children = fileWrappers.reduce(into: [String: DataModel]()) {
            $0[$1.key] = DataModel(key: $1.key, fileWrapper: $1.value)
        }
        children.forEach { $0.value.parent = self }
    }
    
    private(set) weak var parent: DataModel?
    private(set) var children: [String: DataModel]
    
    var noDuplicateChildrenKey: String {
        return fileWrapper.fileWrappers?.keys.max() ?? "0"
    }
    func set(_ dataModels: [DataModel]) {
        guard isDirectory else { fatalError() }
        guard !dataModels.isEmpty else {
            children.forEach { $0.value.parent = nil }
            children = [:]
            return
        }
        let fws = dataModels.reduce(into: [String: FileWrapper]()) { $0[$1.key] = $1.fileWrapper }
        fileWrapper = FileWrapper(directoryWithFileWrappers: fws)
        children = dataModels.reduce(into: [String: DataModel]()) { $0[$1.key] = $1 }
        children.forEach { $0.value.parent = self }
    }
    func insert(_ dataModel: DataModel) {
        guard isDirectory && children[dataModel.key] == nil else { fatalError() }
        dataModel.fileWrapper.preferredFilename = dataModel.key
        fileWrapper.addFileWrapper(dataModel.fileWrapper)
        children[dataModel.key] = dataModel
        dataModel.parent = self
    }
    func remove(_ dataModel: DataModel) {
        guard isDirectory && children[dataModel.key] != nil else { fatalError() }
        fileWrapper.removeFileWrapper(dataModel.fileWrapper)
        dataModel.parent = nil
        children[dataModel.key] = nil
    }
    
    private(set) var isRead = false
    private var object: Any?
    func readObject<T: Decodable>(_ type: T.Type) -> T? {
        guard !isRead else {
            return object as? T
        }
        if let data = fileWrapper.regularFileContents, let object = T(jsonData: data) {
            isRead = true
            self.object = object
            return object
        }
        return nil
    }
    
    private(set) var isStopIsWrite = false
    func stopIsWriteClosure(_ closure: () -> ()) {
        isStopIsWrite = true
        closure()
        isStopIsWrite = false
    }
    
    var didChangeIsWriteClosure: ((DataModel, Bool) -> Void)? = nil
    private var _isWrite = false
    var isWrite: Bool {
        get { return _isWrite }
        set {
            if newValue != _isWrite && !isStopIsWrite {
                _isWrite = newValue
                didChangeIsWriteClosure?(self, newValue)
            }
        }
    }
    var dataClosure: () -> Data? = { nil }
    func writeAllFileWrappers() {
        write()
        children.forEach { $0.value.writeAllFileWrappers() }
    }
    func write() {
        guard isWrite else { return }
        if let data = dataClosure(), let parentFileWrapper = parent?.fileWrapper {
            parentFileWrapper.removeFileWrapper(fileWrapper)
            fileWrapper = FileWrapper(regularFileWithContents: data)
            fileWrapper.preferredFilename = key
            parentFileWrapper.addFileWrapper(fileWrapper)
        }
        isWrite = false
    }
}
