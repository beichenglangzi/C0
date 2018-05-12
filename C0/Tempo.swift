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

import Foundation

struct TempoTrack: Track, Codable {
    static let defaultTempo = BPM(60)
    
    private(set) var animation = Animation<BPM>() {
        didSet {
            updateKeySeconds()
        }
    }
    var animatable: Animatable {
        return animation
    }
    
    private var keySeconds = [Second]()
    mutating func updateKeySeconds() {
        guard animation.loopFrames.count >= 2 else {
            keySeconds = []
            return
        }
        var second = Second(0)
        keySeconds = (0..<animation.loopFrames.count).map { li in
            if li == animation.loopFrames.count - 1 {
                return second
            } else {
                let s = second
                second += integralSecondDuration(at: li)
                return s
            }
        }
    }
    
    func realBeatTime(withSecondTime second: Second,
                      defaultTempo: BPM = TempoTrack.defaultTempo) -> RealBeat {
        guard animation.loopFrames.count >= 2 else {
            let tempo = animation.keyframes.first?.value ?? defaultTempo
            return RealBeat(second * tempo / 60)
        }
        for (li, keySecond) in keySeconds.enumerated().reversed() {
            guard keySecond <= second else { continue }
            let loopFrame = animation.loopFrames[li]
            if li == animation.loopFrames.count - 1 {
                let tempo = animation.keyframes[loopFrame.index].value
                let lastTime = RealBeat((second - keySecond) * (tempo / 60))
                return RealBeat(loopFrame.time) + lastTime
            } else {
                let i2t = animation.loopFrames[li + 1].time
                let d = i2t - loopFrame.time
                return d == 0 ?
                    RealBeat(loopFrame.time) :
                    timeWithIntegralSecond(at: li, second - keySecond)
            }
        }
        return 0
    }
    
    func secondTime(withBeatTime time: Beat,
                    defaultTempo: BPM = TempoTrack.defaultTempo) -> Second {
        guard animation.loopFrames.count >= 2 else {
            let tempo = animation.interpolatedValue(atTime: time) ?? defaultTempo
            return Second(time * 60) / Second(tempo)
        }
        for (li, loopFrame) in animation.loopFrames.enumerated().reversed() {
            guard loopFrame.time <= time else { continue }
            if li == animation.loopFrames.count - 1 {
                let tempo = animation.keyframes[loopFrame.index].value
                return keySeconds[li] + Second((time - loopFrame.time) * 60) / Second(tempo)
            } else {
                let i2t = animation.loopFrames[li + 1].time
                let d = i2t - loopFrame.time
                if d == 0 {
                    return keySeconds[li]
                } else {
                    let t = Real((time - loopFrame.time) / d)
                    return keySeconds[li] + integralSecondDuration(at: li, maxT: t)
                }
            }
        }
        return 0
    }
    
    func timeWithIntegralSecond(at li: Int, _ second: Second, minT: Real = 0,
                                splitSecondCount: Int = 10) -> RealBeat {
        let lf1 = animation.loopFrames[li], lf2 = animation.loopFrames[li + 1]
        let te1 = animation.keyframes[lf1.index].value, te2 = animation.keyframes[lf2.index].value
        let d = Real(lf2.time - lf1.time)
        func shc() -> Int {
            return max(2, Int(max(te1, te2) / d) * splitSecondCount / 2)
        }
        var doubleTime = RealBeat(0)
        func step(_ lf1: LoopFrame) {
            doubleTime = RealBeat((second * te1) / 60)
        }
        func simpsonInteglalB(_ f: (Real) -> (Real)) {
            let ns = second / (d * 60)
            let b = Real.simpsonIntegralB(splitHalfCount: shc(), a: minT, maxB: 1, s: ns, f: f)
            doubleTime = RealBeat(d * b)
        }
        func linear(_ lf1: LoopFrame, _ lf2: LoopFrame) {
            let easing = animation.keyframes[lf1.index].timing.easing
            if easing.isLinear {
                let m = te2 - te1, n = te1
                let l = log(te1) + (m * second) / (d * 60)
                let b = (exp(l) - n) / m
                doubleTime = RealBeat(d * b)
            } else {
                simpsonInteglalB {
                    let t = easing.convertT($0)
                    return 1 / BPM.linear(te1, te2, t: t)
                }
            }
        }
        func monospline(_ lf0: LoopFrame, _ lf1: LoopFrame, _ lf2: LoopFrame, _ lf3: LoopFrame) {
            let te0 = animation.keyframes[lf0.index].value, te3 = animation.keyframes[lf3.index].value
            var ms = Monospline(x0: Real(lf0.time), x1: Real(lf1.time),
                                x2: Real(lf2.time), x3: Real(lf3.time), t: 0)
            let easing = animation.keyframes[lf1.index].timing.easing
            simpsonInteglalB {
                ms.t = easing.convertT($0)
                return 1 / BPM.monospline(te0, te1, te2, te3, with: ms)
            }
        }
        func firstMonospline(_ lf1: LoopFrame, _ lf2: LoopFrame, _ lf3: LoopFrame) {
            let te3 = animation.keyframes[lf3.index].value
            var ms = Monospline(x1: Real(lf1.time), x2: Real(lf2.time), x3: Real(lf3.time), t: 0)
            let easing = animation.keyframes[lf1.index].timing.easing
            simpsonInteglalB {
                ms.t = easing.convertT($0)
                return 1 / BPM.firstMonospline(te1, te2, te3, with: ms)
            }
        }
        func lastMonospline(_ lf0: LoopFrame, _ lf1: LoopFrame, _ lf2: LoopFrame) {
            let te0 = animation.keyframes[lf0.index].value
            var ms = Monospline(x0: Real(lf0.time), x1: Real(lf1.time), x2: Real(lf2.time), t: 0)
            let easing = animation.keyframes[lf1.index].timing.easing
            simpsonInteglalB {
                ms.t = easing.convertT($0)
                return 1 / BPM.lastMonospline(te0, te1, te2, with: ms)
            }
        }
        if te1 == te2 {
            step(lf1)
        } else {
            animation.interpolation(at: li,
                                    step: step, linear: linear,
                                    monospline: monospline,
                                    firstMonospline: firstMonospline, endMonospline: lastMonospline)
        }
        return RealBeat(lf1.time) + doubleTime
    }
    
