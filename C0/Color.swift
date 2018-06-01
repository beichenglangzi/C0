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

/**
 Issue: Lab色空間ベースのカラーピッカー及びカラー補間
 */
struct Color: Codable {
    var hue: Real {
        didSet {
            rgb = Color.hsvWithHSL(h: hue, s: saturation, l: lightness).rgb
        }
    }
    var saturation: Real {
        didSet {
            rgb = Color.hsvWithHSL(h: hue, s: saturation, l: lightness).rgb
        }
    }
    var lightness: Real {
        didSet {
            rgb = Color.hsvWithHSL(h: hue, s: saturation, l: lightness).rgb
        }
    }
    var sl: Point {
        get {
            return Point(x: saturation, y: lightness)
        }
        set {
            self.saturation = newValue.x
            self.lightness = newValue.y
        }
    }
    var alpha: Real
    var colorSpace: ColorSpace
    private(set) var rgb: RGB
    
    init(hue: Real = 0, saturation: Real = 0, lightness: Real = 0,
         alpha: Real = 1, colorSpace: ColorSpace = .sRGB) {
        self.hue = hue
        self.saturation = saturation
        self.lightness = lightness
        rgb = Color.hsvWithHSL(h: hue, s: saturation, l: lightness).rgb
        self.alpha = alpha
        self.colorSpace = colorSpace
    }
    init(hue: Real, saturation: Real, brightness: Real,
         alpha: Real = 1, colorSpace: ColorSpace = .sRGB) {
        let hsv = HSV(h: hue, s: saturation, v: brightness)
        self.init(hsv: hsv, rgb: hsv.rgb, alpha: alpha, colorSpace: colorSpace)
    }
    init(red: Real, green: Real, blue: Real,
         alpha: Real = 1, colorSpace: ColorSpace = .sRGB) {
        
        let rgb = RGB(r: red, g: green, b: blue)
        self.init(hsv: rgb.hsv, rgb: rgb, alpha: alpha, colorSpace: colorSpace)
    }
    init(rgb: RGB, alpha: Real = 1, colorSpace: ColorSpace = .sRGB) {
        self.init(hsv: rgb.hsv, rgb: rgb, alpha: alpha, colorSpace: colorSpace)
    }
    init(white: Real, alpha: Real = 1, colorSpace: ColorSpace = .sRGB) {
        self.init(hue: 0, saturation: 0, lightness: white, alpha: alpha, colorSpace: colorSpace)
    }
    init(hsv: HSV, rgb: RGB, alpha: Real, colorSpace: ColorSpace = .sRGB) {
        (hue, saturation, lightness) = Color.hsl(with: hsv)
        self.rgb = rgb
        self.alpha = alpha
        self.colorSpace = colorSpace
    }
}
extension Color {
    static let white = Color(hue: 0, saturation: 0, lightness: 1)
    static let gray = Color(hue: 0, saturation: 0, lightness: 0.5)
    static let black = Color(hue: 0, saturation: 0, lightness: 0)
    static let red = Color(red: 1, green: 0, blue: 0)
    static let green = Color(hue: 156.0 / 360, saturation: 1, brightness: 0.69)
    static let orange = Color(hue: 38.0 / 360, saturation: 1, brightness: 0.95)
    
    static let rgbRed = Color(red: 1, green: 0, blue: 0)
    static let rgbOrange = Color(red: 1, green: 0.5, blue: 0)
    static let rgbYellow = Color(red: 1, green: 1, blue: 0)
    static let rgbGreen = Color(red: 0, green: 1, blue: 0)
    static let rgbCyan = Color(red: 0, green: 1, blue: 1)
    static let rgbBlue = Color(red: 0, green: 0, blue: 1)
    static let rgbMagenta = Color(red: 1, green: 0, blue: 1)
    
