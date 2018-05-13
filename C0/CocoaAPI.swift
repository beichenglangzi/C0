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

struct Hash {
    static func uniformityHashValue(with hashValues: [Int]) -> Int {
        return Int(bitPattern: hashValues.reduce(into: UInt(bitPattern: 0), unionHashValues))
    }
    static func unionHashValues(_ lhs: inout UInt, _ rhs: Int) {
        #if arch(arm64) || arch(x86_64)
        let magicValue: UInt = 0x9e3779b97f4a7c15
        #else
        let magicValue: UInt = 0x9e3779b9
        #endif
        let urhs = UInt(bitPattern: rhs)
        lhs ^= urhs &+ magicValue &+ (lhs << 6) &+ (lhs >> 2)
    }
}

struct Font {
    static let small = Font(monospacedSize: 8)
    static let `default` = Font(monospacedSize: 11)
    static let smallBold = Font(boldMonospacedSize: 8)
    static let bold = Font(boldMonospacedSize: 11)
    static let smallItalic = Font(italicMonospacedSize: 8)
    static let italic = Font(italicMonospacedSize: 11)
    
    static let action = Font(boldMonospacedSize: 9)
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
    var size: Real {
        didSet {
            updateWith(name: name, size: size)
        }
    }
    private(set) var ascent: Real, descent: Real, leading: Real, ctFont: CTFont
    
    init(size: Real) {
        self.init(NSFont.systemFont(ofSize: size))
    }
    init(boldSize size: Real) {
        self.init(NSFont.boldSystemFont(ofSize: size))
    }
    init(monospacedSize size: Real) {
        self.init(NSFont.monospacedDigitSystemFont(ofSize: size, weight: .medium))
    }
    init(boldMonospacedSize size: Real) {
        self.init(NSFont.monospacedDigitSystemFont(ofSize: size, weight: .heavy))
    }
    init(italicMonospacedSize size: Real) {
        let font = NSFont.monospacedDigitSystemFont(ofSize: size, weight: .medium)
        self.init(NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask))
    }
    init(name: String, size: Real) {
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
    
    private mutating func updateWith(name: String, size: Real) {
        ctFont = CTFontCreateWithName(name as CFString, size, nil)
        ascent = CTFontGetAscent(ctFont)
        descent = -CTFontGetDescent(ctFont)
        leading = -CTFontGetLeading(ctFont)
    }
    
    func ceilHeight(withPadding padding: Real) -> Real {
        return ceil(ascent - descent) + padding * 2
    }
}

extension NSImage {
    convenience init(size: Size, closure: (CGContext) -> Void) {
        self.init(size: size)
        lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            closure(ctx)
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

protocol FileTypeProtocol {
    var utType: String { get }
}
extension URL {
    struct File {
        var url: URL, name: Text, isExtensionHidden: Bool
    }
    static func file(message: Text? = nil,
                     name: Text? = nil,
                     fileTypes: [FileTypeProtocol],
                     completionClosure closure: @escaping (URL.File) -> (Void)) {
        guard let window = NSApp.mainWindow else { return }
        let savePanel = NSSavePanel()
        savePanel.message = message?.currentString
        if let name = name {
            savePanel.nameFieldStringValue = name.currentString
        }
        savePanel.canSelectHiddenExtension = true
        savePanel.allowedFileTypes = fileTypes.map { $0.utType }
        savePanel.beginSheetModal(for: window) { [unowned savePanel] result in
            if result == .OK, let url = savePanel.url {
                closure(URL.File(url: url,
                                 name: Text(savePanel.nameFieldStringValue),
                                 isExtensionHidden: savePanel.isExtensionHidden))
            }
        }
    }
}

private struct C0Coder {
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
        case typeKey(from: KeyframeTiming.self):
            return try? decoder.decode(KeyframeTiming.self, from: data)
        case typeKey(from: Easing.self):
            return try? decoder.decode(Easing.self, from: data)
        case typeKey(from: Transform.self):
            return try? decoder.decode(Transform.self, from: data)
        case typeKey(from: Wiggle.self):
            return try? decoder.decode(Wiggle.self, from: data)
        case typeKey(from: Effect.self):
            return try? decoder.decode(Effect.self, from: data)
        case typeKey(from: Line.self):
            return try? decoder.decode(Line.self, from: data)
        case typeKey(from: Color.self):
            return try? decoder.decode(Color.self, from: data)
        case typeKey(from: URL.self):
            return try? decoder.decode(URL.self, from: data)
        case typeKey(from: Real.self):
            return try? decoder.decode(URL.self, from: data)
        case typeKey(from: Size.self):
            return try? decoder.decode(URL.self, from: data)
        case typeKey(from: Point.self):
            return try? decoder.decode(URL.self, from: data)
        case typeKey(from: Bool.self):
            return try? decoder.decode(URL.self, from: data)
        case typeKey(from: [Line].self):
            return try? decoder.decode([Line].self, from: data)
        default:
            return nil
        }
    }
    static func encode(_ object: Any, forKey key: String) -> Data? {
        if let codable = object as? [Line] {
            return codable.jsonData
        } else if object is [Action] {
            return nil
        } else if let codable = object as? Encodable {
            return codable.jsonData
        } else {
            return nil
        }
    }
}

