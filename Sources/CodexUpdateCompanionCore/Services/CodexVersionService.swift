import AppKit
import Foundation

struct CodexVersionService {
    func currentSnapshot() async -> CodexInstallationSnapshot {
        async let cliInfo = cliVersionInfo()
        async let macUpdateInfo = latestMacAppUpdate()
        let appInfo = await appVersionInfo()
        let resolvedCLIInfo = await cliInfo
        let resolvedMacUpdateInfo = await macUpdateInfo

        return CodexInstallationSnapshot(
            appVersion: appInfo.version,
            appBuild: appInfo.build,
            appPath: appInfo.path,
            appLatestVersion: resolvedMacUpdateInfo?.version,
            appLatestBuild: resolvedMacUpdateInfo?.build,
            appUpdatePublishedAt: resolvedMacUpdateInfo?.publishedAt,
            appUpdateDownloadURL: resolvedMacUpdateInfo?.downloadURL,
            appUpdateFeedURL: resolvedMacUpdateInfo?.appcastURL,
            appUpdateCheckFailed: resolvedMacUpdateInfo == nil,
            cliVersion: resolvedCLIInfo.version,
            cliPath: resolvedCLIInfo.path,
            cliResolvedPath: resolvedCLIInfo.resolvedPath,
            cliInstallMethod: resolvedCLIInfo.installMethod,
            cliUpdateCommand: resolvedCLIInfo.updateCommand,
            checkedAt: Date()
        )
    }

    @MainActor
    private func appVersionInfo() -> (version: String?, build: String?, path: String?) {
        let runningCodex = NSWorkspace.shared.runningApplications.first { app in
            let name = app.localizedName?.lowercased() ?? ""
            let bundleIdentifier = app.bundleIdentifier?.lowercased() ?? ""
            return (name == "codex" || name == "openai codex" || (bundleIdentifier.contains("openai") && bundleIdentifier.contains("codex"))) &&
                bundleIdentifier != AppConstants.bundleIdentifier
        }

        let bundleURL = runningCodex?.bundleURL ?? appURLFromWorkspace()
        guard let bundleURL else {
            return (nil, nil, nil)
        }

        let bundle = Bundle(url: bundleURL)
        let version = bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = bundle?.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return (version, build, bundleURL.path)
    }

    @MainActor
    private func appURLFromWorkspace() -> URL? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex") {
            return url
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "ai.openai.codex") {
            return url
        }

        let commonPaths = [
            "/Applications/Codex.app",
            "\(NSHomeDirectory())/Applications/Codex.app"
        ]

        return commonPaths
            .map(URL.init(fileURLWithPath:))
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func cliVersionInfo() -> (version: String?, path: String?, resolvedPath: String?, installMethod: String?, updateCommand: String?) {
        let cliPath = runAndCapture("/usr/bin/which", arguments: ["codex"])
            .flatMap { CodexVersionParser.firstPath(from: $0) }

        let output = runAndCapture("/usr/bin/env", arguments: ["codex", "--version"])
        let version = output.flatMap(CodexVersionParser.cliVersionLine(from:))
        let resolvedPath = cliPath.flatMap(resolveSymlinkPath)
        let installInfo = cliPath.map { updateInfo(for: $0, resolvedPath: resolvedPath) }
        return (version, cliPath, resolvedPath, installInfo?.method, installInfo?.command)
    }

    private func latestMacAppUpdate() async -> CodexMacAppUpdate? {
        var request = URLRequest(url: AppConstants.codexMacAppcastURL)
        request.setValue(AppConstants.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return CodexMacAppcastParser.latestUpdate(from: data, appcastURL: AppConstants.codexMacAppcastURL)
        } catch {
            return nil
        }
    }

    private func runAndCapture(_ launchPath: String, arguments: [String], timeout: TimeInterval = 3) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.environment = [
            "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return nil
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }

        if process.isRunning {
            process.terminate()
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    private func resolveSymlinkPath(_ path: String) -> String? {
        var url = URL(fileURLWithPath: path)

        for _ in 0..<6 {
            guard let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: url.path) else {
                return url.path == path ? nil : url.path
            }

            if destination.hasPrefix("/") {
                url = URL(fileURLWithPath: destination)
            } else {
                url = url.deletingLastPathComponent().appendingPathComponent(destination).standardizedFileURL
            }
        }

        return url.path == path ? nil : url.path
    }

    private func updateInfo(for path: String, resolvedPath: String?) -> (method: String, command: String) {
        let combined = "\(path)\n\(resolvedPath ?? "")".lowercased()

        if combined.contains("/node_modules/@openai/codex") {
            return ("npm global", "npm install -g @openai/codex@latest")
        }

        if combined.contains("/homebrew/") || combined.contains("/cellar/") || combined.contains("/opt/homebrew/bin/") {
            return ("Homebrew", "brew upgrade codex")
        }

        return ("직접 설치", "npm install -g @openai/codex@latest")
    }
}

