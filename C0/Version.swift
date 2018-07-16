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

final class Version: UndoManager {
    var disabledUndoRegistrationKeys = [String]()
    private(set) var undoedIndex = 0, index = 0
    var undoedDiffCount: Int {
        return undoedIndex - index
    }
    var indexNotification: ((Version, Int) -> ())?
    var undoedIndexNotification: ((Version, Int) -> ())?
    
    private var undoGroupToken: NSObjectProtocol?
    private var undoToken: NSObjectProtocol?, redoToken: NSObjectProtocol?
    override init() {
        super.init()
        updateNotifications()
    }
    
    func updateNotifications() {
        let nc = NotificationCenter.default
        removeNotification()
        let undoGroupClosure: (Notification) -> () = { [unowned self] in
            if !self.disabledUndoRegistrationKeys.isEmpty {
                self.disabledUndoRegistrationKeys = []
            }
            if let undoManager = $0.object as? UndoManager, undoManager == self {
                if undoManager.groupingLevel == 0 {
                    self.undoedIndex += 1
                    self.index = self.undoedIndex
                    self.indexNotification?(self, self.index)
                    self.undoedIndexNotification?(self, self.undoedIndex)
                }
            }
        }
        undoGroupToken = nc.addObserver(forName: .NSUndoManagerDidCloseUndoGroup,
                                        object: self, queue: nil, using: undoGroupClosure)
        
        let undoClosure: (Notification) -> () = { [unowned self] in
            if let undoManager = $0.object as? UndoManager, undoManager == self {
                self.undoedIndex -= 1
                self.undoedIndexNotification?(self, self.undoedIndex)
            }
        }
        undoToken = nc.addObserver(forName: .NSUndoManagerDidUndoChange,
                                   object: self, queue: nil, using: undoClosure)
        
        let redoClosure: (Notification) -> () = { [unowned self] in
            if let undoManager = $0.object as? UndoManager, undoManager == self {
                self.undoedIndex += 1
                self.undoedIndexNotification?(self, self.undoedIndex)
            }
        }
        redoToken = nc.addObserver(forName: .NSUndoManagerDidRedoChange,
                                   object: self, queue: nil, using: redoClosure)
    }
    
    deinit {
        removeNotification()
    }
    func removeNotification() {
        if let token = undoGroupToken {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = undoToken {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = redoToken {
            NotificationCenter.default.removeObserver(token)
        }
    }
}
extension Version: Codable {
    convenience init(from decoder: Decoder) throws {
        self.init()
        updateNotifications()
    }
    func encode(to encoder: Encoder) throws {}
}