private struct C0Preference: Codable {
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
        let localeClosure: (Notification) -> Void = { [unowned self] _ in
            self.updateString(with: Locale.current)
        }
        localToken = nc.addObserver(forName: NSLocale.currentLocaleDidChangeNotification,
                                    object: nil, queue: nil, using: localeClosure)
    }
    deinit {
        if let localToken = localToken {
            NotificationCenter.default.removeObserver(localToken)
        }
    }
    
    func updateString(with locale :Locale) {
        let appName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? "C0"
        aboutAppItem?.title = Text(english: "About \(appName)",
            japanese: "\(appName) について").string(with: locale)
        servicesItem?.title = Text(english: "Services", japanese: "サービス").string(with: locale)
        hideAppItem?.title = Text(english: "Hide \(appName)",
            japanese: "\(appName) を隠す").string(with: locale)
        hideOthersItem?.title = Text(english: "Hide Others", japanese: "ほかを隠す").string(with: locale)
        showAllItem?.title = Text(english: "Show All", japanese: "すべてを表示").string(with: locale)
        quitAppItem?.title = Text(english: "Quit \(appName)",
            japanese: "\(appName) を終了").string(with: locale)
        fileMenu?.title = Text(english: "File", japanese: "ファイル").string(with: locale)
        newItem?.title = Text(english: "New", japanese: "新規").string(with: locale)
        openItem?.title = Text(english: "Open…", japanese: "開く…").string(with: locale)
        saveAsItem?.title = Text(english: "Save As…", japanese: "別名で保存…").string(with: locale)
        openRecentItem?.title = Text(english: "Open Recent",
                                     japanese: "最近使った項目を開く").string(with: locale)
        closeItem?.title = Text(english: "Close", japanese: "閉じる").string(with: locale)
        saveItem?.title = Text(english: "Save…", japanese: "保存…").string(with: locale)
        windowMenu?.title = Text(english: "Window", japanese: "ウインドウ").string(with: locale)
        minimizeItem?.title = Text(english: "Minimize", japanese: "しまう").string(with: locale)
        zoomItem?.title = Text(english: "Zoom", japanese: "拡大／縮小").string(with: locale)
        bringAllToFrontItem?.title = Text(english: "Bring All to Front",
                                          japanese: "すべてを手前に移動").string(with: locale)
    }
    
    @IBAction func readme(_ sender: Any?) {
        if let url = URL(string: "https://github.com/smdls/C0") {
            NSWorkspace.shared.open(url)
        }
    }
}

