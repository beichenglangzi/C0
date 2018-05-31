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

import Foundation

struct Desktop {
    var copiedObjects = [Object]()
    var isHiddenActionManager = false
    let actionManager = ActionManager()
    var objects = [Object]()
    var version = Version()
}
extension Desktop: Codable {
    private enum CodingKeys: String, CodingKey {
        case copiedObjects, isHiddenActionManager, objects, version
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        copiedObjects = try values.decode([Object].self, forKey: .copiedObjects)
        isHiddenActionManager = try values.decode(Bool.self, forKey: .isHiddenActionManager)
        objects = try values.decode([Object].self, forKey: .objects)
        version = try values.decode(Version.self, forKey: .version)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(copiedObjects, forKey: .copiedObjects)
        try container.encode(isHiddenActionManager, forKey: .isHiddenActionManager)
        try container.encode(objects, forKey: .objects)
        try container.encode(version, forKey: .version)
    }
}
extension Desktop: Referenceable {
    static let name = Text(english: "Desktop", japanese: "デスクトップ")
}
extension Desktop {
    static let isHiddenActionManagerOption = BoolOption(defaultModel: false, cationModel: nil,
                                                        name: ActionManager.name,
                                                        info: .hidden)
    static let copiedObjectsInferenceName = Text(english: "Copied", japanese: "コピー済み")
}

final class DesktopBinder: BinderProtocol {
    var rootModel: Desktop {
        didSet {
            diffDesktopDataModel.isWrite = true
        }
    }
    
    init(rootModel: Desktop) {
        self.rootModel = rootModel
        
        diffDesktopDataModel = DataModel(key: diffDesktopDataModelKey)
        objectsDataModel = DataModel(key: objectsDataModelKey, directoryWith: [])
        dataModel = DataModel(key: dataModelKey,
                              directoryWith: [diffDesktopDataModel, objectsDataModel])

        diffDesktopDataModel.dataClosure = { [unowned self] in self.rootModel.jsonData }
    }
    
    let dataModelKey = "desktop"
    var dataModel: DataModel {
        didSet {
            if let objectsDataModel = dataModel.children[objectsDataModelKey] {
                self.objectsDataModel = objectsDataModel
            } else {
                dataModel.insert(objectsDataModel)
            }

            if let dDesktopDataModel = dataModel.children[diffDesktopDataModelKey] {
                self.diffDesktopDataModel = dDesktopDataModel
            } else {
                dataModel.insert(diffDesktopDataModel)
            }
        }
    }
    
    let diffDesktopDataModelKey = "diffDesktop"
    var diffDesktopDataModel: DataModel {
        didSet {
            if let desktop = diffDesktopDataModel.readObject(Desktop.self) {
                self.rootModel = desktop
            }
            diffDesktopDataModel.dataClosure = { [unowned self] in self.rootModel.jsonData }
        }
    }
    
    let objectsDataModelKey = "objects"
    var objectsDataModel: DataModel
}

/**
 Issue: sceneViewを取り除く
 */
