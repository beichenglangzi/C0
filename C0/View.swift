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
                caLayer.transform
                    = CATransform3DMakeAffineTransform(transform.affineTransform)
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
    var opacity: Real {
        get { return Real(caLayer.opacity) }
        set { caLayer.opacity = Float(newValue) }
    }
    
    var lineColor: Color? {
        get { return lineColorComposition?.value }
        set {
            if let lineColor = newValue {
                lineColorComposition = Composition(value: lineColor)
            } else {
                lineColorComposition = nil
            }
        }
    }
    var lineColorComposition: Composition<Color>? {
        didSet {
            guard lineColorComposition != oldValue else { return }
            set(lineWidth: lineColorComposition != nil ? lineWidth : 0)
            if let caShapeLayer = caLayer as? CAShapeLayer {
                caShapeLayer.strokeColor = lineColorComposition?.cgColor
            } else {
                caLayer.borderColor = lineColorComposition?.cgColor
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
        get { return fillColorComposition?.value }
        set {
            if let fillColor = newValue {
                fillColorComposition = Composition(value: fillColor)
            } else {
                fillColorComposition = nil
            }
        }
    }
    var fillColorComposition: Composition<Color>? {
        didSet {
            guard fillColorComposition != oldValue else { return }
            if let caShapeLayer = caLayer as? CAShapeLayer {
                caShapeLayer.fillColor = fillColorComposition?.cgColor
            } else {
                caLayer.backgroundColor = fillColorComposition?.cgColor
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
            caGradientLayer.colors = gradient.values.map {
                $0.colorComposition.cgColor
            }
            caGradientLayer.locations = gradient.values.map {
                NSNumber(value: Double($0.location))
            }
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
            caLayer.contentsGravity = kCAGravityResizeAspect
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
        caLayer.safetyRender(in: ctx)
    }
    func renderImage(with size: Size) -> Image? {
        guard let ctx = CGContext.bitmap(with: size, CGColorSpace.default) else {
                return nil
        }
        let scale = size.width / bounds.width
        let translation = Point(x: -bounds.centerPoint.x * scale + size.width / 2,
                                y: -bounds.centerPoint.y * scale + size.height / 2)
        let viewTransform = Transform(translation: translation,
                                      scale: Point(x: scale, y: scale),
                                      rotation: 0)
        ctx.setFillColor(Color.background.cg)
        ctx.fill(Rect(origin: Point(), size: size))
        ctx.concatenate(viewTransform.affineTransform)
        render(in: ctx)
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
        caLayer = caGradientLayer
        self.gradient = gradient
        View.update(with: gradient, in: caGradientLayer)
    }
    init(path: Path, isLocked: Bool = true, lineColor: Color? = nil) {
        self.isLocked = isLocked
        let caShapeLayer = CAShapeLayer()
        var actions = CALayer.disabledAnimationActions
        actions["fillColor"] = NSNull()
        actions["strokeColor"] = NSNull()
        caShapeLayer.actions = actions
        caShapeLayer.anchorPoint = Point()
        caShapeLayer.fillColor = nil
        caShapeLayer.lineWidth = 0
        caShapeLayer.lineCap = kCALineCapRound
        caShapeLayer.strokeColor = lineColor?.cg
        caShapeLayer.path = path.cg
        caLayer = caShapeLayer
    }
    init(drawClosure: ((CGContext, View, Rect) -> ())?,
         fillColor: Color? = nil, lineColor: Color? = nil,
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
    
    func contains(_ p: Point) -> Bool {
        return !isLocked && !isHidden && containsPath(p)
    }
    func containsPath(_ p: Point) -> Bool {
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
        view.fillColorComposition = .select
        view.lineColor = .background
        return view
    }
    static var deselection: View {
        let view = View()
        view.fillColorComposition = .anti
        view.lineColor = .background
        return view
    }
    static var knob: View {
        return knob(radius: Layouter.knobRadius, lineWidth: Layouter.lineWidth)
    }
    static func knob(radius: Real, lineWidth: Real) -> View {
        let view = View()
        view.fillColor = .content
        view.lineColor = .background
        view.lineWidth = lineWidth
        view.radius = radius
        return view
    }
    static var slidableKnob: View {
        return slidableKnob(Size(square: Layouter.slidableKnobRadius * 2),
                            lineWidth: Layouter.lineWidth)
    }
    static func slidableKnob(_ size: Size, lineWidth: Real) -> View {
        let view = View()
        view.fillColor = .content
        view.lineColor = .background
        view.lineWidth = lineWidth
        view.bounds = Rect(origin: Point(x: -size.width / 2, y: -size.height / 2), size: size)
        return view
    }
}

private final class C0DrawLayer: CALayer {
    init(backgroundColor: Color? = nil, borderColor: Color? = nil) {
        super.init()
        needsDisplayOnBoundsChange = true
        drawsAsynchronously = true
        anchorPoint = Point()
        isOpaque = backgroundColor != nil
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
        didSet { setNeedsDisplay() }
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
                          borderColor: Color? = nil) -> CALayer {
        let layer = CALayer()
        layer.isOpaque = true
        layer.anchorPoint = Point()
        layer.actions = disabledAnimationActions
        layer.backgroundColor = backgroundColor?.cg
        layer.borderColor = borderColor?.cg
        return layer
    }
    func safetyRender(in ctx: CGContext) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
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
    var closure: ((Real) -> ())?
    
    var isRunning: Bool {
        return CVDisplayLinkIsRunning(cv)
    }
    
    var time = 0.0.cg
    var frameRate = 60.0.cg {
        didSet {
            distanceTime = TimeInterval(1 / frameRate)
        }
    }
    private var beginTimestamp = Date() {
        didSet {
            oldTimestamp = beginTimestamp
        }
    }
    private var distanceTime = TimeInterval(1 / 60.0.cg)
    private let cv: CVDisplayLink
    private let source: DispatchSourceUserDataAdd
    private var oldTimestamp = Date()
    
    init?(queue: DispatchQueue = DispatchQueue.main) {
        source = DispatchSource.makeUserDataAddSource(queue: queue)
        var aCV: CVDisplayLink?
        var success = CVDisplayLinkCreateWithActiveCGDisplays(&aCV)
        guard success == kCVReturnSuccess, let cv = aCV else {
            return nil
        }
        func callback(displayLink: CVDisplayLink,
                      inNow: UnsafePointer<CVTimeStamp>, inOutputTime: UnsafePointer<CVTimeStamp>,
                      flagsIn: CVOptionFlags, flagsOut: UnsafeMutablePointer<CVOptionFlags>,
                      displayLinkContext: UnsafeMutableRawPointer?) -> CVReturn {
            guard let displayLinkContext = displayLinkContext else { return kCVReturnError }
            let unmanaged = Unmanaged<DispatchSourceUserDataAdd>.fromOpaque(displayLinkContext)
            unmanaged.takeUnretainedValue().add(data: 1)
            return kCVReturnSuccess
        }
        success = CVDisplayLinkSetOutputCallback(cv,
                                                 callback,
                                                 Unmanaged.passUnretained(source).toOpaque())
        guard success == kCVReturnSuccess else {
            return nil
        }
        success = CVDisplayLinkSetCurrentCGDisplay(cv, CGMainDisplayID())
        guard success == kCVReturnSuccess else {
            return nil
        }
        self.cv = cv

        source.setEventHandler { [weak self] in
            guard let link = self else { return }
            let currentTimestamp = Date()
            let d = currentTimestamp.timeIntervalSince(link.oldTimestamp)
            if d >= link.distanceTime {
                link.closure?(link.time)
                link.oldTimestamp = currentTimestamp
            }
        }
    }
    deinit { stop() }
    
    func start() {
        guard !isRunning else { return }
        oldTimestamp = Date()
        CVDisplayLinkStart(cv)
        source.resume()
    }
    func stop() {
        guard isRunning else { return }
        CVDisplayLinkStop(cv)
        source.cancel()
    }
}

extension C0View {
    func backingLayer(with view: View) -> CALayer {
        return view.caLayer
    }
}