    static let background = Color(white: 0.94)
    static let getSetBorder = Color(white: 0.7)
    static let getBorder = Color(white: 0.8)
    static let formBorder = Color(white: 0.84)
    static let bindingBorder = Color(red: 1.0, green: 0.0, blue: 1.0)
    static let content = Color(white: 0.35)
    static let subContent = Color(white: 0.88)
    static let font = Color(white: 0.05)
    static let knob = white
    static let locked = Color(white: 0.5)
    static let subLocked = Color(white: 0.65)
    static let editing = Color(white: 0.88)
    static let translucentEdit = Color(white: 0, alpha: 0.1)
    static let mainFocus = Color(red: 0.1, green: 0.6, blue: 0.9)
    static let zoomingFocus = Color(red: 0.1, green: 0.3, blue: 0.5)
    static let versioniongFocus = Color(red: 0.05, green: 0.1, blue: 0.3)
    static let indicated = Color(red: 0.1, green: 0.6, blue: 0.9)
    static let noBorderIndicated = Color(red: 0.85, green: 0.9, blue: 0.94)
    static let subIndicated = Color(red: 0.6, green: 0.95, blue: 1)
    static let select = Color(red: 0, green: 0.7, blue: 1, alpha: 0.3)
    static let selectBorder = Color(red: 0, green: 0.5, blue: 1, alpha: 0.5)
    static let deselect = Color(red: 0.9, green: 0.3, blue: 0, alpha: 0.3)
    static let deselectBorder = Color(red: 1, green: 0, blue: 0, alpha: 0.5)
    static let selected = Color(red: 0.1, green: 0.7, blue: 1)
    static let subSelected = Color(red: 0.8, green: 0.95, blue: 1)
    static let warning = rgbRed
}
extension Color {
    static func random(colorSpace: ColorSpace = .sRGB) -> Color {
        let hue = Real.random(min: 0, max: 1)
        let saturation = Real.random(min: 0.5, max: 1)
        let lightness = Real.random(min: 0.4, max: 0.9)
        return Color(hue: hue, saturation: saturation, lightness: lightness, colorSpace: colorSpace)
    }
    
    func with(hue: Real) -> Color {
        return Color(hue: hue, saturation: saturation, lightness:  lightness, alpha: alpha)
    }
    func with(saturation: Real) -> Color {
        return Color(hue: hue, saturation: saturation, lightness: lightness, alpha: alpha)
    }
    func with(lightness: Real) -> Color {
        return Color(hue: hue, saturation: saturation, lightness: lightness, alpha: alpha)
    }
    func with(saturation: Real, lightness: Real) -> Color {
        return Color(hue: hue, saturation: saturation, lightness: lightness, alpha: alpha)
    }
    func with(alpha: Real) -> Color {
        return Color(hue: hue, saturation: saturation, lightness: lightness, alpha: alpha)
    }
    
    func multiply(alpha: Real) -> Color {
        return Color(hue: hue, saturation: saturation, lightness: lightness,
                     alpha: self.alpha * alpha)
    }
    func multiply(white: Real) -> Color {
        return Color.linear(self, Color.white, t: white)
    }
    
    private static func hsl(with hsv: HSV) -> (h: Real, s: Real, l: Real) {
        let h = hsv.h, s = hsv.s, v = hsv.v
        let y = Color.y(withHue: h)
        let n = s * (1 - y) + y
        let nb = n == 0 ? 0 : y * v / n
        if nb < y {
            return (h, s, nb)
        } else {
            let n = 1 - y
            let nb = n == 0 ? 1 : (v - y) / n - s
            return (h, nb == 1 ? 0 : s / (1 - nb), n * nb + y)
        }
    }
    private static func hsvWithHSL(h: Real, s: Real, l: Real) -> HSV {
        let y = Color.y(withHue: h)
        if y < l {
            let by = y == 1 ? 0 : (l - y) / (1 - y)
            return HSV(h: h, s: -s * by + s, v: (1 - y) * (-s * by + s + by) + y)
        } else {
            let by = y == 0 ? 0 : l / y
            return HSV(h: h, s: s, v: s * by * (1 - y) + by * y)
        }
    }
    var hsv: HSV {
        return Color.hsvWithHSL(h: hue, s: saturation, l: lightness)
    }
    
