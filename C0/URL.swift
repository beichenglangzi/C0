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

import struct Foundation.URL
import struct Foundation.Data

extension URL {
    init?(bookmark: Data?) {
        guard let bookmark = bookmark else {
            return nil
        }
        do {
            var bds = false
            guard let url = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &bds) else {
                return nil
            }
            self = url
        } catch {
            return nil
        }
    }
    var type: String? {
        let resourceValues = try? self.resourceValues(forKeys: Set([.typeIdentifierKey]))
        return resourceValues?.typeIdentifier
    }
}
extension URL: Referenceable {
    static let name = Text("URL")
}
extension URL: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        return lastPathComponent.view(withBounds: bounds, sizeType)
    }
}
extension URL: MiniViewable {}
