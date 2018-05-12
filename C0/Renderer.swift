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
import CoreGraphics
import AVFoundation

enum VideoType: FileTypeProtocol {
    case mp4, mov
    fileprivate var av: AVFileType {
        switch self {
        case .mp4:
            return .mp4
        case .mov:
            return .mov
        }
    }
    private var cfUTType: CFString {
        switch self {
        case .mp4:
            return kUTTypeMPEG4
        case .mov:
            return kUTTypeQuickTimeMovie
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
        case .h264:
            return AVVideoCodecH264
        }
    }
}

protocol VideoEncoder {
    func writeVideo(to url: URL,
                    progressClosure: @escaping (Real, inout Bool) -> Void,
                    completionClosure: @escaping (Error?) -> ()) throws
}

final class SceneVideoEncoder: VideoEncoder {
    let scene: Scene, size: Size, videoType: VideoType, codec: VideoCodec
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
        drawView.drawClosure = { [unowned self] ctx, _ in
            ctx.concatenate(scene.canvas.viewTransform.affineTransform)
            self.scene.timeline.canvas.draw(viewType: .preview, in: ctx)
        }
    }
    
    let drawView = View(drawClosure: { _, _ in })
    var screenTransform = Transform()
    
    func writeVideo(to url: URL,
                    progressClosure: @escaping (Real, inout Bool) -> Void,
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
                    let cutTime = scene.timeline.cutTime(withFrameTime: i)
                    scene.editCutIndex = cutTime.cutItemIndex
                    cutTime.cut.currentTime = cutTime.time
                    drawView.render(in: ctx)
                }
                CVPixelBufferUnlockBaseAddress(pb, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
                append = adaptor.append(pb, withPresentationTime: CMTime(value: Int64(i),
                                                                         timescale: timeScale))
            }
            if !append {
                break
            }
            progressClosure(Real(i) / Real(allFrameCount - 1), &stop)
            if stop {
                break
            }
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
                if let audioURL = self.scene.timeline.sound.url {
                    do {
                        try self.wrireAudio(to: url, self.videoType.av, audioURL: audioURL) { error in
                            completionClosure(error)
                        }
                    } catch {
                        if fileManager.fileExists(atPath: url.path) {
                            try? fileManager.removeItem(at: url)
                        }
                    }
                } else {
                    completionClosure(nil)
                }
            }
        }
    }
    
    func wrireAudio(to videoURL: URL, _ fileType: AVFileType, audioURL: URL,
                    completionClosure: @escaping (Error?) -> ()) throws {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(videoURL.lastPathComponent)
        let audioAsset = AVURLAsset(url: audioURL)
        let videoAsset = AVURLAsset(url: videoURL)
        
        let composition = AVMutableComposition()
        guard let videoAssetTrack = videoAsset.tracks(withMediaType: .video).first else {
            throw NSError(domain: AVFoundationErrorDomain, code: AVError.Code.exportFailed.rawValue)
        }
        let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        try compositionVideoTrack?.insertTimeRange(CMTimeRange(start: kCMTimeZero,
                                                               duration: videoAsset.duration),
                                                   of: videoAssetTrack,
                                                   at: kCMTimeZero)
        guard let audioAssetTrack = audioAsset.tracks(withMediaType: .audio).first else {
            throw NSError(domain: AVFoundationErrorDomain, code: AVError.Code.exportFailed.rawValue)
        }
        let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        try compositionAudioTrack?.insertTimeRange(CMTimeRange(start: kCMTimeZero,
                                                               duration: videoAsset.duration),
                                                   of: audioAssetTrack,
                                                   at: kCMTimeZero)
        
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
