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

struct Surface {
    var points: [Point] {
        didSet {
            self.path = Surface.path(with: points)
        }
    }
    var uuColor: UU<Color>
    static func path(with points: [Point]) -> Path {
        var path = Path()
        path.append(PathLine(points: points))
        return path
    }
    private(set) var path: Path
    
    init(points: [Point], uuColor: UU<Color>) {
        self.points = points
        self.uuColor = uuColor
        path = Surface.path(with: points)
    }
}
extension Surface: AppliableAffineTransform {
    static func *(lhs: Surface, rhs: AffineTransform) -> Surface {
        return Surface(points: lhs.points.map { $0 * rhs }, uuColor: lhs.uuColor)
    }
}
extension Surface: Equatable {
    static func == (lhs: Surface, rhs: Surface) -> Bool {
        return lhs.points == rhs.points
    }
}
extension Surface: Codable {
    private enum CodingKeys: String, CodingKey {
        case line, points, uuColor
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        if let line = (try? values.decode(Line.self, forKey: .line)) {
            points = line.controls.map { $0.point }
        } else {
            points = (try? values.decode([Point].self, forKey: .points)) ?? []
        }
        uuColor = try values.decode(UU<Color>.self, forKey: .uuColor)
        path = Surface.path(with: points)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(points, forKey: .points)
        try container.encode(uuColor, forKey: .uuColor)
    }
}
extension Surface: Viewable {
    func viewWith<T: BinderProtocol>
        (binder: T, keyPath: ReferenceWritableKeyPath<T, Surface>) -> ModelView {
        
        return SurfaceView(binder: binder, keyPath: keyPath)
    }
}
extension Surface: ObjectViewable {}

struct LassoSurface {
    var line: Line {
        didSet {
            path = line.fillPath()
        }
    }
    var uuColor: UU<Color>
    static func path(with points: [Point]) -> Path {
        var path = Path()
        path.append(PathLine(points: points))
        return path
    }
    private(set) var path: Path

    init(line: Line, uuColor: UU<Color> = .surface) {
        self.line = line
        self.uuColor = uuColor
        path = line.fillPath()
    }
}
extension LassoSurface {
    var imageBounds: Rect {
        return line.imageBounds
    }
}
extension LassoSurface: AppliableAffineTransform {
    static func *(lhs: LassoSurface, rhs: AffineTransform) -> LassoSurface {
        return LassoSurface(line: lhs.line * rhs)
    }
}
extension LassoSurface: Equatable {
    static func == (lhs: LassoSurface, rhs: LassoSurface) -> Bool {
        return lhs.line == rhs.line
    }
}
extension LassoSurface {
    enum Splited {
        struct Index {
            let startIndex: Int, startT: Real, endIndex: Int, endT: Real
        }

        case around, splited([Index])
    }
    func splited(with otherLine: Line) -> Splited? {
        func intersectsLineImageBounds(_ otherLine: Line) -> Bool {
            return otherLine.imageBounds.intersects(line.imageBounds)
        }
        guard !otherLine.isEmpty && intersectsLineImageBounds(otherLine) else {
            return nil
        }

        var newSplitedIndexes = [Splited.Index](), oldIndex = 0, oldT = 0.0.cg
        var isSplitLine = false, leftIndex = 0
        let firstPointInPath = path.contains(otherLine.firstPoint)
        let lastPointInPath = path.contains(otherLine.lastPoint)
        for (i0, b0) in otherLine.bezierSequence.enumerated() {
            var bis = [BezierIntersection]()
            let lp = line.lastPoint, fp = line.firstPoint
            if lp != fp {
                bis += b0.intersections(Bezier2.linear(lp, fp))
            }
            for b1 in line.bezierSequence {
                bis += b0.intersections(b1)
            }
            guard !bis.isEmpty else { continue }

            let sbis = bis.sorted { $0.t < $1.t }
            for bi in sbis {
                let newLeftIndex = leftIndex + (bi.isLeft ? 1 : -1)
                if firstPointInPath {
                    if leftIndex != 0 && newLeftIndex == 0 {
                        newSplitedIndexes.append(Splited.Index(startIndex: oldIndex, startT: oldT,
                                                               endIndex: i0, endT: bi.t))
                    } else if leftIndex == 0 && newLeftIndex != 0 {
                        oldIndex = i0
                        oldT = bi.t
                    }
                } else {
                    if leftIndex != 0 && newLeftIndex == 0 {
                        oldIndex = i0
                        oldT = bi.t
                    } else if leftIndex == 0 && newLeftIndex != 0 {
                        newSplitedIndexes.append(Splited.Index(startIndex: oldIndex, startT: oldT,
                                                               endIndex: i0, endT: bi.t))
                    }
                }
                leftIndex = newLeftIndex
            }
            isSplitLine = true
        }
        if isSplitLine && !lastPointInPath {
            let endIndex = otherLine.controls.count <= 2 ? 0 : otherLine.controls.count - 3
            newSplitedIndexes.append(Splited.Index(startIndex: oldIndex, startT: oldT,
                                                   endIndex: endIndex, endT: 1))
        }
        if !newSplitedIndexes.isEmpty {
            return Splited.splited(newSplitedIndexes)
        } else if !isSplitLine && firstPointInPath && lastPointInPath {
            return Splited.around
        } else {
            return nil
        }
    }

