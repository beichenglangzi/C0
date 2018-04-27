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

struct Easing: Codable, Equatable, Hashable, DeepCopiable {
    var cp0 = Point(), cp1 = Point(x: 1, y: 1)
    
    func split(with t: CGFloat) -> (b0: Easing, b1: Easing) {
        guard !isDefault else {
            return (Easing(), Easing())
        }
        let sb = bezier.split(withT: t)
        let p = sb.b0.p1
        let b0Affine = CGAffineTransform(scaleX: 1 / p.x, y: 1 / p.y)
        let b1Affine = CGAffineTransform(scaleX: 1 / (1 - p.x),
                                         y: 1 / (1 - p.y)).translatedBy(x: -p.x, y: -p.y)
        let nb0 = Easing(cp0: sb.b0.cp0.applying(b0Affine), cp1: sb.b0.cp1.applying(b0Affine))
        let nb1 = Easing(cp0: sb.b1.cp0.applying(b1Affine), cp1: sb.b1.cp1.applying(b1Affine))
        return (nb0, nb1)
    }
    func convertT(_ t: CGFloat) -> CGFloat {
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
    func path(in pb: Rect) -> CGPath {
        let b = bezier
        let cp0 = Point(x: pb.minX + b.cp0.x * pb.width, y: pb.minY + b.cp0.y * pb.height)
        let cp1 = Point(x: pb.minX + b.cp1.x * pb.width, y: pb.minY + b.cp1.y * pb.height)
        let path = CGMutablePath()
        path.move(to: Point(x: pb.minX, y: pb.minY))
        path.addCurve(to: Point(x: pb.maxX, y: pb.maxY), control1: cp0, control2: cp1)
        return path
    }
}
extension Easing: Referenceable {
    static let name = Localization(english: "Easing", japanese: "イージング")
}
extension Easing: ObjectViewExpression {
    func thumbnail(withBounds bounds: Rect, _ sizeType: SizeType) -> View {
        let thumbnailView = View(drawClosure: { self.draw(with: $1.bounds, in: $0) })
        thumbnailView.bounds = bounds
        return thumbnailView
    }
    func draw(with bounds: Rect, in ctx: CGContext) {
        let path = self.path(in: bounds.inset(by: 5))
        ctx.addPath(path)
        ctx.setStrokeColor(Color.font.cg)
        ctx.setLineWidth(1)
        ctx.strokePath()
    }
}

/**
 Issue: 前後キーフレームからの傾斜スナップ
 */
final class EasingView: View, Assignable {
    var easing = Easing() {
        didSet {
            if easing != oldValue {
                updateWithEasing()
            }
        }
    }
    
    private let classXNameView: TextView, classYNameView: TextView
    private let controlLinePathView: View = {
        let controlLine = View(path: CGMutablePath())
        controlLine.lineColor = .content
        controlLine.lineWidth = 1
        return controlLine
    } ()
    private let easingLinePathVIew: View = {
        let easingLinePathView = View(path: CGMutablePath())
        easingLinePathView.lineColor = .content
        easingLinePathView.lineWidth = 2
        return easingLinePathView
    } ()
    private let axisPathVIew: View = {
        let axisPathView = View(path: CGMutablePath())
        axisPathView.lineColor = .content
        axisPathView.lineWidth = 1
        return axisPathView
    } ()
    private let cp0View = PointView(), cp1View = PointView()
    var padding = Layout.basicPadding {
        didSet {
            updateLayout()
        }
    }
    
    init(frame: Rect = Rect(), sizeType: SizeType = .regular) {
        classXNameView = TextView(text: Localization("t"), font: Font.italic(with: sizeType))
        classYNameView = TextView(text: Localization("t'"), font: Font.italic(with: sizeType))
        super.init()
        children = [classXNameView, classYNameView,
                    controlLinePathView, easingLinePathVIew, axisPathVIew, cp0View, cp1View]
        self.frame = frame
        
        cp0View.binding = { [unowned self] in self.setEasing(with: $0) }
        cp1View.binding = { [unowned self] in self.setEasing(with: $0) }
    }
    
