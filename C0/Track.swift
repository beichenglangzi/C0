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

protocol Track: Codable {
    var editingKeyframeTimingIndex: KeyframeTimingCollection.Index { get }
    var animatable: Animatable { get }
}

/**
 Compiler Issue: Protocolから静的に決定可能な代数的データ型のコードを自動生成
 */
indirect enum AlgebraicTrack: Track {
    var editingKeyframeTimingIndex: Int
    
    case tempo(TempoTrack)
    case subtitle(SubtitleTrack)
    case transform(TransformTrack)
    case sineWave(SineWaveTrack)
    case sound(SoundTrack)
    
    var tempoTrack: TempoTrack? {
        get {
            switch self {
            case .tempo(let track): return track
            default: return nil
            }
        }
        set {
            if let newValue = newValue {
                self = .tempo(newValue)
            }
        }
    }
    var soundTrack: SoundTrack? {
        get {
            switch self {
            case .sound(let track): return track
            default: return nil
            }
        }
        set {
            if let newValue = newValue {
                self = .sound(newValue)
            }
        }
    }
    var subtitleTrack: SubtitleTrack? {
        get {
            switch self {
            case .subtitle(let track): return track
            default: return nil
            }
        }
        set {
            if let newValue = newValue {
                self = .subtitle(newValue)
            }
        }
    }
    
    var animatable: Animatable {
        switch self {
        case .tempo(let track): return track.animation
        case .subtitle(let track): return track.animation
        case .transform(let track): return track.animation
        case .sineWave(let track): return track.animation
        case .sound(let track): return track.animation
        }
    }
}
extension AlgebraicTrack: Codable {
    enum CodingKeys: CodingKey {
        case tempo, subtitle, transform, sineWave, sound
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
        case .sineWave:
            if let track = try? values.decode(SineWaveTrack.self, forKey: key) {
                self = .sineWave(track)
            }
        case .sound:
            if let track = try? values.decode(SoundTrack.self, forKey: key) {
                self = .sound(track)
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
        case .sineWave(let track): try container.encode(track, forKey: .sineWave)
        case .sound(let track): try container.encode(track, forKey: .sound)
        }
    }
}

final class TrackItemView<T: BinderProtocol>: View {
    
    init(binder: T) {
        super.init()
    }
}
