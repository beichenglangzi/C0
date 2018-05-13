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
    var copiedObjects = [Viewable]() {
        didSet {
            copiedObjectsBinding?(copiedObjects)
        }
    }
    var copiedObjectsBinding: (([Viewable]) -> ())?
    
    var isHiddenActionManager = false
    var isSimpleReference = false
    var reference = Reference()
    var objects = [Codable]()
    
//    private enum CodingKeys: String, CodingKey {
//        case isSimpleReference, isHiddenActionManager
//    }
}
//extension Desktop: Codable {
//    init(from decoder: Decoder) throws {
//        self.init()
//        let values = try decoder.container(keyedBy: CodingKeys.self)
//        isSimpleReference = try values.decode(Bool.self, forKey: .isSimpleReference)
//        isHiddenActionManager = try values.decode(Bool.self, forKey: .isHiddenActionManager)
//    }
//    func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        try container.encode(isSimpleReference, forKey: .isSimpleReference)
//        try container.encode(isHiddenActionManager, forKey: .isHiddenActionManager)
//    }
//}
extension Desktop: Referenceable {
    static let name = Text(english: "Desktop", japanese: "デスクトップ")
}

final class DesktopBinder: BinderProtocol {
    var desktop: Desktop {
        didSet {
            dataModel.isWrite = true
        }
    }
    var version: Version
    let sceneBinder = SceneBinder()
    
    init(desktop: Desktop = Desktop(), version: Version = Version()) {
        self.desktop = desktop
        self.version = version
        
        diffDesktopDataModel = DataModel(key: diffDesktopDataModelKey)
        objectsDataModel = DataModel(key: objectsDataModelKey,
                                     directoryWith: [sceneBinder.dataModel])
        dataModel = DataModel(key: dataModelKey,
                              directoryWith: [diffDesktopDataModel, objectsDataModel])
        
        diffDesktopDataModel.dataClosure = { [unowned self] in self.desktop.jsonData }
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
            
            if let sceneDataModel = objectsDataModel.children[sceneBinder.dataModelKey] {
                sceneBinder.dataModel = sceneDataModel
            } else {
                objectsDataModel.insert(sceneBinder.dataModel)
            }
        }
    }
    let diffDesktopDataModelKey = "diffDesktop"
    var diffDesktopDataModel: DataModel {
        didSet {
            if let desktop = diffDesktopDataModel.readObject(Desktop.self) {
                self.desktop = desktop
            }
            diffDesktopDataModel.dataClosure = { [unowned self] in self.desktop.jsonData }
        }
    }
    let objectsDataModelKey = "objects"
    var objectsDataModel: DataModel
}

/**
 Issue: sceneViewを取り除く
 */
final class DesktopView<T: BinderProtocol>: View, BindableReciver {
    typealias Model = Bool
    typealias ModelOption = BoolOption
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    
    var desktop: Desktop {
        get {
            return desktopBinder[keyPath: keyPath]
        }
        set {
            desktopBinder[keyPath: keyPath] = newValue
            updateWithDesktop()
        }
    }
    var desktopBinder = DesktopBinder() {
        didSet {
            versionView.version = desktopBinder.version
            updateWithDesktop()
        }
    }
    var keyPath: WritableKeyPath<DesktopBinder, Desktop> = \DesktopBinder.desktop {
        didSet {
            updateWithDesktop()
        }
    }
    
    var versionWidth = 120.0.cg
    var actionWidth = ActionManagableView.defaultWidth {
        didSet {
            updateLayout()
        }
    }
    var topViewsHeight = Layout.basicHeight {
        didSet {
            updateLayout()
        }
    }
    let versionView = VersionView()
    let classCopiedObjectsNameView = TextView(text: Text(english: "Copied:", japanese: "コピー済み:"))
    let copiedObjectsView = AnyArrayView()
    let isHiddenActionManagerView = BoolView(name: Text(english: "Action Manager",
                                                        japanese: "アクション管理"),
                                             boolInfo: BoolInfo.hidden)
    let isSimpleReferenceView = BoolView(name: Text(english: "Reference", japanese: "情報"),
                                         boolInfo: BoolInfo(trueName: Text(english: "Outline",
                                                                           japanese: "概略"),
                                                            falseName: Text(english: "detail",
                                                                            japanese: "詳細")))
    let infoView = InfoView()
    let actionManagerView = SenderView()
    let objectsView = AnyArrayView()
    let sceneView: SceneView
    
