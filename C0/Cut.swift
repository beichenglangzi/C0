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

final class CutTrack: NSObject, Track, NSCoding {
    private(set) var animation: Animation
    
    static let dataModelKey = "cutTrack"
    var differentialDataModel = DataModel(key: CutTrack.dataModelKey, directoryWithDataModels: []) {
        didSet {
            var nodeDic = [String: Node]()
            cutItem.keyCuts.forEach { cut in
                cut.rootNode.allChildren { (node) in
                    nodeDic[node.key.uuidString] = node
                }
            }
            differentialDataModel.children.forEach { (key, dataModel) in
                nodeDic[key]?.differentialDataModel = dataModel
            }
        }
    }
    func insert(_ cut: Cut, at index: Int) {
        cutItem.keyCuts.insert(cut, at: index)
        let cutTime = index == animation.keyframes.count ? animation.duration : time(at: index)
        let keyframe = Keyframe(time: cutTime, easing: Easing(),
                                interpolation: .none, loop: .none, label: .main)
        animation.keyframes.insert(keyframe, at: index)
        updateCutTimeAndDuration()
        cut.rootNode.allChildren { differentialDataModel.insert($0.differentialDataModel) }
    }
    func removeCut(at index: Int) {
        let cut = cutItem.keyCuts[index]
        cutItem.keyCuts.remove(at: index)
        animation.keyframes.remove(at: index)
        updateCutTimeAndDuration()
        cut.rootNode.allChildren { differentialDataModel.remove($0.differentialDataModel) }
    }
    
    let cutItem: CutItem
    
    var time: Beat {
        didSet {
            updateInterpolation()
        }
    }
    func updateInterpolation() {
        animation.update(withTime: time, to: self)
    }
    func step(_ f0: Int) {
        cutItem.step(f0)
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        cutItem.linear(f0, f1, t: t)
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        cutItem.firstMonospline(f1, f2, f3, with: ms)
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        cutItem.monospline(f0, f1, f2, f3, with: ms)
    }
    func lastMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with ms: Monospline) {
        cutItem.lastMonospline(f0, f1, f2, with: ms)
    }
    
    init(animation: Animation = Animation(), time: Beat = 0, cutItem: CutItem = CutItem()) {
        guard animation.keyframes.count == cutItem.keyCuts.count else {
            fatalError()
        }
        self.animation = animation
        self.time = time
        self.cutItem = cutItem
        super.init()
        cutItem.keyCuts.forEach { cut in
            cut.rootNode.allChildren { node in
                differentialDataModel.insert(node.differentialDataModel)
            }
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case animation, time, cutItem
    }
    init?(coder: NSCoder) {
        animation = coder.decodeDecodable(
            Animation.self, forKey: CodingKeys.animation.rawValue) ?? Animation()
        time = coder.decodeDecodable(Beat.self, forKey: CodingKeys.time.rawValue) ?? 0
        cutItem = coder.decodeObject(forKey: CodingKeys.cutItem.rawValue) as? CutItem ?? CutItem()
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encodeEncodable(animation, forKey: CodingKeys.animation.rawValue)
        coder.encodeEncodable(time, forKey: CodingKeys.time.rawValue)
        coder.encode(cutItem, forKey: CodingKeys.cutItem.rawValue)
    }
    
    func index(atTime time: Beat) -> Int {
        return animation.loopFrames[animation.loopedKeyframeIndex(withTime: time).loopFrameIndex].index
    }
    func time(at index: Int) -> Beat {
        return animation.loopFrames[index].time
    }
    
    func updateCutTimeAndDuration() {
        animation.duration = cutItem.keyCuts.enumerated().reduce(Beat(0)) {
            animation.keyframes[$1.offset].time = $0
            return $0 + $1.element.duration
        }
    }
    
    func cutIndex(withTime time: Beat) -> (index: Int, interTime: Beat, isOver: Bool) {
        guard cutItem.keyCuts.count > 1 else {
            return (0, time, animation.duration <= time)
        }
        let lfi = animation.loopedKeyframeIndex(withTime: time)
        return (lfi.keyframeIndex, lfi.interTime, animation.duration <= time)
    }
    func movingCutIndex(withTime time: Beat) -> Int {
        guard cutItem.keyCuts.count > 1 else {
            return 0
        }
        for i in 1 ..< cutItem.keyCuts.count {
            if time <= cutItem.keyCuts[i].currentTime {
                return i - 1
            }
        }
        return cutItem.keyCuts.count - 1
    }
}
extension CutTrack: Copying {
    func copied(from copier: Copier) -> CutTrack {
        return CutTrack(animation: animation, time: time, cutItem: copier.copied(cutItem))
    }
}
extension CutTrack: Referenceable {
    static let name = Localization(english: "Cut Track", japanese: "カットトラック")
}

