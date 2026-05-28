import Foundation

public enum ReleaseClassifier {
    public static func categories(for text: String) -> [Category] {
        let haystack = text.lowercased()
        var categories = Set<Category>()

        if containsAny(haystack, ["desktop", "mac app", "macos", "app-server", "codex app", "app server"]) {
            categories.insert(.codexApp)
        }
        if containsAny(haystack, ["cli", "tui", "npm", "cargo", "terminal", "command line", "profile"]) {
            categories.insert(.codexCLI)
        }
        if containsAny(haystack, ["ide", "vscode", "jetbrains", "extension"]) {
            categories.insert(.ide)
        }
        if containsAny(haystack, ["github review", "pull request", "code review", "review"]) {
            categories.insert(.githubReview)
        }
        if containsAny(haystack, ["sandbox", "seatbelt", "network proxy", "read-only", "permission profile"]) {
            categories.insert(.sandbox)
        }
        if containsAny(haystack, ["permission", "auth", "oauth", "login", "access token", "least privilege"]) {
            categories.insert(.permission)
        }
        if containsAny(haystack, ["security", "cve", "vulnerability", "patched", "exploit", "secret"]) {
            categories.insert(.security)
        }
        if containsAny(haystack, ["fix", "bug", "crash", "regression", "flake", "retry", "reconnect"]) {
            categories.insert(.bugFix)
        }
        if containsAny(haystack, ["feat", "feature", "added", "new ", "support ", "introduce"]) {
            categories.insert(.newFeature)
        }
        if containsAny(haystack, ["breaking", "migration", "removed", "deprecated", "reject", "no longer"]) {
            categories.insert(.breakingChange)
        }

        if categories.isEmpty {
            categories.insert(.codexCLI)
        }

        return categories.sorted { $0.rawValue < $1.rawValue }
    }

    public static func impactLevel(for text: String, categories: [Category]) -> ImpactLevel {
        let haystack = text.lowercased()

        if categories.contains(.security), containsAny(haystack, ["critical", "exploit", "credential", "secret"]) {
            return .critical
        }
        if categories.contains(.breakingChange) || categories.contains(.security) || categories.contains(.permission) {
            return .high
        }
        if categories.contains(.sandbox) || categories.contains(.newFeature) || categories.contains(.bugFix) {
            return .medium
        }
        return .low
    }

    private static func containsAny(_ haystack: String, _ needles: [String]) -> Bool {
        needles.contains { haystack.contains($0) }
    }
}

public enum KoreanSummaryBuilder {
    public static func summary(version: String, title: String, body: String, categories: [Category], impact: ImpactLevel) -> String {
        let digest = FriendlyReleaseDigestBuilder.digest(
            version: version,
            title: title,
            body: body,
            categories: categories,
            impact: impact
        )

        return digest.changes
            .prefix(3)
            .enumerated()
            .map { index, change in
                "\(index + 1). \(change.areaTitle) 업데이트: \(change.kindTitle) - \(change.plainDetail)"
            }
            .joined(separator: "\n")
    }
}

public enum FriendlyChangeKind: String, Equatable {
    case securityFix
    case permissionChange
    case sandboxChange
    case bugFix
    case newFeature
    case breakingChange
    case general

    var title: String {
        switch self {
        case .securityFix:
            "보안 수정"
        case .permissionChange:
            "권한 변경"
        case .sandboxChange:
            "실행 제한 변경"
        case .bugFix:
            "버그 수정"
        case .newFeature:
            "새 기능"
        case .breakingChange:
            "주의 필요 변경"
        case .general:
            "일반 개선"
        }
    }
}

public struct FriendlyChange: Identifiable, Equatable {
    public var id: String
    public var areaTitle: String
    public var kind: FriendlyChangeKind
    public var kindTitle: String
    public var plainDetail: String
    public var whyItMatters: String
    public var howToUse: [String]
    public var whereToCheck: String
    public var evidence: String
}

public struct FriendlyChangeSection: Identifiable, Equatable {
    public var id: String
    public var title: String
    public var rawTitle: String
    public var changes: [FriendlyChange]
}

public struct FriendlyReleaseDigest: Equatable {
    public var sections: [FriendlyChangeSection]

    public var changes: [FriendlyChange] {
        sections.flatMap(\.changes)
    }

    public var securityRelatedChanges: [FriendlyChange] {
        changes.filter { change in
            [.securityFix, .permissionChange, .sandboxChange, .breakingChange].contains(change.kind)
        }
    }

    public var bugFixChanges: [FriendlyChange] {
        changes.filter { $0.kind == .bugFix }
    }
}

