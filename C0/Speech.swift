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

final class SpeechTrack: NSObject, Track, NSCoding {
    private(set) var animation: Animation
    
    let speechItem: SpeechItem
    
    var time: Beat {
        didSet {
            updateInterpolation()
        }
    }
    func updateInterpolation() {
        animation.update(withTime: time, to: self)
    }
    func step(_ f0: Int) {
        speechItem.step(f0)
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        speechItem.linear(f0, f1, t: t)
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        speechItem.firstMonospline(f1, f2, f3, with: ms)
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        speechItem.monospline(f0, f1, f2, f3, with: ms)
    }
    func lastMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with ms: Monospline) {
        speechItem.lastMonospline(f0, f1, f2, with: ms)
    }
    
    init(animation: Animation = Animation(), time: Beat = 0, speechItem: SpeechItem = SpeechItem()) {
        guard animation.keyframes.count == speechItem.keySpeechs.count else {
            fatalError()
        }
        self.animation = animation
        self.time = time
        self.speechItem = speechItem
        super.init()
    }
    
    private enum CodingKeys: String, CodingKey {
        case animation, time, speechItem
    }
    init?(coder: NSCoder) {
        animation = coder.decodeDecodable(
            Animation.self, forKey: CodingKeys.animation.rawValue) ?? Animation()
        time = coder.decodeDecodable(Beat.self, forKey: CodingKeys.time.rawValue) ?? 0
        speechItem = coder.decodeObject(
            forKey: CodingKeys.speechItem.rawValue) as? SpeechItem ?? SpeechItem()
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encodeEncodable(animation, forKey: CodingKeys.animation.rawValue)
        coder.encodeEncodable(time, forKey: CodingKeys.time.rawValue)
        coder.encode(speechItem, forKey: CodingKeys.speechItem.rawValue)
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
        var speech: Speech
    }
    func insert(_ keyframe: Keyframe, _ kv: KeyframeValues, at index: Int) {
        speechItem.keySpeechs.insert(kv.speech, at: index)
        animation.keyframes.insert(keyframe, at: index)
    }
    func removeKeyframe(at index: Int) {
        animation.keyframes.remove(at: index)
        speechItem.keySpeechs.remove(at: index)
    }
    func set(_ keySpeechs: [Speech], isSetSpeechInItem: Bool  = true) {
        guard keySpeechs.count == animation.keyframes.count else {
            fatalError()
        }
        if isSetSpeechInItem {
            speechItem.speech = keySpeechs[animation.editKeyframeIndex]
        }
        speechItem.keySpeechs = keySpeechs
    }
    func replace(_ speech: Speech, at i: Int) {
        speechItem.replace(speech, at: i)
    }
    var currentItemValues: KeyframeValues {
        return KeyframeValues(speech: speechItem.speech)
    }
    func keyframeItemValues(at index: Int) -> KeyframeValues {
        return KeyframeValues(speech: speechItem.keySpeechs[index])
    }
}
extension SpeechTrack: Copying {
    func copied(from copier: Copier) -> SpeechTrack {
        return SpeechTrack(animation: animation, time: time, speechItem: copier.copied(speechItem))
    }
}
extension SpeechTrack: Referenceable {
    static let name = Localization(english: "Speech Track", japanese: "台詞トラック")
}

final class SpeechItem: NSObject, TrackItem, NSCoding {
    fileprivate(set) var keySpeechs: [Speech]
    var speech: Speech
    
    func replace(_ speech: Speech, at i: Int) {
        keySpeechs[i] = speech
        self.speech = speech
    }
    
    func step(_ f0: Int) {
        speech = keySpeechs[f0]
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        speech = keySpeechs[f0]
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        speech = keySpeechs[f1]
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        speech = keySpeechs[f1]
    }
    func lastMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with ms: Monospline) {
        speech = keySpeechs[f1]
    }
    
    init(keySpeechs: [Speech] = [], speech: Speech = Speech()) {
        if keySpeechs.isEmpty {
            self.keySpeechs = [speech]
        } else {
            self.keySpeechs = keySpeechs
        }
        self.speech = speech
        super.init()
    }
    
    private enum CodingKeys: String, CodingKey {
        case keySpeechs, speech
    }
    init?(coder: NSCoder) {
        keySpeechs = coder.decodeDecodable([Speech].self, forKey: CodingKeys.keySpeechs.rawValue) ?? []
        speech = coder.decodeDecodable(Speech.self, forKey: CodingKeys.speech.rawValue) ?? Speech()
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encodeEncodable(keySpeechs, forKey: CodingKeys.keySpeechs.rawValue)
        coder.encodeEncodable(speech, forKey: CodingKeys.speech.rawValue)
    }
    
    var isEmpty: Bool {
        for t in keySpeechs {
            if !t.isEmpty {
                return false
            }
        }
        return true
    }
}
extension SpeechItem: Copying {
    func copied(from copier: Copier) -> SpeechItem {
        return SpeechItem(keySpeechs: keySpeechs, speech: speech)
    }
}
extension SpeechItem: Referenceable {
    static let name = Localization(english: "Speech Item", japanese: "台詞アイテム")
}

struct Speech: Codable {
    struct Option {
        var borderColor = Color.speechBorder, fillColor = Color.speechFill
        var font = Font.speech
    }
    var string = ""
    
    var isEmpty: Bool {
        return string.isEmpty
    }
    func draw(bounds: CGRect, with option: Option = Option(), in ctx: CGContext) {
        guard !isEmpty else {
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
    
    static func vttStringWith(_ speechTuples: [(time: Beat, duration: Beat, speech: Speech)],
                              timeHandler: (Beat) -> (Second)) -> String {
        return speechTuples.reduce(into: "WEBVTT") {
            guard !$1.speech.isEmpty else {
                return
            }
            let beginTime = timeHandler($1.time), endTime = timeHandler($1.time + $1.duration)
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
            $0 += $1.speech.string
        }
    }
    static func vtt(_ speechTuples: [(time: Beat, duration: Beat, speech: Speech)],
                    timeHandler: (Beat) -> (Second)) -> Data? {
        return vttStringWith(speechTuples, timeHandler: timeHandler).data(using: .utf8)
    }
}
extension Speech: Referenceable {
    static let name = Localization(english: "Speech", japanese: "台詞")
}

final class SpeechView: Layer, Respondable {
    static let name = Localization(english: "Speech View", japanese: "台詞表示")
    
    let selectedLabel = Label()
    var otherLabels = [Label]()
    
    private let nameLabel = Label(text: Speech.name, font: .bold)
    
    override init() {
        super.init()
        replace(children: [nameLabel])
    }
    
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    private func updateLayout() {
        let padding = Layout.basicPadding
        nameLabel.frame.origin = CGPoint(x: padding, y: padding * 2)
    }
    
    
}
