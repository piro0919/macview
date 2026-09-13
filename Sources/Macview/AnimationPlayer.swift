import AppKit

/// Plays the frames of an animated file. ImageIO already holds them; all this adds is a clock.
///
/// Frames are decoded one at a time on a background queue rather than unpacked into memory up
/// front — a long animation would otherwise cost hundreds of megabytes to sit still.
@MainActor
final class AnimationPlayer {
    private let url: URL
    private let delays: [TimeInterval]
    private let maxPixelSize: Int

    /// The clock. Cancelling it is how playback stops — there is no other state to unwind.
    private var clock: Task<Void, Never>?

    var onFrame: ((CGImage) -> Void)?

    nonisolated var frameCount: Int { delays.count }
    nonisolated var frameDelays: [TimeInterval] { delays }

    /// Nil when the file holds a single frame; a still image needs no clock.
    /// The source is read for its frame delays and then let go: the clock opens its own,
    /// so that one image source is never touched from two threads.
    nonisolated init?(url: URL, source: CGImageSource, maxPixelSize: Int) {
        let count = CGImageSourceGetCount(source)
        guard count > 1 else { return nil }
        self.url = url
        self.maxPixelSize = maxPixelSize
        self.delays = (0..<count).map { Self.delay(of: source, at: $0) }
    }

    deinit { clock?.cancel() }

    func start() {
        stop()
        let url = url
        let delays = delays
        let maxPixelSize = maxPixelSize
        clock = Task { [weak self] in
            await Self.play(url: url, delays: delays, maxPixelSize: maxPixelSize) { frame in
                self?.onFrame?(frame)
            }
        }
    }

    func stop() {
        clock?.cancel()
        clock = nil
    }

    /// Runs off the main thread and owns everything it touches: its own image source,
    /// its own index. Only finished frames cross back.
    @concurrent
    private static func play(
        url: URL, delays: [TimeInterval], maxPixelSize: Int,
        show: @escaping @Sendable @MainActor (CGImage) -> Void
    ) async {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary)
        else { return }

        let count = delays.count
        // Frame n is shown, then frame n's own delay is waited out before the next one.
        var next = 1 % count
        while !Task.isCancelled {
            let wait = delays[(next + count - 1) % count]
            guard (try? await Task.sleep(for: .seconds(wait))) != nil else { return }

            guard let image = ImageLoader.frame(of: source, at: next, maxPixelSize: maxPixelSize)
            else { return }
            await show(image)
            next = (next + 1) % count
        }
    }

    /// GIF, APNG, animated WebP and HEICS each keep their frame delay in their own dictionary.
    /// A delay too small to honour is treated as a tenth of a second, the way browsers do.
    nonisolated static func delay(of source: CGImageSource, at index: Int) -> TimeInterval {
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
