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

typealias Closure = (() -> ())

final class ClosureView: View, Runnable {
    var closure: Closure
    
    let nameView: TextView
    var sizeType: SizeType
    
    init(closure: @escaping Closure = {},
         name: Localization = Localization(),
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.closure = closure
        self.nameView = TextView(text: name, font: Font.default(with: sizeType), color: .locked)
        self.sizeType = sizeType
        
        super.init()
        self.frame = frame
        children = [nameView]
    }
    
    override var defaultBounds: Rect {
        let fitSize = nameView.fitSize, padding = Layout.padding(with: sizeType)
        return Rect(x: 0,
                      y: 0,
                      width: fitSize.width + padding * 2,
                      height: fitSize.height + padding * 2)
    }
    override var bounds: Rect {
        didSet {
            updateLayout()
        }
    }
    func updateLayout() {
        let padding = Layout.padding(with: sizeType)
        nameView.frame.origin = Point(x: padding,
                                        y: bounds.height - nameView.frame.height - padding)
    }
    
    func run(for p: Point) {
        closure()
    }
    
    func reference(at p: Point) -> Reference {
        return Reference(name: Localization(english: "Closure", japanese: "クロージャ"))
    }
}
