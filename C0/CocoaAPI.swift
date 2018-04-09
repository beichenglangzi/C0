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

import Cocoa

struct Font {
    static let `default` = Font(monospacedSize: 11)
    static let bold = Font(boldMonospacedSize: 11)
    static let italic = Font(italicMonospacedSize: 11)
    static let smallBold = Font(boldMonospacedSize: 8)
    static let small = Font(monospacedSize: 8)
    static let smallItalic = Font(italicMonospacedSize: 8)
    static let action = Font(boldMonospacedSize: 9)
    static let hedding0 = Font(boldMonospacedSize: 14)
    static let hedding1 = Font(boldMonospacedSize: 10)
    static let subtitle = Font(boldMonospacedSize: 20)
    static func `default`(with sizeType: SizeType) -> Font {
        return sizeType == .small ? small : self.default
    }
    static func bold(with sizeType: SizeType) -> Font {
        return sizeType == .small ? smallBold : bold
    }
    static func italic(with sizeType: SizeType) -> Font {
        return sizeType == .small ? smallItalic : italic
    }
    
    var name: String {
        didSet {
            updateWith(name: name, size: size)
        }
    }
    var size: CGFloat {
        didSet {
            updateWith(name: name, size: size)
        }
    }
    private(set) var ascent: CGFloat, descent: CGFloat, leading: CGFloat, ctFont: CTFont
    
    init(size: CGFloat) {
        self.init(NSFont.systemFont(ofSize: size))
    }
    init(boldSize size: CGFloat) {
        self.init(NSFont.boldSystemFont(ofSize: size))
    }
    init(monospacedSize size: CGFloat) {
        self.init(NSFont.monospacedDigitSystemFont(ofSize: size, weight: .medium))
    }
    init(boldMonospacedSize size: CGFloat) {
        self.init(NSFont.monospacedDigitSystemFont(ofSize: size, weight: .bold))
    }
    init(italicMonospacedSize size: CGFloat) {
        let font = NSFont.monospacedDigitSystemFont(ofSize: size, weight: .medium)
        self.init(NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask))
    }
    init(name: String, size: CGFloat) {
        self.init(CTFontCreateWithName(name as CFString, size, nil))
    }
    init(_ ctFont: CTFont) {
        name = CTFontCopyFullName(ctFont) as String
        size = CTFontGetSize(ctFont)
        ascent = CTFontGetAscent(ctFont)
        descent = -CTFontGetDescent(ctFont)
        leading = -CTFontGetLeading(ctFont)
        self.ctFont = ctFont
    }
    
    private mutating func updateWith(name: String, size: CGFloat) {
        ctFont = CTFontCreateWithName(name as CFString, size, nil)
        ascent = CTFontGetAscent(ctFont)
        descent = -CTFontGetDescent(ctFont)
        leading = -CTFontGetLeading(ctFont)
    }
    
    func ceilHeight(withPadding padding: CGFloat) -> CGFloat {
        return ceil(ascent - descent) + padding * 2
    }
}

struct Cursor {
    static let arrow = Cursor(NSCursor.arrow)
    static let iBeam = Cursor(NSCursor.iBeam)
    static let leftRight = slideCursor(isVertical: false)
    static let upDown = slideCursor(isVertical: true)
    static let pointingHand = Cursor(NSCursor.pointingHand)
    static let stroke = circleCursor(size: 2)
    
