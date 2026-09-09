import AppKit

/// One window, one image. The window is the image.
final class Viewer: NSObject, NSWindowDelegate {
    let window: NSWindow

    private let view = ImageLayerView()
    private var playlist: Playlist?
    private var loadToken = 0
    private var hasSizedToFirstImage = false

    /// Nothing is ever shown larger than the screen can resolve, so nothing larger is decoded.
    private static let maxPixelSize: Int = {
        let longest = NSScreen.screens
            .map { max($0.frame.width, $0.frame.height) * $0.backingScaleFactor }
            .max() ?? 2048
        return max(Int(longest.rounded()), 4096)
    }()

    override init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()

        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = ImageLayerView.ground
        window.contentView = view
        window.delegate = self
        window.center()

        view.onKeyDown = { [weak self] event in self?.handle(event) ?? false }
        view.onOpen = { [weak self] urls in self?.open(urls) }
    }

    func showWindow() {
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
    }

    func open(_ urls: [URL]) {
        guard let first = urls.first else { return }
        playlist = Playlist.around(first)
        load(playlist?.current)
    }

    private func step(_ delta: Int) {
        guard playlist != nil else { return }
        load(playlist?.step(delta))
    }

    private func jump(to position: Int) {
        guard playlist != nil else { return }
        load(playlist?.jump(to: position))
    }

    private func load(_ url: URL?) {
        guard let url else { return }
        loadToken += 1
        let token = loadToken
        window.title = url.lastPathComponent

        DispatchQueue.global(qos: .userInitiated).async {
            let image = ImageLoader.load(url, maxPixelSize: Self.maxPixelSize)
            DispatchQueue.main.async {
                guard token == self.loadToken else { return }
                self.view.show(image)
                if let image, !self.hasSizedToFirstImage {
                    self.hasSizedToFirstImage = true
                    self.sizeWindow(to: image)
                }
            }
        }
    }

    private func sizeWindow(to image: CGImage) {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let size = Self.windowSize(
            imagePixelSize: CGSize(width: image.width, height: image.height),
            screenSize: screen.visibleFrame.size
        )
        window.setContentSize(size)
        window.center()
    }

    /// The window is fitted to the image once, on launch, and then left alone — qView's own
    /// default. Its bounds are qView's too: never below a fifth of the screen, never above
    /// seven tenths of it.
    static let minScreenFraction: CGFloat = 0.20
    static let maxScreenFraction: CGFloat = 0.70

    static func windowSize(imagePixelSize: CGSize, screenSize: CGSize) -> CGSize {
        guard imagePixelSize.width > 0, imagePixelSize.height > 0 else { return screenSize }
        let ceiling = CGSize(width: screenSize.width * maxScreenFraction,
                             height: screenSize.height * maxScreenFraction)
        let floor = CGSize(width: screenSize.width * minScreenFraction,
                           height: screenSize.height * minScreenFraction)
        let ratio = min(ceiling.width / imagePixelSize.width, ceiling.height / imagePixelSize.height, 1)
        return CGSize(
            width: max(imagePixelSize.width * ratio, floor.width).rounded(),
            height: max(imagePixelSize.height * ratio, floor.height).rounded()
        )
    }

    private func handle(_ event: NSEvent) -> Bool {
        switch Int(event.keyCode) {
        case 124, 125, 49:  // right, down, space
            step(1)
        case 123, 126, 51:  // left, up, delete
            step(-1)
        case 115:  // home
            jump(to: 0)
        case 119:  // end
            jump(to: (playlist?.urls.count ?? 1) - 1)
        case 53:  // escape
            window.performClose(nil)
        default:
            return false
        }
        return true
    }
}
