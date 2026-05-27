import Foundation

struct ReleaseCacheStore {
    private let fileURL: URL
    private let fileManager: FileManager

    init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager

        if let fileURL {
            self.fileURL = fileURL
        } else {
            let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.fileURL = supportDirectory
                .appendingPathComponent("CodexUpdateCompanion", isDirectory: true)
                .appendingPathComponent("release-cache.json")
        }
    }

    func load() -> [ReleaseItem] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(ReleaseCacheEnvelope.self, from: data).releases
        } catch {
            return []
        }
    }

    func save(_ releases: [ReleaseItem]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(ReleaseCacheEnvelope(releases: releases))
        try data.write(to: fileURL, options: [.atomic])
    }

    func clear() throws {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }
        try fileManager.removeItem(at: fileURL)
    }
}

private struct ReleaseCacheEnvelope: Codable {
    var releases: [ReleaseItem]
}
