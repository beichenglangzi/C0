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

//# Issue
//再生中の時間移動

import Foundation
import QuartzCore

import AppKit.NSCursor

struct DrawInfo {
    let scale: CGFloat, cameraScale: CGFloat, reciprocalScale: CGFloat, reciprocalCameraScale: CGFloat, rotation: CGFloat
    init(scale: CGFloat = 1, cameraScale: CGFloat = 1, rotation: CGFloat = 0) {
        if scale == 0 || cameraScale == 0 {
            fatalError()
        }
        self.scale = scale
        self.cameraScale = cameraScale
        self.reciprocalScale = 1/scale
        self.reciprocalCameraScale = 1/cameraScale
        self.rotation = rotation
    }
}

protocol PlayerDelegate: class {
    func endPlay(_ player: Player)
}
final class Player: LayerRespondable, Localizable {
    static let type = ObjectType(identifier: "Player", name: Localization(english: "Player", japanese: "プレイヤー"))
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children)
        }
    }
    var undoManager: UndoManager?
    var locale = Locale.current {
        didSet {
            outsideStopLabel.locale = locale
        }
    }
    
    weak var delegate: PlayerDelegate?
    
    var layer = CALayer.interfaceLayer(), drawLayer = DrawLayer()
    var drawInfo = DrawInfo()
    var playCutEntity: CutEntity? {
        didSet {
            if let playCutEntity = playCutEntity {
                self.cut = playCutEntity.cut.deepCopy
            }
        }
    }
    var cut = Cut()
    var time = 0 {
        didSet {
            cut.time = time
            let cameraScale = cut.camera.transform.zoomScale.width
            drawInfo = DrawInfo(scale: cut.camera.transform.zoomScale.width, cameraScale: cameraScale, rotation:cut.camera.transform.rotation)
        }
    }
    var scene = Scene()
    func draw(in ctx: CGContext) {
        cut.draw(scene, with: drawInfo, in: ctx)
    }
    
    var outsidePadding = 100.0.cf, timeLabelWidth = 40.0.cf
    let outsideStopLabel = Label(text: Localization(english: "Playing (Stop at the Click)", japanese: "再生中（クリックで停止）"), font: Defaults.smallFont, color: Defaults.smallFontColor, backgroundColor: SceneDefaults.playBorderColor, height: 24)
    let timeLabel = Label(string: "00:00", color: Defaults.smallFontColor, backgroundColor: SceneDefaults.playBorderColor, height: 30)
    let cutLabel = Label(string: "C1", color: Defaults.smallFontColor, backgroundColor: SceneDefaults.playBorderColor, height: 30)
    let fpsLabel = Label(string: "0fps", color: Defaults.smallFontColor, backgroundColor: SceneDefaults.playBorderColor, height: 30)
    
    init() {
        layer.backgroundColor = SceneDefaults.playBorderColor
        drawLayer.borderWidth = 0
        drawLayer.drawBlock = { [unowned self] ctx in
            self.draw(in: ctx)
        }
        children = [outsideStopLabel, timeLabel, cutLabel, fpsLabel]
        update(withChildren: children)
        layer.addSublayer(drawLayer)
    }
    
    var frame: CGRect {
        get {
            return layer.frame
        }
        set {
            layer.frame = newValue
            layer.bounds.origin = CGPoint(x: -outsidePadding, y: -outsidePadding)
            drawLayer.frame = CGRect(origin: CGPoint(), size: scene.cameraFrame.size)
            let w = ceil(outsideStopLabel.textLine.stringBounds.width + 4)
            let alltw = timeLabelWidth*3
            outsideStopLabel.frame = CGRect(x: bounds.midX - floor(w/2), y: bounds.maxY + bounds.origin.y/2 - 12, width: w, height: 24)
            timeLabel.frame = CGRect(x: bounds.midX - floor(alltw/2), y: bounds.origin.y/2 - 15, width: timeLabelWidth, height: 30)
            cutLabel.frame = CGRect(x: bounds.midX - floor(alltw/2) + timeLabelWidth, y: bounds.origin.y/2 - 15, width: timeLabelWidth, height: 30)
            fpsLabel.frame = CGRect(x: bounds.midX - floor(alltw/2) + timeLabelWidth*2, y: bounds.origin.y/2 - 15, width: timeLabelWidth, height: 30)
        }
    }
    
    var sceneEntity = SceneEntity()
    var selectionCutEntity = CutEntity()
    
    let fps = 24.0.cf
    
    var contentsScale: CGFloat {
        get {
            return layer.contentsScale
        }
        set {
            layer.contentsScale = newValue
            drawLayer.contentsScale = newValue
            allChildren { ($0 as? LayerRespondable)?.layer.contentsScale = newValue }
        }
    }
    
    private var timer = LockTimer(), oldPlayCutEntity: CutEntity?, oldPlayTime = 0, oldTimestamp = 0.0, playDrawCount = 0, playCutIndex = 0, playSecond = 0, playFPS = 0, delayTolerance = 0.5
    var isPlaying = false {
        didSet {
            if isPlaying {
                playCutEntity = selectionCutEntity
                oldPlayCutEntity = selectionCutEntity
                time = selectionCutEntity.cut.time
                oldPlayTime = selectionCutEntity.cut.time
                oldTimestamp = CFAbsoluteTimeGetCurrent()
                let t = Double(currentPlayTime)/Double(scene.frameRate)
                playSecond = Int(t)
                playCutIndex = selectionCutEntity.index
                playFPS = scene.frameRate
                playDrawCount = 0
                timeLabel.textLine.string = minuteSecondString(withSecond: playSecond, frameRate: scene.frameRate)
                cutLabel.textLine.string = "C\(playCutIndex + 1)"
                fpsLabel.textLine.string = "\(playFPS)fps"
                fpsLabel.textLine.color = playFPS != scene.frameRate ? Defaults.warningColor : Defaults.smallFontColor
                scene.soundItem.sound?.currentTime = t
                scene.soundItem.sound?.play()
                timer.begin(1/fps.d, tolerance: 0.1/fps.d) { [unowned self] in
                    self.updatePlayTime()
                }
                drawLayer.setNeedsDisplay()
            } else {
                timer.stop()
//                selectionCutEntity.cut.time = oldPlayTime
                playCutEntity = nil
                scene.soundItem.sound?.stop()
                drawLayer.contents = nil
            }
        }
    }
    private func updatePlayTime() {
        if let playCutEntity = playCutEntity {
            var updated = false
            if let sound = scene.soundItem.sound, !scene.soundItem.isHidden {
                let t = Int(sound.currentTime*Double(scene.frameRate))
                let pt = currentPlayTime + 1
                if abs(pt - t) > 1 {
                    let viewIndex = sceneEntity.cutIndex(withTime: t)
                    if viewIndex.isOver {
                        self.playCutEntity = sceneEntity.cutEntities[0]
//                        sceneEntity.cutEntities[0].
//                        cut.
                        time = 0
                        scene.soundItem.sound?.currentTime = 0
                    } else {
                        let cutEntity = sceneEntity.cutEntities[viewIndex.index]
                        if cutEntity != playCutEntity {
                            self.playCutEntity = cutEntity
                        }
//                        playCutEntity.cut.
                        time =  viewIndex.interTime
                    }
                    updated = true
                }
            }
            if !updated {
                let nextTime = time + 1
                if nextTime < playCutEntity.cut.timeLength {
//                    playCutEntity.
//                    cut.
                    time =  nextTime
                } else if sceneEntity.cutEntities.count == 1 {
//                    playCutEntity.
//                    cut.
                    time = 0
                } else {
                    let cutIndex = sceneEntity.cutEntities.index(of: playCutEntity) ?? 0
                    let nextCutIndex = cutIndex + 1 <= sceneEntity.cutEntities.count - 1 ? cutIndex + 1 : 0
                    let nextCutEntity = sceneEntity.cutEntities[nextCutIndex]
//                    playCutEntity.cut.time = oldPlayTime
                    self.playCutEntity = nextCutEntity
//                    nextCutEntity.
//                    cut.
                    time = 0
                    if nextCutIndex == 0 {
                        scene.soundItem.sound?.currentTime = 0
                    }
                }
                drawLayer.setNeedsDisplay()
            }
            
            let t = currentPlayTime
            let s = t/scene.frameRate
            if s != playSecond {
                playSecond = s
                timeLabel.textLine.string = minuteSecondString(withSecond: playSecond, frameRate: scene.frameRate)
            }
            
            if playCutIndex != playCutEntity.index {
                playCutIndex = playCutEntity.index
                cutLabel.textLine.string = "C\(playCutIndex + 1)"
            }
            
            playDrawCount += 1
            let newTimestamp = CFAbsoluteTimeGetCurrent()
            let deltaTime = newTimestamp - oldTimestamp
            if deltaTime >= 1 {
                let newPlayFPS = min(scene.frameRate, Int(round(Double(playDrawCount)/deltaTime)))
                if newPlayFPS != playFPS {
                    playFPS = newPlayFPS
                    fpsLabel.textLine.string = "\(playFPS)fps"
                    fpsLabel.textLine.color = playFPS != scene.frameRate ? Defaults.warningColor : Defaults.smallFontColor
                }
                oldTimestamp = newTimestamp
                playDrawCount = 0
            }
        }
    }
    func minuteSecondString(withSecond s: Int, frameRate: Int) -> String {
        if s >= 60 {
            let minute = s/60
            let second = s - minute*60
            return String(format: "%02d:%02d", minute, second)
        } else {
            return String(format: "00:%02d", s)
        }
    }
    var currentPlayTime: Int {
        var t = 0
        for entity in sceneEntity.cutEntities {
            if playCutEntity != entity {
                t += entity.cut.timeLength
            } else {
                t += entity.cut.time
                break
            }
        }
        return t
    }
    
    func play(with event: KeyInputEvent) {
        if isPlaying {
            if let oldPlayCutEntity = oldPlayCutEntity {
                playCutEntity = oldPlayCutEntity
            }
            time = oldPlayTime
            scene.soundItem.sound?.currentTime = Double(currentPlayTime)/Double(scene.frameRate)
        } else {
            isPlaying = true
        }
    }
    func click(with event: DragEvent) {
        stop()
    }
    
    func zoom(with event: PinchEvent) {
    }
    func rotate(with event: RotateEvent) {
    }
    func stop() {
        if isPlaying {
            isPlaying = false
        }
        delegate?.endPlay(self)
    }
    
    func drag(with event: DragEvent) {
    }
    func scroll(with event: ScrollEvent) {
    }
}

