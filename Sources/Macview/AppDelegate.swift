import AppKit
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var viewer: Viewer?

    /// main.swift is top-level code, which is nonisolated in the Swift 5 language mode.
    /// Making the object costs nothing isolated; AppKit calls every delegate method on the main thread.
    nonisolated override init() { super.init() }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        currentViewer().showWindow()
        NSApp.activate(ignoringOtherApps: true)
        Updater.shared.checkQuietly()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let viewer = currentViewer()
        viewer.showWindow()
        viewer.open(urls)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        currentViewer().open([url])
    }

    private func currentViewer() -> Viewer {
        if let viewer { return viewer }
        let viewer = Viewer()
        self.viewer = viewer
        return viewer
    }
}

enum MainMenu {
    static func make() -> NSMenu {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Macview",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())
        let update = appMenu.addItem(withTitle: "Check for Updates…",
                                     action: #selector(Updater.checkForUpdates(_:)),
                                     keyEquivalent: "")
        update.target = Updater.shared
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Macview", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Macview", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Open…", action: #selector(AppDelegate.openDocument(_:)), keyEquivalent: "o")
        fileMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileItem.submenu = fileMenu
        main.addItem(fileItem)

        main.addItem(viewItem())

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        add(windowMenu, "Minimise", #selector(NSWindow.performMiniaturize(_:)), "m", .command)
        add(windowMenu, "Zoom", #selector(ImageLayerView.zoomWindow(_:)), "", [])
        windowItem.submenu = windowMenu
        main.addItem(windowItem)

        return main
    }

    /// The keys are qView's: a quarter turn on the up and down arrows, F to mirror, ⌘F to flip.
    /// Nothing of this appears in the window; the menu is where a reader finds it.
    private static func viewItem() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "View")

        add(menu, "Zoom In", #selector(ImageLayerView.zoomIn(_:)), "+", .command)
        add(menu, "Zoom Out", #selector(ImageLayerView.zoomOut(_:)), "-", .command)
        add(menu, "Reset Zoom", #selector(ImageLayerView.resetZoom(_:)), "0", .command)
        add(menu, "Original Size", #selector(ImageLayerView.originalSize(_:)), "o", [])
        menu.addItem(.separator())
        add(menu, "Rotate Right", #selector(ImageLayerView.rotateRight(_:)), arrow(NSUpArrowFunctionKey), [])
        add(menu, "Rotate Left", #selector(ImageLayerView.rotateLeft(_:)), arrow(NSDownArrowFunctionKey), [])
        add(menu, "Mirror", #selector(ImageLayerView.mirrorImage(_:)), "f", [])
        add(menu, "Flip", #selector(ImageLayerView.flipImage(_:)), "f", .command)

        item.submenu = menu
        return item
    }

    private static func arrow(_ code: Int) -> String {
        String(UnicodeScalar(UInt32(code)) ?? " ")
    }

    private static func add(
        _ menu: NSMenu,
        _ title: String,
        _ action: Selector,
        _ key: String,
        _ modifiers: NSEvent.ModifierFlags
    ) {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
    }
}
