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
import AudioToolbox

struct Sound {
    static let basicSampleRate = 44100.0
    
    var url: URL? {
        didSet {
            if let url = url {
                self.bookmark = try? url.bookmarkData()
                self.name = url.lastPathComponent
            }
        }
    }
    private var bookmark: Data?
    var name = ""
    var volume = 1.0
    var isHidden = false
    
    private enum CodingKeys: String, CodingKey {
        case bookmark, name,volume, isHidden
    }
    
    func samples(withSampleRate sampleRate: Float64 = basicSampleRate) -> [Float] {
        guard let url = url else {
            return []
        }
        var aFileRef: ExtAudioFileRef?
        ExtAudioFileOpenURL(url as CFURL, &aFileRef)
        guard let fileRef = aFileRef else {
            return []
        }
        let floatSize = UInt32(MemoryLayout<Float32>.size)
        let channelsPerFrame = UInt32(1), framesPerPacket = UInt32(1)
        let bytesPerFrame = channelsPerFrame * floatSize
        var audioFormat = AudioStreamBasicDescription(mSampleRate: sampleRate,
                                                      mFormatID: kAudioFormatLinearPCM,
                                                      mFormatFlags: kLinearPCMFormatFlagIsFloat,
                                                      mBytesPerPacket: framesPerPacket * bytesPerFrame,
                                                      mFramesPerPacket: framesPerPacket,
                                                      mBytesPerFrame: bytesPerFrame,
                                                      mChannelsPerFrame: channelsPerFrame,
                                                      mBitsPerChannel: floatSize * 8,
                                                      mReserved: 0)
        ExtAudioFileSetProperty(fileRef,
                                kExtAudioFileProperty_ClientDataFormat,
                                UInt32(MemoryLayout<AudioStreamBasicDescription>.size),
                                &audioFormat)
        
        let subSamplesCount = 1024
        let packetsPerBuffer = UInt32(subSamplesCount)
        let outputBufferSize = packetsPerBuffer * UInt32(audioFormat.mBytesPerPacket)
        var outputBuffer = [UInt8]()
        outputBuffer.reserveCapacity(Int(outputBufferSize))
        let audioBuffer = AudioBuffer(mNumberChannels: channelsPerFrame,
                                      mDataByteSize: outputBufferSize,
                                      mData: &outputBuffer)
        var abl = AudioBufferList(mNumberBuffers: channelsPerFrame, mBuffers: audioBuffer)
        
        var samples = [Float](), frameCount = UInt32(subSamplesCount)
        while frameCount > 0 {
            ExtAudioFileRead(fileRef, &frameCount, &abl)
            if frameCount > 0 {
                let buffers = UnsafeBufferPointer<AudioBuffer>(start: &abl.mBuffers,
                                                               count: Int(abl.mNumberBuffers))
                let capacity = Int(buffers[0].mDataByteSize / floatSize)
                if let subSamples = buffers[0].mData?.bindMemory(to: Float.self, capacity: capacity) {
                    (0..<capacity).forEach { samples.append(subSamples[$0]) }
                }
            }
        }
        ExtAudioFileDispose(fileRef)
        return samples
    }
    func dBFSs(withSplitCount count: Int) -> [Float] {
        let samples = self.samples()
        let rc = 1 / Real(count - 1)
        var oldSampleIndex = 0
        return (1..<count).map { i in
            let t = Real(i) * rc
            let sampleIndex = Int(Real(samples.count - 1) * t)
            let subSamples = samples[oldSampleIndex...sampleIndex]
            let p: Float
            if oldSampleIndex < sampleIndex {
                p = sqrt(subSamples.reduce(Float(0.0)) { $0 + $1 * $1 } / Float(subSamples.count))
            } else {
                p = abs(samples[sampleIndex])
            }
            let spl = 20 * log10(p)
            oldSampleIndex = sampleIndex
            return spl
        }
    }
}
extension Sound: Equatable {
    static func ==(lhs: Sound, rhs: Sound) -> Bool {
        return lhs.url == rhs.url && lhs.name == rhs.name
            && lhs.volume == rhs.volume && lhs.isHidden == rhs.isHidden
    }
}
extension Sound: Codable {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        bookmark = try values.decode(Data.self, forKey: .bookmark)
        name = try values.decode(String.self, forKey: .name)
        volume = try values.decode(Double.self, forKey: .volume)
        isHidden = try values.decode(Bool.self, forKey: .isHidden)
        url = URL(bookmark: bookmark)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bookmark, forKey: .bookmark)
        try container.encode(name, forKey: .name)
        try container.encode(volume, forKey: .volume)
        try container.encode(isHidden, forKey: .isHidden)
    }
}
extension Sound: Referenceable {
    static let name = Text(english: "Sound", japanese: "サウンド")
}
extension Sound: Initializable {}
extension Sound: Interpolatable {
    static func linear(_ f0: Sound, _ f1: Sound, t: Real) -> Sound {
        return f0
    }
    static func firstMonospline(_ f1: Sound, _ f2: Sound,
                                _ f3: Sound, with ms: Monospline) -> Sound {
        return f1
    }
    static func monospline(_ f0: Sound, _ f1: Sound,
                           _ f2: Sound, _ f3: Sound, with ms: Monospline) -> Sound {
        return f1
    }
    static func lastMonospline(_ f0: Sound, _ f1: Sound,
                               _ f2: Sound, with ms: Monospline) -> Sound {
        return f1
    }
}
extension Sound: KeyframeValue {}
extension Sound: MiniViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return name.view(withBounds: bounds, sizeType)
    }
}