    static func y(withHue hue: Real) -> Real {
        let hueRGB = HSV(h: hue, s: 1, v: 1).rgb
        return 0.299 * hueRGB.r + 0.587 * hueRGB.g + 0.114 * hueRGB.b
    }
}
extension Color: Equatable {
    static func ==(lhs: Color, rhs: Color) -> Bool {
        return lhs.hue == rhs.hue && lhs.saturation == lhs.saturation && lhs.lightness == rhs.lightness
            && lhs.alpha == rhs.alpha && lhs.colorSpace == rhs.colorSpace
    }
}
extension Color: Hashable {
    var hashValue: Int {
        return Hash.uniformityHashValue(with: [hue.hashValue, saturation.hashValue,
                                               lightness.hashValue,
                                               alpha.hashValue, colorSpace.hashValue])
    }
}
extension Color: Referenceable {
    static let name = Text(english: "Color", japanese: "カラー")
}
extension Color: Interpolatable {
    static func linear(_ f0: Color, _ f1: Color, t: Real) -> Color {
        let rgb = RGB.linear(f0.rgb, f1.rgb, t: t)
        let alpha = Real.linear(f0.alpha, f1.alpha, t: t)
        let color = Color(rgb: rgb, alpha: alpha)
        return color.saturation > 0 ?
            color :
            color.with(hue: Real.linear(f0.hue,
                                        f1.hue.loopValue(other: f0.hue),
                                        t: t).loopValue())
    }
    static func firstMonospline(_ f1: Color, _ f2: Color, _ f3: Color,
                                with ms: Monospline) -> Color {
        let rgb = RGB.firstMonospline(f1.rgb, f2.rgb, f3.rgb, with: ms)
        let alpha = Real.firstMonospline(f1.alpha, f2.alpha, f3.alpha, with: ms)
        let color = Color(rgb: rgb, alpha: alpha)
        return color.saturation > 0 ?
            color :
            color.with(hue: Real.firstMonospline(f1.hue,
                                                 f2.hue.loopValue(other: f1.hue),
                                                 f3.hue.loopValue(other: f1.hue),
                                                 with: ms).loopValue())
    }
    static func monospline(_ f0: Color, _ f1: Color, _ f2: Color, _ f3: Color,
                           with ms: Monospline) -> Color {
        let rgb = RGB.monospline(f0.rgb, f1.rgb, f2.rgb, f3.rgb, with: ms)
        let alpha = Real.monospline(f0.alpha, f1.alpha, f2.alpha, f3.alpha, with: ms)
        let color = Color(rgb: rgb, alpha: alpha)
        return color.saturation > 0 ?
            color :
            color.with(hue: Real.monospline(f0.hue,
                                            f1.hue.loopValue(other: f0.hue),
                                            f2.hue.loopValue(other: f0.hue),
                                            f3.hue.loopValue(other: f0.hue),
                                            with: ms).loopValue())
    }
    static func lastMonospline(_ f0: Color, _ f1: Color, _ f2: Color,
                               with ms: Monospline) -> Color {
        let rgb = RGB.lastMonospline(f0.rgb, f1.rgb, f2.rgb, with: ms)
        let alpha = Real.lastMonospline(f0.alpha, f1.alpha, f2.alpha, with: ms)
        let color = Color(rgb: rgb, alpha: alpha)
        return color.saturation > 0 ?
            color :
            color.with(hue: Real.lastMonospline(f0.hue,
                                                f1.hue.loopValue(other: f0.hue),
                                                f2.hue.loopValue(other: f0.hue),
                                                with: ms).loopValue())
    }
}
extension Color: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return View(frame: frame, fillColor: self, isLocked: true)
    }
}
extension Color: AbstractViewable {
    func abstractViewWith<T : BinderProtocol>(binder: T,
                                              keyPath: ReferenceWritableKeyPath<T, Color>,
                                              frame: Rect, _ sizeType: SizeType,
                                              type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return ColorView(binder: binder, keyPath: keyPath, frame: frame, sizeType: sizeType)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath, frame: frame, sizeType)
        }
    }
}
extension Color: ObjectViewable {}

