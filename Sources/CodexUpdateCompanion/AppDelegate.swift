import AppKit
import CodexUpdateCompanionCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = ReleaseStore()
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("CodexUpdateCompanion did finish launching")
        NSApp.setActivationPolicy(.accessory)
        statusBarController = StatusBarController(store: store)
        store.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stop()
    }
}

@main
enum CodexUpdateCompanionMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
