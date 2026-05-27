import AppKit
import Combine
import Foundation

@MainActor
public final class ReleaseStore: ObservableObject {
    @Published var releases: [ReleaseItem]
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isCodexRunning = false
    @Published var lastRefreshAt: Date?
    @Published var notificationsEnabled: Bool
    @Published var launchAtLoginEnabled: Bool
    @Published var onlyShowWhenCodexRuns: Bool
    @Published var enabledCategories: Set<Category>
    @Published var settingsErrorMessage: String?
    @Published var currentInstallation: CodexInstallationSnapshot?
    @Published var isCheckingVersions = false

    var unreadCount: Int {
        releases.filter { !$0.isRead }.count
    }

    var visibleReleases: [ReleaseItem] {
        let selected = enabledCategories
        guard !selected.isEmpty else {
            return releases
        }
        return releases.filter { item in
            !selected.isDisjoint(with: item.categories)
        }
    }

    var changelogURL: URL {
        AppConstants.codexChangelogURL
    }

    var githubReleasesWebURL: URL {
        AppConstants.githubReleasesWebURL
    }

    var latestGitHubRelease: ReleaseItem? {
        releases.max { $0.publishedAt < $1.publishedAt }
    }

    var latestCLIRelease: ReleaseItem? {
        releases
            .filter { $0.categories.contains(.codexCLI) }
            .max { $0.publishedAt < $1.publishedAt }
    }

    var latestMacAppRelatedRelease: ReleaseItem? {
        releases
            .filter { $0.categories.contains(.codexApp) }
            .max { $0.publishedAt < $1.publishedAt }
    }

    private let cacheStore: ReleaseCacheStore
    private let githubService: GitHubReleaseService
    private let processMonitor: CodexProcessMonitor
    private let notificationService: NotificationService
    private let loginItemService: LoginItemService
    private let versionService: CodexVersionService
    private let defaults: UserDefaults

    public convenience init() {
        self.init(
            cacheStore: ReleaseCacheStore(),
            githubService: GitHubReleaseService(),
            processMonitor: CodexProcessMonitor(),
            notificationService: NotificationService(),
            loginItemService: LoginItemService(),
            versionService: CodexVersionService(),
            defaults: .standard
        )
    }

    init(
        cacheStore: ReleaseCacheStore = ReleaseCacheStore(),
        githubService: GitHubReleaseService = GitHubReleaseService(),
        processMonitor: CodexProcessMonitor = CodexProcessMonitor(),
        notificationService: NotificationService = NotificationService(),
        loginItemService: LoginItemService = LoginItemService(),
        versionService: CodexVersionService = CodexVersionService(),
        defaults: UserDefaults = .standard
    ) {
        self.cacheStore = cacheStore
        self.githubService = githubService
        self.processMonitor = processMonitor
        self.notificationService = notificationService
        self.loginItemService = loginItemService
        self.versionService = versionService
        self.defaults = defaults

        releases = cacheStore.load()
        notificationsEnabled = defaults.object(forKey: DefaultsKey.notificationsEnabled) as? Bool ?? true
        onlyShowWhenCodexRuns = defaults.object(forKey: DefaultsKey.onlyShowWhenCodexRuns) as? Bool ?? false
        launchAtLoginEnabled = loginItemService.isEnabled
        enabledCategories = Self.loadEnabledCategories(from: defaults)
    }

    public func start() {
        processMonitor.onChange = { [weak self] running in
            Task { @MainActor in
                self?.handleCodexStateChange(running)
            }
        }
        processMonitor.start()

        Task {
            await refresh(sendNotifications: false)
        }
    }

    public func stop() {
        processMonitor.stop()
    }

    func refresh(sendNotifications: Bool = true) async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil
        await refreshCurrentVersions()

        let knownIDs = Set(releases.map(\.id))
        let hadExistingCache = !releases.isEmpty

