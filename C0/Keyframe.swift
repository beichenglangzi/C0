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

import CoreGraphics

protocol KeyframeProtocol {
    var time: Rational { get set }
}
protocol KeyframeValue: Equatable, Interpolatable, Initializable, Object.Value, AbstractViewable {}
struct Keyframe<Value: KeyframeValue>: Codable, Equatable, KeyframeProtocol {
    var value = Value()
    var time = Rational(0)
}
extension Keyframe {
    struct IndexInfo {
        var index: Int, interTime: Rational, duration: Rational
    }
    static func indexInfo(atTime t: Rational, with keyframes: [Keyframe]) -> IndexInfo {
        var oldT = Rational(0)
        for i in (0..<keyframes.count).reversed() {
            let keyframe = keyframes[i]
            if t >= keyframe.time {
                return IndexInfo(index: i,
                                 interTime: t - keyframe.time,
                                 duration: oldT - keyframe.time)
            }
            oldT = keyframe.time
        }
        return IndexInfo(index: 0,
                         interTime: t - keyframes.first!.time,
                         duration: oldT - keyframes.first!.time)
    }
}
extension Keyframe: Referenceable {
    static var name: Text {
        return Text(english: "Keyframe", japanese: "キーフレーム") + "<" + Value.name + ">"
    }
}
extension Keyframe: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect) -> View {
        return Text("\(time.description) s").thumbnailView(withFrame: frame)
    }
}
extension Keyframe: AbstractViewable {
    func abstractViewWith<T : BinderProtocol>(binder: T,
                                              keyPath: ReferenceWritableKeyPath<T, Keyframe>,
                                              type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return KeyframeView(binder: binder, keyPath: keyPath)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath)
        }
    }
}
extension Keyframe: ObjectViewable {}

struct KeyframeTimeCollection: RandomAccessCollection {
    let keyframes: [KeyframeProtocol]
    var startIndex: Int {
        return keyframes.startIndex
    }
    var endIndex: Int {
        return keyframes.endIndex
    }
    func index(after i: Int) -> Int {
        return keyframes.index(after: i)
    }
    func index(before i: Int) -> Int {
        return keyframes.index(before: i)
    }
    subscript(i: Int) -> Rational {
        return keyframes[i].time
    }
}

final class KeyframeView<Value: KeyframeValue, T: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = Keyframe<Value>
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((KeyframeView<Value, Binder>, BasicNotification) -> ())]()
    
    var defaultModel = Model()
    
    var keyValueView: View & LayoutMinSize
    var timeView: DiscreteRationalView<Binder>
    
    init(binder: Binder, keyPath: BinderKeyPath) {
        self.binder = binder
        self.keyPath = keyPath
        let keyValueKeyPath = keyPath.appending(path: \Model.value)
        keyValueView = binder[keyPath: keyPath].value.abstractViewWith(binder: binder,
                                                                       keyPath: keyValueKeyPath,
                                                                       type: .mini)
        timeView = DiscreteRationalView(binder: binder,
                                        keyPath: keyPath.appending(path: \Model.time),
                                        option: RationalOption(defaultModel: 0,
                                                               minModel: 0, maxModel: .max,
                                                               isInfinitesimal: false))
        
        super.init(isLocked: false)
    }
    
    var minSize: Size {
        let padding = Layouter.basicPadding
        let kvms = keyValueView.minSize, ktms = timeView.minSize
        return Size(width: kvms.width + ktms.width + padding * 3,
                    height: max(kvms.height, ktms.height) + padding * 2)
    }
    override func updateLayout() {
        let padding = Layouter.basicPadding
        let kvms = keyValueView.minSize, ktms = timeView.minSize
        keyValueView.frame = Rect(origin: Point(x: padding, y: padding), size: kvms)
        timeView.frame = Rect(origin: Point(x: padding + kvms.width, y: padding), size: ktms)
    }
    func updateWithModel() {
        timeView.updateWithModel()
    }
}