/**
 Issue: NSDocument廃止
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
            if let preference = preferenceDataModel.readObject(type: C0Preference.self) {
                self.preference = preference
            }
            preferenceDataModel.didChangeIsWriteClosure = { [unowned self] (_, isWrite) in
                if isWrite {
                    self.updateChangeCount(.changeDone)
                }
            }
            preferenceDataModel.dataClosure = { [unowned self] in self.preference.jsonData }
        }
    }
    private var preference = C0Preference()
    
    var window: NSWindow {
        return windowControllers.first!.window!
    }
    weak var c0View: C0View!
    var desktop: Desktop {
        return c0View.desktopView.desktop
    }
    
    override init() {
        preferenceDataModel = DataModel(key: preferenceDataModelKey)
        rootDataModel = DataModel(key: rootDataModelKey, directoryWith: [preferenceDataModel])
        
        super.init()
        preferenceDataModel.didChangeIsWriteClosure = { [unowned self] (_, isWrite) in
            if isWrite {
                self.updateChangeCount(.changeDone)
            }
        }
        preferenceDataModel.dataClosure = { [unowned self] in self.preference.jsonData }
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
        c0View = windowController.contentViewController!.view as! C0View
        
        if let desktopDataModel = rootDataModel.children[c0View.desktopBinder.dataModelKey] {
            view.desktopBinder.dataModel = desktopDataModel
        } else {
            rootDataModel.insert(c0View.desktopBinder.dataModel)
        }
        
        if preference.windowFrame.isEmpty, let frame = NSScreen.main?.frame {
            let size = NSSize(width: 1132, height: 780)
            let origin = NSPoint(x: round((frame.width - size.width) / 2),
                                 y: round((frame.height - size.height) / 2))
            preference.windowFrame = NSRect(origin: origin, size: size)
        }
        setupWindow(with: preference)
        
        undoManager = c0View.desktopView.sceneView.binder.version
        
        let isWriteClosure: (DataModel, Bool) -> Void = { [unowned self] (_, isWrite) in
            if isWrite {
                self.updateChangeCount(.changeDone)
            }
        }
        c0View.desktopBinder.diffDesktopDataModel.didChangeIsWriteClosure = isWriteClosure
        preferenceDataModel.didChangeIsWriteClosure = isWriteClosure
        
        c0View.desktopView.push(copiedObjects: NSPasteboard.general.copiedObjects)
        c0View.desktopView.desktop.copiedObjectsBinding = { [unowned self] _ in
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
            c0View.desktopView.push(copiedObjects: pasteboard.copiedObjects)
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
    var copiedObjects: [Object] {
        var copiedObjects = [Object]()
        func append(with data: Data, type: NSPasteboard.PasteboardType) {
            let object = C0Coder.decode(from: data, forKey: type.rawValue)
            if let object = object as? [Line] {
                copiedObjects.append(object)
            } else if let object = object as? Object {
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
    func set(copiedObjects: [Object]) {
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

/**
 Issue: トラックパッドの環境設定を無効化
 */
final class C0View: NSView, NSTextInputClient {
    let sender: Sender
    let desktopBinder = DesktopBinder()
    let desktopView = DesktopView()
    
    private let isHiddenActionManagerKey = "isHiddenActionManagerKey"
    private let isSimpleReferenceKey = "isSimpleReferenceKey"
    
