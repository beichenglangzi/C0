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

struct Layout {
    static let smallPadding = 2.0.cf, basicPadding = 3.0.cf, basicLargePadding = 14.0.cf
    static let basicHeight = Font.default.ceilHeight(withPadding: 1) + basicPadding * 2
    static let smallHeight = Font.small.ceilHeight(withPadding: 1) + smallPadding * 2
    static let valueWidth = 56.cf
    static let valueFrame = CGRect(x: 0, y: basicPadding, width: valueWidth, height: basicHeight)
    
    static func centered(_ layers: [Layer],
                         in bounds: CGRect, paddingWidth: CGFloat = 0) {
        
        let w = layers.reduce(-paddingWidth) { $0 +  $1.frame.width + paddingWidth }
        _ = layers.reduce(floor((bounds.width - w) / 2)) { x, layer in
            layer.frame.origin.x = x
            return x + layer.frame.width + paddingWidth
        }
    }
    static func leftAlignmentWidth(_ layers: [Layer], minX: CGFloat = basicPadding,
                                   paddingWidth: CGFloat = 0) -> CGFloat {
        return layers.reduce(minX) { $0 + $1.frame.width + paddingWidth } - paddingWidth
    }
    static func leftAlignment(_ layers: [Layer], minX: CGFloat = basicPadding,
                              y: CGFloat = 0, paddingWidth: CGFloat = 0) {
        _ = layers.reduce(minX) { x, layer in
            layer.frame.origin = CGPoint(x: x, y: y)
            return x + layer.frame.width + paddingWidth
        }
    }
    static func leftAlignment(_ layers: [Layer], minX: CGFloat = basicPadding,
                              y: CGFloat = 0, height: CGFloat, paddingWidth: CGFloat = 0) -> CGSize {
        let width = layers.reduce(minX) { x, layer in
            layer.frame.origin = CGPoint(x: x, y: y + round((height - layer.frame.height) / 2))
            return x + layer.frame.width + paddingWidth
        }
        return CGSize(width: width, height: height)
    }
    static func topAlignment(_ layers: [Layer],
                             minX: CGFloat = basicPadding, minY: CGFloat = basicPadding,
                             minSize: inout CGSize, padding: CGFloat = Layout.basicPadding) {
        
        let width = layers.reduce(0.0.cf) { max($0, $1.defaultBounds.width) } + padding * 2
        let height = layers.reversed().reduce(minY) { y, layer in
            layer.frame = CGRect(x: minX, y: y,
                                  width: width, height: layer.defaultBounds.height)
            return y + layer.frame.height
        }
        minSize = CGSize(width: width, height: height - minY)
    }
    static func autoHorizontalAlignment(_ layers: [Layer],
                                        padding: CGFloat = 0, in bounds: CGRect) {
        
        guard !layers.isEmpty else {
            return
        }
        let w = layers.reduce(0.0.cf) { $0 +  $1.defaultBounds.width + padding } - padding
        let dx = (bounds.width - w) / layers.count.cf
        _ = layers.enumerated().reduce(bounds.minX) { x, value in
            if value.offset == layers.count - 1 {
                value.element.frame = CGRect(x: x, y: bounds.minY,
                                             width: bounds.maxX - x, height: bounds.height)
                return bounds.maxX
            } else {
                value.element.frame = CGRect(x: x,
                                             y: bounds.minY,
                                             width: round(value.element.defaultBounds.width + dx),
                                             height: bounds.height)
                return x + value.element.frame.width + padding
            }
        }
    }
}
final class Padding: View {
    static let name = Localization(english: "Padding", japanese: "パディング")
    override init() {
        super.init()
        self.frame = CGRect(origin: CGPoint(),
                            size: CGSize(width: Layout.basicPadding, height: Layout.basicPadding))
    }
}

extension Data {
    var bytesString: String {
        return ByteCountFormatter().string(fromByteCount: Int64(count))
    }
}

