import AppKit
import Foundation

final class CodexProcessMonitor {
    var onChange: ((Bool) -> Void)?

    private var observers: [NSObjectProtocol] = []
    private var timer: Timer?

    func start() {
        refresh()

        let notificationCenter = NSWorkspace.shared.notificationCenter
        observers.append(
            notificationCenter.addObserver(
                forName: NSWorkspace.didLaunchApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refresh()
            }
        )
        observers.append(
            notificationCenter.addObserver(
                forName: NSWorkspace.didTerminateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refresh()
            }
        )

        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stop() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        observers.forEach { notificationCenter.removeObserver($0) }
        observers.removeAll()
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        onChange?(isCodexRunning())
    }

    private func isCodexRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { app in
            isCodexApp(app)
        }
    }

    private func isCodexApp(_ app: NSRunningApplication) -> Bool {
        if app.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            return false
        }

        let name = app.localizedName?.lowercased() ?? ""
        let bundleIdentifier = app.bundleIdentifier?.lowercased() ?? ""

        if name == "codex" || name == "openai codex" {
            return true
        }

        if name.contains("codex update companion") || bundleIdentifier == AppConstants.bundleIdentifier {
            return false
        }

        return bundleIdentifier.contains("openai") && bundleIdentifier.contains("codex")
    }
}
