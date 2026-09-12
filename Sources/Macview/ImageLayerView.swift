import AppKit

/// The whole window is this view. Nothing is drawn except the image and the ground it sits on.
@MainActor
final class ImageLayerView: NSView {
    /// Dark, and fixed: an image is judged against a neutral ground, not against the system theme.
    /// #212121, the same ground qView settles on.
    static let ground = NSColor(srgbRed: 0x21 / 255, green: 0x21 / 255, blue: 0x21 / 255, alpha: 1)

    var onKeyDown: ((NSEvent) -> Bool)?
    var onOpen: (([URL]) -> Void)?

    private let imageLayer = CALayer()
    private var image: CGImage?
    private var transform = ViewTransform()
    private var dragOrigin: CGPoint?
    private var restoreFrame: NSRect?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = Self.ground.cgColor
        imageLayer.contentsGravity = .resize
        imageLayer.magnificationFilter = .trilinear
        imageLayer.minificationFilter = .trilinear
        layer?.addSublayer(imageLayer)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { true }

    // MARK: - Content

    /// A new picture arrives fitted and unturned. Keeping the previous turn would leave the
    /// next photograph lying on its side for no reason the reader can see.
    func show(_ image: CGImage?, resettingView resets: Bool) {
        self.image = image
        if resets { transform = ViewTransform() }
        applyLayout()
    }

    /// The same picture, one frame on. The view is left exactly as it was.
    func showFrame(_ image: CGImage) {
        show(image, resettingView: false)
    }

    override func layout() {
        super.layout()
        applyLayout()
    }

    private func applyLayout() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        guard let image else {
            imageLayer.contents = nil
            return
        }
        imageLayer.contents = image

        let pixels = CGSize(width: image.width, height: image.height)
        let scale = transform.scale
            ?? Layout.fitScale(pixelSize: pixels, quarterTurns: transform.quarterTurns, in: bounds.size)
        let unturned = CGSize(width: pixels.width * scale, height: pixels.height * scale)
        let displayed = Layout.turnedSize(unturned, quarterTurns: transform.quarterTurns)
        transform.offset = Layout.clamp(offset: transform.offset, displayed: displayed, in: bounds.size)

