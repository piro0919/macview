import AppKit

/// Plays the frames of an animated file. ImageIO already holds them; all this adds is a clock.
///
/// Frames are decoded one at a time on a background queue rather than unpacked into memory up
/// front — a long animation would otherwise cost hundreds of megabytes to sit still.
final class AnimationPlayer {
    private let source: CGImageSource
    private let delays: [TimeInterval]
    private let maxPixelSize: Int
    private let queue = DispatchQueue(label: "io.kkweb.macview.animation", qos: .userInitiated)

    private var index = 0
    private var generation = 0

    var onFrame: ((CGImage) -> Void)?

    var frameCount: Int { delays.count }
    var frameDelays: [TimeInterval] { delays }

    /// Nil when the file holds a single frame; a still image needs no clock.
    init?(source: CGImageSource, maxPixelSize: Int) {
        let count = CGImageSourceGetCount(source)
        guard count > 1 else { return nil }
        self.source = source
        self.maxPixelSize = maxPixelSize
        self.delays = (0..<count).map { Self.delay(of: source, at: $0) }
    }

    func start() {
        generation += 1
        index = 1 % max(frameCount, 1)
        schedule(after: delays.first ?? 0.1, generation: generation)
    }

    func stop() {
        generation += 1
    }

    private func schedule(after delay: TimeInterval, generation: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, generation == self.generation else { return }
            self.advance(generation: generation)
        }
    }

    private func advance(generation: Int) {
        let frameIndex = index
        queue.async { [weak self] in
            guard let self else { return }
            let image = ImageLoader.frame(of: self.source, at: frameIndex, maxPixelSize: self.maxPixelSize)
            DispatchQueue.main.async {
                guard generation == self.generation else { return }
                if let image { self.onFrame?(image) }
                self.index = (frameIndex + 1) % self.frameCount
                self.schedule(after: self.delays[frameIndex], generation: generation)
            }
        }
    }

    /// GIF, APNG, animated WebP and HEICS each keep their frame delay in their own dictionary.
    /// A delay too small to honour is treated as a tenth of a second, the way browsers do.
    static func delay(of source: CGImageSource, at index: Int) -> TimeInterval {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
        let containers: [(CFString, CFString, CFString)] = [
            (kCGImagePropertyGIFDictionary, kCGImagePropertyGIFUnclampedDelayTime, kCGImagePropertyGIFDelayTime),
            (kCGImagePropertyPNGDictionary, kCGImagePropertyAPNGUnclampedDelayTime, kCGImagePropertyAPNGDelayTime),
            (kCGImagePropertyWebPDictionary, kCGImagePropertyWebPUnclampedDelayTime, kCGImagePropertyWebPDelayTime),
            (kCGImagePropertyHEICSDictionary, kCGImagePropertyHEICSUnclampedDelayTime, kCGImagePropertyHEICSDelayTime),
        ]
        for (container, unclamped, clamped) in containers {
            guard let dictionary = properties?[container] as? [CFString: Any] else { continue }
            let value = (dictionary[unclamped] as? TimeInterval) ?? (dictionary[clamped] as? TimeInterval)
            if let value {
                return value < 0.011 ? 0.1 : value
            }
        }
        return 0.1
    }
}
