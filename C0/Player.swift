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

final class Player: View {
    private let drawView = View(drawClosure: { _, _ in })
    override init() {
        super.init()
        fillColor = .playBorder
        drawView.lineWidth = 0
        drawView.drawClosure = { [unowned self] ctx, _ in self.draw(in: ctx) }
        append(child: drawView)
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
        drawView.frame = CGRect(origin: paddingOrigin, size: scene.frame.size)
        screenTransform = CGAffineTransform(translationX: drawView.bounds.midX,
                                            y: drawView.bounds.midY)
    }
    override func draw(in ctx: CGContext) {
        ctx.concatenate(screenTransform)
        playCut.draw(scene: scene, viewType: .preview, in: ctx)
    }
    
    var screenTransform = CGAffineTransform.identity
    
    var audioPlayer: AVAudioPlayer?
    
    private var playCutIndex = 0, playFrameTime = FrameTime(0), playIntSecond = 0
    private var playDrawCount = 0, playFrameRate = FPS(0), delayTolerance = 0.5
    var didSetTimeClosure: ((Beat) -> (Void))? = nil
    var didSetCutIndexClosure: ((Int) -> (Void))? = nil
    var didSetPlayFrameRateClosure: ((FPS) -> (Void))? = nil
    
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
                            closure: { [unowned self] in self.updatePlayTime() })
                drawView.draw()
            } else {
                timer.stop()
                audioPlayer?.stop()
                audioPlayer = nil
                drawView.image = nil
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
                            closure: { [unowned self] in self.updatePlayTime() })
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
        didSetTimeClosure?(t)
        
        if let cutIndex = scene.cuts.index(of: playCut), playCutIndex != cutIndex {
            playCutIndex = cutIndex
            didSetCutIndexClosure?(cutIndex)
        }
        
        if isPlaying && !isPause {
            playDrawCount += 1
            let newTimestamp = CFAbsoluteTimeGetCurrent()
            let deltaTime = newTimestamp - oldTimestamp
            if deltaTime >= 1 {
                let newPlayFrameRate = min(scene.frameRate,
                                           FPS(round(Double(playDrawCount) / deltaTime)))
                if newPlayFrameRate != playFrameRate {
                    playFrameRate = newPlayFrameRate
                    didSetPlayFrameRateClosure?(playFrameRate)
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
        drawView.draw()
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
    
    func play() {
        if isPlaying {
            isPlaying = false
            isPlaying = true
        } else {
            isPlaying = true
        }
    }
    
    var endPlayClosure: ((Player) -> (Void))? = nil
    func stop() {
        if isPlaying {
            isPlaying = false
        }
        endPlayClosure?(self)
    }
    
    func reference(at p: CGPoint) -> Reference {
        return Reference(name: Localization(english: "Player", japanese: "プレイヤー"))
    }
}

final class SeekBar: View {
    let timeTextView = TextView(text: Text("00:00"), color: .locked)
    let frameRateView = RealNumberView(unit: " fps")
    let timeView = SlidableNumberView(min: 0, max: 1)
    
    override init() {
        super.init()
        children = [timeTextView, frameRateView, timeView]
        
        timeView.disabledRegisterUndo = true
        timeView.binding = { [unowned self] in
            self.time = Second($0.number)
            self.timeBinding?(self.time, $0.phase)
        }
    }
    
    var timeBinding: ((Second, Phase) -> (Void))? = nil
    
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
        let padding = Layout.basicPadding, height = Layout.basicHeight
        let sliderY = round((frame.height - height) / 2)
        let labelHeight = Layout.basicHeight - padding * 2
        let labelY = round((frame.height - labelHeight) / 2)
        
        timeTextView.frame.origin = CGPoint(x: padding, y: labelY)
        let frw = Layout.valueWidth(with: .regular)
        frameRateView.frame = CGRect(x: bounds.width - frw - padding,
                                     y: padding * 2, width: frw, height: height - padding * 2)
        let sliderWidth = frameRateView.frame.minX - timeTextView.frame.maxX - padding * 2
        timeView.frame = CGRect(x: timeTextView.frame.maxX + padding,
                              y: sliderY, width: sliderWidth, height: height)
        timeView.backgroundViews = [SeekBar.sliderView(with: timeView.bounds,
                                                       padding: timeView.padding)]
    }
    static func sliderView(with bounds: CGRect, padding: CGFloat) -> View {
        let shapeRect = CGRect(x: padding, y: bounds.midY - 1,
                               width: bounds.width - padding * 2, height: 2)
        let view = View(path: CGPath(rect: shapeRect, transform: nil))
        view.fillColor = .content
        return view
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
            timeView.number = CGFloat(time)
            second = Int(time)
        }
    }
    var maxTime = Second(1.0) {
        didSet {
            timeView.maxNumber = Double(maxTime).cf
        }
    }
    private(set) var second = 0 {
        didSet {
            guard second != oldValue else {
                return
            }
            let oldBounds = timeTextView.bounds
            timeTextView.string = minuteSecondString(withSecond: second, frameRate: frameRate)
            if oldBounds.size != timeTextView.bounds.size {
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
    var playFrameRate = FPS(0) {
        didSet {
            updateWithFrameRate()
        }
    }
    var frameRate = FPS(1) {
        didSet {
            playFrameRate = frameRate
            updateWithFrameRate()
        }
    }
    private func updateWithFrameRate() {
        let oldBounds = frameRateView.bounds
        frameRateView.number = playFrameRate
        frameRateView.formStringView.textFrame.color = playFrameRate < frameRate ? .warning : .locked
        if oldBounds.size != frameRateView.bounds.size {
            updateLayout()
        }
    }
    
    func reference(at p: CGPoint) -> Reference {
        return Reference(name: Text(english: "Seek Bar", japanese: "シークバー"))
    }
}