public final class CodexMacAppcastParser: NSObject, XMLParserDelegate {
    private struct ParsedItem {
        var version: String?
        var build: String?
        var publishedAt: Date?
        var downloadURL: URL?
    }

    private var items: [ParsedItem] = []
    private var currentItem: ParsedItem?
    private var currentElement = ""
    private var currentText = ""

    public static func latestUpdate(from data: Data, appcastURL: URL) -> CodexMacAppUpdate? {
        let delegate = CodexMacAppcastParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate

        guard parser.parse(), let item = delegate.items.first else {
            return nil
        }

        guard let version = item.version, let build = item.build else {
            return nil
        }

        return CodexMacAppUpdate(
            version: version,
            build: build,
            publishedAt: item.publishedAt,
            downloadURL: item.downloadURL,
            appcastURL: appcastURL
        )
    }

    public func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = qName ?? elementName
        currentText = ""

        if elementName == "item" {
            currentItem = ParsedItem()
            return
        }

        guard currentItem != nil else {
            return
        }

        if elementName == "enclosure", let urlString = attributeDict["url"] {
            currentItem?.downloadURL = URL(string: urlString)
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    public func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        defer {
            currentText = ""
        }

        guard currentItem != nil else {
            return
        }

        let element = qName ?? elementName
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch element {
        case "title":
            if currentItem?.version == nil {
                currentItem?.version = text
            }
        case "sparkle:version", "version":
            currentItem?.build = text
        case "sparkle:shortVersionString", "shortVersionString":
            currentItem?.version = text
        case "pubDate":
            currentItem?.publishedAt = Self.pubDateFormatter.date(from: text)
        case "item":
            if let item = currentItem {
                items.append(item)
            }
            currentItem = nil
        default:
            break
        }
    }

    private static let pubDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter
    }()
}

public enum CodexVersionParser {
    public static func cliVersionLine(from output: String) -> String? {
        output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { line in
                line.lowercased().hasPrefix("codex")
            }
    }

    public static func firstPath(from output: String) -> String? {
        output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { line in
                line.hasPrefix("/") && line.contains("codex")
            }
    }

    public static func semanticVersion(from text: String) -> String? {
        let pattern = #"\d+\.\d+\.\d+"#
        guard let range = text.range(of: pattern, options: .regularExpression) else {
            return nil
        }

        return String(text[range])
    }

    public static func compareSemanticVersions(_ lhs: String, _ rhs: String) -> ComparisonResult? {
        guard
            let lhsVersion = semanticVersion(from: lhs),
            let rhsVersion = semanticVersion(from: rhs)
        else {
            return nil
        }

        let lhsParts = lhsVersion.split(separator: ".").compactMap { Int(String($0)) }
        let rhsParts = rhsVersion.split(separator: ".").compactMap { Int(String($0)) }
        guard lhsParts.count == 3, rhsParts.count == 3 else {
            return nil
        }

        for index in 0..<3 {
            if lhsParts[index] < rhsParts[index] {
                return .orderedAscending
            }
            if lhsParts[index] > rhsParts[index] {
                return .orderedDescending
            }
        }

        return .orderedSame
    }
}