    static func circleCursor(size s: CGFloat, color: Color = .black,
                             outlineColor: Color = .white) -> Cursor {
        let lineWidth = 2.0.cf, subLineWidth = 1.0.cf
        let d = subLineWidth + lineWidth / 2
        let b = CGRect(x: d, y: d, width: d * 2 + s, height: d * 2 + s)
        let image = NSImage(size: CGSize(width: s + d * 2 * 2,  height: s + d * 2 * 2)) { ctx in
            ctx.setLineWidth(lineWidth + subLineWidth * 2)
            ctx.setFillColor(outlineColor.with(alpha: 0.35).cgColor)
            ctx.setStrokeColor(outlineColor.with(alpha: 0.8).cgColor)
            ctx.addEllipse(in: b)
            ctx.drawPath(using: .fillStroke)
            ctx.setLineWidth(lineWidth)
            ctx.setStrokeColor(color.cgColor)
            ctx.strokeEllipse(in: b)
        }
        let hotSpot = NSPoint(x: d * 2 + s / 2, y: -d * 2 - s / 2)
        return Cursor(NSCursor(image: image, hotSpot: hotSpot))
    }
    static func slideCursor(color: Color = .black, outlineColor: Color = .white,
                            isVertical: Bool) -> Cursor {
        let lineWidth = 1.0.cf, lineHalfWidth = 4.0.cf, halfHeight = 4.0.cf, halfLineHeight = 1.5.cf
        let aw = floor(halfHeight * sqrt(3)), d = lineWidth / 2
        let w = ceil(aw * 2 + lineHalfWidth * 2 + d), h =  ceil(halfHeight * 2 + d)
        let size = isVertical ? CGSize(width: h,  height: w) : CGSize(width: w,  height: h)
        let image = NSImage(size: size) { ctx in
            if isVertical {
                ctx.translateBy(x: h / 2, y: w / 2)
                ctx.rotate(by: .pi / 2)
                ctx.translateBy(x: -w / 2, y: -h / 2)
            }
            ctx.addLines(between: [CGPoint(x: d, y: d + halfHeight),
                                   CGPoint(x: d + aw, y: d + halfHeight * 2),
                                   CGPoint(x: d + aw, y: d + halfHeight + halfLineHeight),
                                   CGPoint(x: d + aw + lineHalfWidth * 2,
                                           y: d + halfHeight + halfLineHeight),
                                   CGPoint(x: d + aw + lineHalfWidth * 2, y: d + halfHeight * 2),
                                   CGPoint(x: d + aw * 2 + lineHalfWidth * 2, y: d + halfHeight),
                                   CGPoint(x: d + aw + lineHalfWidth * 2, y: d),
                                   CGPoint(x: d + aw + lineHalfWidth * 2,
                                           y: d + halfHeight - halfLineHeight),
                                   CGPoint(x: d + aw, y: d + halfHeight - halfLineHeight),
                                   CGPoint(x: d + aw, y: d)])
            ctx.closePath()
            ctx.setLineJoin(.miter)
            ctx.setLineWidth(lineWidth)
            ctx.setFillColor(color.cgColor)
            ctx.setStrokeColor(outlineColor.cgColor)
            ctx.drawPath(using: .fillStroke)
        }
        let hotSpot = isVertical ? CGPoint(x: h / 2, y: -w / 2) : CGPoint(x: w / 2, y: -h / 2)
        return Cursor(NSCursor(image: image, hotSpot: hotSpot))
    }
    
    var image: CGImage {
        didSet {
            nsCursor = NSCursor(image: NSImage(cgImage: image, size: NSSize()), hotSpot: hotSpot)
        }
    }
    var hotSpot: CGPoint {
        didSet {
            nsCursor = NSCursor(image: NSImage(cgImage: image, size: NSSize()), hotSpot: hotSpot)
        }
    }
    fileprivate var nsCursor: NSCursor
    
    private init(_ nsCursor: NSCursor) {
        self.image = nsCursor.image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        self.hotSpot = nsCursor.hotSpot
        self.nsCursor = nsCursor
    }
    init(image: CGImage, hotSpot: CGPoint) {
        self.image = image
        self.hotSpot = hotSpot
        nsCursor = NSCursor(image: NSImage(cgImage: image, size: NSSize()), hotSpot: hotSpot)
    }
}
extension Cursor: Equatable {
    static func ==(lhs: Cursor, rhs: Cursor) -> Bool {
        return lhs.image === rhs.image && lhs.hotSpot == rhs.hotSpot
    }
}

extension NSImage {
    convenience init(size: CGSize, handler: (CGContext) -> Void) {
        self.init(size: size)
        lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            handler(ctx)
        }
        unlockFocus()
    }
}

struct TextInputContext {
    private static var currentContext: NSTextInputContext? {
        return NSTextInputContext.current
    }
    static func invalidateCharacterCoordinates() {
        currentContext?.invalidateCharacterCoordinates()
    }
    static func discardMarkedText() {
        currentContext?.discardMarkedText()
    }
}

extension URL {
    struct File {
        var url: URL, name: String, isExtensionHidden: Bool
    }
    static func file(message: String?,
                     name: String?,
                     fileTypes: [String],
                     completionHandler handler: @escaping (URL.File) -> (Void)) {
        guard let window = NSApp.mainWindow else {
            return
        }
        let savePanel = NSSavePanel()
        savePanel.message = message
        if let name = name {
            savePanel.nameFieldStringValue = name
        }
        savePanel.canSelectHiddenExtension = true
        savePanel.allowedFileTypes = fileTypes
        savePanel.beginSheetModal(for: window) { [unowned savePanel] result in
            if result == .OK, let url = savePanel.url {
                handler(URL.File(url: url,
                                 name: savePanel.nameFieldStringValue,
                                 isExtensionHidden: savePanel.isExtensionHidden))
            }
        }
    }
}

fileprivate struct C0Coder {
    static let appUTI = Bundle.main.bundleIdentifier ?? "smdls.C0."
    
    static func typeKey(from object: Any) -> String {
        return appUTI + String(describing: type(of: object))
    }
    static func typeKey<T>(from type: T.Type) -> String {
        return appUTI + String(describing: type)
    }
    
    static func decode(from data: Data, forKey key: String) -> Any? {
        if let object = NSKeyedUnarchiver.unarchiveObject(with: data) {
            return object
        }
        let decoder = JSONDecoder()
        switch key {
        case typeKey(from: Keyframe.self):
            return try? decoder.decode(Keyframe.self, from: data)
        case typeKey(from: Easing.self):
            return try? decoder.decode(Easing.self, from: data)
        case typeKey(from: Transform.self):
            return try? decoder.decode(Transform.self, from: data)
        case typeKey(from: Wiggle.self):
            return try? decoder.decode(Wiggle.self, from: data)
        case typeKey(from: Line.self):
            return try? decoder.decode(Line.self, from: data)
        case typeKey(from: Color.self):
            return try? decoder.decode(Color.self, from: data)
        case typeKey(from: URL.self):
            return try? decoder.decode(URL.self, from: data)
        default:
            return nil
        }
    }
    static func encode(_ object: Any, forKey key: String) -> Data? {
        if let coding = object as? NSCoding {
            return coding.data
        } else if let codable = object as? Encodable {
            return codable.jsonData
        } else {
            return nil
        }
    }
}

