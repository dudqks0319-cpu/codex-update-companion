import XCTest
@testable import CodexUpdateCompanionCore

final class OpenAIChangelogParserTests: XCTestCase {
    func testParsesAndClassifiesOfficialChangelogLikeHTML() throws {
        let html = """
        <html><body>
          <h2>May 21, 2026</h2>
          <h3>Appshots, Goal mode, and remote computer use</h3>
          <p>Codex app adds Goal mode, Appshots, remote computer use, and plugin sharing.</p>
          <h2>May 21, 2026</h2>
          <h3>Codex CLI 0.133.0</h3>
          <p>CLI release with bug fixes.</p>
        </body></html>
        """

        let entries = OpenAIChangelogParser.entries(
            from: Data(html.utf8),
            baseURL: URL(string: "https://developers.openai.com/codex/changelog")!
        )

        XCTAssertGreaterThanOrEqual(entries.count, 2)
        XCTAssertTrue(entries.contains { $0.surface == .plugin || $0.surface == .macApp })
        XCTAssertTrue(entries.contains { $0.surface == .cli })
        XCTAssertTrue(entries.allSatisfy { $0.url == URL(string: "https://developers.openai.com/codex/changelog")! })
    }
}
