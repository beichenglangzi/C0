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

extension CGImage {
    var size: CGSize {
        return CGSize(width: width, height: height)
    }
    func write(to url: URL, fileType: String) throws {
        let cfUrl = url as CFURL, cfFileType = fileType as CFString
        guard let idn = CGImageDestinationCreateWithURL(cfUrl, cfFileType, 1, nil) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError)
        }
        CGImageDestinationAddImage(idn, self, nil)
        if !CGImageDestinationFinalize(idn) {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError)
        }
    }
}
extension CGImage: Referenceable {
    static let name = Localization(english: "Image", japanese: "画像")
}

final class ImageView: View {
    var url: URL? {
        didSet {
            if let url = url {
                self.image = ImageView.image(with: url)
            }
        }
    }
    static func image(with url: URL) -> CGImage? {
        guard
            let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                return nil
        }
        return image
    }
    
    init(image: CGImage? = nil) {
        super.init()
        self.image = image
    }
    init(url: URL?) {
        super.init()
        self.url = url
        if let url = url {
            self.image = ImageView.image(with: url)
        }
    }
    
    func delete(with event: KeyInputEvent) -> Bool {
        removeFromParent()
        return true
    }
    
    enum DragType {
        case move, resizeMinXMinY, resizeMaxXMinY, resizeMinXMaxY, resizeMaxXMaxY
    }
    var dragType = DragType.move, downPosition = CGPoint(), oldFrame = CGRect()
    var resizeWidth = 10.0.cf, ratio = 1.0.cf
    func move(with event: DragEvent) -> Bool {
        guard let parent = parent else {
            return false
        }
        let p = parent.point(from: event), ip = point(from: event)
        switch event.sendType {
        case .begin:
            if CGRect(x: 0, y: 0, width: resizeWidth, height: resizeWidth).contains(ip) {
                dragType = .resizeMinXMinY
            } else if CGRect(x:  bounds.width - resizeWidth, y: 0,
                             width: resizeWidth, height: resizeWidth).contains(ip) {
                dragType = .resizeMaxXMinY
            } else if CGRect(x: 0, y: bounds.height - resizeWidth,
                             width: resizeWidth, height: resizeWidth).contains(ip) {
                dragType = .resizeMinXMaxY
            } else if CGRect(x: bounds.width - resizeWidth, y: bounds.height - resizeWidth,
                             width: resizeWidth, height: resizeWidth).contains(ip) {
                dragType = .resizeMaxXMaxY
            } else {
                dragType = .move
            }
            downPosition = p
            oldFrame = frame
            ratio = frame.height / frame.width
        case .sending, .end:
            let dp =  p - downPosition
            var frame = self.frame
            switch dragType {
            case .move:
                frame.origin = CGPoint(x: oldFrame.origin.x + dp.x, y: oldFrame.origin.y + dp.y)
            case .resizeMinXMinY:
                frame.origin.x = oldFrame.origin.x + dp.x
                frame.origin.y = oldFrame.origin.y + dp.y
                frame.size.width = oldFrame.width - dp.x
                frame.size.height = frame.size.width * ratio
            case .resizeMaxXMinY:
                frame.origin.y = oldFrame.origin.y + dp.y
                frame.size.width = oldFrame.width + dp.x
                frame.size.height = frame.size.width * ratio
            case .resizeMinXMaxY:
                frame.origin.x = oldFrame.origin.x + dp.x
                frame.size.width = oldFrame.width - dp.x
                frame.size.height = frame.size.width * ratio
            case .resizeMaxXMaxY:
                frame.size.width = oldFrame.width + dp.x
                frame.size.height = frame.size.width * ratio
            }
            self.frame = event.sendType == .end ? frame.integral : frame
        }
        return true
    }
    
    func reference(with event: TapEvent) -> Reference? {
        return image?.reference
    }
}