    func integralSecondDuration(at li: Int, minT: Real = 0, maxT: Real = 1,
                                splitSecondCount: Int = 10) -> Second {
        let lf1 = animation.loopFrames[li], lf2 = animation.loopFrames[li + 1]
        let te1 = animation.keyframes[lf1.index].value, te2 = animation.keyframes[lf2.index].value
        let d = Real(lf2.time - lf1.time)
        func shc() -> Int {
            return max(2, Int(max(te1, te2) / d) * splitSecondCount / 2)
        }
        
        var rTempo = 0.0.cg
        func step(_ lf1: LoopFrame) {
            rTempo = (maxT - minT) / te1
        }
        func linear(_ lf1: LoopFrame, _ lf2: LoopFrame) {
            let easing = animation.keyframes[lf1.index].timing.easing
            if easing.isLinear {
                let linearA = te2 - te1
                let rla = (1 / linearA)
                let fb = rla * log(linearA * maxT + te1)
                let fa = rla * log(linearA * minT + te1)
                rTempo = fb - fa
            } else {
                rTempo = Real.simpsonIntegral(splitHalfCount: shc(), a: minT, b: maxT) {
                    let t = easing.convertT($0)
                    return 1 / BPM.linear(te1, te2, t: t)
                }
            }
        }
        func monospline(_ lf0: LoopFrame, _ lf1: LoopFrame, _ lf2: LoopFrame, _ lf3: LoopFrame) {
            let te0 = animation.keyframes[lf0.index].value, te3 = animation.keyframes[lf3.index].value
            var ms = Monospline(x0: Real(lf0.time), x1: Real(lf1.time),
                                x2: Real(lf2.time), x3: Real(lf3.time), t: 0)
            let easing = animation.keyframes[lf1.index].timing.easing
            rTempo = Real.simpsonIntegral(splitHalfCount: shc(), a: minT, b: maxT) {
                ms.t = easing.convertT($0)
                return 1 / BPM.monospline(te0, te1, te2, te3, with: ms)
            }
        }
        func firstMonospline(_ lf1: LoopFrame, _ lf2: LoopFrame, _ lf3: LoopFrame) {
            let te3 = animation.keyframes[lf3.index].value
            var ms = Monospline(x1: Real(lf1.time), x2: Real(lf2.time), x3: Real(lf3.time), t: 0)
            let easing = animation.keyframes[lf1.index].timing.easing
            rTempo = Real.simpsonIntegral(splitHalfCount: shc(), a: minT, b: maxT) {
                ms.t = easing.convertT($0)
                return 1 / BPM.firstMonospline(te1, te2, te3, with: ms)
            }
        }
        func lastMonospline(_ lf0: LoopFrame, _ lf1: LoopFrame, _ lf2: LoopFrame) {
            let te0 = animation.keyframes[lf0.index].value
            var ms = Monospline(x0: Real(lf0.time), x1: Real(lf1.time), x2: Real(lf2.time), t: 0)
            let easing = animation.keyframes[lf1.index].timing.easing
            rTempo = Real.simpsonIntegral(splitHalfCount: shc(), a: minT, b: maxT) {
                ms.t = easing.convertT($0)
                return 1 / BPM.lastMonospline(te0, te1, te2, with: ms)
            }
        }
        if te1 == te2 {
            step(lf1)
        } else {
            animation.interpolation(at: li,
                                    step: step, linear: linear,
                                    monospline: monospline,
                                    firstMonospline: firstMonospline, endMonospline: lastMonospline)
        }
        return Second(d * 60 * rTempo)
    }
}
