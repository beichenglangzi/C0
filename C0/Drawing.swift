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

import CoreGraphics

struct Drawing: Codable, Equatable {
    static let defaultLineWidth = 1.0.cg
    
    var lines: [Line], draftLines: [Line], selectedLineIndexes: [Int]
    var lineColor: Color, lineWidth: Real
    
    init(lines: [Line] = [], draftLines: [Line] = [], selectedLineIndexes: [Int] = [],
         lineColor: Color = .strokeLine, lineWidth: Real = defaultLineWidth) {
        self.lines = lines
        self.draftLines = draftLines
        self.selectedLineIndexes = selectedLineIndexes
        self.lineColor = lineColor
        self.lineWidth = lineWidth
    }
}
extension Drawing {
    func imageBounds(withLineWidth lineWidth: Real) -> Rect {
        return Line.imageBounds(with: lines, lineWidth: lineWidth)
            .union(Line.imageBounds(with: draftLines, lineWidth: lineWidth))
    }
    var isEmpty: Bool {
        return lines.isEmpty && draftLines.isEmpty
    }
    
    func nearestLine(at p: Point) -> Line? {
        var minD² = Real.infinity, minLine: Line?
        lines.forEach {
            let d² = $0.minDistance²(at: p)
            if d² < minD² {
                minD² = d²
                minLine = $0
            }
        }
        return minLine
    }
    func isNearestSelectedLineIndexes(at p: Point) -> Bool {
        guard !selectedLineIndexes.isEmpty else {
            return false
        }
        var minD² = Real.infinity, minIndex = 0
        lines.enumerated().forEach {
            let d² = $0.element.minDistance²(at: p)
            if d² < minD² {
                minD² = d²
                minIndex = $0.offset
            }
        }
        return selectedLineIndexes.contains(minIndex)
    }
    var selectedLines: [Line] {
        return selectedLineIndexes.map { lines[$0] }
    }
    var editLines: [Line] {
        return selectedLineIndexes.isEmpty ? lines : selectedLineIndexes.map { lines[$0] }
    }
    var uneditLines: [Line] {
        guard  !selectedLineIndexes.isEmpty else {
            return []
        }
        return (0..<lines.count)
            .filter { !selectedLineIndexes.contains($0) }
            .map { lines[$0] }
    }
    
    func intersects(_ otherLines: [Line]) -> Bool {
        for otherLine in otherLines {
            if lines.contains(where: { $0.equalPoints(otherLine) }) {
                return true
            }
        }
        return false
    }
    
    var imageBounds: Rect {
        return imageBounds(withLineWidth: lineWidth)
    }
}
extension Drawing {
    var view: View {
        return viewWith(lineWidth: lineWidth, lineColor: lineColor)
    }
    func viewWith(lineWidth: Real, lineColor: Color) -> View {
        let view = View()
        view.children = lines.compactMap { $0.view(lineWidth: lineWidth, fillColor: lineColor) }
        return view
    }
    func draftViewWith(lineWidth: Real, lineColor: Color) -> View {
        let view = View()
        view.children = draftLines.compactMap { $0.view(lineWidth: lineWidth, fillColor: lineColor) }
        return view
    }
}
extension Drawing: Referenceable {
    static let name = Text(english: "Drawing", japanese: "ドローイング")
}
extension Drawing: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        let thumbnailView = View(drawClosure: { self.draw(with: $1.bounds, in: $0) })
        thumbnailView.frame = frame
        return thumbnailView
    }
    func draw(with bounds: Rect, in ctx: CGContext) {
        let imageBounds = self.imageBounds(withLineWidth: 1)
        let centering = AffineTransform.centering(from: imageBounds, to: bounds.inset(by: 5))
        let view = View()
        view.bounds = bounds
//        ctx.concatenate(centering.affine)
//        draw(lineWidth: 0.5 / centering.scale, lineColor: Color.strokeLine, in: ctx)
//        drawDraft(lineWidth: 0.5 / centering.scale, lineColor: Color.draft, in: ctx)
    }
}
extension Drawing: AbstractViewable {
    func abstractViewWith<T : BinderProtocol>(binder: T,
                                              keyPath: ReferenceWritableKeyPath<T, Drawing>,
                                              frame: Rect, _ sizeType: SizeType,
                                              type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return DrawingView(binder: binder, keyPath: keyPath, frame: frame, sizeType: sizeType)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath, frame: frame, sizeType)
        }
    }
}
extension Drawing: ObjectViewable {}

