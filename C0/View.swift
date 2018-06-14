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
import QuartzCore

struct Screen {
    static var shared = Screen()
    var backingScaleFactor = 1.0.cg
}

/**
 Issue: CoreGraphicsとQuartzCoreを廃止し、MetalでGPUレンダリング
 Issue: リニアワークフロー、マクロ拡散光
 */
class View {
    private(set) weak var parent: View?
    private var _children = [View]()
    var children: [View] {
        get { return _children }
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
    func insert(child: View, at index: Array<View>.Index) {
        child.removeFromParent()
        caLayer.insertSublayer(child.caLayer, at: UInt32(index))
        _children.insert(child, at: index)
        child.parent = self
        child.allChildrenAndSelf { $0.contentsScale = contentsScale }
    }
    func removeFromParent() {
        guard let parent = parent else { return }
        caLayer.removeFromSuperlayer()
        if let index = parent._children.index(where: { $0 === self }) {
            parent._children.remove(at: index)
        }
        self.parent = nil
    }
    
    func allChildrenAndSelf(_ closure: (View) -> ()) {
        func allChildrenRecursion(_ child: View, _ closure: (View) -> Void) {
            child._children.forEach { allChildrenRecursion($0, closure) }
            closure(child)
        }
        allChildrenRecursion(self, closure)
    }
    func allParents(closure: (View, inout Bool) -> ()) {
        guard let parent = parent else { return }
        var stop = false
        closure(parent, &stop)
        guard !stop else { return }
        parent.allParents(closure: closure)
    }
    func selfAndAllParents(closure: (View, inout Bool) -> ()) {
        var stop = false
        closure(self, &stop)
        guard !stop else { return }
        parent?.selfAndAllParents(closure: closure)
    }
    var root: View {
        return parent?.root ?? self
    }
    
    var isEmpty: Bool {
        return bounds.isEmpty && path.isEmpty
    }
    var bounds = Rect.null {
        didSet {
            guard bounds != oldValue else { return }
            if !bounds.isNull {
                caLayer.bounds = bounds
                caLayer.position = bounds.origin
            } else {
                caLayer.frame = Rect()
            }
            updateLayout()
        }
    }
    var radius: Real {
        get { return caLayer.cornerRadius }
        set {
            caLayer.cornerRadius = newValue
            bounds = Rect(origin: Point(x: -radius, y: -radius),
                          size: Size(square: radius * 2))
        }
    }
    var path: Path {
        get {
            guard let caShapeLayer = caLayer as? CAShapeLayer,
                let path = caShapeLayer.path else {
                    return Path()
            }
            return Path(path)
        }
        set {
            guard let caShapeLayer = caLayer as? CAShapeLayer else { fatalError() }
            caShapeLayer.path = newValue.isEmpty ? nil : newValue.cg
            updateLayout()
        }
    }
    var isClipped = false {
        didSet {
            guard isClipped != oldValue else { return }
            if !bounds.isNull {
                caLayer.mask = nil
                caLayer.masksToBounds = isClipped
            } else {
                caLayer.masksToBounds = false
                if isClipped {
                    let shapelayer = CAShapeLayer()
                    shapelayer.path = path.cg
                    caLayer.mask = shapelayer
                } else {
                    caLayer.mask = nil
                }
            }
        }
    }
    
    func updateLayout() {}
    
    var transform = Transform() {
        didSet {
            guard transform != oldValue else { return }
            CATransaction.disableAnimation {
//                caLayer.position = transform.translation
                caLayer.transform
                    = CATransform3DMakeAffineTransform(transform.affineTransform)
//                parent?.updateLayout()
            }
        }
    }
    var frame: Rect {
        get {
            guard !bounds.isNull else {
                return Rect()
            }
            return Rect(origin: transform.translation, size: bounds.size)
        }
        set {
            transform.translation = newValue.origin
            bounds = Rect(origin: Point(), size: newValue.size)
        }
    }
    var transformedBoundingBox: Rect {
        if !bounds.isNull {
            return bounds * transform.affineTransform
        } else {
            return path.boundingBoxOfPath * transform.affineTransform
        }
    }
    var position: Point {
        get { return transform.translation }
        set { transform.translation = newValue }
    }
    
    var isHidden: Bool {
        get { return caLayer.isHidden }
        set { caLayer.isHidden = newValue }
    }
    var effect = Effect() {
        didSet {
            guard effect != oldValue else { return }
            
            if effect.opacity != oldValue.opacity {
                caLayer.opacity = Float(effect.opacity)
            }
            if effect.blurRadius != oldValue.blurRadius {
                if effect.blurRadius > 0 {
                    if let filter = CIFilter(name: "CIGaussianBlur") {
                        filter.setValue(Float(effect.blurRadius), forKey: kCIInputRadiusKey)
                        caLayer.filters = [filter]
                    }
                } else if caLayer.filters != nil {
                    caLayer.filters = nil
                }
            }
            if effect.blendType != oldValue.blendType {
                switch effect.blendType {
                case .normal: caLayer.compositingFilter = nil
                case .addition: caLayer.compositingFilter = CIFilter(name: " CIAdditionCompositing")
                case .subtract: caLayer.compositingFilter = CIFilter(name: "CISubtractBlendMode")
                }
            }
        }
    }
    
    var lineColor: Color? = .getSetBorder {
        didSet {
            guard lineColor != oldValue else { return }
            set(lineWidth: lineColor != nil ? lineWidth : 0)
            if let caShapeLayer = caLayer as? CAShapeLayer {
                caShapeLayer.strokeColor = lineColor?.cg
            } else {
                caLayer.borderColor = lineColor?.cg
            }
        }
    }
    var lineWidth = 0.5.cg {
        didSet {
            set(lineWidth: lineColor != nil ? lineWidth : 0)
        }
    }
    private func set(lineWidth: Real) {
        if let caShapeLayer = caLayer as? CAShapeLayer {
            caShapeLayer.lineWidth = lineWidth
        } else {
            caLayer.borderWidth = lineWidth
        }
    }
    
    var fillColor: Color? {
        didSet {
            guard fillColor != oldValue else { return }
            if let caShapeLayer = caLayer as? CAShapeLayer {
                caShapeLayer.fillColor = fillColor?.cg
            } else {
                caLayer.backgroundColor = fillColor?.cg
            }
        }
    }
    var gradient: Gradient? {
        didSet {
            guard let gradient = gradient,
                let caGradientLayer = caLayer as? CAGradientLayer else {
                    fatalError()
            }
            View.update(with: gradient, in: caGradientLayer)
        }
    }
    private static func update(with gradient: Gradient,
                               in caGradientLayer: CAGradientLayer) {
        if gradient.values.isEmpty {
            caGradientLayer.colors = nil
            caGradientLayer.locations = nil
        } else {
            caGradientLayer.colors = gradient.values.map { $0.color.cg }
            caGradientLayer.locations = gradient.values.map { NSNumber(value: Double($0.location)) }
        }
        caGradientLayer.startPoint = gradient.startPoint
        caGradientLayer.endPoint = gradient.endPoint
    }
    var image: Image? {
        get {
            guard let contents = caLayer.contents else {
                return nil
            }
            return Image(contents as! CGImage)
        }
        set {
            caLayer.contents = newValue?.cg
            if newValue != nil {
                caLayer.minificationFilter = kCAFilterTrilinear
                caLayer.magnificationFilter = kCAFilterTrilinear
            } else {
                caLayer.minificationFilter = kCAFilterLinear
                caLayer.magnificationFilter = kCAFilterLinear
            }
        }
    }
    var contentsScale: Real {
        get { return caLayer.contentsScale }
        set {
            guard newValue != caLayer.contentsScale else { return }
            caLayer.contentsScale = newValue
        }
    }
    var drawClosure: ((CGContext, View, Rect) -> ())? {
        didSet {
            (caLayer as! C0DrawLayer).drawClosure = { [unowned self] ctx in
                self.drawClosure?(ctx, self, ctx.boundingBoxOfClipPath)
            }
        }
    }
    func displayLinkDraw() {
        caLayer.setNeedsDisplay()
    }
    func displayLinkDraw(_ rect: Rect) {
        caLayer.setNeedsDisplay(rect)
    }
    func draw(in ctx: CGContext) {
        caLayer.draw(in: ctx)
    }
    func render(in ctx: CGContext) {
        (caLayer as! C0DrawLayer).safetyRender(in: ctx)
    }
    func renderImage(with size: Size) -> Image? {
        guard let ctx = CGContext.bitmap(with: size, CGColorSpace.default) else {
                return nil
        }
        let frame = transformedBoundingBox
        let scale = size.width / frame.size.width
        let viewTransform = Transform(translation: Point(x: size.width / 2, y: size.height / 2),
                                      scale: Point(x: scale, y: scale),
                                      rotation: 0)
        let drawView = View(drawClosure: { ctx, _, _ in
            ctx.concatenate(viewTransform.affineTransform)
            self.draw(in: ctx)
        })
        drawView.render(in: ctx)
        return ctx.renderImage
    }
    
    var isLocked = false
    
    fileprivate var caLayer: CALayer
    init(isLocked: Bool = true) {
        self.isLocked = isLocked
        caLayer = CALayer.interface()
        self.bounds = Rect()
    }
    
    init(frame: Rect, fillColor: Color? = nil, isLocked: Bool = true) {
        self.isLocked = isLocked
        caLayer = CALayer.interface(backgroundColor: fillColor)
        self.fillColor = fillColor
        self.frame = frame
    }
    init(gradient: Gradient, isLocked: Bool = true) {
        self.isLocked = isLocked
        var actions = CALayer.disabledAnimationActions
        actions["colors"] = NSNull()
        actions["locations"] = NSNull()
        actions["startPoint"] = NSNull()
        actions["endPoint"] = NSNull()
        let caGradientLayer = CAGradientLayer()
        caGradientLayer.actions = actions
        caGradientLayer.anchorPoint = Point()
        caGradientLayer.borderWidth = 0.5
        caGradientLayer.borderColor = Color.getSetBorder.cg
        caLayer = caGradientLayer
        self.gradient = gradient
        View.update(with: gradient, in: caGradientLayer)
    }
    init(path: Path, isLocked: Bool = true) {
        self.isLocked = isLocked
        let caShapeLayer = CAShapeLayer()
        var actions = CALayer.disabledAnimationActions
        actions["fillColor"] = NSNull()
        actions["strokeColor"] = NSNull()
        caShapeLayer.actions = actions
        caShapeLayer.anchorPoint = Point()
        caShapeLayer.fillColor = nil
        caShapeLayer.lineWidth = 0
        caShapeLayer.strokeColor = lineColor?.cg
        caShapeLayer.path = path.cg
        caLayer = caShapeLayer
    }
    init(drawClosure: ((CGContext, View, Rect) -> ())?,
         fillColor: Color? = .background, lineColor: Color? = .getSetBorder,
         isLocked: Bool = true) {
        
        self.isLocked = isLocked
        let caDrawLayer = C0DrawLayer()
        caLayer = caDrawLayer
        self.fillColor = fillColor
        self.lineColor = lineColor
        self.drawClosure = drawClosure
        caDrawLayer.backgroundColor = fillColor?.cg
        caDrawLayer.borderColor = lineColor?.cg
        caDrawLayer.borderWidth = lineColor == nil ? 0 : lineWidth
        caDrawLayer.drawClosure = { [unowned self] ctx in
            self.drawClosure?(ctx, self, ctx.boundingBoxOfClipPath)
        }
    }
}
extension View {
    func contains(_ p: Point) -> Bool {
        return !isLocked && !isHidden && containsPath(p)
    }
    private func containsPath(_ p: Point) -> Bool {
        if !bounds.isNull {
            return bounds.contains(p)
        } else {
            return path.contains(p)
        }
    }
    func contains(_ rect: Rect) -> Bool {
        if !bounds.isNull {
            return bounds.intersects(rect)
        } else {
            return path.contains(rect)
        }
    }
    func containsFromAllParents(_ parent: View) -> Bool {
        var isParent = false
        allParents { (view, stop) in
            if view == parent {
                isParent = true
                stop = true
            }
        }
        return isParent
    }
    
