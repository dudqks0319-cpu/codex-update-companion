import Foundation

protocol OpenAIChangelogFetching {
    func fetchLatestEntries() async throws -> [ReleaseItem]
}

struct OpenAIChangelogService: OpenAIChangelogFetching {
    private let session: URLSession
    private let changelogURL: URL

    init(session: URLSession = .shared, changelogURL: URL = AppConstants.codexChangelogURL) {
        self.session = session
        self.changelogURL = changelogURL
    }

    func fetchLatestEntries() async throws -> [ReleaseItem] {
        var request = URLRequest(url: changelogURL)
        request.setValue(AppConstants.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12

        let (data, _) = try await session.data(for: request)
        let entries = OpenAIChangelogParser.entries(from: data, baseURL: changelogURL)

        return entries.map { entry in
            let categories = Self.categories(for: entry.surface)
            let body = "\(entry.title)\n\(entry.summary)"
            let impact = ReleaseClassifier.impactLevel(for: body, categories: categories)
            return ReleaseItem(
                id: "openai_changelog:\(entry.id)",
                source: .openAIChangelog,
                version: "OpenAI Changelog",
                title: entry.title,
                publishedAt: entry.date,
                url: entry.url,
                rawBody: body,
                koreanSummary: KoreanSummaryBuilder.summary(
                    version: "OpenAI Changelog",
                    title: entry.title,
                    body: entry.summary,
                    categories: categories,
                    impact: impact
                ),
                categories: categories,
                impactLevel: impact
            )
        }
    }

    private static func categories(for surface: CodexSurface) -> [Category] {
        switch surface {
        case .macApp:
            return [.codexApp]
        case .cli:
            return [.codexCLI]
        case .ide:
            return [.ide]
        case .github:
            return [.githubReview]
        case .security:
            return [.security]
        case .plugin, .model, .web:
            return [.newFeature]
        }
    }
}

public enum OpenAIChangelogParser {
    public static func entries(from data: Data, baseURL: URL) -> [ChangelogEntry] {
        guard let html = String(data: data, encoding: .utf8) else {
            return []
        }

        let text = normalizedText(fromHTML: html)
        let dateRanges = dateMatches(in: text)
        guard !dateRanges.isEmpty else {
            return []
        }

        return dateRanges.prefix(20).compactMap { match in
            let dateText = String(text[match.range])
            guard let date = parseDate(dateText) else {
                return nil
            }

            let start = match.range.upperBound
            let end = match.nextLowerBound ?? text.endIndex
            let chunk = String(text[start..<end])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !chunk.isEmpty else {
                return nil
            }

            let title = firstSentence(from: chunk)
            let summary = String(chunk.prefix(700))
            let surface = surface(for: "\(title) \(summary)")
            let slug = stableSlug(title: title, dateText: dateText)

            return ChangelogEntry(
                id: "\(dateText)-\(slug)",
                title: title,
                date: date,
                surface: surface,
                summary: summary,
                url: baseURL
            )
        }
    }

    private struct DateMatch {
        var range: Range<String.Index>
        var nextLowerBound: String.Index?
    }

    private static func normalizedText(fromHTML html: String) -> String {
        html
            .replacingOccurrences(of: #"<script[\s\S]*?</script>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<style[\s\S]*?</style>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private static func dateMatches(in text: String) -> [DateMatch] {
        let pattern = #"(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]* \d{1,2}, \d{4}|\d{4}-\d{2}-\d{2}"#
        let ranges = text.ranges(of: pattern, options: .regularExpression)
        return ranges.enumerated().map { index, range in
            DateMatch(
                range: range,
                nextLowerBound: index + 1 < ranges.count ? ranges[index + 1].lowerBound : nil
            )
        }
    }

    private static func parseDate(_ text: String) -> Date? {
        for formatter in dateFormatters {
            if let date = formatter.date(from: text) {
                return date
            }
        }
        return nil
    }

    private static func firstSentence(from text: String) -> String {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let separators = CharacterSet(charactersIn: ".\n")
        if let range = cleaned.rangeOfCharacter(from: separators) {
            return String(cleaned[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(cleaned.prefix(90)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func surface(for text: String) -> CodexSurface {
        let lower = text.lowercased()
        if lower.contains("security") || lower.contains("cve") || lower.contains("vulnerability") {
            return .security
        }
        if lower.contains("cli") || lower.contains("terminal") || lower.contains("command line") {
            return .cli
        }
        if lower.contains("ide") || lower.contains("vscode") || lower.contains("jetbrains") {
            return .ide
        }
        if lower.contains("github") || lower.contains("pull request") || lower.contains("review") {
            return .github
        }
        if lower.contains("plugin") || lower.contains("mcp") || lower.contains("skill") {
            return .plugin
        }
        if lower.contains("model") || lower.contains("gpt") {
            return .model
        }
        if lower.contains("web") || lower.contains("chatgpt") {
            return .web
        }
        return .macApp
    }

    private static func stableSlug(title: String, dateText: String) -> String {
        let raw = "\(dateText)-\(title)".lowercased()
        let slug = raw
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return slug.isEmpty ? "codex-changelog" : slug
    }

    private static let dateFormatters: [DateFormatter] = {
        let formats = ["MMM d, yyyy", "MMMM d, yyyy", "yyyy-MM-dd"]
        return formats.map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            return formatter
        }
    }()
}

private extension String {
    func ranges(of pattern: String, options: CompareOptions = []) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var searchStart = startIndex
        while searchStart < endIndex,
              let range = self.range(of: pattern, options: options, range: searchStart..<endIndex) {
            ranges.append(range)
            searchStart = range.upperBound
        }
        return ranges
    }
}
