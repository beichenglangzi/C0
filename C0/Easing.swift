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

struct Easing: Codable, Hashable {
    var cp0 = Point(), cp1 = Point(x: 1, y: 1)
}
extension Easing {
    func split(with t: Real) -> (b0: Easing, b1: Easing) {
        guard !isDefault else {
            return (Easing(), Easing())
        }
        let sb = bezier.split(withT: t)
        let p = sb.b0.p1
        let b0Affine = AffineTransform(scaleX: 1 / p.x, y: 1 / p.y)
        let b1Affine = AffineTransform(scaleX: 1 / (1 - p.x), y: 1 / (1 - p.y))
            .translated(by: -p)
        let nb0 = Easing(cp0: sb.b0.cp0 * b0Affine, cp1: sb.b0.cp1 * b0Affine)
        let nb1 = Easing(cp0: sb.b1.cp0 * b1Affine, cp1: sb.b1.cp1 * b1Affine)
        return (nb0, nb1)
    }
    func convertT(_ t: Real) -> Real {
        return isLinear ? t : bezier.y(withX: t)
    }
    var bezier: Bezier3 {
        return Bezier3(p0: Point(), cp0: cp0, cp1: cp1, p1: Point(x: 1, y: 1))
    }
    var isDefault: Bool {
        return cp0 == Point() && cp1 == Point(x: 1, y: 1)
    }
    var isLinear: Bool {
        return cp0.x == cp0.y && cp1.x == cp1.y
    }
    func path(in pb: Rect) -> Path {
        let b = bezier
        let cp0 = Point(x: pb.minX + b.cp0.x * pb.width, y: pb.minY + b.cp0.y * pb.height)
        let cp1 = Point(x: pb.minX + b.cp1.x * pb.width, y: pb.minY + b.cp1.y * pb.height)
        var path = Path()
//        path.move(to: Point(x: pb.minX, y: pb.minY))
//        path.addCurve(to: Point(x: pb.maxX, y: pb.maxY), control1: cp0, control2: cp1)
        return path
    }
}
extension Easing {
    static let cp0Option: PointOption = {
        let valueOption = RealOption(defaultModel: 0, minModel: 0, maxModel: 1)
        return PointOption(xOption: valueOption, yOption: valueOption)
    } ()
    static let cp1Option: PointOption = {
        let valueOption = RealOption(defaultModel: 1, minModel: 0, maxModel: 1)
        return PointOption(xOption: valueOption, yOption: valueOption)
    } ()
}
extension Easing: Referenceable {
    static let name = Text(english: "Easing", japanese: "イージング")
}
extension Easing: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        let thumbnailView = View(drawClosure: { self.draw(with: $1.bounds, in: $0) })
        thumbnailView.frame = frame
        return thumbnailView
    }
    func draw(with bounds: Rect, in ctx: CGContext) {
        let path = self.path(in: bounds.inset(by: 5))
        ctx.addPath(path.cg)
        ctx.setStrokeColor(Color.font.cg)
        ctx.setLineWidth(1)
        ctx.strokePath()
    }
}

/**
 Issue: 前後キーフレームからの傾斜スナップ
 */
