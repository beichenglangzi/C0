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
    
    //view
    func drawEdit(withReciprocalScale reciprocalScale: Real, in ctx: CGContext) {
        drawEdit(lineWidth: lineWidth * reciprocalScale, lineColor: lineColor, in: ctx)
    }
    func draw(withReciprocalScale reciprocalScale: Real, in ctx: CGContext) {
        draw(lineWidth: lineWidth * reciprocalScale, lineColor: lineColor, in: ctx)
    }
    func drawEdit(lineWidth: Real, lineColor: Color, in ctx: CGContext) {
        drawDraft(lineWidth: lineWidth, lineColor: Color.draft, in: ctx)
        draw(lineWidth: lineWidth, lineColor: lineColor, in: ctx)
        drawSelectedLines(lineWidth: lineWidth + 1.5, lineColor: Color.selected, in: ctx)
    }
    func drawDraft(lineWidth: Real, lineColor: Color, in ctx: CGContext) {
        ctx.setFillColor(lineColor.cg)
        draftLines.forEach { $0.draw(size: lineWidth, in: ctx) }
    }
    func draw(lineColor: Color, in ctx: CGContext) {
        ctx.setFillColor(lineColor.cg)
        lines.forEach { $0.draw(size: lineWidth, in: ctx) }
    }
    func draw(lineWidth: Real, lineColor: Color, in ctx: CGContext) {
        ctx.setFillColor(lineColor.cg)
        lines.forEach { $0.draw(size: lineWidth, in: ctx) }
    }
    func drawSelectedLines(lineWidth: Real, lineColor: Color, in ctx: CGContext) {
        ctx.setFillColor(lineColor.cg)
        selectedLineIndexes.forEach { lines[$0].draw(size: lineWidth, in: ctx) }
    }
}
extension Drawing: Referenceable {
    static let name = Text(english: "Drawing", japanese: "ドローイング")
}
extension Drawing: MiniViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        let thumbnailView = View(drawClosure: { self.draw(with: $1.bounds, in: $0) })
        thumbnailView.bounds = bounds
        return thumbnailView
    }
    func draw(with bounds: Rect, in ctx: CGContext) {
        let imageBounds = self.imageBounds(withLineWidth: 1)
        let c = CGAffineTransform.centering(from: imageBounds, to: bounds.inset(by: 5))
        ctx.concatenate(c.affine)
        draw(lineWidth: 0.5 / c.scale, lineColor: Color.strokeLine, in: ctx)
        drawDraft(lineWidth: 0.5 / c.scale, lineColor: Color.draft, in: ctx)
    }
}

/**
 Issue: DraftArray、下書き化などのコマンドを排除
 */
final class DrawingView: View {
    var drawing = Drawing() {
        didSet {
            updateWithDrawing()
        }
    }
    
    let linesView = ArrayCountView<Line>()
    let draftLinesView = ArrayCountView<Line>()
    
    var sizeType: SizeType
    let classNameView: TextFormView
    let classDraftLinesNameView = TextView(text: Text(english: "Draft Lines:", japanese: "下書き線:"))
    let changeToDraftView = ClosureView(name: Text(english: "Change to Draft", japanese: "下書き化"))
    let exchangeWithDraftView = ClosureView(name: Text(english: "Exchange with Draft",
                                                       japanese: "下書きと交換"))
    
    init(drawing: Drawing = Drawing(), sizeType: SizeType = .regular) {
        self.sizeType = sizeType
        classNameView = TextView(text: Drawing.name, font: Font.bold(with: sizeType))
        
        super.init()
        changeToDraftView.closure = { [unowned self] in self.changeToDraft() }
        exchangeWithDraftView.closure = { [unowned self] in self.exchangeWithDraft() }
        children = [classNameView,
                    linesView,
                    classDraftLinesNameView, draftLinesView,
                    changeToDraftView, exchangeWithDraftView]
    }
    
    override var defaultBounds: Rect {
        let padding = Layout.padding(with: sizeType), buttonH = Layout.height(with: sizeType)
        return Rect(x: 0, y: 0, width: 100,
                      height: buttonH * 4 + padding * 2)
    }
    override func updateLayout() {
        let padding = Layout.padding(with: sizeType), buttonH = Layout.height(with: sizeType)
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
        let fcdlnvw = classDraftLinesNameView.frame.width
        classDraftLinesNameView.frame.origin = Point(x: draftLinesView.frame.minX - fcdlnvw,
                                                           y: py + padding)
        py -= buttonH
        changeToDraftView.frame = Rect(x: px, y: py, width: pw, height: buttonH)
        py -= buttonH
        exchangeWithDraftView.frame = Rect(x: px, y: py, width: pw, height: buttonH)
    }
    private func updateWithDrawing() {
        linesView.array = drawing.lines
        draftLinesView.array = drawing.draftLines
    }
    
    struct Binding {
        let view: DrawingView
        let drawing: Drawing, oldDrawing: Drawing, phase: Phase
    }
    var binding: ((Binding) -> ())?
    
    func changeToDraft() {
        //register() { $0.drawing = drawing }
        drawing.draftLines = drawing.lines
        drawing.lines = []
    }
    func exchangeWithDraft() {
        //r
        let lines = drawing.lines
        drawing.lines = drawing.draftLines
        drawing.draftLines = lines
    }
    
    private func push(_ drawing: Drawing) {
//        registeringUndoManager?.registerUndo(withTarget: self) {
//            $0.set(oldDrawing, old: drawing)
//        }
        self.drawing = drawing
    }
}
extension DrawingView: Queryable {
    static let referenceableType: Referenceable.Type = Drawing.self
}
extension DrawingView: Assignable {
    func delete(for p: Point) {
        push(Drawing())
    }
    func copiedObjects(at p: Point) -> [Viewable] {
        return [drawing.copied]
    }
    func paste(_ objects: [Object], for p: Point) {
        for object in objects {
            if let drawing = object as? Drawing {
                push(drawing.copied)
                return
            }
        }
    }
}