fileprivate struct C0Preference: Codable {
    var isFullScreen = false, windowFrame = NSRect()
}

@objc(C0Application)
final class C0Application: NSApplication {
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyUp && event.modifierFlags.contains(.command) {
            keyWindow?.sendEvent(event)
        } else {
            super.sendEvent(event)
        }
    }
}

@NSApplicationMain final class C0AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var aboutAppItem: NSMenuItem?
    @IBOutlet weak var servicesItem: NSMenuItem?
    @IBOutlet weak var hideAppItem: NSMenuItem?
    @IBOutlet weak var hideOthersItem: NSMenuItem?
    @IBOutlet weak var showAllItem: NSMenuItem?
    @IBOutlet weak var quitAppItem: NSMenuItem?
    @IBOutlet weak var fileMenu: NSMenu?
    @IBOutlet weak var newItem: NSMenuItem?
    @IBOutlet weak var openItem: NSMenuItem?
    @IBOutlet weak var saveAsItem: NSMenuItem?
    @IBOutlet weak var openRecentItem: NSMenuItem?
    @IBOutlet weak var closeItem: NSMenuItem?
    @IBOutlet weak var saveItem: NSMenuItem?
    @IBOutlet weak var windowMenu: NSMenu?
    @IBOutlet weak var minimizeItem: NSMenuItem?
    @IBOutlet weak var zoomItem: NSMenuItem?
    @IBOutlet weak var bringAllToFrontItem: NSMenuItem?
    
    private var localToken: NSObjectProtocol?
    func applicationDidFinishLaunching(_ notification: Notification) {
        updateString(with: Locale.current)
        let nc = NotificationCenter.default
        let localeHandler: (Notification) -> Void = { [unowned self] _ in
            self.updateString(with: Locale.current)
        }
        localToken = nc.addObserver(forName: NSLocale.currentLocaleDidChangeNotification,
                                    object: nil, queue: nil, using: localeHandler)
    }
    deinit {
        if let localToken = localToken {
            NotificationCenter.default.removeObserver(localToken)
        }
    }
    
    func updateString(with locale :Locale) {
        let appName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? "C0"
        aboutAppItem?.title = Localization(english: "About \(appName)",
            japanese: "\(appName) について").string(with: locale)
        servicesItem?.title = Localization(english: "Services",
                                           japanese: "サービス").string(with: locale)
        hideAppItem?.title = Localization(english: "Hide \(appName)",
            japanese: "\(appName) を隠す").string(with: locale)
        hideOthersItem?.title = Localization(english: "Hide Others",
                                             japanese: "ほかを隠す").string(with: locale)
        showAllItem?.title = Localization(english: "Show All",
                                          japanese: "すべてを表示").string(with: locale)
        quitAppItem?.title = Localization(english: "Quit \(appName)",
            japanese: "\(appName) を終了").string(with: locale)
        fileMenu?.title = Localization(english: "File", japanese: "ファイル").string(with: locale)
        newItem?.title = Localization(english: "New", japanese: "新規").string(with: locale)
        openItem?.title = Localization(english: "Open…", japanese: "開く…").string(with: locale)
        saveAsItem?.title = Localization(english: "Save As…",
                                         japanese: "別名で保存…").string(with: locale)
        openRecentItem?.title = Localization(english: "Open Recent",
                                             japanese: "最近使った項目を開く").string(with: locale)
        closeItem?.title = Localization(english: "Close", japanese: "閉じる").string(with: locale)
        saveItem?.title = Localization(english: "Save…", japanese: "保存…").string(with: locale)
        windowMenu?.title = Localization(english: "Window", japanese: "ウインドウ").string(with: locale)
        minimizeItem?.title = Localization(english: "Minimize", japanese: "しまう").string(with: locale)
        zoomItem?.title = Localization(english: "Zoom", japanese: "拡大／縮小").string(with: locale)
        bringAllToFrontItem?.title = Localization(english: "Bring All to Front",
                                                  japanese: "すべてを手前に移動").string(with: locale)
    }
    
    @IBAction func readme(_ sender: Any?) {
        if let url = URL(string: "https://github.com/smdls/C0") {
            NSWorkspace.shared.open(url)
        }
    }
}

/**
 # Issue
 - NSDocument廃止
 */
