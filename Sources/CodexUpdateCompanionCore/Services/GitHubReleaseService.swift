import Foundation

enum ReleaseFetchError: LocalizedError {
    case invalidResponse
    case rateLimited
    case serverStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "GitHub 응답을 읽을 수 없습니다."
        case .rateLimited:
            "GitHub 공개 API rate limit에 도달했습니다. 잠시 뒤 다시 시도하세요."
        case let .serverStatus(statusCode):
            "GitHub releases 요청이 실패했습니다. HTTP \(statusCode)"
        }
    }
}

struct GitHubReleaseService {
    private let releasesURL: URL
    private let session: URLSession

    init(releasesURL: URL = AppConstants.githubReleasesURL, session: URLSession = .shared) {
        self.releasesURL = releasesURL
        self.session = session
    }

    func fetchLatestReleases() async throws -> [ReleaseItem] {
        var request = URLRequest(url: releasesURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(AppConstants.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReleaseFetchError.invalidResponse
        }

        if httpResponse.statusCode == 403, httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0" {
            throw ReleaseFetchError.rateLimited
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ReleaseFetchError.serverStatus(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let releases = try decoder.decode([GitHubReleaseDTO].self, from: data)
        return releases.map { dto in
            let body = dto.body ?? ""
            let title = dto.name?.nilIfBlank ?? dto.tagName
            let text = "\(dto.tagName) \(title) \(body)"
            let categories = ReleaseClassifier.categories(for: text)
            let impact = ReleaseClassifier.impactLevel(for: text, categories: categories)
            let summary = KoreanSummaryBuilder.summary(
                version: dto.tagName,
                title: title,
                body: body,
                categories: categories,
                impact: impact
            )

            return ReleaseItem(
                id: "github_release:\(dto.id)",
                source: .githubRelease,
                version: dto.tagName,
                title: title,
                publishedAt: dto.publishedAt ?? dto.createdAt,
                url: dto.htmlUrl,
                rawBody: body,
                koreanSummary: summary,
                categories: categories,
                impactLevel: impact
            )
        }
    }
}

private struct GitHubReleaseDTO: Decodable {
    let id: Int
    let tagName: String
    let name: String?
    let htmlUrl: URL
    let body: String?
    let createdAt: Date
    let publishedAt: Date?
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
