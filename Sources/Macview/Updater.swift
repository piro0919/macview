import AppKit
import Sparkle

/// Automatic updates, put together the way Nonja, Gocci and Konechi are, and signed with the
/// same key.
///
/// The check happens once, at launch, and never on a timer. Something is only put on screen
/// when there is a new version: an app whose whole point is to stay out of the way should not
/// interrupt to talk about itself.
///
/// Sparkle otherwise asks, on first launch, whether it may check automatically. That question
/// is turned off in Info.plist with SUEnableAutomaticChecks.
final class Updater: NSObject, SPUUpdaterDelegate {
    static let shared = Updater()

    /// Set when the quiet check finds something. The window is opened once the check is over.
    private var foundUpdate = false

    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: self,
        userDriverDelegate: nil
    )

    /// The check at launch. Says nothing when there is nothing.
    func checkQuietly() {
        controller.updater.checkForUpdateInformation()
    }

    /// The menu item. Answers either way, including "you are up to date".
    @objc func checkForUpdates(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        controller.updater.checkForUpdates()
    }

    // MARK: - SPUUpdaterDelegate

    /// Asking for the window here would be thrown away: the check is still running.
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        foundUpdate = true
    }

    func updater(
        _ updater: SPUUpdater,
        didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
        error: (any Error)?
    ) {
        guard foundUpdate else { return }
        foundUpdate = false
        DispatchQueue.main.async { [weak self] in
            self?.checkForUpdates(nil)
        }
    }
}