struct RGB {
    var r = 0.0.cg, g = 0.0.cg, b = 0.0.cg
}
extension RGB {
    var hsv: HSV {
        let minValue = min(r, g, b), maxValue = max(r, g, b)
        let d = maxValue - minValue
        let s = maxValue == 0 ? d : d / maxValue, v = maxValue
        let h: Real = {
            guard d > 0 else {
                return d / 6
            }
            if r == maxValue {
                let hh = (g - b) / d
                return (hh < 0 ? hh + 6 : hh) / 6
            } else if g == maxValue {
                return (2 + (b - r) / d) / 6
            } else {
                return (4 + (r - g) / d) / 6
            }
        } ()
        return HSV(h: h, s: s, v: v)
    }
}
extension RGB: Codable {
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let r = try container.decode(Real.self)
        let g = try container.decode(Real.self)
        let b = try container.decode(Real.self)
        self.init(r: r, g: g, b: b)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(r)
        try container.encode(g)
        try container.encode(b)
    }
}
extension RGB: Interpolatable {
    static func linear(_ f0: RGB, _ f1: RGB, t: Real) -> RGB {
        let r = Real.linear(f0.r, f1.r, t: t)
        let g = Real.linear(f0.g, f1.g, t: t)
        let b = Real.linear(f0.b, f1.b, t: t)
        return RGB(r: r, g: g, b: b)
    }
    static func firstMonospline(_ f1: RGB, _ f2: RGB, _ f3: RGB, with ms: Monospline) -> RGB {
        let r = Real.firstMonospline(f1.r, f2.r, f3.r, with: ms)
        let g = Real.firstMonospline(f1.g, f2.g, f3.g, with: ms)
        let b = Real.firstMonospline(f1.b, f2.b, f3.b, with: ms)
        return RGB(r: r, g: g, b: b)
    }
    static func monospline(_ f0: RGB, _ f1: RGB, _ f2: RGB, _ f3: RGB, with ms: Monospline) -> RGB {
        let r = Real.monospline(f0.r, f1.r, f2.r, f3.r, with: ms)
        let g = Real.monospline(f0.g, f1.g, f2.g, f3.g, with: ms)
        let b = Real.monospline(f0.b, f1.b, f2.b, f3.b, with: ms)
        return RGB(r: r, g: g, b: b)
    }
    static func lastMonospline(_ f0: RGB, _ f1: RGB, _ f2: RGB, with ms: Monospline) -> RGB {
        let r = Real.lastMonospline(f0.r, f1.r, f2.r, with: ms)
        let g = Real.lastMonospline(f0.g, f1.g, f2.g, with: ms)
        let b = Real.lastMonospline(f0.b, f1.b, f2.b, with: ms)
        return RGB(r: r, g: g, b: b)
    }
}

struct HSV {
    var h = 0.0.cg, s = 0.0.cg, v = 0.0.cg
}
extension HSV {
    var rgb: RGB {
        guard s != 0 else {
            return RGB(r: v, g: v, b: v)
        }
        let h6 = 6 * h
        let hi = Int(h6)
        let nh = h6 - Real(hi)
        switch (hi) {
        case 0: return RGB(r: v, g: v * (1 - s * (1 - nh)), b: v * (1 - s))
        case 1: return RGB(r: v * (1 - s * nh), g: v, b: v * (1 - s))
        case 2: return RGB(r: v * (1 - s), g: v, b: v * (1 - s * (1 - nh)))
        case 3: return RGB(r: v * (1 - s), g: v * (1 - s * nh), b: v)
        case 4: return RGB(r: v * (1 - s * (1 - nh)), g: v * (1 - s), b: v)
        default: return RGB(r: v, g: v * (1 - s), b: v * (1 - s * nh))
        }
    }
}
extension HSV: Codable {
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let h = try container.decode(Real.self)
        let s = try container.decode(Real.self)
        let v = try container.decode(Real.self)
        self.init(h: h, s: s, v: v)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(h)
        try container.encode(s)
        try container.encode(v)
    }
}

enum ColorSpace: Int8, Codable, Hashable {
    case sRGB, displayP3
}
extension ColorSpace: Referenceable {
    static let name = Text(english: "Color space", japanese: "色空間")
}
extension ColorSpace: CustomStringConvertible {
    var description: String {
        switch self {
        case .sRGB: return "sRGB"
        case .displayP3: return "Display P3"
        }
    }
}
extension ColorSpace: DisplayableText {
    var displayText: Text {
        return Text(description)
    }
    static var displayTexts: [Text] {
        return [sRGB.displayText, displayP3.displayText]
    }
}

