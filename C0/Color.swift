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

/**
 # Issue
 - Lab色空間ベースのカラーピッカー及びカラー補間
 */
struct Color: Codable {
    static let white = Color(hue: 0, saturation: 0, lightness: 1)
    static let gray = Color(hue: 0, saturation: 0, lightness: 0.5)
    static let black = Color(hue: 0, saturation: 0, lightness: 0)
    static let red = Color(red: 1, green: 0, blue: 0)
    static let green = Color(hue: 156.0 / 360.0, saturation: 1, brightness: 0.69)
    static let orange = Color(hue: 38.0 / 360.0, saturation: 1, brightness: 0.95)
    
    static let rgbRed = Color(red: 1, green: 0, blue: 0)
    static let rgbOrange = Color(red: 1, green: 0.5, blue: 0)
    static let rgbYellow = Color(red: 1, green: 1, blue: 0)
    static let rgbGreen = Color(red: 0, green: 1, blue: 0)
    static let rgbCyan = Color(red: 0, green: 1, blue: 1)
    static let rgbBlue = Color(red: 0, green: 0, blue: 1)
    static let rgbMagenta = Color(red: 1, green: 0, blue: 1)
    
    static let background = Color(white: 0.96)
    static let border = Color(white: 0.7)
    static let content = Color(white: 0.35)
    static let subContent = Color(white: 0.91)
    static let font = Color(white: 0.05)
    static let knob = white
    static let locked = Color(white: 0.5)
    static let editing = Color(white: 0.88)
    static let translucentEdit = Color(white: 0, alpha: 0.1)
    static let indicated = Color(red: 0.1, green: 0.6, blue: 0.9)
    static let noBorderIndicated = Color(red: 0.67, green: 0.84, blue: 1)
    static let subIndicated = Color(red: 0.6, green: 0.95, blue: 1)
    static let select = Color(red: 0, green: 0.7, blue: 1, alpha: 0.3)
    static let selectBorder = Color(red: 0, green: 0.5, blue: 1, alpha: 0.5)
    static let deselect = Color(red: 0.9, green: 0.3, blue: 0, alpha: 0.3)
    static let deselectBorder = Color(red: 1, green: 0, blue: 0, alpha: 0.5)
    static let selected = Color(red: 0.1, green: 0.7, blue: 1)
    static let subSelected = Color(red: 0.8, green: 0.95, blue: 1)
    static let warning = rgbRed
    
    static let moveZ = Color(red: 1, green: 0, blue: 0)
    
    static let draft = Color(red: 0, green: 0.5, blue: 1, alpha: 0.15)
    static let subDraft = Color(red: 0, green: 0.5, blue: 1, alpha: 0.1)
    static let timelineDraft = Color(red: 1, green: 1, blue: 0.2)
    
    static let previous = Color(red: 1, green: 0, blue: 0, alpha: 0.1)
    static let previousSkin = previous.with(alpha: 1)
    static let subPrevious = Color(red: 1, green: 0.2, blue: 0.2, alpha: 0.025)
    static let subPreviousSkin = subPrevious.with(alpha: 0.08)
    
    static let next = Color(red: 0.2, green: 0.8, blue: 0, alpha: 0.1)
    static let nextSkin = next.with(alpha: 1)
    static let subNext = Color(red: 0.4, green: 1, blue: 0, alpha: 0.025)
    static let subNextSkin = subNext.with(alpha: 0.08)
    
    static let editMaterial = Color(red: 1, green: 0.5, blue: 0, alpha: 0.5)
    static let editMaterialColorOnly = Color(red: 1, green: 0.75, blue: 0, alpha: 0.5)
    
    static let snap = Color(red: 0.5, green: 0, blue: 1)
    static let controlEditPointIn = Color(red: 1, green: 1, blue: 0)
    static let controlPointIn = knob
    static let controlPointCapIn = knob
    static let controlPointJointIn = Color(red: 1, green: 0, blue: 0)
    static let controlPointOtherJointIn = Color(red: 1, green: 0.5, blue: 1)
    static let controlPointUnionIn = Color(red: 0, green: 1, blue: 0.2)
    static let controlPointPathIn = Color(red: 0, green: 1, blue: 1)
    static let controlPointOut = border
    static let editControlPointIn = Color(red: 1, green: 0, blue: 0, alpha: 0.8)
    static let editControlPointOut = Color(red: 1, green: 0.5, blue: 0.5, alpha: 0.3)
    static let contolLineIn = Color(red: 1, green: 0.5, blue: 0.5, alpha: 0.3)
    static let contolLineOut = Color(red: 1, green: 0, blue: 0, alpha: 0.3)
    
