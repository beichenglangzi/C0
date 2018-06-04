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

struct Desktop {
    var copiedObjects = [Object(false)]
    var isHiddenActionList = false
    let actionList = ActionList()
    var objects = [Layout<Object>]()
    var version = Version()
}
extension Desktop: Codable {
    private enum CodingKeys: String, CodingKey {
        case copiedObjects, isHiddenActionList, objects, version
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        copiedObjects = try values.decode([Object].self, forKey: .copiedObjects)
        isHiddenActionList = try values.decode(Bool.self, forKey: .isHiddenActionList)
        objects = try values.decode([Layout<Object>].self, forKey: .objects)
        version = try values.decode(Version.self, forKey: .version)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(copiedObjects, forKey: .copiedObjects)
        try container.encode(isHiddenActionList, forKey: .isHiddenActionList)
        try container.encode(objects, forKey: .objects)
        try container.encode(version, forKey: .version)
    }
}
extension Desktop: Referenceable {
    static let name = Text(english: "Desktop", japanese: "デスクトップ")
}
extension Desktop {
    static let isHiddenActionListOption = BoolOption(defaultModel: false, cationModel: nil,
                                                        name: ActionList.name,
                                                        info: .hidden)
    static let copiedObjectsInferenceName = Text(english: "Copied", japanese: "コピー済み")
}
extension Desktop: AbstractViewable {
    func abstractViewWith<T>(binder: T, keyPath: ReferenceWritableKeyPath<T, Desktop>,
                             frame: Rect, _ sizeType: SizeType,
                             type: AbstractType) -> ModelView where T : BinderProtocol {
        switch type {
        case .normal:
            return DesktopView(binder: binder, keyPath: keyPath,
                               frame: frame, sizeType: sizeType)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath, frame: frame, sizeType)
        }
    }
}
extension Desktop: ObjectViewable {}

final class DesktopBinder: BinderProtocol {
    var rootModel: Desktop {
        didSet { diffDesktopDataModel.isWrite = true }
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
                diffDesktopDataModel.stopIsWriteClosure {
                    self.rootModel = desktop
                }
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
final class DesktopView<T: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = Desktop
    typealias Binder = T
    typealias BinderKeyPath = ReferenceWritableKeyPath<Binder, Model>
    typealias Notification = BasicNotification
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((DesktopView<Binder>, BasicNotification) -> ())]()

    var defaultModel: Model {
        return Model()
    }
    
    let versionView: VersionView<Binder>
    let copiedObjectsNameView = TextFormView(text: Desktop.copiedObjectsInferenceName + ":")
    let copiedObjectsView: ArrayView<Object, Binder>
    let isHiddenActionListView: BoolView<Binder>
    let objectsView: ArrayView<Layout<Object>, Binder>
    let actionListView: ActionListFormView

    var versionWidth = 150.0.cg
    var topViewsHeight = Layouter.basicHeight {
        didSet { updateLayout() }
    }
    
    init(binder: Binder, keyPath: BinderKeyPath,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {

        self.binder = binder
        self.keyPath = keyPath
        
        let ihamKeyPath = keyPath.appending(path: \Model.isHiddenActionList)
        isHiddenActionListView = BoolView(binder: binder, keyPath: ihamKeyPath,
                                             option: Model.isHiddenActionListOption,
                                             sizeType: sizeType)
        
        versionView = VersionView(binder: binder,
                                  keyPath: keyPath.appending(path: \Model.version),
                                  sizeType: sizeType)
        copiedObjectsView = ArrayView(binder: binder,
                                      keyPath: keyPath.appending(path: \Model.copiedObjects),
                                      sizeType: .small, abstractType: .mini)
        objectsView = ArrayView(binder: binder,
                                keyPath: keyPath.appending(path: \Model.objects),
                                sizeType: sizeType, abstractType: .normal)
        actionListView = ActionListFormView()
        actionListView.isHidden = binder[keyPath: keyPath].isHiddenActionList
        super.init()
        fillColor = .background
        
        children = [versionView, copiedObjectsNameView,
                    isHiddenActionListView, actionListView]
        children = [versionView, copiedObjectsNameView, copiedObjectsView,
                    isHiddenActionListView, actionListView, objectsView]
        
        isHiddenActionListView.notifications.append({ [unowned self] _, _ in
            self.actionListView.isHidden = self.model.isHiddenActionList
            self.updateLayout()
        })
    }
    
    override var contentsScale: Real {
        didSet {
            if contentsScale != oldValue {
                allChildrenAndSelf { $0.contentsScale = contentsScale }
            }
        }
    }
    override func updateLayout() {
        let padding = Layouter.basicPadding
        let ihamvw = isHiddenActionListView.defaultBounds.width
        let headerY = bounds.height - topViewsHeight - padding
        versionView.frame = Rect(x: padding, y: headerY,
                                 width: versionWidth, height: topViewsHeight)
        copiedObjectsNameView.frame.origin = Point(x: versionView.frame.maxX + padding,
                                                   y: headerY + padding)
        let conw = copiedObjectsNameView.frame.width
        let actionWidth = actionListView.width
        let cw = max(bounds.width - versionWidth - ihamvw - conw - padding * 3,
                     0)
        copiedObjectsView.frame = Rect(x: copiedObjectsNameView.frame.maxX, y: headerY,
                                       width: cw, height: topViewsHeight)
        updateCopiedObjectViewPositions()
        isHiddenActionListView.frame = Rect(x: 100, y: headerY,
                                               width: ihamvw, height: topViewsHeight)
        isHiddenActionListView.frame = Rect(x: copiedObjectsView.frame.maxX, y: headerY,
                                               width: ihamvw, height: topViewsHeight)
        
        if model.isHiddenActionList {
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
            actionListView.frame = Rect(x: padding + ow,
                                           y: padding,
                                           width: actionWidth,
                                           height: h)
        }
        objectsView.bounds.origin = Point(x: -(objectsView.frame.width / 2).rounded(),
                                          y: -(objectsView.frame.height / 2).rounded())
    }
    func updateWithModel() {
        isHiddenActionListView.updateWithModel()
        copiedObjectsView.updateWithModel()
        objectsView.updateWithModel()
        versionView.updateWithModel()
        if actionListView.isHidden != model.isHiddenActionList {
            actionListView.isHidden = model.isHiddenActionList
            updateLayout()
        }
    }

    var objectViewWidth = 80.0.cg
    private func updateCopiedObjectViews() {
        copiedObjectsView.updateWithModel()
        let padding = Layouter.smallPadding
        let bounds = Rect(x: 0,
                          y: 0,
                          width: objectViewWidth,
                          height: copiedObjectsView.bounds.height - padding * 2)
        copiedObjectsView.updateWithModel()
        copiedObjectsView.children.forEach { $0.bounds = bounds }
        updateCopiedObjectViewPositions()
    }
    private func updateCopiedObjectViewPositions() {
        let padding = Layouter.smallPadding
        _ = Layouter.leftAlignment(copiedObjectsView.children.map { .view($0) },
                                   minX: padding, y: padding)
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
