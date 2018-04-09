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

typealias Version = UndoManager

extension Version: Referenceable {
    static let name = Localization(english: "Version", japanese: "バージョン")
}

/**
 # Issue
 - Versionクラス
 - バージョン管理UndoManager
 - ブランチ機能
 */
final class VersionView: View {
    var version = Version() {
        didSet {
            removeNotification()
            let nc = NotificationCenter.default
            
            undoGroupToken = nc.addObserver(forName: .NSUndoManagerDidCloseUndoGroup,
                                            object: version, queue: nil) { [unowned self] in
                if let undoManager = $0.object as? UndoManager, undoManager == self.version {
                    if undoManager.groupingLevel == 0 {
                        self.undoCount += 1
                        self.allCount = self.undoCount
                        self.updateLabel()
                    }
                }
            }
            
            undoToken = nc.addObserver(forName: .NSUndoManagerDidUndoChange,
                                       object: version, queue: nil) { [unowned self] in
                if let undoManager = $0.object as? UndoManager, undoManager == self.version {
                    self.undoCount -= 1
                    self.updateLabel()
                }
            }
            
            redoToken = nc.addObserver(forName: .NSUndoManagerDidRedoChange,
                                       object: version, queue: nil) { [unowned self] in
                if let undoManager = $0.object as? UndoManager, undoManager == self.version {
                    self.undoCount += 1
                    self.updateLabel()
                }
            }
            
            updateLabel()
        }
    }
    private var undoGroupToken: NSObjectProtocol?
    private var undoToken: NSObjectProtocol?, redoToken: NSObjectProtocol?
    override var undoManager: UndoManager? {
        return version
    }
    
    override var locale: Locale {
        didSet {
            updateLayout()
        }
    }
    
    var undoCount = 0, allCount = 0
    
    let classNameLabel = Label(text: Version.name, font: .bold)
    let allCountLabel = Label(text: Localization("0"))
    let currentCountLabel = Label(color: .warning)
    
    override init() {
        _ = Layout.leftAlignment([classNameLabel, Padding(), allCountLabel],
                                 height: Layout.basicHeight)
        super.init()
        isClipped = true
        replace(children: [classNameLabel, allCountLabel])
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
    
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    func updateLayout() {
        let padding = Layout.basicPadding
        classNameLabel.frame.origin = CGPoint(x: padding,
                                              y: bounds.height - classNameLabel.frame.height - padding)
        if undoCount < allCount {
            _ = Layout.leftAlignment([allCountLabel, Padding(), currentCountLabel],
                                     minX: classNameLabel.frame.maxX + padding, height: frame.height)
        } else {
            _ = Layout.leftAlignment([allCountLabel],
                                     minX: classNameLabel.frame.maxX + padding, height: frame.height)
        }
    }
    func updateLabel() {
        if undoCount < allCount {
            allCountLabel.localization = Localization("\(allCount)")
            currentCountLabel.localization = Localization("\(undoCount - allCount)")
            if currentCountLabel.parent == nil {
                replace(children: [classNameLabel, allCountLabel, currentCountLabel])
                updateLayout()
            }
        } else {
            allCountLabel.localization = Localization("\(allCount)")
            if currentCountLabel.parent != nil {
                replace(children: [classNameLabel, allCountLabel])
                updateLayout()
            }
        }
    }
    
    func reference(with event: TapEvent) -> Reference? {
        var reference = version.reference
        reference.classDescription += Localization("\n\n")
            + Localization(english: "Show undoable count and undoed count in parent view",
                           japanese: "親表示での取り消し可能回数、取り消し済み回数を表示")
        return reference
    }
}