final class EasingView<T: BinderProtocol>: View, BindableReceiver {
    typealias Model = Easing
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((EasingView<Binder>, BasicNotification) -> ())]()
    
    var defaultModel = Model()
    
    let cp0View: SlidablePointView<Binder>, cp1View: SlidablePointView<Binder>
    
    var sizeType: SizeType {
        didSet { updateLayout() }
    }
    var padding = Layout.basicPadding {
        didSet {
            updateLayout()
        }
    }
    private let classXNameView: TextFormView, classYNameView: TextFormView
    private let controlLinePathView: View = {
        let controlLine = View(path: Path())
        controlLine.lineColor = .content
        controlLine.lineWidth = 1
        return controlLine
    } ()
    private let easingLinePathView: View = {
        let easingLinePathView = View(path: Path())
        easingLinePathView.lineColor = .content
        easingLinePathView.lineWidth = 2
        return easingLinePathView
    } ()
    private let axisPathView: View = {
        let axisPathView = View(path: Path())
        axisPathView.lineColor = .content
        axisPathView.lineWidth = 1
        return axisPathView
    } ()
    
    init(binder: T, keyPath: BinderKeyPath,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        cp0View = SlidablePointView(binder: binder,
                                    keyPath: keyPath.appending(path: \Model.cp0),
                                    option: Easing.cp0Option)
        cp1View = SlidablePointView(binder: binder,
                                    keyPath: keyPath.appending(path: \Model.cp1),
                                    option: Easing.cp1Option)
        
        self.sizeType = sizeType
        classXNameView = TextFormView(text: "t", font: Font.italic(with: sizeType))
        classYNameView = TextFormView(text: "t'", font: Font.italic(with: sizeType))
        
        super.init()
        children = [classXNameView, classYNameView,
                    controlLinePathView, easingLinePathView, axisPathView, cp0View, cp1View]
        self.frame = frame
    }
    
    override func updateLayout() {
        cp0View.frame = Rect(x: padding,
                             y: padding,
                             width: (bounds.width - padding * 2) / 2,
                             height: (bounds.height - padding * 2) / 2)
        cp1View.frame = Rect(x: bounds.width / 2,
                             y: padding + (bounds.height - padding * 2) / 2,
                             width: (bounds.width - padding * 2) / 2,
                             height: (bounds.height - padding * 2) / 2)
        var path = Path()
        let sp = Layout.smallPadding
        let p0 = Point(x: padding + cp0View.padding,
                       y: bounds.height - padding - classYNameView.frame.height - sp)
        let p1 = Point(x: padding + cp0View.padding,
                       y: padding + cp0View.padding)
        let p2 = Point(x: bounds.width - padding - classXNameView.frame.width - sp,
                       y: padding + cp0View.padding)
        path.append(PathLine(points: [p0, p1, p2]))
        axisPathView.path = path
        classXNameView.frame.origin = Point(x: bounds.width - padding - classXNameView.frame.width,
                                            y: padding)
        classYNameView.frame.origin = Point(x: padding,
                                            y: bounds.height - padding - classYNameView.frame.height)
        updateWithModel()
    }
    func updateWithModel() {
        guard !bounds.isEmpty else { return }
        cp0View.updateWithModel()
        cp1View.updateWithModel()
        easingLinePathView.path = model.path(in: bounds.insetBy(dx: padding + cp0View.padding,
                                                                dy: padding + cp0View.padding))
        var knobLinePath = Path()
        knobLinePath.append(PathLine(points: [Point(x: cp0View.frame.minX + cp0View.padding,
                                                    y: cp0View.frame.minY + cp0View.padding),
                                              cp0View.knobView.position + cp0View.frame.origin]))
        knobLinePath.append(PathLine(points: [Point(x: cp1View.frame.maxX - cp1View.padding,
                                                    y: cp1View.frame.maxY - cp1View.padding),
                                              cp1View.knobView.position + cp1View.frame.origin]))
        controlLinePathView.path = knobLinePath
    }
}
extension EasingView: ViewQueryable {
    static var referenceableType: Referenceable.Type {
        return Model.self
    }
    static var viewDescription: Text {
        return Text(english: "Ring: Hue, Width: Saturation, Height: Luminance",
                    japanese: "輪: 色相, 横: 彩度, 縦: 輝度")
    }
}
extension EasingView: Assignable {
    func reset(for p: Point, _ version: Version) {
        push(defaultModel, to: version)
    }
    func copiedObjects(at p: Point) -> [Object] {
        return [Object(model)]
    }
    func paste(_ objects: [Any], for p: Point, _ version: Version) {
        for object in objects {
            if let model = object as? Model {
                push(model, to: version)
                return
            }
        }
    }
}
