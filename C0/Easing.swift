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

struct Easing: Codable, Equatable, Hashable, Copiable {
    var cp0 = CGPoint(), cp1 = CGPoint(x: 1, y: 1)
    
    func with(cp0: CGPoint) -> Easing {
        return Easing(cp0: cp0, cp1: cp1)
    }
    func with(cp1: CGPoint) -> Easing {
        return Easing(cp0: cp0, cp1: cp1)
    }
    
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
        return Bezier3(p0: CGPoint(), cp0: cp0, cp1: cp1, p1: CGPoint(x: 1, y: 1))
    }
    var isDefault: Bool {
        return cp0 == CGPoint() && cp1 == CGPoint(x: 1, y: 1)
    }
    var isLinear: Bool {
        return cp0.x == cp0.y && cp1.x == cp1.y
    }
    func path(in pb: CGRect) -> CGPath {
        let b = bezier
        let cp0 = CGPoint(x: pb.minX + b.cp0.x * pb.width, y: pb.minY + b.cp0.y * pb.height)
        let cp1 = CGPoint(x: pb.minX + b.cp1.x * pb.width, y: pb.minY + b.cp1.y * pb.height)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: pb.minX, y: pb.minY))
        path.addCurve(to: CGPoint(x: pb.maxX, y: pb.maxY), control1: cp0, control2: cp1)
        return path
    }
}
extension Easing: Referenceable {
    static let name = Localization(english: "Easing", japanese: "イージング")
}
extension Easing: ObjectViewExpression {
    func thumbnail(withBounds bounds: CGRect, sizeType: SizeType) -> Layer {
        let thumbnailView = DrawBox()
        thumbnailView.drawBlock = { [unowned thumbnailView] ctx in
            self.draw(with: thumbnailView.bounds, in: ctx)
        }
        thumbnailView.bounds = bounds
        return thumbnailView
    }
    func draw(with bounds: CGRect, in ctx: CGContext) {
        let path = self.path(in: bounds.inset(by: 5))
        ctx.addPath(path)
        ctx.setStrokeColor(Color.font.cgColor)
        ctx.setLineWidth(1)
        ctx.strokePath()
    }
}

final class EasingView: View {
    var easing = Easing() {
        didSet {
            if easing != oldValue {
                updateWithEasing()
            }
        }
    }
    
    private let xLabel: Label, yLabel: Label
    private let controlLine: PathLayer = {
        let controlLine = PathLayer()
        controlLine.lineColor = .content
        controlLine.lineWidth = 1
        return controlLine
    } ()
    private let easingLine: PathLayer = {
        let easingLine = PathLayer()
        easingLine.lineColor = .content
        easingLine.lineWidth = 2
        return easingLine
    } ()
    private let axis: PathLayer = {
        let axis = PathLayer()
        axis.lineColor = .content
        axis.lineWidth = 1
        return axis
    } ()
    private let cp0View = PointView(), cp1View = PointView()
    var padding = Layout.basicPadding {
        didSet {
            updateLayout()
        }
    }
    
    init(frame: CGRect = CGRect(), sizeType: SizeType = .regular) {
        xLabel = Label(text: Localization("t"), font: Font.italic(with: sizeType))
        yLabel = Label(text: Localization("t'"), font: Font.italic(with: sizeType))
        super.init()
        replace(children: [xLabel, yLabel, controlLine, easingLine, axis, cp0View, cp1View])
        self.frame = frame
        
        cp0View.binding = { [unowned self] in self.setEasing(with: $0) }
        cp1View.binding = { [unowned self] in self.setEasing(with: $0) }
    }
    
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    private func updateLayout() {
        cp0View.frame = CGRect(x: padding,
                               y: padding,
                               width: (bounds.width - padding * 2) / 2,
                               height: (bounds.height - padding * 2) / 2)
        cp1View.frame = CGRect(x: bounds.width / 2,
                               y: padding + (bounds.height - padding * 2) / 2,
                               width: (bounds.width - padding * 2) / 2,
                               height: (bounds.height - padding * 2) / 2)
        let path = CGMutablePath()
        let sp = Layout.smallPadding
        path.addLines(between: [CGPoint(x: padding + cp0View.padding,
                                        y: bounds.height - padding - yLabel.frame.height - sp),
                                CGPoint(x: padding + cp0View.padding,
                                        y: padding + cp0View.padding),
                                CGPoint(x: bounds.width - padding - xLabel.frame.width - sp,
                                        y: padding + cp0View.padding)])
        axis.path = path
        xLabel.frame.origin = CGPoint(x: bounds.width - padding - xLabel.frame.width,
                                      y: padding)
        yLabel.frame.origin = CGPoint(x: padding,
                                      y: bounds.height - padding - yLabel.frame.height)
        updateWithEasing()
    }
    private func updateWithEasing() {
        guard !bounds.isEmpty else {
            return
        }
        cp0View.point = easing.cp0
        cp1View.point = easing.cp1
        easingLine.path = easing.path(in: bounds.insetBy(dx: padding + cp0View.padding,
                                                         dy: padding + cp0View.padding))
        let knobLinePath = CGMutablePath()
        knobLinePath.addLines(between: [CGPoint(x: cp0View.frame.minX + cp0View.padding,
                                                y: cp0View.frame.minY + cp0View.padding),
                                        cp0View.knob.position + cp0View.frame.origin])
        knobLinePath.addLines(between: [CGPoint(x: cp1View.frame.maxX - cp1View.padding,
                                                y: cp1View.frame.maxY - cp1View.padding),
                                        cp1View.knob.position + cp1View.frame.origin])
        controlLine.path = knobLinePath
    }
    
    var disabledRegisterUndo = false
    
    struct Binding {
        let view: EasingView, easing: Easing, oldEasing: Easing, type: Action.SendType
    }
    var binding: ((Binding) -> ())?
    
    private var oldEasing = Easing()
    
    private func setEasing(with obj: PointView.Binding) {
        if obj.type == .begin {
            oldEasing = easing
            binding?(Binding(view: self, easing: oldEasing, oldEasing: oldEasing, type: .begin))
        } else {
            easing = obj.view == cp0View ? easing.with(cp0: obj.point) : easing.with(cp1: obj.point)
            binding?(Binding(view: self, easing: easing, oldEasing: oldEasing, type: obj.type))
        }
    }
    
    func delete(with event: KeyInputEvent) -> Bool {
        let easing = Easing()
        guard easing != self.easing else {
            return false
        }
        set(easing, old: self.easing)
        return true
    }
    func copiedObjects(with event: KeyInputEvent) -> [ViewExpression]? {
        return [easing]
    }
    func paste(_ objects: [Any], with event: KeyInputEvent) -> Bool {
        for object in objects {
            if let easing = object as? Easing {
                if easing != self.easing {
                    set(easing, old: self.easing)
                    return true
                }
            }
        }
        return false
    }
    
    private func set(_ easing: Easing, old oldEasing: Easing) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldEasing, old: easing) }
        binding?(Binding(view: self, easing: oldEasing, oldEasing: oldEasing, type: .begin))
        self.easing = easing
        binding?(Binding(view: self, easing: easing, oldEasing: oldEasing, type: .end))
    }
    
    func reference(with event: TapEvent) -> Reference? {
        var reference = easing.reference
        reference.viewDescription = Localization(english: "Horizontal axis: Time\nVertical axis: Correction time",
                                                 japanese: "横軸: 時間\n縦軸: 補正後の時間")
        reference.comment = Localization("Issue: 前後キーフレームからの傾斜スナップ")
        return reference
    }
}
