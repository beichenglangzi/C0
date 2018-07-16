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

final class StrokableObject {
    var strokableView: View & Strokable
    
    init(strokableView: View & Strokable) {
        self.strokableView = strokableView
    }
    
    var line: Line?
    var lineWidth = 1.0.cg, lineColor = Color.black
    
    struct Temp {
        var point: Point, speed: Real
    }
    var temps = [Temp]()
    var oldPoint = Point(), tempDistance = 0.0.cg, oldLastBounds = Rect.null
    var beginTime = 0.0.cg, oldTime = 0.0.cg, oldTempTime = 0.0.cg
    
    var join = Join()
    
    struct Join {
        var lowAngle = 0.8.cg * (.pi / 2), angle = 1.5.cg * (.pi / 2)
        
        func joinControlWith(_ line: Line, lastControl lc: Point) -> Point? {
            guard line.points.count >= 4 else {
                return nil
            }
            let p0 = line.points[line.points.count - 4]
            let p1 = line.points[line.points.count - 3], p2 = lc
            guard p0 != p1 && p1 != p2 else {
                return nil
            }
            let dr = abs(Point.differenceAngle(p0: p0, p1: p1, p2: p2))
            if dr > angle {
                return p1
            } else if dr > lowAngle {
                let t = 1 - (dr - lowAngle) / (angle - lowAngle)
                return Point.linear(p1, p2, t: t)
            } else {
                return nil
            }
        }
    }
    
    var interval = Interval()
    