public enum FriendlyReleaseDigestBuilder {
    public static func digest(for item: ReleaseItem) -> FriendlyReleaseDigest {
        digest(
            version: item.version,
            title: item.title,
            body: item.rawBody,
            categories: item.categories,
            impact: item.impactLevel
        )
    }

    static func digest(
        version: String,
        title: String,
        body: String,
        categories: [Category],
        impact: ImpactLevel
    ) -> FriendlyReleaseDigest {
        let sections = markdownSections(from: body)
        var friendlySections: [FriendlyChangeSection] = sections.enumerated().compactMap { sectionIndex, section in
            let changes = section.lines.enumerated().map { lineIndex, line in
                change(
                    version: version,
                    sectionIndex: sectionIndex,
                    lineIndex: lineIndex,
                    line: line,
                    categories: categories
                )
            }

            guard !changes.isEmpty else {
                return nil
            }

            return FriendlyChangeSection(
                id: "\(version)-section-\(sectionIndex)-\(section.title)",
                title: displayTitle(forSection: section.title),
                rawTitle: section.title,
                changes: mergeSimilar(changes, limit: 120)
            )
        }

        if friendlySections.isEmpty {
            friendlySections = [
                FriendlyChangeSection(
                    id: "\(version)-fallback-section",
                    title: "요약",
                    rawTitle: "Summary",
                    changes: fallbackChanges(version: version, title: title, categories: categories, impact: impact)
                )
            ]
        }

        return FriendlyReleaseDigest(sections: friendlySections)
    }

    private static func change(
        version: String,
        sectionIndex: Int,
        lineIndex: Int,
        line: String,
        categories: [Category]
    ) -> FriendlyChange {
        let kind = kind(for: line, categories: categories)
        let area = areaTitle(for: line, categories: categories)

        return FriendlyChange(
            id: "\(version)-\(sectionIndex)-\(lineIndex)-\(area)-\(kind.rawValue)",
            areaTitle: area,
            kind: kind,
            kindTitle: kind.title,
            plainDetail: plainDetail(for: line, kind: kind),
            whyItMatters: whyItMatters(for: line, kind: kind),
            howToUse: howToUse(for: line, kind: kind),
            whereToCheck: whereToCheck(for: line, area: area),
            evidence: line
        )
    }

    private static func fallbackChanges(
        version: String,
        title: String,
        categories: [Category],
        impact: ImpactLevel
    ) -> [FriendlyChange] {
        let kind = fallbackKind(categories: categories, impact: impact)
        let area = primaryAreaTitle(categories)
        return [
            FriendlyChange(
                id: "\(version)-fallback-\(area)-\(kind.rawValue)",
                areaTitle: area,
                kind: kind,
                kindTitle: kind.title,
                plainDetail: "원문 설명이 짧아 세부 내용은 제한적으로만 확인됩니다. 제목 기준으로 \(title)을 확인하세요.",
                whyItMatters: "릴리즈 노트 본문이 짧으면 실제 체감 변화가 제목이나 링크 뒤의 changelog에만 있을 수 있습니다.",
                howToUse: ["원문 열기를 눌러 공식 릴리즈 페이지를 확인하세요.", "업데이트 후 평소 쓰던 Codex 흐름을 한 번 실행해보세요."],
                whereToCheck: "GitHub release 원문 또는 OpenAI Codex changelog",
                evidence: title
            )
        ]
    }

    private static func mergeSimilar(_ changes: [FriendlyChange], limit: Int) -> [FriendlyChange] {
        var seen = Set<String>()
        var merged: [FriendlyChange] = []

        for change in changes {
            let key = "\(change.areaTitle)-\(change.kind.rawValue)-\(change.plainDetail)"
            guard !seen.contains(key) else {
                continue
            }
            seen.insert(key)
            merged.append(change)
        }

        return Array(merged.prefix(limit))
    }

    private static func kind(for line: String, categories: [Category]) -> FriendlyChangeKind {
        let lower = line.lowercased()

        if containsAny(lower, ["security", "cve", "vulnerability", "exploit", "credential", "secret"]) {
            return .securityFix
        }
        if containsAny(lower, ["permission", "auth", "oauth", "login", "token", "access"]) {
            return .permissionChange
        }
        if containsAny(lower, ["sandbox", "seatbelt", "read-only", "network proxy", "managed network proxy"]) {
            return .sandboxChange
        }
        if containsAny(lower, ["fix", "fixed", "bug", "crash", "regression", "reconnect", "retry", "incorrect", "case-insensitive"]) {
            return .bugFix
        }
        if containsAny(lower, ["breaking", "removed", "deprecated", "migration", "no longer"]) {
            return .breakingChange
        }
        if containsAny(lower, ["add", "added", "new", "support", "search", "preview", "introduce", "goal", "improved", "made", "let"]) {
            return .newFeature
        }

        return fallbackKind(categories: categories, impact: .low)
    }