final class C0Document: NSDocument, NSWindowDelegate {
    let rootDataModelKey = "root"
    var rootDataModel: DataModel {
        didSet {
            if let preferenceDataModel = rootDataModel.children[preferenceDataModelKey] {
                self.preferenceDataModel = preferenceDataModel
            } else {
                rootDataModel.insert(preferenceDataModel)
            }
        }
    }
    let preferenceDataModelKey = "preference"
    var preferenceDataModel: DataModel {
        didSet {
            if let preference: C0Preference = preferenceDataModel.readObject() {
                self.preference = preference
            }
            preferenceDataModel.didChangeIsWriteHandler = { [unowned self] (_, isWrite) in
                if isWrite {
                    self.updateChangeCount(.changeDone)
                }
            }
            preferenceDataModel.dataHandler = { [unowned self] in self.preference.jsonData }
        }
    }
    private var preference = C0Preference()
    
    var window: NSWindow {
        return windowControllers.first!.window!
    }
    weak var view: C0View!
    var desktop: Desktop {
        return view.desktopView.desktop
    }
    
    override init() {
        preferenceDataModel = DataModel(key: preferenceDataModelKey)
        rootDataModel = DataModel(key: rootDataModelKey, directoryWith: [preferenceDataModel])
        
        super.init()
        preferenceDataModel.didChangeIsWriteHandler = { [unowned self] (_, isWrite) in
            if isWrite {
                self.updateChangeCount(.changeDone)
            }
        }
        preferenceDataModel.dataHandler = { [unowned self] in self.preference.jsonData }
    }
    convenience init(type typeName: String) throws {
        self.init()
        fileType = typeName
    }
    
    override class var autosavesInPlace: Bool {
        return true
    }
    
    override func makeWindowControllers() {
        let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        let identifier = NSStoryboard.SceneIdentifier(rawValue: "Document Window Controller")
        let windowController = storyboard
            .instantiateController(withIdentifier: identifier) as! NSWindowController
        addWindowController(windowController)
        window.acceptsMouseMovedEvents = true
        view = windowController.contentViewController!.view as! C0View
        
        if let desktopDataModel = rootDataModel.children[view.desktopView.dataModelKey] {
            view.desktopView.dataModel = desktopDataModel
        } else {
            rootDataModel.insert(view.desktopView.dataModel)
        }
        
        if preference.windowFrame.isEmpty, let frame = NSScreen.main?.frame {
            let size = NSSize(width: 1132, height: 780)
            let origin = NSPoint(x: round((frame.width - size.width) / 2),
                                 y: round((frame.height - size.height) / 2))
            preference.windowFrame = NSRect(origin: origin, size: size)
        }
        setupWindow(with: preference)
        
        undoManager = view.desktopView.sceneView.undoManager
        
        let isWriteHandler: (DataModel, Bool) -> Void = { [unowned self] (_, isWrite) in
            if isWrite {
                self.updateChangeCount(.changeDone)
            }
        }
        view.desktopView.differentialDesktopDataModel.didChangeIsWriteHandler = isWriteHandler
        view.desktopView.sceneView.differentialSceneDataModel.didChangeIsWriteHandler = isWriteHandler
        preferenceDataModel.didChangeIsWriteHandler = isWriteHandler
        
        view.desktopView.undoManager?.disableUndoRegistration()
        view.desktopView.push(copiedObjects: NSPasteboard.general.copiedObjects)
        view.desktopView.undoManager?.enableUndoRegistration()
        
        view.desktopView.desktop.copiedObjectsBinding = { [unowned self] _ in
            self.didSetCopiedObjects()
        }
    }
    private func setupWindow(with preference: C0Preference) {
        window.setFrame(preference.windowFrame, display: false)
        if preference.isFullScreen {
            window.toggleFullScreen(nil)
        }
        window.delegate = self
    }
    
    override func fileWrapper(ofType typeName: String) throws -> FileWrapper {
        rootDataModel.writeAllFileWrappers()
        return rootDataModel.fileWrapper
    }
    override func read(from fileWrapper: FileWrapper, ofType typeName: String) throws {
        rootDataModel = DataModel(key: rootDataModelKey, fileWrapper: fileWrapper)
    }
    
    func windowDidResize(_ notification: Notification) {
        preference.windowFrame = window.frame
        preferenceDataModel.isWrite = true
    }
    func windowDidMove(_ notification: Notification) {
        preference.windowFrame = window.frame
        preferenceDataModel.isWrite = true
    }
    func windowDidEnterFullScreen(_ notification: Notification) {
        preference.isFullScreen = true
        preferenceDataModel.isWrite = true
    }
    func windowDidExitFullScreen(_ notification: Notification) {
        preference.isFullScreen = false
        preferenceDataModel.isWrite = true
    }
    