struct LinesTrack: Track, Codable {
    var animation: Animation<Lines>
    var animatable: Animatable {
        return animation
    }
    
    var cellTreeIndexes: [TreeIndex<Cell>]
}
extension LinesTrack {
    func previousNextViewsWith(isHiddenPrevious: Bool, isHiddenNext: Bool,
                               index: Int, reciprocalScale: Real) -> [View] {
        var views = [View]()
        func viewWith(lineColor: Color, at i: Int) -> View {
            let drawing = animation.keyframes[i].value.drawing
            let lineWidth = drawing.lineWidth * reciprocalScale
            return drawing.viewWith(lineWidth: lineWidth, lineColor: .next)
        }
        if !isHiddenPrevious && index - 1 >= 0 {
            views.append(viewWith(lineColor: .previous, at: index - 1))
        }
        if !isHiddenNext && index + 1 <= animation.keyframes.count - 1 {
            views.append(viewWith(lineColor: .next, at: index + 1))
        }
        return views
    }
}

struct Lines: Codable, Equatable {
    var drawing = Drawing()
    var geometries = [Geometry]()
    
    var defaultLabel: KeyframeTiming.Label {
        return geometries.contains(where: { !$0.isEmpty }) ? .sub : .main
    }
}
extension Lines: KeyframeValue {}
extension Lines: Interpolatable {
    static func linear(_ f0: Lines, _ f1: Lines,
                       t: Real) -> Lines {
        let drawing = f0.drawing
        let geometries = [Geometry].linear(f0.geometries, f1.geometries, t: t)
        return Lines(drawing: drawing, geometries: geometries)
    }
    static func firstMonospline(_ f1: Lines, _ f2: Lines,
                                _ f3: Lines, with ms: Monospline) -> Lines {
        let drawing = f1.drawing
        let geometries = [Geometry].firstMonospline(f1.geometries,
                                                    f2.geometries, f3.geometries, with: ms)
        return Lines(drawing: drawing, geometries: geometries)
    }
    static func monospline(_ f0: Lines, _ f1: Lines,
                           _ f2: Lines, _ f3: Lines,
                           with ms: Monospline) -> Lines {
        let drawing = f1.drawing
        let geometries = [Geometry].monospline(f0.geometries, f1.geometries,
                                               f2.geometries, f3.geometries, with: ms)
        return Lines(drawing: drawing, geometries: geometries)
    }
    static func lastMonospline(_ f0: Lines, _ f1: Lines,
                               _ f2: Lines, with ms: Monospline) -> Lines {
        let drawing = f1.drawing
        let geometries = [Geometry].lastMonospline(f0.geometries,
                                                   f1.geometries, f2.geometries, with: ms)
        return Lines(drawing: drawing, geometries: geometries)
    }
}
extension Lines: Referenceable {
    static let name = Text(english: "Lines Keyframe Value", japanese: "線キーフレーム値")
}
extension Lines: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return drawing.thumbnailView(withFrame: frame, sizeType)
    }
}
extension Lines: AbstractViewable {
    func abstractViewWith<T : BinderProtocol>(binder: T,
                                              keyPath: ReferenceWritableKeyPath<T, Lines>,
                                              frame: Rect, _ sizeType: SizeType,
                                              type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return DrawingView(binder: binder, keyPath: keyPath.appending(path: \Lines.drawing),
                               frame: frame, sizeType: sizeType)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath, frame: frame, sizeType)
        }
    }
}
extension Lines: ObjectViewable {}