extension Color {
    init(_ cgColor: CGColor) {
        guard cgColor.numberOfComponents == 4,
            let components = cgColor.components,
            let name = cgColor.colorSpace?.name as String? else {
                self.init()
                return
        }
        switch name {
        case String(CGColorSpace.sRGB):
            self.init(red: Real(components[0]),
                      green: Real(components[1]),
                      blue: Real(components[2]),
                      alpha: Real(components[3]),
                      colorSpace: .sRGB)
        case String(CGColorSpace.displayP3):
            self.init(red: Real(components[0]),
                      green: Real(components[1]),
                      blue: Real(components[2]),
                      alpha: Real(components[3]),
                      colorSpace: .displayP3)
        default:
            self.init()
        }
    }
    
    func with(colorSpace: ColorSpace) -> Color {
        guard
            let cs = CGColorSpace.with(colorSpace),
            let cgColor = self.cg.converted(to: cs, intent: .defaultIntent, options: nil),
            let cps = cgColor.components, cgColor.numberOfComponents == 4 else {
                return self
        }
        return Color(red: Real(cps[0]), green: Real(cps[1]), blue: Real(cps[2]),
                     alpha: Real(cps[3]), colorSpace: colorSpace)
    }
    
    var cg: CGColor {
        return CGColor.with(rgb: rgb, alpha: alpha, colorSpace: CGColorSpace.with(colorSpace))
    }
}

extension CGColor {
    static func with(rgb: RGB, alpha a: Real = 1, colorSpace: CGColorSpace? = nil) -> CGColor {
        let cs = colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let cps = [Real(rgb.r), Real(rgb.g), Real(rgb.b), Real(a)]
        return CGColor(colorSpace: cs, components: cps)
            ?? CGColor(red: cps[0], green: cps[1], blue: cps[2], alpha: cps[3])
    }
}
extension CGColorSpace {
    static let `default` = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    static var labColorSpace: CGColorSpace? {
        return CGColorSpace(labWhitePoint: [0.95947, 1, 1.08883],
                            blackPoint: [0, 0, 0],
                            range: [-127, 127, -127, 127])
    }
    static func with(_ colorSpace: ColorSpace) -> CGColorSpace? {
        switch colorSpace {
        case .sRGB: return CGColorSpace(name: CGColorSpace.sRGB)
        case .displayP3: return CGColorSpace(name: CGColorSpace.displayP3)
        }
    }
}

struct HueCircle {
    var lineWidth: Real, colorSpace: ColorSpace
    var bounds: Rect {
        didSet {
            radius = min(bounds.width, bounds.height) / 2
        }
    }
    private(set) var radius: Real
    
    init(lineWidth: Real = 2, bounds: Rect = Rect(), colorSpace: ColorSpace = .sRGB) {
        self.lineWidth = lineWidth
        self.bounds = bounds
        self.radius = min(bounds.width, bounds.height) / 2
        self.colorSpace = colorSpace
    }
    
    func hue(withAngle angle: Real) -> Real {
        let a = (angle < -.pi + .pi / 6 ? 2 * (.pi) : 0) +  angle - .pi / 6
        return hue(withRevisionHue: (a < 0 ? 1 : 0) + a / (2 * (.pi)))
    }
    func angle(withHue hue: Real) -> Real {
        return revisionHue(withHue: hue) * 2 * (.pi) + .pi / 6
    }
    
