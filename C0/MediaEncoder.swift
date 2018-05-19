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
import AVFoundation

protocol MediaEncoder {
    func write(to url: URL,
               progressClosure: @escaping (Real, inout Bool) -> (),
               completionClosure: @escaping (Error?) -> ()) throws
}

enum VideoType: FileTypeProtocol {
    case mp4, mov
    fileprivate var av: AVFileType {
        switch self {
        case .mp4: return .mp4
        case .mov: return .mov
        }
    }
    private var cfUTType: CFString {
        switch self {
        case .mp4: return kUTTypeMPEG4
        case .mov: return kUTTypeQuickTimeMovie
        }
    }
    var utType: String {
        return cfUTType as String
    }
}
enum VideoCodec {
    case h264
    fileprivate var av: String {
        switch self {
        case .h264: return AVVideoCodecH264
        }
    }
}

final class SceneVideoEncoder: MediaEncoder {
    private var scene: Scene, size: Size, videoType: VideoType, codec: VideoCodec
    private let drawView = View(drawClosure: { _, _ in })
    private var screenTransform = Transform()
    
    init(scene: Scene, size: Size, videoType: VideoType = .mp4, codec: VideoCodec = .h264) {
        self.scene = scene
        self.size = size
        self.videoType = videoType
        self.codec = codec
        
        let scale = size.width / scene.canvas.frame.size.width
        self.screenTransform = Transform(translation: Point(x: size.width / 2, y: size.height / 2),
                                         scale: Point(x: scale, y: scale),
                                         rotation: 0)
        drawView.bounds.size = size
        drawView.drawClosure = { [unowned self] ctx, _ in self.scene.canvas.draw(in: ctx) }
    }
    
    func write(to url: URL,
               progressClosure: @escaping (Real, inout Bool) -> (),
               completionClosure: @escaping (Error?) -> ()) throws {
        let colorSpace = CGColorSpace.default
        guard let colorSpaceProfile = colorSpace.iccData else {
            throw NSError(domain: AVFoundationErrorDomain, code: AVError.Code.exportFailed.rawValue)
        }
        
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        
        let writer = try AVAssetWriter(outputURL: url, fileType: videoType.av)
        
        let width = size.width, height = size.height
        let setting: [String: Any] = [AVVideoCodecKey: codec.av,
                                      AVVideoWidthKey: width,
                                      AVVideoHeightKey: height]
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: setting)
        writerInput.expectsMediaDataInRealTime = true
        writer.add(writerInput)
        