extension URL {
    func isConforms(uti: String) -> Bool {
        if let aUTI = self.uti {
            return UTTypeConformsTo(aUTI as CFString, uti as CFString)
        } else {
            return false
        }
    }
    var uti: String? {
        return (try? resourceValues(forKeys: Set([URLResourceKey.typeIdentifierKey])))?
            .typeIdentifier
    }
    init?(bookmark: Data?) {
        guard let bookmark = bookmark else {
            return nil
        }
        do {
            var bookmarkDataIsStale = false
            guard let url = try URL(resolvingBookmarkData: bookmark,
                                    bookmarkDataIsStale: &bookmarkDataIsStale) else {
                                        return nil
            }
            self = url
        } catch {
            return nil
        }
    }
}
extension URL: Referenceable {
    static var  name: Localization {
        return Localization("URL")
    }
}
extension URL: ViewExpression {
    func view(withBounds bounds: CGRect, isSmall: Bool) -> View {
        let thumbnailView = lastPathComponent.view(withBounds: bounds, isSmall: isSmall)
        return ObjectView(object: self, thumbnailView: thumbnailView, minFrame: bounds,
                          isSmall : isSmall)
    }
}

final class LockTimer {
    private var count = 0
    private(set) var wait = false
    func begin(endDuration: Second, beginHandler: () -> Void,
               waitHandler: () -> Void, endHandler: @escaping () -> Void) {
        if wait {
            waitHandler()
            count += 1
        } else {
            beginHandler()
            wait = true
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + endDuration) {
            if self.count == 0 {
                endHandler()
                self.wait = false
            } else {
                self.count -= 1
            }
        }
    }
    private(set) var inUse = false
    private weak var timer: Timer?
    func begin(interval: Second, repeats: Bool = true,
               tolerance: Second = 0.0, handler: @escaping () -> Void) {
        let time = interval + CFAbsoluteTimeGetCurrent()
        let timer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault,
                                                    time, repeats ? interval : 0, 0, 0) { _ in
                                                        handler()
        }
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, .commonModes)
        self.timer = timer
        inUse = true
        self.timer?.tolerance = tolerance
    }
    func stop() {
        inUse = false
        timer?.invalidate()
        timer = nil
    }
}

final class Weak<T: AnyObject> {
    weak var value : T?
    init (value: T) {
        self.value = value
    }
}

final class ObjectView: View {
    static let name = Localization(english: "Object", japanese: "オブジェクト")
    var instanceDescription: Localization {
        return (object as? Referenceable)?.instanceDescription ?? Localization()
    }
    
    let object: Any
    
    var isSmall: Bool
    let classNameLabel: Label, thumbnailView: Layer
    init(object: Any, thumbnailView: Layer?, minFrame: CGRect, thumbnailWidth: CGFloat = 40.0,
         isSmall: Bool = false) {
        self.object = object
        if let reference = object as? Referenceable {
            classNameLabel = Label(text: type(of: reference).name, font: isSmall ? .smallBold : .bold)
        } else {
            classNameLabel = Label(text: Localization(String(describing: type(of: object))),
                                   font: isSmall ? .smallBold : .bold)
        }
        self.thumbnailView = thumbnailView ?? Box()
        self.isSmall = isSmall
        
        super.init()
        let width = max(minFrame.width, classNameLabel.frame.width + thumbnailWidth)
        self.frame = CGRect(origin: minFrame.origin,
                            size: CGSize(width: width, height: minFrame.height))
        replace(children: [classNameLabel, self.thumbnailView])
        updateLayout()
    }
    
    override var locale: Locale {
        didSet {
            updateLayout()
        }
    }
    
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    func updateLayout() {
        let padding = isSmall ? Layout.smallPadding : Layout.basicPadding
        classNameLabel.frame.origin = CGPoint(x: padding,
                                              y: bounds.height - classNameLabel.frame.height - padding)
        thumbnailView.frame = CGRect(x: classNameLabel.frame.maxX + padding,
                                     y: padding,
                                     width: bounds.width - classNameLabel.frame.width - padding * 3,
                                     height: bounds.height - padding * 2)
    }
    func copiedObjects(with event: KeyInputEvent) -> [Any]? {
        return [object]
    }
}

final class Progress: View {
    let barLayer = Layer()
    let barBackgroundLayer = Layer()
    let nameLabel: Label
    
    init(frame: CGRect = CGRect(), backgroundColor: Color = .background,
         name: String = "", type: String = "", state: Localization? = nil) {
        
        self.name = name
        self.type = type
        self.state = state
        nameLabel = Label()
        nameLabel.frame.origin = CGPoint(x: Layout.basicPadding,
                                         y: round((frame.height - nameLabel.frame.height) / 2))
        barLayer.frame = CGRect(x: 0, y: 0, width: 0, height: frame.height)
        barBackgroundLayer.fillColor = .editing
        barLayer.fillColor = .content
        
        super.init()
        self.frame = frame
        isClipped = true
        replace(children: [nameLabel, barBackgroundLayer, barLayer])
        updateLayout()
    }
    
