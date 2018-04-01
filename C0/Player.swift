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
import AVFoundation

final class Player: Layer, Respondable {
    static let name = Localization(english: "Player", japanese: "プレイヤー")
    
    private let drawLayer = DrawLayer()
    override init() {
        super.init()
        fillColor = .playBorder
        drawLayer.lineWidth = 0
        drawLayer.drawBlock = { [unowned self] ctx in self.draw(in: ctx) }
        append(child: drawLayer)
    }
    
    var scene = Scene() {
        didSet {
            updateChildren()
        }
    }
    
    var playCut = Cut()
    
    override var bounds: CGRect {
        didSet {
            updateChildren()
        }
    }
    func updateChildren() {
        let paddingOrigin = CGPoint(x: (bounds.width - scene.frame.size.width) / 2,
                                    y: (bounds.height - scene.frame.size.height) / 2)
        drawLayer.frame = CGRect(origin: paddingOrigin, size: scene.frame.size)
        screenTransform = CGAffineTransform(translationX: drawLayer.bounds.midX,
                                            y: drawLayer.bounds.midY)
    }
    func draw(in ctx: CGContext) {
        ctx.concatenate(screenTransform)
        playCut.draw(scene: scene, viewType: .preview, in: ctx)
    }
    
    var screenTransform = CGAffineTransform.identity
    
    var audioPlayer: AVAudioPlayer?
    
    private var playCutIndex = 0, playFrameTime = FrameTime(0), playIntSecond = 0
    private var playDrawCount = 0, playFrameRate = FPS(0), delayTolerance = 0.5
    var didSetTimeHandler: ((Beat) -> (Void))? = nil
    var didSetCutIndexHandler: ((Int) -> (Void))? = nil
    var didSetPlayFrameRateHandler: ((Int) -> (Void))? = nil
    
    private var timer = LockTimer(), oldPlayCut: Cut?
    private var oldPlayTime = Beat(0), oldTimestamp = 0.0
    var isPlaying = false {
        didSet {
            guard isPlaying != oldValue else {
                return
            }
            if isPlaying {
                playCut = scene.editCut.copied
                oldPlayCut = scene.editCut
                oldPlayTime = scene.editCut.currentTime
                playDrawCount = 0
                oldTimestamp = CFAbsoluteTimeGetCurrent()
                let t = scene.time
                playIntSecond = t.integralPart
                playCutIndex = scene.editCutIndex
                playFrameRate = scene.frameRate
                playFrameTime = scene.frameTime(withBeatTime: scene.time)
                playDrawCount = 0
                if let url = scene.sound.url {
                    do {
                        try audioPlayer = AVAudioPlayer(contentsOf: url)
                        audioPlayer?.volume = Float(scene.sound.volume)
                    } catch {
                    }
                }
                audioPlayer?.currentTime = scene.secondTime(withBeatTime: t)
                audioPlayer?.play()
                timer.begin(interval: 1 / Second(scene.frameRate),
                            tolerance: 0.1 / Second(scene.frameRate),
                            handler: { [unowned self] in self.updatePlayTime() })
                drawLayer.draw()
            } else {
                timer.stop()
                audioPlayer?.stop()
                audioPlayer = nil
                drawLayer.image = nil
            }
        }
    }
    var isPause = false {
        didSet {
            guard isPause != oldValue else {
                return
            }
            if isPause {
                timer.stop()
                audioPlayer?.pause()
            } else {
                playDrawCount = 0
                oldTimestamp = CFAbsoluteTimeGetCurrent()
                playFrameRate = scene.frameRate
                timer.begin(interval: 1 / Second(scene.frameRate),
                            tolerance: 0.1 / Second(scene.frameRate),
                            handler: { [unowned self] in self.updatePlayTime() })
                audioPlayer?.play()
            }
        }
    }
    var allowableDelayTime = Second(0.1)
    private func updatePlayTime() {
        playFrameTime += 1
        if let audioPlayer = audioPlayer, !scene.sound.isHidden {
            let playTime = scene.secondTime(withFrameTime: playFrameTime)
            let audioTime = Second(audioPlayer.currentTime)
            if abs(playTime - audioTime) > allowableDelayTime {
                playFrameTime = scene.frameTime(withSecondTime: audioTime)
            }
        }
        let newTime = scene.beatTime(withFrameTime: playFrameTime)
        update(withTime: newTime)
    }
    private func updateBinding() {
        let t = currentPlayTime
        didSetTimeHandler?(t)
        
        if let cutIndex = scene.cuts.index(of: playCut), playCutIndex != cutIndex {
            playCutIndex = cutIndex
            didSetCutIndexHandler?(cutIndex)
        }
        
        if isPlaying && !isPause {
            playDrawCount += 1
            let newTimestamp = CFAbsoluteTimeGetCurrent()
            let deltaTime = newTimestamp - oldTimestamp
            if deltaTime >= 1 {
                let newPlayFrameRate = min(scene.frameRate,
                                           Int(round(Double(playDrawCount) / deltaTime)))
                if newPlayFrameRate != playFrameRate {
                    playFrameRate = newPlayFrameRate
                    didSetPlayFrameRateHandler?(playFrameRate)
                }
                oldTimestamp = newTimestamp
                playDrawCount = 0
            }
        } else {
            playFrameRate = 0
        }
    }
    