    func didSetCopiedObjects() {
        changeCountWithCopiedObjects += 1
    }
    var changeCountWithCopiedObjects = 0
    var oldChangeCountWithCopiedObjects = 0
    var oldChangeCountWithPsteboard = NSPasteboard.general.changeCount
    func windowDidBecomeMain(_ notification: Notification) {
        let pasteboard = NSPasteboard.general
        if pasteboard.changeCount != oldChangeCountWithPsteboard {
            oldChangeCountWithPsteboard = pasteboard.changeCount
            view.desktopView.push(copiedObjects: pasteboard.copiedObjects)
            oldChangeCountWithCopiedObjects = changeCountWithCopiedObjects
        }
    }
    func windowDidResignMain(_ notification: Notification) {
        if oldChangeCountWithCopiedObjects != changeCountWithCopiedObjects {
            oldChangeCountWithCopiedObjects = changeCountWithCopiedObjects
            let pasteboard = NSPasteboard.general
            pasteboard.set(copiedObjects: desktop.copiedObjects)
            oldChangeCountWithPsteboard = pasteboard.changeCount
        }
    }
    
    func openEmoji() {
        NSApp.orderFrontCharacterPalette(nil)
    }
}

extension NSPasteboard {
    var copiedObjects: [ViewExpression] {
        var copiedObjects = [ViewExpression]()
        func append(with data: Data, type: NSPasteboard.PasteboardType) {
            if let object = C0Coder.decode(from: data, forKey: type.rawValue) as? ViewExpression {
                copiedObjects.append(object)
            }
        }
        if let urls = readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            urls.forEach { copiedObjects.append($0) }
        }
        if let string = string(forType: .string) {
            copiedObjects.append(string)
        } else if let types = types {
            for type in types {
                if let data = data(forType: type) {
                    append(with: data, type: type)
                } else if let string = string(forType: .string) {
                    copiedObjects.append(string)
                }
            }
        } else if let items = pasteboardItems {
            for item in items {
                for type in item.types {
                    if let data = item.data(forType: type) {
                        append(with: data, type: type)
                    } else if let string = item.string(forType: .string) {
                        copiedObjects.append(string)
                    }
                }
            }
        }
        return copiedObjects
    }
    func set(copiedObjects: [ViewExpression]) {
        guard !copiedObjects.isEmpty else {
            clearContents()
            return
        }
        var strings = [String]()
        var typesAndDatas = [(type: NSPasteboard.PasteboardType, data: Data)]()
        for object in copiedObjects {
            if let string = object as? String {
                strings.append(string)
            } else {
                let type = C0Coder.typeKey(from: object)
                if let data = C0Coder.encode(object, forKey: type) {
                    typesAndDatas.append((NSPasteboard.PasteboardType(rawValue: type), data))
                }
            }
        }
        
        if strings.count == 1, let string = strings.first {
            declareTypes([.string], owner: nil)
            setString(string, forType: .string)
        } else if typesAndDatas.count == 1, let typeAndData = typesAndDatas.first {
            declareTypes([typeAndData.type], owner: nil)
            setData(typeAndData.data, forType: typeAndData.type)
        } else {
            var items = [NSPasteboardItem]()
            for string in strings {
                let item = NSPasteboardItem()
                item.setString(string, forType: .string)
                items.append(item)
            }
            for typeAndData in typesAndDatas {
                let item = NSPasteboardItem()
                item.setData(typeAndData.data, forType: typeAndData.type)
                items.append(item)
            }
            clearContents()
            writeObjects(items)
        }
    }
}

final class C0View: NSView, NSTextInputClient {
    let sender: Sender
    let desktopView = DesktopView()
    
    private let isHiddenActionManagerKey = "isHiddenActionManagerKey"
    private let isSimpleReferenceKey = "isSimpleReferenceKey"
    
    override init(frame frameRect: NSRect) {
        sender = Sender(rootView: desktopView,
                        actionManager: desktopView.actionManagerView.actionManager)
        super.init(frame: frameRect)
        setup()
    }
    required init?(coder: NSCoder) {
        sender = Sender(rootView: desktopView,
                        actionManager: desktopView.actionManagerView.actionManager)
        super.init(coder: coder)
        setup()
    }
    private var token: NSObjectProtocol?, localToken: NSObjectProtocol?
    func setup() {
        acceptsTouchEvents = true
        wantsLayer = true
        guard let layer = layer else {
            return
        }

        desktopView.desktop.isHiddenActionManager =
            UserDefaults.standard.bool(forKey: isHiddenActionManagerKey)
        desktopView.isHiddenActionManagerBinding = { [unowned self] in
            UserDefaults.standard.set($0, forKey: self.isHiddenActionManagerKey)
        }
        desktopView.desktop.isSimpleReference =
            UserDefaults.standard.bool(forKey: isSimpleReferenceKey)
        desktopView.isSimpleReferenceBinding = { [unowned self] in
            UserDefaults.standard.set($0, forKey: self.isSimpleReferenceKey)
        }
        
        desktopView.allChildrenAndSelf { $0.contentsScale = layer.contentsScale }
        sender.setCursorHandler = {
            if $0.cursor.nsCursor != NSCursor.current {
                $0.cursor.nsCursor.set()
            }
        }

        let nc = NotificationCenter.default
        localToken = nc.addObserver(forName: NSLocale.currentLocaleDidChangeNotification,
                                    object: nil,
                                    queue: nil) { [unowned self] _ in
                                        self.desktopView.locale = .current }
        token = nc.addObserver(forName: NSView.frameDidChangeNotification,
                               object: self,
                               queue: nil) { ($0.object as? C0View)?.updateFrame() }
    }

