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

extension URL {
    func isConforms(uti: String) -> Bool {
        if let aUTI = self.uti {
            return UTTypeConformsTo(aUTI as CFString, uti as CFString)
        } else {
            return false
        }
    }
    var uti: String? {
        return (try? resourceValues(forKeys: Set([URLResourceKey.typeIdentifierKey])))?
            .typeIdentifier
    }
    init?(bookmark: Data?) {
        guard let bookmark = bookmark else {
            return nil
        }
        do {
            var bookmarkDataIsStale = false
            guard let url = try URL(resolvingBookmarkData: bookmark,
                                    bookmarkDataIsStale: &bookmarkDataIsStale) else {
                                        return nil
            }
            self = url
        } catch {
            return nil
        }
    }
}
extension URL: Referenceable {
    static let name = Localization("URL")
}
extension URL: DeepCopiable {
}
extension URL: ObjectViewExpression {
    func thumbnail(withBounds bounds: Rect, _ sizeType: SizeType) -> View {
        return lastPathComponent.view(withBounds: bounds, sizeType)
    }
}