    func at(_ p: Point) -> View? {
        guard !(isLocked && _children.isEmpty) else {
            return nil
        }
        guard ((!isClipped && isEmpty) || containsPath(p)) && !isHidden else {
            return nil
        }
        for child in _children.reversed() {
            let inPoint = p * child.transform.affineTransform.inverted()
            if let view = child.at(inPoint) {
                return view
            }
        }
        return isLocked || (!isClipped && isEmpty) ? nil : self
    }
    func at<T>(_ p: Point, _ type: T.Type) -> T? {
        return at(p)?.withSelfAndAllParents(with: type)
    }
    func withSelfAndAllParents<T>(with type: T.Type) -> T? {
        var t: T?
        selfAndAllParents { (view, stop) in
            if !view.isLocked, let at = view as? T {
                t = at
                stop = true
            }
        }
        return t
    }
    
    func convert<T: AppliableAffineTransform>(_ value: T, from view: View) -> T {
        guard self != view else {
            return value
        }
        if containsFromAllParents(view) {
            return convert(value, fromParent: view)
        } else if view.containsFromAllParents(self) {
            return view.convert(value, toParent: self)
        } else {
            let rootValue = view.convertToRoot(value)
            return convertFromRoot(rootValue)
        }
    }
    private func convert<T: AppliableAffineTransform>(_ value: T, fromParent: View) -> T {
        var affine = AffineTransform.identity
        selfAndAllParents { (view, stop) in
            if view == fromParent {
                stop = true
            } else {
                affine *= view.transform.affineTransform
            }
        }
        return value * affine.inverted()
    }
    func convertFromRoot<T: AppliableAffineTransform>(_ value: T) -> T {
        var affine = AffineTransform.identity
        selfAndAllParents { (view, _) in
            if view.parent != nil {
                affine *= view.transform.affineTransform
            }
        }
        return value * affine.inverted()
    }
    