    private static func fallbackKind(categories: [Category], impact: ImpactLevel) -> FriendlyChangeKind {
        if categories.contains(.security) {
            return .securityFix
        }
        if categories.contains(.permission) {
            return .permissionChange
        }
        if categories.contains(.sandbox) {
            return .sandboxChange
        }
        if categories.contains(.bugFix) {
            return .bugFix
        }
        if categories.contains(.breakingChange) || impact >= .high {
            return .breakingChange
        }
        if categories.contains(.newFeature) {
            return .newFeature
        }
        return .general
    }

    private static func areaTitle(for line: String, categories: [Category]) -> String {
        let lower = line.lowercased()

        if containsAny(lower, ["goal", "/goal", "objective", "acceptance criteria"]) {
            return "Goal"
        }
        if containsAny(lower, ["cli", "tui", "terminal", "command line", "npm", "profile", "powershell", "curl", "cargo", "just test"]) {
            return "CLI"
        }
        if containsAny(lower, ["desktop", "mac app", "macos", "app-server", "app server", "local conversation", "conversation history", "result preview"]) {
            return "맥앱"
        }
        if containsAny(lower, ["ide", "vscode", "jetbrains", "extension"]) {
            return "IDE"
        }
        if containsAny(lower, ["github review", "pull request", "pr review", "code review"]) {
            return "GitHub 리뷰"
        }
        if containsAny(lower, ["mcp", "connector", "tool schema", "hook", "extension", "subagent", "read-only", "readonlyhint"]) {
            return "확장/도구"
        }
        if containsAny(lower, ["packaging", "artifact", "dotslash", "release-build", "v8", "zsh"]) {
            return "배포/패키징"
        }
        if containsAny(lower, ["trace", "analytics", "websocket", "compaction", "turnstarted"]) {
            return "원격/분석"
        }
        if containsAny(lower, ["sandbox", "permission", "auth", "login"]) {
            return "보안/권한"
        }

        return primaryAreaTitle(categories)
    }

    private static func primaryAreaTitle(_ categories: [Category]) -> String {
        if categories.contains(.codexApp) {
            return "맥앱"
        }
        if categories.contains(.codexCLI) {
            return "CLI"
        }
        if categories.contains(.ide) {
            return "IDE"
        }
        if categories.contains(.githubReview) {
            return "GitHub 리뷰"
        }
        if categories.contains(.sandbox) || categories.contains(.permission) || categories.contains(.security) {
            return "보안/권한"
        }
        return "Codex"
    }

