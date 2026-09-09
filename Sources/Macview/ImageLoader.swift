import AppKit
import UniformTypeIdentifiers

/// Everything the app can open comes from ImageIO. No decoders of our own.
enum ImageLoader {
    static let supportedTypeIdentifiers: Set<String> = {
        let identifiers = (CGImageSourceCopyTypeIdentifiers() as? [String]) ?? []
        return Set(identifiers.map { $0.lowercased() })
    }()

    static func canOpen(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else { return false }
        if supportedTypeIdentifiers.contains(type.identifier.lowercased()) { return true }
        return type.conforms(to: .image)
    }

    /// The first frame, plus a player when there are more frames behind it.
    struct Loaded {
        let first: CGImage
        let player: AnimationPlayer?
    }

    static func load(_ url: URL, maxPixelSize: Int) -> Loaded? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary),
              let first = frame(of: source, at: 0, maxPixelSize: maxPixelSize)
        else { return nil }
        return Loaded(first: first, player: AnimationPlayer(source: source, maxPixelSize: maxPixelSize))
    }

    /// Decoded at most `maxPixelSize` on the long edge, with the EXIF orientation already applied.
    /// The window only ever shows the image fitted, so a full-resolution buffer would be paid for
    /// and thrown away.
    static func frame(of source: CGImageSource, at index: Int, maxPixelSize: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary)
    }
}
