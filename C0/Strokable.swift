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

import CoreGraphics

private struct Stroker {
    static let defaultLineWidth = 1.0.cg
    var line: Line?
    var lineWidth = Stroker.defaultLineWidth, lineColor = Color.strokeLine
    
    struct Temp {
        var control: Line.Control, speed: Real
    }
    var temps: [Temp] = []
    var oldPoint = Point(), tempDistance = 0.0.cg, oldLastBounds = Rect.null
    var beginTime = Second(0.0), oldTime = Second(0.0), oldTempTime = Second(0.0)
    
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
        var minSpeed = 100.0.cg, maxSpeed = 1500.0.cg, exp = 2.0.cg
        var minTime = Second(0.1), maxTime = Second(0.03)
        var minDistance = 1.45.cg, maxDistance = 1.5.cg
        func speedTWith(distance: Real, deltaTime: Second, scale: Real) -> Real {
            let speed = ((distance / scale) / deltaTime).clip(min: minSpeed, max: maxSpeed)
            return pow((speed - minSpeed) / (maxSpeed - minSpeed), 1 / exp)
        }
        func isAppendPointWith(distance: Real, deltaTime: Second,
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
                let t = pow((speed - minSpeed) / (maxSpeed - minSpeed), 1 / exp)
                let maxD = minDistance + (maxDistance - minDistance) * t
                if tc.control.point.distanceWithLine(ap: ap, bp: bp) > maxD / scale {
                    return true
                }
            }
            return false
        }
    }
    
    var short = Short()
    struct Short {
        var minTime = Second(0.1), linearMaxDistance = 1.5.cg
        func shortedLineWith(_ line: Line, deltaTime: Second, scale: Real) -> Line {
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
}
private var stroker = Stroker()
func stroke(for p: Point, pressure: Real, time: Second, _ phase: Phase, _ version: Version) {
    stroke(for: p, pressure: pressure, time: time, phase, isAppendLine: true)
}
func stroke(for point: Point, pressure: Real, time: Second, _ phase: Phase,
            isAppendLine: Bool) {
    let p = convertToCurrentLocal(point)
    switch phase {
    case .began:
        let fc = Line.Control(point: p, pressure: pressure)
        stroker.line = Line(controls: [fc, fc, fc])
        stroker.oldPoint = p
        stroker.oldTime = time
        stroker.oldTempTime = time
        stroker.tempDistance = 0
        stroker.temps = [Stroker.Temp(control: fc, speed: 0)]
        stroker.beginTime = time
    case .changed:
        guard var line = stroker.line, p != stroker.oldPoint else {
            return
        }
        let d = p.distance(stroker.oldPoint)
        stroker.tempDistance += d
        
        let pressure = (stroker.temps.first!.control.pressure + pressure) / 2
        let rc = Line.Control(point: line.controls[line.controls.count - 3].point,
                              pressure: pressure)
        line = line.withReplaced(rc, at: line.controls.count - 3)
        set(line)
        
        let speed = d / (time - stroker.oldTime)
        stroker.temps.append(Stroker.Temp(control: Line.Control(point: p, pressure: pressure),
                                          speed: speed))
        let lPressure = stroker.temps.reduce(0.0.cg) { $0 + $1.control.pressure }
            / Real(stroker.temps.count)
        let lc = Line.Control(point: p, pressure: lPressure)
        
        let mlc = lc.mid(stroker.temps[stroker.temps.count - 2].control)
        if let jc = stroker.join.joinControlWith(line, lastControl: mlc) {
            line = line.withInsert(jc, at: line.controls.count - 2)
            set(line, updateBounds: line.strokeLastBoundingBox)
            stroker.temps = [Stroker.Temp(control: lc, speed: speed)]
            stroker.oldTempTime = time
            stroker.tempDistance = 0
        } else if stroker.interval.isAppendPointWith(distance: stroker.tempDistance / viewScale,
                                                     deltaTime: time - stroker.oldTempTime,
                                                     stroker.temps,
                                                     scale: viewScale) {
            line = line.withInsert(lc, at: line.controls.count - 2)
            set(line, updateBounds: line.strokeLastBoundingBox)
            stroker.temps = [Stroker.Temp(control: lc, speed: speed)]
            stroker.oldTempTime = time
            stroker.tempDistance = 0
        }
        
        line = line.withReplaced(lc, at: line.controls.count - 2)
        line = line.withReplaced(lc, at: line.controls.count - 1)
        set(line, updateBounds: line.strokeLastBoundingBox)
        
        stroker.oldTime = time
        stroker.oldPoint = p
    case .ended:
        guard var line = stroker.line else {
            return
        }
        if !stroker.interval.isAppendPointWith(distance: stroker.tempDistance / viewScale,
                                               deltaTime: time - stroker.oldTempTime,
                                               stroker.temps,
                                               scale: viewScale) {
            line = line.withRemoveControl(at: line.controls.count - 2)
        }
        line = line.withReplaced(Line.Control(point: p, pressure: line.controls.last!.pressure),
                                 at: line.controls.count - 1)
        line = stroker.short.shortedLineWith(line, deltaTime: time - stroker.beginTime,
                                             scale: viewScale)
        if isAppendLine {
            addLine(line, in: node.editTrack.drawingItem.drawing, node, time: self.time)
            stroker.line = nil
        } else {
            stroker.line = line
        }
    }
}
private func set(_ line: Line) {
    stroker.line = line
    let lastBounds = line.visibleImageBounds(withLineWidth: stroker.lineWidth)
    let ub = lastBounds.union(stroker.oldLastBounds)
    let b = Line.visibleImageBoundsWith(imageBounds: ub, lineWidth: stroker.lineWidth)
    setNeedsDisplay(inCurrentLocalBounds: b)
    stroker.oldLastBounds = lastBounds
}
private func set(_ line: Line, updateBounds lastBounds: Rect) {
    stroker.line = line
    let ub = lastBounds.union(stroker.oldLastBounds)
    let b = Line.visibleImageBoundsWith(imageBounds: ub, lineWidth: stroker.lineWidth)
    setNeedsDisplay(inCurrentLocalBounds: b)
    stroker.oldLastBounds = lastBounds
}

func lassoErase(for p: Point, pressure: Real, time: Second, _ phase: Phase, _ version: Version) {
    _ = stroke(for: p, pressure: pressure, time: time, phase, isAppendLine: false)
    switch phase {
    case .began:
        break
    case .changed:
        if let line = stroker.line {
            let b = line.visibleImageBounds(withLineWidth: stroker.lineWidth)
            setNeedsDisplay(inCurrentLocalBounds: b)
        }
    case .ended:
        if let line = stroker.line {
            lassoErase(with: line)
            stroker.line = nil
        }
    }
}
func lassoErase(with line: Line) {
    let inNode = cut.currentNode
    let drawing = inNode.editTrack.drawingItem.drawing, track = inNode.editTrack
    if let index = drawing.lines.index(of: line) {
        removeLine(at: index, in: drawing, inNode, time: time)
    }
    if !drawing.selectedLineIndexes.isEmpty {
        setSelectedLineIndexes([], oldLineIndexes: drawing.selectedLineIndexes,
                               in: drawing, inNode, time: time)
    }
    var isRemoveLineInDrawing = false, isRemoveLineInCell = false
    let lasso = LineLasso(lines: [line])
    let newDrawingLines = drawing.lines.reduce(into: [Line]()) {
        let split = lasso.split(with: $1)
        if split.isSplited {
            isRemoveLineInDrawing = true
            $0 += split.lines
        } else {
            $0.append($1)
        }
    }
    if isRemoveLineInDrawing {
        set(newDrawingLines, old: drawing.lines, in: drawing, inNode, time: time)
    }
    var removeGeometryItems = [GeometryItem]()
    removeGeometryItems = track.geometryItems.filter { geometryItem in
        if geometryItem.cell.intersects(lasso) {
            set(Geometry(), old: geometryItem.cell.geometry,
                at: track.animation.editKeyframeIndex, in: geometryItem, track, inNode, time: time)
            if geometryItem.isEmptyKeyGeometries {
                return true
            }
            isRemoveLineInCell = true
        }
        return false
    }
    if !isRemoveLineInDrawing && !isRemoveLineInCell {
        if let hitGeometryItem = inNode.geometryItem(at: line.firstPoint,
                                                     reciprocalScale: scene.reciprocalScale,
                                                     with: track) {
            let lines = hitGeometryItem.cell.geometry.lines
            set(Geometry(), old: hitGeometryItem.cell.geometry,
                at: track.animation.editKeyframeIndex,
                in: hitGeometryItem, track, inNode, time: time)
            if hitGeometryItem.isEmptyKeyGeometries {
                removeGeometryItems.append(hitGeometryItem)
            }
            set(drawing.lines + lines, old: drawing.lines,
                in: drawing, inNode, time: time)
        }
    }
    if !removeGeometryItems.isEmpty {
        self.removeGeometryItems(removeGeometryItems)
    }
}


protocol Strokable {
    var viewScale: Real { get }
    func insertWillStorkeObject(at p: Point, _ version: Version)
    func stroke(for p: Point, pressure: Real, time: Second, _ phase: Phase)
    func captureWillEraseObject(to version: Version)
    func lassoErase(for p: Point, pressure: Real, time: Second, _ phase: Phase)
}
final class StrokableActionManager: ActionManagable {
    typealias Receiver = View & Strokable
    
    var strokeAction = Action(name: Text(english: "Stroke", japanese: "ストローク"),
                              quasimode: Quasimode([Dragger.EventType.subDrag]))
    var lassoEraseAction = Action(name: Text(english: "Lasso Erase", japanese: "囲み消し"),
                                  quasimode: Quasimode(modifier: [Inputter.EventType.shift],
                                                       [Dragger.EventType.subDrag]))
    var actions: [Action] {
        return [strokeAction, lassoEraseAction]
    }
    
    private final class Stroker {
        weak var receiver: Receiver?
        func send(_ event: Dragger.Event, _ phase: Phase, in rootView: View) {
            if phase == .began {
                if let receiver = rootView.at(event.rootLocation, Receiver.self),
                    let version = receiver.withSelfAndAllParents(with: Versionable.self)?.version {
                    
                    self.receiver = receiver
                    let p = receiver.convertFromRoot(event.rootLocation)
                    receiver.insertWillStorkeObject(at: p, version)
                }
            }
            guard let receiver = receiver else { return }
            let p = receiver.convertFromRoot(event.rootLocation)
            receiver.stroke(for: p, pressure: event.pressure, time: event.time, phase)
            if phase == .ended {
                self.receiver = nil
            }
        }
    }
    private var stroker = Stroker()
    
    private final class LassoEraser {
        weak var receiver: Receiver?
        func send(_ event: Dragger.Event, _ phase: Phase, in rootView: View) {
            if phase == .began {
                if let receiver = rootView.at(event.rootLocation, Receiver.self),
                    let version = receiver.withSelfAndAllParents(with: Versionable.self)?.version {
                    
                    self.receiver = receiver
                    receiver.captureWillEraseObject(to: version)
                }
            }
            guard let receiver = receiver else { return }
            let p = receiver.convertFromRoot(event.rootLocation)
            receiver.lassoErase(for: p, pressure: event.pressure, time: event.time, phase)
            if phase == .ended {
                self.receiver = nil
            }
        }
    }
    private var lassoEraser = LassoEraser()
    
    func send(_ eventMap: EventMap, in rootView: View) {
        if let (draggerEvent, phase) = eventMap.sendableTuple(with: strokeAction, .subDrag) {
            stroker.send(draggerEvent, phase, in: rootView)
        }
        if let (draggerEvent, phase) = eventMap.sendableTuple(with: lassoEraseAction, .subDrag) {
            lassoEraser.send(draggerEvent, phase, in: rootView)
        }
    }
}