        imageLayer.bounds = CGRect(origin: .zero, size: unturned)
        imageLayer.position = CGPoint(
            x: (bounds.midX + transform.offset.x).rounded(),
            y: (bounds.midY + transform.offset.y).rounded()
        )
        // The flips belong to the picture, so they are applied before it is turned.
        var matrix = CATransform3DIdentity
        matrix = CATransform3DRotate(matrix, -.pi / 2 * CGFloat(transform.quarterTurns), 0, 0, 1)
        matrix = CATransform3DScale(
            matrix,
            transform.mirrored ? -1 : 1,
            transform.flipped ? -1 : 1,
            1
        )
        imageLayer.transform = matrix
    }

    // MARK: - Zoom, turn, flip

    /// The size the picture takes up, in image pixels, the way round it is currently shown.
    var pictureSize: CGSize? {
        guard let image else { return nil }
        return Layout.turnedSize(
            CGSize(width: image.width, height: image.height),
            quarterTurns: transform.quarterTurns
        )
    }

    private var currentScale: CGFloat {
        guard let image else { return 1 }
        let pixels = CGSize(width: image.width, height: image.height)
        return transform.scale
            ?? Layout.fitScale(pixelSize: pixels, quarterTurns: transform.quarterTurns, in: bounds.size)
    }

    private var canPan: Bool {
        guard let image else { return false }
        let pixels = CGSize(width: image.width, height: image.height)
        let scaled = CGSize(width: pixels.width * currentScale, height: pixels.height * currentScale)
        let displayed = Layout.turnedSize(scaled, quarterTurns: transform.quarterTurns)
        return displayed.width > bounds.width + 1 || displayed.height > bounds.height + 1
    }

    private func displayedSize(at scale: CGFloat) -> CGSize {
        guard let image else { return .zero }
        let scaled = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        return Layout.turnedSize(scaled, quarterTurns: transform.quarterTurns)
    }

    func zoom(by factor: CGFloat, at cursor: CGPoint?) {
        guard image != nil else { return }
        let old = currentScale
        let new = min(max(old * factor, ViewTransform.minScale), ViewTransform.maxScale)
        guard new != old else { return }
        if let cursor {
            transform.offset = Layout.offsetAnchoring(
                cursor: cursor,
                in: bounds.size,
                offset: transform.offset,
                oldDisplayed: displayedSize(at: old),
                newDisplayed: displayedSize(at: new)
            )
        }
        transform.scale = new
        applyLayout()
    }

    func zoomToFit() {
        transform.scale = nil
        transform.offset = .zero
        applyLayout()
    }

    func zoomToActualSize() {
        transform.scale = 1
        transform.offset = .zero
        applyLayout()
    }

    func turn(by turns: Int) {
        transform.turn(by: turns)
        applyLayout()
    }

    func mirror() {
        transform.mirrored.toggle()
        applyLayout()
    }

    func flip() {
        transform.flipped.toggle()
        applyLayout()
    }

    // MARK: - Menu actions

    // The menu items carry no target, so these are found on the responder chain: the view
    // holding the picture is the one that knows how it is being shown.
    @objc func zoomIn(_ sender: Any?) { zoom(by: ViewTransform.step, at: nil) }
    @objc func zoomOut(_ sender: Any?) { zoom(by: 1 / ViewTransform.step, at: nil) }
    @objc func resetZoom(_ sender: Any?) { zoomToFit() }
    @objc func originalSize(_ sender: Any?) { zoomToActualSize() }
    @objc func rotateRight(_ sender: Any?) { turn(by: 1) }
    @objc func rotateLeft(_ sender: Any?) { turn(by: -1) }
    @objc func mirrorImage(_ sender: Any?) { mirror() }
    @objc func flipImage(_ sender: Any?) { flip() }

    /// Grows the window to the largest rectangle of the picture's own shape the screen holds,
    /// and back again. The size to come back to is kept here: AppKit only remembers one when
    /// the reader resized the window by hand, and this window sizes itself.
    @objc func zoomWindow(_ sender: Any?) {
        guard let window, let screen = window.screen ?? NSScreen.main else { return }
        let standard = standardFrame(for: window, in: screen.visibleFrame)
        if let restore = restoreFrame {
            restoreFrame = nil
            window.setFrame(restore, display: true, animate: false)
        } else {
            guard standard != window.frame else { return }
            restoreFrame = window.frame
            window.setFrame(standard, display: true, animate: false)
        }
    }

    /// The picture's shape, as large as it fits, never beyond its own size, centred.
    func standardFrame(for window: NSWindow, in visible: NSRect) -> NSRect {
        guard let picture = pictureSize, picture.width > 0, picture.height > 0 else { return visible }
        let limit = window.contentRect(forFrameRect: visible).size
        let ratio = min(limit.width / picture.width, limit.height / picture.height, 1)
        let content = NSSize(
            width: (picture.width * ratio).rounded(),
            height: (picture.height * ratio).rounded()
        )
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: content))
        frame.origin = NSPoint(
            x: (visible.midX - frame.width / 2).rounded(),
            y: (visible.midY - frame.height / 2).rounded()
        )
        return frame
    }

    // MARK: - Events

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) == true { return }
        super.keyDown(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        let delta = event.scrollingDeltaY
        guard delta != 0 else { return }
        let factor = event.hasPreciseScrollingDeltas
            ? pow(ViewTransform.step, delta / 60)
            : (delta > 0 ? ViewTransform.step : 1 / ViewTransform.step)
        zoom(by: factor, at: convert(event.locationInWindow, from: nil))
    }

    override func magnify(with event: NSEvent) {
        zoom(by: 1 + event.magnification, at: convert(event.locationInWindow, from: nil))
    }

    /// The window has no title bar to grab, so dragging the ground moves the window - except
    /// while the picture is larger than the window, when dragging moves the picture instead.
    /// AppKit's own background dragging is not used: it decides before the view sees the event,
    /// and it moved the window while the picture was zoomed in.
    /// Nothing happens on the way down. Moving the window takes over the whole event loop
    /// until the button comes back up, so starting it here would swallow the second click of
    /// a double-click.
    override func mouseDown(with event: NSEvent) {
        dragOrigin = convert(event.locationInWindow, from: nil)
    }

    /// The drag is measured from where the pointer actually is, not from the event's reported
    /// delta: a delta is not filled in by every kind of pointing device.
    override func mouseDragged(with event: NSEvent) {
        guard canPan else {
            // No title bar to grab, so the ground moves the window.
            window?.performDrag(with: event)
            return
        }
        guard let origin = dragOrigin else { return }
        let point = convert(event.locationInWindow, from: nil)
        transform.offset.x += point.x - origin.x
        transform.offset.y += point.y - origin.y
        dragOrigin = point
        applyLayout()
    }

    /// The window has no title bar to double-click, so the picture itself takes the gesture.
    override func mouseUp(with event: NSEvent) {
        dragOrigin = nil
        if event.clickCount == 2 {
            zoomWindow(nil)
        }
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