final class CutItem: NSObject, TrackItem, NSCoding {
    fileprivate(set) var keyCuts: [Cut]
    var cut: Cut
    
    func step(_ f0: Int) {
        cut = keyCuts[f0]
    }
    func linear(_ f0: Int, _ f1: Int, t: CGFloat) {
        cut = keyCuts[f0]
    }
    func firstMonospline(_ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        cut = keyCuts[f1]
    }
    func monospline(_ f0: Int, _ f1: Int, _ f2: Int, _ f3: Int, with ms: Monospline) {
        cut = keyCuts[f1]
    }
    func lastMonospline(_ f0: Int, _ f1: Int, _ f2: Int, with ms: Monospline) {
        cut = keyCuts[f1]
    }
    
    init(keyCuts: [Cut] = [], cut: Cut = Cut()) {
        if keyCuts.isEmpty {
            self.keyCuts = [cut]
        } else {
            self.keyCuts = keyCuts
        }
        self.cut = cut
        super.init()
    }
    
    private enum CodingKeys: String, CodingKey {
        case keyCuts, cut
    }
    init?(coder: NSCoder) {
        keyCuts = coder.decodeObject(forKey: CodingKeys.keyCuts.rawValue) as? [Cut] ?? []
        cut = coder.decodeObject(forKey: CodingKeys.cut.rawValue) as? Cut ?? Cut()
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(keyCuts, forKey: CodingKeys.keyCuts.rawValue)
        coder.encode(cut, forKey: CodingKeys.cut.rawValue)
    }
}
extension CutItem: Copying {
    func copied(from copier: Copier) -> CutItem {
        return CutItem(keyCuts: keyCuts.map { copier.copied($0) }, cut: copier.copied(cut))
    }
}

/**
 # Issue
 - 変更通知
 */
final class Cut: NSObject, NSCoding {
    enum ViewType: Int8 {
        case
        preview, edit,
        editPoint, editVertex, editMoveZ,
        editWarp, editTransform, editSelected, editDeselected,
        editMaterial, changingMaterial
    }
    
    var rootNode: Node
    var editNode: Node {
        didSet {
            if editNode != oldValue {
                oldValue.isEdited = false
                editNode.isEdited = true
            }
        }
    }
    
    let subtitleTrack: SubtitleTrack
    
    var currentTime: Beat {
        didSet {
            updateWithTime()
        }
    }
    func updateWithTime() {
        rootNode.time = currentTime
        subtitleTrack.time = currentTime
    }
    var duration: Beat {
        didSet {
            subtitleTrack.replace(duration: duration)
        }
    }
    
    init(rootNode: Node = Node(tracks: [NodeTrack(animation: Animation(duration: 0))]),
         editNode: Node = Node(name: Localization(english: "Node 0",
                                                  japanese: "ノード0").currentString),
         subtitleTrack: SubtitleTrack = SubtitleTrack(),
         currentTime: Beat = 0) {
        
        editNode.editTrack.name = Localization(english: "Track 0", japanese: "トラック0").currentString
        if rootNode.children.isEmpty {
            let node = Node(name: Localization(english: "Root", japanese: "ルート").currentString)
            node.editTrack.name = Localization(english: "Track 0", japanese: "トラック0").currentString
            node.children.append(editNode)
            rootNode.children.append(node)
        }
        self.rootNode = rootNode
        self.editNode = editNode
        self.subtitleTrack = subtitleTrack
        self.currentTime = currentTime
        self.duration = rootNode.maxDuration
        subtitleTrack.replace(duration: duration)
        rootNode.time = currentTime
        rootNode.isEdited = true
        editNode.isEdited = true
        super.init()
    }
    
    private enum CodingKeys: String, CodingKey {
        case rootNode, editNode, subtitleTrack, time, duration
    }
    init?(coder: NSCoder) {
        rootNode = coder.decodeObject(forKey: CodingKeys.rootNode.rawValue) as? Node ?? Node()
        editNode = coder.decodeObject(forKey: CodingKeys.editNode.rawValue) as? Node ?? Node()
        rootNode.isEdited = true
        editNode.isEdited = true
        subtitleTrack = coder.decodeObject(
            forKey: CodingKeys.subtitleTrack.rawValue) as? SubtitleTrack ?? SubtitleTrack()
        currentTime = coder.decodeDecodable(Beat.self, forKey: CodingKeys.time.rawValue) ?? 0
        duration = coder.decodeDecodable(Beat.self, forKey: CodingKeys.duration.rawValue) ?? 0
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(rootNode, forKey: CodingKeys.rootNode.rawValue)
        coder.encode(editNode, forKey: CodingKeys.editNode.rawValue)
        coder.encode(subtitleTrack, forKey: CodingKeys.subtitleTrack.rawValue)
        coder.encodeEncodable(currentTime, forKey: CodingKeys.time.rawValue)
        coder.encodeEncodable(duration, forKey: CodingKeys.duration.rawValue)
    }
    
