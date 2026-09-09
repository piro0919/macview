import AppKit

/// The whole window is this view. Nothing is drawn except the image and the ground it sits on.
final class ImageLayerView: NSView {
    /// Dark, and fixed: an image is judged against a neutral ground, not against the system theme.
    /// #212121, the same ground qView settles on.
    static let ground = NSColor(srgbRed: 0x21 / 255, green: 0x21 / 255, blue: 0x21 / 255, alpha: 1)

    var onKeyDown: ((NSEvent) -> Bool)?
    var onOpen: (([URL]) -> Void)?

    private let imageLayer = CALayer()
    private var image: CGImage?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = Self.ground.cgColor
        imageLayer.contentsGravity = .resizeAspect
        imageLayer.magnificationFilter = .trilinear
        imageLayer.minificationFilter = .trilinear
        layer?.addSublayer(imageLayer)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { true }

    func show(_ image: CGImage?) {
        self.image = image
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.contents = image
        layoutImageLayer()
        CATransaction.commit()
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layoutImageLayer()
        CATransaction.commit()
    }

    private func layoutImageLayer() {
        guard let image else {
            imageLayer.frame = .zero
            return
        }
        imageLayer.frame = Self.fittedRect(
            pixelSize: CGSize(width: image.width, height: image.height),
            in: bounds
        )
    }

    /// Fits the image inside `bounds`, never enlarging it past its own size.
    static func fittedRect(pixelSize: CGSize, in bounds: CGRect) -> CGRect {
        guard pixelSize.width > 0, pixelSize.height > 0, bounds.width > 0, bounds.height > 0 else {
            return .zero
        }
        let ratio = min(bounds.width / pixelSize.width, bounds.height / pixelSize.height, 1)
        let size = CGSize(width: (pixelSize.width * ratio).rounded(), height: (pixelSize.height * ratio).rounded())
        return CGRect(
            x: ((bounds.width - size.width) / 2).rounded(),
            y: ((bounds.height - size.height) / 2).rounded(),
            width: size.width,
            height: size.height
        )
    }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) == true { return }
        super.keyDown(with: event)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        droppedURLs(sender).isEmpty ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = droppedURLs(sender)
        guard !urls.isEmpty else { return false }
        onOpen?(urls)
        return true
    }

    private func droppedURLs(_ sender: NSDraggingInfo) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] ?? []
        return urls.filter { $0.hasDirectoryPath || ImageLoader.canOpen($0) }
    }
}
