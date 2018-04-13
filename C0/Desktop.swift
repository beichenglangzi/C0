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

final class Desktop {
    var version = Version()
    var copiedObjects = [ViewExpression]() {
        didSet {
            copiedObjectsBinding?(copiedObjects)
        }
    }
    var copiedObjectsBinding: (([ViewExpression]) -> ())?
    var isHiddenActionManager = false
    var isSimpleReference = false
    var actionManager = ActionManager()
    var objects = [Any]()
    private enum CodingKeys: String, CodingKey {
        case isSimpleReference, isHiddenActionManager
    }
}
extension Desktop: Codable {
    convenience init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        isSimpleReference = try values.decode(Bool.self, forKey: .isSimpleReference)
        isHiddenActionManager = try values.decode(Bool.self, forKey: .isHiddenActionManager)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isSimpleReference, forKey: .isSimpleReference)
        try container.encode(isHiddenActionManager, forKey: .isHiddenActionManager)
    }
}
extension Desktop: Referenceable {
    static let name = Localization(english: "Desktop", japanese: "デスクトップ")
}

/**
 # Issue
 - sceneViewを取り除く
 */
final class DesktopView: RootView {
    var desktop = Desktop() {
        didSet {
            versionView.version = desktop.version
            actionManagerView.actionManager = desktop.actionManager
            isSimpleReferenceView.bool = desktop.isSimpleReference
            isHiddenActionManagerView.bool = desktop.isHiddenActionManager
            updateLayout()
        }
    }
    let dataModelKey = "desktop"
    var dataModel: DataModel {
        didSet {
            if let objectsDataModel = dataModel.children[objectsDataModelKey] {
                self.objectsDataModel = objectsDataModel
            } else {
                dataModel.insert(objectsDataModel)
            }
            
            if let dDesktopDataModel = dataModel.children[differentialDesktopDataModelKey] {
                self.differentialDesktopDataModel = dDesktopDataModel
            } else {
                dataModel.insert(differentialDesktopDataModel)
            }
            
            if let sceneDataModel = objectsDataModel.children[sceneView.dataModelKey] {
                sceneView.dataModel = sceneDataModel
            } else {
                objectsDataModel.insert(sceneView.dataModel)
            }
        }
    }
    let differentialDesktopDataModelKey = "differentialDesktop"
    var differentialDesktopDataModel: DataModel {
        didSet {
            if let desktop: Desktop = differentialDesktopDataModel.readObject() {
                self.desktop = desktop
            }
            differentialDesktopDataModel.dataClosure = { [unowned self] in self.desktop.jsonData }
        }
    }
    let objectsDataModelKey = "objects"
    var objectsDataModel: DataModel
    
