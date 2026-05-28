import Foundation
import XCTest
@testable import CodexUpdateCompanionCore

@MainActor
final class ReleaseStoreFetchFallbackTests: XCTestCase {
    func testChangelogStillLoadsWhenGitHubFails() async throws {
        let changelogItem = release(id: "openai_changelog:goal-mode", source: .openAIChangelog)
        let store = makeStore(
            githubResult: .failure(TestFetchError.sourceFailed),
            changelogResult: .success([changelogItem])
        )

        await store.refresh(sendNotifications: false)

        XCTAssertEqual(store.releases.map(\.id), [changelogItem.id])
        XCTAssertNil(store.errorMessage)
    }

    func testGitHubStillLoadsWhenChangelogFails() async throws {
        let githubItem = release(id: "github_release:134", source: .githubRelease)
        let store = makeStore(
            githubResult: .success([githubItem]),
            changelogResult: .failure(TestFetchError.sourceFailed)
        )

        await store.refresh(sendNotifications: false)

        XCTAssertEqual(store.releases.map(\.id), [githubItem.id])
        XCTAssertNil(store.errorMessage)
    }

    func testBothFailuresKeepExistingCacheAndSetError() async throws {
        let cachedItem = release(id: "github_release:cached", source: .githubRelease)
        let cacheStore = temporaryCacheStore()
        try cacheStore.save([cachedItem])
        let store = makeStore(
            cacheStore: cacheStore,
            githubResult: .failure(TestFetchError.sourceFailed),
            changelogResult: .failure(TestFetchError.sourceFailed)
        )

        await store.refresh(sendNotifications: false)

        XCTAssertEqual(store.releases.map(\.id), [cachedItem.id])
        XCTAssertEqual(store.errorMessage, TestFetchError.sourceFailed.errorDescription)
    }

    private func makeStore(
        cacheStore: ReleaseCacheStore? = nil,
        githubResult: Result<[ReleaseItem], Error>,
        changelogResult: Result<[ReleaseItem], Error>
    ) -> ReleaseStore {
        ReleaseStore(
            cacheStore: cacheStore ?? temporaryCacheStore(),
            githubService: FakeGitHubReleaseFetcher(result: githubResult),
            changelogService: FakeOpenAIChangelogFetcher(result: changelogResult),
            notificationService: FakeNotificationSender(),
            versionService: FakeCodexVersionProvider(),
            defaults: temporaryDefaults()
        )
    }

    private func temporaryCacheStore() -> ReleaseCacheStore {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("release-cache.json")
        return ReleaseCacheStore(fileURL: fileURL)
    }

    private func temporaryDefaults() -> UserDefaults {
        let suiteName = "CodexUpdateCompanionTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName) ?? .standard
    }

    private func release(id: String, source: SourceType) -> ReleaseItem {
        ReleaseItem(
            id: id,
            source: source,
            version: "0.134.0",
            title: "Test release",
            publishedAt: Date(timeIntervalSince1970: 1_800_000_000),
            url: URL(string: "https://developers.openai.com/codex/changelog")!,
            rawBody: "Goal mode update",
            koreanSummary: "Goal 모드 업데이트",
            categories: [.codexApp],
            impactLevel: .medium
        )
    }
}

private struct FakeGitHubReleaseFetcher: GitHubReleaseFetching {
    let result: Result<[ReleaseItem], Error>

    func fetchLatestReleases() async throws -> [ReleaseItem] {
        try result.get()
    }
}

private struct FakeOpenAIChangelogFetcher: OpenAIChangelogFetching {
    let result: Result<[ReleaseItem], Error>

    func fetchLatestEntries() async throws -> [ReleaseItem] {
        try result.get()
    }
}

private struct FakeCodexVersionProvider: CodexVersionProviding {
    func currentSnapshot() async -> CodexInstallationSnapshot {
        CodexInstallationSnapshot(
            appVersion: nil,
            appBuild: nil,
            appPath: nil,
            appLatestVersion: nil,
            appLatestBuild: nil,
            appUpdatePublishedAt: nil,
            appUpdateDownloadURL: nil,
            appUpdateFeedURL: nil,
            appUpdateCheckFailed: false,
            cliVersion: nil,
            cliPath: nil,
            cliResolvedPath: nil,
            cliInstallMethod: nil,
            cliUpdateCommand: nil,
            checkedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }
}

private struct FakeNotificationSender: NotificationSending {
    func requestAuthorization() async -> Bool {
        true
    }

    func notifyNewReleases(_ releases: [ReleaseItem], enabled: Bool) async {}
}

private enum TestFetchError: LocalizedError {
    case sourceFailed

    var errorDescription: String? {
        "source failed"
    }
}
