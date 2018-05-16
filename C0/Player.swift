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

struct Player {
    var time: Second, isSynchronized: Bool, volume: Real, isMute: Bool
    var playRange = -1.0...5.0, isUsingRange: Bool
    var isPlaying: Bool
    var playingTime: Second
    
    static func minuteSecondString(withSecond s: Int, frameRate: FPS) -> String {
        if s >= 60 {
            let minute = s / 60
            let second = s - minute * 60
            return String(format: "%02d:%02d", minute, second)
        } else {
            return String(format: "00:%02d", s)
        }
    }
}
extension Player: Referenceable {
    static let name = Text(english: "Player", japanese: "プレイヤー")
}

final class ScenePlayerView<T: BinderProtocol>: View, BindableReceiver {
    typealias Model = Player
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    
    var sceneKeyPath: KeyPath<Binder, Scene> {
        didSet { updateWithModel() }
    }
    var scene: Scene {
        return binder[keyPath: sceneKeyPath]
    }
    
    private var screenTransform = CGAffineTransform.identity
    private var audioPlayers = [AVAudioPlayer]()
    
    private var playFrameTime = FrameTime(0), playIntSecond = 0
    private var playingDrawnCount = 0, delayTolerance = 0.5
    
    private var timer = LockTimer()
    private var oldPlayTime = Beat(0), oldTimestamp = 0.0
    
    var time = Second(0.0) {
        didSet {
            second = Int(time)
        }
    }
    var maxTime = Second(1.0) {
        didSet {
            timeView.option.maxModel = maxTime
        }
    }
    private(set) var second = 0 {
        didSet {
            guard second != oldValue else { return }
            let oldBounds = timeStringView.bounds
            let string = Player.minuteSecondString(withSecond: second,
                                                   frameRate: scene.timeline.frameRate)
            timeStringView.text = Text(string)
            if oldBounds.size != timeStringView.bounds.size { updateLayout() }
        }
    }
    
    var playingFrameRate = FPS(0) {
        didSet { updateWithFrameRate() }
    }
    
    var didSetTimeClosure: ((Beat) -> ())? = nil
    var didSetPlayFrameRateClosure: ((FPS) -> ())? = nil
    var timeBinding: ((Second, Phase) -> ())? = nil
    var isPlayingBinding: ((Bool) -> ())? = nil
    var endPlayClosure: ((ScenePlayerView) -> ())? = nil
    
    let timeStringView = TextFormView(text: "00:00", color: .locked)
    let playingFrameRateView: RealGetterView<Binder>//(model: 0, option: RealGetterOption(numberOfDigits: 1, unit: " fps"))
    let timeView: SlidableRealView<Binder>
    let drawView = View(drawClosure: { _, _ in })
    
    var isPlaying = false {
        didSet {
            guard isPlaying != oldValue else { return }
            if isPlaying {
                oldPlayTime = scene.editCut.currentTime
                playingDrawnCount = 0
                oldTimestamp = CFAbsoluteTimeGetCurrent()
                let t = scene.time
                playIntSecond = t.integralPart
                playingFrameRate = scene.timeline.frameRate
                playFrameTime = scene.frameTime(withBeatTime: scene.time)
                playingDrawnCount = 0
                if let url = scene.sound.url {
                    do {
                        try audioPlayer = AVAudioPlayer(contentsOf: url)
                        audioPlayer?.volume = Float(scene.sound.volume)
                    } catch {
                    }
                }
                audioPlayer?.currentTime = Double(scene.secondTime(withBeatTime: t))
                audioPlayer?.play()
                timer.begin(interval: 1 / Second(scene.frameRate),
                            tolerance: 0.1 / Second(scene.frameRate),
                            closure: { [unowned self] in self.updatePlayTime() })
                drawView.displayLinkDraw()
            } else {
                timer.stop()
                audioPlayers.forEach { $0.stop() }
                audioPlayers = []
                drawView.image = nil
            }
        }
    }
    
    var isPause = false {
        didSet {
            guard isPause != oldValue else { return }
            if isPause {
                timer.stop()
                audioPlayers.forEach { $0.pause() }
            } else {
                playingDrawnCount = 0
                oldTimestamp = CFAbsoluteTimeGetCurrent()
                playFrameRate = scene.frameRate
                timer.begin(interval: 1 / Second(scene.frameRate),
                            tolerance: 0.1 / Second(scene.frameRate),
                            closure: { [unowned self] in self.updatePlayTime() })
                
                audioPlayer?.play()
            }
        }
    }
    