    var value = 0.0.cf {
        didSet {
            updateLayout()
        }
    }
    func begin() {
        startDate = Date()
    }
    func end() {}
    var startDate: Date?
    var remainingTime: Double? {
        didSet {
            updateString(with: Locale.current)
        }
    }
    var computationTime = 5.0
    var name = "" {
        didSet {
            updateString(with: locale)
        }
    }
    var type = "" {
        didSet {
            updateString(with: locale)
        }
    }
    var state: Localization? {
        didSet {
            updateString(with: locale)
        }
    }
    
    override var locale: Locale {
        didSet {
            updateLayout()
        }
    }
    
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    func updateLayout() {
        let padding = Layout.basicPadding
        barBackgroundLayer.frame = CGRect(x: padding, y: padding - 1,
                                          width: (bounds.width - padding * 2), height: 1)
        barLayer.frame = CGRect(x: padding, y: padding - 1,
                                width: floor((bounds.width - padding * 2) * value), height: 1)
        updateString(with: locale)
    }
    func updateString(with locale: Locale) {
        var string = ""
        if let state = state {
            string += state.string(with: locale)
        } else if let remainingTime = remainingTime {
            let minutes = Int(ceil(remainingTime)) / 60
            let seconds = Int(ceil(remainingTime)) - minutes * 60
            if minutes == 0 {
                let translator = Localization(english: "%@sec left",
                                              japanese: "あと%@秒").string(with: locale)
                string += (string.isEmpty ? "" : " ") + String(format: translator, String(seconds))
            } else {
                let translator = Localization(english: "%@min %@sec left",
                                              japanese: "あと%@分%@秒").string(with: locale)
                string += (string.isEmpty ? "" : " ") + String(format: translator,
                                                               String(minutes), String(seconds))
            }
        }
        nameLabel.string = type + "(" + name + "), "
            + string + (string.isEmpty ? "" : ", ") + "\(Int(value * 100)) %"
        nameLabel.frame.origin = CGPoint(x: Layout.basicPadding,
                                         y: round((frame.height - nameLabel.frame.height) / 2))
    }
    
    var deleteHandler: ((Progress) -> (Bool))?
    weak var operation: Operation?
    func delete(with event: KeyInputEvent) -> Bool {
        if let operation = operation {
            operation.cancel()
        }
        return deleteHandler?(self) ?? false
    }
    
    func lookUp(with event: TapEvent) -> Reference? {
        return Reference(name: Localization(english: "Progress", japanese: "進捗"),
                         viewDescription: Localization(english: "Stop: Send \"Cut\" action",
                                                       japanese: "停止: \"カット\"アクションを送信"))
    }
}

final class Drager {
    private var downPosition = CGPoint(), oldFrame = CGRect()
    func drag(with event: DragEvent, _ layer: Layer, in parent: Layer) {
        let p = parent.point(from: event)
        switch event.sendType {
        case .begin:
            downPosition = p
            oldFrame = layer.frame
        case .sending:
            let dp =  p - downPosition
            layer.frame.origin = CGPoint(x: oldFrame.origin.x + dp.x,
                                         y: oldFrame.origin.y + dp.y)
        case .end:
            let dp =  p - downPosition
            layer.frame.origin = CGPoint(x: round(oldFrame.origin.x + dp.x),
                                         y: round(oldFrame.origin.y + dp.y))
        }
    }
}
final class Scroller {
    func scroll(with event: ScrollEvent, layer: Layer) {
        layer.frame.origin += event.scrollDeltaPoint
    }
}

final class Knob: Layer {
    init(radius: CGFloat = 5, lineWidth: CGFloat = 1) {
        super.init()
        fillColor = .knob
        lineColor = .border
        self.lineWidth = lineWidth
        self.radius = radius
    }
    var radius: CGFloat {
        get {
            return min(bounds.width, bounds.height) / 2
        }
        set {
            frame = CGRect(x: position.x - newValue, y: position.y - newValue,
                           width: newValue * 2, height: newValue * 2)
            cornerRadius = newValue
        }
    }
}
final class DiscreteKnob: Layer {
    init(_ size: CGSize = CGSize(width: 5, height: 10), lineWidth: CGFloat = 1) {
        super.init()
        fillColor = .knob
        lineColor = .border
        self.lineWidth = lineWidth
        frame.size = size
    }
}
