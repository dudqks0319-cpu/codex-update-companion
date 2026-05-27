import AppKit
import SwiftUI

@MainActor
final class ReleaseDetailWindowController: NSWindowController {
    private let item: ReleaseItem

    init(store: ReleaseStore, item: ReleaseItem) {
        self.item = item

        let hostingController = NSHostingController(
            rootView: ReleaseDetailView(store: store, item: item)
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = "\(item.version) 상세보기"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 760, height: 720))
        window.minSize = NSSize(width: 560, height: 520)
        window.isReleasedWhenClosed = false

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func show() {
        window?.title = "\(item.version) 상세보기"
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
