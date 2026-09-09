import AppKit
import UniformTypeIdentifiers

/// `Macview --selftest` — checks the parts that have no window: fitting, ordering, decoding.
enum SelfTest {
    static func run() -> Bool {
        var failures: [String] = []

        func expect(_ condition: Bool, _ label: String) {
            if condition {
                print("ok   \(label)")
            } else {
                print("FAIL \(label)")
                failures.append(label)
            }
        }

        // Fitting: never enlarged past one image pixel per screen pixel, always centred.
        let bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
        let small = ImageLayerView.fittedRect(pixelSize: CGSize(width: 200, height: 100), in: bounds)
        expect(small.size == CGSize(width: 200, height: 100), "a small image stays at its own size")
        expect(small.midX == bounds.midX && small.midY == bounds.midY, "a small image is centred")

        let wide = ImageLayerView.fittedRect(pixelSize: CGSize(width: 8000, height: 2000), in: bounds)
        expect(wide.width == 800, "a wide image fills the width")
        expect(wide.height == 200, "a wide image keeps its aspect ratio")
        expect(bounds.contains(wide), "a fitted image stays inside the window")

        let empty = ImageLayerView.fittedRect(pixelSize: .zero, in: bounds)
        expect(empty == .zero, "an empty image asks for no space")

        // Window size on launch: fitted to the image, held between a fifth and seven tenths
        // of the screen.
        let screen = CGSize(width: 1000, height: 1000)
        expect(Viewer.windowSize(imagePixelSize: CGSize(width: 400, height: 300), screenSize: screen)
               == CGSize(width: 400, height: 300), "an ordinary image opens at its own size")
        let huge = Viewer.windowSize(imagePixelSize: CGSize(width: 4000, height: 2000), screenSize: screen)
        expect(huge == CGSize(width: 700, height: 350), "a huge image stops at seven tenths of the screen")
        let tiny = Viewer.windowSize(imagePixelSize: CGSize(width: 32, height: 32), screenSize: screen)
        expect(tiny == CGSize(width: 200, height: 200), "a tiny image still gets a fifth of the screen")

        // Formats: the whole design rests on ImageIO covering these without a decoder of our own.
        for identifier in ["org.webmproject.webp", "public.avif", "public.heic", "public.jpeg-xl"] {
            expect(ImageLoader.supportedTypeIdentifiers.contains(identifier), "ImageIO reads \(identifier)")
        }

        // Ordering: Finder order, wrapping at both ends, non-images left out.
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("macview-selftest-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        for name in ["10.png", "2.png", "1.jpg", "notes.txt"] {
            FileManager.default.createFile(atPath: directory.appendingPathComponent(name).path, contents: Data())
        }
        var playlist = Playlist.around(directory.appendingPathComponent("2.png"))
        expect(playlist.urls.map(\.lastPathComponent) == ["1.jpg", "2.png", "10.png"],
               "images are ordered the way Finder orders them")
        expect(playlist.current?.lastPathComponent == "2.png", "the opened file is the one shown")
        expect(playlist.step(1)?.lastPathComponent == "10.png", "the next image comes after")
        expect(playlist.step(1)?.lastPathComponent == "1.jpg", "the end wraps to the start")
        expect(playlist.step(-1)?.lastPathComponent == "10.png", "the start wraps to the end")
        expect(playlist.jump(to: 0)?.lastPathComponent == "1.jpg", "home reaches the first image")

        // Decoding: a real file, through the same path the window uses.
        if let written = writeTestPNG(to: directory.appendingPathComponent("real.png"), width: 300, height: 120) {
            let decoded = ImageLoader.load(written, maxPixelSize: 100)
            expect(decoded != nil, "a PNG decodes")
            expect(decoded.map { max($0.first.width, $0.first.height) <= 100 } ?? false,
                   "decoding stops at the requested size")
            expect(decoded?.player == nil, "a still image is given no clock")
        } else {
            expect(false, "a test PNG could be written")
        }

        // Animation: frames counted and their delays read, without unpacking them all.
        if let animated = writeTestGIF(to: directory.appendingPathComponent("moving.gif"),
                                       frames: 3, delay: 0.08) {
            let loaded = ImageLoader.load(animated, maxPixelSize: 200)
            expect(loaded?.player?.frameCount == 3, "an animated GIF reports its frames")
            let delays = loaded?.player?.frameDelays ?? []
            expect(delays.count == 3 && delays.allSatisfy { abs($0 - 0.08) < 0.005 },
                   "frame delays are read from the file")
        } else {
            expect(false, "a test GIF could be written")
        }

        print(failures.isEmpty ? "\nall checks passed" : "\n\(failures.count) failed")
        return failures.isEmpty
    }

    private static func writeTestGIF(to url: URL, frames: Int, delay: TimeInterval) -> URL? {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.gif.identifier as CFString, frames, nil) else { return nil }
        let frameProperties = [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]
        ] as CFDictionary
        for step in 0..<frames {
            guard let context = CGContext(
                data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }
            context.setFillColor(gray: CGFloat(step) / CGFloat(frames), alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
            guard let image = context.makeImage() else { return nil }
            CGImageDestinationAddImage(destination, image, frameProperties)
        }
        return CGImageDestinationFinalize(destination) ? url : nil
    }

    private static func writeTestPNG(to url: URL, width: Int, height: Int) -> URL? {
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(
                  url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? url : nil
    }
}
