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
    var time = 0.0.cg, isEnableDelay = false, volume = 1.0.cg, isMute = false
    var playRange: ClosedRange<Real> = -0.5...2.0, isUsingRange = false
    var isPlaying = false
    var playingTime = 0.0.cg, playingFrameRate = 0.0.cg
    
    static func minuteSecondString(withSecond s: Int, frameRate: Real) -> String {
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
    static let playingFrameRateOption = RealGetterOption(numberOfDigits: 0, unit: " fps")
    static let timeOption = RealOption(minModel: 0, maxModel: 1)
}
extension Player: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect) -> View {
        return "\(time) b".thumbnailView(withFrame: frame)
    }
}
extension Player: Viewable {
    func standardViewWith<T: BinderProtocol>
        (binder: T, keyPath: ReferenceWritableKeyPath<T, Player>) -> ModelView {
        
        return MiniView(binder: binder, keyPath: keyPath)
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
    
    private var screenTransform = AffineTransform.identity
    
    private var playingFrameTime = 0, playIntSecond = 0
    private var playingDrawnCount = 0, delayTolerance = 0.5
    
    private var displayLink = DisplayLink()
    private var oldPlayTime = Rational(0), oldTimestamp = 0.0
    
    var time = 0.0.cg {
        didSet {
            second = Int(time)
        }
    }
    var maxTime = 1.0.cg {
        didSet {
            timeView.option.maxModel = maxTime
        }
    }
    let frameRate = 60.0.cg
    private(set) var second = 0 {
        didSet {
            guard second != oldValue else { return }
            let oldSize = timeStringView.minSize
            let string = Player.minuteSecondString(withSecond: second,
                                                   frameRate: frameRate)
            timeStringView.text = Text(string)
            if oldSize != timeStringView.minSize { updateLayout() }
        }
    }
    
    var playingFrameRate = 0.0.cg {
        didSet { updateWithFrameRate() }
    }
    
    let timeStringView = TextFormView(text: "00:00", color: .locked)
    let playingFrameRateView: RealGetterView<Binder>
    let timeView: MovableRealView<Binder>
    let drawView = View(drawClosure: { _, _, _ in })
    
    var isPlaying = false {
        didSet {
            guard isPlaying != oldValue else { return }
            if isPlaying {
                oldPlayTime = scene.editingTime
                playingDrawnCount = 0
                oldTimestamp = Date.timeIntervalSinceReferenceDate
                let t = scene.editingTime
                playIntSecond = t.integralPart
                playingFrameRate = frameRate
                playingFrameTime = scene.frameTime(withTime: scene.editingTime)
                playingDrawnCount = 0

                drawView.displayLinkDraw()
            } else {
                displayLink?.stop()
                displayLink = nil
                drawView.image = nil
            }
        }
    }
    
    var isPause = false {
        didSet {
            guard isPause != oldValue else { return }
            if isPause {
                displayLink?.stop()
            } else {
                playingDrawnCount = 0
                oldTimestamp = Date.timeIntervalSinceReferenceDate
                playingFrameRate = frameRate
                displayLink?.time = model.playingTime
                displayLink?.start()
            }
        }
    }
    
    init(binder: Binder, keyPath: BinderKeyPath, sceneKeyPath: KeyPath<Binder, Scene>) {
        self.binder = binder
        self.keyPath = keyPath
        self.sceneKeyPath = sceneKeyPath
        playingFrameRateView
            = RealGetterView(binder: binder,
                             keyPath: keyPath.appending(path: \Model.playingFrameRate),
                             option: Model.playingFrameRateOption)
        
        timeView = MovableRealView(binder: binder, keyPath: keyPath.appending(path: \Model.time),
                                    option: Model.timeOption)
        
        super.init(isLocked: false)
        drawView.drawClosure = { [unowned self] ctx, _, _ in self.draw(in: ctx) }
        
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
            self.update(withTime: self.scene.basedTime(withTime: $0))
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

    var minSize: Size {
        let padding = Layouter.basicPadding
        let w = timeStringView.minSize.width
            + timeView.minSize.width + playingFrameRateView.minSize.width
        return Size(width: w + padding * 2, height: timeView.minSize.height + padding * 2)
    }
    override func updateLayout() {
        let padding = Layouter.basicPadding, height = Layouter.basicHeight
        
        drawView.frame = Rect(x: padding, y: padding + height,
                              width: bounds.width - padding * 2,
                              height: bounds.height - height - padding * 2)
        
        let timeMinSize = timeStringView.minSize
        timeStringView.frame = Rect(origin: Point(x: padding, y: padding * 2), size: timeMinSize)
        let frw = Layouter.basicValueWidth
        playingFrameRateView.frame = Rect(x: bounds.width - frw - padding,
                                          y: padding * 2, width: frw, height: height - padding * 2)
        let sliderWidth = playingFrameRateView.frame.minX - timeStringView.frame.maxX - padding * 2
        timeView.frame = Rect(x: timeStringView.frame.maxX + padding,
                              y: padding, width: sliderWidth, height: height)
        timeView.backgroundViews = [ScenePlayerView.sliderView(with: timeView.bounds,
                                                               padding: timeView.padding)]
    }
    func updateWithModel() {
        playingFrameRateView.updateWithModel()
        timeView.updateWithModel()
        displayLink?.frameRate = frameRate
    }
    private func updateWithFrameRate() {
        let oldMinSize = playingFrameRateView.minSize
        playingFrameRateView.updateWithModel()
        playingFrameRateView.optionStringView.textMaterial.color
            = playingFrameRate < frameRate ? .warning : .locked
        if oldMinSize != playingFrameRateView.minSize { updateLayout() }
    }
    var allowableDelayTime = 0.1.cg
    private func updatePlayTime() {
        playingFrameTime += 1
        
        if !model.isEnableDelay {
            let playTime: Real = scene.time(withFrameTime: playingFrameTime)
            let audioTime = model.playingTime
            if abs(playTime - audioTime) > allowableDelayTime {
                playingFrameTime = scene.frameTime(withTime: audioTime)
            }
        }
        
        let newTime: Rational = scene.time(withFrameTime: playingFrameTime)
        update(withTime: newTime)
    }
    private func updatePlayingFrameRate() {
        if isPlaying && !isPause {
            playingDrawnCount += 1
            let newTimestamp = Date.timeIntervalSinceReferenceDate
            let deltaTime = Real(newTimestamp - oldTimestamp)
            if deltaTime >= 1 {
                let newPlayingFrameRate = min(frameRate,
                                              ((Real(playingDrawnCount) / deltaTime)).rounded())
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
    private func update(withTime newTime: Rational) {
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
