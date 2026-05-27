import Foundation

public enum SourceType: String, Codable, CaseIterable, Sendable {
    case openAIChangelog = "openai_changelog"
    case githubRelease = "github_release"
    case githubIssue = "github_issue"
    case chatGPTReleaseNote = "chatgpt_release_note"

    var displayName: String {
        switch self {
        case .openAIChangelog:
            "OpenAI Changelog"
        case .githubRelease:
            "GitHub Release"
        case .githubIssue:
            "GitHub Issue"
        case .chatGPTReleaseNote:
            "ChatGPT Release Note"
        }
    }
}

public enum ImpactLevel: String, Codable, CaseIterable, Comparable, Sendable {
    case low
    case medium
    case high
    case critical

    private var rank: Int {
        switch self {
        case .low: 0
        case .medium: 1
        case .high: 2
        case .critical: 3
        }
    }

    public static func < (lhs: ImpactLevel, rhs: ImpactLevel) -> Bool {
        lhs.rank < rhs.rank
    }

    var displayName: String {
        switch self {
        case .low:
            "낮음"
        case .medium:
            "중간"
        case .high:
            "높음"
        case .critical:
            "긴급"
        }
    }
}

public enum Category: String, Codable, CaseIterable, Identifiable, Sendable {
    case codexApp = "codex_app"
    case codexCLI = "codex_cli"
    case ide
    case githubReview = "github_review"
    case sandbox
    case permission
    case security
    case bugFix = "bug_fix"
    case newFeature = "new_feature"
    case breakingChange = "breaking_change"

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .codexApp:
            "맥앱"
        case .codexCLI:
            "CLI"
        case .ide:
            "IDE"
        case .githubReview:
            "GitHub 리뷰"
        case .sandbox:
            "샌드박스"
        case .permission:
            "권한"
        case .security:
            "보안"
        case .bugFix:
            "버그 수정"
        case .newFeature:
            "새 기능"
        case .breakingChange:
            "주의 필요"
        }
    }

    var systemImage: String {
        switch self {
        case .codexApp:
            "macwindow"
        case .codexCLI:
            "terminal"
        case .ide:
            "curlybraces.square"
        case .githubReview:
            "checkmark.seal"
        case .sandbox:
            "shippingbox"
        case .permission:
            "lock.shield"
        case .security:
            "shield.lefthalf.filled"
        case .bugFix:
            "wrench.and.screwdriver"
        case .newFeature:
            "sparkles"
        case .breakingChange:
            "exclamationmark.triangle"
        }
    }
}

public struct ReleaseItem: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var source: SourceType
    public var version: String
    public var title: String
    public var publishedAt: Date
    public var url: URL
    public var rawBody: String
    public var koreanSummary: String
    public var categories: [Category]
    public var impactLevel: ImpactLevel
    public var isRead: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        source: SourceType,
        version: String,
        title: String,
        publishedAt: Date,
        url: URL,
        rawBody: String,
        koreanSummary: String,
        categories: [Category],
        impactLevel: ImpactLevel,
        isRead: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.source = source
        self.version = version
        self.title = title
        self.publishedAt = publishedAt
        self.url = url
        self.rawBody = rawBody
        self.koreanSummary = koreanSummary
        self.categories = categories
        self.impactLevel = impactLevel
        self.isRead = isRead
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