    private static func plainDetail(for line: String, kind: FriendlyChangeKind) -> String {
        let lower = line.lowercased()

        if lower.contains("search across local conversation history") {
            return "내 Mac에 있는 Codex 대화 기록을 검색하고 결과 미리보기를 볼 수 있게 했습니다."
        }
        if lower.contains("goal") || lower.contains("/goal") {
            return "작업 목표를 Codex 안에 저장하고, 완료 기준과 진행 상태를 추적할 수 있게 한 기능입니다."
        }
        if lower.contains("case-insensitive") {
            return "검색할 때 대소문자 차이 때문에 결과가 빠지는 문제를 줄였습니다."
        }
        if lower.contains("--profile") || lower.contains("profile") {
            return "CLI, TUI, 샌드박스 권한 흐름에서 사용할 기본 프로필 선택 방식이 `--profile` 중심으로 정리되었습니다."
        }
        if lower.contains("mcp") && lower.contains("oauth") {
            return "MCP 서버를 추가하거나 연결할 때 서버별 환경값과 OAuth 옵션을 더 명확하게 지정할 수 있게 했습니다."
        }
        if lower.contains("$ref") || lower.contains("$defs") || lower.contains("tool schema") {
            return "커넥터 도구 스키마가 큰 경우에도 구조를 유지하고 압축해 도구 노출이 더 안정적으로 동작하게 했습니다."
        }
        if lower.contains("readonlyhint") || lower.contains("read-only") {
            return "읽기 전용 MCP 도구는 서로 충돌 위험이 낮을 때 동시에 실행될 수 있게 했습니다."
        }
        if lower.contains("hook") || lower.contains("extension") || lower.contains("subagent") {
            return "확장 도구와 후크가 대화 기록이나 하위 에이전트 정보를 더 많이 받아 상황에 맞게 동작할 수 있게 했습니다."
        }
        if lower.contains("reconnect") {
            return "네트워크가 끊겼다가 다시 연결될 때 생기던 오류를 줄였습니다."
        }
        if lower.contains("remote compaction") || lower.contains("remote control") || lower.contains("websocket") {
            return "원격 세션, 웹소켓 연결, 압축 스트림이 실패했을 때 재연결과 재시도가 더 안정적으로 동작하게 했습니다."
        }
        if lower.contains("windows") && lower.contains("tui") {
            return "Windows 터미널에서 TUI 화면이 깨져 보일 수 있는 렌더링 문제를 수정했습니다."
        }
        if lower.contains("usage-limit") || lower.contains("spend-cap") || lower.contains("credit") {
            return "크레딧이나 지출 한도에 걸렸을 때 어느 작업공간의 제한인지 더 구체적으로 보여줍니다."
        }
        if lower.contains("icon asset") {
            return "플러그인 스킬이 공통 아이콘 에셋을 재사용할 수 있게 해 표시 누락 가능성을 줄였습니다."
        }
        if lower.contains("managed network proxy") || lower.contains("node env proxy") {
            return "Node 기반 도구도 Codex가 관리하는 네트워크 프록시 설정을 따르도록 수정했습니다."
        }
        if lower.contains("curl") || lower.contains("powershell") {
            return "README에 curl과 PowerShell 설치 경로가 추가되어 설치 방법을 찾기 쉬워졌습니다."
        }
        if lower.contains("just test") || lower.contains("cargo test") {
            return "저장소 로컬 테스트는 `cargo test`를 직접 치기보다 `just test`를 우선 쓰도록 문서가 정리되었습니다."
        }
        if lower.contains("packaging") || lower.contains("artifact") || lower.contains("dotslash") || lower.contains("zsh") {
            return "릴리스 패키징과 플랫폼별 배포 아티팩트 생성 흐름이 정리되었습니다."
        }
        if lower.contains("v8 artifact") {
            return "Codex가 생성한 V8 아티팩트를 릴리스 빌드에 포함할 수 있게 했습니다."
        }
        if lower.contains("benchmark") || lower.contains("fixture") {
            return "성능 측정과 스키마 정책 검증을 위한 테스트 자료가 추가되었습니다."
        }
        if lower.contains("trace") || lower.contains("analytics") {
            return "웹소켓 요청, 턴 시작, 원격 압축 같은 내부 동작을 추적하고 분석하는 정보가 늘었습니다."
        }
        if lower.contains("crash") {
            return "앱이나 CLI가 비정상 종료되던 상황을 수정했습니다."
        }
        if lower.contains("sandbox") || lower.contains("seatbelt") {
            return "Codex가 명령을 실행할 때 허용/차단하는 범위를 조정했습니다."
        }
        if lower.contains("permission") || lower.contains("auth") || lower.contains("login") {
            return "로그인, 권한 요청, 접근 허용 방식과 관련된 동작을 조정했습니다."
        }
        if lower.contains("security") || lower.contains("vulnerability") || lower.contains("cve") {
            return "외부 접근, 취약점, 민감정보 노출 가능성과 관련된 보안 항목을 수정했습니다."
        }
        if lower.contains("removed") || lower.contains("deprecated") {
            return "기존에 쓰던 기능이나 옵션이 바뀌었거나 사라졌을 수 있습니다."
        }

        switch kind {
        case .securityFix:
            return "보안과 관련된 문제를 수정했습니다. 원문 항목을 함께 확인하세요: \(line)"
        case .permissionChange:
            return "권한 요청이나 접근 허용 방식이 바뀌었습니다. 원문 항목: \(line)"
        case .sandboxChange:
            return "명령 실행 제한이나 파일/네트워크 접근 범위가 바뀌었습니다. 원문 항목: \(line)"
        case .bugFix:
            return "사용 중 오류가 나던 동작을 수정했습니다. 원문 항목: \(line)"
        case .newFeature:
            return "새로 사용할 수 있는 기능이 추가되었습니다. 원문 항목: \(line)"
        case .breakingChange:
            return "기존 사용 방식이 달라질 수 있는 변경입니다. 원문 항목: \(line)"
        case .general:
            return "일반 개선 사항입니다. 원문 항목: \(line)"
        }
    }

