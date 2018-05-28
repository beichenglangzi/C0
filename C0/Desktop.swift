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

struct Desktop: Codable {
    var copiedObjects = [Object]()
    var isHiddenActionManager = false
    var objects = [Object]()
    var version = Version()
}
extension Desktop: Referenceable {
    static let name = Text(english: "Desktop", japanese: "デスクトップ")
}
extension Desktop {
    static let isHiddenActionManagerOption = BoolOption(defaultModel: false, cationModel: nil,
                                                        name: ActionManager.name,
                                                        info: .hidden)
}

final class DesktopBinder: BinderProtocol {
    var rootModel: Desktop {
        didSet {
            dataModel.isWrite = true
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
    let copiedObjectsNameView = TextFormView(text: Text(english: "Copied:", japanese: "コピー済み:"))
    let copiedObjectsView: ObjectsView<Object, Binder>
    let isHiddenActionManagerView: BoolView<Binder>
    let objectsView: ObjectsView<Object, Binder>
    let actionManagerView: ActionManagerView<Binder>

    var versionWidth = 100.0.cg
    var actionWidth = Layout.propertyWidth {
        didSet { updateLayout() }
    }
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
                                        sizeType: sizeType, abstractType: .mini)
        objectsView = ObjectsView(binder: binder,
                                  keyPath: keyPath.appending(path: \Model.objects),
                                  sizeType: sizeType, abstractType: .normal)
        
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
        let cw = max(bounds.width - actionWidth - versionWidth - ihamvw - conw - padding * 3,
                     0)
        copiedObjectsView.frame = Rect(x: copiedObjectsNameView.frame.maxX, y: headerY,
                                       width: cw, height: topViewsHeight)
        updateCopiedObjectViewPositions()
        isHiddenActionManagerView.frame = Rect(x: copiedObjectsNameView.frame.maxX, y: headerY,
                                               width: ihamvw, height: topViewsHeight)
        
        if model.isHiddenActionManager {
            objectsView.frame = Rect(x: padding,
                                     y: padding,
                                     width: bounds.width - padding * 2,
                                     height: bounds.height - topViewsHeight - padding * 2)
        } else {
            let h = bounds.height - padding * 2
            actionManagerView.frame = Rect(x: isHiddenActionManagerView.frame.maxX,
                                           y: padding,
                                           width: actionWidth,
                                           height: h)
            objectsView.frame = Rect(x: padding,
                                     y: padding,
                                     width: bounds.width - (padding * 2 + actionWidth),
                                     height: bounds.height - topViewsHeight - padding * 2)
        }
        objectsView.bounds.origin = Point(x: -round((objectsView.frame.width / 2)),
                                          y: -round((objectsView.frame.height / 2)))
//        sceneView.frame.origin = Point(x: -round(sceneView.frame.width / 2),
//                                       y: -round(sceneView.frame.height / 2))
        
        updateWithModel()
    }
    func updateWithModel() {
        isHiddenActionManagerView.updateWithModel()
    }

    var objectViewWidth = 80.0.cg
    private func updateCopiedObjectViews() {
        copiedObjectsView.updateWithModel()
        let padding = Layout.smallPadding
        let bounds = Rect(x: 0,
                          y: 0,
                          width: objectViewWidth,
                          height: copiedObjectsView.bounds.height - padding * 2)
        copiedObjectsView.children = model.copiedObjects.enumerated().map { (i, object) in
            return object.abstractViewWith(binder: binder,
                                           keyPath: keyPath.appending(path: \Model.copiedObjects[i]),
                                           frame: bounds, .small, type: .mini)
        }
        updateCopiedObjectViewPositions()
    }
    private func updateCopiedObjectViewPositions() {
        let padding = Layout.smallPadding
        _ = Layout.leftAlignment(copiedObjectsView.children.map { .view($0) },
                                 minX: padding, y: padding)
    }
}
extension DesktopView: Versionable {
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