final class DesktopView<T: BinderProtocol>: View, BindableReceiver {
    typealias Model = Desktop
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((DesktopView<Binder>, BasicNotification) -> ())]()

    let versionView: VersionView<Binder>
    let copiedObjectsNameView = TextFormView(text: Desktop.copiedObjectsInferenceName + ":")
    let copiedObjectsView: ObjectsView<Binder>
    let isHiddenActionManagerView: BoolView<Binder>
    let objectsView: ObjectsView<Binder>
    let actionManagerView: ActionManagerView<Binder>

    var versionWidth = 150.0.cg
    var topViewsHeight = Layout.basicHeight {
        didSet { updateLayout() }
    }
    
    init(binder: Binder, keyPath: BinderKeyPath,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {

        self.binder = binder
        self.keyPath = keyPath
        
        let ihamKeyPath = keyPath.appending(path: \Model.isHiddenActionManager)
        isHiddenActionManagerView = BoolView(binder: binder, keyPath: ihamKeyPath,
                                             option: Model.isHiddenActionManagerOption,
                                             sizeType: sizeType)
        
        versionView = VersionView(binder: binder,
                                  keyPath: keyPath.appending(path: \Model.version),
                                  sizeType: sizeType)
        copiedObjectsView = ObjectsView(binder: binder,
                                        keyPath: keyPath.appending(path: \Model.copiedObjects),
                                        sizeType: .small, abstractType: .mini)
        objectsView = ObjectsView(binder: binder,
                                  keyPath: keyPath.appending(path: \Model.objects),
                                  sizeType: sizeType, abstractType: .normal)
        actionManagerView = ActionManagerView(binder: binder,
                                              keyPath: keyPath.appending(path: \Model.actionManager))
        actionManagerView.isHidden = binder[keyPath: keyPath].isHiddenActionManager
        print(actionManagerView.isHidden)
        super.init()
        fillColor = .background
        
        children = [versionView, copiedObjectsNameView, copiedObjectsView,
                    isHiddenActionManagerView, actionManagerView, objectsView]
        
        isHiddenActionManagerView.notifications.append({ [unowned self] _, _ in
            self.actionManagerView.isHidden = self.model.isHiddenActionManager
            self.updateLayout()
        })
    }

    var locale = Locale.current {
        didSet {
            if locale.languageCode != oldValue.languageCode {
                allChildrenAndSelf { ($0 as? Localizable)?.update(with: locale) }
            }
        }
    }
    
    override var contentsScale: Real {
        didSet {
            if contentsScale != oldValue {
                allChildrenAndSelf { $0.contentsScale = contentsScale }
            }
        }
    }
    override func updateLayout() {
        let padding = Layout.basicPadding
        let ihamvw = isHiddenActionManagerView.defaultBounds.width
        let headerY = bounds.height - topViewsHeight - padding
        versionView.frame = Rect(x: padding, y: headerY,
                                 width: versionWidth, height: topViewsHeight)
        copiedObjectsNameView.frame.origin = Point(x: versionView.frame.maxX + padding,
                                                   y: headerY + padding)
        let conw = copiedObjectsNameView.frame.width
        let actionWidth = actionManagerView.width
        let cw = max(bounds.width - versionWidth - ihamvw - conw - padding * 3,
                     0)
        copiedObjectsView.frame = Rect(x: copiedObjectsNameView.frame.maxX, y: headerY,
                                       width: cw, height: topViewsHeight)
        updateCopiedObjectViewPositions()
        isHiddenActionManagerView.frame = Rect(x: copiedObjectsView.frame.maxX, y: headerY,
                                               width: ihamvw, height: topViewsHeight)
        
        if model.isHiddenActionManager {
            objectsView.frame = Rect(x: padding,
                                     y: padding,
                                     width: bounds.width - padding * 2,
                                     height: bounds.height - topViewsHeight - padding * 2)
        } else {
            let ow = max(bounds.width - actionWidth - padding * 2,
                         0)
            let h = bounds.height - padding * 2 - topViewsHeight
            objectsView.frame = Rect(x: padding,
                                     y: padding,
                                     width: ow,
                                     height: bounds.height - topViewsHeight - padding * 2)
            actionManagerView.frame = Rect(x: padding + ow,
                                           y: padding,
                                           width: actionWidth,
                                           height: h)
        }
        objectsView.bounds.origin = Point(x: -round((objectsView.frame.width / 2)),
                                          y: -round((objectsView.frame.height / 2)))
    }
    func updateWithModel() {
        isHiddenActionManagerView.updateWithModel()
        if actionManagerView.isHidden != model.isHiddenActionManager {
            actionManagerView.isHidden = model.isHiddenActionManager
            updateLayout()
        }
    }

    var objectViewWidth = 80.0.cg
    private func updateCopiedObjectViews() {
        copiedObjectsView.updateWithModel()
        let padding = Layout.smallPadding
        let bounds = Rect(x: 0,
                          y: 0,
                          width: objectViewWidth,
                          height: copiedObjectsView.bounds.height - padding * 2)
        copiedObjectsView.updateWithModel()
        copiedObjectsView.children.forEach { $0.bounds = bounds }
        updateCopiedObjectViewPositions()
    }
    private func updateCopiedObjectViewPositions() {
        let padding = Layout.smallPadding
        _ = Layout.leftAlignment(copiedObjectsView.children.map { .view($0) },
                                 minX: padding, y: padding)
    }
}
extension DesktopView: Localizable {
    func update(with locale: Locale) {
        updateLayout()
    }
}
extension DesktopView: Undoable {
    var version: Version {
        return versionView.model
    }
}
extension DesktopView: CopiedObjectsViewer {
    var copiedObjects: [Object] {
        get { return copiedObjectsView.model }
        set { copiedObjectsView.model = newValue }
    }
    func push(_ copiedObjects: [Object], to version: Version) {
        copiedObjectsView.push(copiedObjects, to: version)
    }
}