    private static func whyItMatters(for line: String, kind: FriendlyChangeKind) -> String {
        let lower = line.lowercased()

        if lower.contains("goal") || lower.contains("/goal") {
            return "긴 작업을 하다 보면 Codex가 무엇을 완료해야 하는지 흐려질 수 있습니다. Goal은 목표와 완료 기준을 고정해서 중간에 방향이 틀어지는 일을 줄여줍니다."
        }
        if lower.contains("search across local conversation history") {
            return "예전에 Codex와 나눈 대화나 작업 근거를 다시 찾기 쉬워져, 업데이트 내용이나 이전 결정사항을 빠르게 확인할 수 있습니다."
        }
        if lower.contains("--profile") || lower.contains("profile") {
            return "프로필 설정을 여러 곳에서 다르게 해석하면 권한이나 샌드박스 동작이 헷갈릴 수 있습니다. 이번 변경은 선택 기준을 하나로 맞추는 성격입니다."
        }
        if lower.contains("mcp") || lower.contains("connector") || lower.contains("tool schema") {
            return "MCP나 커넥터를 쓰는 사용자는 도구 연결 실패, 스키마 오류, 인증 옵션 누락 같은 문제가 줄어들 수 있습니다."
        }
        if lower.contains("remote") || lower.contains("websocket") {
            return "원격 환경을 쓰는 경우 연결 끊김이나 인증 복구 뒤 작업을 다시 이어가는 안정성이 중요합니다."
        }
        if lower.contains("usage-limit") || lower.contains("spend-cap") || lower.contains("credit") {
            return "한도 초과 메시지가 구체적이면 어떤 워크스페이스에서 비용이나 사용량을 조정해야 하는지 빨리 알 수 있습니다."
        }
        if lower.contains("case-insensitive") {
            return "대문자/소문자를 정확히 기억하지 않아도 검색 결과가 더 잘 나옵니다."
        }
        if lower.contains("reconnect") {
            return "네트워크가 흔들릴 때 작업이 끊기거나 다시 시작해야 하는 상황을 줄입니다."
        }
        if lower.contains("sandbox") || lower.contains("seatbelt") {
            return "Codex가 로컬 명령을 어디까지 실행할 수 있는지에 영향을 주므로, 보안과 작업 편의성 모두에 관련됩니다."
        }
        if lower.contains("permission") || lower.contains("auth") || lower.contains("login") {
            return "로그인이나 권한 요청 흐름이 달라지면 기존에 허용되던 작업이 다시 승인을 요구할 수 있습니다."
        }

        switch kind {
        case .securityFix:
            return "민감정보 노출, 권한 우회, 외부 접근 같은 위험을 줄이는 데 관련됩니다."
        case .permissionChange:
            return "사용자가 무엇을 허용했는지 더 명확해지고, 불필요한 권한 사용을 줄일 수 있습니다."
        case .sandboxChange:
            return "Codex가 파일, 네트워크, 명령 실행에 접근하는 범위가 달라질 수 있습니다."
        case .bugFix:
            return "평소 쓰던 기능에서 오류나 중단이 줄어드는 체감 개선입니다."
        case .newFeature:
            return "새로운 작업 방식이나 더 빠른 확인 흐름을 사용할 수 있습니다."
        case .breakingChange:
            return "기존 명령, 설정, 자동화가 그대로 동작하지 않을 수 있습니다."
        case .general:
            return "작은 개선이지만 특정 상황에서는 사용 경험이 달라질 수 있습니다."
        }
    }