    static let camera = Color(red: 0.7, green: 0.6, blue: 0)
    static let cameraBorder = Color(red: 1, green: 0, blue: 0, alpha: 0.5)
    static let cutBorder = Color(red: 0.3, green: 0.46, blue: 0.7, alpha: 0.5)
    static let cutSubBorder = background.multiply(alpha: 0.5)
    
    static let strokeLine = Color(white: 0)
    
    static let playBorder = Color(white: 0.4)
    static let subtitleBorder = Color(white: 0)
    static let subtitleFill = white
    
    var hue: Double {
        didSet {
            rgb = Color.hsvWithHSL(h: hue, s: saturation, l: lightness).rgb
            id = UUID()
        }
    }
    var saturation: Double {
        didSet {
            rgb = Color.hsvWithHSL(h: hue, s: saturation, l: lightness).rgb
            id = UUID()
        }
    }
    var lightness: Double {
        didSet {
            rgb = Color.hsvWithHSL(h: hue, s: saturation, l: lightness).rgb
            id = UUID()
        }
    }
    var sl: CGPoint {
        get {
            return CGPoint(x: saturation, y: lightness)
        }
        set {
            self.saturation = newValue.x.d
            self.lightness = newValue.y.d
        }
    }
    var alpha: Double {
        didSet {
            id = UUID()
        }
    }
    var colorSpace: ColorSpace {
        didSet {
            id = UUID()
        }
    }
    private(set) var rgb: RGB, id: UUID
    
    init(hue: Double = 0, saturation: Double = 0, lightness: Double = 0,
         alpha: Double = 1, colorSpace: ColorSpace = .sRGB) {
        self.hue = hue
        self.saturation = saturation
        self.lightness = lightness
        rgb = Color.hsvWithHSL(h: hue, s: saturation, l: lightness).rgb
        self.alpha = alpha
        self.colorSpace = colorSpace
        id = UUID()
    }
    init(hue: Double, saturation: Double, brightness: Double,
         alpha: Double = 1, colorSpace: ColorSpace = .sRGB) {
        let hsv = HSV(h: hue, s: saturation, v: brightness)
        self.init(hsv: hsv, rgb: hsv.rgb, alpha: alpha, colorSpace: colorSpace)
    }
    init(red: Double, green: Double, blue: Double,
         alpha: Double = 1, colorSpace: ColorSpace = .sRGB) {
        
        let rgb = RGB(r: red, g: green, b: blue)
        self.init(hsv: rgb.hsv, rgb: rgb, alpha: alpha, colorSpace: colorSpace)
    }
    init(rgb: RGB, alpha: Double = 1, colorSpace: ColorSpace = .sRGB) {
        self.init(hsv: rgb.hsv, rgb: rgb, alpha: alpha, colorSpace: colorSpace)
    }
    init(white: Double, alpha: Double = 1, colorSpace: ColorSpace = .sRGB) {
        self.init(hue: 0, saturation: 0, lightness: white, alpha: alpha, colorSpace: colorSpace)
    }
    init(hsv: HSV, rgb: RGB, alpha: Double, colorSpace: ColorSpace = .sRGB) {
        (hue, saturation, lightness) = Color.hsl(with: hsv)
        self.rgb = rgb
        self.alpha = alpha
        self.colorSpace = colorSpace
        id = UUID()
    }
    
    static func random(colorSpace: ColorSpace = .sRGB) -> Color {
        let hue = Double.random(min: 0, max: 1)
        let saturation = Double.random(min: 0.5, max: 1)
        let lightness = Double.random(min: 0.4, max: 0.9)
        return Color(hue: hue, saturation: saturation, lightness: lightness, colorSpace: colorSpace)
    }
    
