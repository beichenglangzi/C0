/*
 Copyright 2018 S
 
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

import func CoreGraphics.sqrt

enum StrokableType {
    case normal, sub, fillLine, erase
}
final class StrokableUserObject<Binder: BinderProtocol>: Strokable {
    var rootView: View & Zoomable
    var drawingView: DrawingView<Binder>
    var surfaceView: SurfaceView<Binder>?
    var lineView: LineView<Binder>?
    var fillLineColor: UU<Color>
    
    func convertToCurrentLocal(_ point: Point) -> Point {
        return drawingView.convertFromRoot(point)
    }
    var viewScale: Real {
        return rootView.zoomingTransform.scale.x
    }
    
    init(rootView: View & Zoomable, drawingView: DrawingView<Binder>, fillLineColor: UU<Color>) {
        self.rootView = rootView
        self.drawingView = drawingView
        self.fillLineColor = fillLineColor
    }
    
    var line: Line?
    var lineWidth = 1.0.cg, lineColor = Color.content
    
    struct Temp {
        var control: Line.Control, speed: Real
    }
    var temps = [Temp]()
    var oldPoint = Point(), tempDistance = 0.0.cg, oldLastBounds = Rect.null
    var beginTime = Real(0.0), oldTime = Real(0.0), oldTempTime = Real(0.0)
    
    var join = Join()
    
    struct Join {
        var lowAngle = 0.8.cg * (.pi / 2), angle = 1.5.cg * (.pi / 2)
        
        func joinControlWith(_ line: Line, lastControl lc: Line.Control) -> Line.Control? {
            guard line.controls.count >= 4 else {
                return nil
            }
            let c0 = line.controls[line.controls.count - 4]
            let c1 = line.controls[line.controls.count - 3], c2 = lc
            guard c0.point != c1.point && c1.point != c2.point else {
                return nil
            }
            let dr = abs(Point.differenceAngle(p0: c0.point, p1: c1.point, p2: c2.point))
            if dr > angle {
                return c1
            } else if dr > lowAngle {
                let t = 1 - (dr - lowAngle) / (angle - lowAngle)
                return Line.Control(point: Point.linear(c1.point, c2.point, t: t),
                                    pressure: Real.linear(c1.pressure, c2.pressure, t: t))
            } else {
                return nil
            }
        }
    }
    
    var interval = Interval()
    
    struct Interval {
        var minSpeed = 100.0.cg, maxSpeed = 600.0.cg, exp = 2.0.cg
        var minTime = Real(0.08), maxTime = Real(0.03)
        var minDistance = 1.1.cg, maxDistance = 1.25.cg
        
        func speedTWith(distance: Real, deltaTime: Real, scale: Real) -> Real {
            let speed = ((distance / scale) / deltaTime).clip(min: minSpeed, max: maxSpeed)
            return ((speed - minSpeed) / (maxSpeed - minSpeed)) ** (1 / exp)
        }
        func isAppendPointWith(distance: Real, deltaTime: Real,
                               _ temps: [Temp], scale: Real) -> Bool {
            guard deltaTime > 0 else {
                return false
            }
            let t = speedTWith(distance: distance, deltaTime: deltaTime, scale: scale)
            let time = minTime + (maxTime - minTime) * t
            return deltaTime > time || isAppendPointWith(temps, scale: scale)
        }
        private func isAppendPointWith(_ temps: [Temp], scale: Real) -> Bool {
            let ap = temps.first!.control.point, bp = temps.last!.control.point
            for tc in temps {
                let speed = tc.speed.clip(min: minSpeed, max: maxSpeed)
                let t = ((speed - minSpeed) / (maxSpeed - minSpeed)) ** (1 / exp)
                let maxD = minDistance + (maxDistance - minDistance) * t
                if tc.control.point.distanceWithLine(ap: ap, bp: bp) > maxD / scale {
                    return true
                }
            }
            return false
        }
    }
    
    var cap = Cap()
    
    struct Cap {
        var minTime = 0.025.cg, minDistance = 2.0.cg
        func isJoinedCapWith(_ line: Line,
                             index0: Int, index1: Int,
                             time: Real, oldTime: Real, scale: Real) -> Bool {
            let deltaTime = time - oldTime
            let p0 = line.controls[line.controls.count - 3].point
            let p1 = line.controls[line.controls.count - 2].point
            let d = p0.distance(p1)
            return deltaTime < minTime && d / scale < minDistance
        }
    }
    
    var short = Short()
    
    struct Short {
        var minTime = Real(0.1), linearMaxDistance = 1.2.cg
        
        func shortedLineWith(_ line: Line, deltaTime: Real, scale: Real) -> Line {
            guard deltaTime < minTime && line.controls.count > 3 else {
                return line
            }
            
            var maxD = 0.0.cg, maxControl = line.controls[0]
            line.controls.forEach { control in
                let d = control.point.distanceWithLine(ap: line.firstPoint, bp: line.lastPoint)
                if d > maxD {
                    maxD = d
                    maxControl = control
                }
            }
            let mcp = maxControl.point.nearestWithLine(ap: line.firstPoint, bp: line.lastPoint)
            let cp = 2 * maxControl.point - mcp
            let b = Bezier2(p0: line.firstPoint, cp: cp, p1: line.lastPoint)
            
            let linearMaxDistance = self.linearMaxDistance / scale
            var isShorted = true
            for p in line.mainPointSequence {
                let nd = sqrt(b.minDistance²(at: p))
                if nd > linearMaxDistance {
                    isShorted = false
                }
            }
            return isShorted ?
                line :
                Line(controls: [line.controls[0],
                                Line.Control(point: cp, pressure: maxControl.pressure),
                                line.controls[line.controls.count - 1]])
        }
    }
    
    func stroke(with eventValue: DragEvent.Value, _ phase: Phase,
                strokableType: StrokableType, _ version: Version) {
        if strokableType == .fillLine {
            lassoFillLine(with: eventValue, phase, version)
        } else if strokableType == .erase {
            lassoErase(with: eventValue, phase, version)
        } else {
            let p = rootView.convertFromRoot(eventValue.rootLocation)
            stroke(for: p, pressure: eventValue.pressure, time: eventValue.time, phase,
                   strokeType: strokableType, to: version)
        }
    }
    func stroke(for point: Point, pressure: Real, time: Real, _ phase: Phase,
                strokeType: StrokableType,
                isAppendLine: Bool = true, to version: Version? = nil) {
        let p = convertToCurrentLocal(point)
        switch phase {
        case .began:
            let fc = Line.Control(point: p, pressure: pressure)
            var line = Line(controls: [fc, fc, fc])
            self.line = line
            oldPoint = p
            oldTime = time
            oldTempTime = time
            tempDistance = 0
            temps = [Temp(control: fc, speed: 0)]
            beginTime = time
            if isAppendLine, let version = version {
                switch strokeType {
                case .normal:
                    drawingView.linesView.insert(line, at: drawingView.linesView.model.count, version)
                    lineView = drawingView.linesView.elementViews.last
                case .sub:
                    line.uuColor = UU(Color.subLine, id: .one)
                    self.line = line
                    drawingView.linesView.insert(line, at: 0, version)
                    lineView = drawingView.linesView.elementViews.first
                default:
                    break
                }
            }
        case .changed:
            guard var line = line, p != oldPoint else { return }
            let d = p.distance(oldPoint)
            tempDistance += d
            
            let pressure = (temps.first!.control.pressure + pressure) / 2
            let rc = Line.Control(point: line.controls[line.controls.count - 3].point,
                                  pressure: pressure)
            line.controls[line.controls.count - 3] = rc
            
            let speed = d / (time - oldTime)
            temps.append(Temp(control: Line.Control(point: p, pressure: pressure), speed: speed))
//            let lPressure = temps.reduce(0.0.cg) { $0 + $1.control.pressure } / Real(temps.count)
            let lPressure = temps.reduce(0.0.cg) { max($0, $1.control.pressure) }
            let lc = Line.Control(point: p, pressure: lPressure)
            
            let mlc = lc.mid(temps[temps.count - 2].control)
            if let jc = join.joinControlWith(line, lastControl: mlc) {
                line.controls.insert(jc, at: line.controls.count - 2)
                temps = [Temp(control: lc, speed: speed)]
                oldTempTime = time
                tempDistance = 0
            } else if interval.isAppendPointWith(distance: tempDistance,
                                                 deltaTime: time - oldTempTime,
                                                 temps,
                                                 scale: viewScale) {
                line.controls.insert(lc, at: line.controls.count - 2)
//                if line.controls.count <= 4 && cap.isJoinedCapWith(line,
//                                                                  index0: 1, index1: 0,
//                                                                  time: time, oldTime: oldTempTime,
//                                                                  scale: viewScale) {
//                    line.controls.removeFirst()
//                }
                temps = [Temp(control: lc, speed: speed)]
                oldTempTime = time
                tempDistance = 0
            }
            
            line.controls[line.controls.count - 2] = lc
            line.controls[line.controls.count - 1] = lc
            self.line = line
            lineView?.model = line
            oldTime = time
            oldPoint = p
        case .ended:
            guard var line = line else { return }
            
            if cap.isJoinedCapWith(line,
                                   index0: line.controls.count - 3, index1: line.controls.count - 2,
                                   time: time, oldTime: oldTempTime,
                                   scale:  viewScale) {
                line.controls.removeLast()
                line.controls.removeLast()
            }
            self.line = line
            lineView?.model = line
        }
    }
    
    var oldLassoFillLineViews = [Int: (lineView: LineView<Binder>, uuColor: UU<Color>)]()
    func lassoFillLine(with eventValue: DragEvent.Value,
                       _ phase: Phase, _ version: Version) {
        let p = rootView.convertFromRoot(eventValue.rootLocation)
        stroke(for: p, pressure: eventValue.pressure, time: eventValue.time, phase,
               strokeType: .normal, isAppendLine: false, to: version)
        switch phase {
        case .began:
            oldLassoFillLineViews = [:]
            drawingView.lassoPathViewColor = .selected
            drawingView.lassoPathViewFillColorComposition = .select
            drawingView.lassoLine = line
        case .changed:
            drawingView.lassoLine = line
            if let line = line {
                updateFillLineViews(with: line)
            }
        case .ended:
            if let line = line {
                updateFillLineViews(with: line)
            }
            oldLassoFillLineViews.values.forEach { (lineView, uuColor) in
                lineView.capture(uuColor: uuColor, to: version)
            }
            drawingView.lassoLine = nil
            oldLassoFillLineViews = [:]
        }
    }
    func updateFillLineViews(with line: Line) {
        for (i, drawingLine) in drawingView.model.lines.enumerated() {
            if LassoSurface(line: line).intersects(drawingLine) {
                if oldLassoFillLineViews[i] == nil {
                    let lineView = drawingView.linesView.elementViews[i]
                    let oldUUColor = lineView.uuColor
                    lineView.uuColor = fillLineColor
                    oldLassoFillLineViews[i] = (lineView, oldUUColor)
                }
            } else {
                if let (lineView, uuColor) = oldLassoFillLineViews[i] {
                    lineView.uuColor = uuColor
                    oldLassoFillLineViews[i] = nil
                }
            }
        }
    }
    
    func lassoErase(with eventValue: DragEvent.Value,
                    _ phase: Phase, _ version: Version) {
        let p = rootView.convertFromRoot(eventValue.rootLocation)
        stroke(for: p, pressure: eventValue.pressure, time: eventValue.time, phase,
               strokeType: .normal, isAppendLine: false, to: version)
        switch phase {
        case .began:
            break
        case .changed:
            drawingView.lassoPathViewColor = .warning
            drawingView.lassoPathViewFillColorComposition = .anti
            drawingView.lassoLine = line
        case .ended:
            drawingView.lassoLine = nil
            if let line = line {
                lassoErase(with: line, to: version)
            }
        }
    }
    func lassoErase(with line: Line, to version: Version) {

        let lasso = LassoSurface(line: line)
        let slt = lasso.splitedLinesTuple(with: drawingView.linesView.model)
        if !slt.removedIndexes.isEmpty {
            var di = 0
            for i in slt.removedIndexes {
                drawingView.linesView.remove(at: i + di, version)
                di -= 1
            }
//            drawingView.linesView.remove(at: slt.removedIndexes, version)
        }
        if !slt.splitedLines.isEmpty {
            for line in slt.splitedLines {
                drawingView.linesView.append(line, version)
            }
//            drawingView.linesView.append(slt.splitedLines, version)
        }
    }
}
