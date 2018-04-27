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

extension Double {
    var cg: CGFloat {
        return CGFloat(self)
    }
}

protocol DeepCopiable {
    var copied: Self { get }
    func copied(from deepCopier: DeepCopier) -> Self
}
extension DeepCopiable {
    var copied: Self {
        return self
    }
    func copied(from deepCopier: DeepCopier) -> Self {
        return self
    }
}
protocol ClassDeepCopiable: class, DeepCopiable {
}
extension ClassDeepCopiable {
    var copied: Self {
        return DeepCopier().copied(self)
    }
}
final class DeepCopier {
    var userInfo = [String: Any]()
    func copied<T: ClassDeepCopiable>(_ object: T) -> T {
        let key = String(describing: T.self)
        let oim: ObjectIdentifierManager<T>
        if let o = userInfo[key] as? ObjectIdentifierManager<T> {
            oim = o
        } else {
            oim = ObjectIdentifierManager<T>()
            userInfo[key] = oim
        }
        let objectID = ObjectIdentifier(object)
        if let copyManager = oim.objects[objectID] {
            return copyManager
        } else {
            let copyManager = object.copied(from: self)
            oim.objects[objectID] = copyManager
            return copyManager
        }
    }
}
private final class ObjectIdentifierManager<T> {
    var objects = [ObjectIdentifier: T]()
}

extension Data {
    var bytesString: String {
        return ByteCountFormatter().string(fromByteCount: Int64(count))
    }
}
extension Data: Referenceable {
    static let name = Localization(english: "Data", japanese: "データ")
}

final class LockTimer {
    private var workItem: DispatchWorkItem?
    func begin(endDuration: Second,
               beginClosure: () -> (),
               waitClosure: () -> (),
               endClosure: @escaping () -> ()) {
        if isWait {
            cancel()
            waitClosure()
        } else {
            beginClosure()
        }
        let workItem = DispatchWorkItem(block: endClosure)
        workItem.notify(queue: .main) { [unowned self] in
            self.workItem = nil
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(endDuration),
                                      execute: workItem)
        self.workItem = workItem
    }
    var isWait: Bool {
        if let workItem = workItem {
            return !workItem.isCancelled
        } else {
            return false
        }
    }
    func cancel() {
        if isWait {
            workItem?.cancel()
            workItem = nil
        }
    }
    
    private(set) var inUse = false
    private weak var timer: Timer?
    func begin(interval: Second, repeats: Bool = true,
               tolerance: Second = 0.0, closure: @escaping () -> ()) {
        let time = Double(interval) + CFAbsoluteTimeGetCurrent()
        let rInterval = repeats ? Double(interval) : 0
        let timer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault,
                                                    time, rInterval, 0, 0) { _ in closure() }
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, .commonModes)
        self.timer = timer
        inUse = true
        self.timer?.tolerance = Double(tolerance)
    }
    func stop() {
        inUse = false
        timer?.invalidate()
        timer = nil
    }
}

final class Weak<T: AnyObject> {
    weak var value : T?
    init (value: T) {
        self.value = value
    }
}
