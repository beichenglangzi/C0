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
    var cg: CGImage?
    
    init?(url: URL) {
        guard
            let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
            let cg = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                return nil
        }
        self.cg = cg
    }
    init?(data: Data) {
        guard
            let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
            let cg = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                return nil
        }
        self.cg = cg
    }
    init(_ cg: CGImage) {
        self.cg = cg
    }
    init() {}
}
extension Image {
    var size: Size {
        return cg?.size ?? Size()
    }
}
extension Image {
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
    
    func data(_ type: FileType) -> Data? {
        return cg?.data(type)
    }
    
    func write(_ type: FileType, to url: URL) throws {
        try cg?.write(type, to: url)
    }
}
extension Image: Referenceable {
    static let name = Text(english: "Image", japanese: "画像")
}
extension Image: Equatable {
    static func ==(lhs: Image, rhs: Image) -> Bool {
        return lhs.cg == rhs.cg
    }
}
extension Image: Codable {
    private enum CodingKeys: String, CodingKey {
        case data
    }
    enum CodingError: Error {
        case decoding(String), encoding(String)
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let data = try values.decode(Data.self, forKey: .data)
        guard let image = Image(data: data) else {
            throw CodingError.decoding("\(dump(values))")
        }
        self = image
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let data = data(.tiff) {
            try container.encode(data, forKey: .data)
        } else {
            throw CodingError.decoding("\(dump(container))")
        }
    }
}
extension Image: ThumbnailViewable {
    func thumbnailView(withFrame frame: Rect, _ sizeType: SizeType) -> View {
        let view = View(frame: frame, isLocked: true)
        view.image = self
        return view
    }
}
extension Image: AbstractViewable {
    func abstractViewWith<T : BinderProtocol>(binder: T,
                                              keyPath: ReferenceWritableKeyPath<T, Image>,
                                              frame: Rect, _ sizeType: SizeType,
                                              type: AbstractType) -> ModelView {
        switch type {
        case .normal:
            return ImageView(binder: binder, keyPath: keyPath, frame: frame)
        case .mini:
            return MiniView(binder: binder, keyPath: keyPath, frame: frame, sizeType)
        }
    }
}
extension Image: ObjectViewable {}

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
    func data(_ fileType: Image.FileType) -> Data? {
        let cfFileType = fileType.cfUTType
        guard
            let mData = CFDataCreateMutable(nil, 0),
            let idn = CGImageDestinationCreateWithData(mData, cfFileType, 1, nil) else {
                return nil
        }
        CGImageDestinationAddImage(idn, self, nil)
        if !CGImageDestinationFinalize(idn) {
            return nil
        } else {
            return mData as Data
        }
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

final class ImageView<T: BinderProtocol>: ModelView, BindableReceiver {
    typealias Model = Image
    typealias Binder = T
    var binder: Binder {
        didSet { updateWithModel() }
    }
    var keyPath: BinderKeyPath {
        didSet { updateWithModel() }
    }
    var notifications = [((ImageView<Binder>, BasicNotification) -> ())]()
    
    var defaultModel = Model()
    
    init(binder: Binder, keyPath: BinderKeyPath, frame: Rect = Rect()) {
        self.binder = binder
        self.keyPath = keyPath
        
        super.init()
        self.image = model
        self.frame = frame
    }
    
    func updateWithModel() {
        self.image = model
    }
    
    var defaultMinSize = Size(width: 50, height: 50)
    var defaultMaxSize = Size(width: 400, height: 400)
    override var defaultBounds: Rect {
        let size = model.size
        return Rect(x: 0, y: 0,
                    width: size.width.clip(min: defaultMinSize.width,
                                           max: defaultMaxSize.width),
                    height: size.height.clip(min: defaultMinSize.height,
                                             max: defaultMaxSize.height))
    }
}
