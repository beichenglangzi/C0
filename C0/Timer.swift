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

import Dispatch

final class RunTimer {
    private var workItem: DispatchWorkItem?
    func run(afterTime: Real,
             dispatchQueue: DispatchQueue,
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
        workItem.notify(queue: .main) { [weak self] in
            self?.workItem = nil
        }
        dispatchQueue.asyncAfter(deadline: DispatchTime.now() + Double(afterTime),
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
}
