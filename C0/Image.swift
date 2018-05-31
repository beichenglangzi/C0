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

import CoreGraphics
import QuartzCore

struct Image {
    enum FileType: FileTypeProtocol {
        case png, jpeg, tiff
        fileprivate var cfUTType: CFString {
            switch self {
            case .png: return kUTTypePNG
            case .jpeg: return kUTTypeJPEG
            case .tiff: return kUTTypeTIFF
            }
        }
        var utType: String {
            return cfUTType as String
        }
    }
    
    let url: URL?
    let cg: CGImage
    init?(url: URL) {
        guard
            let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
            let cg = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                return nil
        }
        self.url = url
        self.cg = cg
    }
    init(_ cg: CGImage) {
        url = nil
        self.cg = cg
    }
    var size: Size {
        return cg.size
    }
    func write(_ type: FileType, to url: URL) throws {
        try cg.write(type, to: url)
    }
}
extension Image: Referenceable {
    static let name = Text(english: "Image", japanese: "画像")
}
extension Image: Equatable {
    static func ==(lhs: Image, rhs: Image) -> Bool {
        return lhs.cg == rhs.cg || lhs.url == rhs.url
    }
}

extension CGContext {
    var renderImage: Image? {
        if let cg = makeImage() {
            return Image(cg)
        } else {
            return nil
        }
    }
}
extension CGImage {
    var size: Size {
        return Size(width: width, height: height)
    }
    func write(_ fileType: Image.FileType, to url: URL) throws {
        let cfUrl = url as CFURL, cfFileType = fileType.cfUTType
        guard let idn = CGImageDestinationCreateWithURL(cfUrl, cfFileType, 1, nil) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError)
        }
        CGImageDestinationAddImage(idn, self, nil)
        if !CGImageDestinationFinalize(idn) {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError)
        }
    }
}
extension CALayer {
    var image: Image? {
        get {
            guard let contents = contents else {
                return nil
            }
            return Image(contents as! CGImage)
        }
        set {
            contents = newValue?.cg
            if newValue != nil {
                minificationFilter = kCAFilterTrilinear
                magnificationFilter = kCAFilterTrilinear
            } else {
                minificationFilter = kCAFilterLinear
                magnificationFilter = kCAFilterLinear
            }
        }
    }
}

final class ImageView<T: BinderProtocol>: View, BindableReceiver {
    typealias Model = Image
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((ImageView<Binder>, BasicNotification) -> ())]()
    
    init(binder: Binder, keyPath: BinderKeyPath, frame: Rect = Rect()) {
        self.binder = binder
        self.keyPath = keyPath
        
        super.init()
        self.frame = frame
    }
    
    func updateWithModel() {
        self.image = model
    }
}
extension ImageView: Movable {
    func captureWillMoveObject(at p: Point, to version: Version) {}
    
    func makeViewMover() -> ViewMover {
        return ImageViewMover(imageView: self)
    }
    
}
final class ImageViewMover<Binder: BinderProtocol>: ViewMover {
    var movableView: View & Movable {
        return imageView
    }
    var imageView: ImageView<Binder>
    
    init(imageView: ImageView<Binder>) {
        self.imageView = imageView
    }
    
    private enum DragType {
        case move, resizeMinXMinY, resizeMaxXMinY, resizeMinXMaxY, resizeMaxXMaxY
    }
    private var dragType = DragType.move, downPosition = Point(), oldFrame = Rect()
    private var resizeWidth = 10.0.cg, ratio = 1.0.cg
    
    func move(for point: Point, first fp: Point, pressure: Real,
              time: Second, _ phase: Phase) {
        guard let parent = imageView.parent else { return }
        let p = parent.convert(point, from: imageView), ip = point
        switch phase {
        case .began:
            if Rect(x: 0, y: 0, width: resizeWidth, height: resizeWidth).contains(ip) {
                dragType = .resizeMinXMinY
            } else if Rect(x: imageView.bounds.width - resizeWidth, y: 0,
                           width: resizeWidth, height: resizeWidth).contains(ip) {
                dragType = .resizeMaxXMinY
            } else if Rect(x: 0, y: imageView.bounds.height - resizeWidth,
                           width: resizeWidth, height: resizeWidth).contains(ip) {
                dragType = .resizeMinXMaxY
            } else if Rect(x: imageView.bounds.width - resizeWidth,
                           y: imageView.bounds.height - resizeWidth,
                           width: resizeWidth, height: resizeWidth).contains(ip) {
                dragType = .resizeMaxXMaxY
            } else {
                dragType = .move
            }
            downPosition = p
            oldFrame = imageView.frame
            ratio = imageView.frame.height / imageView.frame.width
        case .changed, .ended:
            let dp =  p - downPosition
            var frame = imageView.frame
            switch dragType {
            case .move:
                frame.origin = Point(x: oldFrame.origin.x + dp.x, y: oldFrame.origin.y + dp.y)
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
            imageView.frame = phase == .ended ? frame.integral : frame
        }
    }
}