    func convert<T: AppliableAffineTransform>(_ value: T, to view: View) -> T {
        guard self != view else {
            return value
        }
        if containsFromAllParents(view) {
            return convert(value, toParent: view)
        } else if view.containsFromAllParents(self) {
            return view.convert(value, fromParent: self)
        } else {
            let rootValue = convertToRoot(value)
            return view.convertFromRoot(rootValue)
        }
    }
    private func convert<T: AppliableAffineTransform>(_ value: T, toParent: View) -> T {
        guard let parent = parent else {
            return value
        }
        if parent == toParent {
            return value * transform.affineTransform
        } else {
            return parent.convert(value * transform.affineTransform, toParent: toParent)
        }
    }
    func convertToRoot<T: AppliableAffineTransform>(_ value: T) -> T {
        return parent?.convertToRoot(value * transform.affineTransform) ?? value
    }
}
extension View: Equatable {
    static func ==(lhs: View, rhs: View) -> Bool {
        return lhs === rhs
    }
}
extension View {
    static var selection: View {
        let view = View()
        view.fillColor = .select
        view.lineColor = .selectBorder
        return view
    }
    static var deselection: View {
        let view = View()
        view.fillColor = .deselect
        view.lineColor = .deselectBorder
        return view
    }
    static func knob(radius: Real = 5, lineWidth: Real = 1) -> View {
        let view = View()
        view.fillColor = .knob
        view.lineColor = .getSetBorder
        view.lineWidth = lineWidth
        view.radius = radius
        return view
    }
    static func discreteKnob(_ size: Size = Size(width: 10, height: 10),
                             lineWidth: Real = 1) -> View {
        let view = View()
        view.fillColor = .knob
        view.lineColor = .getSetBorder
        view.lineWidth = lineWidth
        view.bounds = Rect(origin: Point(x: -size.width / 2, y: -size.height / 2), size: size)
        return view
    }
}

private final class C0DrawLayer: CALayer {
    init(backgroundColor: Color? = .background, borderColor: Color? = .getSetBorder) {
        super.init()
        self.needsDisplayOnBoundsChange = true
        self.drawsAsynchronously = true
        self.anchorPoint = Point()
        self.isOpaque = backgroundColor != nil
        self.borderWidth = borderColor == nil ? 0 : 0.5
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
    override var contentsScale: Real {
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
        layer.anchorPoint = Point()
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

final class DisplayLink {
    var closure: ((Second) -> ())?
    
    var isRunning: Bool {
        return false
//        return CVDisplayLinkIsRunning(cv)
    }
    
    var time = Second(0)
    var frameRate = FPS(60) {
        didSet {
            distanceTime = TimeInterval(1 / frameRate)
        }
    }
    private var beginTimestamp = Date() {
        didSet {
            oldTimestamp = beginTimestamp
        }
    }
    private var distanceTime = TimeInterval(1 / FPS(60))
//    private let cv: CVDisplayLink
//    private let source: DispatchSourceUserDataAdd
    private var oldTimestamp = Date()
    
    init?(queue: DispatchQueue = DispatchQueue.main) {
//        source = DispatchSource.makeUserDataAddSource(queue: queue)
//        var acv: CVDisplayLink?
//        var success = CVDisplayLinkCreateWithActiveCGDisplays(&acv)
//        guard let cv = acv else {
//            return nil
//        }
////        func callback(displayLink: CVDisplayLink,
////                      inNow: UnsafePointer<CVTimeStamp>, inOutputTime: UnsafePointer<CVTimeStamp>,
////                      flagsIn: CVOptionFlags, flagsOut: UnsafeMutablePointer<CVOptionFlags>,
////                      displayLinkContext: UnsafeMutableRawPointer?) -> CVReturn {
////            guard let displayLinkContext = displayLinkContext else { return kCVReturnSuccess }
////            let unmanaged = Unmanaged<DispatchSourceUserDataAdd>.fromOpaque(displayLinkContext)
////            unmanaged.takeUnretainedValue().add(data: 1)
////            return kCVReturnSuccess
////        }
//        success = CVDisplayLinkSetOutputCallback(cv,
//                                                 { (displayLink: CVDisplayLink,
//                                                    inNow: UnsafePointer<CVTimeStamp>,
//                                                    inOutputTime: UnsafePointer<CVTimeStamp>,
//                                                    flagsIn: CVOptionFlags,
//                                                    flagsOut: UnsafeMutablePointer<CVOptionFlags>,
//                                                    displayLinkContext: UnsafeMutableRawPointer?)
//                                                    -> CVReturn in
//                                                        guard let displayLinkContext = displayLinkContext else { return kCVReturnSuccess }
//                                                        let unmanaged = Unmanaged<DispatchSourceUserDataAdd>.fromOpaque(displayLinkContext)
//                                                        unmanaged.takeUnretainedValue().add(data: 1)
//                                                        return kCVReturnSuccess
//                                                    },
//                                                    Unmanaged.passUnretained(source).toOpaque())
//        guard success == kCVReturnSuccess else {
//            return nil
//        }
//        success = CVDisplayLinkSetCurrentCGDisplay(cv, CGMainDisplayID())
//        guard success == kCVReturnSuccess else {
//            return nil
//        }
//        self.cv = cv
//
//        source.setEventHandler { [weak self] in
//            guard let link = self else { return }
//            let currentTimestamp = Date()
//            let d = currentTimestamp.timeIntervalSince(link.oldTimestamp)
//            if d >= link.distanceTime {
//                link.closure?(link.time)
//                link.oldTimestamp = currentTimestamp
//            }
//        }
    }
    deinit {
//        stop()
    }
    
    func start() {
//        guard !isRunning else { return }
//        oldTimestamp = Date()
//        CVDisplayLinkStart(cv)
//        source.resume()
    }
    func stop() {
//        guard isRunning else { return }
//        CVDisplayLinkStop(cv)
//        source.cancel()
    }
}

extension C0View {
    func backingLayer(with view: View) -> CALayer {
        return view.caLayer
    }
}
