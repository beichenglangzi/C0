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

final class SoundItem: TrackItem, Codable {
    var sound: Sound
    fileprivate(set) var keySounds: [Sound]
    func replace(_ sound: Sound, at i: Int) {
        keySounds[i] = sound
        self.sound = sound
    }
    
    func step(_ f0: Int) {
        sound = keySounds[f0]
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        sound = keySounds[f0]
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        sound = keySounds[f1]
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        sound = keySounds[f1]
    }
    func lastMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with ms: Monospline) {
        sound = keySounds[f1]
    }
    
    static let defaultSound = Sound()
    init(sound: Sound = defaultSound, keySounds: [Sound] = [defaultSound]) {
        self.sound = sound
        self.keySounds = keySounds
    }
}
extension SoundItem: Copying {
    func copied(from copier: Copier) -> SoundItem {
        return SoundItem(sound: sound, keySounds: keySounds)
    }
}
extension SoundItem: Referenceable {
    static let name = Localization(english: "Sound Item", japanese: "サウンドアイテム")
}

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
                    for i in 0 ..< capacity {
                        samples.append(subSamples[i])
                    }
                }
            }
        }
        ExtAudioFileDispose(fileRef)
        return samples
    }
    func dBFSs(withSplitCount count: Int) -> [Float] {
        let samples = self.samples()
        let rc = 1 / (count.cf - 1)
        var oldSampleIndex = 0
        return (1 ..< count).map { i in
            let t = i.cf * rc
            let sampleIndex = Int((samples.count.cf - 1) * t)
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
    static let name = Localization(english: "Sound", japanese: "サウンド")
}

final class SoundWaveformView: Layer {
    var sampleRate = Sound.basicSampleRate
    var sound = Sound() {
        didSet {
            updateWaveform(isRefreshCache: true)
        }
    }
    
    private var cacheDBFSs = [Float]()
    
    enum WaveformType {
        case normal, dBFS
    }
    var waveformType = WaveformType.dBFS {
        didSet {
            updateWaveform()
        }
    }
    
    var tempoTrack = TempoTrack()
    
    static let defautBaseWidth = 6.0.cf
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
    
    func x(withDoubleBeatTime doubleBeatTime: DoubleBeat) -> CGFloat {
        return CGFloat(doubleBeatTime * DoubleBeat(baseTimeInterval.inversed!)) * baseWidth
    }
    
    private(set) var secondDuration = Second(0)
    private(set) var duration = DoubleBeat(0) {
        didSet {
            frame.size.width = x(withDoubleBeatTime: duration)
        }
    }
    let waveformLayer = PathLayer()
    
    init(height: CGFloat = 12.0) {
        super.init()
        frame.size.height = height
        isClipped = true
        replace(children: [waveformLayer])
    }
    func updateWaveform(isRefreshCache: Bool = false) {
        switch waveformType {
        case .normal:
            let samples = sound.samples(withSampleRate: sampleRate)
            guard !samples.isEmpty else {
                waveformLayer.path = nil
                secondDuration = 0
                duration = 0
                return
            }
            secondDuration = Second(Double(samples.count) / sampleRate)
            duration = tempoTrack.doubleBeatTime(withSecondTime: secondDuration)
            
            
            let path = CGMutablePath()
            let count = Int(frame.width / 5)
            let rc = 1 / (count.cf - 1)
            
            let midY = bounds.midY, halfH = frame.height / 2
            func y(withSample sample: Float) -> CGFloat {
                return midY + halfH * sample.cf
            }
            path.addLines(between: (0..<count).map { i in
                let xt = i.cf * rc
                let si = Int(CGFloat(samples.count - 1) * xt)
                return CGPoint(x: frame.width * xt, y: y(withSample: samples[si]))
            })
            waveformLayer.lineColor = .content
            waveformLayer.lineWidth = 1
            waveformLayer.path = path
        case .dBFS:
            let dBFSs: [Float]
            if cacheDBFSs.isEmpty || isRefreshCache {
                let samples = sound.samples(withSampleRate: sampleRate)
                guard !samples.isEmpty else {
                    waveformLayer.path = nil
                    secondDuration = 0
                    duration = 0
                    return
                }
                secondDuration = Second(Double(samples.count) / sampleRate)
                duration = tempoTrack.doubleBeatTime(withSecondTime: secondDuration)
                
                let count = Int(frame.width / 5)
                dBFSs = sound.dBFSs(withSplitCount: count)
                cacheDBFSs = dBFSs
            } else {
                duration = tempoTrack.doubleBeatTime(withSecondTime: secondDuration)
                dBFSs = cacheDBFSs
            }
            
            let path = CGMutablePath()
            path.move(to: CGPoint(x: bounds.width, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 0))
            let rc = 1 / (dBFSs.count.cf - 1)
            dBFSs.enumerated().forEach { i, spl in
                let xt = i.cf * rc
                let yt = 1 + spl.cf.clip(min: -30, max: 0) / 30
                path.addLine(to: CGPoint(x: frame.width * xt, y: frame.height * yt))
            }
            waveformLayer.fillColor = .content
            waveformLayer.path = path
        }
    }
}

/**
 # Issue
 - 効果音編集
 - シーケンサー
 */
final class SoundView: Layer, Respondable, Localizable {
    static let name = Localization(english: "Sound View", japanese: "サウンド表示")
    
    var locale = Locale.current {
        didSet {
            updateLayout()
        }
    }
    
    var sound = Sound() {
        didSet {
            soundLabel.localization = sound.url != nil ?
                Localization(sound.name) : Localization(english: "Empty", japanese: "空")
        }
    }
    
    let nameLabel = Label(text: Localization(english: "Sound", japanese: "サウンド"), font: .bold)
    let soundLabel = Label(text: Localization(english: "Empty", japanese: "空"))
    
    override init() {
        soundLabel.noIndicatedLineColor = .border
        soundLabel.indicatedLineColor = .indicated
        super.init()
        isClipped = true
        replace(children: [nameLabel, soundLabel])
        updateLayout()
    }
    
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    private func updateLayout() {
        _ = Layout.leftAlignment([nameLabel, Padding(), soundLabel], height: frame.height)
    }
    
    var disabledRegisterUndo = false
    
    struct Binding {
        let soundView: SoundView, sound: Sound, oldSound: Sound, type: Action.SendType
    }
    var setSoundHandler: ((Binding) -> ())?
    
    func delete(with event: KeyInputEvent) -> Bool {
        guard sound.url != nil else {
            return false
        }
        set(Sound(), old: self.sound)
        return true
    }
    func copy(with event: KeyInputEvent) -> CopiedObject? {
        guard let url = sound.url else {
            return CopiedObject(objects: [sound])
        }
        return CopiedObject(objects: [sound, url])
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) -> Bool {
        for object in copiedObject.objects {
            if let url = object as? URL, url.isConforms(uti: kUTTypeAudio as String) {
                var sound = Sound()
                sound.url = url
                set(sound, old: self.sound)
                return true
            } else if let sound = object as? Sound {
                set(sound, old: self.sound)
                return true
            }
        }
        return false
    }
    private func set(_ sound: Sound, old oldSound: Sound) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldSound, old: sound) }
        setSoundHandler?(Binding(soundView: self,
                                       sound: oldSound, oldSound: oldSound, type: .begin))
        self.sound = sound
        setSoundHandler?(Binding(soundView: self,
                                       sound: sound, oldSound: oldSound, type: .end))
    }
}
