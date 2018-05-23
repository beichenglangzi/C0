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
    var isSimpleReference = false
    var reference: Reference?
    var objects = [Object]()
}
extension Desktop: Referenceable {
    static let name = Text(english: "Desktop", japanese: "デスクトップ")
}

final class DesktopBinder: BinderProtocol {
    var rootModel: Desktop {
        didSet {
            dataModel.isWrite = true
        }
    }
    
    var version = Version()
    
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
extension Desktop {
    static let isHiddenActionManagerOption
        = BoolOption(defaultModel: false, cationModel: nil,
                     name: Text(english: "Action Manager", japanese: "アクション管理"),
                     info: .hidden)
    private static let isrInfo
        = BoolOption.Info(trueName: Text(english: "Outline",  japanese: "概略"),
                          falseName: Text(english: "detail", japanese: "詳細"))
    static let isSimpleReferenceOption
        = BoolOption(defaultModel: false, cationModel: nil,
                     name: Text(english: "Reference", japanese: "情報"),
                     info: isrInfo)
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
    let isSimpleReferenceView: BoolView<Binder>
    let referenceView: ReferenceView<Binder>
    let objectsView: ObjectsView<Object, Binder>
    let actionManagerView = SenderView()
    
    let sceneView: SceneView<Binder>

    var versionWidth = 120.0.cg
    var actionWidth = ActionManagableView.defaultWidth {
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
        
        let isrKeyPath = keyPath.appending(path: \Model.isSimpleReference)
        isSimpleReferenceView = BoolView(binder: binder, keyPath: isrKeyPath,
                                         option: Model.isSimpleReferenceOption,
                                         sizeType: sizeType)
        
        super.init()
        fillColor = .background
        
        objectsView.children = [sceneView]
        children = [versionView, copiedObjectsNameView, copiedObjectsView,
                    isHiddenActionManagerView, isSimpleReferenceView,
                    actionManagerView, referenceView, objectsView]
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
        let referenceHeight = 80.0.cg
        let isrw = isSimpleReferenceView.defaultBounds.width
        let ihamvw = isHiddenActionManagerView.defaultBounds.width
        let headerY = bounds.height - topViewsHeight - padding
        versionView.frame = Rect(x: padding, y: headerY,
                                 width: versionWidth, height: topViewsHeight)
        copiedObjectsNameView.frame.origin = Point(x: versionView.frame.maxX + padding,
                                                   y: headerY + padding)
        let conw = copiedObjectsNameView.frame.width
        let cw = max(bounds.width - actionWidth - versionWidth - isrw - ihamvw - conw - padding * 3,
                     0)
        copiedObjectsView.frame = Rect(x: copiedObjectsNameView.frame.maxX, y: headerY,
                                       width: cw, height: topViewsHeight)
        updateCopiedObjectViewPositions()
        isSimpleReferenceView.frame = Rect(x: copiedObjectsView.frame.maxX, y: headerY,
                                           width: isrw, height: topViewsHeight)
        isHiddenActionManagerView.frame = Rect(x: isSimpleReferenceView.frame.maxX, y: headerY,
                                               width: ihamvw, height: topViewsHeight)
        if model.isSimpleReference {
            referenceView.frame = Rect(x: isHiddenActionManagerView.frame.maxX, y: headerY,
                                  width: actionWidth, height: topViewsHeight)
        } else {
            let h = model.isHiddenActionManager ? bounds.height - padding * 2 : referenceHeight
            referenceView.frame = Rect(x: isHiddenActionManagerView.frame.maxX,
                                  y: bounds.height - h - padding,
                                  width: actionWidth,
                                  height: h)
        }
        if !model.isHiddenActionManager {
            let h = model.isSimpleReference ?
                bounds.height - isSimpleReferenceView.frame.height - padding * 2 :
                bounds.height - referenceHeight - padding * 2
            actionManagerView.frame = Rect(x: isHiddenActionManagerView.frame.maxX, y: padding,
                                           width: actionWidth, height: h)
        }

        if model.isHiddenActionManager && model.isSimpleReference {
            objectsView.frame = Rect(x: padding,
                                     y: padding,
                                     width: bounds.width - padding * 2,
                                     height: bounds.height - topViewsHeight - padding * 2)
        } else {
            objectsView.frame = Rect(x: padding,
                                     y: padding,
                                     width: bounds.width - (padding * 2 + actionWidth),
                                     height: bounds.height - topViewsHeight - padding * 2)
        }
        objectsView.bounds.origin = Point(x: -round((objectsView.frame.width / 2)),
                                          y: -round((objectsView.frame.height / 2)))
        sceneView.frame.origin = Point(x: -round(sceneView.frame.width / 2),
                                       y: -round(sceneView.frame.height / 2))
        
        updateWithModel()
    }
    func updateWithModel() {
        isSimpleReferenceView.updateWithModel()
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
extension DesktopView: ReferenceViewer {
    var reference: Reference {
        get { return referenceView.model }
        set { referenceView.model = newValue }
    }
    func push(_ reference: Reference, to version: Version) {
        referenceView.push(reference, to: version)
    }
}
extension DesktopView: Queryable {
    static var referenceableType: Referenceable.Type{
        return Model.self
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
