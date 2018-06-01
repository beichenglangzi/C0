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
extension Version: Referenceable {
    static let name = Text(english: "Version", japanese: "バージョン")
}
extension Version: Codable {
    convenience init(from decoder: Decoder) throws {
        self.init()
        updateNotifications()
    }
    func encode(to encoder: Encoder) throws {}
}

/**
 Issue: バージョン管理
 Issue: ブランチ機能
 */
final class VersionView<T: BinderProtocol>: View, BindableReceiver {
    typealias Model = Version
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((VersionView<Binder>, BasicNotification) -> ())]()
    
    let indexView: IntGetterView<Binder>
    let undoedDiffCountView: IntGetterView<Binder>
    
    var sizeType: SizeType {
        didSet { updateLayout() }
    }
    let classNameView: TextFormView
    
    init(binder: Binder, keyPath: BinderKeyPath,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        self.sizeType = sizeType
        classNameView = TextFormView(text: Version.name, font: Font.bold(with: sizeType))
        indexView = IntGetterView(binder: binder,
                                  keyPath: keyPath.appending(path: \Model.index),
                                  option: IntGetterOption(unit: ""), sizeType: sizeType)
        undoedDiffCountView = IntGetterView(binder: binder,
                                            keyPath: keyPath.appending(path: \Model.undoedDiffCount),
                                            option: IntGetterOption(unit: ""), sizeType: sizeType)
        
        super.init()
        isClipped = true
        children = [classNameView, indexView]
        self.frame = frame
        updateWithModel()
    }
    
    override var defaultBounds: Rect {
        return Rect(x: 0, y: 0, width: 120, height: Layout.height(with: sizeType))
    }
    override func updateLayout() {
        let padding = Layout.padding(with: sizeType)
        classNameView.frame.origin = Point(x: padding,
                                           y: bounds.height - classNameView.frame.height - padding)
        let items: [Layout.Item] = model.undoedIndex < model.index ?
            [.view(indexView), .xPadding(padding), .view(undoedDiffCountView)] :
            [.view(indexView)]
        _ = Layout.leftAlignment(items, minX: classNameView.frame.maxX + padding,
                                 height: frame.height)
    }
    func updateWithModel() {
        model.indexNotification = { [unowned self] _, _ in self.updateWithVersionIndex() }
        model.undoedIndexNotification = { [unowned self] _, _ in self.updateWithVersionIndex() }
        updateWithVersionIndex()
    }
    private func updateWithVersionIndex() {
        if model.undoedIndex < model.index {
            indexView.updateWithModel()
            undoedDiffCountView.updateWithModel()
            indexView.bounds = indexView.optionStringView.defaultBounds
            undoedDiffCountView.bounds = undoedDiffCountView.optionStringView.defaultBounds
            undoedDiffCountView.optionStringView.textMaterial.color = .warning
            if undoedDiffCountView.parent == nil {
                children = [classNameView, indexView, undoedDiffCountView]
            }
        } else {
            indexView.updateWithModel()
            if undoedDiffCountView.parent != nil {
                children = [classNameView, indexView]
            }
        }
        updateLayout()
    }
}
extension VersionView: Localizable {
    func update(with locale: Locale) {
        updateLayout()
    }
}