    var versionWidth = 120.0.cf
    var actionWidth = ActionManagerView.defaultWidth {
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
    let classCopiedObjectsNameView = TextView(text: Localization(english: "Copied:",
                                                                 japanese: "コピー済み:"))
    let copiedObjectsView = AnyArrayView()
    let isHiddenActionManagerView = BoolView(name: Localization(english: "Action Manager",
                                                                japanese: "アクション管理"),
                                             boolInfo: BoolInfo.hidden)
    let isSimpleReferenceView = BoolView(name: Localization(english: "Reference",
                                                            japanese: "情報"),
                                         boolInfo: BoolInfo(trueName: Localization(english: "Outline",
                                                                                   japanese: "概略"),
                                                            falseName: Localization(english: "detail",
                                                                                    japanese: "詳細")))
    let referenceView = ReferenceView()
    let actionManagerView = ActionManagerView()
    let objectsView = AnyArrayView()
    let sceneView = SceneView()
    
    override init() {
        differentialDesktopDataModel = DataModel(key: differentialDesktopDataModelKey)
        objectsDataModel = DataModel(key: objectsDataModelKey, directoryWith: [sceneView.dataModel])
        dataModel = DataModel(key: dataModelKey,
                              directoryWith: [differentialDesktopDataModel, objectsDataModel])
        
        super.init()
        fillColor = .background
        versionView.version = desktop.version
        
        objectsView.replace(children: [sceneView])
        replace(children: [versionView, classCopiedObjectsNameView, copiedObjectsView,
                           isHiddenActionManagerView, isSimpleReferenceView,
                           actionManagerView, referenceView, objectsView])
        
        isHiddenActionManagerView.binding = { [unowned self] in
            self.update(withIsHiddenActionManager: $0.bool)
            self.isHiddenActionManagerBinding?($0.bool)
        }
        isSimpleReferenceView.binding = { [unowned self] in
            self.update(withIsSimpleReference: $0.bool)
            self.isSimpleReferenceBinding?($0.bool)
        }
        
        differentialDesktopDataModel.dataClosure = { [unowned self] in self.desktop.jsonData }
    }
    
    var isHiddenActionManagerBinding: ((Bool) -> (Void))? = nil
    var isSimpleReferenceBinding: ((Bool) -> (Void))? = nil
    
    override var undoManager: UndoManager? {
        return desktop.version
    }
    
    var rootCursorPoint = CGPoint()
    override var cursorPoint: CGPoint {
        return rootCursorPoint
    }
    
    override var contentsScale: CGFloat {
        didSet {
            if contentsScale != oldValue {
                allChildrenAndSelf { $0.contentsScale = contentsScale }
            }
        }
    }
    override var locale: Locale {
        didSet {
            if locale.languageCode != oldValue.languageCode {
                allChildrenAndSelf { $0.locale = locale }
            }
        }
    }
    
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    private func updateLayout() {
        let padding = Layout.basicPadding
        let referenceHeight = 150.0.cf
        let isrw = isSimpleReferenceView.defaultBounds.width
        let ihamvw = isHiddenActionManagerView.defaultBounds.width
        let headerY = bounds.height - topViewsHeight - padding
        versionView.frame = CGRect(x: padding,
                                   y: headerY,
                                   width: versionWidth, height: topViewsHeight)
        classCopiedObjectsNameView.frame.origin = CGPoint(x: versionView.frame.maxX + padding, y: headerY + padding)
        let cw = max(bounds.width - actionWidth - versionWidth - isrw - ihamvw - classCopiedObjectsNameView.frame.width - padding * 3, 0)
        copiedObjectsView.frame = CGRect(x: classCopiedObjectsNameView.frame.maxX,
                                         y: headerY,
                                         width: cw,
                                         height: topViewsHeight)
        updateCopiedObjectViewPositions()
        isSimpleReferenceView.frame = CGRect(x: copiedObjectsView.frame.maxX,
                                             y: headerY,
                                             width: isrw,
                                             height: topViewsHeight)
        isHiddenActionManagerView.frame = CGRect(x: isSimpleReferenceView.frame.maxX,
                                                 y: headerY,
                                                 width: ihamvw,
                                                 height: topViewsHeight)
        if desktop.isSimpleReference {
            referenceView.frame = CGRect(x: isHiddenActionManagerView.frame.maxX,
                                         y: headerY,
                                         width: actionWidth,
                                         height: topViewsHeight)
        } else {
            let h = desktop.isHiddenActionManager ? bounds.height - padding * 2 : referenceHeight
            referenceView.frame = CGRect(x: isHiddenActionManagerView.frame.maxX,
                                         y: bounds.height - h - padding,
                                         width: actionWidth,
                                         height: h)
        }
        if !desktop.isHiddenActionManager {
            let h = desktop.isSimpleReference ?
                bounds.height - isSimpleReferenceView.frame.height - padding * 2 :
                bounds.height - referenceHeight - padding * 2
            actionManagerView.frame = CGRect(x: isHiddenActionManagerView.frame.maxX, y: padding,
                                             width: actionWidth, height: h)
        }
        
        if desktop.isHiddenActionManager && desktop.isSimpleReference {
            objectsView.frame = CGRect(x: padding,
                                       y: padding,
                                       width: bounds.width - padding * 2,
                                       height: bounds.height - topViewsHeight - padding * 2)
        } else {
            objectsView.frame = CGRect(x: padding,
                                       y: padding,
                                       width: bounds.width - (padding * 2 + actionWidth),
                                       height: bounds.height - topViewsHeight - padding * 2)
        }
        objectsView.bounds.origin = CGPoint(x: -round((objectsView.frame.width / 2)),
                                            y: -round((objectsView.frame.height / 2)))
        sceneView.frame.origin = CGPoint(x: -round(sceneView.frame.width / 2),
                                         y: -round(sceneView.frame.height / 2))
    }
    func update(withIsHiddenActionManager isHiddenActionManager: Bool) {
        actionManagerView.isHidden = isHiddenActionManager
        desktop.isHiddenActionManager = isHiddenActionManager
        updateLayout()
        differentialDesktopDataModel.isWrite = true
    }
    func update(withIsSimpleReference isSimpleReference: Bool) {
        desktop.isSimpleReference = isSimpleReference
        updateLayout()
        differentialDesktopDataModel.isWrite = true
    }
    var objectViewWidth = 80.0.cf
    private func updateCopiedObjectViews() {
        copiedObjectsView.array = desktop.copiedObjects
        let padding = Layout.smallPadding
        let bounds = CGRect(x: 0,
                            y: 0,
                            width: objectViewWidth,
                            height: copiedObjectsView.bounds.height - padding * 2)
        copiedObjectsView.replace(children: desktop.copiedObjects.map {
            $0.view(withBounds: bounds, sizeType: .small)
        })
        updateCopiedObjectViewPositions()
    }
    func updateCopiedObjectViewPositions() {
        let padding = Layout.smallPadding
        _ = Layout.leftAlignment(copiedObjectsView.children, minX: padding, y: padding)
    }

    override var topCopiedObjects: [ViewExpression] {
        return desktop.copiedObjects
    }
    override func sendToTop(copiedObjects: [ViewExpression]) {
        push(copiedObjects: copiedObjects)
    }
    func push(copiedObjects: [ViewExpression]) {
        push(copiedObjects: copiedObjects, oldCopiedObjects: desktop.copiedObjects)
    }
    private func push(copiedObjects: [ViewExpression], oldCopiedObjects: [ViewExpression]) {
        undoManager?.registerUndo(withTarget: self) {
            $0.push(copiedObjects: oldCopiedObjects, oldCopiedObjects: copiedObjects)
        }
        desktop.copiedObjects = copiedObjects
        updateCopiedObjectViews()
    }
    
    override func sendToTop(_ reference: Reference) {
        push(reference, old: referenceView.reference)
    }
    func push(_ reference: Reference, old oldReference: Reference) {
        undoManager?.registerUndo(withTarget: self) {
            $0.push(oldReference, old: reference)
        }
        referenceView.reference = reference
    }
    func reference(with event: TapEvent) -> Reference? {
        return desktop.reference
    }
}
