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

    func testBuildsSectionedDigestForLargeGitHubReleaseNotes() {
        let item = ReleaseItem(
            id: "github_release:134",
            source: .githubRelease,
            version: "rust-v0.134.0",
            title: "0.134.0",
            publishedAt: Date(timeIntervalSince1970: 10),
            url: URL(string: "https://github.com/openai/codex/releases/tag/rust-v0.134.0")!,
            rawBody: Self.largeReleaseBody,
            koreanSummary: "요약",
            categories: [.codexApp, .codexCLI, .sandbox, .permission, .bugFix, .newFeature],
            impactLevel: .high
        )

        let digest = FriendlyReleaseDigestBuilder.digest(for: item)

        XCTAssertEqual(digest.sections.map(\.title), ["새로운 기능", "버그 수정", "문서", "정리/릴리스 작업", "전체 변경 로그"])
        XCTAssertGreaterThanOrEqual(digest.changes.count, 50)
        XCTAssertTrue(digest.sections.first?.changes.first?.plainDetail.contains("대화 기록") == true)
        XCTAssertTrue(digest.changes.contains { $0.evidence.contains("#24165") })
        XCTAssertTrue(digest.changes.contains { $0.plainDetail.contains("프로필") })
        XCTAssertTrue(digest.bugFixChanges.contains { $0.plainDetail.contains("Windows 터미널") })
    }

    private static let largeReleaseBody = """
    ## New Features
    - Added search across local conversation history, including case-insensitive content matches with result previews. (#23519, #23921)
    - Made `--profile` the primary profile selector across CLI, TUI permissions, and sandbox flows, with legacy profile configs rejected through migration guidance. (#23708, #23883, #23890, #24051, #24055, #24059, #24067, #24110)
    - Improved MCP setup with per-server environment targeting and OAuth options for streamable HTTP servers. (#23583, #24120)
    - Made connector tool schemas more reliable by preserving local `$ref`/`$defs` structures and compacting oversized schemas before exposure. (#23357, #23904)
    - Let read-only MCP tools run concurrently when they advertise `readOnlyHint`. (#23750)
    - Added richer extension and hook context, including conversation history for extension tools and subagent identity in hook inputs. (#22882, #23963)

    ## Bug Fixes
    - Improved remote reliability by reconnecting stale exec-server websocket clients, retrying remote control immediately after auth recovery, and retrying remote compaction v2 streams. (#23867, #23775, #23951)
    - Fixed Windows TUI rendering corruption by restoring virtual terminal mode before drawing. (#24082)
    - Displayed workspace-specific usage-limit messages for credit and spend-cap failures. (#24114)
    - Allowed plugin skills to reuse shared plugin-level icon assets. (#23776)
    - Preserved active permission profile metadata when syncing auto-review runtime settings. (#23956)
    - Ensured Node-based tools honor Codex's managed network proxy environment. (#23905)

    ## Documentation
    - Documented the curl and PowerShell installer paths in the README. (#24106)
    - Updated developer docs to prefer `just test` over direct `cargo test` for repo-local test runs. (#23910)
    - Added profile migration documentation links to relevant config errors. (#23879)

    ## Chores
    - Simplified release packaging around canonical native artifacts, reusable DotSlash fetching, and a new macOS x64 zsh artifact. (#23833, #23836, #24129, #24165)
    - Added release-build support for Codex-produced V8 artifacts. (#23934)
    - Added image re-encoding benchmarks and connector-style JSON schema policy fixtures. (#23935, #24152)
    - Improved tracing and analytics for websocket requests, turn starts, and remote compaction v2. (#23581, #23980, #24146)

    ## Changelog

    Full Changelog: https://github.com/openai/codex/compare/rust-v0.133.0...rust-v0.134.0

    - #23581 Trace logical websocket request after untraced warmup @jif-oai
    - #23718 [codex] Steer budget-limited goal extension turns @jif-oai
    - #23861 fix: cargo lock @jif-oai
    - #23728 feat: retain remote compaction truncation parity in v2 @jif-oai
    - #23870 Make tool executor specs mandatory @jif-oai
    - #23882 [codex] Stabilize subagent start hook test @jif-oai
    - #23876 refactor: centralize tool exposure planning @jif-oai
    - #23879 chore: link doc in profile error messages @jif-oai
    - #23883 cli: rename profile v2 flag to --profile @jif-oai
    - #23835 docs: add description to codex-cli/package.json @bolinfest
    - #23583 Route MCP servers through explicit environments @starr-openai
    - #23886 cli: remove legacy profile v1 plumbing @jif-oai
    - #23708 tui: plumb permission profile selection @viyatb-oai
    - #23833 packaging: move rg manifest out of npm bin @bolinfest
    - #23796 Improve `/goal` error messages for ephemeral sessions @etraut-openai
    - #23867 Reconnect disconnected exec-server websocket clients with fresh sessions @starr-openai
    - #23792 TUI: skip goal replace prompt for completed goals @etraut-openai
    - #23519 [codex] Add rollout-backed thread content search @fc-oai
    - #22552 Remove plugin hooks feature flag @abhinav-oai
    - #23836 npm: remove legacy package artifact synthesis @bolinfest
    - #23921 [codex] Make thread search case-insensitive @fc-oai
    - #23775 fix(remote-control): retry after auth recovery @apanasenko-oai
    - #22882 Add subagent identity to hook inputs @abhinav-oai
    - #22915 [3 of 4] tui: route feature and memory toggles through app server @etraut-openai
    - #23776 fix: Allow plugin skills to share plugin-level icon assets @xl-openai
    - #23860 Add Bedrock Mantle GovCloud region @CHARLESPALEN-OAI
    - #23956 Fix auto-review permission profile override @etraut-openai
    - #23357 feat: support local refs and defs in tool input schemas @celia-oai
    - #23963 Expose conversation history to extension tools @sayan-oai
    - #23904 feat: best-effort compact large tool schemas @celia-oai
    - #23750 Allow parallel MCP tool calls when annotated readOnly @anp-oai
    - #23905 [codex] Enable Node env proxy for managed network proxy @rreichel3-oai
    - #23890 mcp: surface profile migration guidance under --profile @jif-oai
    - #24051 config: remove legacy profile v1 resolution @jif-oai
    - #24055 config: remove legacy profile write paths @jif-oai
    - #24057 Avoid config snapshots in live agent subtree traversal @jif-oai
    - #24061 otel: drop legacy profile usage telemetry @jif-oai
    - #24059 fix: reject legacy profile selectors @jif-oai
    - #23934 ci: Use codex produced v8 artifacts for release builds @cconger
    - #24099 fix(app-server): fix optional bool annotations @owenlin0
    - #23910 Prefer `just test` over `cargo test` in docs @anp-oai
    - #23951 retry remote compaction v2 requests @rhan-oai
    - #24081 tui: make `codex-tui.log` opt-in @jif-oai
    - #24102 cli: infer host sandbox backend @bolinfest
    - #24067 app-server: drop legacy profile config surface @jif-oai
    - #23736 Add new enterprise requirement gate @adams-oai
    - #24117 [codex] Use rolling files for Windows sandbox logs @iceweasel-oai
    - #24106 docs: update README.md to mention curl-based installer @bolinfest
    - #24082 fix(tui): restore Windows VT before TUI renders @fcoury-oai
    - #24110 cli: support --profile for codex sandbox @bolinfest
    - #23980 Add trace_id to TurnStartedEvent @mchen-oai
    - #24120 Support OAuth options in codex mcp add @mzeng-openai
    - #23989 Add typed Images client to codex-api @won-openai
    - #24146 [codex-analytics] split compaction v2 analytics implementation @rhan-oai
    - #24129 package: factor DotSlash executable fetching @bolinfest
    - #24151 [codex] Use TurnInput for session task input @pakrym-oai
    - #23935 [codex] Add image re-encoding benchmarks @anp-oai
    - #24152 chore: add JSON schema policy fixture coverage @celia-oai
    - #24157 [codex] Remove external client session reset plumbing @pakrym-oai
    - #24114 Display workspace usage limit error copy from response header @dhruvgupta-oai
    - #24165 release: build macOS x64 zsh artifact @bolinfest
    """
}