    var imageBounds: CGRect {
        return rootNode.imageBounds
    }
    
    func read() {
        rootNode.allChildren { $0.read() }
    }
    
    func draw(scene: Scene, viewType: Cut.ViewType, in ctx: CGContext) {
        if viewType == .preview {
            ctx.saveGState()
            rootNode.draw(scene: scene, viewType: viewType,
                          scale: 1, rotation: 0,
                          viewScale: 1, viewRotation: 0,
                          in: ctx)
            if !scene.isHiddenSubtitles {
                subtitleTrack.drawSubtitle.draw(bounds: scene.frame, in: ctx)
            }
            ctx.restoreGState()
        } else {
            ctx.saveGState()
            ctx.concatenate(scene.viewTransform.affineTransform)
            rootNode.draw(scene: scene, viewType: viewType,
                          scale: 1, rotation: 0,
                          viewScale: scene.scale, viewRotation: scene.viewTransform.rotation,
                          in: ctx)
            ctx.restoreGState()
        }
    }
    
    func drawCautionBorder(scene: Scene, bounds: CGRect, in ctx: CGContext) {
        func drawBorderWith(bounds: CGRect, width: CGFloat, color: Color, in ctx: CGContext) {
            ctx.setFillColor(color.cgColor)
            ctx.fill([CGRect(x: bounds.minX, y: bounds.minY,
                             width: width, height: bounds.height),
                      CGRect(x: bounds.minX + width, y: bounds.minY,
                             width: bounds.width - width * 2, height: width),
                      CGRect(x: bounds.minX + width, y: bounds.maxY - width,
                             width: bounds.width - width * 2, height: width),
                      CGRect(x: bounds.maxX - width, y: bounds.minY,
                             width: width, height: bounds.height)])
        }
        if scene.viewTransform.rotation > .pi / 2 || scene.viewTransform.rotation < -.pi / 2 {
            let borderWidth = 2.0.cf
            drawBorderWith(bounds: bounds, width: borderWidth * 2, color: .warning, in: ctx)
            let textLine = TextFrame(string: "\(Int(scene.viewTransform.rotation * 180 / (.pi)))°",
                font: .bold, color: .warning)
            let sb = textLine.typographicBounds.insetBy(dx: -10, dy: -2).integral
            textLine.draw(in: CGRect(x: bounds.minX + (bounds.width - sb.width) / 2,
                                     y: bounds.minY + bounds.height - sb.height - borderWidth,
                                     width: sb.width, height: sb.height),
                          in: ctx)
        }
    }
    
    var cells: [Cell] {
        var cells = [Cell]()
        rootNode.allChildrenAndSelf { cells += $0.rootCell.allCells }
        return cells
    }
    
    var maxDuration: Beat {
        var maxDuration = editNode.editTrack.animation.duration
        rootNode.children.forEach { node in
            node.tracks.forEach {
                let duration = $0.animation.duration
                if duration > maxDuration {
                    maxDuration = duration
                }
            }
        }
        return maxDuration
    }
    
    struct NodeAndTrack: Equatable {
        let node: Node, trackIndex: Int
        var track: NodeTrack {
            return node.tracks[trackIndex]
        }
        static func ==(lhs: NodeAndTrack, rhs: NodeAndTrack) -> Bool {
            return lhs.node == rhs.node && lhs.trackIndex == rhs.trackIndex
        }
    }
    func nodeAndTrackIndex(with nodeAndTrack: NodeAndTrack) -> Int {
        var index = 0, stop = false
        func maxNodeAndTrackIndexRecursion(_ node: Node) {
            for child in node.children {
                maxNodeAndTrackIndexRecursion(child)
                if stop {
                    return
                }
            }
            if node == nodeAndTrack.node {
                index += nodeAndTrack.trackIndex
                stop = true
                return
            }
            if !stop {
                index += node.tracks.count
            }
        }
        for child in rootNode.children {
            maxNodeAndTrackIndexRecursion(child)
            if stop {
                break
            }
        }
        return index
    }
    func nodeAndTrack(atNodeAndTrackIndex nodeAndTrackIndex: Int) -> NodeAndTrack {
        var index = 0, stop = false
        var nodeAndTrack = NodeAndTrack(node: rootNode, trackIndex: 0)
        func maxNodeAndTrackIndexRecursion(_ node: Node) {
            for child in node.children {
                maxNodeAndTrackIndexRecursion(child)
                if stop {
                    return
                }
            }
            let newIndex = index + node.tracks.count
            if index <= nodeAndTrackIndex && newIndex > nodeAndTrackIndex {
                nodeAndTrack = NodeAndTrack(node: node, trackIndex: nodeAndTrackIndex - index)
                stop = true
                return
            }
            index = newIndex
            
        }
        for child in rootNode.children {
            maxNodeAndTrackIndexRecursion(child)
            if stop {
                break
            }
        }
        return nodeAndTrack
    }
    var editNodeAndTrack: NodeAndTrack {
        get {
            let node = editNode
            return NodeAndTrack(node: node, trackIndex: node.editTrackIndex)
        }
        set {
            editNode = newValue.node
            if newValue.trackIndex < newValue.node.tracks.count {
                newValue.node.editTrackIndex = newValue.trackIndex
            }
        }
    }
    var editNodeAndTrackIndex: Int {
        return nodeAndTrackIndex(with: editNodeAndTrack)
    }
    var maxNodeAndTrackIndex: Int {
        func maxNodeAndTrackIndexRecursion(_ node: Node) -> Int {
            let count = node.children.reduce(0) { $0 + maxNodeAndTrackIndexRecursion($1) }
            return count + node.tracks.count
        }
        return maxNodeAndTrackIndexRecursion(rootNode) - 2
    }
    
