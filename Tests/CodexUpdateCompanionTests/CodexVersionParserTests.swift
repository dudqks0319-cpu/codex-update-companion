import XCTest
@testable import CodexUpdateCompanionCore

final class CodexVersionParserTests: XCTestCase {
    func testParsesCLIOutputWithWarningPrefix() {
        let output = """
        WARNING: proceeding, even though we could not update PATH: Operation not permitted (os error 1)
        codex-cli 0.133.0
        """

        XCTAssertEqual(CodexVersionParser.cliVersionLine(from: output), "codex-cli 0.133.0")
    }

    func testParsesFirstCodexPath() {
        let output = """
        /opt/homebrew/bin/codex
        /usr/local/bin/codex-old
        """

        XCTAssertEqual(CodexVersionParser.firstPath(from: output), "/opt/homebrew/bin/codex")
    }

    func testExtractsSemanticVersionFromReleaseTag() {
        XCTAssertEqual(CodexVersionParser.semanticVersion(from: "rust-v0.134.0"), "0.134.0")
    }

    func testComparesCLIAndGitHubReleaseVersions() {
        XCTAssertEqual(
            CodexVersionParser.compareSemanticVersions("codex-cli 0.133.0", "rust-v0.134.0"),
            .orderedAscending
        )
        XCTAssertEqual(
            CodexVersionParser.compareSemanticVersions("codex-cli 0.134.0", "rust-v0.134.0"),
            .orderedSame
        )
    }

    func testParsesLatestMacAppcastItem() throws {
        let xml = """
        <?xml version='1.0' encoding='utf-8'?>
        <rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
            <channel>
                <title>Codex</title>
                <item>
                    <title>26.519.81530</title>
                    <pubDate>Tue, 26 May 2026 16:59:23 -0700</pubDate>
                    <sparkle:version>3178</sparkle:version>
                    <sparkle:shortVersionString>26.519.81530</sparkle:shortVersionString>
                    <enclosure url="https://persistent.oaistatic.com/codex-app-prod/Codex-darwin-arm64-26.519.81530.zip" length="477141549" type="application/octet-stream" />
                </item>
            </channel>
        </rss>
        """

        let update = try XCTUnwrap(
            CodexMacAppcastParser.latestUpdate(
                from: Data(xml.utf8),
                appcastURL: URL(string: "https://persistent.oaistatic.com/codex-app-prod/appcast.xml")!
            )
        )

        XCTAssertEqual(update.version, "26.519.81530")
        XCTAssertEqual(update.build, "3178")
        XCTAssertEqual(update.downloadURL?.absoluteString, "https://persistent.oaistatic.com/codex-app-prod/Codex-darwin-arm64-26.519.81530.zip")
    }

    func testMacAppUpdateStateUsesBuildNumber() {
        let snapshot = CodexInstallationSnapshot(
            appVersion: "26.519.41501",
            appBuild: "3044",
            appPath: "/Applications/Codex.app",
            appLatestVersion: "26.519.81530",
            appLatestBuild: "3178",
            appUpdatePublishedAt: nil,
            appUpdateDownloadURL: nil,
            appUpdateFeedURL: nil,
            appUpdateCheckFailed: false,
            cliVersion: nil,
            cliPath: nil,
            cliResolvedPath: nil,
            cliInstallMethod: nil,
            cliUpdateCommand: nil,
            checkedAt: Date()
        )

        XCTAssertEqual(snapshot.appUpdateState, .updateAvailable)
        XCTAssertTrue(snapshot.isMacAppUpdateAvailable)
    }
}