    override func makeBackingLayer() -> CALayer {
        return backingLayer(with: desktopView)
    }

    deinit {
        if let token = token {
            NotificationCenter.default.removeObserver(token)
        }
        if let localToken = localToken {
            NotificationCenter.default.removeObserver(localToken)
        }
    }

    override var acceptsFirstResponder: Bool {
        return true
    }
    override func becomeFirstResponder() -> Bool {
        return true
    }
    override func resignFirstResponder() -> Bool {
        return true
    }

    override func viewDidChangeBackingProperties() {
        if let backingScaleFactor = window?.backingScaleFactor {
            Screen.shared.backingScaleFactor = backingScaleFactor
            desktopView.contentsScale = backingScaleFactor
        }
    }

    func updateFrame() {
        desktopView.frame.size = bounds.size
    }

    func screenPoint(with event: NSEvent) -> CGPoint {
        return convertToLayer(convert(event.locationInWindow, from: nil))
    }
    var cursorPoint: CGPoint {
        guard let window = window else {
            return NSPoint()
        }
        let windowPoint = window.mouseLocationOutsideOfEventStream
        return convertToLayer(convert(windowPoint, from: nil))
    }
    func convertFromTopScreen(_ p: NSPoint) -> NSPoint {
        guard let window = window else {
            return NSPoint()
        }
        let windowPoint = window.convertFromScreen(NSRect(origin: p, size: NSSize())).origin
        return convertToLayer(convert(windowPoint, from: nil))
    }
    func convertToTopScreen(_ r: CGRect) -> NSRect {
        guard let window = window else {
            return NSRect()
        }
        return convertFromLayer(window.convertToScreen(convert(r, to: nil)))
    }

    func viewQuasimodeEventWith(_ sendType: Action.SendType, _ nsEvent: NSEvent) -> MoveCursorEvent {
        return MoveCursorEvent(sendType: sendType, location: cursorPoint,
                               time: nsEvent.timestamp, modifierKeys: nsEvent.modifierKeys, key: nil)
    }
    func moveEventWith(_ sendType: Action.SendType, _ nsEvent: NSEvent) -> MoveCursorEvent {
        return MoveCursorEvent(sendType: sendType, location: screenPoint(with: nsEvent),
                               time: nsEvent.timestamp, modifierKeys: nsEvent.modifierKeys, key: nil)
    }
    func dragEventWith(_ sendType: Action.SendType, _ nsEvent: NSEvent) -> DragEvent {
        return DragEvent(sendType: sendType, location: screenPoint(with: nsEvent),
                         time: nsEvent.timestamp, modifierKeys: nsEvent.modifierKeys, key: nil,
                         isPen: nsEvent.subtype == .tabletPoint,
                         pressure: nsEvent.pressure.cf)
    }
    func scrollEventWith(_ sendType: Action.SendType, _ nsEvent: NSEvent) -> ScrollEvent {
        return ScrollEvent(sendType: sendType, location: screenPoint(with: nsEvent),
                           time: nsEvent.timestamp, modifierKeys: nsEvent.modifierKeys, key: nil,
                           scrollDeltaPoint: CGPoint(x: nsEvent.scrollingDeltaX,
                                                     y: -nsEvent.scrollingDeltaY),
                           scrollMomentumType: nsEvent.scrollMomentumType,
                           beginNormalizedPosition: beginTouchesNormalizedPosition)
    }
    func pinchEventWith(_ sendType: Action.SendType, _ nsEvent: NSEvent) -> PinchEvent {
        return PinchEvent(sendType: sendType, location: screenPoint(with: nsEvent),
                          time: nsEvent.timestamp, modifierKeys: nsEvent.modifierKeys, key: nil,
                          magnification: nsEvent.magnification)
    }
    func rotateEventWith(_ sendType: Action.SendType, _ nsEvent: NSEvent) -> RotateEvent {
        return RotateEvent(sendType: sendType, location: screenPoint(with: nsEvent),
                           time: nsEvent.timestamp, modifierKeys: nsEvent.modifierKeys, key: nil,
                           rotation: nsEvent.rotation.cf)
    }
    func tapEventWith(_ sendType: Action.SendType, _ nsEvent: NSEvent) -> TapEvent {
        return TapEvent(sendType: sendType, location: screenPoint(with: nsEvent),
                        time: nsEvent.timestamp, modifierKeys: nsEvent.modifierKeys, key: nil)
    }
    func doubleTapEventWith(_ sendType: Action.SendType, _ nsEvent: NSEvent) -> DoubleTapEvent {
        return DoubleTapEvent(sendType: sendType, location: screenPoint(with: nsEvent),
                              time: nsEvent.timestamp, modifierKeys: nsEvent.modifierKeys, key: nil)
    }
    func keyInputEventWith(_ sendType: Action.SendType, _ nsEvent: NSEvent) -> KeyInputEvent {
        return KeyInputEvent(sendType: sendType, location: cursorPoint,
                             time: nsEvent.timestamp,
                             modifierKeys: nsEvent.modifierKeys, key: nsEvent.key)
    }