    private static func howToUse(for line: String, kind: FriendlyChangeKind) -> [String] {
        let lower = line.lowercased()

        if lower.contains("goal") || lower.contains("/goal") {
            return [
                "Codex 입력창에서 `/goal` 또는 Goal 관련 명령을 엽니다.",
                "예: `이 작업을 목표로 잡아줘: 앱 출시 전 보안 점검 완료`처럼 목표를 짧게 씁니다.",
                "완료 기준을 같이 적습니다. 예: `빌드 통과, 테스트 통과, 남은 리스크 정리`.",
                "작업 중에는 Goal 상태를 확인해서 남은 단계와 차단 요인을 봅니다.",
                "완료되면 Goal을 완료 처리해서 다음 작업과 섞이지 않게 합니다."
            ]
        }

        if lower.contains("search across local conversation history") {
            return [
                "Codex에서 이전 대화나 작업명을 검색합니다.",
                "결과 미리보기를 보고 필요한 대화로 이동합니다.",
                "대소문자가 섞인 검색어도 함께 시도해봅니다."
            ]
        }

        if lower.contains("--profile") || lower.contains("profile") {
            return [
                "터미널에서 `codex --profile <이름>` 형태로 원하는 프로필을 지정합니다.",
                "기존 프로필 설정 오류가 보이면 마이그레이션 안내 링크를 따라 새 형식으로 옮깁니다.",
                "샌드박스나 권한 프롬프트가 예상한 프로필 기준으로 뜨는지 확인합니다."
            ]
        }

        if lower.contains("mcp") || lower.contains("connector") || lower.contains("tool schema") {
            return [
                "사용 중인 MCP 서버나 커넥터를 한 번 다시 연결해봅니다.",
                "OAuth가 필요한 서버는 인증 옵션이 정상적으로 유지되는지 확인합니다.",
                "도구 호출 실패가 줄었는지 작은 작업으로 확인합니다."
            ]
        }

        if lower.contains("reconnect") {
            return [
                "네트워크가 끊긴 뒤 Codex를 다시 연결해봅니다.",
                "이전보다 세션 복구나 재시도 흐름이 안정적인지 확인합니다."
            ]
        }

        if lower.contains("remote") || lower.contains("websocket") || lower.contains("compaction") {
            return [
                "원격 세션을 연결한 뒤 네트워크가 끊겼다가 복구되는 상황을 확인합니다.",
                "이전보다 재시도 메시지나 세션 복구가 자연스러운지 봅니다."
            ]
        }

        if lower.contains("windows") && lower.contains("tui") {
            return [
                "Windows 터미널에서 Codex TUI를 실행합니다.",
                "화면 깨짐이나 글자 잔상이 줄었는지 확인합니다."
            ]
        }

        if lower.contains("sandbox") || lower.contains("permission") {
            return [
                "업데이트 후 평소 쓰던 파일 읽기, 테스트 실행, 네트워크 요청 작업을 한 번 실행합니다.",
                "승인 프롬프트가 새로 뜨면 요청 내용이 맞는지 확인한 뒤 허용합니다.",
                "예전보다 권한 요청이 늘거나 줄었는지 확인합니다."
            ]
        }

        switch kind {
        case .securityFix:
            return ["가능하면 최신 버전으로 업데이트합니다.", "업데이트 후 로그인, 권한, 파일 접근 흐름이 정상인지 확인합니다."]
        case .permissionChange:
            return ["권한 요청이 뜨면 어떤 작업을 허용하는지 확인합니다.", "불필요해 보이는 권한은 거절하고 원문을 확인합니다."]
        case .sandboxChange:
            return ["테스트 실행, 파일 수정, 네트워크 요청처럼 자주 쓰는 작업을 실행해봅니다.", "차단 메시지가 바뀌었는지 확인합니다."]
        case .bugFix:
            return ["이전에 문제를 겪던 상황을 다시 실행해봅니다.", "같은 오류가 재현되는지 확인합니다."]
        case .newFeature:
            return ["릴리즈 원문의 기능 이름을 기준으로 앱/CLI에서 해당 메뉴나 명령을 찾아봅니다.", "작은 테스트 작업으로 먼저 사용해봅니다."]
        case .breakingChange:
            return ["기존 스크립트나 설정을 백업합니다.", "업데이트 후 자동화 명령을 한 번씩 실행해 깨지는 부분이 있는지 확인합니다."]
        case .general:
            return ["업데이트 후 평소 쓰던 흐름을 가볍게 확인합니다."]
        }
    }

    private static func whereToCheck(for line: String, area: String) -> String {
        let lower = line.lowercased()

        if lower.contains("goal") || lower.contains("/goal") {
            return "Codex 입력창의 `/goal` 기능 또는 Goal 상태 UI"
        }
        if lower.contains("conversation history") || lower.contains("search") {
            return "Codex 앱의 검색 또는 대화 기록 영역"
        }
        if area == "CLI" {
            return "터미널에서 `codex` 명령과 관련 설정"
        }
        if area == "맥앱" {
            return "Codex Mac 앱 화면, 메뉴바, 설정"
        }
        if area == "IDE" {
            return "사용 중인 IDE 확장 설정과 명령 팔레트"
        }
        if area == "GitHub 리뷰" {
            return "GitHub PR 리뷰 화면과 Codex 리뷰 결과"
        }
        if area == "보안/권한" {
            return "권한 요청 팝업, sandbox/approval 메시지, 설정"
        }
        if area == "확장/도구" {
            return "MCP 설정, 커넥터 도구 목록, 플러그인/후크 실행 결과"
        }
        if area == "배포/패키징" {
            return "GitHub release asset, npm 패키지, macOS 아티팩트"
        }
        if area == "원격/분석" {
            return "원격 세션 로그, 재연결 메시지, trace/analytics 로그"
        }
        return "원문 릴리즈 노트와 OpenAI Codex changelog"
    }

