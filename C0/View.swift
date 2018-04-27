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
import QuartzCore

final class Screen {
    static let shared = Screen()
    var backingScaleFactor = 1.0.cg
}

struct Gradient {
    var colors = [Color]()
    var locations = [CGFloat]()
    var startPoint = Point(), endPoint = Point(x: 1, y: 0)
}

/**
 Issue: QuartzCoreを廃止し、MetalでGPUレンダリング
 Issue: リニアワークフロー、マクロ拡散光
 Issue: GradientLayer, PathLayerなどをLayerに統合
 */
class View: Undoable, Queryable {
    static var selection: View {
        let view = View(isForm: true)
        view.fillColor = .select
        view.lineColor = .selectBorder
        return view
    }
    static var deselection: View {
        let view = View(isForm: true)
        view.fillColor = .deselect
        view.lineColor = .deselectBorder
        return view
    }
    
    fileprivate var caLayer: CALayer
    init() {
        caLayer = CALayer.interface()
    }
    init(isForm: Bool) {
        self.isForm = isForm
        caLayer = CALayer.interface()
    }
    
    init(gradient: Gradient, isForm: Bool = true) {
        self.isForm = isForm
        var actions = CALayer.disabledAnimationActions
        actions["colors"] = NSNull()
        actions["locations"] = NSNull()
        actions["startPoint"] = NSNull()
        actions["endPoint"] = NSNull()
        let caGradientLayer = CAGradientLayer()
        caGradientLayer.actions = actions
        caLayer = caGradientLayer
        self.gradient = gradient
        View.update(with: gradient, in: caGradientLayer)
    }
    var gradient: Gradient? {
        didSet {
            guard let gradient = gradient, let caGradientLayer = caLayer as? CAGradientLayer else {
                fatalError()
            }
            View.update(with: gradient, in: caGradientLayer)
        }
    }
    private static func update(with gradient: Gradient, in caGradientLayer: CAGradientLayer) {
        caGradientLayer.colors = gradient.colors.isEmpty ? nil : gradient.colors.map { $0.cg }
        caGradientLayer.locations = gradient.locations.isEmpty ?
            nil : gradient.locations.map { NSNumber(value: Double($0)) }
        caGradientLayer.startPoint = gradient.startPoint
        caGradientLayer.endPoint = gradient.endPoint
    }
    
    init(path: CGPath, isForm: Bool = true) {
        self.isForm = isForm
        let caShapeLayer = CAShapeLayer()
        var actions = CALayer.disabledAnimationActions
        actions["fillColor"] = NSNull()
        actions["strokeColor"] = NSNull()
        caShapeLayer.actions = actions
        caShapeLayer.fillColor = nil
        caShapeLayer.lineWidth = 0
        caShapeLayer.strokeColor = lineColor?.cg
        caShapeLayer.path = path
        caLayer = caShapeLayer
    }
    var path: CGPath? {
        get {
            guard let caShapeLayer = caLayer as? CAShapeLayer else {
                return nil
            }
            return caShapeLayer.path
        }
        set {
            guard let caShapeLayer = caLayer as? CAShapeLayer else {
                fatalError()
            }
            caShapeLayer.path = newValue
            changed(frame)
        }
    }
    
    init(drawClosure: ((CGContext, View) -> ())?,
         fillColor: Color? = .background, lineColor: Color? = .getSetBorder, isForm: Bool = true) {
        
        self.isForm = isForm
        let caDrawLayer = C0DrawLayer()
        caLayer = caDrawLayer
        self.fillColor = fillColor
        self.lineColor = lineColor
        self.drawClosure = drawClosure
        caDrawLayer.backgroundColor = fillColor?.cg
        caDrawLayer.borderColor = lineColor?.cg
        caDrawLayer.borderWidth = lineColor == nil ? 0 : lineWidth
        caDrawLayer.drawClosure = { [unowned self] ctx in self.drawClosure?(ctx, self) }
    }
    var drawClosure: ((CGContext, View) -> ())? {
        didSet {
            (caLayer as! C0DrawLayer).drawClosure = { [unowned self] ctx in
                self.drawClosure?(ctx, self)
            }
        }
    }
    func draw() {
        caLayer.setNeedsDisplay()
    }
    func draw(_ rect: Rect) {
        caLayer.setNeedsDisplay(rect)
    }
    func draw(in ctx: CGContext) {
        caLayer.draw(in: ctx)
    }
    func render(in ctx: CGContext) {
        (caLayer as! C0DrawLayer).safetyRender(in: ctx)
    }
    
