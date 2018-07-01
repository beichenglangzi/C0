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

struct Hash {//swift 4.2
    static func uniformityHashValue(with hashValues: [Int]) -> Int {
        return Int(bitPattern: hashValues.reduce(into: UInt(bitPattern: 0),
                                                 unionHashValues))
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

private struct C0Preference: Codable {
    var isFullScreen = false
    var windowFrame = NSRect()
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
        Object.appendTypes()
        
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

final class TestDocument {
    let documentURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    init() {
        let fileURL = documentURL.appendingPathComponent("C0Database.c0db")
        try? FileWrapper().write(to: fileURL, options: .withNameUpdating, originalContentsURL: nil)
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
            if let preference = preferenceDataModel.readObject(C0Preference.self) {
                preferenceDataModel.stopIsWriteClosure {
                    self.preference = preference
                }
            }
            preferenceDataModel.didChangeIsWriteClosure = { [unowned self] (_, isWrite) in
                self.updateChangeCount(.changeDone)
            }
            preferenceDataModel.dataClosure = { [unowned self] in self.preference.jsonData }
        }
    }
    private var preference = C0Preference() {
        didSet { preferenceDataModel.isWrite = true }
    }
    
    var window: NSWindow {
        return windowControllers.first!.window!
    }
    weak var c0View: C0View!
    var desktop: Desktop {
        return c0View.desktopView.model
    }
    
    override init() {
        preferenceDataModel = DataModel(key: preferenceDataModelKey)
        rootDataModel = DataModel(key: rootDataModelKey, directoryWith: [preferenceDataModel])
        
        super.init()
        preferenceDataModel.didChangeIsWriteClosure = { [unowned self] (_, isWrite) in
            self.updateChangeCount(.changeDone)
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
        c0View = windowController.contentViewController!.view as? C0View
        
        if let desktopDataModel = rootDataModel.children[c0View.desktopBinder.dataModelKey] {
            c0View.desktopBinder.dataModel = desktopDataModel
            c0View.desktopView.updateWithModel()
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
        
        let isWriteClosure: (DataModel, Bool) -> Void = { [unowned self] (_, _) in
            self.updateChangeCount(.changeDone)
        }
        c0View.desktopBinder.dataModel.didChangeIsWriteClosure = isWriteClosure
        c0View.desktopBinder.diffDesktopDataModel.didChangeIsWriteClosure = isWriteClosure
        preferenceDataModel.didChangeIsWriteClosure = isWriteClosure
        
        c0View.desktopBinder.diffDesktopDataModel.isWrite = false
        
        c0View.desktopView.copiedObjectsView.valuesView.push(NSPasteboard.general.copiedObjects,
                                                             to: c0View.desktopView.version)
        c0View.desktopView.copiedObjectsView.notifications.append({ [unowned self] _, _ in
            self.didSetCopiedObjects()
        })
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
    }
    func windowDidMove(_ notification: Notification) {
        preference.windowFrame = window.frame
    }
    func windowDidEnterFullScreen(_ notification: Notification) {
        preference.isFullScreen = true
    }
    func windowDidExitFullScreen(_ notification: Notification) {
        preference.isFullScreen = false
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
            c0View.desktopView.copiedObjectsView.valuesView.push(pasteboard.copiedObjects,
                                                                 to: c0View.desktopView.version)
            oldChangeCountWithCopiedObjects = changeCountWithCopiedObjects
        }
    }
    func windowDidResignMain(_ notification: Notification) {
        if oldChangeCountWithCopiedObjects != changeCountWithCopiedObjects {
            oldChangeCountWithCopiedObjects = changeCountWithCopiedObjects
            let pasteboard = NSPasteboard.general
            pasteboard.set(copiedObjects: desktop.copiedObjects.values)
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
            if Object.contains(type.rawValue),
                let object = try? JSONDecoder().decode(Object.self, from: data) {
                
                copiedObjects.append(object)
            }
        }
        if let urls = readObjects(forClasses: [NSURL.self],
                                  options: nil) as? [URL], !urls.isEmpty {
            urls.forEach {
                if let image = Image(url: $0) {
                    copiedObjects.append(Object(image))
                } else {
                    copiedObjects.append(Object($0))
                }
            }
        }
        if !copiedObjects.isEmpty {
            return copiedObjects
        } else if let string = string(forType: .string) {
            copiedObjects.append(Object(string))
        } else if let types = types {
            for type in types {
                if let data = data(forType: type) {
                    append(with: data, type: type)
                } else if let string = string(forType: .string) {
                    copiedObjects.append(Object(string))
                }
            }
        } else if let items = pasteboardItems {
            for item in items {
                for type in item.types {
                    if let data = item.data(forType: type) {
                        append(with: data, type: type)
                    } else if let string = item.string(forType: .string) {
                        copiedObjects.append(Object(string))
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
            if let string = object.value as? String {
                strings.append(string)
            } else {
                let typeName = object.value.objectTypeName
                if let data = object.jsonData {
                    let pasteboardType = NSPasteboard.PasteboardType(rawValue: typeName)
                    typesAndDatas.append((pasteboardType, data))
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

protocol CocoaKeyInputtable {
    var markedRange: NSRange { get }
    var selectedRange: NSRange { get }
    var attributedString: NSAttributedString { get }
    var hasMarkedText: Bool { get }
    func editingCharacterIndex(for p: Point) -> Int
    func characterIndex(for p: Point) -> Int
    func characterFraction(for p: Point) -> Real
    func characterOffset(for p: Point) -> Real
    func baselineDelta(at i: Int) -> Real
    func firstRect(forCharacterRange range: NSRange,
                   actualRange: NSRangePointer?) -> Rect
    func definition(characterIndex: Int) -> String?
    func insertNewline()
    func insertTab()
    func deleteBackward()
    func deleteForward()
    func moveLeft()
    func moveRight()
    func deleteCharacters(in range: NSRange)
    func setMarkedText(_ string: Any, selectedRange: NSRange,
                       replacementRange: NSRange)
    func unmarkText()
    func attributedSubstring(forProposedRange range: NSRange,
                             actualRange: NSRangePointer?) -> NSAttributedString?
    func insertText(_ string: Any, replacementRange: NSRange)
}

/**
 Issue: トラックパッドの環境設定を無効化
 */
final class C0View: NSView, NSTextInputClient {
    let sender: Sender
    let desktopBinder: DesktopBinder
    let desktopView: DesktopView<DesktopBinder>
    
    private let isHiddenActionListKey = "isHiddenActionListKey"
    
    override init(frame frameRect: NSRect) {
        fatalError()
    }
    required init?(coder: NSCoder) {
        let desktop = Desktop()
        desktopBinder = DesktopBinder(rootModel: desktop)
        desktopView = DesktopView(binder: desktopBinder, keyPath: \DesktopBinder.rootModel)
        desktopView.objectsView.valuesView.newableValue = Scene()
        sender = Sender(rootView: desktopView)
        
        dragManager = DragManager(sender: sender, clickType: .click, dragType: .drag)
        subDragManager = DragManager(sender: sender, clickType: .subClick, dragType: .subDrag)
        super.init(coder: coder)
        setup()
    }
    private var token: NSObjectProtocol?, localToken: NSObjectProtocol?
    func setup() {
        acceptsTouchEvents = true
        wantsLayer = true
        guard let layer = layer else { return }
        
        desktopView.allChildrenAndSelf { $0.contentsScale = layer.contentsScale }
        
        desktopView.isHiddenActionListView.notifications.append({ [unowned self] view, _ in
            UserDefaults.standard.set(view.model,
                                      forKey: self.isHiddenActionListKey)
        })
        desktopView.model.isHiddenActionList
            = UserDefaults.standard.bool(forKey: isHiddenActionListKey)
        
        let nc = NotificationCenter.default
        localToken = nc.addObserver(forName: NSLocale.currentLocaleDidChangeNotification,
                                    object: nil,
                                    queue: nil) { [unowned self] _ in
                                        self.sender.locale = .current }
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
        desktopView.bounds = bounds
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
    
    func dragEventValueWith(pointing nsEvent: NSEvent) -> DragEvent.Value {
        return DragEvent.Value(rootLocation: screenPoint(with: nsEvent),
                               time: nsEvent.timestamp.cg,
                               pressure: 1, phase: .changed)
    }
    func dragEventValueWith(_ nsEvent: NSEvent, _ phase: Phase) -> DragEvent.Value {
        return DragEvent.Value(rootLocation: screenPoint(with: nsEvent),
                               time: nsEvent.timestamp.cg,
                               pressure: Real(nsEvent.pressure), phase: phase)
    }
    func scrollEventValueWith(_ nsEvent: NSEvent, _ phase: Phase) -> ScrollEvent.Value {
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
        return ScrollEvent.Value(rootLocation: screenPoint(with: nsEvent),
                                 time: nsEvent.timestamp.cg,
                                 scrollDeltaPoint: Point(x: nsEvent.scrollingDeltaX,
                                                         y: -nsEvent.scrollingDeltaY),
                                 phase: phase,
                                 momentumPhase: scrollMomentumPhase)
    }
    func pinchEventValueWith(_ nsEvent: NSEvent, _ phase: Phase) -> PinchEvent.Value {
        return PinchEvent.Value(rootLocation: screenPoint(with: nsEvent),
                                time: nsEvent.timestamp.cg,
                                magnification: nsEvent.magnification, phase: phase)
    }
    func rotateEventValueWith(_ nsEvent: NSEvent, _ phase: Phase) -> RotateEvent.Value {
        return RotateEvent.Value(rootLocation: screenPoint(with: nsEvent),
                                 time: nsEvent.timestamp.cg,
                                 rotationQuantity: Real(nsEvent.rotation), phase: phase)
    }
    func inputEventValueWith(_ nsEvent: NSEvent, _ phase: Phase) -> InputEvent.Value {
        return InputEvent.Value(rootLocation: cursorPoint,
                                time: nsEvent.timestamp.cg,
                                pressure: 1, phase: phase)
    }
    
    func didSet(_ indicatedView: View?, oldIndicatedView: View?) {
        if let editStringView = oldIndicatedView as? CocoaKeyInputtable {
            editStringView.unmarkText()
        }
    }
    
    override func flagsChanged(with nsEvent: NSEvent) {
        let inputEventTypes = nsEvent.modifierKeys
        let oldInputEvents = sender.eventMap.events(InputEvent.self)
        inputEventTypes.forEach { inputEventType in
            if !oldInputEvents.contains(where: { inputEventType == $0.type }) {
                sender.send(InputEvent(type: inputEventType,
                                       value: inputEventValueWith(nsEvent, .began)))
            }
        }
        oldInputEvents.forEach { oldInputEvent in
            if !inputEventTypes.contains(where: { oldInputEvent.type == $0 }) {
                sender.send(InputEvent(type: oldInputEvent.type,
                                       value: inputEventValueWith(nsEvent, .ended)))
            }
        }
    }
    
    override func keyDown(with nsEvent: NSEvent) {
        guard !nsEvent.isARepeat else { return }
        if let key = nsEvent.key {
            sender.send(InputEvent(type: key, value: inputEventValueWith(nsEvent, .began)))
        }
    }
    override func keyUp(with nsEvent: NSEvent) {
        if let key = nsEvent.key {
            sender.send(InputEvent(type: key, value: inputEventValueWith(nsEvent, .ended)))
        }
    }
    
    override func cursorUpdate(with nsEvent: NSEvent) {
        super.cursorUpdate(with: nsEvent)
        mouseMoved(with: nsEvent)
    }
    override func mouseMoved(with nsEvent: NSEvent) {
        sender.sendPointing(dragEventValueWith(pointing: nsEvent))
    }
    
    private final class DragManager {
        var sender: Sender
        let clickTime: TimeInterval
        let clickType: InputEvent.EventType, dragType: DragEvent.EventType
        
        init(sender: Sender,
             clickTime: TimeInterval = 0.2,
             clickType: InputEvent.EventType, dragType: DragEvent.EventType) {
            
            self.sender = sender
            self.clickTime = clickTime
            self.clickType = clickType
            self.dragType = dragType
        }
        
        private var workItem: DispatchWorkItem?, beganDragEvent: DragEvent?
        
        func mouseDown(with nsEvent: NSEvent, _ view: C0View) {
            sender.sendPointing(view.dragEventValueWith(pointing: nsEvent))
            let beganDragEvent = DragEvent(type: dragType,
                                           value: view.dragEventValueWith(nsEvent, .began))
            self.beganDragEvent = beganDragEvent
            let workItem = DispatchWorkItem() { [unowned self] in
                self.sender.send(beganDragEvent)
                self.workItem?.cancel()
                self.workItem = nil
            }
            self.workItem = workItem
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + clickTime,
                                          execute: workItem)
        }
        func mouseDragged(with nsEvent: NSEvent, _ view: C0View) {
            sender.sendPointing(view.dragEventValueWith(pointing: nsEvent))
            if workItem != nil {
                workItem?.perform()
            }
            sender.send(DragEvent(type: dragType,
                                  value: view.dragEventValueWith(nsEvent, .changed)))
        }
        func mouseUp(with nsEvent: NSEvent, _ view: C0View) {
            let endedDragEvent = DragEvent(type: dragType,
                                           value: view.dragEventValueWith(nsEvent, .ended))
            if workItem != nil {
                workItem?.cancel()
                self.workItem = nil
                
                guard let beganDragEvent = beganDragEvent else { return }
                if beganDragEvent.value.rootLocation != endedDragEvent.value.rootLocation {
                    sender.sendPointing(view.dragEventValueWith(pointing: nsEvent))
                    sender.send(beganDragEvent)
                    sender.send(endedDragEvent)
                } else {
                    func clickEventWith(_ dragEvent: DragEvent, _ phase: Phase) -> InputEvent {
                        let value = InputEvent.Value(rootLocation: dragEvent.value.rootLocation,
                                                     time: dragEvent.value.time,
                                                     pressure: dragEvent.value.pressure,
                                                     phase: phase)
                        return InputEvent(type: clickType, value: value)
                    }
                    sender.send(clickEventWith(beganDragEvent, .began))
                    sender.send(clickEventWith(beganDragEvent, .ended))
                }
            } else {
                sender.sendPointing(view.dragEventValueWith(pointing: nsEvent))
                sender.send(endedDragEvent)
            }
        }
    }
    
    private let subDragManager: DragManager
    
    override func rightMouseDown(with nsEvent: NSEvent) {
        subDragManager.mouseDown(with: nsEvent, self)
    }
    override func rightMouseDragged(with nsEvent: NSEvent) {
        subDragManager.mouseDragged(with: nsEvent, self)
    }
    override func rightMouseUp(with nsEvent: NSEvent) {
        subDragManager.mouseUp(with: nsEvent, self)
    }
    
    private let dragManager: DragManager
    
    override func mouseDown(with nsEvent: NSEvent) {
        sender.sendPointing(dragEventValueWith(pointing: nsEvent))
        sender.send(DragEvent(type: .drag, value: dragEventValueWith(nsEvent, .began)))
    }
    override func mouseDragged(with nsEvent: NSEvent) {
        sender.sendPointing(dragEventValueWith(pointing: nsEvent))
        sender.send(DragEvent(type: .drag, value: dragEventValueWith(nsEvent, .changed)))
    }
    override func mouseUp(with nsEvent: NSEvent) {
        sender.send(DragEvent(type: .drag, value: dragEventValueWith(nsEvent, .ended)))
        sender.sendPointing(dragEventValueWith(pointing: nsEvent))
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
        let type: ScrollEvent.EventType = beginTouchesNormalizedPosition.y > 0.85 ?
            .upperScroll : .scroll
        switch phase {
        case .began:
            sender.send(ScrollEvent(type: type,
                                    value: scrollEventValueWith(nsEvent, .began)))
        case .changed:
            sender.send(ScrollEvent(type: type,
                                    value: scrollEventValueWith(nsEvent, .changed)))
        case .ended:
            sender.send(ScrollEvent(type: type,
                                    value: scrollEventValueWith(nsEvent, .ended)))
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
                sender.send(PinchEvent(type: .pinch,
                                       value: pinchEventValueWith(nsEvent, .began)))
            }
        } else if nsEvent.phase == .ended {
            if blockGesture == .pinch {
                blockGesture = .none
                sender.send(PinchEvent(type: .pinch,
                                       value: pinchEventValueWith(nsEvent, .ended)))
            }
        } else {
            if blockGesture == .pinch {
                sender.send(PinchEvent(type: .pinch,
                                       value: pinchEventValueWith(nsEvent, .changed)))
            }
        }
    }
    override func rotate(with nsEvent: NSEvent) {
        if nsEvent.phase == .began {
            if blockGesture == .none {
                blockGesture = .rotate
                sender.send(RotateEvent(type: .rotate,
                                        value: rotateEventValueWith(nsEvent, .began)))
            }
        } else if nsEvent.phase == .ended {
            if blockGesture == .rotate {
                blockGesture = .none
                sender.send(RotateEvent(type: .rotate,
                                        value: rotateEventValueWith(nsEvent, .ended)))
            }
        } else {
            if blockGesture == .rotate {
                sender.send(RotateEvent(type: .rotate,
                                        value: rotateEventValueWith(nsEvent, .changed)))
            }
        }
    }
    
    override func quickLook(with nsEvent: NSEvent) {
        sender.send(InputEvent(type: .tap, value: inputEventValueWith(nsEvent, .began)))
        sender.send(InputEvent(type: .tap, value: inputEventValueWith(nsEvent, .ended)))
    }
    
    func sentKeyInput() {
        if let nsEvent = NSApp.currentEvent {
            inputContext?.handleEvent(nsEvent)
        }
    }
    var indicatedVView: View {
        return sender.mainIndicatedView
    }
    var editingStringView: CocoaKeyInputtable? {
        return indicatedVView as? CocoaKeyInputtable
    }
    func hasMarkedText() -> Bool {
        return editingStringView?.hasMarkedText ?? false
    }
    func markedRange() -> NSRange {
        return editingStringView?.markedRange ?? NSRange(location: NSNotFound, length: 0)
    }
    func selectedRange() -> NSRange {
        return editingStringView?.selectedRange ?? NSRange(location: NSNotFound, length: 0)
    }
    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        editingStringView?.setMarkedText(string, selectedRange: selectedRange,
                                         replacementRange: replacementRange)
    }
    func unmarkText() {
        editingStringView?.unmarkText()
    }
    func validAttributesForMarkedText() -> [NSAttributedStringKey] {
        return [.markedClauseSegment, .glyphInfo]
    }
    func attributedSubstring(forProposedRange range: NSRange,
                             actualRange: NSRangePointer?) -> NSAttributedString? {
        return editingStringView?.attributedSubstring(forProposedRange: range,
                                                      actualRange: actualRange)
    }
    func insertText(_ string: Any, replacementRange: NSRange) {
        editingStringView?.insertText(string, replacementRange: replacementRange)
    }
    func characterIndex(for point: NSPoint) -> Int {
        if let stringView = editingStringView {
            let p = indicatedVView.convertFromRoot(convertFromTopScreen(point))
            return stringView.editingCharacterIndex(for: p)
        } else {
            return 0
        }
    }
    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        if let stringView = editingStringView {
            let rect = stringView.firstRect(forCharacterRange: range, actualRange: actualRange)
            return convertToTopScreen(indicatedVView.convertToRoot(rect))
        } else {
            return NSRect()
        }
    }
    func attributedString() -> NSAttributedString {
        return editingStringView?.attributedString ?? NSAttributedString()
    }
    func fractionOfDistanceThroughGlyph(for point: NSPoint) -> Real {
        if let stringView = editingStringView {
            let p = indicatedVView.convertFromRoot(convertFromTopScreen(point))
            return stringView.characterFraction(for: p)
        } else {
            return 0
        }
    }
    func baselineDeltaForCharacter(at anIndex: Int) -> Real {
        return editingStringView?.baselineDelta(at: anIndex) ?? 0
    }
    func windowLevel() -> Int {
        return window?.level.rawValue ?? 0
    }
    func drawsVerticallyForCharacter(at charIndex: Int) -> Bool {
        return false
    }
    
    override func insertNewline(_ sender: Any?) {
        editingStringView?.insertNewline()
    }
    override func insertTab(_ sender: Any?) {
        editingStringView?.insertTab()
    }
    override func deleteBackward(_ sender: Any?) {
        editingStringView?.deleteBackward()
    }
    override func deleteForward(_ sender: Any?) {
        editingStringView?.deleteForward()
    }
    override func moveLeft(_ sender: Any?) {
        editingStringView?.moveLeft()
    }
    override func moveRight(_ sender: Any?) {
        editingStringView?.moveRight()
    }
}

extension CTFont {
    static func systemFont(ofSize size: Real) -> CTFont {
        return NSFont.systemFont(ofSize: size)
    }
    static func boldSystemFont(ofSize size: Real) -> CTFont {
        return NSFont.boldSystemFont(ofSize: size)
    }
    static func monospacedSystemFont(ofSize size: Real) -> CTFont {
        return NSFont.monospacedDigitSystemFont(ofSize: size, weight: .medium)
    }
    static func boldMonospacedSystemFont(ofSize size: Real) -> CTFont {
        return NSFont.monospacedDigitSystemFont(ofSize: size, weight: .heavy)
    }
    static func italicMonospacedSystemFont(ofSize size: Real) -> CTFont {
        let font = NSFont.monospacedDigitSystemFont(ofSize: size, weight: .medium)
        return NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
    }
    static func boldItalicMonospacedSystemFont(ofSize size: Real) -> CTFont {
        let font = NSFont.monospacedDigitSystemFont(ofSize: size, weight: .heavy)
        return NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
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
        
        var attributes: [FileAttributeKey: Any] {
            return [.extensionHidden: isExtensionHidden]
        }
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
    var modifierKeys: [InputEvent.EventType] {
        var modifierKeys = [InputEvent.EventType]()
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
    
    var key: InputEvent.EventType? {
        switch keyCode {
        case 0: return .a
        case 1: return .s
        case 2: return .d
        case 3: return .f
        case 4: return .h
        case 5: return .g
        case 6: return .z
        case 7: return .x
        case 8: return .c
        case 9: return .v
        case 11: return .b
        case 12: return .q
        case 13: return .w
        case 14: return .e
        case 15: return .r
        case 16: return .y
        case 17: return .t
        case 18: return .no1
        case 19: return .no2
        case 20: return .no3
        case 21: return .no4
        case 22: return .no6
        case 23: return .no5
        case 24: return .equals
        case 25: return .no9
        case 26: return .no7
        case 27: return .minus
        case 28: return .no8
        case 29: return .no0
        case 30: return .rightBracket
        case 31: return .o
        case 32: return .u
        case 33: return .leftBracket
        case 34: return .i
        case 35: return .p
        case 36: return .return
        case 37: return .l
        case 38: return .j
        case 39: return .apostrophe
        case 40: return .k
        case 41: return .semicolon
        case 42: return .frontslash
        case 43: return .comma
        case 44: return .backslash
        case 45: return .n
        case 46: return .m
        case 47: return .period
        case 48: return .tab
        case 49: return .space
        case 50: return .backApostrophe
        case 51: return .delete
        case 53: return .escape
        case 55: return .command
        case 56: return .shift
        case 58: return .option
        case 59: return .control
        case 123: return .left
        case 124: return .right
        case 125: return .down
        case 126: return .up
        default: return nil
        }
    }
}