        let pixelFormat = Int(kCVPixelFormatType_32ARGB)
        let attributes: [String: Any] = [String(kCVPixelBufferPixelFormatTypeKey): pixelFormat,
                                         String(kCVPixelBufferWidthKey): width,
                                         String(kCVPixelBufferHeightKey): height,
                                         String(kCVPixelBufferCGBitmapContextCompatibilityKey): true]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput,
                                                           sourcePixelBufferAttributes: attributes)
        
        guard writer.startWriting() else {
            throw NSError(domain: AVFoundationErrorDomain, code: AVError.Code.exportFailed.rawValue)
        }
        writer.startSession(atSourceTime: kCMTimeZero)
        
        let allFrameCount = scene.timeline.frameTime(withBeatTime: scene.timeline.duration)
        let timeScale = Int32(scene.timeline.frameRate)
        
        var append = false, stop = false
        for i in 0..<allFrameCount {
            autoreleasepool {
                while !writerInput.isReadyForMoreMediaData {
                    progressClosure(Real(i) / Real(allFrameCount - 1), &stop)
                    if stop {
                        append = false
                        return
                    }
                    Thread.sleep(forTimeInterval: 0.1)
                }
                guard let bufferPool = adaptor.pixelBufferPool else {
                    append = false
                    return
                }
                var pixelBuffer: CVPixelBuffer?
                CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, bufferPool, &pixelBuffer)
                guard let pb = pixelBuffer else {
                    append = false
                    return
                }
                CVBufferSetAttachment(pb, kCVImageBufferICCProfileKey,
                                      colorSpaceProfile, .shouldPropagate)
                CVPixelBufferLockBaseAddress(pb, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
                if let ctx = CGContext(data: CVPixelBufferGetBaseAddress(pb),
                                       width: CVPixelBufferGetWidth(pb),
                                       height: CVPixelBufferGetHeight(pb),
                                       bitsPerComponent: 8,
                                       bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
                                       space: colorSpace,
                                       bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) {
                    scene.timeline.editingTime = scene.timeline.beatTime(withFrameTime: i)
                    drawView.render(in: ctx)
                }
                CVPixelBufferUnlockBaseAddress(pb, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
                append = adaptor.append(pb, withPresentationTime: CMTime(value: Int64(i),
                                                                         timescale: timeScale))
            }
            if !append { break }
            progressClosure(Real(i) / Real(allFrameCount - 1), &stop)
            if stop { break }
        }
        writerInput.markAsFinished()
        
        if !append || stop {
            writer.cancelWriting()
            if fileManager.fileExists(atPath: url.path) {
                try? fileManager.removeItem(at: url)
            }
            if !append {
                throw NSError(domain: AVFoundationErrorDomain,
                              code: AVError.Code.exportFailed.rawValue)
            }
        } else {
            writer.endSession(atSourceTime: CMTime(value: Int64(allFrameCount),
                                                   timescale: timeScale))
            writer.finishWriting {
                let soundTuples = self.scene.timeline.soundTuples
                guard !soundTuples.isEmpty else {
                    completionClosure(nil)
                    return
                }
                do {
                    try self.wrireAudio(to: url, self.videoType.av, soundTuples) { error in
                        completionClosure(error)
                    }
                } catch {
                    if fileManager.fileExists(atPath: url.path) {
                        try? fileManager.removeItem(at: url)
                    }
                }
            }
        }
    }
    
    func wrireAudio(to videoURL: URL, _ fileType: AVFileType,
                    _ soundTuples: [(sound: Sound, startFrameTime: FrameTime)],
                    completionClosure: @escaping (Error?) -> ()) throws {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(videoURL.lastPathComponent)
        
        let composition = AVMutableComposition()
        let compositionVideoTrack
            = composition.addMutableTrack(withMediaType: .video,
                                          preferredTrackID: kCMPersistentTrackID_Invalid)
        let compositionAudioTrack
            = composition.addMutableTrack(withMediaType: .audio,
                                          preferredTrackID: kCMPersistentTrackID_Invalid)
        
        let videoAsset = AVURLAsset(url: videoURL)
        guard let videoAssetTrack = videoAsset.tracks(withMediaType: .video).first else {
            throw NSError(domain: AVFoundationErrorDomain, code: AVError.Code.exportFailed.rawValue)
        }
        try compositionVideoTrack?.insertTimeRange(videoAssetTrack.timeRange,
                                                   of: videoAssetTrack,
                                                   at: kCMTimeZero)
        
        let timeScale = Int32(scene.timeline.frameRate)
        for (sound, startFrameTime) in soundTuples {
            guard let url = sound.url else { continue }
            let audioAsset = AVURLAsset(url: url)
            guard let audioAssetTrack = audioAsset.tracks(withMediaType: .audio).first else {
                throw NSError(domain: AVFoundationErrorDomain,
                              code: AVError.Code.exportFailed.rawValue)
            }
            try compositionAudioTrack?.insertTimeRange(audioAssetTrack.timeRange,
                                                       of: audioAssetTrack,
                                                       at: CMTime(value: Int64(startFrameTime),
                                                                  timescale: timeScale))
        }
        
        guard let aes = AVAssetExportSession(asset: composition,
                                             presetName: AVAssetExportPresetHighestQuality) else {
            throw NSError(domain: AVFoundationErrorDomain, code: AVError.Code.exportFailed.rawValue)
        }
        aes.outputFileType = fileType
        aes.outputURL = tempURL
        aes.exportAsynchronously { [unowned aes] in
            let fileManager = FileManager.default
            do {
                try _ = fileManager.replaceItemAt(videoURL, withItemAt: tempURL)
                if fileManager.fileExists(atPath: tempURL.path) {
                    try fileManager.removeItem(at: tempURL)
                }
                completionClosure(aes.error)
            } catch {
                completionClosure(error)
            }
        }
    }
}
typealias SceneVideoEncoderView = MediaEncoderView<SceneVideoEncoder>

final class SceneImageEncoder: MediaEncoder {
    private var canvas: Canvas, size: Size, fileType: Image.FileType
    init(canvas: Canvas, size: Size, fileType: Image.FileType) {
        self.canvas = canvas
        self.size = size
        self.fileType = fileType
    }
    