    private(set) weak var parent: View?
    private var _children = [View]()
    var children: [View] {
        get {
            return _children
        }
        set {
            let oldChildren = _children
            oldChildren.forEach { child in
                if !newValue.contains(where: { $0 === child }) {
                    child.removeFromParent()
                }
            }
            caLayer.sublayers = newValue.compactMap { $0.caLayer }
            _children = newValue
            newValue.forEach { child in
                child.parent = self
                child.allChildrenAndSelf { $0.contentsScale = contentsScale }
            }
        }
    }
    func append(child: View) {
        child.removeFromParent()
        caLayer.addSublayer(child.caLayer)
        _children.append(child)
        child.parent = self
        child.allChildrenAndSelf { $0.contentsScale = contentsScale }
    }
    func insert(child: View, at index: Int) {
        child.removeFromParent()
        caLayer.insertSublayer(child.caLayer, at: UInt32(index))
        _children.insert(child, at: index)
        child.parent = self
        child.allChildrenAndSelf { $0.contentsScale = contentsScale }
    }
    func removeFromParent() {
        guard let parent = parent else {
            return
        }
        caLayer.removeFromSuperlayer()
        if let index = parent._children.index(where: { $0 === self }) {
            parent._children.remove(at: index)
        }
        self.parent = nil
    }
    
    func allChildrenAndSelf(_ closure: (View) -> Void) {
        func allChildrenRecursion(_ child: View, _ closure: (View) -> Void) {
            child._children.forEach { allChildrenRecursion($0, closure) }
            closure(child)
        }
        allChildrenRecursion(self, closure)
    }
    func selfAndAllParents(closure: (View, inout Bool) -> Void) {
        var stop = false
        closure(self, &stop)
        if stop {
            return
        }
        parent?.selfAndAllParents(closure: closure)
    }
    var root: View {
        return parent?.root ?? self
    }
    
    var defaultBounds: Rect {
        return Rect()
    }
    private var isUseDidSetBounds = true, isUseDidSetFrame = true
    var bounds = Rect() {
        didSet {
            guard isUseDidSetBounds && bounds != oldValue else {
                return
            }
            if frame.size != bounds.size {
                isUseDidSetFrame = false
                frame.size = bounds.size
                isUseDidSetFrame = true
            }
            caLayer.bounds = bounds
        }
    }
    var frame = Rect() {
        didSet {
            guard isUseDidSetFrame && frame != oldValue else {
                return
            }
            if bounds.size != frame.size {
                isUseDidSetBounds = false
                bounds.size = frame.size
                isUseDidSetBounds = true
            }
            caLayer.frame = frame
            changed(frame)
        }
    }
    var position: Point {
        get {
            return caLayer.position
        }
        set {
            caLayer.position = newValue
        }
    }
    
    var changedFrame: ((Rect) -> ())?
    func changed(_ frame: Rect) {
        guard !isForm else {
            return
        }
        changedFrame?(frame)
        if let parent = parent {
            parent.changed(convert(frame, to: parent))
        }
    }
    
    var isHidden: Bool {
        get {
            return caLayer.isHidden
        }
        set {
            caLayer.isHidden = newValue
            changed(frame)
        }
    }
    var opacity: CGFloat {
        get {
            return CGFloat(caLayer.opacity)
        }
        set {
            caLayer.opacity = Float(newValue)
        }
    }
    
    var cornerRadius: CGFloat {
        get {
            return caLayer.cornerRadius
        }
        set {
            caLayer.cornerRadius = newValue
        }
    }
    var isClipped: Bool {
        get {
            return caLayer.masksToBounds
        }
        set {
            caLayer.masksToBounds = newValue
        }
    }
    
