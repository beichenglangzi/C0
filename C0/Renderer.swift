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
import AVFoundation

final class SceneImageRendedrer {
    private let drawLayer = DrawLayer()
    let scene: Scene, renderSize: CGSize, cut: Cut
    let fileType: String
    init(scene: Scene, renderSize: CGSize, cut: Cut, fileType: String = kUTTypePNG as String) {
        self.scene = scene
        self.renderSize = renderSize
        self.cut = cut
        self.fileType = fileType
        
        let scale = renderSize.width / scene.frame.size.width
        scene.viewTransform = Transform(translation: CGPoint(x: renderSize.width / 2,
                                                             y: renderSize.height / 2),
                                        scale: CGPoint(x: scale, y: scale),
                                        rotation: 0)
        drawLayer.bounds.size = renderSize
        drawLayer.drawBlock = { [unowned self] ctx in
            ctx.concatenate(scene.viewTransform.affineTransform)
            self.scene.editCut.draw(scene: self.scene, viewType: .preview, in: ctx)
        }
    }
    
    var image: CGImage? {
        guard let ctx = CGContext.bitmap(with: renderSize, CGColorSpace.default) else {
            return nil
        }
        drawLayer.render(in: ctx)
        return ctx.makeImage()
    }
    func writeImage(to url: URL) throws {
        guard let image = image else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError)
        }
        try image.write(to: url, fileType: fileType)
    }
}

final class SceneMovieRenderer {
    static func UTTypeWithAVFileType(_ fileType: AVFileType) -> String? {
        switch fileType {
        case .mp4:
            return String(kUTTypeMPEG4)
        case .mov:
            return String(kUTTypeQuickTimeMovie)
        default:
            return nil
        }
    }
    
    let scene: Scene, renderSize: CGSize, fileType: AVFileType, codec: String
    init(scene: Scene, renderSize: CGSize,
         fileType: AVFileType = .mp4, codec: String = AVVideoCodecH264) {
        
        self.scene = scene
        self.renderSize = renderSize
        self.fileType = fileType
        self.codec = codec
        
        let scale = renderSize.width / scene.frame.size.width
        self.screenTransform = Transform(translation: CGPoint(x: renderSize.width / 2,
                                                              y: renderSize.height / 2),
                                         scale: CGPoint(x: scale, y: scale),
                                         rotation: 0)
        drawLayer.bounds.size = renderSize
        drawLayer.drawBlock = { [unowned self] ctx in
            ctx.concatenate(scene.viewTransform.affineTransform)
            self.scene.editCut.draw(scene: self.scene, viewType: .preview, in: ctx)
        }
    }
    
    let drawLayer = DrawLayer()
    var screenTransform = Transform()
    
