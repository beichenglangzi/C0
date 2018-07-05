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
extension Version: Viewable {
    func standardViewWith<T: BinderProtocol>
        (binder: T, keyPath: ReferenceWritableKeyPath<T, Version>) -> ModelView {
        
        return VersionView(binder: binder, keyPath: keyPath)
    }
}
extension Version: ObjectViewable {}

/**
 Issue: ブランチ機能
 */
final class VersionView<T: BinderProtocol>: ModelView, BindableReceiver {
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
    
    let classNameView: TextFormView
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        indexView = IntGetterView(binder: binder,
                                  keyPath: keyPath.appending(path: \Model.index),
                                  option: IntGetterOption(unit: ""))
        undoedDiffCountView = IntGetterView(binder: binder,
                                            keyPath: keyPath.appending(path: \Model.undoedDiffCount),
                                            option: IntGetterOption(unit: ""))
        
        classNameView = TextFormView(text: Version.name, font: .bold)
        
        super.init(isLocked: false)
        isClipped = true
        children = [classNameView, indexView]
        updateWithModel()
    }
    
    var baselinePadding = Layouter.basicPadding
    var minSize: Size {
        let cnms = classNameView.minSize
        let ims = indexView.minSize
        if model.undoedIndex < model.index {
            return Size(width: cnms.width + ims.width,
                        height: Layouter.basicTextHeight + baselinePadding * 2)
        } else {
            let udcms = undoedDiffCountView.minSize
            return Size(width: cnms.width + ims.width + udcms.width,
                        height: Layouter.basicTextHeight + baselinePadding * 2)
        }
    }
    override func updateLayout() {
        let padding = Layouter.basicPadding
        let classNameSize = classNameView.minSize
        let classNameOrigin = Point(x: padding, y: baselinePadding)
        classNameView.frame = Rect(origin: classNameOrigin, size: classNameSize)
        let items: [Layouter.Item] = model.undoedIndex < model.index ?
            [.view(indexView), .xPadding(padding), .view(undoedDiffCountView)] :
            [.view(indexView)]
        _ = Layouter.leftAlignment(items, minX: classNameView.frame.maxX + padding,
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
            indexView.bounds = Rect(origin: Point(), size: indexView.minSize)
            undoedDiffCountView.bounds = Rect(origin: Point(), size: undoedDiffCountView.minSize)
            undoedDiffCountView.optionStringView.textMaterial.color = .warning
            if !children.contains(undoedDiffCountView) {
                children = [classNameView, indexView, undoedDiffCountView]
            }
        } else {
            indexView.updateWithModel()
            indexView.bounds = Rect(origin: Point(), size: indexView.minSize)
            if children.contains(undoedDiffCountView) {
                children = [classNameView, indexView]
            }
        }
        updateLayout()
    }
    
    func clippedModel(_ model: Model) -> Model {
        return self.model
    }
}
