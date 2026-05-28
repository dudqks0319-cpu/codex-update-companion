import Foundation

public enum CodexSurface: String, Codable, CaseIterable, Sendable {
    case macApp
    case cli
    case ide
    case web
    case github
    case model
    case plugin
    case security
}

public struct ChangelogEntry: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var date: Date
    public var surface: CodexSurface
    public var summary: String
    public var url: URL
}
