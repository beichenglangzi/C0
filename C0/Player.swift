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

import struct Foundation.Date
import class CoreGraphics.CGContext

struct Player: Codable {
    var time = Second(0), isEnableDelay = false, volume = 1.0.cg, isMute = false
    var playRange: ClosedRange<Double> = -0.5...2.0, isUsingRange = false
    var isPlaying = false
    var playingTime = Second(0), playingFrameRate = FPS(0)
    
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
extension Player {
    static let playingFrameRateOption = RealGetterOption(numberOfDigits: 1, unit: " fps")
    static let timeOption = RealOption(defaultModel: 0, minModel: 0, maxModel: 1)
}
extension Player: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return "\(time) b".thumbnailView(withFrame: frame, sizeType)
    }
}
extension Player: AbstractViewable {
    func abstractViewWith<T>(binder: T, keyPath: ReferenceWritableKeyPath<T, Player>,
                             frame: Rect, _ sizeType: SizeType,
                             type: AbstractType) -> ModelView where T : BinderProtocol {
        return MiniView(binder: binder, keyPath: keyPath, frame: frame, sizeType)
    }
}
extension Player: ObjectViewable {}

final class ScenePlayerView<T: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = Player
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((ScenePlayerView<Binder>, BasicNotification) -> ())]()
    
    var sceneKeyPath: KeyPath<Binder, Scene> {
        didSet { updateWithModel() }
    }
    var scene: Scene {
        return binder[keyPath: sceneKeyPath]
    }
    
    var defaultModel = Player()
    
    private var screenTransform = AffineTransform.identity
    private var audioPlayers = [SoundPlayer]()
    
    private var playingFrameTime = FrameTime(0), playIntSecond = 0
    private var playingDrawnCount = 0, delayTolerance = 0.5
    
    private var displayLink = DisplayLink()
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
    
    let timeStringView = TextFormView(text: "00:00", color: .locked)
    let playingFrameRateView: RealGetterView<Binder>
    let timeView: SlidableRealView<Binder>
    let drawView = View(drawClosure: { _, _ in })
    
    var isPlaying = false {
        didSet {
            guard isPlaying != oldValue else { return }
            if isPlaying {
                oldPlayTime = scene.timeline.editingTime
                playingDrawnCount = 0
                oldTimestamp = Date.timeIntervalSinceReferenceDate
                let t = scene.timeline.editingTime
                playIntSecond = t.integralPart
                playingFrameRate = scene.timeline.frameRate
                playingFrameTime = scene.timeline.frameTime(withBeatTime: scene.timeline.editingTime)
                playingDrawnCount = 0
                
//                let sound = Sound()//allsounds
//                if let soundPlayer = sound.soundPlayer {
//                    soundPlayer.currentTime = scene.timeline.secondTime(withBeatTime: t)
//                    soundPlayer.play()
//                }

                drawView.displayLinkDraw()
            } else {
                displayLink?.stop()
                displayLink = nil
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
                displayLink?.stop()
                audioPlayers.forEach { $0.pause() }
            } else {
                playingDrawnCount = 0
                oldTimestamp = Date.timeIntervalSinceReferenceDate
                playingFrameRate = scene.timeline.frameRate
                displayLink?.time = model.playingTime
                displayLink?.start()
                audioPlayers.forEach { $0.play() }
            }
        }
    }
    
    init(binder: Binder, keyPath: BinderKeyPath, sceneKeyPath: KeyPath<Binder, Scene>,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        self.sceneKeyPath = sceneKeyPath
        playingFrameRateView
            = RealGetterView(binder: binder,
                             keyPath: keyPath.appending(path: \Model.playingFrameRate),
                             option: Model.playingFrameRateOption,
                             sizeType: sizeType)
        
        timeView = SlidableRealView(binder: binder, keyPath: keyPath.appending(path: \Model.time),
                                    option: Model.timeOption, sizeType: sizeType)
        super.init()
        drawView.drawClosure = { [unowned self] ctx, _ in self.draw(in: ctx) }
        
        children = [drawView, timeStringView, playingFrameRateView, timeView]
        
        timeView.notifications.append({ [unowned self] in
            guard case .didChangeFromPhase(let phase, _) = $1 else { return }
            switch phase {
            case .began: self.isPause = true
            case .changed: break
            case .ended: self.isPause = false
            }
        })
        
        displayLink?.closure = { [unowned self] in
            self.update(withTime: self.scene.timeline.basedBeatTime(withSecondTime: $0))
        }
    }
    
    static func sliderView(with bounds: Rect, padding: Real) -> View {
        let shapeRect = Rect(x: padding, y: bounds.midY - 1,
                             width: bounds.width - padding * 2, height: 2)
        var path = Path()
        path.append(shapeRect)
        let view = View(path: path)
        view.fillColor = .content
        return view
    }

    override func updateLayout() {
        let paddingOrigin = Point(x: (bounds.width - scene.canvas.frame.size.width) / 2,
                                  y: (bounds.height - scene.canvas.frame.size.height) / 2)
        drawView.frame = Rect(origin: paddingOrigin, size: scene.canvas.frame.size)
        screenTransform = AffineTransform(translation: drawView.bounds.midPoint)
        
        let padding = Layouter.basicPadding, height = Layouter.basicHeight
        let sliderY = ((frame.height - height) / 2).rounded()
        let labelHeight = Layouter.basicHeight - padding * 2
        let labelY = ((frame.height - labelHeight) / 2).rounded()
        
        timeStringView.frame.origin = Point(x: padding, y: labelY)
        let frw = Layouter.valueWidth(with: .regular)
        playingFrameRateView.frame = Rect(x: bounds.width - frw - padding,
                                          y: padding * 2, width: frw, height: height - padding * 2)
        let sliderWidth = playingFrameRateView.frame.minX - timeStringView.frame.maxX - padding * 2
        timeView.frame = Rect(x: timeStringView.frame.maxX + padding,
                              y: sliderY, width: sliderWidth, height: height)
        timeView.backgroundViews = [ScenePlayerView.sliderView(with: timeView.bounds,
                                                               padding: timeView.padding)]
    }
    func updateWithModel() {
        displayLink?.frameRate = scene.timeline.frameRate
    }
    private func updateWithFrameRate() {
        let oldBounds = playingFrameRateView.bounds
        playingFrameRateView.updateWithModel()
        playingFrameRateView.optionStringView.textMaterial.color
            = playingFrameRate < scene.timeline.frameRate ? .warning : .locked
        if oldBounds.size != playingFrameRateView.bounds.size { updateLayout() }
    }
    var allowableDelayTime = Second(0.1)
    private func updatePlayTime() {
        playingFrameTime += 1
        
        if !model.isEnableDelay {
            let playTime = scene.timeline.secondTime(withFrameTime: playingFrameTime)
            let audioTime = model.playingTime
            if abs(playTime - audioTime) > allowableDelayTime {
                playingFrameTime = scene.timeline.frameTime(withSecondTime: audioTime)
            }
        }
        
        let newTime = scene.timeline.beatTime(withFrameTime: playingFrameTime)
        update(withTime: newTime)
    }
    private func updatePlayingFrameRate() {
        if isPlaying && !isPause {
            playingDrawnCount += 1
            let newTimestamp = Date.timeIntervalSinceReferenceDate
            let deltaTime = Second(newTimestamp - oldTimestamp)
            if deltaTime >= 1 {
                let newPlayingFrameRate = min(scene.timeline.frameRate,
                                              FPS((Second(playingDrawnCount) / deltaTime)).rounded())
                if newPlayingFrameRate != playingFrameRate {
                    playingFrameRate = newPlayingFrameRate
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
        updatePlayingFrameRate()
    }
    override func draw(in ctx: CGContext) {
        ctx.concatenate(screenTransform)
//        scene.draw(time: time, in: ctx)
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
    }
}