    override var bounds: Rect {
        didSet {
            updateLayout()
        }
    }
    private func updateLayout() {
        cp0View.frame = Rect(x: padding,
                               y: padding,
                               width: (bounds.width - padding * 2) / 2,
                               height: (bounds.height - padding * 2) / 2)
        cp1View.frame = Rect(x: bounds.width / 2,
                               y: padding + (bounds.height - padding * 2) / 2,
                               width: (bounds.width - padding * 2) / 2,
                               height: (bounds.height - padding * 2) / 2)
        let path = CGMutablePath()
        let sp = Layout.smallPadding
        path.addLines(between: [Point(x: padding + cp0View.padding,
                                        y: bounds.height - padding - classYNameView.frame.height - sp),
                                Point(x: padding + cp0View.padding,
                                        y: padding + cp0View.padding),
                                Point(x: bounds.width - padding - classXNameView.frame.width - sp,
                                        y: padding + cp0View.padding)])
        axisPathVIew.path = path
        classXNameView.frame.origin = Point(x: bounds.width - padding - classXNameView.frame.width,
                                      y: padding)
        classYNameView.frame.origin = Point(x: padding,
                                      y: bounds.height - padding - classYNameView.frame.height)
        updateWithEasing()
    }
    private func updateWithEasing() {
        guard !bounds.isEmpty else {
            return
        }
        cp0View.point = easing.cp0
        cp1View.point = easing.cp1
        easingLinePathVIew.path = easing.path(in: bounds.insetBy(dx: padding + cp0View.padding,
                                                         dy: padding + cp0View.padding))
        let knobLinePath = CGMutablePath()
        knobLinePath.addLines(between: [Point(x: cp0View.frame.minX + cp0View.padding,
                                                y: cp0View.frame.minY + cp0View.padding),
                                        cp0View.formKnobView.position + cp0View.frame.origin])
        knobLinePath.addLines(between: [Point(x: cp1View.frame.maxX - cp1View.padding,
                                                y: cp1View.frame.maxY - cp1View.padding),
                                        cp1View.formKnobView.position + cp1View.frame.origin])
        controlLinePathView.path = knobLinePath
    }
    
    var disabledRegisterUndo = false
    
    struct Binding {
        let view: EasingView, easing: Easing, oldEasing: Easing, phase: Phase
    }
    var binding: ((Binding) -> ())?
    
    private var oldEasing = Easing()
    
    private func setEasing(with obj: PointView.Binding) {
        if obj.phase == .began {
            oldEasing = easing
            binding?(Binding(view: self, easing: oldEasing, oldEasing: oldEasing, phase: .began))
        } else {
            if obj.view == cp0View {
                easing.cp0 = obj.point
            } else {
                easing.cp1 = obj.point
            }
            binding?(Binding(view: self, easing: easing, oldEasing: oldEasing, phase: obj.phase))
        }
    }
    
    func delete(for p: Point) {
        let easing = Easing()
        guard easing != self.easing else {
            return
        }
        set(easing, old: self.easing)
    }
    func copiedViewables(at p: Point) -> [Viewable] {
        return [easing]
    }
    func paste(_ objects: [Any], for p: Point) {
        for object in objects {
            if let easing = object as? Easing {
                if easing != self.easing {
                    set(easing, old: self.easing)
                    return
                }
            }
        }
    }
    
    private func set(_ easing: Easing, old oldEasing: Easing) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldEasing, old: easing) }
        binding?(Binding(view: self, easing: oldEasing, oldEasing: oldEasing, phase: .began))
        self.easing = easing
        binding?(Binding(view: self, easing: easing, oldEasing: oldEasing, phase: .ended))
    }
    
    func reference(at p: Point) -> Reference {
        var reference = Easing.reference
        reference.viewDescription = Localization(english: "Horizontal axis t: Time\nVertical axis t': Correction time",
                                                 japanese: "横軸t: 時間\n縦軸t': 補正後の時間")
        return reference
    }
}
