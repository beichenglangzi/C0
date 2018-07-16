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

extension URL {
    init?(bookmark: Data?) {
        guard let bookmark = bookmark else {
            return nil
        }
        do {
            var bds = false
            guard let url = try URL(resolvingBookmarkData: bookmark,
                                    bookmarkDataIsStale: &bds) else {
                return nil
            }
            self = url
        } catch {
            return nil
        }
    }
    var type: String? {
        let resourceValues = try? self.resourceValues(forKeys: Set([.typeIdentifierKey]))
        return resourceValues?.typeIdentifier
    }
}

protocol URLEncodable {
    func write(to url: URL,
               progressClosure: @escaping (Real, inout Bool) -> (),
               completionClosure: @escaping (Error?) -> ()) throws
}

final class URLEncoder<T: URLEncodable> {
    var encodable: T
    var operation: Operation?
    var progress: Progress?
    
    init(encodable: T) {
        self.encodable = encodable
    }
    
    func write(to e: URL.File) -> BlockOperation {
        let name = Localization(e.url.deletingPathExtension().lastPathComponent)
        let type = Localization(e.url.pathExtension.uppercased())
        
        func completedUnitCount(withTotalProgress value: Real) -> Int64 {
            return Int64(value * 100)
        }
        
        let progressKind = Progress.FileOperationKind.receiving
        let progressUserInfo: [ProgressUserInfoKey: Any] = [.fileOperationKindKey: progressKind,
                                                            .fileURLKey: e.url]
        let progress = Progress(parent: nil, userInfo: progressUserInfo)
        progress.isCancellable = true
        progress.kind = .file
        progress.totalUnitCount = 100
        progress.cancellationHandler = {
            self.stop()
        }
        progress.publish()
        self.progress = progress
        
        let operation = BlockOperation()
        operation.addExecutionBlock() { [unowned operation, unowned self] in
            do {
                let progressClosure: (Real, inout Bool) -> () = { (totalProgress, stop) in
                    if operation.isCancelled {
                        stop = true
                    } else {
                        OperationQueue.main.addOperation() {
                            progress.completedUnitCount
                                = completedUnitCount(withTotalProgress: totalProgress)
                        }
                    }
                }
                let completionClosure: (Error?) -> () = { error in
                    do {
                        if let error = error {
                            throw error
                        }
                        OperationQueue.main.addOperation() {
                            progress.completedUnitCount = 100
                        }
                        try FileManager.default.setAttributes(e.attributes,
                                                              ofItemAtPath: e.url.path)
                        OperationQueue.main.addOperation() {
                            self.endedClosure?(self)
                        }
                    } catch {
                        OperationQueue.main.addOperation() {
                            progress.cancel()
                        }
                    }
                    self.operation = nil
                    self.progress = nil
                }
                try self.encodable.write(to: e.url,
                                         progressClosure: progressClosure,
                                         completionClosure: completionClosure)
            } catch {
                OperationQueue.main.addOperation() {
                    self.progress?.cancel()
                    self.operation = nil
                    self.progress = nil
                }
            }
        }
        self.operation = operation
        return operation
    }
    
    var endedClosure: ((URLEncoder) -> ())?
    
    var stoppedClosure: ((URLEncoder) -> ())?
    func stop() {
        if let operation = operation, !operation.isCancelled {
            operation.cancel()
            stoppedClosure?(self)
        }
    }
}
