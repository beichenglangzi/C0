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
    var actionManager = ActionManager()
    var objects = [Any]()
    private enum CodingKeys: String, CodingKey {
        case isHiddenActions
    }
}
extension Desktop: Codable {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        actionManager.isHiddenActions = try values.decode(Bool.self, forKey: .isHiddenActions)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(actionManager.isHiddenActions, forKey: .isHiddenActions)
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
            actionManagerView.actionManager = desktop.actionManager
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
            differentialDesktopDataModel.dataHandler = { [unowned self] in self.desktop.jsonData }
        }
    }
    let objectsDataModelKey = "objects"
    var objectsDataModel: DataModel
    
    var actionWidth = ActionManagerView.defaultWidth {
        didSet {
            updateLayout()
        }
    }
    var copyManagerViewHeight = Layout.basicHeight + Layout.basicPadding * 2 {
        didSet {
            updateLayout()
        }
    }
    let actionManagerView = ActionManagerView(), copyManagerView = CopyManagerView()
    let objectsView = ArrayView<Any>()
    let sceneView = SceneView()
    
    override init() {
        differentialDesktopDataModel = DataModel(key: differentialDesktopDataModelKey)
        objectsDataModel = DataModel(key: objectsDataModelKey, directoryWith: [sceneView.dataModel])
        dataModel = DataModel(key: dataModelKey,
                              directoryWith: [differentialDesktopDataModel, objectsDataModel])
        
        super.init()
        fillColor = .background
        
        objectsView.replace(children: [sceneView])
        replace(children: [copyManagerView, actionManagerView, objectsView])
        
        actionManagerView.isHiddenActionsBinding = { [unowned self] in
            self.update(withIsHiddenActions: $0)
            self.isHiddenActionsBinding?($0)
        }
        differentialDesktopDataModel.dataHandler = { [unowned self] in self.desktop.jsonData }
    }
    
    var isHiddenActionsBinding: ((Bool) -> (Void))? = nil
    
    override var copyManager: CopyManager? {
        return copyManagerView.rootCopyManager
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
        let ah = actionManagerView.defaultBounds.height
        let preferenceY = bounds.height - ah - padding
        actionManagerView.frame = CGRect(x: padding, y: preferenceY,
                                         width: actionWidth, height: ah)
        copyManagerView.frame = CGRect(x: padding + actionWidth,
                                       y: bounds.height - copyManagerViewHeight - padding,
                                       width: bounds.width - actionWidth - padding * 2,
                                       height: copyManagerViewHeight)
        if actionManagerView.actionManager.isHiddenActions {
            objectsView.frame = CGRect(x: padding,
                                       y: padding,
                                       width: bounds.width - padding * 2,
                                       height: bounds.height - copyManagerViewHeight - padding * 2)
        } else {
            objectsView.frame = CGRect(x: padding + actionWidth,
                                       y: padding,
                                       width: bounds.width - (padding * 2 + actionWidth),
                                       height: bounds.height - copyManagerViewHeight - padding * 2)
        }
        objectsView.bounds.origin = CGPoint(x: -round((objectsView.frame.width / 2)),
                                            y: -round((objectsView.frame.height / 2)))
        sceneView.frame.origin = CGPoint(x: -round(sceneView.frame.width / 2),
                                         y: -round(sceneView.frame.height / 2))
    }
    private func update(withIsHiddenActions isHiddenActions: Bool) {
        updateLayout()
        differentialDesktopDataModel.isWrite = true
    }
    
    func lookUp(with event: TapEvent) -> Reference? {
        return desktop.reference
    }
}
