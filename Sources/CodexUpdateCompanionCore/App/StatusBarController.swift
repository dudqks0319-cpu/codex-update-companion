import AppKit
import Combine
import SwiftUI

@MainActor
public final class StatusBarController: NSObject {
    private let store: ReleaseStore
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var cancellables = Set<AnyCancellable>()
    private var settingsWindowController: SettingsWindowController?
    private var detailWindowControllers: [ReleaseItem.ID: ReleaseDetailWindowController] = [:]

    public init(store: ReleaseStore) {
        self.store = store
        statusItem = NSStatusBar.system.statusItem(withLength: 72)
        popover = NSPopover()
        super.init()

        configureStatusItem()
        configurePopover()
        observeStore()
        updateButton()
        NSLog("CodexUpdateCompanion status item configured: visible=%d title=%@", statusItem.isVisible, statusItem.button?.title ?? "nil")
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.target = self
        button.action = #selector(togglePopover(_:))
        button.imagePosition = .imageLeading
        button.title = " Codex"
        button.toolTip = AppConstants.appName
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 430, height: 620)
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(
                store: store,
                openSettings: { [weak self] in
                    self?.showSettings()
                },
                openDetails: { [weak self] item in
                    self?.showDetails(for: item)
                }
            )
        )
    }

    private func observeStore() {
        store.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateButton()
                }
            }
            .store(in: &cancellables)
    }

    private func updateButton() {
        statusItem.isVisible = true

        guard let button = statusItem.button else {
            return
        }

        let symbolName = store.isCodexRunning ? "bolt.circle.fill" : "bolt.circle"
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Codex status")
        image?.isTemplate = true
        button.image = image
        button.contentTintColor = store.isCodexRunning ? .controlAccentColor : .secondaryLabelColor
        button.title = store.unreadCount > 0 ? " Codex \(min(store.unreadCount, 99))" : " Codex"
        button.toolTip = store.isCodexRunning
            ? "Codex 실행 중 - \(store.unreadCount)개 미확인 업데이트"
            : "Codex가 실행 중이 아닙니다"
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else {
            return
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showSettings() {
        popover.performClose(nil)

        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(store: store)
        }

        settingsWindowController?.show()
    }

    private func showDetails(for item: ReleaseItem) {
        popover.performClose(nil)

        if detailWindowControllers[item.id] == nil {
            detailWindowControllers[item.id] = ReleaseDetailWindowController(store: store, item: item)
        }

        detailWindowControllers[item.id]?.show()
        store.markRead(item)
    }
}
