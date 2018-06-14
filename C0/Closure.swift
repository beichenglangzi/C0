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

typealias Closure = ((Version) -> ())

final class ClosureView: ModelView, IndicatableResponder {
    typealias Model = Closure
    var model: Model
    
    let nameView: TextFormView
    
    init(model: @escaping Model = { _ in }, name: Text = "") {
        self.model = model
        
        self.nameView = TextFormView(text: name)
        
        super.init(isLocked: false)
        lineColor = .sendBorder
        children = [nameView]
    }
    
    var minSize: Size {
        let minSize = nameView.minSize, padding = Layouter.basicPadding
        return Size(width: minSize.width + padding * 2, height: minSize.height + padding * 2)
    }
    override func updateLayout() {
        let minSize = nameView.minSize, padding = Layouter.basicPadding
        let nameOrigin = Point(x: padding,
                               y: bounds.height - minSize.height - padding)
        nameView.frame = Rect(origin: nameOrigin, size: minSize)
    }
    
    var indicatedLineColor: Color? {
        return .indicated
    }
}
private struct _Closure: Referenceable {
    static let name = Text(english: "Closure", japanese: "クロージャ")
}
extension ClosureView: Runnable {
    func run(for p: Point, _ version: Version) {
        model(version)
    }
}
