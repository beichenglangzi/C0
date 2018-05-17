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

protocol Track: Codable {
    var animatable: Animatable { get }
}

struct TrackTree<Value: KeyframeValue>: Track, Codable, TreeNode {
    var children: [TrackTree] {
        didSet {
            updateSumAnimation()
        }
    }
    
//    var trackItem
    
    var animation: Animation<Value> {
        didSet {
            updateSumAnimation()
        }
    }
    var animatable: Animatable {
        return animation
    }
    
    var sumAnimation: Animation<SumKeyframeValue>
    mutating func updateSumAnimation() {
        var keyframeDics = [Beat: Keyframe<SumKeyframeValue>]()
        func updateKeyframesWith(time: Beat, _ label: KeyframeTiming.Label) {
            if keyframeDics[time] != nil {
                if label == .main {
                    keyframeDics[time]?.timing.label = .main
                }
            } else {
                var newKeyframe = Keyframe<SumKeyframeValue>()
                newKeyframe.timing.time = time
                newKeyframe.timing.label = label
                keyframeDics[time] = newKeyframe
            }
        }
        let beginTime = animatable.beginTime
        children.forEach { track in
            track.animatable.keyframeTimings.forEach {
                updateKeyframesWith(time: $0.time + track.animatable.beginTime + beginTime, $0.label)
            }
            let maxTime = track.animatable.duration + track.animatable.beginTime + beginTime
            updateKeyframesWith(time: maxTime, KeyframeTiming.Label.main)
        }
        var keyframes = keyframeDics.values.sorted(by: { $0.timing.time < $1.timing.time })
        guard let lastTime = keyframes.last?.timing.time else {
            sumAnimation = Animation()
            return
        }
        keyframes.removeLast()
        
        let clippedSelectedKeyframeIndexes = sumAnimation.selectedKeyframeIndexes.isEmpty ?
            [] :
            sumAnimation.selectedKeyframeIndexes[...keyframes.count]
        sumAnimation = Animation(keyframes: keyframes, duration: lastTime,
                                 selectedKeyframeIndexes: Array(clippedSelectedKeyframeIndexes))
    }
    
    var childrenMaxDuration: Beat {
        var maxDuration = animation.duration
        children.forEach {
            let duration = $0.animatable.duration
            if duration > maxDuration {
                maxDuration = duration
            }
        }
        return maxDuration
    }
}

/**
 Issue: Protocolから静的に決定可能な代数的データ型のコードを自動生成
 */
enum AlgebraicTrackItem: Track {
    var animatable: Animatable {
        switch self {
        case .tempo(let track): return track.animation
        case .subtitle(let track): return track.animation
        case .transform(let track): return track.animation
        case .wiggle(let track): return track.animation
        }
    }
    case tempo(TempoTrack)
    case subtitle(SubtitleTrack)
    case transform(TransformTrack)
    case wiggle(SineWaveTrack)
    var tempoTrack: TempoTrack? {
        get {
            switch self {
            case .tempo(let track): return track
            default: return nil
            }
        }
        set {
            
        }
    }
}
extension AlgebraicTrackItem: Codable {
    enum CodingKeys: CodingKey {
        case tempo, subtitle, transform, wiggle
    }
    enum CodingError: Error {
        case decoding(String)
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard let key = values.allKeys.first else {
            throw CodingError.decoding("\(dump(values))")
        }
        switch key {
        case .tempo:
            if let track = try? values.decode(TempoTrack.self, forKey: key) {
                self = .tempo(track)
            }
        case .subtitle:
            if let track = try? values.decode(SubtitleTrack.self, forKey: key) {
                self = .subtitle(track)
            }
        case .transform:
            if let track = try? values.decode(TransformTrack.self, forKey: key) {
                self = .transform(track)
            }
        case .wiggle:
            if let track = try? values.decode(SineWaveTrack.self, forKey: key) {
                self = .wiggle(track)
            }
        }
        throw CodingError.decoding("\(dump(values))")
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .tempo(let track): try container.encode(track, forKey: .tempo)
        case .subtitle(let track): try container.encode(track, forKey: .subtitle)
        case .transform(let track): try container.encode(track, forKey: .transform)
        case .wiggle(let track): try container.encode(track, forKey: .wiggle)
        }
    }
}

