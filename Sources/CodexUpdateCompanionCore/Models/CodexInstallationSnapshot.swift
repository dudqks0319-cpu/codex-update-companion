import Foundation

public enum CodexAppUpdateState: Equatable {
    case unknown
    case upToDate
    case updateAvailable
    case newerThanFeed
}

public struct CodexMacAppUpdate: Equatable {
    public var version: String
    public var build: String
    public var publishedAt: Date?
    public var downloadURL: URL?
    public var appcastURL: URL

    public var displayVersion: String {
        "\(version) (\(build))"
    }
}

public struct CodexInstallationSnapshot: Equatable {
    public var appVersion: String?
    public var appBuild: String?
    public var appPath: String?
    public var appLatestVersion: String?
    public var appLatestBuild: String?
    public var appUpdatePublishedAt: Date?
    public var appUpdateDownloadURL: URL?
    public var appUpdateFeedURL: URL?
    public var appUpdateCheckFailed: Bool
    public var cliVersion: String?
    public var cliPath: String?
    public var cliResolvedPath: String?
    public var cliInstallMethod: String?
    public var cliUpdateCommand: String?
    public var checkedAt: Date

    public var appDisplayVersion: String {
        if let appVersion, let appBuild, !appBuild.isEmpty {
            return "\(appVersion) (\(appBuild))"
        }
        return appVersion ?? "확인 불가"
    }

    public var cliDisplayVersion: String {
        cliVersion ?? "확인 불가"
    }

    public var appLatestDisplayVersion: String {
        if let appLatestVersion, let appLatestBuild, !appLatestBuild.isEmpty {
            return "\(appLatestVersion) (\(appLatestBuild))"
        }
        return appLatestVersion ?? "확인 불가"
    }

    public var appUpdateState: CodexAppUpdateState {
        guard let appBuild, let appLatestBuild else {
            return .unknown
        }

        if let currentBuild = Int(appBuild), let latestBuild = Int(appLatestBuild) {
            if currentBuild < latestBuild {
                return .updateAvailable
            }
            if currentBuild > latestBuild {
                return .newerThanFeed
            }
            return .upToDate
        }

        guard let appVersion, let appLatestVersion else {
            return .unknown
        }

        let comparison = appVersion.compare(appLatestVersion, options: .numeric)
        switch comparison {
        case .orderedAscending:
            return .updateAvailable
        case .orderedDescending:
            return .newerThanFeed
        case .orderedSame:
            return .upToDate
        }
    }

    public var isMacAppUpdateAvailable: Bool {
        appUpdateState == .updateAvailable
    }
}