    func write(to url: URL,
               progressClosure: @escaping (Real, inout Bool) -> (),
               completionClosure: @escaping (Error?) -> ()) throws {
        let image = canvas.image(with: size)
        try image?.write(fileType, to: url)
        completionClosure(nil)
    }
}
typealias SceneImageEncoderView = MediaEncoderView<SceneImageEncoder>

final class SceneSubtitlesEncoder: MediaEncoder {
    private var timeline: Timeline, fileType: Subtitle.FileType
    init(timeline: Timeline, fileType: Subtitle.FileType) {
        self.timeline = timeline
        self.fileType = fileType
    }
    
    func write(to url: URL,
               progressClosure: @escaping (Real, inout Bool) -> (),
               completionClosure: @escaping (Error?) -> ()) throws {
        let vttData = timeline.vtt
        try vttData?.write(to: url)
        completionClosure(nil)
    }
}
typealias SceneSubtitlesEncoderView = MediaEncoderView<SceneSubtitlesEncoder>

final class MediaEncoderView<T: MediaEncoder>: View {
    var encoder: T
    var operation: Operation?
    
    var sizeType: SizeType {
        didSet { updateLayout() }
    }
    var textView: TextFormView
    let stopView = ClosureView(name: Text(english: "Stop", japanese: "中止"))
    
    init(encoder: T, frame: Rect = Rect(), sizeType: SizeType = .regular) {
        self.encoder = encoder
        self.sizeType = sizeType
        
        super.init()
        stopView.model = { [unowned self] _ in self.stop() }
        children = [textView, stopView]
        self.frame = frame
    }
    
    override func updateLayout() {
        let padding = Layout.padding(with: sizeType)
        let y = bounds.height - textView.bounds.height - padding
        textView.frame.origin = Point(x: padding, y: y)
        let sb = stopView.defaultBounds
        stopView.frame = Rect(x: bounds.width - sb.width - padding, y: y,
                              width: sb.width, height: sb.height)
    }
    
    func write(to e: URL.File) {
        let name = Text(e.url.deletingPathExtension().lastPathComponent)
        let type = Text(e.url.pathExtension.uppercased())
        
        func text(withTotalProgress value: Real) -> Text {
            let t = Text(english: "Exporting", japanese: "書き出し中")
            return text(withState: t + ", " + Text("\(Int(value * 100)) %"))
        }
        func errorText(withErrorName errorName: Text? = nil) -> Text {
            let t = Text(english: "Error", japanese: "エラー")
            if let errorName = errorName {
                return text(withState: t + ": " + errorName)
            } else {
                return text(withState: t)
            }
        }
        func text(withState state: Text) -> Text {
            return type + "(" + name + "), " + state
        }
        
        let operation = BlockOperation()
        operation.addExecutionBlock() { [unowned operation, unowned self] in
            do {
                let progressClosure: (Real, inout Bool) -> () = { (totalProgress, stop) in
                    if operation.isCancelled {
                        stop = true
                    } else {
                        OperationQueue.main.addOperation() {
                            self.textView.text = text(withTotalProgress: totalProgress)
                        }
                    }
                }
                let completionClosure: (Error?) -> () = { error in
                    do {
                        if let error = error {
                            throw error
                        }
                        OperationQueue.main.addOperation() {
                            self.textView.text = text(withTotalProgress: 1)
                        }
                        try FileManager.default.setAttributes([.extensionHidden: e.isExtensionHidden],
                                                              ofItemAtPath: e.url.path)
                        OperationQueue.main.addOperation() {
                            self.endedClosure?(self)
                        }
                    } catch {
                        OperationQueue.main.addOperation() {
                            self.textView.text = errorText()
                            self.textView.textMaterial.color = .warning
                        }
                    }
                }
                try self.encoder.write(to: e.url,
                                       progressClosure: progressClosure,
                                       completionClosure: completionClosure)
            } catch {
                OperationQueue.main.addOperation() {
                    self.textView.text = errorText()
                    self.textView.textMaterial.color = .warning
                }
            }
        }
        self.operation = operation
    }
    
    var endedClosure: ((MediaEncoderView) -> ())?
    
    var stoppedClosure: ((MediaEncoderView) -> ())?
    func stop() {
        if let operation = operation {
            operation.cancel()
        }
        stoppedClosure?(self)
    }
}