    override func flagsChanged(with event: NSEvent) {
        let viewQuasimode = viewQuasimodeEventWith(!event.modifierFlags.isEmpty ? .begin : .end, event)
        sender.sendViewQuasimode(with: viewQuasimode)
    }

    override func keyDown(with event: NSEvent) {
        keyInput(with: event, .begin)
    }
    override func keyUp(with event: NSEvent) {
        keyInput(with: event, .end)
    }
    private func keyInput(with event: NSEvent, _ sendType: Action.SendType) {
        if sender.sendKeyInputIsEditText(with: keyInputEventWith(sendType, event)) {
            inputContext?.handleEvent(event)
        }
    }

    override func cursorUpdate(with event: NSEvent) {
        sender.sendMoveCursor(with: moveEventWith(.sending, event))
        if sender.indicatedResponder.cursor.nsCursor != NSCursor.current {
            sender.indicatedResponder.cursor.nsCursor.set()
        }
    }
    override func mouseMoved(with event: NSEvent) {
        sender.sendMoveCursor(with: moveEventWith(.sending, event))
    }

    override func rightMouseDown(with nsEvent: NSEvent) {
        sender.sendSubDrag(with: dragEventWith(.begin, nsEvent))
    }
    override func rightMouseDragged(with nsEvent: NSEvent) {
        sender.sendSubDrag(with: dragEventWith(.sending, nsEvent))
    }
    override func rightMouseUp(with nsEvent: NSEvent) {
        sender.sendSubDrag(with: dragEventWith(.end, nsEvent))
    }

    override func mouseDown(with nsEvent: NSEvent) {
        sender.sendDrag(with: dragEventWith(.begin, nsEvent))
    }
    override func mouseDragged(with nsEvent: NSEvent) {
        sender.sendDrag(with: dragEventWith(.sending, nsEvent))
    }
    override func mouseUp(with nsEvent: NSEvent) {
        sender.sendDrag(with: dragEventWith(.end, nsEvent))
    }

    private var beginTouchesNormalizedPosition = CGPoint()
    override func touchesBegan(with event: NSEvent) {
        let touches = event.touches(matching: .began, in: self)
        beginTouchesNormalizedPosition = touches.reduce(CGPoint()) {
            return CGPoint(x: max($0.x, $1.normalizedPosition.x),
                           y: max($0.y, $1.normalizedPosition.y))
        }
    }

    override func scrollWheel(with event: NSEvent) {
        if event.phase != .mayBegin && event.phase != .cancelled {
            let momentum = event.momentumPhase == .changed || event.momentumPhase == .ended
            let sendType: Action.SendType = event.phase == .began ?
                .begin : (event.phase == .ended ? .end : .sending)
            sender.sendScroll(with: scrollEventWith(sendType, event), momentum: momentum)
        }
    }

    private enum TouchGesture {
        case none, scroll, pinch, rotate
    }
    private var blockGesture = TouchGesture.none
    override func magnify(with event: NSEvent) {
        if event.phase == .began {
            if blockGesture == .none {
                blockGesture = .pinch
                sender.sendPinch(with: pinchEventWith(.begin, event))
            }
        } else if event.phase == .ended {
            if blockGesture == .pinch {
                blockGesture = .none
                sender.sendPinch(with:pinchEventWith(.end, event))
            }
        } else {
            if blockGesture == .pinch {
                sender.sendPinch(with: pinchEventWith(.sending, event))
            }
        }
    }
    override func rotate(with event: NSEvent) {
        if event.phase == .began {
            if blockGesture == .none {
                blockGesture = .rotate
                sender.sendRotate(with: rotateEventWith(.begin, event))
            }
        } else if event.phase == .ended {
            if blockGesture == .rotate {
                blockGesture = .none
                sender.sendRotate(with: rotateEventWith(.end, event))
            }
        } else {
            if blockGesture == .rotate {
                sender.sendRotate(with: rotateEventWith(.sending, event))
            }
        }
    }

    override func quickLook(with event: NSEvent) {
        sender.sendTap(with: tapEventWith(.end, event))
    }
    override func smartMagnify(with event: NSEvent) {
        sender.sendDoubleTap(with: doubleTapEventWith(.end, event))
    }

