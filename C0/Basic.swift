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

extension Data {
    var bytesString: String {
        return ByteCountFormatter().string(fromByteCount: Int64(count))
    }
}
extension Data: Referenceable {
    static let name = Localization(english: "Data", japanese: "データ")
}

final class LockTimer {
    private var count = 0
    private(set) var wait = false
    func begin(endDuration: Second, beginClosure: () -> Void,
               waitClosure: () -> Void, endClosure: @escaping () -> Void) {
        if wait {
            waitClosure()
            count += 1
        } else {
            beginClosure()
            wait = true
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + endDuration) {
            if self.count == 0 {
                endClosure()
                self.wait = false
            } else {
                self.count -= 1
            }
        }
    }
    private(set) var inUse = false
    private weak var timer: Timer?
    func begin(interval: Second, repeats: Bool = true,
               tolerance: Second = 0.0, closure: @escaping () -> Void) {
        let time = interval + CFAbsoluteTimeGetCurrent()
        let rInterval = repeats ? interval : 0
        let timer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault,
                                                    time, rInterval, 0, 0) { _ in closure() }
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, .commonModes)
        self.timer = timer
        inUse = true
        self.timer?.tolerance = tolerance
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