    var image: CGImage? {
        get {
            guard let contents = caLayer.contents else {
                return nil
            }
            return (contents as! CGImage)
        }
        set {
            caLayer.contents = newValue
            if newValue != nil {
                caLayer.minificationFilter = kCAFilterTrilinear
                caLayer.magnificationFilter = kCAFilterTrilinear
            } else {
                caLayer.minificationFilter = kCAFilterLinear
                caLayer.magnificationFilter = kCAFilterLinear
            }
        }
    }
    var fillColor: Color? {
        didSet {
            guard fillColor != oldValue else {
                return
            }
            set(fillColor: fillColor?.cg)
        }
    }
    fileprivate func set(fillColor: CGColor?) {
        if let caShapeLayer = caLayer as? CAShapeLayer {
            caShapeLayer.fillColor = fillColor
        } else {
            caLayer.backgroundColor = fillColor
        }
    }
    var contentsScale: CGFloat {
        get {
            return caLayer.contentsScale
        }
        set {
            guard newValue != caLayer.contentsScale else {
                return
            }
            caLayer.contentsScale = newValue
        }
    }
    
    var lineColor: Color? = .getSetBorder {
        didSet {
            guard lineColor != oldValue else {
                return
            }
            set(lineWidth: lineColor != nil ? lineWidth : 0)
            set(lineColor: lineColor?.cg)
        }
    }
    var lineWidth = 0.5.cg {
        didSet {
            set(lineWidth: lineColor != nil ? lineWidth : 0)
        }
    }
    fileprivate func set(lineColor: CGColor?) {
        if let caShapeLayer = caLayer as? CAShapeLayer {
            caShapeLayer.strokeColor = lineColor
        } else {
            caLayer.borderColor = lineColor
        }
    }
    fileprivate func set(lineWidth: CGFloat) {
        if let caShapeLayer = caLayer as? CAShapeLayer {
            caShapeLayer.lineWidth = lineWidth
        } else {
            caLayer.borderWidth = lineWidth
        }
    }
    
    func containsPath(_ p: Point) -> Bool {
        if let path = path {
            return path.contains(p)
        } else {
            return bounds.contains(p)
        }
    }
    func contains(_ p: Point) -> Bool {
        return !isForm && !isHidden && containsPath(p)
    }
    func at(_ p: Point) -> View? {
        guard !(isForm && _children.isEmpty) else {
            return nil
        }
        guard containsPath(p) && !isHidden else {
            return nil
        }
        for child in _children.reversed() {
            let inPoint = child.convert(p, from: self)
            if let view = child.at(inPoint) {
                return view
            }
        }
        return isForm ? nil : self
    }
    
    func convertFromRoot(_ point: Point) -> Point {
        return point - convertToRoot(Point(), stop: nil).point
    }
    func convert(_ point: Point, from view: View) -> Point {
        guard self !== view else {
            return point
        }
        let result = view.convertToRoot(point, stop: self)
        return !result.isRoot ?
            result.point : result.point - convertToRoot(Point(), stop: nil).point
    }
    func convertToRoot(_ point: Point) -> Point {
        return convertToRoot(point, stop: nil).point
    }
    func convert(_ point: Point, to view: View) -> Point {
        guard self !== view else {
            return point
        }
        let result = convertToRoot(point, stop: view)
        return !result.isRoot ?
            result.point : result.point - view.convertToRoot(Point(), stop: nil).point
    }
    private func convertToRoot(_ point: Point,
                               stop view: View?) -> (point: Point, isRoot: Bool) {
        if let parent = parent {
            let parentPoint = point - bounds.origin + frame.origin
            return parent === view ?
                (parentPoint, false) : parent.convertToRoot(parentPoint, stop: view)
        } else {
            return (point, true)
        }
    }
    
    func convertFromRoot(_ rect: Rect) -> Rect {
        return Rect(origin: convertFromRoot(rect.origin), size: rect.size)
    }
    func convert(_ rect: Rect, from view: View) -> Rect {
        return Rect(origin: convert(rect.origin, from: view), size: rect.size)
    }
    func convertToRoot(_ rect: Rect) -> Rect {
        return Rect(origin: convertToRoot(rect.origin), size: rect.size)
    }
    func convert(_ rect: Rect, to view: View) -> Rect {
        return Rect(origin: convert(rect.origin, to: view), size: rect.size)
    }
    
