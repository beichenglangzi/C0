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
        guard
            let colorSpace = CGColorSpace.with(scene.colorSpace),
            let ctx = CGContext.bitmap(with: renderSize, colorSpace) else {
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
                    progressHandler: @escaping (CGFloat, UnsafeMutablePointer<Bool>) -> Void,
                    completionHandler: @escaping (Error?) -> ()) throws {
        guard
            let colorSpace = CGColorSpace.with(scene.colorSpace),
            let colorSpaceProfile = colorSpace.iccData else {
                throw NSError(domain: AVFoundationErrorDomain,
                              code: AVError.Code.exportFailed.rawValue)
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
        
        let allFrameCount = (scene.duration.p * scene.frameRate) / scene.duration.q
        let timeScale = Int32(scene.frameRate)
        
        var append = false, stop = false
        for i in 0 ..< allFrameCount {
            autoreleasepool {
                while !writerInput.isReadyForMoreMediaData {
                    progressHandler(i.cf / (allFrameCount - 1).cf, &stop)
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
            progressHandler(i.cf / (allFrameCount - 1).cf, &stop)
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
                            completionHandler(error)
                        }
                    } catch {
                        if fileManager.fileExists(atPath: url.path) {
                            try? fileManager.removeItem(at: url)
                        }
                    }
                } else {
                    completionHandler(nil)
                }
            }
        }
    }
    func wrireAudio(to videoURL: URL, _ fileType: AVFileType, audioURL: URL,
                    completionHandler: @escaping (Error?) -> ()) throws {
        
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
                completionHandler(assetExportSession.error)
            } catch {
                completionHandler(error)
            }
        }
    }
}

final class RendererManager {
    weak var progressesEdgeLayer: Layer?
    lazy var scene = Scene()
    var rendingContentScale = 1.0.cf
    let popupBox: PopupBox
    
    var renderQueue = OperationQueue()
    
    init() {
        popupBox = PopupBox(frame: CGRect(x: 0, y: 0, width: 100.0, height: Layout.basicHeight),
                            text: Localization(english: "Export", japanese: "書き出し"))
        popupBox.isSubIndicatedHandler = { [unowned self] isSubIndicated in
            if isSubIndicated {
                self.updatePopupBox(withRendingContentScale: self.rendingContentScale)
            } else {
                self.popupBox.panel.replace(children: [])
            }
        }
    }
    deinit {
        renderQueue.cancelAllOperations()
    }