    private let split = 1.0.cg / 12.0.cg, slow = 0.5.cg, fast = 1.5.cg
    private func revisionHue(withHue hue: Real) -> Real {
        if hue < split {
            return hue * fast
        } else if hue < split * 2 {
            return (hue - split) * slow + split * fast
        } else if hue < split * 3 {
            return (hue - split * 2) * slow + split * (fast + slow)
        } else if hue < split * 4 {
            return (hue - split * 3) * fast + split * (fast + slow * 2)
        } else if hue < split * 5 {
            return (hue - split * 4) * fast + split * (fast * 2 + slow * 2)
        } else if hue < split * 6 {
            return (hue - split * 5) * slow + split * (fast * 3 + slow * 2)
        } else if hue < split * 7 {
            return (hue - split * 6) * slow + split * (fast * 3 + slow * 3)
        } else if hue < split * 8 {
            return (hue - split * 7) * fast + split * (fast * 3 + slow * 4)
        } else if hue < split * 9 {
            return (hue - split * 8) * fast + split * (fast * 4 + slow * 4)
        } else if hue < split * 10 {
            return (hue - split * 9) * slow + split * (fast * 5 + slow * 4)
        } else if hue < split * 11 {
            return (hue - split * 10) * slow + split * (fast * 5 + slow * 5)
        } else {
            return (hue - split * 11) * fast + split * (fast * 5 + slow * 6)
        }
    }
    private func hue(withRevisionHue revisionHue: Real) -> Real {
        if revisionHue < split * fast {
            return revisionHue / fast
        } else if revisionHue < split * (fast + slow) {
            return (revisionHue - split * fast) / slow + split
        } else if revisionHue < split * (fast + slow * 2) {
            return (revisionHue - split * (fast + slow)) / slow + split * 2
        } else if revisionHue < split * (fast * 2 + slow * 2) {
            return (revisionHue - split * (fast + slow * 2)) / fast + split * 3
        } else if revisionHue < split * (fast * 3 + slow * 2) {
            return (revisionHue - split * (fast * 2 + slow * 2)) / fast + split * 4
        } else if revisionHue < split * (fast * 3 + slow * 3) {
            return (revisionHue - split * (fast * 3 + slow * 2)) / slow + split * 5
        } else if revisionHue < split * (fast * 3 + slow * 4) {
            return (revisionHue - split * (fast * 3 + slow * 3)) / slow + split * 6
        } else if revisionHue < split * (fast * 4 + slow * 4) {
            return (revisionHue - split * (fast * 3 + slow * 4)) / fast + split * 7
        } else if revisionHue < split * (fast * 5 + slow * 4) {
            return (revisionHue - split * (fast * 4 + slow * 4)) / fast + split * 8
        } else if revisionHue < split * (fast * 5 + slow * 5) {
            return (revisionHue - split * (fast * 5 + slow * 4)) / slow + split * 9
        } else if revisionHue < split * (fast * 5 + slow * 6) {
            return (revisionHue - split * (fast * 5 + slow * 5)) / slow + split * 10
        } else {
            return (revisionHue - split * (fast * 5 + slow * 6)) / fast + split * 11
        }
    }
    
    func draw(in ctx: CGContext) {
        let outR = radius
        let inR = outR - lineWidth, deltaAngle = 1 / outR
        let splitCount = Int(ceil(2 * .pi * outR))
        let inChord = 2 + inR / outR, outChord = 2.0.cg
        let points = [Point(x: inR, y: inChord / 2), Point(x: outR, y: outChord / 2),
                      Point(x: outR, y: -outChord / 2), Point(x: inR, y: -inChord / 2)]
        ctx.saveGState()
        ctx.translateBy(x: bounds.midX, y: bounds.midY)
        ctx.rotate(by: .pi / 6 - deltaAngle / 2)
        for i in 0..<splitCount {
            let hue = revisionHue(withHue: Real(i) / Real(splitCount))
            let color = Color(hue: hue, saturation: 1, brightness: 1, colorSpace: colorSpace)
            ctx.setFillColor(color.cg)
            ctx.addLines(between: points)
            ctx.fillPath()
            ctx.rotate(by: deltaAngle)
        }
        ctx.restoreGState()
    }
}

