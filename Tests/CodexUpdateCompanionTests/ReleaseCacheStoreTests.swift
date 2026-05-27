import Foundation
import XCTest
@testable import CodexUpdateCompanionCore

final class ReleaseCacheStoreTests: XCTestCase {
    func testCacheRoundTripPreservesReadState() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("release-cache.json")
        let store = ReleaseCacheStore(fileURL: fileURL)
        let item = ReleaseItem(
            id: "github_release:1",
            source: .githubRelease,
            version: "rust-v0.1.0",
            title: "Test Release",
            publishedAt: Date(timeIntervalSince1970: 10),
            url: URL(string: "https://github.com/openai/codex/releases/tag/rust-v0.1.0")!,
            rawBody: "Body",
            koreanSummary: "요약",
            categories: [.codexCLI],
            impactLevel: .low,
            isRead: true
        )

        try store.save([item])
        let loaded = store.load()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, item.id)
        XCTAssertTrue(loaded[0].isRead)

        try store.clear()
    }
}