    var isIndicated = false {
        didSet {
            updateLineColorWithIsIndicated()
        }
    }
    var noIndicatedLineColor: Color? = .getSetBorder {
        didSet {
            updateLineColorWithIsIndicated()
        }
    }
    var indicatedLineColor: Color? = .indicated {
        didSet {
            updateLineColorWithIsIndicated()
        }
    }
    private func updateLineColorWithIsIndicated() {
        lineColor = isIndicated ? indicatedLineColor : noIndicatedLineColor
    }
    
    var isSubIndicated = false
    weak var subIndicatedParent: View?
    func allSubIndicatedParentsAndSelf(closure: (View) -> Void) {
        closure(self)
        (subIndicatedParent ?? parent)?.allSubIndicatedParentsAndSelf(closure: closure)
    }
    
    var isForm = false, isLiteral = false
    
    var undoManager: UndoManager? {
        return subIndicatedParent?.undoManager ?? parent?.undoManager
    }
    
    var topCopiedViewables: [Viewable] {
        if let subIndicatedParent = subIndicatedParent {
            return subIndicatedParent.topCopiedViewables
        } else {
            return parent?.topCopiedViewables ?? []
        }
    }
    func sendToTop(copiedViewables: [Viewable]) {
        if let subIndicatedParent = subIndicatedParent {
            subIndicatedParent.sendToTop(copiedViewables: copiedViewables)
        } else {
            parent?.sendToTop(copiedViewables: copiedViewables)
        }
    }
    func sendToTop(_ reference: Reference) {
        if let subIndicatedParent = subIndicatedParent {
            subIndicatedParent.sendToTop(reference)
        } else {
            parent?.sendToTop(reference)
        }
    }
    
    func at<T>(_ p: Point, _ type: T.Type) -> T? {
        return at(p)?.withSelfAndAllParents(with: type)
    }
    func withSelfAndAllParents<T>(with type: T.Type) -> T? {
        var t: T?
        selfAndAllParents { (view, stop) in
            if !view.isForm, let at = view as? T {
                t = at
                stop = true
            }
        }
        return t
    }
    
    var locale = Locale.current
}
extension View: Equatable {
    static func ==(lhs: View, rhs: View) -> Bool {
        return lhs === rhs
    }
}

private final class C0DrawLayer: CALayer {
    init(backgroundColor: Color? = .background, borderColor: Color? = .getSetBorder) {
        super.init()
        self.needsDisplayOnBoundsChange = true
        self.drawsAsynchronously = true
        self.anchorPoint = Point()
        self.isOpaque = backgroundColor != nil
        self.borderWidth = borderColor == nil ? 0.0 : 0.5
        self.backgroundColor = backgroundColor?.cg
        self.borderColor = borderColor?.cg
    }
    override init(layer: Any) {
        super.init(layer: layer)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func action(forKey event: String) -> CAAction? {
        return nil
    }
    override var backgroundColor: CGColor? {
        didSet {
            self.isOpaque = backgroundColor != nil
            setNeedsDisplay()
        }
    }
    override var contentsScale: CGFloat {
        didSet {
            setNeedsDisplay()
        }
    }
    var drawClosure: ((CGContext) -> ())?
    override func draw(in ctx: CGContext) {
        if let backgroundColor = backgroundColor {
            ctx.setFillColor(backgroundColor)
            ctx.fill(ctx.boundingBoxOfClipPath)
        }
        drawClosure?(ctx)
    }
    func safetySetNeedsDisplay(_ closure: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        closure()
        setNeedsDisplay()
        CATransaction.commit()
    }
}

extension CALayer {
    static let disabledAnimationActions = ["backgroundColor": NSNull(),
                                           "content": NSNull(),
                                           "sublayers": NSNull(),
                                           "frame": NSNull(),
                                           "bounds": NSNull(),
                                           "position": NSNull(),
                                           "hidden": NSNull(),
                                           "opacity": NSNull(),
                                           "borderColor": NSNull(),
                                           "borderWidth": NSNull()]
    static var disabledAnimation: CALayer {
        let layer = CALayer()
        layer.actions = disabledAnimationActions
        return layer
    }
    static func interface(backgroundColor: Color? = nil,
                          borderColor: Color? = .getSetBorder) -> CALayer {
        let layer = CALayer()
        layer.isOpaque = true
        layer.actions = disabledAnimationActions
        layer.borderWidth = borderColor == nil ? 0.0 : 0.5
        layer.backgroundColor = backgroundColor?.cg
        layer.borderColor = borderColor?.cg
        return layer
    }
    func safetyRender(in ctx: CGContext) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        setNeedsDisplay()
        render(in: ctx)
        CATransaction.commit()
    }
}