struct SoundTrack: Track, Codable {
    private(set) var animation = Animation<Sound>()
    var animatable: Animatable {
        return animation
    }
}

typealias SoundSample = Float
final class SoundWaveformView: View {
    var sampleRate = Sound.basicSampleRate
    var sound = Sound() {
        didSet {
            updateWaveform(isRefreshCache: true)
        }
    }
    
    private var cacheDBFSs = [SoundSample]()
    
    enum WaveformType {
        case normal, dBFS
    }
    var waveformType = WaveformType.dBFS {
        didSet {
            updateWaveform()
        }
    }
    
    var tempoTrack = TempoTrack()//delete
    
    static let defautBaseWidth = 6.0.cg
    var baseWidth = defautBaseWidth {
        didSet {
            updateWaveform()
        }
    }
    var baseTimeInterval = Beat(1, 24) {
        didSet {
            updateWaveform()
        }
    }
    
    func x(withDoubleBeatTime realBeatTime: RealBeat) -> Real {
        return Real(realBeatTime * RealBeat(baseTimeInterval.inversed!)) * baseWidth
    }
    
    private(set) var secondDuration = Second(0)
    private(set) var duration = RealBeat(0) {
        didSet {
            frame.size.width = x(withDoubleBeatTime: duration)
        }
    }
    let waveformView = View(path: CGMutablePath())
    
    init(height: Real = 12) {
        super.init()
        frame.size.height = height
        isClipped = true
        children = [waveformView]
    }
    
