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

struct Subtitle: Codable, Equatable {
    enum FileType: FileTypeProtocol {
        case vtt
        var utType: String {
            switch self {
            case .vtt:
                return "vtt"
            }
        }
    }
    
    struct Option {
        var borderColor = Color.subtitleBorder, fillColor = Color.subtitleFill
        var font = Font.subtitle
    }
    
    var string = ""
    
    var vttString: String {
        return string
    }
    var isEmpty: Bool {
        return string.isEmpty
    }
    
    static func vttStringWith(_ subtitleTuples: [(time: Beat, duration: Beat, subtitle: Subtitle)],
                              timeClosure: (Beat) -> (Second)) -> String {
        return subtitleTuples.reduce(into: "WEBVTT") {
            guard !$1.subtitle.isEmpty else { return }
            let beginTime = timeClosure($1.time), endTime = timeClosure($1.time + $1.duration)
            func timeString(withSecond second: Second) -> String {
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
extension Subtitle {
    //view
    //    func draw(bounds: Rect, with option: Option = Option(), in ctx: CGContext) {
    //        guard !string.isEmpty else { return }
    //        let attributes: [NSAttributedStringKey : Any] = [
    //            NSAttributedStringKey(rawValue: String(kCTFontAttributeName)): option.font.ctFont,
    //            NSAttributedStringKey(rawValue: String(kCTForegroundColorFromContextAttributeName)): true
    //        ]
    //        let attString = NSAttributedString(string: string, attributes: attributes)
    //        let framesetter = CTFramesetterCreateWithAttributedString(attString)
    //        let range = CFRange(location: 0, length: attString.length), ratio = bounds.size.width/640
    //        let size = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, range, nil,
    //                                                                Size(width: Real.infinity,
    //                                                                     height: Real.infinity), nil)
    //        let lineBounds = Rect(origin: Point(), size: size)
    //        let ctFrame = CTFramesetterCreateFrame(framesetter, range,
    //                                               CGPath(rect: lineBounds, transform: nil), nil)
    //        ctx.saveGState()
    //        ctx.setAllowsFontSmoothing(false)
    //        ctx.translateBy(x: round(bounds.midX - lineBounds.midX),  y: round(bounds.minY + 20 * ratio))
    //        ctx.setTextDrawingMode(.stroke)
    //        ctx.setLineWidth(ceil(3 * ratio))
    //        ctx.setStrokeColor(option.borderColor.cg)
    //        CTFrameDraw(ctFrame, ctx)
    //        ctx.setTextDrawingMode(.fill)
    //        ctx.setFillColor(option.fillColor.cg)
    //        CTFrameDraw(ctFrame, ctx)
    //        ctx.restoreGState()
    //    }
}
extension Subtitle: Interpolatable {
    static func linear(_ f0: Subtitle, _ f1: Subtitle, t: Real) -> Subtitle {
        let string = String.linear(f0.string, f1.string, t: t)
        return Subtitle(string: string)
    }
    static func firstMonospline(_ f1: Subtitle, _ f2: Subtitle,
                                _ f3: Subtitle, with ms: Monospline) -> Subtitle {
        let string = String.firstMonospline(f1.string, f2.string, f3.string, with: ms)
        return Subtitle(string: string)
    }
    static func monospline(_ f0: Subtitle, _ f1: Subtitle,
                           _ f2: Subtitle, _ f3: Subtitle, with ms: Monospline) -> Subtitle {
        let string = String.monospline(f0.string, f1.string, f2.string, f3.string, with: ms)
        return Subtitle(string: string)
    }
    static func lastMonospline(_ f0: Subtitle, _ f1: Subtitle,
                               _ f2: Subtitle, with ms: Monospline) -> Subtitle {
        let string = String.lastMonospline(f0.string, f1.string, f2.string, with: ms)
        return Subtitle(string: string)
    }
}
extension Subtitle: Referenceable {
    static let name = Text(english: "Subtitle", japanese: "字幕")
}
extension Subtitle: KeyframeValue {}
extension Subtitle: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return string.thumbnailView(withFrame: frame, sizeType)
    }
}

struct SubtitleTrack: Track {
    private(set) var animation = Animation<Subtitle>()
    var animatable: Animatable {
        return animation
    }
}
extension SubtitleTrack: Referenceable {
    static let name = Text(english: "Subtitle Track", japanese: "字幕トラック")
}