    func node(atTreeNodeIndex ti: Int) -> Node {
        var i = 0, node: Node?
        rootNode.allChildren { (aNode, stop) in
            if i == ti {
                node = aNode
                stop = true
            } else {
                i += 1
            }
        }
        return node!
    }
    var editTreeNodeIndex: Int {
        get {
            var i = 0
            rootNode.allChildren { (node, stop) in
                if node == editNode {
                    stop = true
                } else {
                    i += 1
                }
            }
            return i
        }
        set {
            var i = 0
            rootNode.allChildren { (node, stop) in
                if i == newValue {
                    editNode = node
                    stop = true
                } else {
                    i += 1
                }
            }
        }
    }
    var maxTreeNodeIndex: Int {
        return rootNode.treeNodeCount - 1
    }
}
extension Cut: Copying {
    func copied(from copier: Copier) -> Cut {
        return Cut(rootNode: copier.copied(rootNode), editNode: copier.copied(editNode),
                   subtitleTrack: copier.copied(subtitleTrack),
                   currentTime: currentTime)
    }
}
extension Cut: Referenceable {
    static let name = Localization(english: "Cut", japanese: "カット")
}

final class CutView: Layer, Respondable {
    static let name = Localization(english: "Cut View", japanese: "カット表示")
    
    let nameLabel = Label(font: .small)
    let clipView = Box()
    
    private(set) var editAnimationView: AnimationView {
        didSet {
            oldValue.isSmall = true
            editAnimationView.isSmall = false
            updateChildren()
        }
    }
    private(set) var animationViews: [AnimationView]
    
    let subtitleAnimationView: AnimationView
    var subtitleTextViews = [TextView]()
    
    func animationView(with nodeAndTrack: Cut.NodeAndTrack) -> AnimationView {
        let index = cut.nodeAndTrackIndex(with: nodeAndTrack)
        return animationViews[index]
    }
    func animationViews(with node: Node) -> [AnimationView] {
        var animationViews = [AnimationView]()
        tracks(from: node) { (_, _, i) in
            animationViews.append(self.animationViews[i])
        }
        return animationViews
    }
    func tracks(handler: (Node, NodeTrack, Int) -> ()) {
        CutView.tracks(with: cut, handler: handler)
    }
    func tracks(from node: Node, handler: (Node, NodeTrack, Int) -> ()) {
        CutView.tracks(from: node, with: cut, handler: handler)
    }
    static func tracks(with node: Node, handler: (Node, NodeTrack, Int) -> ()) {
        var i = 0
        node.allChildrenAndSelf { aNode in
            aNode.tracks.forEach { track in
                handler(aNode, track, i)
                i += 1
            }
        }
    }
    static func tracks(with cut: Cut, handler: (Node, NodeTrack, Int) -> ()) {
        var i = 0
        cut.rootNode.allChildren { node in
            node.tracks.forEach { track in
                handler(node, track, i)
                i += 1
            }
        }
    }
    static func tracks(from node: Node, with cut: Cut, handler: (Node, NodeTrack, Int) -> ()) {
        tracks(with: cut) { (aNode, track, i) in
            aNode.allParentsAndSelf { (n) -> (Bool) in
                if node == n {
                    handler(aNode, track, i)
                    return true
                } else {
                    return false
                }
            }
            
        }
    }
    static func animationView(with track: Track, beginBaseTime: Beat,
                              baseTimeInterval: Beat, isSmall: Bool) -> AnimationView {
        return AnimationView(track.animation,
                             beginBaseTime: beginBaseTime,
                             baseTimeInterval: baseTimeInterval,
                             isSmall: isSmall)
    }
    func newAnimationView(with track: NodeTrack, node: Node, isSmall: Bool) -> AnimationView {
        let animationView = CutView.animationView(with: track, beginBaseTime: beginBaseTime,
                                                  baseTimeInterval: baseTimeInterval,
                                                  isSmall: isSmall)
        animationView.frame.size.width = frame.width
        bind(in: animationView, from: node, from: track)
        return animationView
    }
    func newAnimationViews(with node: Node) -> [AnimationView] {
        var animationViews = [AnimationView]()
        CutView.tracks(with: node) { (node, track, index) in
            let animationView = CutView.animationView(with: track, beginBaseTime: beginBaseTime,
                                                      baseTimeInterval: baseTimeInterval,
                                                      isSmall: false)
            animationView.frame.size.width = frame.width
            bind(in: animationView, from: node, from: track)
            animationViews.append(animationView)
        }
        return animationViews
    }
    