    var editTextView: TextView? {
        return sender.editTextView
    }
    func hasMarkedText() -> Bool {
        return editTextView?.hasMarkedText ?? false
    }
    func markedRange() -> NSRange {
        return editTextView?.markedRange ?? NSRange(location: NSNotFound, length: 0)
    }
    func selectedRange() -> NSRange {
        return editTextView?.selectedRange ?? NSRange(location: NSNotFound, length: 0)
    }
    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        editTextView?.setMarkedText(string, selectedRange: selectedRange,
                                      replacementRange: replacementRange)
    }
    func unmarkText() {
        editTextView?.unmarkText()
    }
    func validAttributesForMarkedText() -> [NSAttributedStringKey] {
        return [.markedClauseSegment, .glyphInfo]
    }
    func attributedSubstring(forProposedRange range: NSRange,
                             actualRange: NSRangePointer?) -> NSAttributedString? {
        return editTextView?.attributedSubstring(forProposedRange: range, actualRange: actualRange)
    }
    func insertText(_ string: Any, replacementRange: NSRange) {
        editTextView?.insertText(string, replacementRange: replacementRange)
    }
    func characterIndex(for point: NSPoint) -> Int {
        if let editText = editTextView {
            let p = editText.convert(convertFromTopScreen(point), from: nil)
            return editText.characterIndex(for: p)
        } else {
            return 0
        }
    }
    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        if let editText = editTextView {
            let rect = editText.firstRect(forCharacterRange: range, actualRange: actualRange)
            return convertToTopScreen(editText.convert(rect, to: nil))
        } else {
            return NSRect()
        }
    }
    func attributedString() -> NSAttributedString {
        return editTextView?.attributedString ?? NSAttributedString()
    }
    func fractionOfDistanceThroughGlyph(for point: NSPoint) -> CGFloat {
        if let editText = editTextView {
            let p = editText.convert(convertFromTopScreen(point), from: nil)
            return editText.characterFraction(for: p)
        } else {
            return 0
        }
    }
    func baselineDeltaForCharacter(at anIndex: Int) -> CGFloat {
        return editTextView?.baselineDelta(at: anIndex) ?? 0
    }
    func windowLevel() -> Int {
        return window?.level.rawValue ?? 0
    }
    func drawsVerticallyForCharacter(at charIndex: Int) -> Bool {
        return false
    }

    override func insertNewline(_ sender: Any?) {
        editTextView?.insertNewline()
    }
    override func insertTab(_ sender: Any?) {
        editTextView?.insertTab()
    }
    override func deleteBackward(_ sender: Any?) {
        editTextView?.deleteBackward()
    }
    override func deleteForward(_ sender: Any?) {
        editTextView?.deleteForward()
    }
    override func moveLeft(_ sender: Any?) {
        editTextView?.moveLeft()
    }
    override func moveRight(_ sender: Any?) {
        editTextView?.moveRight()
    }
}

extension NSEvent {
    var scrollMomentumType: Action.SendType? {
        if momentumPhase.contains(.began) {
            return .begin
        } else if momentumPhase.contains(.changed) {
            return .sending
        } else if momentumPhase.contains(.ended) {
            return .end
        } else {
            return nil
        }
    }
    
    var modifierKeys: Quasimode.ModifierKeys {
        var modifierKeys: Quasimode.ModifierKeys = []
        if modifierFlags.contains(.shift) {
            modifierKeys.insert(.shift)
        }
        if modifierFlags.contains(.command) {
            modifierKeys.insert(.command)
        }
        if modifierFlags.contains(.control) {
            modifierKeys.insert(.control)
        }
        if modifierFlags.contains(.option) {
            modifierKeys.insert(.option)
        }
        return modifierKeys
    }
    
    var key: Quasimode.Key? {
        switch keyCode {
        case 0:
            return .a
        case 1:
            return .s
        case 2:
            return .d
        case 3:
            return .f
        case 4:
            return .h
        case 5:
            return .g
        case 6:
            return .z
        case 7:
            return .x
        case 8:
            return .c
        case 9:
            return .v
        case 11:
            return .b
        case 12:
            return .q
        case 13:
            return .w
        case 14:
            return .e
        case 15:
            return .r
        case 16:
            return .y
        case 17:
            return .t
        case 18:
            return .no1
        case 19:
            return .no2
        case 20:
            return .no3
        case 21:
            return .no4
        case 22:
            return .no6
        case 23:
            return .no5
        case 24:
            return .equals
        case 25:
            return .no9
        case 26:
            return .no7
        case 27:
            return .minus
        case 28:
            return .no8
        case 29:
            return .no0
        case 30:
            return .rightBracket
        case 31:
            return .o
        case 32:
            return .u
        case 33:
            return .leftBracket
        case 34:
            return .i
        case 35:
            return .p
        case 36:
            return .return
        case 37:
            return .l
        case 38:
            return .j
        case 39:
            return .apostrophe
        case 40:
            return .k
        case 41:
            return .semicolon
        case 42:
            return .frontslash
        case 43:
            return .comma
        case 44:
            return .backslash
        case 45:
            return .n
        case 46:
            return .m
        case 47:
            return .period
        case 48:
            return .tab
        case 49:
            return .space
        case 50:
            return .backApostrophe
        case 51:
            return .delete
        case 53:
            return .escape
        case 55:
            return .command
        case 56:
            return .shift
        case 58:
            return .option
        case 59:
            return .control
        case 123:
            return .left
        case 124:
            return .right
        case 125:
            return .down
        case 126:
            return .up
        default:
            return nil
        }
    }
}