    func writeMovie(to url: URL,
                    progressClosure: @escaping (CGFloat, UnsafeMutablePointer<Bool>) -> Void,
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
        
        let writer = try AVAssetWriter(outputURL: url, fileType: fileType)
        
        let width = renderSize.width, height = renderSize.height
        let setting: [String: Any] = [AVVideoCodecKey: codec,
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
        
        let allFrameCount = scene.frameTime(withBeatTime: scene.duration)
        let timeScale = Int32(scene.frameRate)
        
        var append = false, stop = false
        for i in 0 ..< allFrameCount {
            autoreleasepool {
                while !writerInput.isReadyForMoreMediaData {
                    progressClosure(i.cf / (allFrameCount - 1).cf, &stop)
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
                    let cutTime = scene.cutTime(withFrameTime: i)
                    scene.editCutIndex = cutTime.cutItemIndex
                    cutTime.cut.currentTime = cutTime.time
                    drawLayer.render(in: ctx)
                }
                CVPixelBufferUnlockBaseAddress(pb, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
                append = adaptor.append(pb, withPresentationTime: CMTime(value: Int64(i),
                                                                         timescale: timeScale))
            }
            if !append {
                break
            }
            progressClosure(i.cf / (allFrameCount - 1).cf, &stop)
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
                if let audioURL = self.scene.sound.url {
                    do {
                        try self.wrireAudio(to: url, self.fileType, audioURL: audioURL) { error in
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
        
        guard let assetExportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw NSError(domain: AVFoundationErrorDomain, code: AVError.Code.exportFailed.rawValue)
        }
        assetExportSession.outputFileType = fileType
        assetExportSession.outputURL = tempURL
        assetExportSession.exportAsynchronously { [unowned assetExportSession] in
            let fileManager = FileManager.default
            do {
                try _ = fileManager.replaceItemAt(videoURL, withItemAt: tempURL)
                if fileManager.fileExists(atPath: tempURL.path) {
                    try fileManager.removeItem(at: tempURL)
                }
                completionClosure(assetExportSession.error)
            } catch {
                completionClosure(error)
            }
        }
    }
}

final class RendererManager {
    weak var progressesEdgeLayer: Layer?
    lazy var scene = Scene()
    var rendingContentScale = 1.0.cf
    
    var renderQueue = OperationQueue()
    
    init() {
    }
    deinit {
        renderQueue.cancelAllOperations()
    }
    
    var bars = [ProgressNumberView]()
    func beginProgress(_ progressBar: ProgressNumberView) {
        bars.append(progressBar)
        progressesEdgeLayer?.parent?.append(child: progressBar)
        progressBar.begin()
        updateProgresssPosition()
    }
    func endProgress(_ progressBar: ProgressNumberView) {
        progressBar.end()
        if let index = bars.index(where: { $0 === progressBar }) {
            bars[index].removeFromParent()
            bars.remove(at: index)
            updateProgresssPosition()
        }
    }
    private let progressWidth = 200.0.cf
    func updateProgresssPosition() {
        guard let view = progressesEdgeLayer else {
            return
        }
        _ = bars.reduce(CGPoint(x: view.frame.origin.x, y: view.frame.maxY)) {
            $1.frame.origin = $0
            return CGPoint(x: $0.x + progressWidth, y: $0.y)
        }
    }
    
    func exportMovie(message: String?, name: String? = nil, size: CGSize,
                     fileType: AVFileType = .mp4, codec: String = AVVideoCodecH264,
                     isSelectedCutOnly: Bool = false) -> Bool {
        guard let utType = SceneMovieRenderer.UTTypeWithAVFileType(fileType) else {
            return true
        }
        URL.file(message: message, name: nil, fileTypes: [utType]) { [unowned self] e in
            let renderer = SceneMovieRenderer(scene: self.scene.copied,
                                              renderSize: size, fileType: fileType, codec: codec)
            
            let progressBar = ProgressNumberView(frame: CGRect(x: 0, y: 0,
                                                               width: self.progressWidth,
                                                               height: Layout.basicHeight),
                                                 name: e.url.deletingPathExtension().lastPathComponent,
                                                 type: e.url.pathExtension.uppercased(),
                                                 state: Localization(english: "Exporting",
                                                                     japanese: "書き出し中"))
            let operation = BlockOperation()
            progressBar.operation = operation
            progressBar.deleteClosure = { [unowned self] in
                self.endProgress($0)
                return true
            }
            self.beginProgress(progressBar)
            
            operation.addExecutionBlock() { [unowned operation] in
                let progressClosure: (CGFloat, UnsafeMutablePointer<Bool>) -> () =
                { (totalProgress, stop) in
                    if operation.isCancelled {
                        stop.pointee = true
                    } else {
                        OperationQueue.main.addOperation() {
                            progressBar.value = totalProgress
                        }
                    }
                }
                let completionClosure: (Error?) -> () = { (error) in
                    do {
                        if let error = error {
                            throw error
                        }
                        OperationQueue.main.addOperation() {
                            progressBar.value = 1
                        }
                        try FileManager.default.setAttributes([.extensionHidden: e.isExtensionHidden],
                                                              ofItemAtPath: e.url.path)
                        OperationQueue.main.addOperation() {
                            self.endProgress(progressBar)
                        }
                    } catch {
                        OperationQueue.main.addOperation() {
                            progressBar.state = Localization(english: "Error", japanese: "エラー")
                            progressBar.nameView.textFrame.color = .warning
                        }
                    }
                }
                do {
                    try renderer.writeMovie(to: e.url,
                                            progressClosure: progressClosure,
                                            completionClosure: completionClosure)
                } catch {
                    OperationQueue.main.addOperation() {
                        progressBar.state = Localization(english: "Error", japanese: "エラー")
                        progressBar.nameView.textFrame.color = .warning
                    }
                }
            }
            self.renderQueue.addOperation(operation)
        }
        return true
    }
    
    func exportImage(message: String?, size: CGSize) -> Bool {
        URL.file(message: message, name: nil, fileTypes: [kUTTypePNG as String]) {
            [unowned self] exportURL in
            
            let renderer = SceneImageRendedrer(scene: self.scene.copied,
                                               renderSize: size,
                                               cut: self.scene.editCut)
            do {
                try renderer.writeImage(to: exportURL.url)
                try FileManager.default.setAttributes([.extensionHidden: exportURL.isExtensionHidden],
                                                      ofItemAtPath: exportURL.url.path)
            } catch {
                self.showError(withName: exportURL.name)
            }
        }
        return true
    }
    
    func exportSubtitles() -> Bool {
        let message = Localization(english: "Export Subtitles",
                                   japanese: "字幕として書き出す").currentString
        URL.file(message: message, name: nil, fileTypes: ["vtt"]) { [unowned self] exportURL in
            let vttData = self.scene.vtt
            do {
                try vttData?.write(to: exportURL.url)
                try FileManager.default.setAttributes([.extensionHidden: exportURL.isExtensionHidden],
                                                      ofItemAtPath: exportURL.url.path)
            } catch {
                self.showError(withName: exportURL.name)
            }
        }
        return true
    }
    
    func showError(withName name: String) {
        let progressBar = ProgressNumberView()
        progressBar.name = name
        progressBar.state = Localization(english: "Error", japanese: "エラー")
        progressBar.nameView.textFrame.color = .warning
        progressBar.deleteClosure = { [unowned self] in
            self.endProgress($0)
            return true
        }
        beginProgress(progressBar)
    }
}