    let cut: Cut
    init(_ cut: Cut,
         beginBaseTime: Beat = 0,
         baseWidth: CGFloat, baseTimeInterval: Beat,
         knobHalfHeight: CGFloat, subKnobHalfHeight: CGFloat, maxLineWidth: CGFloat, height: CGFloat) {
        
        nameLabel.fillColor = nil
        clipView.isClipped = true
        
        self.cut = cut
        self.beginBaseTime = beginBaseTime
        self.baseWidth = baseWidth
        self.baseTimeInterval = baseTimeInterval
        self.knobHalfHeight = knobHalfHeight
        self.subKnobHalfHeight = subKnobHalfHeight
        self.maxLineWidth = maxLineWidth
        
        let editNode = cut.editNode
        var animationViews = [AnimationView](), editAnimationView = AnimationView()
        CutView.tracks(with: cut) { (node, track, index) in
            let isEdit = node === editNode && track == editNode.editTrack
            let animationView = AnimationView(track.animation,
                                              baseTimeInterval: baseTimeInterval,
                                              isSmall: !isEdit)
            animationViews.append(animationView)
            if isEdit {
                editAnimationView = animationView
            }
        }
        self.animationViews = animationViews
        self.editAnimationView = editAnimationView
        
        subtitleAnimationView = CutView.animationView(with: cut.subtitleTrack,
                                                    beginBaseTime: beginBaseTime,
                                                    baseTimeInterval: baseTimeInterval,
                                                    isSmall: true)
        
        super.init()
        clipView.replace(children: animationViews)
        replace(children: [clipView, nameLabel])
        frame.size.height = height
        updateLayout()
        updateWithDuration()
        
        let subtitleItem = cut.subtitleTrack.subtitleItem
        subtitleTextViews = subtitleItem.keySubtitles.enumerated().map { (i, subtitle) in
            let textView = TextView()
            textView.isLocked = false
            textView.string = subtitle.string
            textView.noIndicatedLineColor = .border
            textView.indicatedLineColor = .indicated
            textView.fillColor = nil
            textView.binding = {
                cut.subtitleTrack.replace(Subtitle(string: $0.text, isConnectedWithPrevious: false),
                                          at: i)
            }
            return textView
        }
        subtitleAnimationView.setKeyframeHandler = { [unowned self] ab in
            guard ab.type == .end else {
                return
            }
            switch ab.setType {
            case .insert:
                let subtitle = Subtitle()
                let textView = TextView()
                textView.isLocked = false
                textView.noIndicatedLineColor = .border
                textView.indicatedLineColor = .indicated
                textView.fillColor = nil
                textView.string = subtitle.string
                textView.binding = {
                    cut.subtitleTrack.replace(Subtitle(string: $0.text,
                                                       isConnectedWithPrevious: false),
                                              at: ab.index)
                }
                cut.subtitleTrack.insert(ab.keyframe,
                                         SubtitleTrack.KeyframeValues(subtitle: subtitle),
                                         at: ab.index)
                self.subtitleTextViews.insert(textView, at: ab.index)
                self.subtitleKeyframeBinding?(SubtitleKeyframeBinding(cutView: self,
                                                                      keyframe: ab.keyframe,
                                                                      subtitle: subtitle,
                                                                      index: ab.index,
                                                                      setType: ab.setType,
                                                                      animation: ab.animation,
                                                                      oldAnimation: ab.oldAnimation,
                                                                      type: ab.type))
            case .remove:
                let subtitle = cut.subtitleTrack.subtitleItem.keySubtitles[ab.index]
                cut.subtitleTrack.removeKeyframe(at: ab.index)
                self.subtitleTextViews.remove(at: ab.index)
                self.subtitleKeyframeBinding?(SubtitleKeyframeBinding(cutView: self,
                                                                      keyframe: ab.keyframe,
                                                                      subtitle: subtitle,
                                                                      index: ab.index,
                                                                      setType: ab.setType,
                                                                      animation: ab.animation,
                                                                      oldAnimation: ab.oldAnimation,
                                                                      type: ab.type))
            case .replace:
                break
            }
        }
        subtitleAnimationView.slideHandler = {
            cut.subtitleTrack.replace($0.animation.keyframes)
        }
        
        animationViews.enumerated().forEach { (i, animationView) in
            let nodeAndTrack = cut.nodeAndTrack(atNodeAndTrackIndex: i)
            bind(in: animationView, from: nodeAndTrack.node, from: nodeAndTrack.track)
        }
    }
    