extension CATransaction {
    static func disableAnimation(_ closure: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        closure()
        CATransaction.commit()
    }
}

extension CGPath {
    static func checkerboard(with size: Size, in frame: Rect) -> CGPath {
        let path = CGMutablePath()
        let xCount = Int(frame.width / size.width)
        let yCount = Int(frame.height / (size.height * 2))
        for xi in 0 ..< xCount {
            let x = frame.minX + CGFloat(xi) * size.width
            let fy = xi % 2 == 0 ? size.height : 0
            for yi in 0 ..< yCount {
                let y = frame.minY + CGFloat(yi) * size.height * 2 + fy
                path.addRect(Rect(x: x, y: y, width: size.width, height: size.height))
            }
        }
        return path
    }
}

extension CGContext {
    static func bitmap(with size: Size,
                       _ cs: CGColorSpace? = CGColorSpace(name: CGColorSpace.sRGB)) -> CGContext? {
        guard let colorSpace = cs else {
            return nil
        }
        return CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                         bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                         bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
    }
}

extension CGContext {
    func drawBlurWith(color fillColor: Color, width: CGFloat, strength: CGFloat,
                      isLuster: Bool, path: CGPath, scale: CGFloat, rotation: CGFloat) {
        let nFillColor: Color
        if fillColor.alpha < 1 {
            saveGState()
            setAlpha(CGFloat(fillColor.alpha))
            nFillColor = fillColor.with(alpha: 1)
        } else {
            nFillColor = fillColor
        }
        let pathBounds = path.boundingBoxOfPath.insetBy(dx: -width, dy: -width)
        let lineColor = strength == 1 ? nFillColor : nFillColor.multiply(alpha: strength)
        beginTransparencyLayer(in: boundingBoxOfClipPath.intersection(pathBounds),
                               auxiliaryInfo: nil)
        if isLuster {
            setShadow(offset: Size(), blur: width * scale, color: lineColor.cg)
        } else {
            let shadowY = hypot(pathBounds.size.width, pathBounds.size.height)
            translateBy(x: 0, y: shadowY)
            let shadowOffset = Size(width: shadowY * scale * sin(rotation),
                                      height: -shadowY * scale * cos(rotation))
            setShadow(offset: shadowOffset, blur: width * scale / 2, color: lineColor.cg)
            setLineWidth(width)
            setLineJoin(.round)
            setStrokeColor(lineColor.cg)
            addPath(path)
            strokePath()
            translateBy(x: 0, y: -shadowY)
        }
        setFillColor(nFillColor.cg)
        addPath(path)
        fillPath()
        endTransparencyLayer()
        if fillColor.alpha < 1 {
            restoreGState()
        }
    }
    func drawBlur(withBlurRadius blurRadius: CGFloat, to ctx: CGContext) {
        guard let image = makeImage() else {
            return
        }
        let ciImage = CIImage(cgImage: image)
        let cictx = CIContext(cgContext: ctx, options: nil)
        let filter = CIFilter(name: "CIGaussianBlur")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(Float(blurRadius), forKey: kCIInputRadiusKey)
        if let outputImage = filter?.outputImage {
            cictx.draw(outputImage,
                       in: ctx.boundingBoxOfClipPath,
                       from: Rect(origin: Point(), size: image.size))
        }
    }
}

extension C0View {
    func backingLayer(with view: View) -> CALayer {
        return view.caLayer
    }
}

enum ViewType {
    case form, get, getSet
}

enum SizeType {
    case small, regular
}

