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

protocol Copiable {
    var copied: Self { get }
    func copied(from copier: Copier) -> Self
}
extension Copiable {
    var copied: Self {
        return self
    }
    func copied(from copier: Copier) -> Self {
        return self
    }
}
protocol ClassCopiable: class, Copiable {
}
extension ClassCopiable {
    var copied: Self {
        return Copier().copied(self)
    }
}
final class Copier {
    var userInfo = [String: Any]()
    func copied<T: ClassCopiable>(_ object: T) -> T {
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