final class Canvas: LayerRespondable, PlayerDelegate, Localizable {
    static let type = ObjectType(identifier: "Canvas", name: Localization(english: "Canvas", japanese: "キャンバス"))
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children)
        }
    }
    var undoManager: UndoManager?
    var locale = Locale.current {
        didSet {
            player.locale = locale
        }
    }
    
    weak var sceneEditor: SceneEditor!
    
    let player = Player()
    
    var scene = Scene() {
        didSet {
            player.scene = scene
            updateViewAffineTransform()
        }
    }
    var cutEntity = CutEntity() {
        didSet {
            updateViewAffineTransform()
            setNeedsDisplay(in: oldValue.cut.imageBounds)
            setNeedsDisplay(in: cutEntity.cut.imageBounds)
            player.selectionCutEntity = cutEntity
        }
    }
    var cut: Cut {
        return cutEntity.cut
    }
    
    var isUpdate: Bool {
        get {
            return cutEntity.isUpdate
        }
        set {
            cutEntity.isUpdate = newValue
            setNeedsDisplay()
            sceneEditor.timeline.setNeedsDisplay()
        }
    }
    
    var contentsScale: CGFloat {
        get {
            return layer.contentsScale
        }
        set {
            layer.contentsScale = newValue
            player.contentsScale = newValue
        }
    }
    
    var layer: CALayer {
        return drawLayer
    }
    private let drawLayer = DrawLayer()
    
    init() {
        drawLayer.bounds = cameraFrame.insetBy(dx: -player.outsidePadding, dy: -player.outsidePadding)
        drawLayer.frame.origin = drawLayer.bounds.origin
        drawLayer.drawBlock = { [unowned self] ctx in
            self.draw(in: ctx)
        }
        layer.backgroundColor = SceneDefaults.playBorderColor
        bounds = drawLayer.bounds
        player.frame = bounds
        player.delegate = self
    }
    
    static let strokeCurosr = NSCursor.circleCursor(size: 2)
    var cursor = Canvas.strokeCurosr
    func cursor(with p: CGPoint) -> NSCursor {
        return cursor
    }
    
    var editQuasimode = EditQuasimode.none
    var materialEditorType = MaterialEditor.ViewType.none {
        didSet {
            updateViewType()
        }
    }
    var isOpenedPlayer = false {
        didSet {
            if isOpenedPlayer != oldValue {
                if isOpenedPlayer {
                    CATransaction.disableAnimation {
                        player.frame = frame
                        sceneEditor.children.append(player)
                    }
                } else {
                    player.removeFromParent()
                }
            }
        }
    }
    func setEditQuasimode(_ editQuasimode: EditQuasimode, with event: Event) {
        self.editQuasimode = editQuasimode
        let p = convertToCut(point(from: event))
        switch editQuasimode {
        case .none:
            cursor = Canvas.strokeCurosr
            moveZCell = nil
            editPoint = nil
            editTransform = nil
        case .movePoint:
            cursor = NSCursor.arrow()
            moveZCell = nil
        case .moveVertex:
            cursor = NSCursor.arrow()
            moveZCell = nil
        case .snapPoint:
            cursor = NSCursor.arrow()
            moveZCell = nil
        case .moveZ:
            cursor = Defaults.upDownCursor
            moveZCell = indicationCellItem?.cell
            editPoint = nil
        case .move:
            cursor = NSCursor.arrow()
            moveZCell = nil
            editPoint = nil
        case .warp:
            cursor = NSCursor.arrow()
            moveZCell = nil
            editPoint = nil
            transformAnchorPoint = p
        case .transform:
            cursor = NSCursor.arrow()
            moveZCell = nil
            editPoint = nil
            transformAnchorPoint = p
        }
        updateViewType()
        updateEditView(with: p)
    }
    private func updateViewType() {
        if materialEditorType == .selection {
            viewType = .editMaterial
        } else if materialEditorType == .preview {
            viewType = .editingMaterial
        } else {
            switch editQuasimode {
            case .none:
                viewType = .edit
            case .movePoint:
                viewType = .editPoint
            case .moveVertex:
                viewType = .editWarpLine
            case .snapPoint:
                viewType = .editSnap
            case .moveZ:
                viewType = .editMoveZ
            case .move:
                viewType = .edit
            case .warp:
                viewType = .editWarp
            case .transform:
                viewType = .editTransform
            }
        }
    }
    var viewType = Cut.ViewType.edit {
        didSet {
            updateViewAffineTransform()
            setNeedsDisplay()
        }
    }
    func updateEditView(with p : CGPoint) {
        switch viewType {
        case .edit, .editMaterial, .editingMaterial, .preview:
            break
        case .editPoint, .editWarpLine, .editSnap:
            updateEditPoint(with: p)
            editTransform = nil
        case .editMoveZ:
            updateMoveZ(with: p)
            editPoint = nil
            editTransform = nil
        case .editWarp, .editTransform:
            editPoint = nil
            updateEditTransform(with: p)
        }
        indicationCellItem = cut.cellItem(at: p, with: cut.editGroup)
    }
    var editTransform: Cut.EditTransform? {
        didSet {
            setNeedsDisplay()
        }
    }
    var editPoint: Cut.EditPoint? {
        didSet {
            setNeedsDisplay()
        }
    }
    func updateEditPoint(with point: CGPoint) {
        if let n = cut.nearest(at: point, isWarp: viewType == .editWarpLine, isUseCells: !cut.isInterpolatedKeyframe(with: cut.editGroup)) {
            if let e = n.drawingEdit {
                editPoint = Cut.EditPoint(nearestLine: e.line, nearestPointIndex: e.pointIndex, lines: [e.line], point: n.point, isSnap: moveIsSnap)
            } else if let e = n.cellItemEdit {
                editPoint = Cut.EditPoint(nearestLine: e.geometry.lines[e.lineIndex], nearestPointIndex: e.pointIndex, lines: [e.geometry.lines[e.lineIndex]], point: n.point, isSnap: moveIsSnap)
            } else if n.drawingEditLineCap != nil || !n.cellItemEditLineCaps.isEmpty {
                if let nlc = n.bezierSortedResult(at: point) {
                    if let e = n.drawingEditLineCap {
                        editPoint = Cut.EditPoint(nearestLine: nlc.lineCap.line, nearestPointIndex: nlc.lineCap.pointIndex, lines: e.drawingCaps.map { $0.line } + n.cellItemEditLineCaps.reduce([Line]()) { $0 + $1.caps.map { $0.line } }, point: n.point, isSnap: moveIsSnap)
                    } else {
                        editPoint = Cut.EditPoint(nearestLine: nlc.lineCap.line, nearestPointIndex: nlc.lineCap.pointIndex, lines: n.cellItemEditLineCaps.reduce([Line]()) { $0 + $1.caps.map { $0.line } }, point: n.point, isSnap: moveIsSnap)
                    }
                } else {
                    editPoint = nil
                }
            }
        } else {
            editPoint = nil
        }
    }
    var transformAnchorPoint = CGPoint()
    func updateEditTransform(with point: CGPoint) {
        editTransform = Cut.EditTransform(anchorPoint: transformAnchorPoint, point: point, oldPoint: point)
    }

    var cameraFrame: CGRect {
        get {
            return scene.cameraFrame
        }
        set {
            scene.cameraFrame = frame
            updateWithScene()
            drawLayer.bounds.origin = CGPoint(x: -ceil((frame.width - frame.width)/2), y: -ceil((frame.height - frame.height)/2))
            drawLayer.frame.origin = drawLayer.bounds.origin
            bounds = drawLayer.bounds
        }
    }
    var time: Int {
        get {
            return scene.time
        }
        set {
            sceneEditor.timeline.time = newValue
        }
    }
    var isShownPrevious: Bool {
        get {
            return scene.isShownPrevious
        }
        set {
            scene.isShownPrevious = newValue
            updateWithScene()
        }
    }
    var isShownNext: Bool {
        get {
            return scene.isShownNext
        }
        set {
            scene.isShownNext = newValue
            updateWithScene()
        }
    }
    var viewTransform: ViewTransform {
        get {
            return scene.viewTransform
        }
        set {
            scene.viewTransform = newValue
            updateViewAffineTransform()
            updateWithScene()
        }
    }
    private func updateWithScene() {
        setNeedsDisplay()
        sceneEditor.sceneEntity.isUpdatePreference = true
    }
    func updateViewAffineTransform() {
        let cameraScale = cut.camera.transform.zoomScale.width
        var affine = CGAffineTransform.identity
        if viewType != .preview, let t = scene.affineTransform {
            affine = affine.concatenating(t)
            drawInfo = DrawInfo(scale: cameraScale*viewTransform.scale, cameraScale: cameraScale, rotation: cut.camera.transform.rotation + viewTransform.rotation)
        } else {
            drawInfo = DrawInfo(scale: cut.camera.transform.zoomScale.width, cameraScale: cameraScale, rotation:cut.camera.transform.rotation)
        }
        if let cameraAffine = cut.camera.affineTransform {
            affine = cameraAffine.concatenating(affine)
        }
        viewAffineTransform = affine
    }
    private var drawInfo = DrawInfo()
    private(set) var viewAffineTransform: CGAffineTransform? {
        didSet {
            setNeedsDisplay()
        }
    }
    func convertFromCut(_ point: CGPoint) -> CGPoint {
        return layer.convert(convertFromInternal(point), from: drawLayer)
    }
    func convertToCut(_ viewPoint: CGPoint) -> CGPoint {
        return convertToInternal(drawLayer.convert(viewPoint, from: layer))
    }
    func convertToInternal(_ r: CGRect) -> CGRect {
        if let affine = viewAffineTransform {
            return r.applying(affine.inverted())
        } else {
            return r
        }
    }
    func convertFromInternal(_ r: CGRect) -> CGRect {
        if let affine = viewAffineTransform {
            return r.applying(affine)
        } else {
            return r
        }
    }
    func convertToInternal(_ point: CGPoint) -> CGPoint {
        if let affine = viewAffineTransform {
            return point.applying(affine.inverted())
        } else {
            return point
        }
    }
    func convertFromInternal(_ p: CGPoint) -> CGPoint {
        if let affine = viewAffineTransform {
            return p.applying(affine)
        } else {
            return p
        }
    }
    
    var indication = false {
        didSet {
            if !indication {
                indicationCellItem = nil
            }
        }
    }
    var indicationCellItem: CellItem? {
        didSet {
            if indicationCellItem != oldValue {
                setNeedsDisplay()
            }
        }
    }
    
    func setNeedsDisplay() {
        drawLayer.setNeedsDisplay()
    }
    func setNeedsDisplay(in rect: CGRect) {
        if let affine = viewAffineTransform {
            drawLayer.setNeedsDisplayIn(rect.applying(affine))
        } else {
            drawLayer.setNeedsDisplayIn(rect)
        }
    }
    
    func draw(in ctx: CGContext) {
        func drawStroke(in ctx: CGContext) {
            if let strokeLine = strokeLine {
                cut.drawStrokeLine(strokeLine, lineColor: strokeLineColor, lineWidth: strokeLineWidth*drawInfo.reciprocalCameraScale, in: ctx)
            }
        }
        if viewType == .preview {
            if viewTransform.isFlippedHorizontal {
                ctx.flipHorizontal(by: cameraFrame.width)
            }
            cut.draw(sceneEditor.scene, with: drawInfo, in: ctx)
            drawStroke(in: ctx)
        } else {
            if let affine = scene.affineTransform {
                ctx.saveGState()
                ctx.concatenate(affine)
                cut.draw(sceneEditor.scene, viewType: viewType, editMaterial: viewType == .editMaterial ? nil : sceneEditor.materialEditor.material,
                         indicationCellItem: indicationCellItem, moveZCell: moveZCell, editPoint: editPoint, editTransform: editTransform, isShownPrevious: isShownPrevious, isShownNext: isShownNext, with: drawInfo, in: ctx)
                drawStroke(in: ctx)
                ctx.restoreGState()
            } else {
                cut.draw(sceneEditor.scene, viewType: viewType, editMaterial: viewType == .editMaterial ? nil : sceneEditor.materialEditor.material,
                         indicationCellItem: indicationCellItem, moveZCell: moveZCell, editPoint: editPoint, editTransform: editTransform, isShownPrevious: isShownPrevious, isShownNext: isShownNext, with: drawInfo, in: ctx)
                drawStroke(in: ctx)
            }
            drawCautionBorder(in: ctx)
        }
    }
    private func drawCautionBorder(in ctx: CGContext) {
        func drawBorderWith(bounds: CGRect, width: CGFloat, color: CGColor, in ctx: CGContext) {
            ctx.setFillColor(color)
            ctx.fill([
                CGRect(x: bounds.minX, y: bounds.minY, width: width, height: bounds.height),
                CGRect(x: bounds.minX + width, y: bounds.minY, width: bounds.width - width*2, height: width),
                CGRect(x: bounds.minX + width, y: bounds.maxY - width, width: bounds.width - width*2, height: width),
                CGRect(x: bounds.maxX - width, y: bounds.minY, width: width, height: bounds.height)
                ])
        }
        let borderWidth = 2.0.cf, bounds = self.bounds
        if viewTransform.rotation > .pi/2 || viewTransform.rotation < -.pi/2 {
            drawBorderWith(bounds: bounds, width: borderWidth*2, color: SceneDefaults.rotateCautionColor, in: ctx)
        }
    }
    
    private func registerUndo(_ handler: @escaping (Canvas, Int) -> Void) {
        undoManager?.registerUndo(withTarget: self) { [oldTime = time] in handler($0, oldTime) }
    }
    
    func copy(with event: KeyInputEvent) -> CopyObject {
        let p = convertToCut(point(from: event))
        let indicationCellsTuple = cut.indicationCellsTuple(with : p)
        switch indicationCellsTuple.type {
        case .none:
            let copySelectionLines = cut.editGroup.drawingItem.drawing.editLines
            if !copySelectionLines.isEmpty {
                let drawing = Drawing(lines: copySelectionLines)
                return CopyObject(objects: [drawing.deepCopy])
            }
        case .indication, .selection:
            let cell = cut.rootCell.intersection(indicationCellsTuple.cells).deepCopy
            let material = indicationCellsTuple.cells[0].material
            return CopyObject(objects: [cell.deepCopy, material])
        }
        return CopyObject()
    }
    func paste(_ copyObject: CopyObject, with event: KeyInputEvent) {
        for object in copyObject.objects {
            if let color = object as? Color {
                paste(color, with: event)
            } else if let copyDrawing = object as? Drawing {
                let p = convertToCut(point(from: event))
                let indicationCellsTuple = cut.indicationCellsTuple(with : p)
                if indicationCellsTuple.type != .none, let cellItem = cut.editGroup.cellItem(with: indicationCellsTuple.cells[0]) {
                    let nearestPathLineIndex = cellItem.cell.geometry.nearestPathLineIndex(at: p)
                    let previousLine = cellItem.cell.geometry.lines[nearestPathLineIndex]
                    let nextLine = cellItem.cell.geometry.lines[nearestPathLineIndex + 1 >= cellItem.cell.geometry.lines.count ? 0 : nearestPathLineIndex + 1]
                    let geometry = Geometry(lines: [Line(controls: [Line.Control(point: nextLine.firstPoint, pressure: 1), Line.Control(point: previousLine.lastPoint, pressure: 1)])] + copyDrawing.lines, scale: drawInfo.scale)
                    let lines = geometry.lines.withRemovedFirst()
                    setGeometries(Geometry.geometriesWithInserLines(with: cellItem.keyGeometries, lines: lines, atLinePathIndex: nearestPathLineIndex), oldKeyGeometries: cellItem.keyGeometries, in: cellItem, cut.editGroup, time: time)
                } else {
                    let drawing = cut.editGroup.drawingItem.drawing, oldCount = drawing.lines.count
                    let lineIndexes = Set((0 ..< copyDrawing.lines.count).map { $0 + oldCount })
                    setLines(drawing.lines + copyDrawing.lines, oldLines: drawing.lines, drawing: drawing, time: time)
                    setSelectionLineIndexes(Array(Set(drawing.selectionLineIndexes).union(lineIndexes)), in: drawing, time: time)
                }
            } else if !cut.isInterpolatedKeyframe(with: cut.editGroup), let copyRootCell = object as? Cell {
                for copyCell in copyRootCell.allCells {
                    for group in cut.groups {
                        for ci in group.cellItems {
                            if ci.cell.id == copyCell.id {
                                setGeometry(copyCell.geometry, oldGeometry: ci.cell.geometry, at: group.editKeyframeIndex, in: ci, time: time)
                            }
                        }
                    }
                }
            }
        }
    }
    func paste(_ color: Color, with event: KeyInputEvent) {
        let indicationCellsTuple = cut.indicationCellsTuple(with : convertToCut(point(from: event)))
        if indicationCellsTuple.type != .none {
            let selectionMaterial = indicationCellsTuple.cells.first!.material
            if color != selectionMaterial.color {
                sceneEditor.materialEditor.paste(color, withSelection: selectionMaterial, useSelection: indicationCellsTuple.type == .selection)
            }
        }
    }
    func paste(_ material: Material, with event: KeyInputEvent) {
        let indicationCellsTuple = cut.indicationCellsTuple(with : convertToCut(point(from: event)))
        if indicationCellsTuple.type != .none {
            let selectionMaterial = indicationCellsTuple.cells.first!.material
            if material != selectionMaterial {
                sceneEditor.materialEditor.paste(material, withSelection: selectionMaterial, useSelection: indicationCellsTuple.type == .selection)
            }
        }
    }
    func delete(with event: KeyInputEvent) {
        if deleteCells(with: event) {
            return
        }
        if deleteSelectionDrawingLines() {
            return
        }
        if deleteDrawingLines() {
            return
        }
    }
    func deleteSelectionDrawingLines() -> Bool {
        let drawingItem = cut.editGroup.drawingItem
        if !drawingItem.drawing.selectionLineIndexes.isEmpty {
            let unseletionLines = drawingItem.drawing.uneditLines
            setSelectionLineIndexes([], in: drawingItem.drawing, time: time)
            setLines(unseletionLines, oldLines: drawingItem.drawing.lines, drawing: drawingItem.drawing, time: time)
            return true
        } else {
            return false
        }
    }
    func deleteDrawingLines() -> Bool {
        let drawingItem = cut.editGroup.drawingItem
        if !drawingItem.drawing.lines.isEmpty {
            setLines([], oldLines: drawingItem.drawing.lines, drawing: drawingItem.drawing, time: time)
            return true
        } else {
            return false
        }
    }
    func deleteCells(with event: KeyInputEvent) -> Bool {
        guard !cut.isInterpolatedKeyframe(with: cut.editGroup) else {
            return false
        }
        let point = convertToCut(self.point(from: event))
        let indicationCellsTuple = cut.indicationCellsTuple(with: point)
        switch indicationCellsTuple.type {
        case .selection:
            var isChanged = false
            for group in cut.groups {
                let removeSelectionCellItems = group.editSelectionCellItemsWithNoEmptyGeometry.filter {
                    if !$0.cell.geometry.isEmpty {
                        setGeometry(Geometry(), oldGeometry: $0.cell.geometry, at: group.editKeyframeIndex, in: $0, time: time)
                        isChanged = true
                        if $0.isEmptyKeyGeometries {
                            return true
                        }
                    }
                    return false
                }
                if !removeSelectionCellItems.isEmpty {
                    removeCellItems(removeSelectionCellItems)
                }
            }
            if isChanged {
                return true
            }
        case .indication:
            if let cellItem = cut.cellItem(at: point, with: cut.editGroup) {
                if !cellItem.cell.geometry.isEmpty {
                    setGeometry(Geometry(), oldGeometry: cellItem.cell.geometry, at: cut.editGroup.editKeyframeIndex, in: cellItem, time: time)
                    if cellItem.isEmptyKeyGeometries {
                        removeCellItems([cellItem])
                    }
                    return true
                }
            }
        case .none:
            break
        }
        return false
    }
    
    private func removeCellItems(_ cellItems: [CellItem]) {
        var cellItems = cellItems
        while !cellItems.isEmpty {
            let cellRemoveManager = cut.cellRemoveManager(with: cellItems.first!)
            for groupAndCellItems in cellRemoveManager.groupAndCellItems {
                let group = groupAndCellItems.group, cellItems = groupAndCellItems.cellItems
                let removeSelectionCellItems = Array(Set(group.selectionCellItems).subtracting(cellItems))
                if removeSelectionCellItems.count != cut.editGroup.selectionCellItems.count {
                    setSelectionCellItems(removeSelectionCellItems, in: group, time: time)
                }
            }
            removeCell(with: cellRemoveManager, time: time)
            cellItems = cellItems.filter { !cellRemoveManager.contains($0) }
        }
    }
    private func insertCell(with cellRemoveManager: Cut.CellRemoveManager, time: Int) {
        registerUndo { $0.removeCell(with: cellRemoveManager, time: $1) }
        self.time = time
        cut.insertCell(with: cellRemoveManager)
        isUpdate = true
    }
    private func removeCell(with cellRemoveManager: Cut.CellRemoveManager, time: Int) {
        registerUndo { $0.insertCell(with: cellRemoveManager, time: $1) }
        self.time = time
        cut.removeCell(with: cellRemoveManager)
        isUpdate = true
    }
    
    private func setGeometries(_ keyGeometries: [Geometry], oldKeyGeometries: [Geometry], in cellItem: CellItem, _ group: Group, time: Int) {
        registerUndo { $0.setGeometries(oldKeyGeometries, oldKeyGeometries: keyGeometries, in: cellItem, group, time: $1) }
        self.time = time
        group.setKeyGeometries(keyGeometries, in: cellItem)
        isUpdate = true
    }
    private func setGeometry(_ geometry: Geometry, oldGeometry: Geometry, at i: Int, in cellItem: CellItem, time: Int) {
        registerUndo { $0.setGeometry(oldGeometry, oldGeometry: geometry, at: i, in: cellItem, time: $1) }
        self.time = time
        cellItem.replaceGeometry(geometry, at: i)
        isUpdate = true
    }
    
    func play(with event: KeyInputEvent) {
        isOpenedPlayer = true
        player.play(with: event)
    }
    func endPlay(_ player: Player) {
        isOpenedPlayer = false
    }
    
    func addCellWithLines(with event: KeyInputEvent) {
        guard !cut.isInterpolatedKeyframe(with: cut.editGroup) else {
            return
        }
        let drawingItem = cut.editGroup.drawingItem, rootCell = cut.rootCell
        let geometry = Geometry(lines: drawingItem.drawing.editLines, scale: drawInfo.scale)
        if !geometry.isEmpty {
            let isDrawingSelectionLines = !drawingItem.drawing.selectionLineIndexes.isEmpty
            let unselectionLines = drawingItem.drawing.uneditLines
            if isDrawingSelectionLines {
                setSelectionLineIndexes([], in: drawingItem.drawing, time: time)
            }
            setLines(unselectionLines, oldLines: drawingItem.drawing.lines, drawing: drawingItem.drawing, time: time)
            let lki = cut.editGroup.loopedKeyframeIndex(withTime: cut.time)
            let keyGeometries = cut.editGroup.emptyKeyGeometries.withReplaced(geometry, at: lki.index)
            let newCellItem = CellItem(cell: Cell(geometry: geometry, material: Material(color: Color.random())), keyGeometries: keyGeometries)
            insertCell(newCellItem, in: [(rootCell, addCellIndex(with: newCellItem.cell, in: rootCell))], cut.editGroup, time: time)
        }
    }
    func addAndClipCellWithLines(with event: KeyInputEvent) {
        guard !cut.isInterpolatedKeyframe(with: cut.editGroup) else {
            return
        }
        let drawingItem = cut.editGroup.drawingItem
        let geometry = Geometry(lines: drawingItem.drawing.editLines, scale: drawInfo.scale)
        if !geometry.isEmpty {
            let isDrawingSelectionLines = !drawingItem.drawing.selectionLineIndexes.isEmpty
            let unselectionLines = drawingItem.drawing.uneditLines
            if isDrawingSelectionLines {
                setSelectionLineIndexes([], in: drawingItem.drawing, time: time)
            }
            setLines(unselectionLines, oldLines: drawingItem.drawing.lines, drawing: drawingItem.drawing, time: time)
            
            let lki = cut.editGroup.loopedKeyframeIndex(withTime: cut.time)
            let keyGeometries = cut.editGroup.emptyKeyGeometries.withReplaced(geometry, at: lki.index)
            let newCellItem = CellItem(cell: Cell(geometry: geometry, material: Material(color: Color.random())), keyGeometries: keyGeometries)
            let p = point(from: event)
            let ict = cut.indicationCellsTuple(with: convertToCut(p), usingLock: false)
            if ict.type == .selection {
                insertCell(newCellItem, in: ict.cells.map { ($0, addCellIndex(with: newCellItem.cell, in: $0)) }, cut.editGroup, time: time)
            } else {
                let ict = cut.indicationCellsTuple(with: convertToCut(p), usingLock: true)
                if ict.type != .none {
                    insertCell(newCellItem, in: ict.cells.map { ($0, addCellIndex(with: newCellItem.cell, in: $0)) }, cut.editGroup, time: time)
                }
            }
        }
    }
    private func addCellIndex(with cell: Cell, in parent: Cell) -> Int {
        let editCells = cut.editGroup.cells
        for i in (0 ..< parent.children.count).reversed() {
            if editCells.contains(parent.children[i]) && parent.children[i].contains(cell) {
                return i + 1
            }
        }
        for i in 0 ..< parent.children.count {
            if editCells.contains(parent.children[i]) && parent.children[i].intersects(cell) {
                return i
            }
        }
        for i in 0 ..< parent.children.count {
            if editCells.contains(parent.children[i]) && !parent.children[i].isLocked {
                return i
            }
        }
        return cellIndex(withGroupIndex: cut.editGroupIndex, in: parent)
    }
    
    func cellIndex(withGroupIndex groupIndex: Int, in parent: Cell) -> Int {
        for i in groupIndex + 1 ..< cut.groups.count {
            let group = cut.groups[i]
            var maxIndex = 0, isMax = false
            for cellItem in group.cellItems {
                if let j = parent.children.index(of: cellItem.cell) {
                    isMax = true
                    maxIndex = max(maxIndex, j)
                }
            }
            if isMax {
                return maxIndex + 1
            }
        }
        return 0
    }
    
    func moveCell(_ cell: Cell, from fromParents: [(cell: Cell, index: Int)], to toParents: [(cell: Cell, index: Int)], time: Int) {
        registerUndo { $0.moveCell(cell, from: toParents, to: fromParents, time: $1) }
        self.time = time
        for fromParent in fromParents {
            fromParent.cell.children.remove(at: fromParent.index)
        }
        for toParent in toParents {
            toParent.cell.children.insert(cell, at: toParent.index)
        }
        isUpdate = true
    }
    func lassoDelete(with event: KeyInputEvent) {
        let drawing = cut.editGroup.drawingItem.drawing, group = cut.editGroup
        if let lastLine = drawing.lines.last {
            removeLastLine(in: drawing, time: time)
            if !drawing.selectionLineIndexes.isEmpty {
                setSelectionLineIndexes([], in: drawing, time: time)
            }
            var isRemoveLineInDrawing = false, isRemoveLineInCell = false
            let lasso = Lasso(lines: [lastLine])
            let newDrawingLines = drawing.lines.reduce([Line]()) {
                if let splitLines = lasso.split($1) {
                    isRemoveLineInDrawing = true
                    return $0 + splitLines
                } else {
                    return $0 + [$1]
                }
            }
            if isRemoveLineInDrawing {
                setLines(newDrawingLines, oldLines: drawing.lines, drawing: drawing, time: time)
            }
            var removeCellItems = [CellItem]()
            if !cut.isInterpolatedKeyframe(with: cut.editGroup) {
                removeCellItems = group.cellItems.filter { cellItem in
                    if cellItem.cell.intersects(lasso) {
                        setGeometry(Geometry(), oldGeometry: cellItem.cell.geometry, at: group.editKeyframeIndex, in: cellItem, time: time)
                        if cellItem.isEmptyKeyGeometries {
                            return true
                        }
                        isRemoveLineInCell = true
                    }
                    return false
                }
            }
            if !isRemoveLineInDrawing && !isRemoveLineInCell {
                if !cut.isInterpolatedKeyframe(with: cut.editGroup), let hitCellItem = cut.cellItem(at: lastLine.firstPoint, with: group) {
                    let lines = hitCellItem.cell.geometry.lines
                    setGeometry(Geometry(), oldGeometry: hitCellItem.cell.geometry, at: group.editKeyframeIndex, in: hitCellItem, time: time)
                    if hitCellItem.isEmptyKeyGeometries {
                        removeCellItems.append(hitCellItem)
                    }
                    setLines(drawing.lines + lines, oldLines: drawing.lines, drawing: drawing, time: time)
                }
            }
            if !removeCellItems.isEmpty {
                self.removeCellItems(removeCellItems)
            }
        }
    }
    func lassoSelect(with event: KeyInputEvent) {
        lassoSelect(isDelete: false, with: event)
    }
    func lassoDeleteSelect(with event: KeyInputEvent) {
        lassoSelect(isDelete: true, with: event)
    }
    private func lassoSelect(isDelete: Bool, with event: KeyInputEvent) {
        let group = cut.editGroup
        let drawing = group.drawingItem.drawing
        if let lastLine = drawing.lines.last {
            if let index = drawing.selectionLineIndexes.index(of: drawing.lines.count - 1) {
                setSelectionLineIndexes(drawing.selectionLineIndexes.withRemoved(at: index), in: drawing, time: time)
            }
            removeLastLine(in: drawing, time: time)
            let lasso = Lasso(lines: [lastLine])
            let intersectionCellItems = Set(group.cellItems.filter { $0.cell.intersects(lasso) })
            let selectionCellItems = Array(isDelete ? Set(group.selectionCellItems).subtracting(intersectionCellItems) : Set(group.selectionCellItems).union(intersectionCellItems))
            let drawingLineIndexes = Set(drawing.lines.enumerated().flatMap { lasso.intersects($1) ? $0 : nil })
            let selectionLineIndexes = Array(isDelete ? Set(drawing.selectionLineIndexes).subtracting(drawingLineIndexes) : Set(drawing.selectionLineIndexes).union(drawingLineIndexes))
            if selectionCellItems != group.selectionCellItems {
                setSelectionCellItems(selectionCellItems, in: group, time: time)
            }
            if selectionLineIndexes != drawing.selectionLineIndexes {
                setSelectionLineIndexes(selectionLineIndexes, in: drawing, time: time)
            }
        }
    }
    
    func clipCellInSelection(with event: KeyInputEvent) {
        let point = convertToCut(self.point(from: event))
        if let fromCell = cut.rootCell.atPoint(point) {
            let selectionCells = cut.allEditSelectionCellsWithNoEmptyGeometry
            if selectionCells.isEmpty {
                if !cut.rootCell.children.contains(fromCell) {
                    let fromParents = cut.rootCell.parents(with: fromCell)
                    moveCell(fromCell, from: fromParents, to: [(cut.rootCell, cut.rootCell.children.count)], time: time)
                }
            } else if !selectionCells.contains(fromCell) {
                let fromChildrens = fromCell.allCells
                var newFromParents = cut.rootCell.parents(with: fromCell)
                let newToParents: [(cell: Cell, index: Int)] = selectionCells.flatMap { toCell in
                    for fromChild in fromChildrens {
                        if fromChild == toCell {
                            return nil
                        }
                    }
                    for (i, newFromParent) in newFromParents.enumerated() {
                        if toCell == newFromParent.cell {
                            newFromParents.remove(at: i)
                            return nil
                        }
                    }
                    return (toCell, toCell.children.count)
                }
                if !(newToParents.isEmpty && newFromParents.isEmpty) {
                    moveCell(fromCell, from: newFromParents, to: newToParents, time: time)
                }
            }
        }
    }
    
    private func insertCell(_ cellItem: CellItem, in parents: [(cell: Cell, index: Int)], _ group: Group, time: Int) {
        registerUndo { $0.removeCell(cellItem, in: parents, group, time: $1) }
        self.time = time
        cut.insertCell(cellItem, in: parents, group)
        isUpdate = true
    }
    private func removeCell(_ cellItem: CellItem, in parents: [(cell: Cell, index: Int)], _ group: Group, time: Int) {
        registerUndo { $0.insertCell(cellItem, in: parents, group, time: $1) }
        self.time = time
        cut.removeCell(cellItem, in: parents, group)
        isUpdate = true
    }
    private func insertCells(_ cellItems: [CellItem], rootCell: Cell, at index: Int, in parent: Cell, _ group: Group, time: Int) {
        registerUndo { $0.removeCells(cellItems, rootCell: rootCell, at: index, in: parent, group, time: $1) }
        self.time = time
        cut.insertCells(cellItems, rootCell: rootCell, at: index, in: parent, group)
        isUpdate = true
    }
    private func removeCells(_ cellItems: [CellItem], rootCell: Cell, at index: Int, in parent: Cell, _ group: Group, time: Int) {
        registerUndo { $0.insertCells(cellItems, rootCell: rootCell, at: index, in: parent, group, time: $1) }
        self.time = time
        cut.removeCells(cellItems, rootCell: rootCell, in: parent, group)
        isUpdate = true
    }
    
    func hide(with event: KeyInputEvent) {
        let seletionCells = cut.indicationCellsTuple(with : convertToCut(point(from: event)))
        for cell in seletionCells.cells {
            if !cell.isEditHidden {
                setIsEditHidden(true, in: cell, time: time)
            }
        }
    }
    func show(with event: KeyInputEvent) {
        for cell in cut.cells {
            if cell.isEditHidden {
                setIsEditHidden(false, in: cell, time: time)
            }
        }
    }
    func setIsEditHidden(_ isEditHidden: Bool, in cell: Cell, time: Int) {
        registerUndo { [oldIsEditHidden = cell.isEditHidden] in $0.setIsEditHidden(oldIsEditHidden, in: cell, time: $1) }
        self.time = time
        cell.isEditHidden = isEditHidden
        isUpdate = true
    }
    
    func minimize(with event: KeyInputEvent) {
        guard !cut.isInterpolatedKeyframe(with: cut.editGroup) else {
            return
        }
        let seletionCells = cut.indicationCellsTuple(with : convertToCut(point(from: event)))
        if seletionCells.cells.isEmpty {
            let drawing = cut.editGroup.drawingItem.drawing
            if !drawing.lines.isEmpty {
                setLines(drawing.lines.map { $0.bezierLine(withScale: drawInfo.scale) }, oldLines: drawing.lines, drawing: drawing, time: time)
            }
        } else {
            for cell in seletionCells.cells {
                if let cellItem = cut.editGroup.cellItem(with: cell) {
                    setGeometries(Geometry.bezierLineGeometries(with: cellItem.keyGeometries, scale: drawInfo.scale), oldKeyGeometries: cellItem.keyGeometries, in: cellItem, cut.editGroup, time: time)
                }
            }
        }
    }
    
    func pasteCell(_ copyObject: CopyObject, with event: KeyInputEvent) {
        guard !cut.isInterpolatedKeyframe(with: cut.editGroup) else {
            return
        }
        for object in copyObject.objects {
            if let copyRootCell = object as? Cell {
                let keyframeIndex = cut.editGroup.loopedKeyframeIndex(withTime: cut.time)
                var newCellItems = [CellItem]()
                copyRootCell.depthFirstSearch(duplicate: false) { parent, cell in
                    cell.id = UUID()
                    let keyGeometrys = cut.editGroup.emptyKeyGeometries.withReplaced(cell.geometry, at: keyframeIndex.index)
                    newCellItems.append(CellItem(cell: cell, keyGeometries: keyGeometrys, keyMaterials: []))
                }
                let index = cellIndex(withGroupIndex: cut.editGroupIndex, in: cut.rootCell)
                insertCells(newCellItems, rootCell: copyRootCell, at: index, in: cut.rootCell, cut.editGroup, time: time)
                setSelectionCellItems(cut.editGroup.selectionCellItems + newCellItems, in: cut.editGroup, time: time)
            }
        }
    }
    func pasteMaterial(_ copyObject: CopyObject, with event: KeyInputEvent) {
        for object in copyObject.objects {
            if let material = object as? Material {
                paste(material, with: event)
                return
            }
        }
    }
    func splitColor(with event: KeyInputEvent) {
        let point = convertToCut(self.point(from: event))
        let ict = cut.indicationCellsTuple(with: point)
        if !ict.cells.isEmpty {
            sceneEditor.materialEditor.splitColor(with: ict.cells)
        }
    }
    func splitOtherThanColor(with event: KeyInputEvent) {
        let point = convertToCut(self.point(from: event))
        let ict = cut.indicationCellsTuple(with: point)
        if !ict.cells.isEmpty {
            sceneEditor.materialEditor.splitOtherThanColor(with: ict.cells)
        }
    }
    
    func changeToRough(with event: KeyInputEvent) {
        let drawing = cut.editGroup.drawingItem.drawing
        if !drawing.roughLines.isEmpty || !drawing.lines.isEmpty {
            setRoughLines(drawing.editLines, oldLines: drawing.roughLines, drawing: drawing, time: time)
            setLines(drawing.uneditLines, oldLines: drawing.lines, drawing: drawing, time: time)
            if !drawing.selectionLineIndexes.isEmpty {
                setSelectionLineIndexes([], in: drawing, time: time)
            }
        }
    }
    func removeRough(with event: KeyInputEvent) {
        let drawing = cut.editGroup.drawingItem.drawing
        if !drawing.roughLines.isEmpty {
            setRoughLines([], oldLines: drawing.roughLines, drawing: drawing, time: time)
        }
    }
    func swapRough(with event: KeyInputEvent) {
        let drawing = cut.editGroup.drawingItem.drawing
        if !drawing.roughLines.isEmpty || !drawing.lines.isEmpty {
            if !drawing.selectionLineIndexes.isEmpty {
                setSelectionLineIndexes([], in: drawing, time: time)
            }
            let newLines = drawing.roughLines, newRoughLines = drawing.lines
            setRoughLines(newRoughLines, oldLines: drawing.roughLines, drawing: drawing, time: time)
            setLines(newLines, oldLines: drawing.lines, drawing: drawing, time: time)
        }
    }
    private func setRoughLines(_ lines: [Line], oldLines: [Line], drawing: Drawing, time: Int) {
        registerUndo { $0.setRoughLines(oldLines, oldLines: lines, drawing: drawing, time: $1) }
        self.time = time
        drawing.roughLines = lines
        isUpdate = true
        sceneEditor.timeline.setNeedsDisplay()
    }
    private func setLines(_ lines: [Line], oldLines: [Line], drawing: Drawing, time: Int) {
        registerUndo { $0.setLines(oldLines, oldLines: lines, drawing: drawing, time: $1) }
        self.time = time
        drawing.lines = lines
        isUpdate = true
    }
    
    func moveCursor(with event: MoveEvent) {
        updateEditView(with: convertToCut(point(from: event)))
    }
    
    private var strokeLine: Line?, strokeLineColor = SceneDefaults.strokeLineColor, strokeLineWidth = SceneDefaults.strokeLineWidth
    private var strokeOldPoint = CGPoint(), strokeOldTime = 0.0, strokeOldLastBounds = CGRect(), strokeIsDrag = false, strokeControls: [Line.Control] = [], strokeBeginTime = 0.0
    private let strokeSplitAngle = 1.5*(.pi)/2.0.cf, strokeLowSplitAngle = 0.9*(.pi)/2.0.cf, strokeDistance = 1.0.cf, strokeTime = 0.1, strokeSlowDistance = 3.5.cf, strokeSlowTime = 0.25, strokeShortTime = 0.1, strokeShortLinearDistance = 1.0.cf, strokeShortLinearMaxDistance = 1.5.cf
    func drag(with event: DragEvent) {
        drag(with: event, lineWidth: strokeLineWidth, strokeDistance: strokeDistance, strokeTime: strokeTime)
    }
    func slowDrag(with event: DragEvent) {
        drag(with: event, lineWidth: strokeLineWidth, strokeDistance: strokeSlowDistance, strokeTime: strokeSlowTime, splitAcuteAngle: false)
    }
    func drag(with event: DragEvent, lineWidth: CGFloat, strokeDistance: CGFloat, strokeTime: Double, splitAcuteAngle: Bool = true) {
        let p = convertToCut(point(from: event))
        switch event.sendType {
        case .begin:
            let firstControl = Line.Control(point: p, pressure: event.pressure)
            let line = Line(controls: [firstControl, firstControl])
            strokeLine = line
            strokeOldPoint = p
            strokeOldTime = event.time
            strokeBeginTime = event.time
            strokeOldLastBounds = line.strokeLastBoundingBox
            strokeIsDrag = false
            strokeControls = [firstControl]
        case .sending:
            if var line = strokeLine, p != strokeOldPoint {
                strokeIsDrag = true
                let ac = strokeControls.first!, bp = p, lc = strokeControls.last!, scale = drawInfo.scale
                let control = Line.Control(point: p, pressure: event.pressure)
                strokeControls.append(control)
                if splitAcuteAngle && line.controls.count >= 3 {
                    let c0 = line.controls[line.controls.count - 3], c1 = line.controls[line.controls.count - 2], c2 = lc
                    if c0.point != c1.point && c1.point != c2.point {
                        let dr = abs(CGPoint.differenceAngle(p0: c0.point, p1: c1.point, p2: c2.point))
                        if dr > strokeLowSplitAngle {
                            if dr > strokeSplitAngle {
                                line = line.withInsert(c1, at: line.controls.count - 1)
                                let  lastBounds = line.strokeLastBoundingBox
                                strokeLine = line
                                setNeedsDisplay(in: lastBounds.union(strokeOldLastBounds).inset(by: -lineWidth/2))
                                strokeOldLastBounds = lastBounds
                            } else {
                                let t = 1 - (dr - strokeLowSplitAngle)/strokeSplitAngle
                                let tp = CGPoint.linear(c1.point, c2.point, t: t)
                                if c1.point != tp {
                                    line = line.withInsert(Line.Control(point: tp, pressure: CGFloat.linear(c1.pressure, c2.pressure, t:  t)), at: line.controls.count - 1)
                                    let  lastBounds = line.strokeLastBoundingBox
                                    strokeLine = line
                                    setNeedsDisplay(in: lastBounds.union(strokeOldLastBounds).inset(by: -lineWidth/2))
                                    strokeOldLastBounds = lastBounds
                                }
                            }
                        }
                    }
                }
                if line.controls[line.controls.count - 2].point != lc.point {
                    for (i, sp) in strokeControls.enumerated() {
                        if i > 0 {
                            if sp.point.distanceWithLine(ap: ac.point, bp: bp)*scale > strokeDistance || event.time - strokeOldTime > strokeTime {
                                line = line.withInsert(lc, at: line.controls.count - 1)
                                strokeLine = line
                                let lastBounds = line.strokeLastBoundingBox
                                setNeedsDisplay(in: lastBounds.union(strokeOldLastBounds).inset(by: -lineWidth/2))
                                strokeOldLastBounds = lastBounds
                                strokeControls = [lc]
                                strokeOldTime = event.time
                                break
                            }
                        }
                    }
                }
                line = line.withReplaced(control, at: line.controls.count - 1)
                strokeLine = line
                let lastBounds = line.strokeLastBoundingBox
                setNeedsDisplay(in: lastBounds.union(strokeOldLastBounds).inset(by: -lineWidth/2))
                strokeOldLastBounds = lastBounds
                strokeOldPoint = p
            }
        case .end:
            if let line = strokeLine {
                strokeLine = nil
                if strokeIsDrag {
                    let scale = drawInfo.scale
                    func lastRevisionLine(line: Line) -> Line {
                        if line.controls.count > 3 {
                            let ap = line.controls[line.controls.count - 3].point, bp = p, lp = line.controls[line.controls.count - 2].point
                            if !(lp.distanceWithLine(ap: ap, bp: bp)*scale > strokeDistance || event.time - strokeOldTime > strokeTime) {
                                return line.withRemoveControl(at: line.controls.count - 2)
                            }
                        }
                        return line
                    }
                    var newLine = lastRevisionLine(line: line)
                    if event.time - strokeBeginTime < strokeShortTime && newLine.controls.count > 3 {
                        var maxD = 0.0.cf, maxControl = newLine.controls[0]
                        for control in newLine.controls {
                            let d = control.point.distanceWithLine(ap: newLine.firstPoint, bp: newLine.lastPoint)
                            if d*scale > maxD {
                                maxD = d
                                maxControl = control
                            }
                        }
                        let mcp = maxControl.point.nearestWithLine(ap: newLine.firstPoint, bp: newLine.lastPoint)
                        let cp = 2*maxControl.point - mcp
                        
                        let b = Bezier2(p0: newLine.firstPoint, cp: cp, p1: newLine.lastPoint)
                        var isShort = true
                        newLine.allEditPoints { p, i in
                            let nd = p.distance(b.position(withT: b.nearestT(with: p)))
                            if nd*scale > strokeShortLinearMaxDistance {
                                isShort = false
                            }
                        }
                        if isShort {
                            newLine = Line(controls: [newLine.controls[0], Line.Control(point: cp, pressure: maxControl.pressure), newLine.controls[newLine.controls.count - 1]])
                        }
                    }
                    addLine(newLine.withReplaced(Line.Control(point: p, pressure: newLine.controls.last!.pressure), at: newLine.controls.count - 1), in: cut.editGroup.drawingItem.drawing, time: time)
                }
            }
        }
    }
    private func addLine(_ line: Line, in drawing: Drawing, time: Int) {
        registerUndo { $0.removeLastLine(in: drawing, time: $1) }
        self.time = time
        drawing.lines.append(line)
        isUpdate = true
    }
    private func removeLastLine(in drawing: Drawing, time: Int) {
        registerUndo { [lastLine = drawing.lines.last!] in $0.addLine(lastLine, in: drawing, time: $1) }
        self.time = time
        drawing.lines.removeLast()
        isUpdate = true
    }
    private func insertLine(_ line: Line, at i: Int, in drawing: Drawing, time: Int) {
        registerUndo { $0.removeLine(at: i, in: drawing, time: $1) }
        self.time = time
        drawing.lines.insert(line, at: i)
        isUpdate = true
    }
    private func removeLine(at i: Int, in drawing: Drawing, time: Int) {
        let oldLine = drawing.lines[i]
        registerUndo { $0.insertLine(oldLine, at: i, in: drawing, time: $1) }
        self.time = time
        drawing.lines.remove(at: i)
        isUpdate = true
    }
    private func setSelectionLineIndexes(_ lineIndexes: [Int], in drawing: Drawing, time: Int) {
        registerUndo { [os = drawing.selectionLineIndexes] in $0.setSelectionLineIndexes(os, in: drawing, time: $1) }
        self.time = time
        drawing.selectionLineIndexes = lineIndexes
        isUpdate = true
    }
    
    func click(with event: DragEvent) {
        selectCell(at: point(from: event))
    }
    func selectCell(at point: CGPoint) {
        let p = convertToCut(point)
        let selectionCell = cut.rootCell.nearestCell(at: p)//cut.rootCell.cells(at: p).first
        if let selectionCell = selectionCell {
            if selectionCell.material.id != sceneEditor.materialEditor.material.id {
                setMaterial(selectionCell.material, time: time)
            }
        } else {
            if MaterialEditor.emptyMaterial != sceneEditor.materialEditor.material {
                setMaterial(MaterialEditor.emptyMaterial, time: time)
            }
            for group in cut.groups {
                if !group.selectionCellItems.isEmpty {
                    setSelectionCellItems([], in: group, time: time)
                }
            }
            for group in cut.groups {
                if !group.drawingItem.drawing.selectionLineIndexes.isEmpty {
                    setSelectionLineIndexes([], in: group.drawingItem.drawing, time: time)
                }
            }
        }
    }
    private func setMaterial(_ material: Material, time: Int) {
        registerUndo { [om = sceneEditor.materialEditor.material] in $0.setMaterial(om, time: $1) }
        self.time = time
        sceneEditor.materialEditor.material = material
    }
    private func setSelectionCellItems(_ cellItems: [CellItem], in group: Group, time: Int) {
        registerUndo { [os = group.selectionCellItems] in $0.setSelectionCellItems(os, in: group, time: $1) }
        self.time = time
        group.selectionCellItems = cellItems
        setNeedsDisplay()
        sceneEditor.timeline.setNeedsDisplay()
        isUpdate = true
    }
    
    func addPoint(with event: KeyInputEvent) {
        let p = convertToCut(point(from: event))
        if let nearest = cut.nearestLine(at: p, isUseCells: !cut.isInterpolatedKeyframe(with: cut.editGroup)) {
            if let drawing = nearest.drawing {
                replaceLine(nearest.line.splited(at: nearest.pointIndex), oldLine: nearest.line, at: nearest.lineIndex, in: drawing, time: time)
                updateEditView(with: p)
            } else if let cellItem = nearest.cellItem {
                setGeometries(Geometry.geometriesWithSplitedControl(with: cellItem.keyGeometries, at: nearest.lineIndex, pointIndex: nearest.pointIndex), oldKeyGeometries: cellItem.keyGeometries, in: cellItem, cut.editGroup, time: time)
                updateEditView(with: p)
            }
        }
    }
    func deletePoint(with event: KeyInputEvent) {
        let p = convertToCut(point(from: event))
        if let nearest = cut.nearestLine(at: p, isUseCells: !cut.isInterpolatedKeyframe(with: cut.editGroup)) {
            if let drawing = nearest.drawing {
                if nearest.line.controls.count > 2 {
                    replaceLine(nearest.line.removedControl(at: nearest.pointIndex), oldLine: nearest.line, at: nearest.lineIndex, in: drawing, time: time)
                } else {
                    removeLine(at: nearest.lineIndex, in: drawing, time: time)
                }
                updateEditView(with: p)
            } else if let cellItem = nearest.cellItem {
                setGeometries(Geometry.geometriesWithRemovedControl(with: cellItem.keyGeometries, atLineIndex: nearest.lineIndex, index: nearest.pointIndex), oldKeyGeometries: cellItem.keyGeometries, in: cellItem, cut.editGroup, time: time)
                if cellItem.isEmptyKeyGeometries {
                    removeCellItems([cellItem])
                }
                updateEditView(with: p)
            }
        }
    }
    private func insert(_ control: Line.Control, at index: Int, in drawing: Drawing, _ lineIndex: Int, time: Int) {
        registerUndo { $0.removeControl(at: index, in: drawing, lineIndex, time: $1) }
        self.time = time
        drawing.lines[lineIndex] = drawing.lines[lineIndex].withInsert(control, at: index)
        isUpdate = true
    }
    private func removeControl(at index: Int, in drawing: Drawing, _ lineIndex: Int, time: Int) {
        let line = drawing.lines[lineIndex]
        registerUndo { [oc = line.controls[index]] in $0.insert(oc, at: index, in: drawing, lineIndex, time: $1) }
        self.time = time
        drawing.lines[lineIndex] = line.withRemoveControl(at: index)
        isUpdate = true
    }
    
    private var movePointNearest: Cut.Nearest?, movePointOldPoint = CGPoint(), moveIsSnap = false
    private let snapPointSnapDistance = 8.0.cf
    private var bezierSortedResult: Cut.Nearest.BezierSortedResult?
    func movePoint(with event: DragEvent) {
        movePoint(with: event, isVertex: false)
    }
    func moveVertex(with event: DragEvent) {
        movePoint(with: event, isVertex: true)
    }
    func movePoint(with event: DragEvent, isVertex: Bool) {
        let p = convertToCut(point(from: event))
        switch event.sendType {
        case .begin:
            if let nearest = cut.nearest(at: p, isWarp: isVertex, isUseCells: !cut.isInterpolatedKeyframe(with: cut.editGroup)) {
                bezierSortedResult = nearest.bezierSortedResult(at: p)
                movePointNearest = nearest
                moveIsSnap = event.pressure == 1
            }
            movePointOldPoint = p
            updateEditView(with: p)
        case .sending:
            let dp = p - movePointOldPoint
            if let nearest = movePointNearest {
                if nearest.drawingEdit != nil || nearest.cellItemEdit != nil {
//                    moveIsSnap = moveIsSnap ? true : event.pressure == 1
                    if let e = nearest.drawingEdit {
                        var control = e.line.controls[e.pointIndex]
                        control.point = e.line.editPoint(withEditCenterPoint: nearest.point + dp, at: e.pointIndex)
                        e.drawing.lines[e.lineIndex] = e.line.withReplaced(control, at: e.pointIndex)
                        editPoint = Cut.EditPoint(nearestLine: e.drawing.lines[e.lineIndex], nearestPointIndex: e.pointIndex, lines: [e.drawing.lines[e.lineIndex]], point: nearest.point + dp, isSnap: moveIsSnap)
                    } else if let e = nearest.cellItemEdit {
                        var control = e.geometry.lines[e.lineIndex].controls[e.pointIndex]
                        control.point = e.geometry.lines[e.lineIndex].editPoint(withEditCenterPoint: nearest.point + dp, at: e.pointIndex)
                        e.cellItem.cell.geometry = Geometry(lines: e.geometry.lines.withReplaced(e.geometry.lines[e.lineIndex].withReplaced(control, at: e.pointIndex).autoPressure(), at: e.lineIndex))
                        editPoint = Cut.EditPoint(nearestLine: e.cellItem.cell.geometry.lines[e.lineIndex], nearestPointIndex: e.pointIndex, lines: [e.cellItem.cell.geometry.lines[e.lineIndex]], point: nearest.point + dp, isSnap: moveIsSnap)
                    }
                } else {
                    let np: CGPoint
                    if moveIsSnap || event.pressure == 1, let b = bezierSortedResult {
                        moveIsSnap = true
                        let snapD = snapPointSnapDistance/drawInfo.scale
                        np = cut.editGroup.snapPoint(nearest.point + dp, with: b, snapDistance: snapD)
                        if let b = bezierSortedResult {
                            if let e = nearest.drawingEditLineCap, let drawing = b.drawing {
                                var newLines = e.lines
                                if isVertex {
                                    newLines[b.lineCap.lineIndex] = b.lineCap.line.warpedWith(deltaPoint: np - nearest.point, isFirst: b.lineCap.isFirst)
                                } else {
                                    let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                                    var control = b.lineCap.line.controls[pointIndex]
                                    control.point = np
                                    newLines[b.lineCap.lineIndex] = newLines[b.lineCap.lineIndex].withReplaced(control, at: b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1)
                                }
                                drawing.lines = newLines
                                editPoint = Cut.EditPoint(nearestLine: drawing.lines[b.lineCap.lineIndex], nearestPointIndex: b.lineCap.pointIndex, lines: drawing.lines, point: np, isSnap: moveIsSnap)
                            } else if let cellItem = b.cellItem, let geometry = b.geometry {
                                for editLineCap in nearest.cellItemEditLineCaps {
                                    if editLineCap.cellItem == cellItem {
                                        if isVertex {
                                            cellItem.cell.geometry = Geometry(lines: geometry.lines.withReplaced(b.lineCap.line.warpedWith(deltaPoint: np - nearest.point, isFirst: b.lineCap.isFirst).autoPressure(), at: b.lineCap.lineIndex))
                                        } else {
                                            let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                                            var control = geometry.lines[b.lineCap.lineIndex].controls[pointIndex]
                                            control.point = np
                                            cellItem.cell.geometry = Geometry(lines: geometry.lines.withReplaced(b.lineCap.line.withReplaced(control, at: pointIndex).autoPressure(), at: b.lineCap.lineIndex))
                                        }
                                        editPoint = Cut.EditPoint(nearestLine: cellItem.cell.geometry.lines[b.lineCap.lineIndex], nearestPointIndex: b.lineCap.pointIndex, lines: cellItem.cell.geometry.lines, point: np, isSnap: moveIsSnap)
                                    } else {
                                        editLineCap.cellItem.cell.geometry = editLineCap.geometry
                                    }
                                }
                            }
                        }
                    } else {
                        np = nearest.point + dp
                        var editPointLines = [Line]()
                        if let e = nearest.drawingEditLineCap {
                            var newLines = e.drawing.lines
                            if isVertex {
                                for cap in e.drawingCaps {
                                    newLines[cap.lineIndex] = cap.line.warpedWith(deltaPoint: dp, isFirst: cap.isFirst)
                                }
                            } else {
                                for cap in e.drawingCaps {
                                    var control = cap.isFirst ? cap.line.controls[0] : cap.line.controls[cap.line.controls.count - 1]
                                    control.point = np
                                    newLines[cap.lineIndex] = newLines[cap.lineIndex].withReplaced(control, at: cap.isFirst ? 0 : cap.line.controls.count - 1)
                                }
                            }
                            e.drawing.lines = newLines
                            editPointLines = e.drawingCaps.map { newLines[$0.lineIndex] }
                        }
                        
                        for editLineCap in nearest.cellItemEditLineCaps {
                            var newLines = editLineCap.geometry.lines
                            if isVertex {
                                for cap in editLineCap.caps {
                                    newLines[cap.lineIndex] = cap.line.warpedWith(deltaPoint: dp, isFirst: cap.isFirst).autoPressure()
                                }
                            } else {
                                for cap in editLineCap.caps {
                                    var control = cap.isFirst ? cap.line.controls[0] : cap.line.controls[cap.line.controls.count - 1]
                                    control.point = np
                                    newLines[cap.lineIndex] = newLines[cap.lineIndex].withReplaced(control, at: cap.isFirst ? 0 : cap.line.controls.count - 1).autoPressure()
                                }
                            }
                            editLineCap.cellItem.cell.geometry = Geometry(lines: newLines)
                            editPointLines += editLineCap.caps.map { newLines[$0.lineIndex] }
                        }
                        if let b = bezierSortedResult {
                            if let cellItem = b.cellItem {
                                editPoint = Cut.EditPoint(nearestLine: cellItem.cell.geometry.lines[b.lineCap.lineIndex], nearestPointIndex: b.lineCap.pointIndex, lines: Array(Set(editPointLines)), point: np, isSnap: moveIsSnap)
                            } else if let drawing = b.drawing {
                                editPoint = Cut.EditPoint(nearestLine: drawing.lines[b.lineCap.lineIndex], nearestPointIndex: b.lineCap.pointIndex, lines: Array(Set(editPointLines)), point: np, isSnap: moveIsSnap)
                            }
                        }
                    }
                }
            }
        case .end:
            let dp = p - movePointOldPoint
            if let nearest = movePointNearest {
                if nearest.drawingEdit != nil || nearest.cellItemEdit != nil {
                    if let e = nearest.drawingEdit {
                        var control = e.line.controls[e.pointIndex]
                        control.point = e.line.editPoint(withEditCenterPoint: nearest.point + dp, at: e.pointIndex)
                        replaceLine(e.line.withReplaced(control, at: e.pointIndex), oldLine: e.line, at: e.lineIndex, in: e.drawing, time: time)
                    } else if let e = nearest.cellItemEdit {
                        var control = e.geometry.lines[e.lineIndex].controls[e.pointIndex]
                        control.point = e.geometry.lines[e.lineIndex].editPoint(withEditCenterPoint: nearest.point + dp, at: e.pointIndex)
                        setGeometry(Geometry(lines: e.geometry.lines.withReplaced(e.geometry.lines[e.lineIndex].withReplaced(control, at: e.pointIndex).autoPressure(), at: e.lineIndex)), oldGeometry: e.geometry, at: cut.editGroup.editKeyframeIndex, in: e.cellItem, time: time)
                    }
                } else {
                    if moveIsSnap, let b = bezierSortedResult {
                        let snapD = snapPointSnapDistance/drawInfo.scale
                        let np = cut.editGroup.snapPoint(nearest.point + dp, with: b, snapDistance: snapD)
                        if let b = bezierSortedResult {
                            if let e = nearest.drawingEditLineCap, let drawing = b.drawing {
                                var newLines = e.lines
                                if isVertex {
                                    newLines[b.lineCap.lineIndex] = b.lineCap.line.warpedWith(deltaPoint: np - nearest.point, isFirst: b.lineCap.isFirst)
                                } else {
                                    let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                                    var control = b.lineCap.line.controls[pointIndex]
                                    control.point = np
                                    newLines[b.lineCap.lineIndex] = newLines[b.lineCap.lineIndex].withReplaced(control, at: b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1)
                                }
                                setLines(newLines, oldLines: e.lines, drawing: drawing, time: time)
                            } else if let cellItem = b.cellItem, let geometry = b.geometry {
                                for editLineCap in nearest.cellItemEditLineCaps {
                                    if editLineCap.cellItem == cellItem {
                                        if isVertex {
                                            setGeometry(Geometry(lines: geometry.lines.withReplaced(b.lineCap.line.warpedWith(deltaPoint: np - nearest.point, isFirst: b.lineCap.isFirst).autoPressure(), at: b.lineCap.lineIndex)), oldGeometry: geometry, at: cut.editGroup.editKeyframeIndex, in: cellItem, time: time)
                                        } else {
                                            let pointIndex = b.lineCap.isFirst ? 0 : b.lineCap.line.controls.count - 1
                                            var control = geometry.lines[b.lineCap.lineIndex].controls[pointIndex]
                                            control.point = np
                                            setGeometry(Geometry(lines: geometry.lines.withReplaced(b.lineCap.line.withReplaced(control, at: pointIndex).autoPressure(), at: b.lineCap.lineIndex)), oldGeometry: geometry, at: cut.editGroup.editKeyframeIndex, in: cellItem, time: time)
                                        }
                                    } else {
                                        editLineCap.cellItem.cell.geometry = editLineCap.geometry
                                    }
                                }
                            }
                            bezierSortedResult = nil
                        }
                    } else {
                        let np = nearest.point + dp
                        if let e = nearest.drawingEditLineCap {
                            var newLines = e.drawing.lines
                            if isVertex {
                                for cap in e.drawingCaps {
                                    newLines[cap.lineIndex] = cap.line.warpedWith(deltaPoint: dp, isFirst: cap.isFirst)
                                }
                            } else {
                                for cap in e.drawingCaps {
                                    var control = cap.isFirst ? cap.line.controls[0] : cap.line.controls[cap.line.controls.count - 1]
                                    control.point = np
                                    newLines[cap.lineIndex] = newLines[cap.lineIndex].withReplaced(control, at: cap.isFirst ? 0 : cap.line.controls.count - 1)
                                }
                            }
                            setLines(newLines, oldLines: e.lines, drawing: e.drawing, time: time)
                        }
                        for editLineCap in nearest.cellItemEditLineCaps {
                            var newLines = editLineCap.geometry.lines
                            if isVertex {
                                for cap in editLineCap.caps {
                                    newLines[cap.lineIndex] = cap.line.warpedWith(deltaPoint: dp, isFirst: cap.isFirst).autoPressure()
                                }
                            } else {
                                for cap in editLineCap.caps {
                                    var control = cap.isFirst ? cap.line.controls[0] : cap.line.controls[cap.line.controls.count - 1]
                                    control.point = np
                                    newLines[cap.lineIndex] = newLines[cap.lineIndex].withReplaced(control, at: cap.isFirst ? 0 : cap.line.controls.count - 1).autoPressure()
                                }
                            }
                            setGeometry(Geometry(lines: newLines), oldGeometry: editLineCap.geometry, at: cut.editGroup.editKeyframeIndex, in: editLineCap.cellItem, time: time)
                        }
                    }
                }
                moveIsSnap = false
                movePointNearest = nil
                bezierSortedResult = nil
                updateEditView(with: p)
            }
        }
        setNeedsDisplay()
    }
    private func replaceLine(_ line: Line, oldLine: Line, at i: Int, in drawing: Drawing, time: Int) {
        registerUndo { $0.replaceLine(oldLine, oldLine: line, at: i, in: drawing, time: $1) }
        self.time = time
        drawing.lines[i] = line
        isUpdate = true
    }
    
    weak var moveZCell: Cell? {
        didSet {
            setNeedsDisplay()
        }
    }
    func updateMoveZ(with point: CGPoint) {
        moveZCell = cut.rootCell.atPoint(point)
    }
    private var moveZOldPoint = CGPoint(), moveZCellTuple: (indexes: [Int], parent: Cell, oldChildren: [Cell])?, moveZMinDeltaIndex = 0, moveZMaxDeltaIndex = 0, moveZHeight = 2.0.cf
    private weak var moveZOldCell: Cell?
    func moveZ(with event: DragEvent) {
        let p = point(from: event), cp = convertToCut(point(from: event))
        switch event.sendType {
        case .begin:
            let indicationCellsTuple = cut.indicationCellsTuple(with : cp)
            switch indicationCellsTuple.type {
            case .none:
                break
            case .indication:
                let cell = indicationCellsTuple.cells.first!
                cut.rootCell.depthFirstSearch(duplicate: false) { parent, aCell in
                    if cell === aCell, let index = parent.children.index(of: cell) {
                        moveZCellTuple = ([index], parent, parent.children)
                        moveZMinDeltaIndex = -index
                        moveZMaxDeltaIndex = parent.children.count - 1 - index
                    }
                }
            case .selection:
                let firstCell = indicationCellsTuple.cells.first!, cutAllSelectionCells = cut.allEditSelectionCellsWithNoEmptyGeometry
                var firstParent: Cell?
                cut.rootCell.depthFirstSearch(duplicate: false) { parent, cell in
                    if cell === firstCell {
                        firstParent = parent
                    }
                }
                if let firstParent = firstParent {
                    var indexes = [Int]()
                    cut.rootCell.depthFirstSearch(duplicate: false) { parent, cell in
                        if cutAllSelectionCells.contains(cell) && firstParent === parent, let index = parent.children.index(of: cell) {
                            indexes.append(index)
                        }
                    }
                    moveZCellTuple = (indexes, firstParent, firstParent.children)
                    moveZMinDeltaIndex = -(indexes.min() ?? 0)
                    moveZMaxDeltaIndex = firstParent.children.count - 1 - (indexes.max() ?? 0)
                } else {
                    moveZCellTuple = nil
                }
            }
            moveZOldPoint = p
        case .sending:
            if let moveZCellTuple = moveZCellTuple {
                let deltaIndex = Int((p.y - moveZOldPoint.y)/moveZHeight)
                var children = moveZCellTuple.oldChildren
                let indexes = moveZCellTuple.indexes.sorted {
                    deltaIndex < 0 ? $0 < $1 : $0 > $1
                }
                for i in indexes {
                    let cell = children[i]
                    children.remove(at: i)
                    children.insert(cell, at: (i + deltaIndex).clip(min: 0, max: moveZCellTuple.oldChildren.count - 1))
                }
                moveZCellTuple.parent.children = children
            }
        case .end:
            if let moveZCellTuple = moveZCellTuple {
                let deltaIndex = Int((p.y - moveZOldPoint.y)/moveZHeight)
                var children = moveZCellTuple.oldChildren
                let indexes = moveZCellTuple.indexes.sorted {
                    deltaIndex < 0 ? $0 < $1 : $0 > $1
                }
                for i in indexes {
                    let cell = children[i]
                    children.remove(at: i)
                    children.insert(cell, at: (i + deltaIndex).clip(min: 0, max: moveZCellTuple.oldChildren.count - 1))
                }
                setChildren(children, oldChildren: moveZCellTuple.oldChildren, inParent: moveZCellTuple.parent, time: time)
                self.moveZCellTuple = nil
            }
        }
        setNeedsDisplay()
    }
    private func setChildren(_ children: [Cell], oldChildren: [Cell], inParent parent: Cell, time: Int) {
        registerUndo { $0.setChildren(oldChildren, oldChildren: children, inParent: parent, time: $1) }
        self.time = time
        parent.children = children
        isUpdate = true
    }
    
    private var moveDrawingTuple: (drawing: Drawing, lineIndexes: [Int], oldLines: [Line])?, moveCellTuples = [(group: Group, cellItem: CellItem, geometry: Geometry)]()
    private var transformBounds = CGRect()
    private var moveOldPoint = CGPoint(), moveTransformOldPoint = CGPoint()
    enum TransformEditType {
        case move, warp, transform
    }
    func move(with event: DragEvent) {
        move(with: event, type: .move)
    }
    func warp(with event: DragEvent) {
        move(with: event, type: .warp)
    }
    func transform(with event: DragEvent) {
        move(with: event, type: .transform)
    }
    let moveTransformAngleTime = 0.1
    var moveTransformAngleOldTime = 0.0, moveTransformAngleOldPoint = CGPoint(), isMoveTransformAngle = false
    func move(with event: DragEvent,type: TransformEditType) {
        let viewP = point(from: event)
        let p = convertToCut(viewP)
        func affineTransform() -> CGAffineTransform {
            switch type {
            case .move:
                return CGAffineTransform(translationX: p.x - moveOldPoint.x, y: p.y - moveOldPoint.y)
            case .warp:
                if let editTransform = editTransform {
                    return cut.warpAffineTransform(with: editTransform)
                } else {
                    return CGAffineTransform.identity
                }
            case .transform:
                if let editTransform = editTransform {
                    return cut.transformAffineTransform(with: editTransform)
                } else {
                    return CGAffineTransform.identity
                }
            }
        }
        switch event.sendType {
        case .begin:
            moveCellTuples = !cut.isInterpolatedKeyframe(with: cut.editGroup) ? cut.selectionTuples(with: p) : []
            let drawing = cut.editGroup.drawingItem.drawing
            moveDrawingTuple = !moveCellTuples.isEmpty ? (drawing: drawing, lineIndexes: drawing.selectionLineIndexes, oldLines: drawing.lines) : (drawing: drawing, lineIndexes: drawing.editLineIndexes, oldLines: drawing.lines)
            if type != .move {
                self.editTransform = Cut.EditTransform(anchorPoint: transformAnchorPoint, point: p, oldPoint: p)
            }
            moveOldPoint = p
            moveTransformAngleOldTime = event.time
            moveTransformAngleOldPoint = p
            isMoveTransformAngle = false
            moveTransformOldPoint = viewP
        case .sending:
            if type != .move {
                editTransform = editTransform?.withPoint(p)
            }
            if !(moveDrawingTuple?.lineIndexes.isEmpty ?? true) || !moveCellTuples.isEmpty {
                let affine = affineTransform()
                if let mdp = moveDrawingTuple {
                    var newLines = mdp.oldLines
                    for index in mdp.lineIndexes {
                        newLines.remove(at: index)
                        newLines.insert(mdp.oldLines[index].applying(affine), at: index)
                    }
                    mdp.drawing.lines = newLines
                }
                for mcp in moveCellTuples {
                    mcp.cellItem.replaceGeometry(mcp.geometry.applying(affine), at: mcp.group.editKeyframeIndex)
                }
            }
        case .end:
            if !(moveDrawingTuple?.lineIndexes.isEmpty ?? true) || !moveCellTuples.isEmpty {
                let affine = affineTransform()
                if let mdp = moveDrawingTuple {
                    var newLines = mdp.oldLines
                    for index in mdp.lineIndexes {
                        newLines[index] = mdp.oldLines[index].applying(affine)
                    }
                    setLines(newLines, oldLines: mdp.oldLines, drawing: mdp.drawing, time: time)
                }
                for mcp in moveCellTuples {
                    setGeometry(mcp.geometry.applying(affine), oldGeometry: mcp.geometry, at: mcp.group.editKeyframeIndex, in:mcp.cellItem, time: time)
                }
                moveDrawingTuple = nil
                moveCellTuples = []
            }
            editTransform = nil
        }
        setNeedsDisplay()
    }
    
    func scroll(with event: ScrollEvent) {
        let newScrollPoint = CGPoint(x: viewTransform.position.x + event.scrollDeltaPoint.x, y: viewTransform.position.y + event.scrollDeltaPoint.y)
        viewTransform.position = newScrollPoint
    }
    var minScale = 0.00001.cf, blockScale = 1.0.cf, maxScale = 64.0.cf, correctionScale = 1.28.cf, correctionRotation = 1.0.cf/(4.2*(.pi))
    private var isBlockScale = false, oldScale = 0.0.cf
    func zoom(with event: PinchEvent) {
        let scale = viewTransform.scale
        switch event.sendType {
        case .begin:
            oldScale = scale
            isBlockScale = false
        case .sending:
            if !isBlockScale {
                zoom(at: point(from: event)) {
                    let newScale = (scale*pow(event.magnification*correctionScale + 1, 2)).clip(min: minScale, max: maxScale)
                    if blockScale.isOver(old: scale, new: newScale) {
                        isBlockScale = true
                    }
                    viewTransform.scale = newScale
                }
            }
        case .end:
            if isBlockScale {
                zoom(at: point(from: event)) {
                    viewTransform.scale = blockScale
                }
            }
        }
    }
    var blockRotations: [CGFloat] = [-.pi, 0.0, .pi]
    private var isBlockRotation = false, blockRotation = 0.0.cf, oldRotation = 0.0.cf
    func rotate(with event: RotateEvent) {
        let rotation = viewTransform.rotation
        switch event.sendType {
        case .begin:
            oldRotation = rotation
            isBlockRotation = false
        case .sending:
            if !isBlockRotation {
                zoom(at: point(from: event)) {
                    let oldRotation = rotation, newRotation = rotation + event.rotation*correctionRotation
                    for br in blockRotations {
                        if br.isOver(old: oldRotation, new: newRotation) {
                            isBlockRotation = true
                            blockRotation = br
                            break
                        }
                    }
                    viewTransform.rotation = newRotation.clipRotation
                }
            }
        case .end:
            if isBlockRotation {
                zoom(at: point(from: event)) {
                    viewTransform.rotation = blockRotation
                }
            }
        }
    }
    func reset(with event: DoubleTapEvent) {
        if !viewTransform.isIdentity {
            viewTransform = ViewTransform()
        }
    }
    func zoom(at p: CGPoint, handler: () -> ()) {
        let point = convertToCut(p)
        handler()
        let newPoint = convertFromCut(point)
        viewTransform.position = viewTransform.position - (newPoint - p)
    }
    
    func lookUp(with event: TapEvent) -> Referenceable {
        let seletionCells = cut.indicationCellsTuple(with : convertToCut(point(from: event)))
        if let cell = seletionCells.cells.first {
            return cell
        } else {
            return self
        }
    }
}