    init(binder: Binder, keyPath: BinderKeyPath,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        sceneView = SceneView(desktopBinder.sceneBinder, keyPath: \SceneBinder.scene)
        
        super.init()
        fillColor = .background
        versionView.version = desktopBinder.version
        
        objectsView.children = [sceneView]
        children = [versionView, classCopiedObjectsNameView, copiedObjectsView,
                    isHiddenActionManagerView, isSimpleReferenceView,
                    actionManagerView, infoView, objectsView]
        
        isHiddenActionManagerView.binding = { [unowned self] in
            self.update(withIsHiddenActionManager: $0.bool)
            self.isHiddenActionManagerBinding?($0.bool)
        }
        isSimpleReferenceView.binding = { [unowned self] in
            self.update(withIsSimpleReference: $0.bool)
            self.isSimpleReferenceBinding?($0.bool)
        }
    }
    
    var isHiddenActionManagerBinding: ((Bool) -> (Void))? = nil
    var isSimpleReferenceBinding: ((Bool) -> (Void))? = nil
    
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
        classCopiedObjectsNameView.frame.origin = Point(x: versionView.frame.maxX + padding, y: headerY + padding)
        let cw = max(bounds.width - actionWidth - versionWidth - isrw - ihamvw - classCopiedObjectsNameView.frame.width - padding * 3, 0)
        copiedObjectsView.frame = Rect(x: classCopiedObjectsNameView.frame.maxX,
                                         y: headerY,
                                         width: cw,
                                         height: topViewsHeight)
        updateCopiedObjectViewPositions()
        isSimpleReferenceView.frame = Rect(x: copiedObjectsView.frame.maxX,
                                           y: headerY,
                                           width: isrw,
                                           height: topViewsHeight)
        isHiddenActionManagerView.frame = Rect(x: isSimpleReferenceView.frame.maxX,
                                               y: headerY,
                                               width: ihamvw,
                                               height: topViewsHeight)
        if desktop.isSimpleReference {
            infoView.frame = Rect(x: isHiddenActionManagerView.frame.maxX,
                                  y: headerY,
                                  width: actionWidth,
                                  height: topViewsHeight)
        } else {
            let h = desktop.isHiddenActionManager ? bounds.height - padding * 2 : referenceHeight
            infoView.frame = Rect(x: isHiddenActionManagerView.frame.maxX,
                                  y: bounds.height - h - padding,
                                  width: actionWidth,
                                  height: h)
        }
        if !desktop.isHiddenActionManager {
            let h = desktop.isSimpleReference ?
                bounds.height - isSimpleReferenceView.frame.height - padding * 2 :
                bounds.height - referenceHeight - padding * 2
            actionManagerView.frame = Rect(x: isHiddenActionManagerView.frame.maxX, y: padding,
                                           width: actionWidth, height: h)
        }
        
        if desktop.isHiddenActionManager && desktop.isSimpleReference {
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
    }
    private func updateWithDesktop() {
        actionManagerView.sender = desktop.sender
        isSimpleReferenceView.bool = desktop.isSimpleReference
        isHiddenActionManagerView.bool = desktop.isHiddenActionManager
        updateLayout()
    }
    
    func update(withIsHiddenActionManager isHiddenActionManager: Bool) {
        actionManagerView.isHidden = isHiddenActionManager
        desktop.isHiddenActionManager = isHiddenActionManager
        updateLayout()
    }
    func update(withIsSimpleReference isSimpleReference: Bool) {
        desktop.isSimpleReference = isSimpleReference
        updateLayout()
    }
    
    var objectViewWidth = 80.0.cg
    private func updateCopiedObjectViews() {
        copiedObjectsView.array = desktop.copiedObjects
        let padding = Layout.smallPadding
        let bounds = Rect(x: 0,
                          y: 0,
                          width: objectViewWidth,
                          height: copiedObjectsView.bounds.height - padding * 2)
        copiedObjectsView.children = desktop.copiedObjects.map {
            $0.view(withBounds: bounds, .small)
        }
        updateCopiedObjectViewPositions()
    }
    private func updateCopiedObjectViewPositions() {
        let padding = Layout.smallPadding
        _ = Layout.leftAlignment(copiedObjectsView.children, minX: padding, y: padding)
    }
}
extension DesktopView: ReferenceViewer {
    var reference: Reference {
        get {
            return infoView.info
        }
        set {
            push(newValue)
        }
    }
    private func push(_ info: Info) {
        //        undoManager?.registerUndo(withTarget: self) { [oldInfo = infoView.info] in
        //            $0.push(oldInfo)
        //
        infoView.info = info
    }
}
extension DesktopView: Queryable {
    static let referenceableType: Referenceable.Type = Desktop.self
}
extension DesktopView: Versionable {
    var binder: BinderProtocol {
        return desktopBinder
    }
}
extension DesktopView: CopiedObjectsViewer {
    var copiedObjects: [Object] {
        return desktop.copiedObjects
    }
    func push(copiedObjects: [Object]) {
        //        undoManager?.registerUndo(withTarget: self) { [oldCopiedObjects = desktop.copiedObjects] in
        //            $0.push(copiedObjects: oldCopiedObjects)
        //        }
        desktop.copiedObjects = copiedObjects
        updateCopiedObjectViews()
    }
}
