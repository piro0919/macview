import AppKit

if CommandLine.arguments.contains("--selftest") {
    exit(SelfTest.run() ? 0 : 1)
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