    enum SplitedLine {
        case around(Line), splited([Line])
    }
    func splitedLine(with otherLine: Line) -> SplitedLine? {
        guard let splited = self.splited(with: otherLine) else {
            return nil
        }
        switch splited {
        case .around: return SplitedLine.around(otherLine)
        case .splited(let indexes):
            return SplitedLine.splited(LassoSurface.splitedLines(with: otherLine, indexes))
        }
    }
    static func splitedLines(with otherLine: Line, _ splitedIndexes: [Splited.Index]) -> [Line] {
        return splitedIndexes.reduce(into: [Line]()) { (lines, si) in
            lines += otherLine.splited(startIndex: si.startIndex, startT: si.startT,
                                       endIndex: si.endIndex, endT: si.endT)
        }
    }
}
extension LassoSurface {
    func contains(_ p: Point) -> Bool {
        return path.contains(p)
    }
    func intersects(_ lasso: LassoSurface) -> Bool {
        guard !line.imageBounds.intersects(lasso.line.imageBounds) else {
            return false
        }
        if lasso.line.intersects(line) {
            return true
        }
        if lasso.path.contains(line.firstPoint)
            || lasso.path.contains(line.lastPoint) {

            return true
        }
        return false
    }
    func intersects(_ otherLine: Line) -> Bool {
        guard imageBounds.intersects(otherLine.imageBounds) else {
            return false
        }
        if line.intersects(otherLine) {
            return true
        }
        for p in otherLine.mainPointSequence {
            if contains(p) {
                return true
            }
        }
        return false
    }
}

final class SurfaceView<T: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = Surface
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((SurfaceView<Binder>, BasicNotification) -> ())]()

    init(binder: T, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath

        super.init(path: Path(), isLocked: false)
        fillColor = binder[keyPath: keyPath].uuColor.value
        updateWithModel()
    }

    var minSize: Size {
        return model.path.boundingBoxOfPath.size
    }
    func updateWithModel() {
        updateColor()
        updatePath()
    }
    func updateColor() {
        fillColor = model.uuColor.value
    }
    func updatePath() {
        self.path = model.path
    }
}
extension SurfaceView: ChangeableColorOwner {
    func captureUUColor(to version: Version) {
        capture(uuColor: model.uuColor, to: version)
    }

    func push(uuColor: UU<Color>, to version: Version) {
        version.registerUndo(withTarget: self) { [oldUUColor = model.uuColor, unowned version] in
            $0.push(uuColor: oldUUColor, to: version)
        }
        binder[keyPath: keyPath].uuColor = uuColor
        updateColor()
    }
    func capture(uuColor: UU<Color>, to version: Version) {
        version.registerUndo(withTarget: self) { [oldUUColor = model.uuColor, unowned version] in
            $0.push(uuColor: oldUUColor, to: version)
        }
    }
    var uuColor: UU<Color> {
        get { return model.uuColor }
        set {
            model.uuColor = newValue
            updateColor()
        }
    }
}
extension SurfaceView: Assignable {
    var copiableObject: Object {
        return Object(model.uuColor)
    }
    func paste(_ object: Object,
               with eventValue: InputEvent.Value, _ phase: Phase, _ version: Version) {
        if let uuColor = object.value as? UU<Color> {
            push(uuColor: uuColor, to: version)
        }
    }
}
