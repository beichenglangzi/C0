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
    var line: Line {
        didSet {
            path = Surface.path(with: line)
        }
    }
    var uuColor: UU<Color>
    private(set) var path: Path
    
    private static func path(with line: Line) -> Path {
        guard let elementsTuple = line.bezierCurveElementsTuple else {
            return Path()
        }
        var path = Path()
        path.append(PathLine(firstPoint: elementsTuple.firstPoint,
                             elements: elementsTuple.elements))
        return path
    }
    
    init(line: Line, uuColor: UU<Color> = UU(.surface, id: .zero)) {
        self.line = line
        self.uuColor = uuColor
        path = Surface.path(with: line)
    }
}
extension Surface: AppliableAffineTransform {
    static func *(lhs: Surface, rhs: AffineTransform) -> Surface {
        return Surface(line: lhs.line * rhs )
    }
}
extension Surface: Equatable {
    static func == (lhs: Surface, rhs: Surface) -> Bool {
        return lhs.line == rhs.line
    }
}
extension Surface: Interpolatable {
    static func linear(_ f0: Surface, _ f1: Surface, t: Real) -> Surface {
        let line = Line.linear(f0.line, f1.line, t: t)
        let color = Color.linear(f0.uuColor.value, f1.uuColor.value, t: t)
        return Surface(line: line, uuColor: UU(color))
    }
    static func firstMonospline(_ f1: Surface, _ f2: Surface, _ f3: Surface,
                                with ms: Monospline) -> Surface {
        let line = Line.firstMonospline(f1.line, f2.line, f3.line, with: ms)
        let color = Color.firstMonospline(f1.uuColor.value, f2.uuColor.value,
                                          f3.uuColor.value, with: ms)
        return Surface(line: line, uuColor: UU(color))
    }
    static func monospline(_ f0: Surface, _ f1: Surface, _ f2: Surface, _ f3: Surface,
                           with ms: Monospline) -> Surface {
        let line = Line.monospline(f0.line, f1.line, f2.line, f3.line, with: ms)
        let color = Color.monospline(f0.uuColor.value, f1.uuColor.value,
                                     f2.uuColor.value, f3.uuColor.value, with: ms)
        return Surface(line: line, uuColor: UU(color))
    }
    static func lastMonospline(_ f0: Surface, _ f1: Surface, _ f2: Surface,
                               with ms: Monospline) -> Surface {
        let line = Line.lastMonospline(f0.line, f1.line, f2.line, with: ms)
        let color = Color.lastMonospline(f0.uuColor.value, f1.uuColor.value,
                                         f2.uuColor.value, with: ms)
        return Surface(line: line, uuColor: UU(color))
    }
}
extension Surface: Codable {
    private enum CodingKeys: String, CodingKey {
        case line, uuColor
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        line = try values.decode(Line.self, forKey: .line)
        uuColor = try values.decode(UU<Color>.self, forKey: .uuColor)
        path = Surface.path(with: line)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(line, forKey: .line)
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

struct SurfaceLasso {
    let surface: Surface
    
    enum Splited {
        struct Index {
            let startIndex: Int, startT: Real, endIndex: Int, endT: Real
        }
        
        case around, splited([Index])
    }
    func splited(with otherLine: Line) -> Splited? {
        func intersectsLineImageBounds(_ otherLine: Line) -> Bool {
            return otherLine.imageBounds.intersects(surface.line.imageBounds)
        }
        guard !otherLine.isEmpty && intersectsLineImageBounds(otherLine) else {
            return nil
        }
        
        var newSplitedIndexes = [Splited.Index](), oldIndex = 0, oldT = 0.0.cg
        var isSplitLine = false, leftIndex = 0
        let firstPointInPath = surface.path.contains(otherLine.firstPoint)
        let lastPointInPath = surface.path.contains(otherLine.lastPoint)
        for (i0, b0) in otherLine.bezierSequence.enumerated() {
            var bis = [BezierIntersection]()
            let lp = surface.line.lastPoint, fp = surface.line.firstPoint
            if lp != fp {
                bis += b0.intersections(Bezier2.linear(lp, fp))
            }
            for b1 in surface.line.bezierSequence {
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
            return SplitedLine.splited(SurfaceLasso.splitedLines(with: otherLine, indexes))
        }
    }
    static func splitedLines(with otherLine: Line, _ splitedIndexes: [Splited.Index]) -> [Line] {
        return splitedIndexes.reduce(into: [Line]()) { (lines, si) in
            lines += otherLine.splited(startIndex: si.startIndex, startT: si.startT,
                                       endIndex: si.endIndex, endT: si.endT)
        }
    }
}
extension Surface {
    func intersects(_ lasso: SurfaceLasso) -> Bool {
        guard !line.imageBounds.intersects(lasso.surface.line.imageBounds) else {
            return false
        }
        if lasso.surface.line.intersects(line) {
            return true
        }
        if lasso.surface.path.contains(line.firstPoint)
            || lasso.surface.path.contains(line.lastPoint) {
            
            return true
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
    
    let lineView: LineView<Binder>
    
    init(binder: T, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        
        lineView = LineView(binder: binder, keyPath: keyPath.appending(path: \Model.line))
        
        super.init(path: Path(), isLocked: false)
        fillColor = binder[keyPath: keyPath].uuColor.value
        lineView.notifications.append { [unowned self] (_, _) in self.updatePath() }
        updateWithModel()
    }

    var minSize: Size {
        return model.line.imageBounds.size
    }
    func updateWithModel() {
        lineView.updateWithModel()
        updateColor()
        updatePath()
    }
    func updateColor() {
        fillColor = model.uuColor.value
    }
    func updatePath() {
        path = model.path
    }
}
extension SurfaceView: ChangeableColorOwner {
    func captureUUColor(to version: Version) {
        capture(uuColor: model.uuColor, to: version)
    }
    func capture(uuColor: UU<Color>, to version: Version) {
        version.registerUndo(withTarget: self) { [oldUUColor = model.uuColor] in
            $0.capture(uuColor: oldUUColor, to: version)
        }
        binder[keyPath: keyPath].uuColor = uuColor
        updateColor()
    }
    var uuColor: UU<Color> {
        get {
            return model.uuColor
        }
        set {
            model.uuColor = newValue
            updateColor()
        }
    }
}