    override init(frame frameRect: NSRect) {
        sender = Sender(rootView: desktopView)
        super.init(frame: frameRect)
        setup()
    }
    required init?(coder: NSCoder) {
        sender = Sender(rootView: desktopView)
        super.init(coder: coder)
        setup()
    }
    private var token: NSObjectProtocol?, localToken: NSObjectProtocol?
    func setup() {
        acceptsTouchEvents = true
        wantsLayer = true
        guard let layer = layer else { return }
        
        desktopView.isHiddenActionManagerBinding = { [unowned self] in
            UserDefaults.standard.set($0, forKey: self.isHiddenActionManagerKey)
        }
        desktopView.update(withIsHiddenActionManager:
            UserDefaults.standard.bool(forKey: isHiddenActionManagerKey))
        desktopView.isSimpleReferenceBinding = { [unowned self] in
            UserDefaults.standard.set($0, forKey: self.isSimpleReferenceKey)
        }
        desktopView.update(withIsSimpleReference:
            UserDefaults.standard.bool(forKey: isSimpleReferenceKey))
        
        desktopView.allChildrenAndSelf { $0.contentsScale = layer.contentsScale }
        
        sender.indicatableActionManager.indicatedViewBinding = { [unowned self] in
            self.didSet($0.indicatedView, oldIndicatedView: $0.oldIndicatedView)
        }
        desktopView.changedFrame = { [unowned self] in
            self.sender.indicatableActionManager.updateIndicatedView(with: $0, in: self.desktopView)
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
    
    func screenPoint(with event: NSEvent) -> Point {
        return convertToLayer(convert(event.locationInWindow, from: nil))
    }
    var cursorPoint: Point {
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
    func convertToTopScreen(_ r: Rect) -> NSRect {
        guard let window = window else {
            return NSRect()
        }
        return convertFromLayer(window.convertToScreen(convert(r, to: nil)))
    }
    
    func draggerEventWith(pointing nsEvent: NSEvent, _ phase: Phase, _ version: Version) -> Dragger.Event {
        return Dragger.Event(rootLocation: screenPoint(with: nsEvent), time: nsEvent.timestamp.cg,
                             pressure: 1, phase: phase)
    }
    func draggerEventWith(_ nsEvent: NSEvent, _ phase: Phase, _ version: Version) -> Dragger.Event {
        return Dragger.Event(rootLocation: screenPoint(with: nsEvent), time: nsEvent.timestamp.cg,
                             pressure: Real(nsEvent.pressure), phase: phase)
    }
    func scrollerEventWith(_ nsEvent: NSEvent, _ phase: Phase, _ version: Version) -> Scroller.Event {
        var scrollMomentumPhase: Phase? {
            if nsEvent.momentumPhase.contains(.began) {
                return .began
            } else if nsEvent.momentumPhase.contains(.changed) {
                return .changed
            } else if nsEvent.momentumPhase.contains(.ended) {
                return .ended
            } else {
                return nil
            }
        }
        return Scroller.Event(rootLocation: screenPoint(with: nsEvent),
                              time: nsEvent.timestamp.cg,
                              scrollDeltaPoint: Point(x: nsEvent.scrollingDeltaX,
                                                      y: -nsEvent.scrollingDeltaY),
                              phase: phase,
                              momentumPhase: scrollMomentumPhase)
    }
    func pincherEventWith(_ nsEvent: NSEvent, _ phase: Phase, _ version: Version) -> Pincher.Event {
        return Pincher.Event(rootLocation: screenPoint(with: nsEvent), time: nsEvent.timestamp.cg,
                             magnification: nsEvent.magnification, phase: phase)
    }
    func rotaterEventWith(_ nsEvent: NSEvent, _ phase: Phase, _ version: Version) -> Rotater.Event {
        return Rotater.Event(rootLocation: screenPoint(with: nsEvent), time: nsEvent.timestamp.cg,
                             rotationQuantity: Real(nsEvent.rotation), phase: phase)
    }
    func inputterEventWith(_ nsEvent: NSEvent, _ phase: Phase, _ version: Version) -> Inputter.Event {
        return Inputter.Event(rootLocation: cursorPoint, time: nsEvent.timestamp.cg,
                              pressure: 1, phase: phase)
    }
    
    func didSet(_ indicatedView: View?, oldIndicatedView: View?) {
        if let editTextView = oldIndicatedView as? TextView {
            editTextView.unmarkText()
        }
    }
    
    override func flagsChanged(with nsEvent: NSEvent) {
        let newInputterTypes = nsEvent.modifierKeys, oldInputters = sender.eventMap.inputters
        newInputterTypes.forEach { newInputterType in
            if !oldInputters.contains(where: { newInputterType == $0.type }) {
                sender.send(Inputter(type: newInputterType, event: inputterEventWith(nsEvent, .began)))
            }
        }
        oldInputters.forEach { oldInptter in
            if !newInputterTypes.contains(where: { oldInptter.type == $0 }) {
                sender.send(Inputter(type: oldInptter.type, event: inputterEventWith(nsEvent, .ended)))
            }
        }
    }
    
    override func keyDown(with nsEvent: NSEvent) {
        guard !nsEvent.isARepeat else { return }
        if let key = nsEvent.key {
            sender.send(Inputter(type: key, event: inputterEventWith(nsEvent, .began)))
        }
    }
    override func keyUp(with nsEvent: NSEvent) {
        if let key = nsEvent.key {
            sender.send(Inputter(type: key, event: inputterEventWith(nsEvent, .ended)))
        }
    }
    
    override func cursorUpdate(with nsEvent: NSEvent) {
        mouseMoved(with: nsEvent)
    }
    override func mouseMoved(with nsEvent: NSEvent) {
        sender.send(Dragger(type: .pointing, event: draggerEventWith(pointing: nsEvent, .began)))
    }
    
    override func rightMouseDown(with nsEvent: NSEvent) {
        sender.send(Dragger(type: .subDrag, event: draggerEventWith(nsEvent, .began)))
    }
    override func rightMouseDragged(with nsEvent: NSEvent) {
        sender.send(Dragger(type: .subDrag, event: draggerEventWith(nsEvent, .changed)))
    }
    override func rightMouseUp(with nsEvent: NSEvent) {
        sender.send(Dragger(type: .subDrag, event: draggerEventWith(nsEvent, .ended)))
        sender.send(Dragger(type: .pointing, event: draggerEventWith(pointing: nsEvent, .began)))
    }
    
    private var workItem: DispatchWorkItem?
    private var beginDragger: Dragger?
    var clickTime = 0.2
    override func mouseDown(with nsEvent: NSEvent) {
        sender.send(Dragger(type: .pointing, event: draggerEventWith(pointing: nsEvent, .began)))
        let beginDragger = Dragger(type: .drag, event: draggerEventWith(nsEvent, .began))
        self.beginDragger = beginDragger
        let workItem = DispatchWorkItem() { [unowned self] in
            self.sender.send(beginDragger)
            self.workItem?.cancel()
            self.workItem = nil
        }
        self.workItem = workItem
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + clickTime, execute: workItem)
    }
    override func mouseDragged(with nsEvent: NSEvent) {
        sender.send(Dragger(type: .pointing, event: draggerEventWith(pointing: nsEvent, .began)))
        if workItem != nil {
            workItem?.perform()
        }
        sender.send(Dragger(type: .drag, event: draggerEventWith(nsEvent, .changed)))
    }
    override func mouseUp(with nsEvent: NSEvent) {
        let endDragger = Dragger(type: .drag, event: draggerEventWith(nsEvent, .ended))
        if workItem != nil {
            workItem?.cancel()
            self.workItem = nil
            
            guard let beginDragger = beginDragger else { return }
            if beginDragger.event.rootLocation != endDragger.event.rootLocation {
                sender.send(Dragger(type: .pointing,
                                    event: draggerEventWith(pointing: nsEvent, .began)))
                sender.send(beginDragger)
                sender.send(endDragger)
            } else {
                func clickInputterWith(_ dragger: Dragger, _ phase: Phase, _ version: Version) -> Inputter {
                    return Inputter(type: .click,
                                    event: Inputter.Event(rootLocation: dragger.event.rootLocation,
                                                          time: dragger.event.time,
                                                          pressure: dragger.event.pressure,
                                                          phase: phase))
                }
                sender.send(clickInputterWith(beginDragger, .began))
                sender.send(clickInputterWith(beginDragger, .ended))
            }
        } else {
            sender.send(Dragger(type: .pointing, event: draggerEventWith(pointing: nsEvent, .began)))
            sender.send(endDragger)
        }
    }
    
    private var beginTouchesNormalizedPosition = Point()
    override func touchesBegan(with nsEvent: NSEvent) {
        let touches = nsEvent.touches(matching: .began, in: self)
        beginTouchesNormalizedPosition = touches.reduce(Point()) {
            return Point(x: max($0.x, $1.normalizedPosition.x),
                         y: max($0.y, $1.normalizedPosition.y))
        }
    }
    override func touchesEnded(with event: NSEvent) {
        beginTouchesNormalizedPosition = Point()
    }
    
    override func scrollWheel(with nsEvent: NSEvent) {
        guard nsEvent.phase != .mayBegin && nsEvent.phase != .cancelled else { return }
        let phase: Phase = nsEvent.phase == .began ?
            .began : (nsEvent.phase == .ended ? .ended : .changed)
        let type: Scroller.EventType = beginTouchesNormalizedPosition.y > 0.85 ?
            .upperScroll : .scroll
        switch phase {
        case .began:
            sender.send(Scroller(type: type, event: scrollerEventWith(nsEvent, .began)))
        case .changed:
            sender.send(Scroller(type: type, event: scrollerEventWith(nsEvent, .changed)))
        case .ended:
            sender.send(Scroller(type: type, event: scrollerEventWith(nsEvent, .ended)))
        }
    }
    
    private enum TouchGesture {
        case none, scroll, pinch, rotate
    }
    private var blockGesture = TouchGesture.none
    override func magnify(with nsEvent: NSEvent) {
        if nsEvent.phase == .began {
            if blockGesture == .none {
                blockGesture = .pinch
                sender.send(Pincher(type: .pinch, event: pincherEventWith(nsEvent, .began)))
            }
        } else if nsEvent.phase == .ended {
            if blockGesture == .pinch {
                blockGesture = .none
                sender.send(Pincher(type: .pinch, event: pincherEventWith(nsEvent, .ended)))
            }
        } else {
            if blockGesture == .pinch {
                sender.send(Pincher(type: .pinch, event: pincherEventWith(nsEvent, .changed)))
            }
        }
    }
    override func rotate(with nsEvent: NSEvent) {
        if nsEvent.phase == .began {
            if blockGesture == .none {
                blockGesture = .rotate
                sender.send(Rotater(type: .rotate, event: rotaterEventWith(nsEvent, .began)))
            }
        } else if nsEvent.phase == .ended {
            if blockGesture == .rotate {
                blockGesture = .none
                sender.send(Rotater(type: .rotate, event: rotaterEventWith(nsEvent, .ended)))
            }
        } else {
            if blockGesture == .rotate {
                sender.send(Rotater(type: .rotate, event: rotaterEventWith(nsEvent, .changed)))
            }
        }
    }
    
    override func quickLook(with nsEvent: NSEvent) {
        sender.send(Inputter(type: .tap, event: inputterEventWith(nsEvent, .began)))
        sender.send(Inputter(type: .tap, event: inputterEventWith(nsEvent, .ended)))
    }
    
    func sentKeyInput() {
        if let nsEvent = NSApp.currentEvent {
            inputContext?.handleEvent(nsEvent)
        }
    }
    var editTextView: TextView? {
        return sender.indicatableActionManager.indicatedView as? TextView
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
            let p = editText.convertFromRoot(convertFromTopScreen(point))
            return editText.editCharacterIndex(for: p)
        } else {
            return 0
        }
    }
    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        if let editText = editTextView {
            let rect = editText.firstRect(forCharacterRange: range, actualRange: actualRange)
            return convertToTopScreen(editText.convertToRoot(rect))
        } else {
            return NSRect()
        }
    }
    func attributedString() -> NSAttributedString {
        return editTextView?.attributedString ?? NSAttributedString()
    }
    func fractionOfDistanceThroughGlyph(for point: NSPoint) -> Real {
        if let editText = editTextView {
            let p = editText.convertFromRoot(convertFromTopScreen(point))
            return editText.characterFraction(for: p)
        } else {
            return 0
        }
    }
    func baselineDeltaForCharacter(at anIndex: Int) -> Real {
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

extension URL {
    func isConforms(type otherType: String) -> Bool {
        if let type = type {
            return UTTypeConformsTo(type as CFString, otherType as CFString)
        } else {
            return false
        }
    }
}

extension NSEvent {
    var modifierKeys: [Inputter.EventType] {
        var modifierKeys = [Inputter.EventType]()
        if modifierFlags.contains(.shift) {
            modifierKeys.append(.shift)
        }
        if modifierFlags.contains(.command) {
            modifierKeys.append(.command)
        }
        if modifierFlags.contains(.control) {
            modifierKeys.append(.control)
        }
        if modifierFlags.contains(.option) {
            modifierKeys.append(.option)
        }
        return modifierKeys
    }
    
    var key: Inputter.EventType? {
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