/**
 Issue: DraftArray、下書き化などのコマンドを排除
 */
final class DrawingView<T: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = Drawing
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((DrawingView<Binder>, BasicNotification) -> ())]()
    
    var defaultModel = Model()
    
    let linesView: ArrayCountView<Line, Binder>
    let draftLinesView: ArrayCountView<Line, Binder>
    
    var sizeType: SizeType
    let classNameView: TextFormView
    let draftLinesNameView = TextFormView(text: Text(english: "Draft Lines:", japanese: "下書き線:"))
    let changeToDraftView = ClosureView(name: Text(english: "Change to Draft", japanese: "下書き化"))
    let exchangeWithDraftView = ClosureView(name: Text(english: "Exchange with Draft",
                                                       japanese: "下書きと交換"))
    
    init(binder: T, keyPath: BinderKeyPath, frame: Rect = Rect(), sizeType: SizeType = .regular) {
        self.binder = binder
        self.keyPath = keyPath
        
        self.sizeType = sizeType
        classNameView = TextFormView(text: Model.name, font: Font.bold(with: sizeType))
        linesView = ArrayCountView(binder: binder,
                                   keyPath: keyPath.appending(path: \Model.lines),
                                   sizeType: sizeType)
        draftLinesView = ArrayCountView(binder: binder,
                                        keyPath: keyPath.appending(path: \Model.draftLines),
                                        sizeType: sizeType)
        
        super.init()
        changeToDraftView.model = { [unowned self] in self.changeToDraft($0) }
        exchangeWithDraftView.model = { [unowned self] in self.exchangeWithDraft($0) }
        children = [classNameView,
                    linesView,
                    draftLinesNameView, draftLinesView,
                    changeToDraftView, exchangeWithDraftView]
    }
    
    override var defaultBounds: Rect {
        let padding = Layouter.padding(with: sizeType), buttonH = Layouter.height(with: sizeType)
        return Rect(x: 0, y: 0, width: 170,
                      height: buttonH * 4 + padding * 2)
    }
    override func updateLayout() {
        let padding = Layouter.padding(with: sizeType), buttonH = Layouter.height(with: sizeType)
        let px = padding, pw = bounds.width - padding * 2
        var py = bounds.height - padding
        py -= classNameView.frame.height
        classNameView.frame.origin = Point(x: padding, y: py)
        let lsdb = linesView.defaultBounds
        py = bounds.height - padding
        py -= lsdb.height
        linesView.frame = Rect(x: bounds.maxX - lsdb.width - padding, y: py,
                                 width: lsdb.width, height: lsdb.height)
        py -= lsdb.height
        draftLinesView.frame = Rect(x: bounds.maxX - lsdb.width - padding, y: py,
                                      width: lsdb.width, height: lsdb.height)
        let fcdlnvw = draftLinesNameView.frame.width
        draftLinesNameView.frame.origin = Point(x: draftLinesView.frame.minX - fcdlnvw,
                                                           y: py + padding)
        py -= buttonH
        changeToDraftView.frame = Rect(x: px, y: py, width: pw, height: buttonH)
        py -= buttonH
        exchangeWithDraftView.frame = Rect(x: px, y: py, width: pw, height: buttonH)
    }
    func updateWithModel() {
        linesView.updateWithModel()
        draftLinesView.updateWithModel()
    }
}
extension DrawingView {
    func changeToDraft(_ version: Version) {
        capture(model, to: version)
        model.draftLines = model.lines
        model.lines = []
    }
    func exchangeWithDraft(_ version: Version) {
        capture(model, to: version)
        let lines = model.lines
        model.lines = model.draftLines
        model.draftLines = lines
    }
}
