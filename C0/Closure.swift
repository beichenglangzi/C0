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

final class ClosureView: View {
    typealias Model = Closure
    var model: Model
    
    var sizeType: SizeType {
        didSet { updateLayout() }
    }
    let nameView: TextFormView
    
    init(model: @escaping Model = { _ in }, name: Text = "",
         frame: Rect = Rect(), sizeType: SizeType = .regular) {
        
        self.model = model
        
        self.sizeType = sizeType
        self.nameView = TextFormView(text: name, font: Font.default(with: sizeType), color: .locked)
        
        super.init()
        children = [nameView]
        self.frame = frame
    }
    
    override var defaultBounds: Rect {
        let fitSize = nameView.defaultBounds.size, padding = Layout.padding(with: sizeType)
        return Rect(x: 0, y: 0,
                    width: fitSize.width + padding * 2, height: fitSize.height + padding * 2)
    }
    override func updateLayout() {
        let padding = Layout.padding(with: sizeType)
        nameView.frame.origin = Point(x: padding, y: bounds.height - nameView.frame.height - padding)
    }
}
private struct _Closure: Referenceable {
    static let name = Text(english: "Closure", japanese: "クロージャ")
}
extension ClosureView: Queryable {
    static let referenceableType: Referenceable.Type = _Closure.self
}
extension ClosureView: Runnable {
    func run(for p: Point, _ version: Version) {
        model(version)
    }
}
