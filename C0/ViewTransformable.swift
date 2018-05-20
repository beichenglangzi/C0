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

final class ViewTransformer {
    var view: ViewTransformable
    
    init(view: ViewTransformable) {
        self.view = view
    }
    
    func zoom(at p: Point, closure: () -> ()) {
        let point = view.convertToCurrentLocal(p)
        closure()
        let newPoint = view.convertFromCurrentLocal(point)
        view.transform.translation -= (newPoint - p)
    }
    
    var minScale = 0.00001.cg, blockScale = 1.0.cg, maxScale = 64.0.cg
    var correctionScale = 1.28.cg, correctionRotation = 1.0.cg / (4.2 * .pi)
    private var isBlockScale = false, oldScale = 0.0.cg
    func zoom(for p: Point, time: Second, magnification: Real, _ phase: Phase) {
        let scale = view.transform.scale.x
        switch phase {
        case .began:
            oldScale = scale
            isBlockScale = false
        case .changed:
            if !isBlockScale {
                zoom(at: p) {
                    let newScale = (scale * pow(magnification * correctionScale + 1, 2))
                        .clip(min: minScale, max: maxScale)
                    if blockScale.isOver(old: scale, new: newScale) {
                        isBlockScale = true
                    }
                    view.transform.scale = Point(x: newScale, y: newScale)
                }
            }
        case .ended:
            if isBlockScale {
                zoom(at: p) {
                    view.transform.scale = Point(x: blockScale, y: blockScale)
                }
            }
        }
    }
    
    var blockRotations: [Real] = [-.pi, 0.0, .pi]
    private var isBlockRotation = false, blockRotation = 0.0.cg, oldRotation = 0.0.cg
    func rotate(for p: Point, time: Second, rotationQuantity: Real, _ phase: Phase) {
        let rotation = view.transform.rotation
        switch phase {
        case .began:
            oldRotation = rotation
            isBlockRotation = false
        case .changed:
            if !isBlockRotation {
                zoom(at: p) {
                    let oldRotation = rotation
                    let newRotation = rotation + rotationQuantity * correctionRotation
                    for br in blockRotations {
                        if br.isOver(old: oldRotation, new: newRotation) {
                            isBlockRotation = true
                            blockRotation = br
                            break
                        }
                    }
                    view.transform.rotation = newRotation.clipRotation
                }
            }
        case .ended:
            if isBlockRotation {
                zoom(at: p) {
                    view.transform.rotation = blockRotation
                }
            }
        }
    }
}