    func with(hue: Double) -> Color {
        return Color(hue: hue, saturation: saturation, lightness:  lightness, alpha: alpha)
    }
    func with(saturation: Double) -> Color {
        return Color(hue: hue, saturation: saturation, lightness: lightness, alpha: alpha)
    }
    func with(lightness: Double) -> Color {
        return Color(hue: hue, saturation: saturation, lightness: lightness, alpha: alpha)
    }
    func with(saturation: Double, lightness: Double) -> Color {
        return Color(hue: hue, saturation: saturation, lightness: lightness, alpha: alpha)
    }
    func with(alpha: Double) -> Color {
        return Color(hue: hue, saturation: saturation, lightness: lightness, alpha: alpha)
    }
    func withNewID() -> Color {
        return Color(hue: hue, saturation: saturation, lightness: lightness, alpha: alpha)
    }
    
    func multiply(alpha: Double) -> Color {
        return Color(hue: hue, saturation: saturation, lightness: lightness,
                     alpha: self.alpha * alpha)
    }
    func multiply(white: Double) -> Color {
        return Color.linear(self, Color.white, t: white.cf)
    }
    
    private static func hsl(with hsv: HSV) -> (h: Double, s: Double, l: Double) {
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
    private static func hsvWithHSL(h: Double, s: Double, l: Double) -> HSV {
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
    
    static func y(withHue hue: Double) -> Double {
        let hueRGB = HSV(h: hue, s: 1, v: 1).rgb
        return 0.299 * hueRGB.r + 0.587 * hueRGB.g + 0.114 * hueRGB.b
    }
}
extension Color: Equatable {
    static func ==(lhs: Color, rhs: Color) -> Bool {
        return lhs.id == rhs.id
    }
}
extension Color: Hashable {
    var hashValue: Int {
        return id.hashValue
    }
}
extension Color: Referenceable {
    static let name = Localization(english: "Color", japanese: "カラー")
}
extension Color: Interpolatable {
    static func linear(_ f0: Color, _ f1: Color, t: CGFloat) -> Color {
        let rgb = RGB.linear(f0.rgb, f1.rgb, t: t)
        let alpha = CGFloat.linear(f0.alpha.cf, f1.alpha.cf, t: t).d
        let color = Color(rgb: rgb, alpha: alpha)
        return color.saturation > 0 ?
            color :
            color.with(hue: CGFloat.linear(f0.hue.cf,
                                           f1.hue.cf.loopValue(other: f0.hue.cf),
                                           t: t).loopValue().d)
    }
    static func firstMonospline(_ f1: Color, _ f2: Color, _ f3: Color,
                                with ms: Monospline) -> Color {
        let rgb = RGB.firstMonospline(f1.rgb, f2.rgb, f3.rgb, with: ms)
        let alpha = CGFloat.firstMonospline(f1.alpha.cf, f2.alpha.cf, f3.alpha.cf, with: ms).d
        let color = Color(rgb: rgb, alpha: alpha)
        return color.saturation > 0 ?
            color :
            color.with(hue: CGFloat.firstMonospline(f1.hue.cf,
                                                    f2.hue.cf.loopValue(other: f1.hue.cf),
                                                    f3.hue.cf.loopValue(other: f1.hue.cf),
                                                    with: ms).loopValue().d)
    }
    static func monospline(_ f0: Color, _ f1: Color, _ f2: Color, _ f3: Color,
                           with ms: Monospline) -> Color {
        let rgb = RGB.monospline(f0.rgb, f1.rgb, f2.rgb, f3.rgb, with: ms)
        let alpha = CGFloat.monospline(f0.alpha.cf, f1.alpha.cf, f2.alpha.cf, f3.alpha.cf, 
                                       with: ms).d
        let color = Color(rgb: rgb, alpha: alpha)
        return color.saturation > 0 ?
            color :
            color.with(hue: CGFloat.monospline(f0.hue.cf,
                                               f1.hue.cf.loopValue(other: f0.hue.cf),
                                               f2.hue.cf.loopValue(other: f0.hue.cf),
                                               f3.hue.cf.loopValue(other: f0.hue.cf),
                                               with: ms).loopValue().d)
    }
    static func lastMonospline(_ f0: Color, _ f1: Color, _ f2: Color,
                               with ms: Monospline) -> Color {
        let rgb = RGB.lastMonospline(f0.rgb, f1.rgb, f2.rgb, with: ms)
        let alpha = CGFloat.lastMonospline(f0.alpha.cf, f1.alpha.cf, f2.alpha.cf, with: ms).d
        let color = Color(rgb: rgb, alpha: alpha)
        return color.saturation > 0 ?
            color :
            color.with(hue: CGFloat.lastMonospline(f0.hue.cf,
                                                   f1.hue.cf.loopValue(other: f0.hue.cf),
                                                   f2.hue.cf.loopValue(other: f0.hue.cf),
                                                   with: ms).loopValue().d)
    }
}

struct RGB {
    var r = 0.0, g = 0.0, b = 0.0
    
    var hsv: HSV {
        let minValue = min(r, g, b), maxValue = max(r, g, b)
        let d = maxValue - minValue
        let s = maxValue == 0 ? d : d / maxValue, v = maxValue
        let h: Double = {
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
        let r = try container.decode(Double.self)
        let g = try container.decode(Double.self)
        let b = try container.decode(Double.self)
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
    static func linear(_ f0: RGB, _ f1: RGB, t: CGFloat) -> RGB {
        let r = CGFloat.linear(f0.r.cf, f1.r.cf, t: t).d
        let g = CGFloat.linear(f0.g.cf, f1.g.cf, t: t).d
        let b = CGFloat.linear(f0.b.cf, f1.b.cf, t: t).d
        return RGB(r: r, g: g, b: b)
    }
    static func firstMonospline(_ f1: RGB, _ f2: RGB, _ f3: RGB, with ms: Monospline) -> RGB {
        let r = CGFloat.firstMonospline(f1.r.cf, f2.r.cf, f3.r.cf, with: ms).d
        let g = CGFloat.firstMonospline(f1.g.cf, f2.g.cf, f3.g.cf, with: ms).d
        let b = CGFloat.firstMonospline(f1.b.cf, f2.b.cf, f3.b.cf, with: ms).d
        return RGB(r: r, g: g, b: b)
    }
    static func monospline(_ f0: RGB, _ f1: RGB, _ f2: RGB, _ f3: RGB, with ms: Monospline) -> RGB {
        let r = CGFloat.monospline(f0.r.cf, f1.r.cf, f2.r.cf, f3.r.cf, with: ms).d
        let g = CGFloat.monospline(f0.g.cf, f1.g.cf, f2.g.cf, f3.g.cf, with: ms).d
        let b = CGFloat.monospline(f0.b.cf, f1.b.cf, f2.b.cf, f3.b.cf, with: ms).d
        return RGB(r: r, g: g, b: b)
    }
    static func lastMonospline(_ f0: RGB, _ f1: RGB, _ f2: RGB, with ms: Monospline) -> RGB {
        let r = CGFloat.lastMonospline(f0.r.cf, f1.r.cf, f2.r.cf, with: ms).d
        let g = CGFloat.lastMonospline(f0.g.cf, f1.g.cf, f2.g.cf, with: ms).d
        let b = CGFloat.lastMonospline(f0.b.cf, f1.b.cf, f2.b.cf, with: ms).d
        return RGB(r: r, g: g, b: b)
    }
}

struct HSV {
    var h = 0.0, s = 0.0, v = 0.0
    
    var rgb: RGB {
        guard s != 0 else {
            return RGB(r: v, g: v, b: v)
        }
        let h6 = 6 * h
        let hi = Int(h6)
        let nh = h6 - Double(hi)
        switch (hi) {
        case 0:
            return RGB(r: v, g: v * (1 - s * (1 - nh)), b: v * (1 - s))
        case 1:
            return RGB(r: v * (1 - s * nh), g: v, b: v * (1 - s))
        case 2:
            return RGB(r: v * (1 - s), g: v, b: v * (1 - s * (1 - nh)))
        case 3:
            return RGB(r: v * (1 - s), g: v * (1 - s * nh), b: v)
        case 4:
            return RGB(r: v * (1 - s * (1 - nh)), g: v * (1 - s), b: v)
        default:
            return RGB(r: v, g: v * (1 - s), b: v * (1 - s * nh))
        }
    }
}
extension HSV: Codable {
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let h = try container.decode(Double.self)
        let s = try container.decode(Double.self)
        let v = try container.decode(Double.self)
        self.init(h: h, s: s, v: v)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(h)
        try container.encode(s)
        try container.encode(v)
    }
}

enum ColorSpace: Int8, Codable {
    case sRGB, displayP3
    
    var description: String {
        switch self {
        case .sRGB:
            return "sRGB"
        case .displayP3:
            return "Display P3"
        }
    }
    var displayText: Localization {
        return Localization(description)
    }
    static var displayTexts: [Localization] {
        return [sRGB.displayText, displayP3.displayText]
    }
}
extension ColorSpace: Referenceable {
    static let name = Localization(english: "Color space", japanese: "色空間")
}
extension ColorSpace: ObjectViewExpressionWithDisplayText {
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
            self.init(red: Double(components[0]),
                      green: Double(components[1]),
                      blue: Double(components[2]),
                      alpha: Double(components[3]),
                      colorSpace: .sRGB)
        case String(CGColorSpace.displayP3):
            self.init(red: Double(components[0]),
                      green: Double(components[1]),
                      blue: Double(components[2]),
                      alpha: Double(components[3]),
                      colorSpace: .displayP3)
        default:
            self.init()
        }
    }
    
    func with(colorSpace: ColorSpace) -> Color {
        guard
            let cs = CGColorSpace.with(colorSpace),
            let cgColor = self.cgColor.converted(to: cs, intent: .defaultIntent, options: nil),
            let cps = cgColor.components, cgColor.numberOfComponents == 4 else {
                return self
        }
        return Color(red: Double(cps[0]), green: Double(cps[1]), blue: Double(cps[2]),
                     alpha: Double(cps[3]), colorSpace: colorSpace)
    }
    
    var cgColor: CGColor {
        return CGColor.with(rgb: rgb, alpha: alpha, colorSpace: CGColorSpace.with(colorSpace))
    }
}
extension Color: Copiable {
}
extension Color: ObjectViewExpression {
    func thumbnail(withBounds bounds: CGRect, sizeType: SizeType) -> Layer {
        let layer = Layer()
        layer.bounds = bounds
        layer.fillColor = self
        return layer
    }
}

extension CGColor {
    static func with(rgb: RGB, alpha a: Double = 1, colorSpace: CGColorSpace? = nil) -> CGColor {
        let cs = colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let cps = [CGFloat(rgb.r), CGFloat(rgb.g), CGFloat(rgb.b), CGFloat(a)]
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
        case .sRGB:
            return CGColorSpace(name: CGColorSpace.sRGB)
        case .displayP3:
            return CGColorSpace(name: CGColorSpace.displayP3)
        }
    }
}

