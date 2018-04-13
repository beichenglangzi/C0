/*
 Copyright 2018 S
 
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

final class SubtitleTrack: NSObject, Track, NSCoding {
    private(set) var animation: Animation
    
    let subtitleItem: SubtitleItem
    
    var time: Beat {
        didSet {
            updateInterpolation()
            updateDrawSubtitle()
        }
    }
    func updateInterpolation() {
        animation.update(withTime: time, to: self)
    }
    func step(_ f0: Int) {
        subtitleItem.step(f0)
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        subtitleItem.linear(f0, f1, t: t)
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        subtitleItem.firstMonospline(f1, f2, f3, with: ms)
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        subtitleItem.monospline(f0, f1, f2, f3, with: ms)
    }
    func lastMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with ms: Monospline) {
        subtitleItem.lastMonospline(f0, f1, f2, with: ms)
    }
    
    private(set) var drawSubtitle = Subtitle()
    func updateDrawSubtitle() {
        var count = 0
        for subtitle in subtitleItem.keySubtitles[(animation.editKeyframeIndex + 1)...] {
            if subtitle.isConnectedWithPrevious {
                count += 1
            } else {
                break
            }
        }
        let editSubtitle = subtitleItem.keySubtitles[animation.editKeyframeIndex]
        guard count > 0 || editSubtitle.isConnectedWithPrevious else {
            drawSubtitle = editSubtitle
            return
        }
        var string = editSubtitle.string
        if animation.editKeyframeIndex > 0 {
            for i in (1...animation.editKeyframeIndex).reversed() {
                let subtitle = subtitleItem.keySubtitles[i]
                if subtitle.isConnectedWithPrevious {
                    string = subtitleItem.keySubtitles[i - 1].string + "\n" + string
                } else {
                    break
                }
            }
        }
        (0..<count).forEach { _ in string += "\n" }
        drawSubtitle = Subtitle(string: string, isConnectedWithPrevious: false)
    }
    
    init(animation: Animation = Animation(), time: Beat = 0,
         subtitleItem: SubtitleItem = SubtitleItem()) {
        guard animation.keyframes.count == subtitleItem.keySubtitles.count else {
            fatalError()
        }
        self.animation = animation
        self.time = time
        self.subtitleItem = subtitleItem
        super.init()
        updateDrawSubtitle()
    }
    
    private enum CodingKeys: String, CodingKey {
        case animation, time, subtitleItem
    }
    init?(coder: NSCoder) {
        animation = coder.decodeDecodable(
            Animation.self, forKey: CodingKeys.animation.rawValue) ?? Animation()
        time = coder.decodeDecodable(Beat.self, forKey: CodingKeys.time.rawValue) ?? 0
        subtitleItem = coder.decodeObject(
            forKey: CodingKeys.subtitleItem.rawValue) as? SubtitleItem ?? SubtitleItem()
        super.init()
        if animation.keyframes.count < subtitleItem.keySubtitles.count {
            subtitleItem.keySubtitles = Array(subtitleItem.keySubtitles[..<animation.keyframes.count])
        } else if animation.keyframes.count > subtitleItem.keySubtitles.count {
            let count = animation.keyframes.count - subtitleItem.keySubtitles.count
            let subtitles = (0..<count).map { _ in Subtitle() }
            subtitleItem.keySubtitles += subtitles
        }
    }
    func encode(with coder: NSCoder) {
        coder.encodeEncodable(animation, forKey: CodingKeys.animation.rawValue)
        coder.encodeEncodable(time, forKey: CodingKeys.time.rawValue)
        coder.encode(subtitleItem, forKey: CodingKeys.subtitleItem.rawValue)
    }
    
    func replace(_ keyframe: Keyframe, at index: Int) {
        animation.keyframes[index] = keyframe
    }
    func replace(_ keyframes: [Keyframe]) {
        check(keyCount: keyframes.count)
        animation.keyframes = keyframes
    }
    func replace(duration: Beat) {
        animation.duration = duration
    }
    func replace(_ keyframes: [Keyframe], duration: Beat) {
        check(keyCount: keyframes.count)
        animation.keyframes = keyframes
        animation.duration = duration
    }
    func set(selectedkeyframeIndexes: [Int]) {
        animation.selectedKeyframeIndexes = selectedkeyframeIndexes
    }
    
    private func check(keyCount count: Int) {
        guard count == animation.keyframes.count else {
            fatalError()
        }
    }
    
    struct KeyframeValues: KeyframeValue {
        var subtitle: Subtitle
    }
    func insert(_ keyframe: Keyframe, _ kv: KeyframeValues, at index: Int) {
        subtitleItem.keySubtitles.insert(kv.subtitle, at: index)
        animation.keyframes.insert(keyframe, at: index)
        updateDrawSubtitle()
    }
    func removeKeyframe(at index: Int) {
        animation.keyframes.remove(at: index)
        subtitleItem.keySubtitles.remove(at: index)
        updateDrawSubtitle()
    }
    func set(_ keySubtitles: [Subtitle], isSetSubtitleInItem: Bool  = true) {
        guard keySubtitles.count == animation.keyframes.count else {
            fatalError()
        }
        if isSetSubtitleInItem {
            subtitleItem.subtitle = keySubtitles[animation.editKeyframeIndex]
        }
        subtitleItem.keySubtitles = keySubtitles
    }
    func replace(_ subtitle: Subtitle, at i: Int) {
        subtitleItem.replace(subtitle, at: i)
        updateDrawSubtitle()
    }
    var currentItemValues: KeyframeValues {
        return KeyframeValues(subtitle: subtitleItem.subtitle)
    }
    func keyframeItemValues(at index: Int) -> KeyframeValues {
        return KeyframeValues(subtitle: subtitleItem.keySubtitles[index])
    }
}
extension SubtitleTrack: ClassCopiable {
    func copied(from copier: Copier) -> SubtitleTrack {
        return SubtitleTrack(animation: animation, time: time, subtitleItem: copier.copied(subtitleItem))
    }
}
extension SubtitleTrack: Referenceable {
    static let name = Localization(english: "Subtitle Track", japanese: "字幕トラック")
}

final class SubtitleItem: NSObject, TrackItem, NSCoding {
    fileprivate(set) var keySubtitles: [Subtitle]
    var subtitle: Subtitle
    
    func replace(_ subtitle: Subtitle, at i: Int) {
        keySubtitles[i] = subtitle
        self.subtitle = subtitle
    }
    
    func step(_ f0: Int) {
        subtitle = keySubtitles[f0]
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        subtitle = keySubtitles[f0]
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        subtitle = keySubtitles[f1]
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        subtitle = keySubtitles[f1]
    }
    func lastMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with ms: Monospline) {
        subtitle = keySubtitles[f1]
    }
    
    init(keySubtitles: [Subtitle] = [], subtitle: Subtitle = Subtitle()) {
        if keySubtitles.isEmpty {
            self.keySubtitles = [subtitle]
        } else {
            self.keySubtitles = keySubtitles
        }
        self.subtitle = subtitle
        super.init()
    }
    
    private enum CodingKeys: String, CodingKey {
        case keySubtitles, subtitle
    }
    init?(coder: NSCoder) {
        keySubtitles = coder.decodeDecodable([Subtitle].self,
                                             forKey: CodingKeys.keySubtitles.rawValue) ?? []
        subtitle = coder.decodeDecodable(Subtitle.self,
                                         forKey: CodingKeys.subtitle.rawValue) ?? Subtitle()
        super.init()
        if keySubtitles.isEmpty {
            keySubtitles = [subtitle]
        }
    }
    func encode(with coder: NSCoder) {
        coder.encodeEncodable(keySubtitles, forKey: CodingKeys.keySubtitles.rawValue)
        coder.encodeEncodable(subtitle, forKey: CodingKeys.subtitle.rawValue)
    }
    
    var isEmpty: Bool {
        for t in keySubtitles {
            if !t.isEmpty {
                return false
            }
        }
        return true
    }
}
extension SubtitleItem: ClassCopiable {
    func copied(from copier: Copier) -> SubtitleItem {
        return SubtitleItem(keySubtitles: keySubtitles, subtitle: subtitle)
    }
}
extension SubtitleItem: Referenceable {
    static let name = Localization(english: "Subtitle Item", japanese: "字幕アイテム")
}

struct Subtitle: Codable, Equatable {
    struct Option {
        var borderColor = Color.subtitleBorder, fillColor = Color.subtitleFill
        var font = Font.subtitle
    }
    var string = ""
    var isConnectedWithPrevious = false
    var vttString: String {
        return string
    }
    var isEmpty: Bool {
        return string.isEmpty
    }
    func draw(bounds: CGRect, with option: Option = Option(), in ctx: CGContext) {
        guard !string.isEmpty else {
            return
        }
        let attributes: [NSAttributedStringKey : Any] = [
            NSAttributedStringKey(rawValue: String(kCTFontAttributeName)): option.font.ctFont,
            NSAttributedStringKey(rawValue: String(kCTForegroundColorFromContextAttributeName)): true
            ]
        let attString = NSAttributedString(string: string, attributes: attributes)
        let framesetter = CTFramesetterCreateWithAttributedString(attString)
        let range = CFRange(location: 0, length: attString.length), ratio = bounds.size.width/640
        let size = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, range, nil,
                                                                CGSize(width: CGFloat.infinity,
                                                                       height: CGFloat.infinity), nil)
        let lineBounds = CGRect(origin: CGPoint(), size: size)
        let ctFrame = CTFramesetterCreateFrame(framesetter, range,
                                               CGPath(rect: lineBounds, transform: nil), nil)
        ctx.saveGState()
        ctx.setAllowsFontSmoothing(false)
        ctx.translateBy(x: round(bounds.midX - lineBounds.midX),  y: round(bounds.minY + 20 * ratio))
        ctx.setTextDrawingMode(.stroke)
        ctx.setLineWidth(ceil(3 * ratio))
        ctx.setStrokeColor(option.borderColor.cgColor)
        CTFrameDraw(ctFrame, ctx)
        ctx.setTextDrawingMode(.fill)
        ctx.setFillColor(option.fillColor.cgColor)
        CTFrameDraw(ctFrame, ctx)
        ctx.restoreGState()
    }
    
    static func vttStringWith(_ subtitleTuples: [(time: Beat, duration: Beat, subtitle: Subtitle)],
                              timeClosure: (Beat) -> (Second)) -> String {
        return subtitleTuples.reduce(into: "WEBVTT") {
            guard !$1.subtitle.isEmpty else {
                return
            }
            let beginTime = timeClosure($1.time), endTime = timeClosure($1.time + $1.duration)
            func timeString(withSecond second: Double) -> String {
                let s = Int(second)
                let mm = s / 60
                let ss = second - Second(mm * 60)
                let secondString = String(format: "%06.3f", ss)
                if mm >= 60 {
                    let hh = Int(mm / 60)
                    let nmm = mm - hh * 60
                    return String(format: "%02d:%02d:", hh, nmm) + secondString
                } else {
                    return String(format: "%02d:", mm) + secondString
                }
            }
            $0 += "\n\n"
            $0 += "\(timeString(withSecond: beginTime)) --> \(timeString(withSecond: endTime))\n"
            $0 += $1.subtitle.vttString
        }
    }
    static func vtt(_ subtitleTuples: [(time: Beat, duration: Beat, subtitle: Subtitle)],
                    timeClosure: (Beat) -> (Second)) -> Data? {
        return vttStringWith(subtitleTuples, timeClosure: timeClosure).data(using: .utf8)
    }
}
extension Subtitle: Referenceable {
    static let name = Localization(english: "Subtitle", japanese: "字幕")
}
extension Subtitle: ObjectViewExpression {
    func thumbnail(withBounds bounds: CGRect, sizeType: SizeType) -> Layer {
        return string.view(withBounds: bounds, sizeType: sizeType)
    }
}

final class SubtitleView: View {
    var subtitle = Subtitle() {
        didSet {
            isConnectedWithPreviousView.bool = subtitle.isConnectedWithPrevious
        }
    }
    
    var sizeType: SizeType
    private let classNameView: TextView
    private let isConnectedWithPreviousView: BoolView
    init(sizeType: SizeType = .regular) {
        self.sizeType = sizeType
        classNameView = TextView(text: Subtitle.name, font: Font.bold(with: sizeType))
        isConnectedWithPreviousView = BoolView(cationBool: true,
                                               name: Localization(english: "No Connected With Previous",
                                                                  japanese: "前と結合なし"),
                                               sizeType: sizeType)
        super.init()
        replace(children: [classNameView, isConnectedWithPreviousView])
        
        isConnectedWithPreviousView.binding = { [unowned self] in
            self.setIsConnectedWithPrevious(with: $0)
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
    private func updateLayout() {
        let padding = Layout.padding(with: sizeType)
        classNameView.frame.origin = CGPoint(x: padding,
                                              y: bounds.height - classNameView.frame.height - padding)
        let icpw = bounds.width - classNameView.frame.width - padding * 3
        let icph = Layout.height(with: sizeType)
        isConnectedWithPreviousView.frame = CGRect(x: classNameView.frame.maxX + padding, y: padding,
                                                   width: icpw, height: icph)
    }
    func updateWithSubtitle() {
        isConnectedWithPreviousView.bool = subtitle.isConnectedWithPrevious
    }
    
    var disabledRegisterUndo = true
    
    struct Binding {
        let view: SubtitleView, isConnectedWithPrevious: Bool, oldIsConnectedWithPrevious: Bool
        let subtitle: Subtitle, oldSubtitle: Subtitle, type: Action.SendType
    }
    var binding: ((Binding) -> ())?
    
    private var oldSubtitle = Subtitle()
    
    private func setIsConnectedWithPrevious(with binding: BoolView.Binding) {
        if binding.type == .begin {
            oldSubtitle = subtitle
        } else {
            subtitle.isConnectedWithPrevious = binding.bool
        }
        self.binding?(Binding(view: self,
                              isConnectedWithPrevious: binding.bool,
                              oldIsConnectedWithPrevious: binding.oldBool,
                              subtitle: subtitle, oldSubtitle: oldSubtitle,
                              type: binding.type))
    }
    
    func copiedObjects(with event: KeyInputEvent) -> [ViewExpression]? {
        return [subtitle]
    }
}
