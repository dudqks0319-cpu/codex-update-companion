import Foundation

enum AppConstants {
    static let appName = "Codex Update Companion"
    static let processName = "CodexUpdateCompanion"
    static let bundleIdentifier = "com.jyb.codex-update-companion"
    static let githubReleasesURL = URL(string: "https://api.github.com/repos/openai/codex/releases?per_page=20")!
    static let githubReleasesWebURL = URL(string: "https://github.com/openai/codex/releases")!
    static let codexChangelogURL = URL(string: "https://developers.openai.com/codex/changelog")!
    static let codexMacAppcastURL = URL(string: "https://persistent.oaistatic.com/codex-app-prod/appcast.xml")!
    static let codexMacDownloadURL = URL(string: "https://persistent.oaistatic.com/codex-app-prod/Codex.dmg")!
    static let userAgent = "CodexUpdateCompanion/0.1 (+https://github.com/openai/codex)"
}