    func updatePopupBox(withRendingContentScale rendingContentScale: CGFloat) {
        let size = self.scene.frame.size
        let size2 = size * rendingContentScale
        let size720p = CGSize(width: floor((size.width * 720) / size.height), height: 720)
        let size1080p = CGSize(width: floor((size.width * 1080) / size.height), height: 1080)
        let size2160p = CGSize(width: floor((size.width * 2160) / size.height), height: 2160)
        
        let s2String = "w: \(Int(size2.width)) px, h: \(Int(size2.height)) px"
        let s720String = "w: \(Int(size720p.width)) px, h: 720 px"
        let s1080String = "w: \(Int(size1080p.width)) px, h: 1080 px"
        let s2160String = "w: \(Int(size2160p.width)) px, h: 2160 px"
        
        let s2Text = Localization(english: "Export Movie(\(s2String))",
                                  japanese: "動画として書き出す(\(s2String))")
        let s2Handler: (TextBox) -> (Bool) = { [unowned self] in
            self.exportMovie(message: $0.label.string, size: size2, isSelectedCutOnly: false)
        }
        let s720Text = Localization(english: "Export Movie(\(s720String))",
                                    japanese: "動画として書き出す(\(s720String))")
        let s720Handler: (TextBox) -> (Bool) = { [unowned self] in
            self.exportMovie(message: $0.label.string, size: size720p, isSelectedCutOnly: false)
        }
        let s1080Text = Localization(english: "Export Movie(\(s1080String))",
                                     japanese: "動画として書き出す(\(s1080String))")
        let s1080Handler: (TextBox) -> (Bool) = { [unowned self] in
            self.exportMovie(message: $0.label.string, size: size1080p, isSelectedCutOnly: false)
        }
        let s2160Text = Localization(english: "Export Movie(\(s2160String))",
                                     japanese: "動画として書き出す(\(s2160String))")
        let s2160Handler: (TextBox) -> (Bool) = { [unowned self] in
            self.exportMovie(message: $0.label.string, size: size2160p, isSelectedCutOnly: false)
        }
        
        let s2IText = Localization(english: "Export Image(\(s2String))",
                                   japanese: "画像として書き出す(\(s2String))")
        let s2IHandler: (TextBox) -> (Bool) = { [unowned self] in
            self.exportImage(message: $0.label.string, size: size2)
        }
        let s720IText = Localization(english: "Export Image(\(s720String))",
                                     japanese: "画像として書き出す(\(s720String))")
        let s720IHandler: (TextBox) -> (Bool) = { [unowned self] in
            self.exportImage(message: $0.label.string, size: size720p)
        }
        let s1080IText = Localization(english: "Export Image(\(s1080String))",
                                      japanese: "画像として書き出す(\(s1080String))")
        let s1080IHandler: (TextBox) -> (Bool) = { [unowned self] in
            self.exportImage(message: $0.label.string, size: size1080p)
        }
        let s2160IText = Localization(english: "Export Image(\(s2160String))",
                                      japanese: "画像として書き出す(\(s2160String))")
        let s2160IHandler: (TextBox) -> (Bool) = { [unowned self] in
            self.exportImage(message: $0.label.string, size: size2160p)
        }
        
        let subtitleText = Localization(english: "Export Subtitle", japanese: "字幕として書き出す")
        let subtitleHandler: (TextBox) -> (Bool) =  { [unowned self] in
            self.exportSubtitle(message: $0.label.string)
        }
        
        let panel = self.popupBox.panel
        panel.replace(children: [TextBox(name: s2Text, runHandler: s2Handler),
                                 TextBox(name: s720Text, runHandler: s720Handler),
                                 TextBox(name: s1080Text, runHandler: s1080Handler),
                                 TextBox(name: s2160Text, runHandler: s2160Handler),
                                 TextBox(name: s2IText, runHandler: s2IHandler),
                                 TextBox(name: s720IText, runHandler: s720IHandler),
                                 TextBox(name: s1080IText, runHandler: s1080IHandler),
                                 TextBox(name: s2160IText, runHandler: s2160IHandler),
                                 TextBox(name: subtitleText, runHandler: subtitleHandler)])
        var minSize = CGSize()
        Layout.topAlignment(panel.children, minSize: &minSize)
        panel.frame.size = CGSize(width: minSize.width + Layout.basicPadding * 2,
                                  height: minSize.height + Layout.basicPadding * 2)
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
                     isSelectedCutOnly: Bool) -> Bool {
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
            progressBar.deleteHandler = { [unowned self] in
                self.endProgress($0)
                return true
            }
            self.beginProgress(progressBar)
            
            operation.addExecutionBlock() { [unowned operation] in
                let progressHandler: (CGFloat, UnsafeMutablePointer<Bool>) -> () =
                { (totalProgress, stop) in
                    if operation.isCancelled {
                        stop.pointee = true
                    } else {
                        OperationQueue.main.addOperation() {
                            progressBar.value = totalProgress
                        }
                    }
                }
                let completionHandler: (Error?) -> () = { (error) in
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
                            progressBar.nameLabel.textFrame.color = .warning
                        }
                    }
                }
                do {
                    try renderer.writeMovie(to: e.url,
                                            progressHandler: progressHandler,
                                            completionHandler: completionHandler)
                } catch {
                    OperationQueue.main.addOperation() {
                        progressBar.state = Localization(english: "Error", japanese: "エラー")
                        progressBar.nameLabel.textFrame.color = .warning
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
    
    func exportSubtitle(message: String?) -> Bool {
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
        progressBar.nameLabel.textFrame.color = .warning
        progressBar.deleteHandler = { [unowned self] in
            self.endProgress($0)
            return true
        }
        beginProgress(progressBar)
    }
}