    private struct MarkdownSection {
        var title: String
        var lines: [String]
    }

    private static func markdownSections(from body: String) -> [MarkdownSection] {
        var sections: [MarkdownSection] = []
        var currentTitle = "요약"
        var currentLines: [String] = []

        func flush() {
            let lines = currentLines
            if !lines.isEmpty {
                sections.append(MarkdownSection(title: currentTitle, lines: lines))
            }
            currentLines = []
        }

        for rawLine in body.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            if let heading = markdownHeadingTitle(from: trimmed) {
                flush()
                currentTitle = heading
                continue
            }

            guard let line = meaningfulLine(from: trimmed, dropsSectionIntro: true) else {
                continue
            }
            currentLines.append(line)
        }

        flush()
        return sections
    }

    private static func markdownHeadingTitle(from line: String) -> String? {
        guard line.hasPrefix("#") else {
            return nil
        }

        let title = line
            .drop(while: { $0 == "#" || $0 == " " })
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    private static func displayTitle(forSection title: String) -> String {
        let lower = title.lowercased()

        if lower.contains("new feature") || lower.contains("feature") {
            return "새로운 기능"
        }
        if lower.contains("bug") || lower.contains("fix") {
            return "버그 수정"
        }
        if lower.contains("documentation") || lower.contains("docs") {
            return "문서"
        }
        if lower.contains("chore") {
            return "정리/릴리스 작업"
        }
        if lower.contains("changelog") || lower.contains("changed") {
            return "전체 변경 로그"
        }
        if title == "요약" {
            return title
        }
        return title
    }

    private static func meaningfulLines(from body: String) -> [String] {
        body
            .components(separatedBy: .newlines)
            .compactMap { line in
                meaningfulLine(from: line, dropsSectionIntro: true)
            }
    }

    private static func meaningfulLine(from rawLine: String, dropsSectionIntro: Bool) -> String? {
        let line = rawLine
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "*-#` "))

        let lower = line.lowercased()
        guard !line.isEmpty,
              !lower.hasPrefix("full changelog"),
              !lower.contains("compare/"),
              line.count > 8 else {
            return nil
        }

        if dropsSectionIntro, lower.hasPrefix("what") {
            return nil
        }

        return line
    }

    private static func containsAny(_ haystack: String, _ needles: [String]) -> Bool {
        needles.contains { haystack.contains($0) }
    }
}

public struct DetailedReleaseExplanation: Equatable {
    public var headline: String
    public var plainLanguageSummary: String
    public var userImpactBullets: [String]
    public var attentionBullets: [String]
    public var rawHighlights: [String]
}

public enum DetailedExplanationBuilder {
    public static func explanation(for item: ReleaseItem) -> DetailedReleaseExplanation {
        let highlights = meaningfulLines(from: item.rawBody)
        let primaryCategory = primaryCategoryPhrase(item.categories)
        let headline = "\(item.version): \(primaryCategory) 업데이트 상세"
        let plainLanguageSummary = plainLanguageSummary(for: item, primaryCategory: primaryCategory, highlights: highlights)

        return DetailedReleaseExplanation(
            headline: headline,
            plainLanguageSummary: plainLanguageSummary,
            userImpactBullets: userImpactBullets(for: item, highlights: highlights),
            attentionBullets: attentionBullets(for: item),
            rawHighlights: Array(highlights.prefix(8))
        )
    }