        do {
            let fetched = try await githubService.fetchLatestReleases()
            let merged = merge(fetched: fetched, existing: releases)
            let newReleases = merged.filter { !knownIDs.contains($0.id) }

            releases = merged
            lastRefreshAt = Date()
            try cacheStore.save(merged)

            if sendNotifications, hadExistingCache {
                await notificationService.notifyNewReleases(newReleases, enabled: notificationsEnabled)
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isLoading = false
    }

    func refreshCurrentVersions() async {
        guard !isCheckingVersions else {
            return
        }

        isCheckingVersions = true
        currentInstallation = await versionService.currentSnapshot()
        isCheckingVersions = false
    }

    func markRead(_ item: ReleaseItem) {
        updateRelease(id: item.id) { release in
            release.isRead = true
            release.updatedAt = Date()
        }
    }

    func markUnread(_ item: ReleaseItem) {
        updateRelease(id: item.id) { release in
            release.isRead = false
            release.updatedAt = Date()
        }
    }

    func markAllRead() {
        for index in releases.indices {
            releases[index].isRead = true
            releases[index].updatedAt = Date()
        }
        persistCache()
    }

    func clearCache() {
        do {
            try cacheStore.clear()
            releases = []
            errorMessage = nil
        } catch {
            errorMessage = "캐시를 삭제하지 못했습니다: \(error.localizedDescription)"
        }
    }

    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        notificationsEnabled = enabled
        defaults.set(enabled, forKey: DefaultsKey.notificationsEnabled)

        if enabled {
            Task {
                _ = await notificationService.requestAuthorization()
            }
        }
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        do {
            try loginItemService.setEnabled(enabled)
            launchAtLoginEnabled = loginItemService.isEnabled
            settingsErrorMessage = nil
        } catch {
            launchAtLoginEnabled = loginItemService.isEnabled
            settingsErrorMessage = "로그인 시 자동 실행 설정을 변경하지 못했습니다: \(error.localizedDescription)"
        }
    }

    func setOnlyShowWhenCodexRuns(_ enabled: Bool) {
        onlyShowWhenCodexRuns = enabled
        defaults.set(enabled, forKey: DefaultsKey.onlyShowWhenCodexRuns)
    }

    func toggleCategory(_ category: Category, enabled: Bool) {
        if enabled {
            enabledCategories.insert(category)
        } else {
            enabledCategories.remove(category)
        }

        let rawValues = enabledCategories.map(\.rawValue).sorted()
        defaults.set(rawValues, forKey: DefaultsKey.enabledCategories)
    }

    private func handleCodexStateChange(_ running: Bool) {
        let didLaunch = running && !isCodexRunning
        isCodexRunning = running

        if didLaunch {
            Task {
                await refresh()
            }
        }
    }

    private func updateRelease(id: String, mutate: (inout ReleaseItem) -> Void) {
        guard let index = releases.firstIndex(where: { $0.id == id }) else {
            return
        }

        mutate(&releases[index])
        persistCache()
    }

    private func persistCache() {
        do {
            try cacheStore.save(releases)
        } catch {
            errorMessage = "캐시 저장에 실패했습니다: \(error.localizedDescription)"
        }
    }

    private func merge(fetched: [ReleaseItem], existing: [ReleaseItem]) -> [ReleaseItem] {
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let fetchedIDs = Set(fetched.map(\.id))

        var merged = fetched.map { release in
            var release = release
            if let cached = existingByID[release.id] {
                release.isRead = cached.isRead
                release.createdAt = cached.createdAt
            }
            release.updatedAt = Date()
            return release
        }

        merged.append(contentsOf: existing.filter { !fetchedIDs.contains($0.id) })

        return Array(
            merged
                .sorted { $0.publishedAt > $1.publishedAt }
                .prefix(60)
        )
    }

    private static func loadEnabledCategories(from defaults: UserDefaults) -> Set<Category> {
        guard let rawValues = defaults.stringArray(forKey: DefaultsKey.enabledCategories) else {
            return Set(Category.allCases)
        }

        let categories = rawValues.compactMap(Category.init(rawValue:))
        return Set(categories)
    }
}

private enum DefaultsKey {
    static let notificationsEnabled = "notificationsEnabled"
    static let onlyShowWhenCodexRuns = "onlyShowWhenCodexRuns"
    static let enabledCategories = "enabledCategories"
}