    private func updateWaveform(isRefreshCache: Bool = false) {
        switch waveformType {
        case .normal:
            let samples = sound.samples(withSampleRate: sampleRate)
            guard !samples.isEmpty else {
                waveformView.path = nil
                secondDuration = 0
                duration = 0
                return
            }
            secondDuration = Second(Double(samples.count) / sampleRate)
            duration = tempoTrack.realBeatTime(withSecondTime: secondDuration)
            
            let count = Int(frame.width / 5)
            let rc = 1 / Real(count - 1)
            
            let midY = bounds.midY, halfH = frame.height / 2
            func y(withSample sample: SoundSample) -> Real {
                return midY + halfH * Real(sample)
            }
            let path = CGMutablePath()
            path.addLines(between: (0..<count).map { i in
                let xt = Real(i) * rc
                let si = Int(Real(samples.count - 1) * xt)
                return Point(x: frame.width * xt, y: y(withSample: samples[si]))
            })
            waveformView.lineColor = .content
            waveformView.lineWidth = 1
            waveformView.path = path
        case .dBFS:
            let dBFSs: [SoundSample]
            if cacheDBFSs.isEmpty || isRefreshCache {
                let samples = sound.samples(withSampleRate: sampleRate)
                guard !samples.isEmpty else {
                    waveformView.path = nil
                    secondDuration = 0
                    duration = 0
                    return
                }
                secondDuration = Second(Double(samples.count) / sampleRate)
                duration = tempoTrack.realBeatTime(withSecondTime: secondDuration)
                
                let count = Int(frame.width / 5)
                dBFSs = sound.dBFSs(withSplitCount: count)
                cacheDBFSs = dBFSs
            } else {
                duration = tempoTrack.realBeatTime(withSecondTime: secondDuration)
                dBFSs = cacheDBFSs
            }
            
            let path = CGMutablePath()
            path.move(to: Point(x: bounds.width, y: 0))
            path.addLine(to: Point(x: 0, y: 0))
            let rc = 1 / Real(dBFSs.count - 1)
            dBFSs.enumerated().forEach { i, spl in
                let xt = Real(i) * rc
                let yt = 1 + Real(spl).clip(min: -30, max: 0) / 30
                path.addLine(to: Point(x: frame.width * xt, y: frame.height * yt))
            }
            waveformView.fillColor = .content
            waveformView.path = path
        }
    }
}

/**
 Issue: 効果音編集
 Issue: シーケンサー
 */
final class SoundView: View {
    var sound = Sound() {
        didSet {
            nameView.text = sound.url != nil ? Text(sound.name) : ""
        }
    }
    
    var sizeType: SizeType
    let classNameView: TextFormView
    let nameView: TextView<Binder>
    
    init(sizeType: SizeType = .regular) {
        self.sizeType = sizeType
        classNameView = TextFormView(text: Sound.name, font: Font.bold(with: sizeType))
        nameView = TextView(text: "", font: Font.default(with: sizeType),
                            isSizeToFit: false, isLocked: false)
        
        super.init()
        isClipped = true
        children = [classNameView, nameView]
        updateLayout()
    }
    
    override func updateLayout() {
        let padding = Layout.padding(with: sizeType)
        let y = bounds.height - padding - classNameView.frame.height
        classNameView.frame.origin = Point(x: padding, y: y)
        nameView.frame = Rect(x: classNameView.frame.maxX + padding, y: padding,
                                width: bounds.width - classNameView.frame.maxX - padding * 2,
                                height: bounds.height - padding * 2)
    }
    
    struct Binding {
        let soundView: SoundView, sound: Sound, oldSound: Sound, phase: Phase
    }
    var setSoundClosure: ((Binding) -> ())?
    
    func push(_ sound: Sound) {
        //        registeringUndoManager?.registerUndo(withTarget: self) { [old =]$0.set(oldSound, old: sound) }
        self.sound = sound
    }
}
extension SoundView: Localizable {
    func update(with locale: Locale) {
        updateLayout()
    }
}
extension SoundView: Queryable {
    static let referenceableType: Referenceable.Type = Sound.self
}
extension SoundView: Assignable {
    func delete(for p: Point) {
        push(Sound())
    }
    func copiedObjects(at p: Point) -> [Viewable] {
        guard let url = sound.url else {
            return [sound]
        }
        return [sound, url]
    }
    func paste(_ objects: [Object], for p: Point) {
        for object in objects {
            if let sound = object as? Sound {
                push(sound)
                return
            } else if let url = object as? URL, url.isConforms(type: kUTTypeAudio as String) {
                var sound = Sound()
                sound.url = url
                push(sound)
                return
            }
        }
    }
}