final class TrackItemView<T: BinderProtocol>: View {
    let effectView: EffectView<T>
    var animation: Animation<Transform>
    init(binder: T) {
        effectView = EffectView(binder: binder,
                                keyPath: \SceneBinder.scene.canvas.editingCellGroup.effect,
                                sizeType: .small)
        super.init()
    }
}

struct LinesTrack: Track, Codable {
    var animation: Animation<LinesKeyframeValue>
    var animatable: Animatable {
        return animation
    }
    
    var cellTreeIndexes: [TreeIndex<Cell>]
}

struct SumKeyframeValue: KeyframeValue {}
extension SumKeyframeValue: Interpolatable {
    static func linear(_ f0: SumKeyframeValue, _ f1: SumKeyframeValue, t: Real) -> SumKeyframeValue {
        return f0
    }
    static func firstMonospline(_ f1: SumKeyframeValue, _ f2: SumKeyframeValue,
                                _ f3: SumKeyframeValue, with ms: Monospline) -> SumKeyframeValue {
        return f1
    }
    static func monospline(_ f0: SumKeyframeValue, _ f1: SumKeyframeValue,
                           _ f2: SumKeyframeValue, _ f3: SumKeyframeValue,
                           with ms: Monospline) -> SumKeyframeValue {
        return f1
    }
    static func lastMonospline(_ f0: SumKeyframeValue, _ f1: SumKeyframeValue,
                               _ f2: SumKeyframeValue, with ms: Monospline) -> SumKeyframeValue {
        return f1
    }
}
extension SumKeyframeValue: Referenceable {
    static let name = Text(english: "Sum Keyframe Value", japanese: "合計キーフレーム値")
}

struct LinesKeyframeValue: KeyframeValue {
    var drawing = Drawing()
    var geometries = [Geometry]()
}
extension LinesKeyframeValue {
    //view
    func drawPreviousNext(lineWidth: Real,
                          isHiddenPrevious: Bool, isHiddenNext: Bool, index: Int, in ctx: CGContext) {
        if !isHiddenPrevious && index - 1 >= 0 {
            ctx.setFillColor(Color.previous.cg)
            keyGeometries[index - 1].draw(withLineWidth: lineWidth, in: ctx)
        }
        if !isHiddenNext && index + 1 <= keyGeometries.count - 1 {
            ctx.setFillColor(Color.next.cg)
            keyGeometries[index + 1].draw(withLineWidth: lineWidth, in: ctx)
        }
    }
}
extension LinesKeyframeValue: Interpolatable {
    static func linear(_ f0: LinesKeyframeValue, _ f1: LinesKeyframeValue,
                       t: Real) -> LinesKeyframeValue {
        let drawing = f0.drawing
        let geometries = [Geometry].linear(f0.geometries, f1.geometries, t: t)
        return LinesKeyframeValue(drawing: drawing, geometries: geometries)
    }
    static func firstMonospline(_ f1: LinesKeyframeValue, _ f2: LinesKeyframeValue,
                                _ f3: LinesKeyframeValue, with ms: Monospline) -> LinesKeyframeValue {
        let drawing = f1.drawing
        let geometries = [Geometry].firstMonospline(f1.geometries,
                                                    f2.geometries, f3.geometries, with: ms)
        return LinesKeyframeValue(drawing: drawing, geometries: geometries)
    }
    static func monospline(_ f0: LinesKeyframeValue, _ f1: LinesKeyframeValue,
                           _ f2: LinesKeyframeValue, _ f3: LinesKeyframeValue,
                           with ms: Monospline) -> LinesKeyframeValue {
        let drawing = f1.drawing
        let geometries = [Geometry].monospline(f0.geometries, f1.geometries,
                                               f2.geometries, f3.geometries, with: ms)
        return LinesKeyframeValue(drawing: drawing, geometries: geometries)
    }
    static func lastMonospline(_ f0: LinesKeyframeValue, _ f1: LinesKeyframeValue,
                               _ f2: LinesKeyframeValue, with ms: Monospline) -> LinesKeyframeValue {
        let drawing = f1.drawing
        let geometries = [Geometry].lastMonospline(f0.geometries,
                                                   f1.geometries, f2.geometries, with: ms)
        return LinesKeyframeValue(drawing: drawing, geometries: geometries)
    }
}
extension LinesKeyframeValue: Referenceable {
    static let name = Text(english: "Lines Keyframe Value", japanese: "線キーフレーム値")
}