    private static func plainLanguageSummary(
        for item: ReleaseItem,
        primaryCategory: String,
        highlights: [String]
    ) -> String {
        let firstHighlight = highlights.first ?? item.title
        let impact = item.impactLevel.displayName

        if item.categories.contains(.security) || item.categories.contains(.permission) {
            return "이번 업데이트는 \(primaryCategory)에서 보안, 인증, 권한 흐름과 관련된 변경이 포함된 것으로 보입니다. 중요도는 \(impact)입니다. 특히 \(firstHighlight)을 확인해야 합니다."
        }

        if item.categories.contains(.breakingChange) {
            return "이번 업데이트는 기존 동작이 달라질 수 있는 변경을 포함합니다. 중요도는 \(impact)입니다. 업데이트 전후로 설정, 명령어, 자동화 스크립트가 같은 방식으로 동작하는지 확인하는 편이 좋습니다."
        }

        if item.categories.contains(.sandbox) {
            return "이번 업데이트는 Codex가 로컬에서 명령을 실행하거나 파일/네트워크 접근을 제한하는 방식과 관련된 변화가 있을 수 있습니다. 중요도는 \(impact)이며, \(firstHighlight)을 중심으로 확인하면 됩니다."
        }

        if item.categories.contains(.bugFix) {
            return "이번 업데이트는 사용 중 겪던 오류, 크래시, 재시도, 연결 안정성 같은 문제를 줄이는 성격이 큽니다. 중요도는 \(impact)이며, \(firstHighlight)이 핵심 단서입니다."
        }

        if item.categories.contains(.newFeature) {
            return "이번 업데이트는 \(primaryCategory)에 새 기능이나 지원 범위 확대가 들어간 릴리즈로 보입니다. 중요도는 \(impact)이며, \(firstHighlight)을 먼저 보면 체감 변화를 빠르게 파악할 수 있습니다."
        }

        return "이번 릴리즈는 \(primaryCategory) 관련 일반 업데이트입니다. 중요도는 \(impact)이며, 원문 릴리즈 노트가 짧다면 실제 변경은 GitHub 커밋이나 changelog 링크에서 추가 확인이 필요합니다."
    }

    private static func userImpactBullets(for item: ReleaseItem, highlights: [String]) -> [String] {
        var bullets: [String] = []

        if item.categories.contains(.codexApp) {
            bullets.append("Mac 앱 사용자라면 앱 실행, 메뉴, 세션 표시, 알림 같은 데스크톱 경험이 달라졌는지 확인하세요.")
        }
        if item.categories.contains(.codexCLI) {
            bullets.append("CLI 사용자라면 기존 명령어, 설정 파일, sandbox/approval 동작이 그대로 맞는지 확인하세요.")
        }
        if item.categories.contains(.ide) {
            bullets.append("IDE 확장 사용자는 에디터 연결, 리뷰 표시, 명령 실행 흐름이 달라졌는지 확인하면 좋습니다.")
        }
        if item.categories.contains(.githubReview) {
            bullets.append("GitHub Review 기능을 쓰는 경우 PR 댓글, 리뷰 권한, 체크 결과 표시 흐름을 확인하세요.")
        }

        highlights.prefix(3).forEach { highlight in
            bullets.append("원문 주요 항목: \(highlight)")
        }

        if bullets.isEmpty {
            bullets.append("원문 릴리즈 노트가 짧아 사용자 영향은 제한적으로만 추정됩니다.")
        }

        return bullets
    }

    private static func attentionBullets(for item: ReleaseItem) -> [String] {
        var bullets: [String] = []

        if item.impactLevel >= .high {
            bullets.append("중요도가 높으므로 업데이트 직후 자주 쓰는 워크플로우를 한 번 실행해보는 것이 좋습니다.")
        }
        if item.categories.contains(.breakingChange) {
            bullets.append("breaking/deprecated/remove 계열 단어가 감지되었습니다. 기존 자동화나 스크립트가 깨질 수 있습니다.")
        }
        if item.categories.contains(.permission) || item.categories.contains(.sandbox) {
            bullets.append("권한 또는 sandbox 관련 변경은 로컬 파일 접근, 네트워크 접근, 승인 프롬프트 체감에 영향을 줄 수 있습니다.")
        }
        if item.categories.contains(.security) {
            bullets.append("보안 관련 릴리즈는 가능한 빨리 적용하고, 관련 설정이 의도대로 유지되는지 확인하세요.")
        }

        bullets.append("이 설명은 공개 GitHub release 원문을 로컬 규칙으로 풀어쓴 것입니다. 공식 판단은 원문 링크와 OpenAI changelog를 기준으로 확인하세요.")
        return bullets
    }

    private static func meaningfulLines(from body: String) -> [String] {
        body
            .components(separatedBy: .newlines)
            .map { line in
                line
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "*-#` "))
            }
            .filter { line in
                !line.isEmpty &&
                    !line.lowercased().hasPrefix("full changelog") &&
                    !line.lowercased().contains("compare/") &&
                    line.count > 8
            }
            .map { String($0.prefix(240)) }
    }

    private static func primaryCategoryPhrase(_ categories: [Category]) -> String {
        if categories.contains(.codexApp) {
            return "Codex Mac App"
        }
        if categories.contains(.codexCLI) {
            return "Codex CLI"
        }
        if categories.contains(.ide) {
            return "IDE"
        }
        if categories.contains(.githubReview) {
            return "GitHub Review"
        }
        if categories.contains(.sandbox) {
            return "Sandbox"
        }
        return "Codex"
    }
}