struct HueCircle {
    var lineWidth: CGFloat, colorSpace: ColorSpace
    var bounds: CGRect {
        didSet {
            radius = min(bounds.width, bounds.height) / 2
        }
    }
    private(set) var radius: CGFloat
    
    init(lineWidth: CGFloat = 2, bounds: CGRect = CGRect(), colorSpace: ColorSpace = .sRGB) {
        self.lineWidth = lineWidth
        self.bounds = bounds
        self.radius = min(bounds.width, bounds.height) / 2
        self.colorSpace = colorSpace
    }
    
    func hue(withAngle angle: Double) -> Double {
        let a = (angle < -.pi + .pi / 6 ? 2 * (.pi) : 0) +  angle - .pi / 6
        return hue(withRevisionHue: (a < 0 ? 1 : 0) + a / (2 * (.pi)))
    }
    func angle(withHue hue: Double) -> Double {
        return revisionHue(withHue: hue) * 2 * (.pi) + .pi / 6
    }
    
    private let split = 1.0 / 12.0, slow = 0.5, fast = 1.5
    private func revisionHue(withHue hue: Double) -> Double {
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
    private func hue(withRevisionHue revisionHue: Double) -> Double {
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
        let splitCount = Int(ceil(2 * (.pi) * outR))
        let inChord = 2 + inR / outR, outChord = 2.0.cf
        let points = [
            CGPoint(x: inR, y: inChord / 2), CGPoint(x: outR, y: outChord / 2),
            CGPoint(x: outR, y: -outChord / 2), CGPoint(x: inR, y: -inChord / 2)
        ]
        ctx.saveGState()
        ctx.translateBy(x: bounds.midX, y: bounds.midY)
        ctx.rotate(by: .pi / 6 - deltaAngle / 2)
        for i in 0 ..< splitCount {
            let color = Color(hue: revisionHue(withHue: Double(i) / Double(splitCount)),
                              saturation: 1,
                              brightness: 1,
                              colorSpace: colorSpace)
            ctx.setFillColor(color.cgColor)
            ctx.addLines(between: points)
            ctx.fillPath()
            ctx.rotate(by: deltaAngle)
        }
        ctx.restoreGState()
    }
}

final class ColorView: View {    
    var color = Color() {
        didSet {
            updateWithColor()
            if color.colorSpace != oldValue.colorSpace {
                updateWithColorSpace()
            }
        }
    }
    