    struct SubtitleBinding {
        let cutView: CutView
        let subtitle: Subtitle, oldSubtitle: Subtitle, type: Action.SendType
    }
    var subtitleBinding: ((SubtitleBinding) -> ())?
    struct SubtitleKeyframeBinding {
        let cutView: CutView
        let keyframe: Keyframe, subtitle: Subtitle, index: Int, setType: AnimationView.SetKeyframeType
        let animation: Animation, oldAnimation: Animation, type: Action.SendType
    }
    var subtitleKeyframeBinding: ((SubtitleKeyframeBinding) -> ())?
    
    func bind(in animationView: AnimationView, from node: Node, from track: NodeTrack) {
        animationView.splitKeyframeLabelHandler = { (keyframe, _) in
            track.isEmptyGeometryWithCells(at: keyframe.time) ? .main : .sub
        }
        animationView.lineColorHandler = { _ in
            track.transformItem != nil ? .camera : .content
        }
        animationView.smallLineColorHandler = {
            track.transformItem != nil ? .camera : .content
        }
        animationView.knobColorHandler = {
            track.drawingItem.keyDrawings[$0].roughLines.isEmpty ? .knob : .timelineRough
        }
    }
    
    var beginBaseTime: Beat {
        didSet {
            tracks { animationViews[$2].beginBaseTime = beginBaseTime }
        }
    }
    
    var baseTimeInterval = Beat(1, 16) {
        didSet {
            animationViews.forEach { $0.baseTimeInterval = baseTimeInterval }
            updateWithDuration()
        }
    }
    
    var isEdit = false {
        didSet {
            animationViews.forEach { $0.isEdit = isEdit }
        }
    }
    
    var baseWidth: CGFloat {
        didSet {
            animationViews.forEach { $0.baseWidth = baseWidth }
            updateChildren()
            updateWithDuration()
        }
    }
    let knobHalfHeight: CGFloat, subKnobHalfHeight: CGFloat
    let maxLineWidth: CGFloat
    
    func x(withTime time: Beat) -> CGFloat {
        return DoubleBeat(time / baseTimeInterval).cf * baseWidth
    }
    
    override var bounds: CGRect {
        didSet {
            updateLayout()
        }
    }
    
    func updateLayout() {
        let sp = Layout.smallPadding
        nameLabel.frame.origin = CGPoint(x: sp, y: bounds.height - nameLabel.frame.height - sp)
        clipView.frame = CGRect(x: 0, y: 0, width: frame.width, height: nameLabel.frame.minY)
        updateChildren()
    }
    func updateIndex(_ i: Int) {
        nameLabel.localization = Localization(english: "Cut\(i)", japanese: "カット\(i)")
    }
    func updateChildren() {
        guard let index = animationViews.index(of: editAnimationView) else {
            return
        }
        let midY = clipView.frame.height / 2
        var y = midY - editAnimationView.frame.height / 2
        editAnimationView.frame.origin = CGPoint(x: 0, y: y)
        for i in (0 ..< index).reversed() {
            let animationView = animationViews[i]
            y -= animationView.frame.height
            animationView.frame.origin = CGPoint(x: 0, y: y)
        }
        y = midY + editAnimationView.frame.height / 2
        for i in (index + 1 ..< animationViews.count) {
            let animationView = animationViews[i]
            animationView.frame.origin = CGPoint(x: 0, y: y)
            y += animationView.frame.height
        }
    }
    func updateWithDuration() {
        frame.size.width = x(withTime: cut.duration)
        animationViews.forEach { $0.frame.size.width = frame.width }
        subtitleAnimationView.frame.size.width = frame.width
    }
    func updateIfChangedEditTrack() {
        editAnimationView.animation = cut.editNode.editTrack.animation
        updateChildren()
    }
    func updateWithTime() {
        tracks { animationViews[$2].updateKeyframeIndex(with: $1.animation) }
    }
    
    var editNodeAndTrack: Cut.NodeAndTrack {
        get {
            return cut.editNodeAndTrack
        }
        set {
            cut.editNodeAndTrack = newValue
            editAnimationView = animationViews[cut.editNodeAndTrackIndex]
        }
    }
    