final class ColorView<T: BinderProtocol>: View, BindableReceiver {
    typealias Model = Color
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((ColorView<Binder>, BasicNotification) -> ())]()
    
    var defaultModel = Model()
    
    let hueView: CircularRealView<Binder>
    let slView: SlidablePointView<Binder>
    
    var hueLineWidth: Real {
        didSet {
            hueCircle.lineWidth = hueLineWidth
        }
    }
    var hueCircle = HueCircle() {
        didSet {
            hueDrawView.displayLinkDraw()
        }
    }
    var slRatio = 0.82.cg {
        didSet { updateLayout() }
    }
    let hueDrawView = View(drawClosure: { _, _ in })
    let slColorGradientView: View
    let slBlackWhiteGradientView: View
    
    init(binder: Binder, keyPath: BinderKeyPath,
         hLineWidth: Real = 2.5, hWidth: Real = 16, slPadding: Real? = nil, slRatio: Real = 0.82,
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.binder = binder
        self.keyPath = keyPath
        
        let valueOption = RealOption(defaultModel: 0, minModel: 0, maxModel: 1)
        hueView = CircularRealView(binder: binder, keyPath: keyPath.appending(path: \Color.hue),
                                   option: valueOption, width: hWidth)
        let slOption = PointOption(xOption: valueOption, yOption: valueOption)
        slView = SlidablePointView(binder: binder, keyPath: keyPath.appending(path: \Color.sl),
                                   option: slOption)
        
        if sizeType == .small {
            slView.knobView.radius = 4
            hueView.knobView.radius = 4
        }
        if let slPadding = slPadding {
            slView.padding = slPadding
        }
        hueView.width = hWidth
        self.hueLineWidth = hLineWidth
        self.slRatio = slRatio
        slColorGradientView = View(gradient: Gradient(values: [],
                                                      startPoint: Point(x: 0, y: 0),
                                                      endPoint: Point(x: 1, y: 0)))
        let slgValues = [Gradient.Value(color: Color(white: 0, alpha: 1), location: 0),
                         Gradient.Value(color: Color(white: 0, alpha: 0), location: 0.5),
                         Gradient.Value(color: Color(white: 1, alpha: 0), location: 0.5),
                         Gradient.Value(color: Color(white: 1, alpha: 1), location: 1)]
        slBlackWhiteGradientView = View(gradient: Gradient(values: slgValues,
                                                           startPoint: Point(x: 0, y: 0),
                                                           endPoint: Point(x: 0, y: 1)))
        
        super.init()
        hueDrawView.fillColor = nil
        hueDrawView.lineColor = nil
        hueDrawView.drawClosure = { [unowned self] ctx, _ in self.hueCircle.draw(in: ctx) }
        hueView.backgroundViews = [hueDrawView]
        slView.children = [slColorGradientView, slBlackWhiteGradientView, slView.knobView]
        children = [hueView, slView]
        self.frame = frame
    }
    
    override func updateLayout() {
        guard !bounds.isEmpty else { return }
        let padding = Layout.smallPadding
        let r = floor(min(bounds.size.width, bounds.size.height) / 2) - padding
        hueView.frame = Rect(x: padding, y: padding, width: r * 2, height: r * 2)
        let sr = r - hueView.width
        let b2 = floor(sr * slRatio)
        let a2 = floor(sqrt(sr * sr - b2 * b2))
        slView.frame = Rect(x: bounds.size.width / 2 - a2,
                            y: bounds.size.height / 2 - b2,
                            width: a2 * 2,
                            height: b2 * 2)
        let slInFrame = slView.bounds.inset(by: slView.padding)
        slColorGradientView.frame = slInFrame
        slBlackWhiteGradientView.frame = slInFrame
        
        hueDrawView.frame = hueView.bounds.inset(by: ceil((hueView.width - hueLineWidth) / 2))
        hueCircle = HueCircle(lineWidth: hueLineWidth,
                              bounds: hueDrawView.bounds,
                              colorSpace: model.colorSpace)
    }
    func updateWithModel() {
        if model.colorSpace != hueCircle.colorSpace {
            updateWithColorSpace()
        }
        
        let y = Color.y(withHue: model.hue)
        slColorGradientView.gradient?.colors = [Color(hue: model.hue, saturation: 0, brightness: y),
                                                Color(hue: model.hue, saturation: 1, brightness: 1)]
        slBlackWhiteGradientView.gradient?.locations = [0, y, y, 1]
        
        hueView.updateWithModel()
        slView.updateWithModel()
    }
    private func updateWithColorSpace() {
        let colors = [Color(white: 0, alpha: 1, colorSpace: model.colorSpace),
                      Color(white: 0, alpha: 0, colorSpace: model.colorSpace),
                      Color(white: 1, alpha: 0, colorSpace: model.colorSpace),
                      Color(white: 1, alpha: 1, colorSpace: model.colorSpace)]
        slBlackWhiteGradientView.gradient?.colors = colors
        hueCircle = HueCircle(lineWidth: hueLineWidth,
                              bounds: hueDrawView.bounds,
                              colorSpace: model.colorSpace)
    }
}
extension ColorView: Assignable {
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