    let hueView: CircularNumberView
    let hueFormLayer = DrawLayer()
    var hueFormLineWidth: CGFloat {
        didSet {
            hueFormCircle.lineWidth = hueFormLineWidth
        }
    }
    var hueFormCircle = HueCircle() {
        didSet {
            hueFormLayer.draw()
        }
    }
    
    let slView = PointView()
    var slFormRatio = 0.82.cf {
        didSet {
            updateLayout()
        }
    }
    let slFormColorLayer: GradientLayer = {
        let layer = GradientLayer()
        layer.gradient = Gradient(colors: [], locations: [],
                                  startPoint: CGPoint(x: 0, y: 0),
                                  endPoint: CGPoint(x: 1, y: 0))
        return layer
    } ()
    let slFormBlackWhiteLayer: GradientLayer = {
        let layer = GradientLayer()
        layer.gradient = Gradient(colors: [Color(white: 0, alpha: 1),
                                           Color(white: 0, alpha: 0),
                                           Color(white: 1, alpha: 0),
                                           Color(white: 1, alpha: 1)],
                                  locations: [],
                                  startPoint: CGPoint(x: 0, y: 0),
                                  endPoint: CGPoint(x: 0, y: 1))
        return layer
    } ()
    
    init(frame: CGRect = CGRect(),
         hLineWidth: CGFloat = 2.5, hWidth: CGFloat = 16.0.cf, slPadding: CGFloat? = nil,
         sizeType: SizeType = .regular) {
        
        hueView = CircularNumberView(width: hWidth)
        
        if let slPadding = slPadding {
            slView.padding = slPadding
        }
        if sizeType == .small {
            slView.formKnob.radius = 4
            hueView.knob.radius = 4
        }
        self.hueFormLineWidth = hLineWidth
        hueView.width = hWidth
        
        super.init()
        hueFormLayer.fillColor = nil
        hueFormLayer.lineColor = nil
        hueFormLayer.drawBlock = { [unowned self] ctx in
            self.hueFormCircle.draw(in: ctx)
        }
        hueView.backgroundLayers = [hueFormLayer]
        slView.formBackgroundLayers = [slFormColorLayer, slFormBlackWhiteLayer]
        replace(children: [hueView, slView])
        self.frame = frame
        
        hueView.binding = { [unowned self] in self.setColor(with: $0) }
        slView.binding = { [unowned self] in self.setColor(with: $0) }
    }
    
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    private func updateLayout() {
        guard !bounds.isEmpty else {
            return
        }
        let padding = Layout.smallPadding
        let r = floor(min(bounds.size.width, bounds.size.height) / 2) - padding
        hueView.frame = CGRect(x: padding, y: padding, width: r * 2, height: r * 2)
        let sr = r - hueView.width
        let b2 = floor(sr * slFormRatio)
        let a2 = floor(sqrt(sr * sr - b2 * b2))
        slView.frame = CGRect(x: bounds.size.width / 2 - a2,
                              y: bounds.size.height / 2 - b2,
                              width: a2 * 2,
                              height: b2 * 2)
        let slInFrame = slView.bounds.inset(by: slView.padding)
        slFormColorLayer.frame = slInFrame
        slFormBlackWhiteLayer.frame = slInFrame
        
        hueFormLayer.frame = hueView.bounds.inset(by: ceil((hueView.width - hueFormLineWidth) / 2))
        hueFormCircle = HueCircle(lineWidth: hueFormLineWidth,
                                  bounds: hueFormLayer.bounds,
                                  colorSpace: color.colorSpace)
        updateWithColor()
    }
    private func updateWithColor() {
        let y = Color.y(withHue: color.hue)
        slFormColorLayer.gradient?.colors = [Color(hue: color.hue, saturation: 0, brightness: y),
                                             Color(hue: color.hue, saturation: 1, brightness: 1)]
        slFormBlackWhiteLayer.gradient?.locations = [0, y, y, 1]
        hueView.number = hueFormCircle.angle(withHue: color.hue).cf
        slView.point = CGPoint(x: color.saturation, y: color.lightness)
    }
    private func updateWithColorSpace() {
        let colors = [Color(white: 0, alpha: 1, colorSpace: color.colorSpace),
                      Color(white: 0, alpha: 0, colorSpace: color.colorSpace),
                      Color(white: 1, alpha: 0, colorSpace: color.colorSpace),
                      Color(white: 1, alpha: 1, colorSpace: color.colorSpace)]
        slFormBlackWhiteLayer.gradient?.colors = colors
        hueFormCircle = HueCircle(lineWidth: hueFormLineWidth,
                                  bounds: hueFormLayer.bounds,
                                  colorSpace: color.colorSpace)
    }
    
