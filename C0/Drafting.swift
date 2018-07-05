/*
 Copyright 2018 S
 
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

struct Drafting: Codable, Equatable {
    var drawing = Drawing()
    var draftDrawing = Drawing()
}
extension Drafting {
    func formViewWith(lineWidth: Real, lineColor: Color) -> View {
        return drawing.formViewWith(lineWidth: lineWidth, lineColor: lineColor)
    }
}
extension Drafting: KeyframeValue {
    static func linear(_ f0: Drafting, _ f1: Drafting, t: Real) -> Drafting {
        return Drafting(drawing: Drawing.linear(f0.drawing, f1.drawing, t: t),
                        draftDrawing: Drawing.linear(f0.draftDrawing, f1.draftDrawing, t: t))
    }
    static func firstMonospline(_ f1: Drafting, _ f2: Drafting,
                                _ f3: Drafting, with ms: Monospline) -> Drafting {
        return Drafting(drawing: Drawing.firstMonospline(f1.drawing,
                                                         f2.drawing, f3.drawing, with: ms),
                        draftDrawing: Drawing.firstMonospline(f1.draftDrawing, f2.draftDrawing,
                                                              f3.draftDrawing, with: ms))
    }
    static func monospline(_ f0: Drafting, _ f1: Drafting,
                           _ f2: Drafting, _ f3: Drafting,
                           with ms: Monospline) -> Drafting {
        return Drafting(drawing: Drawing.monospline(f0.drawing, f1.drawing,
                                                    f2.drawing, f3.drawing, with: ms),
                        draftDrawing: Drawing.monospline(f0.draftDrawing, f1.draftDrawing,
                                                         f2.draftDrawing, f3.draftDrawing, with: ms))
    }
    static func lastMonospline(_ f0: Drafting, _ f1: Drafting,
                               _ f2: Drafting, with ms: Monospline) -> Drafting {
        return Drafting(drawing: Drawing.lastMonospline(f0.drawing, f1.drawing,
                                                        f2.drawing, with: ms),
                        draftDrawing: Drawing.lastMonospline(f0.draftDrawing, f1.draftDrawing,
                                                             f2.draftDrawing, with: ms))
    }
}
extension Drafting: Referenceable {
    static let name = Text(english: "Drafting", japanese: "ドラフティング")
}
extension Drafting: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect) -> View {
        let thumbnailView = View()
        thumbnailView.frame = frame
        return thumbnailView
    }
}
extension Drafting: Viewable {
    func standardViewWith<T: BinderProtocol>
        (binder: T, keyPath: ReferenceWritableKeyPath<T, Drafting>) -> ModelView {
        
        return DraftingView(binder: binder, keyPath: keyPath)
    }
}
extension Drafting: ObjectViewable {}

final class DraftingView<T: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = Drafting
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((DraftingView<Binder>, BasicNotification) -> ())]()

    let drawingView: DrawingView<Binder>
    let draftDrawingFormView: View

    let draftColor = Color(red: 0, green: 0.5, blue: 1)
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath

        drawingView = DrawingView(binder: binder, keyPath: keyPath.appending(path: \Model.drawing))
        draftDrawingFormView = View()
        
        super.init(isLocked: false)
        updateDraftDrawing()
        children = [drawingView, draftDrawingFormView]
    }

    var minSize: Size {
        let padding = Layouter.basicPadding, buttonH = Layouter.basicHeight
        return Size(width: 170,
                    height: buttonH * 3 + padding * 2)
    }
    func updateWithModel() {
        drawingView.updateWithModel()
        updateDraftDrawing()
    }
    private func updateDraftDrawing() {
        draftDrawingFormView.children = [model.draftDrawing.formViewWith(lineWidth: 1,
                                                                         lineColor: draftColor)]
    }
}

final class CompactDraftingView<T: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = Drafting
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((CompactDraftingView<Binder>, BasicNotification) -> ())]()
    
    let compactDrawingView: CompactDrawingView<Binder>
    let compactDraftDrawingView: CompactDrawingView<Binder>
    
    init(binder: T, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        compactDrawingView = CompactDrawingView(binder: binder,
                                                keyPath: keyPath.appending(path: \Model.drawing))
        compactDraftDrawingView
            = CompactDrawingView(binder: binder,
                                 keyPath: keyPath.appending(path: \Model.draftDrawing))
        
        super.init(isLocked: false)
        children = [compactDrawingView, compactDraftDrawingView]
        updateWithModel()
    }
    
    var minSize: Size {
        let drawingSize = compactDrawingView.minSize
        let draftDrawingSize = compactDraftDrawingView.minSize
        let padding = Layouter.basicPadding
        return Size(width: max(drawingSize.width, draftDrawingSize.width) + padding * 2,
                    height: drawingSize.height + draftDrawingSize.height + padding * 2)
    }
    override func updateLayout() {
        let padding = Layouter.basicPadding
        let w = bounds.width - padding * 2
        let h = bounds.height - padding * 2
        let dh = (h / 2).rounded()
        compactDrawingView.frame = Rect(x: padding, y: padding + dh, width: w, height: h - dh)
        compactDraftDrawingView.frame = Rect(x: padding, y: padding, width: w, height: dh)
    }
}