    private func update(withTime newTime: Beat) {
        let ci = scene.cutTrack.cutIndex(withTime: newTime)
        if ci.isOver {
            playCut = scene.cuts[0]
            playCut.currentTime = 0
            audioPlayer?.currentTime = 0
            playFrameTime = 0
        } else {
            let playCut = scene.cuts[ci.index]
            if playCut != self.playCut {
                self.playCut = playCut
            }
            playCut.currentTime = ci.interTime
        }
        drawLayer.draw()
        updateBinding()
    }
    
    var currentPlaySecond: Second {
        get {
            return scene.secondTime(withBeatTime: currentPlayTime)
        }
        set {
            update(withTime: scene.basedBeatTime(withSecondTime: newValue))
            playFrameTime = scene.frameTime(withSecondTime: newValue)
            audioPlayer?.currentTime = newValue
        }
    }
    var currentPlayTime: Beat {
        get {
            var t = Beat(0)
            for cut in scene.cuts {
                if playCut != cut {
                    t += cut.duration
                } else {
                    t += playCut.currentTime
                    break
                }
            }
            return t
        }
        set {
            update(withTime: newValue)
            playFrameTime = scene.frameTime(withBeatTime: newValue)
            audioPlayer?.currentTime = scene.secondTime(withFrameTime: playFrameTime)
        }
    }
    
    func play(with event: KeyInputEvent) {
        play()
    }
    func play() {
        if isPlaying {
            isPlaying = false
            isPlaying = true
        } else {
            isPlaying = true
        }
    }
    
    var endPlayHandler: ((Player) -> (Void))? = nil
    func stop() {
        if isPlaying {
            isPlaying = false
        }
        endPlayHandler?(self)
    }
}

final class SeekBar: Layer, Respondable, Localizable {
    static let name = Localization(english: "Seek Bar", japanese: "シークバー")
    
    var locale = Locale.current {
        didSet {
            updateLayout()
        }
    }
    
    let timeLabel = Label(text: Localization("00:00"), color: .locked)
    let frameRateLabel = Label(text: Localization("00 fps"), color: .locked)
    let slider = Slider(min: 0, max: 1,
                        description: Localization(english: "Play Time", japanese: "再生時間"))
    
    override init() {
        super.init()
        replace(children: [timeLabel, frameRateLabel, slider])
        
        slider.disabledRegisterUndo = true
        slider.binding = { [unowned self] in
            self.time = Second($0.value)
            self.timeBinding?(self.time, $0.type)
        }
    }
    
    var timeBinding: ((Second, Action.SendType) -> (Void))? = nil
    
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    func updateLayout() {
        let padding = Layout.basicPadding, height = Layout.basicHeight
        let sliderY = round((frame.height - height) / 2)
        let labelHeight = Layout.basicHeight - padding * 2
        let labelY = round((frame.height - labelHeight) / 2)
        
        timeLabel.frame.origin = CGPoint(x: padding, y: labelY)
        frameRateLabel.frame.origin = CGPoint(x: bounds.width - frameRateLabel.frame.width - padding,
                                              y: labelY)
        let sliderWidth = frameRateLabel.frame.minX - timeLabel.frame.maxX - padding * 2
        slider.frame = CGRect(x: timeLabel.frame.maxX + padding,
                              y: sliderY, width: sliderWidth, height: height)
        slider.backgroundLayers = [SeekBar.sliderLayer(with: slider.bounds, padding: slider.padding)]
    }
    static func sliderLayer(with bounds: CGRect, padding: CGFloat) -> Layer {
        let layer = PathLayer()
        let shapeRect = CGRect(x: padding, y: bounds.midY - 1,
                               width: bounds.width - padding * 2, height: 2)
        layer.path = CGPath(rect: shapeRect, transform: nil)
        layer.fillColor = .content
        return layer
    }
    
    override var isSubIndicated: Bool {
        didSet {
            isPlaying = isSubIndicated
            isPlayingBinding?(isSubIndicated)
        }
    }
    var isPlayingBinding: ((Bool) -> (Void))? = nil
    var isPlaying = false
    
    var time = Second(0.0) {
        didSet {
            slider.value = CGFloat(time)
            second = Int(time)
        }
    }
    var maxTime = Second(1.0) {
        didSet {
            slider.maxValue = Double(maxTime).cf
        }
    }
    private(set) var second = 0 {
        didSet {
            guard second != oldValue else {
                return
            }
            let oldBounds = timeLabel.bounds
            timeLabel.string = minuteSecondString(withSecond: second, frameRate: Int(frameRate))
            if oldBounds.size != timeLabel.bounds.size {
                updateLayout()
            }
        }
    }
    func minuteSecondString(withSecond s: Int, frameRate: FPS) -> String {
        if s >= 60 {
            let minute = s / 60
            let second = s - minute * 60
            return String(format: "%02d:%02d", minute, second)
        } else {
            return String(format: "00:%02d", s)
        }
    }
    var playFrameRate = 0 {
        didSet {
            updateWithFrameRate()
        }
    }
    var frameRate = 1 {
        didSet {
            playFrameRate = frameRate
            updateWithFrameRate()
        }
    }
    private func updateWithFrameRate() {
        let oldBounds = frameRateLabel.bounds
        frameRateLabel.string = String(format: "%02d fps", playFrameRate)
        frameRateLabel.textFrame.color = playFrameRate < frameRate ? .warning : .locked
        if oldBounds.size != frameRateLabel.bounds.size {
            updateLayout()
        }
    }
}