    struct Binding {
        let colorView: ColorView, color: Color, oldColor: Color, type: Action.SendType
    }
    var setColorClosure: ((Binding) -> ())?
    
    var disabledRegisterUndo = false
    
    func copiedObjects(with event: KeyInputEvent) -> [ViewExpression]? {
        return [color]
    }
    func paste(_ objects: [Any], with event: KeyInputEvent) -> Bool {
        for object in objects {
            if let color = object as? Color {
                if color != self.color {
                    set(color, old: self.color)
                    return true
                }
            }
        }
        return false
    }
    func delete(with event: KeyInputEvent) -> Bool {
        let color = Color(), oldColor = self.color
        guard color != oldColor else {
            return false
        }
        setColorClosure?(Binding(colorView: self,
                                 color: oldColor, oldColor: oldColor, type: .begin))
        set(color, old: oldColor)
        setColorClosure?(Binding(colorView: self,
                                 color: color, oldColor: oldColor, type: .end))
        return true
    }
    
    private var oldColor = Color()
    private func setColor(with obj: PointView.Binding) {
        if obj.type == .begin {
            oldColor = color
            setColorClosure?(Binding(colorView: self,
                                     color: oldColor, oldColor: oldColor, type: .begin))
        } else {
            color.sl = obj.point
            setColorClosure?(Binding(colorView: self,
                                     color: color, oldColor: oldColor, type: obj.type))
        }
    }
    
    private func setColor(with obj: CircularNumberView.Binding) {
        if obj.type == .begin {
            oldColor = color
            setColorClosure?(Binding(colorView: self,
                                     color: oldColor, oldColor: oldColor, type: .begin))
        } else {
            color.hue = hueFormCircle.hue(withAngle: obj.number.d)
            setColorClosure?(Binding(colorView: self,
                                     color: color, oldColor: oldColor, type: obj.type))
        }
    }
    
    private func set(_ color: Color, old oldColor: Color) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldColor, old: color) }
        setColorClosure?(Binding(colorView: self,
                                 color: oldColor, oldColor: oldColor, type: .begin))
        self.color = color
        setColorClosure?(Binding(colorView: self,
                                 color: color, oldColor: oldColor, type: .end))
    }
    
    func reference(with event: TapEvent) -> Reference? {
        var reference = color.reference
        reference.viewDescription = Localization(english: "Ring: Hue, Width: Saturation, Height: Luminance",
                                                 japanese: "輪: 色相, 横: 彩度, 縦: 輝度")
        return reference
    }
}