    init(binder: Binder, keyPath: BinderKeyPath, sceneKeyPath: KeyPath<Binder, Scene>,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        self.sceneKeyPath = sceneKeyPath
        
        super.init()
        drawView.drawClosure = { [unowned self] ctx, _ in self.draw(in: ctx) }
        
        children = [drawView, timeStringView, frameRateView, timeView]
        
        timeView.movePointClosure = { [unowned self] in
            switch $1 {
            case .began: self.isPause = true
            case .changed: break
            case .ended: self.isPause = false
            }
        }
    }
    
    static func sliderView(with bounds: Rect, padding: Real) -> View {
        let shapeRect = Rect(x: padding, y: bounds.midY - 1,
                             width: bounds.width - padding * 2, height: 2)
        let view = View(path: CGPath(rect: shapeRect, transform: nil))
        view.fillColor = .content
        return view
    }

    override func updateLayout() {
        let paddingOrigin = Point(x: (bounds.width - scene.canvas.frame.size.width) / 2,
                                  y: (bounds.height - scene.canvas.frame.size.height) / 2)
        drawView.frame = Rect(origin: paddingOrigin, size: scene.canvas.frame.size)
        screenTransform = CGAffineTransform(translationX: drawView.bounds.midX,
                                            y: drawView.bounds.midY)
        
        let padding = Layout.basicPadding, height = Layout.basicHeight
        let sliderY = round((frame.height - height) / 2)
        let labelHeight = Layout.basicHeight - padding * 2
        let labelY = round((frame.height - labelHeight) / 2)
        
        timeStringView.frame.origin = Point(x: padding, y: labelY)
        let frw = Layout.valueWidth(with: .regular)
        playingFrameRateView.frame = Rect(x: bounds.width - frw - padding,
                                          y: padding * 2, width: frw, height: height - padding * 2)
        let sliderWidth = frameRateView.frame.minX - timeStringView.frame.maxX - padding * 2
        timeView.frame = Rect(x: timeStringView.frame.maxX + padding,
                              y: sliderY, width: sliderWidth, height: height)
        timeView.backgroundViews = [ScenePlayerView.sliderView(with: timeView.bounds,
                                                               padding: timeView.padding)]
    }
    func updateWithModel() {
        
    }
    private func updateWithFrameRate() {
        let oldBounds = playingFrameRateView.bounds
        playingFrameRateView.model = playingFrameRate
        playingFrameRateView.optionStringView.textMaterial.color = playingFrameRate < frameRate ?
            .warning : .locked
        if oldBounds.size != playingFrameRateView.bounds.size { updateLayout() }
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
        
        if isPlaying && !isPause {
            playingDrawnCount += 1
            let newTimestamp = CFAbsoluteTimeGetCurrent()
            let deltaTime = Second(newTimestamp - oldTimestamp)
            if deltaTime >= 1 {
                let newPlayingFrameRate = min(scene.timeline.frameRate,
                                              FPS(round(Second(playingDrawnCount) / deltaTime)))
                if newPlayingFrameRate != playingFrameRate {
                    playingFrameRate = newPlayingFrameRate
                    didSetPlayFrameRateClosure?(playingFrameRate)
                }
                oldTimestamp = newTimestamp
                playingDrawnCount = 0
            }
        } else {
            playingFrameRate = 0
        }
    }
    private func update(withTime newTime: Beat) {
        drawView.displayLinkDraw()
        updateBinding()
    }
    override func draw(in ctx: CGContext) {
        ctx.concatenate(screenTransform)
        scene.draw(time: time, viewType: .preview, in: ctx)
    }

    func play() {
        if isPlaying {
            isPlaying = false
            isPlaying = true
        } else {
            isPlaying = true
        }
    }
    
    func stop() {
        if isPlaying {
            isPlaying = false
        }
        endPlayClosure?(self)
    }
}
extension ScenePlayerView: Queryable {
    static var referenceableType: Referenceable.Type {
        return Model.self
    }
}
extension ScenePlayerView: Localizable {
    func update(with locale: Locale) {
        updateLayout()
    }
}