    func insert(_ node: Node, at index: Int, _ animationViews: [AnimationView], parent: Node) {
        parent.children.insert(node, at: index)
        let nodeAndTrackIndex = cut.nodeAndTrackIndex(with: Cut.NodeAndTrack(node: node,
                                                                             trackIndex: 0))
        self.animationViews.insert(contentsOf: animationViews, at: nodeAndTrackIndex)
        var children = self.clipView.children
        children.insert(contentsOf: animationViews as [Layer], at: nodeAndTrackIndex)
        replace(children: children)
        updateChildren()
    }
    func remove(at index: Int, _ animationViews: [AnimationView], parent: Node) {
        let node = parent.children[index]
        let animationIndex = cut.nodeAndTrackIndex(with: Cut.NodeAndTrack(node: node, trackIndex: 0))
        let maxAnimationIndex = animationIndex + animationViews.count
        parent.children.remove(at: index)
        self.animationViews.removeSubrange(animationIndex..<maxAnimationIndex)
        var children = self.clipView.children
        children.removeSubrange(animationIndex..<maxAnimationIndex)
        replace(children: children)
        updateChildren()
    }
    func insert(_ track: NodeTrack, _ animationView: AnimationView,
                in nodeAndTrack: Cut.NodeAndTrack) {
        let i = cut.nodeAndTrackIndex(with: nodeAndTrack)
        nodeAndTrack.node.tracks.insert(track, at: nodeAndTrack.trackIndex)
        animationViews.insert(animationView, at: i)
        append(child: animationView)
        updateChildren()
    }
    func removeTrack(at nodeAndTrack: Cut.NodeAndTrack) {
        let i = cut.nodeAndTrackIndex(with: nodeAndTrack)
        nodeAndTrack.node.tracks.remove(at: nodeAndTrack.trackIndex)
        animationViews[i].removeFromParent()
        animationViews.remove(at: i)
        updateChildren()
    }
    func set(editTrackIndex: Int, in node: Node) {
        editNodeAndTrack = Cut.NodeAndTrack(node: node, trackIndex: editTrackIndex)
    }
    func moveNode(from oldIndex: Int, fromParemt oldParent: Node,
                  to index: Int, toParent parent: Node) {
        let node = oldParent.children[oldIndex]
        let moveAnimationViews = self.animationViews(with: node)
        let oldNodeAndTrack = Cut.NodeAndTrack(node: node, trackIndex: 0)
        let oldMaxAnimationIndex = cut.nodeAndTrackIndex(with: oldNodeAndTrack)
        let oldAnimationIndex = oldMaxAnimationIndex - (moveAnimationViews.count - 1)
        
        var animationViews = self.animationViews
        
        oldParent.children.remove(at: oldIndex)
        animationViews.removeSubrange(oldAnimationIndex...oldMaxAnimationIndex)
        
        parent.children.insert(node, at: index)
        
        let nodeAndTrack = Cut.NodeAndTrack(node: node, trackIndex: 0)
        let newMaxAnimationIndex = cut.nodeAndTrackIndex(with: nodeAndTrack)
        let newAnimationIndex = newMaxAnimationIndex - (moveAnimationViews.count - 1)
        animationViews.insert(contentsOf: moveAnimationViews, at: newAnimationIndex)
        self.animationViews = animationViews
        editAnimationView = animationViews[cut.editNodeAndTrackIndex]
    }
    func moveTrack(from oldIndex: Int, to index: Int, in node: Node) {
        let editTrack = node.tracks[oldIndex]
        var tracks = node.tracks
        tracks.remove(at: oldIndex)
        tracks.insert(editTrack, at: index)
        node.tracks = tracks
        
        let oldAnimationIndex = cut.nodeAndTrackIndex(with: Cut.NodeAndTrack(node: node,
                                                                             trackIndex: oldIndex))
        let newAnimationIndex = cut.nodeAndTrackIndex(with: Cut.NodeAndTrack(node: node,
                                                                             trackIndex: index))
        let editAnimationView = self.animationViews[oldAnimationIndex]
        var animationViews = self.animationViews
        animationViews.remove(at: oldAnimationIndex)
        animationViews.insert(editAnimationView, at: newAnimationIndex)
        self.animationViews = animationViews
        self.editAnimationView = animationViews[cut.editNodeAndTrackIndex]
    }
    
    var disabledRegisterUndo = true
    
    var isUseUpdateChildren = true
    
    var removeTrackHandler: ((CutView, Int, Node) -> ())?
    func removeTrack() {
        let node = cut.editNode
        if node.tracks.count > 1 {
            removeTrackHandler?(self, node.editTrackIndex, node)
        }
    }
    
    func copy(with event: KeyInputEvent) -> CopiedObject? {
        return CopiedObject(objects: [cut.copied])
    }
    
