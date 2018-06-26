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

struct Drafting<Value: Object.Value & Equatable & Initializable>: Codable, Equatable {
    var value = Value()
    var draftValue: Value? = nil
}
extension Drafting {
    func viewWith(lineWidth: Real, lineColor: Color) -> View {
        let view = View()
//        view.children = lines.compactMap { $0.view(lineWidth: lineWidth, fillColor: lineColor) }
        return view
    }
    func draftViewWith(lineWidth: Real, lineColor: Color) -> View {
        let view = View()
//        view.children = draftLines.compactMap { $0.view(lineWidth: lineWidth, fillColor: lineColor) }
        return view
    }
}
extension Drafting: Referenceable {
    static var name: Text {
        return Text(english: "Drafting", japanese: "ドラフティング") + "<" + Value.name + ">"
    }
}
extension Drafting: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect) -> View {
        let thumbnailView = View()
        thumbnailView.frame = frame
        return thumbnailView
    }
}
extension Drafting: AbstractViewable {
    func abstractViewWith<T : BinderProtocol>(binder: T,
                                              keyPath: ReferenceWritableKeyPath<T, Drafting>,
                                              type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return DraftingView(binder: binder, keyPath: keyPath)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath)
        }
    }
}
extension Drafting: ObjectViewable {}

struct DraftingOption {
    let draftColor = Color(red: 0, green: 0.5, blue: 1)
}

final class DraftingView<Value: Object.Value & Equatable & Initializable, U: BinderProtocol>
: ModelView, BindableReceiver {
    typealias Model = Drafting<Value>
    typealias Binder = U
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((DraftingView<Value, Binder>, BasicNotification) -> ())]()

    var defaultModel = Model()

//    let linesView: ArrayCountView<Line, Binder>
//    let draftLinesView: ArrayCountView<Line, Binder>
//
//    let classNameView: TextFormView
//    let draftLinesNameView = TextFormView(text: Text(english: "Draft Lines",
//                                                     japanese: "下書き線") + ":")
//    let changeToDraftView = ClosureView(name: Text(english: "Change to Draft", japanese: "下書き化"))

    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
//
//        classNameView = TextFormView(text: Model.name, font: .bold)
//        linesView = ArrayCountView(binder: binder,
//                                   keyPath: keyPath.appending(path: \Model.lineValue))
//        draftLinesView = ArrayCountView(binder: binder,
//                                        keyPath: keyPath.appending(path: \Model.draftValue))
//
        super.init(isLocked: false)
//        changeToDraftView.model = { [unowned self] in self.changeToDraft($0) }
//
//        children = [classNameView,
//                    linesView,
//                    draftLinesNameView, draftLinesView,
//                    changeToDraftView]
    }
//
    var minSize: Size {
        let padding = Layouter.basicPadding, buttonH = Layouter.basicHeight
        return Size(width: 170,
                    height: buttonH * 3 + padding * 2)
    }
//    override func updateLayout() {
//        let padding = Layouter.basicPadding
//        let classNameSize = classNameView.minSize
//        let classNameOrigin = Point(x: padding,
//                                    y: bounds.height - classNameSize.height - padding * 2)
//        classNameView.frame = Rect(origin: classNameOrigin, size: classNameSize)
//
//        let buttonH = Layouter.basicHeight
//        let px = padding, pw = bounds.width - padding * 2
//        var py = bounds.height - padding
//        py -= classNameView.frame.height
//        let lsms = linesView.minSize
//        py = bounds.height - padding
//        py -= lsms.height
//        linesView.frame = Rect(x: bounds.maxX - lsms.width - padding, y: py,
//                               width: lsms.width, height: lsms.height)
//        py -= lsms.height
//        draftLinesView.frame = Rect(x: bounds.maxX - lsms.width - padding, y: py,
//                                    width: lsms.width, height: lsms.height)
//        let dlnms = draftLinesNameView.minSize
//        draftLinesNameView.frame = Rect(origin: Point(x: draftLinesView.frame.minX - dlnms.width,
//                                                      y: py + padding),
//                                        size: dlnms)
//        py -= buttonH
//        changeToDraftView.frame = Rect(x: px, y: py, width: pw, height: buttonH)
//    }
    func updateWithModel() {
//        linesView.updateWithModel()
//        draftLinesView.updateWithModel()
    }
}
//extension DraftingView {
//    func changeToDraft(_ version: Version) {
//        capture(model, to: version)
//        model.draftValue = model.value
//        model.value = nil
//    }
//}