protocol Viewable: Referenceable {
    func view(withBounds bounds: Rect, _ sizeType: SizeType) -> View
}
protocol Thumbnailable {
    func thumbnail(withBounds bounds: Rect, _ sizeType: SizeType) -> View
}
protocol ObjectViewExpression: Viewable, Thumbnailable, DeepCopiable {
}
extension ObjectViewExpression {
    func view(withBounds bounds: Rect, _ sizeType: SizeType) -> View {
        return ObjectView(object: self,
                          thumbnailView: thumbnail(withBounds: bounds, sizeType),
                          minFrame: bounds, sizeType)
    }
}
protocol ObjectViewExpressionWithDisplayText: ObjectViewExpression {
    var displayText: Localization { get }
}
extension ObjectViewExpressionWithDisplayText {
    func thumbnail(withBounds bounds: Rect, _ sizeType: SizeType) -> View {
        return displayText.thumbnail(withBounds: bounds, sizeType)
    }
}

final class KnobView: View {
    init(radius: CGFloat = 5, lineWidth: CGFloat = 1) {
        super.init(isForm: true)
        fillColor = .knob
        lineColor = .getSetBorder
        self.lineWidth = lineWidth
        self.radius = radius
    }
    var radius: CGFloat {
        get {
            return min(bounds.width, bounds.height) / 2
        }
        set {
            frame = Rect(x: position.x - newValue, y: position.y - newValue,
                           width: newValue * 2, height: newValue * 2)
            cornerRadius = newValue
        }
    }
}
final class DiscreteKnobView: View {
    init(_ size: Size = Size(width: 5, height: 10), lineWidth: CGFloat = 1) {
        super.init(isForm: true)
        fillColor = .knob
        lineColor = .getSetBorder
        self.lineWidth = lineWidth
        frame.size = size
    }
}

final class GetterView<T: Viewable>: View, Copiable {
    var sizeType: SizeType
    let classNameView: TextView
    
    init(copiedViewablesClosure: @escaping () -> (T), sizeType: SizeType = .regular) {
        classNameView = TextView(text: T.name, font: Font.bold(with: sizeType))
        self.copiedViewablesClosure = copiedViewablesClosure
        self.sizeType = sizeType
        
        super.init()
    }
    
    override var bounds: Rect {
        didSet {
            updateLayout()
        }
    }
    func updateLayout() {
        let padding = Layout.padding(with: sizeType)
        classNameView.frame.origin = Point(x: padding,
                                             y: bounds.height - classNameView.frame.height - padding)
    }
    
    var copiedViewablesClosure: () -> (T)
    func copiedViewables(at p: Point) -> [Viewable] {
        return [copiedViewablesClosure()]
    }
    
    func reference(at p: Point) -> Reference {
        return T.reference
    }
}

final class ObjectView<T: DeepCopiable & Viewable & Referenceable>: View, Copiable {
    let object: T
    
    var sizeType: SizeType
    let classNameView: TextView, thumbnailView: View
    init(object: T, thumbnailView: View?, minFrame: Rect, thumbnailWidth: CGFloat = 40.0,
         _ sizeType: SizeType = .regular) {
        self.object = object
        classNameView = TextView(text: T.name, font: Font.bold(with: sizeType))
        self.thumbnailView = thumbnailView ?? View(isForm: true)
        self.sizeType = sizeType
        
        super.init()
        let width = max(minFrame.width, classNameView.frame.width + thumbnailWidth)
        self.frame = Rect(origin: minFrame.origin,
                            size: Size(width: width, height: minFrame.height))
        children = [classNameView, self.thumbnailView]
        updateLayout()
    }
    
    override var locale: Locale {
        didSet {
            updateLayout()
        }
    }
    
    override var bounds: Rect {
        didSet {
            updateLayout()
        }
    }
    func updateLayout() {
        let padding = Layout.padding(with: sizeType)
        classNameView.frame.origin = Point(x: padding,
                                             y: bounds.height - classNameView.frame.height - padding)
        thumbnailView.frame = Rect(x: classNameView.frame.maxX + padding,
                                     y: padding,
                                     width: bounds.width - classNameView.frame.width - padding * 3,
                                     height: bounds.height - padding * 2)
    }
    
    func copiedViewables(at p: Point) -> [Viewable] {
        return  [object.copied]
    }
    
    func reference(at p: Point) -> Reference {
        return T.reference
    }
}