    var pasteHandler: ((CutView, CopiedObject) -> (Bool))?
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) -> Bool {
        return pasteHandler?(self, copiedObject) ?? false
    }
    
    var deleteHandler: ((CutView) -> (Bool))?
    func delete(with event: KeyInputEvent) -> Bool {
        return deleteHandler?(self) ?? false
    }
    
    private var isScrollTrack = false
    func scroll(with event: ScrollEvent) -> Bool {
        if event.sendType  == .begin {
            isScrollTrack = abs(event.scrollDeltaPoint.x) < abs(event.scrollDeltaPoint.y)
        }
        guard isScrollTrack else {
            return false
        }
        scrollTrack(with: event)
        return true
    }
    
    struct ScrollBinding {
        let cutView: CutView
        let nodeAndTrack: Cut.NodeAndTrack, oldNodeAndTrack: Cut.NodeAndTrack
        let type: Action.SendType
    }
    var scrollHandler: ((ScrollBinding) -> ())?
    
    private struct ScrollObject {
        var oldP = CGPoint(), deltaScrollY = 0.0.cf
        var nodeAndTrackIndex = 0, oldNodeAndTrackIndex = 0
        var oldNodeAndTrack: Cut.NodeAndTrack?
    }
    private var scrollObject = ScrollObject()
    func scrollTrack(with event: ScrollEvent) {
        guard event.scrollMomentumType == nil else {
            return
        }
        let p = point(from: event)
        switch event.sendType {
        case .begin:
            scrollObject = ScrollObject()
            scrollObject.oldP = p
            scrollObject.deltaScrollY = 0
            let editNodeAndTrack = self.editNodeAndTrack
            scrollObject.oldNodeAndTrack = editNodeAndTrack
            scrollObject.oldNodeAndTrackIndex = cut.nodeAndTrackIndex(with: editNodeAndTrack)
            scrollHandler?(ScrollBinding(cutView: self,
                                         nodeAndTrack: editNodeAndTrack,
                                         oldNodeAndTrack: editNodeAndTrack,
                                         type: .begin))
        case .sending:
            guard let oldEditNodeAndTrack = scrollObject.oldNodeAndTrack else {
                return
            }
            scrollObject.deltaScrollY += event.scrollDeltaPoint.y
            let maxIndex = cut.maxNodeAndTrackIndex
            let i = (scrollObject.oldNodeAndTrackIndex - Int(scrollObject.deltaScrollY / 10))
                .clip(min: 0, max: maxIndex)
            if i != scrollObject.nodeAndTrackIndex {
                isUseUpdateChildren = false
                scrollObject.nodeAndTrackIndex = i
                editNodeAndTrack = cut.nodeAndTrack(atNodeAndTrackIndex: i)
                scrollHandler?(ScrollBinding(cutView: self,
                                             nodeAndTrack: editNodeAndTrack,
                                             oldNodeAndTrack: oldEditNodeAndTrack,
                                             type: .sending))
                isUseUpdateChildren = true
            }
        case .end:
            guard let oldEditNodeAndTrack = scrollObject.oldNodeAndTrack else {
                return
            }
            scrollObject.deltaScrollY += event.scrollDeltaPoint.y
            let maxIndex = cut.maxNodeAndTrackIndex
            let i = (scrollObject.oldNodeAndTrackIndex - Int(scrollObject.deltaScrollY / 10))
                .clip(min: 0, max: maxIndex)
            isUseUpdateChildren = false
            editNodeAndTrack = cut.nodeAndTrack(atNodeAndTrackIndex: i)
            scrollHandler?(ScrollBinding(cutView: self,
                                         nodeAndTrack: editNodeAndTrack,
                                         oldNodeAndTrack: oldEditNodeAndTrack,
                                         type: .end))
            isUseUpdateChildren = true
            if i != scrollObject.oldNodeAndTrackIndex {
                registeringUndoManager?.registerUndo(withTarget: self) { [old = editNodeAndTrack] in
                    $0.set(oldEditNodeAndTrack, old: old)
                }
            }
            scrollObject.oldNodeAndTrack = nil
        }
    }
    private func set(_ editNodeAndTrack: Cut.NodeAndTrack, old oldEditNodeAndTrack: Cut.NodeAndTrack) {
        registeringUndoManager?.registerUndo(withTarget: self) {
            $0.set(oldEditNodeAndTrack, old: editNodeAndTrack)
        }
        scrollHandler?(ScrollBinding(cutView: self,
                                     nodeAndTrack: oldEditNodeAndTrack,
                                     oldNodeAndTrack: oldEditNodeAndTrack,
                                     type: .begin))
        isUseUpdateChildren = false
        self.editNodeAndTrack = editNodeAndTrack
        scrollHandler?(ScrollBinding(cutView: self,
                                     nodeAndTrack: oldEditNodeAndTrack,
                                     oldNodeAndTrack: editNodeAndTrack,
                                     type: .end))
        isUseUpdateChildren = true
    }
}