    struct Interval {
        var minSpeed = 100.0.cg, maxSpeed = 1500.0.cg, exp = 2.0.cg
        var minTime = 0.1.cg, maxTime = 0.03.cg
        var minDistance = 1.45.cg, maxDistance = 1.5.cg
        
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
            let ap = temps.first!.point, bp = temps.last!.point
            for temp in temps {
                let speed = temp.speed.clip(min: minSpeed, max: maxSpeed)
                let t = ((speed - minSpeed) / (maxSpeed - minSpeed)) ** (1 / exp)
                let maxD = minDistance + (maxDistance - minDistance) * t
                if temp.point.distanceWithLine(ap: ap, bp: bp) > maxD / scale {
                    return true
                }
            }
            return false
        }
    }
    
    var short = Short()
    
    struct Short {
        var minTime = 0.1.cg, linearMaxDistance = 1.5.cg
        
        func shortedLineWith(_ line: Line, deltaTime: Real, scale: Real) -> Line {
            guard deltaTime < minTime && line.points.count > 3 else {
                return line
            }
            
            var maxD = 0.0.cg, maxPoint = line.points[0]
            line.points.forEach { point in
                let d = point.distanceWithLine(ap: line.firstPoint, bp: line.lastPoint)
                if d > maxD {
                    maxD = d
                    maxPoint = point
                }
            }
            let mcp = maxPoint.nearestWithLine(ap: line.firstPoint, bp: line.lastPoint)
            let cp = 2 * maxPoint - mcp
            let b = Bezier2(p0: line.firstPoint, cp: cp, p1: line.lastPoint)
            
            let linearMaxDistance = self.linearMaxDistance / scale
            var isShorted = true
            for p in line.points {
                let nd = sqrt(b.minDistance²(at: p))
                if nd > linearMaxDistance {
                    isShorted = false
                }
            }
            return isShorted ?
                line :
                Line(points: [line.points[0],
                              cp,
                              line.points[line.points.count - 1]])
        }
    }
    
    var tempPoints = [Point]()
    var minDistance = 2.0.cg, oldP = Point()
    func stroke(with eventValue: DragEvent.Value, _ phase: Phase, _ version: Version) {
        
    }
    func stroke(for point: Point, pressure: Real, time: Real, _ phase: Phase,
                isAppendLine: Bool = true, to version: Version? = nil) {
        let ap = strokableView.convertToCurrentLocal(point)
        switch phase {
        case .began:
            let line = Line(beziers: [Bezier2(p0: ap, cp: ap, p1: ap)])
            self.line = line
            oldP = ap
            tempPoints = [ap]
            if isAppendLine, let version = version {
                strokableView.insert(line, to: version)
            }
        case .changed, .ended:
            guard var line = line else { return }
            let p = ap.mid(oldP)
            oldP = p
            tempPoints.append(p)
            var bezier: Bezier2? = nil
            if line.beziers.count >= 2 {
                let previousBezier = line.beziers[line.beziers.count - 2]
                let startP = previousBezier.p1
                let startCP = previousBezier.cp * 2 - previousBezier.p1
                //                    let startDP = startCP - startP
                
                if tempPoints.count == 2 {
                    bezier = Bezier2(p0: tempPoints[0], cp: tempPoints[1], p1: tempPoints[1])
                } else if tempPoints.count == 3 {
                    bezier = Bezier2(p0: tempPoints[0], cp: tempPoints[1], p1: tempPoints[2])
                } else if tempPoints.count >= 4 {
                    let endCP = tempPoints[tempPoints.count - 3]
                        .mid(tempPoints[tempPoints.count - 2])
                    let endP = p
                    //                        let endDP = endCP - endP
                    
                    if let cp = Point.intersectionLineSegmentOver0(startCP, startP,
                                                                   endP, endCP),
                        cp.distanceWithLine(ap: startP, bp: endP)
                            < startP.distance(endP) * 4 {
                        
                        bezier = Bezier2(p0: startP, cp: cp, p1: endP)
                    }
                }
            } else {
                if tempPoints.count == 2 {
                    bezier = Bezier2(p0: tempPoints[0], cp: tempPoints[1], p1: tempPoints[1])
                } else if tempPoints.count == 3 {
                    bezier = Bezier2(p0: tempPoints[0], cp: tempPoints[1], p1: tempPoints[2])
                } else if tempPoints.count >= 4 {
                    let startCP = tempPoints[1].mid(tempPoints[2])
                    let startP = tempPoints[0]
                    //                        let startDP = startCP - startP
                    let endCP = tempPoints[tempPoints.count - 3]
                        .mid(tempPoints[tempPoints.count - 2])
                    let endP = p
                    //                        let endDP = endCP - endP
                    
                    if let cp = Point.intersectionLineSegmentOver0(startP, startCP,
                                                                   endP, endCP),
                        cp.distanceWithLine(ap: startP, bp: endP) < startP.distance(endP) * 4 {
                        
                        bezier = Bezier2(p0: startP, cp: cp, p1: endP)
                    }
                }
            }
            guard let newBezier = bezier else {
                let lastP = tempPoints.last!
                tempPoints = [lastP, p]
                line.beziers.append(Bezier2(p0: lastP, cp: lastP, p1: p))
                self.line = line
                strokableView.update(line)
                return
            }
            let distance = tempPoints.reduce(0.0.cg) {
                max($0, newBezier.minDistance²(at: $1))
            }
            if distance < minDistance {
                line.beziers[line.beziers.count - 1] = newBezier
            } else {
                let lastP = tempPoints.last!
                tempPoints = [lastP, p]
                line.beziers.append(Bezier2(p0: lastP, cp: lastP, p1: p))
            }
            self.line = line
            strokableView.update(line)
        }
    }
    
    //        func stroke(for point: Point, pressure: Real, time: Real, _ phase: Phase,
    //                    isAppendLine: Bool = true, to version: Version? = nil) {
    //            let p = viewStroker.convertToCurrentLocal(point)
    //            switch phase {
    //            case .began:
    //                let line = Line(points: [p, p, p])
    //                self.line = line
    //                oldPoint = p
    //                oldTime = time
    //                oldTempTime = time
    //                tempDistance = 0
    //                temps = [Temp(point: p, speed: 0)]
    //                beginTime = time
    //                if isAppendLine, let version = version {
    //                    viewStroker.insert(line, to: version)
    //                }
    //            case .changed:
    //                guard var line = line, p != oldPoint else { return }
    //                let viewScale = viewStroker.viewScale
    //                let d = p.distance(oldPoint)
    //                tempDistance += d
    //
    //                let rp = line.points[line.points.count - 3]
    //                line.points[line.points.count - 3] = rp
    //
    //                let speed = d / (time - oldTime)
    //                temps.append(Temp(point: p, speed: speed))
    //                let lp = p
    //
    //                let mlp = lp.mid(temps[temps.count - 2].point)
    //                if let jp = join.joinControlWith(line, lastControl: mlp) {
    //                    line.points.insert(jp, at: line.points.count - 2)
    //                    temps = [Temp(point: lp, speed: speed)]
    //                    oldTempTime = time
    //                    tempDistance = 0
    //                } else if interval.isAppendPointWith(distance: tempDistance / viewScale,
    //                                                     deltaTime: time - oldTempTime,
    //                                                     temps,
    //                                                     scale: viewScale) {
    //                    line.points.insert(lp, at: line.points.count - 2)
    //                    temps = [Temp(point: lp, speed: speed)]
    //                    oldTempTime = time
    //                    tempDistance = 0
    //                }
    //
    //                line.points[line.points.count - 2] = lp
    //                line.points[line.points.count - 1] = lp
    //                self.line = line
    //                viewStroker.update(line)
    //                oldTime = time
    //                oldPoint = p
    //            case .ended:
    //                guard var line = line else { return }
    //                let viewScale = viewStroker.viewScale
    //                if !interval.isAppendPointWith(distance: tempDistance / viewScale,
    //                                               deltaTime: time - oldTempTime,
    //                                               temps,
    //                                               scale: viewScale) {
    //                    line.points.remove(at: line.points.count - 2)
    //                }
    //                line.points[line.points.count - 1] = p
    //                line = short.shortedLineWith(line, deltaTime: time - beginTime,
    //                                             scale: viewScale)
    //                self.line = line
    //                viewStroker.update(line)
    //            }
    //        }
    
    var lines = [Line]()
    
    func lassoErase(for p: Point, pressure: Real, time: Real, _ phase: Phase) {
        _ = stroke(for: p, pressure: pressure, time: time, phase, isAppendLine: false)
        switch phase {
        case .began:
            break
        case .changed, .ended:
            if let line = line {
                lassoErase(with: line)
            }
        }
    }
    func lassoErase(with line: Line) {
        var isRemoveLineInDrawing = false
        let lasso = GeometryLasso(geometry: Geometry(lines: [line]))
        let newDrawingLines = lines.reduce(into: [Line]()) {
            if let splitedLine = lasso.splitedLine(with: $1) {
                switch splitedLine {
                case .around:
                    isRemoveLineInDrawing = true
                case .splited(let lines):
                    isRemoveLineInDrawing = true
                    $0 += lines
                }
            } else {
                $0.append($1)
            }
        }
        if isRemoveLineInDrawing {
            self.lines = newDrawingLines
        }
    }
}
