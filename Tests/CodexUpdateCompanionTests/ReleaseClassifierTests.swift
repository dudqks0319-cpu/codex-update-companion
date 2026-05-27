import XCTest
@testable import CodexUpdateCompanionCore

final class ReleaseClassifierTests: XCTestCase {
    func testClassifiesSecurityPermissionAsHighImpact() {
        let text = "Security fix: reject legacy permission profile and patch credential handling"
        let categories = ReleaseClassifier.categories(for: text)

        XCTAssertTrue(categories.contains(.security))
        XCTAssertTrue(categories.contains(.permission))
        XCTAssertEqual(ReleaseClassifier.impactLevel(for: text, categories: categories), .critical)
    }

    func testBuildsKoreanSummaryAsNonDeveloperList() {
        let categories: [CodexUpdateCompanionCore.Category] = [.codexCLI, .newFeature]
        let summary = KoreanSummaryBuilder.summary(
            version: "rust-v0.134.0",
            title: "Codex CLI 0.134.0",
            body: "* Added search across local conversation history.",
            categories: categories,
            impact: .medium
        )

        XCTAssertTrue(summary.contains("1."))
        XCTAssertTrue(summary.contains("업데이트:"))
        XCTAssertTrue(summary.contains("새 기능"))
        XCTAssertTrue(summary.contains("대화 기록"))
    }

    func testBuildsDetailedExplanationFromReleaseBody() {
        let item = ReleaseItem(
            id: "github_release:42",
            source: .githubRelease,
            version: "rust-v0.134.0",
            title: "Codex CLI 0.134.0",
            publishedAt: Date(timeIntervalSince1970: 10),
            url: URL(string: "https://github.com/openai/codex/releases/tag/rust-v0.134.0")!,
            rawBody: """
            ## What's Changed
            * Added sandbox permission profile controls.
            * Fixed reconnect behavior after network failures.
            """,
            koreanSummary: "요약",
            categories: [.codexCLI, .sandbox, .bugFix],
            impactLevel: .medium
        )

        let explanation = DetailedExplanationBuilder.explanation(for: item)

        XCTAssertTrue(explanation.headline.contains("rust-v0.134.0"))
        XCTAssertTrue(explanation.plainLanguageSummary.contains("로컬에서 명령"))
        XCTAssertFalse(explanation.userImpactBullets.isEmpty)
        XCTAssertFalse(explanation.attentionBullets.isEmpty)
        XCTAssertTrue(explanation.rawHighlights.contains { $0.contains("sandbox permission") })
    }

    func testBuildsSecurityAndBugDigestDetails() {
        let item = ReleaseItem(
            id: "github_release:43",
            source: .githubRelease,
            version: "rust-v0.135.0",
            title: "Codex fixes",
            publishedAt: Date(timeIntervalSince1970: 10),
            url: URL(string: "https://github.com/openai/codex/releases/tag/rust-v0.135.0")!,
            rawBody: """
            * Security fix for secret handling.
            * Fixed reconnect behavior after network failures.
            """,
            koreanSummary: "요약",
            categories: [.codexCLI, .security, .bugFix],
            impactLevel: .high
        )

        let digest = FriendlyReleaseDigestBuilder.digest(for: item)

        XCTAssertTrue(digest.securityRelatedChanges.contains { $0.kindTitle == "보안 수정" })
        XCTAssertTrue(digest.bugFixChanges.contains { $0.kindTitle == "버그 수정" })
        XCTAssertTrue(digest.bugFixChanges.contains { $0.plainDetail.contains("네트워크") })
    }

    func testGoalUpdateIncludesUsageGuide() throws {
        let item = ReleaseItem(
            id: "github_release:44",
            source: .githubRelease,
            version: "rust-v0.136.0",
            title: "Goal support",
            publishedAt: Date(timeIntervalSince1970: 10),
            url: URL(string: "https://github.com/openai/codex/releases/tag/rust-v0.136.0")!,
            rawBody: """
            * Added /goal support to track objective and acceptance criteria.
            """,
            koreanSummary: "요약",
            categories: [.codexApp, .newFeature],
            impactLevel: .medium
        )

        let digest = FriendlyReleaseDigestBuilder.digest(for: item)
        let goalChange = try XCTUnwrap(digest.changes.first)

        XCTAssertEqual(goalChange.areaTitle, "Goal")
        XCTAssertEqual(goalChange.kindTitle, "새 기능")
        XCTAssertTrue(goalChange.plainDetail.contains("작업 목표"))
        XCTAssertTrue(goalChange.howToUse.contains { $0.contains("/goal") })
        XCTAssertTrue(goalChange.whereToCheck.contains("Goal"))
    }
}
