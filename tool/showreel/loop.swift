// Crops the rotated 4:3 showreel out of a portrait simulator recording,
// turns it back to landscape and makes a seamless loop: the first `fade`
// seconds cross-dissolve from the frames one loop later.
// Usage: swift loop.swift <in.mp4> <out.mp4> <start> <loop> <fade>
import AVFoundation
import Foundation

let args = CommandLine.arguments
let input = URL(fileURLWithPath: args[1])
let output = URL(fileURLWithPath: args[2])
let start = Double(args[3])!
let loop = Double(args[4])!
let fade = Double(args[5])!

func time(_ s: Double) -> CMTime { CMTime(seconds: s, preferredTimescale: 600) }

let asset = AVURLAsset(url: input)
let sema = DispatchSemaphore(value: 0)

Task {
    do {
        let src = try await asset.loadTracks(withMediaType: .video).first!
        let natural = try await src.load(.naturalSize)
        let duration = try await asset.load(.duration).seconds
        print("source \(natural) \(duration)s")
        guard start + loop + fade <= duration else { fatalError("recording too short") }

        // Landscape scene: width = portrait width * 4/3, height = portrait width.
        let w = natural.width
        let sceneW = (w * 4 / 3).rounded()
        let top = ((natural.height - sceneW) / 2).rounded()
        let render = CGSize(width: sceneW, height: w)
        // Portrait (x, y) -> landscape (u, v): u = y - top, v = w - x.
        let transform = CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: -top, ty: w)

        let comp = AVMutableComposition()
        let a = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
        let b = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
        try a.insertTimeRange(CMTimeRange(start: time(start), duration: time(loop)), of: src, at: .zero)
        try b.insertTimeRange(CMTimeRange(start: time(start + loop), duration: time(fade)), of: src, at: .zero)

        let head = AVMutableVideoCompositionInstruction()
        head.timeRange = CMTimeRange(start: .zero, duration: time(fade))
        let headB = AVMutableVideoCompositionLayerInstruction(assetTrack: b)
        headB.setTransform(transform, at: .zero)
        headB.setOpacityRamp(fromStartOpacity: 1, toEndOpacity: 0, timeRange: head.timeRange)
        let headA = AVMutableVideoCompositionLayerInstruction(assetTrack: a)
        headA.setTransform(transform, at: .zero)
        head.layerInstructions = [headB, headA]

        let body = AVMutableVideoCompositionInstruction()
        body.timeRange = CMTimeRange(start: time(fade), duration: time(loop - fade))
        let bodyA = AVMutableVideoCompositionLayerInstruction(assetTrack: a)
        bodyA.setTransform(transform, at: .zero)
        body.layerInstructions = [bodyA]

        let video = AVMutableVideoComposition()
        video.renderSize = render
        video.frameDuration = CMTime(value: 1, timescale: 60)
        video.instructions = [head, body]

        try? FileManager.default.removeItem(at: output)
        let export = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality)!
        export.videoComposition = video
        export.outputURL = output
        export.outputFileType = .mp4
        await export.export()
        if let e = export.error { print("error: \(e)") } else { print("wrote \(output.path) \(render)") }
    } catch {
        print("error: \(error)")
    }
    sema.signal()
}
sema.wait()
