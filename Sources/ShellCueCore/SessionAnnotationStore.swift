import Foundation

public struct SessionAnnotation: Codable, Equatable, Sendable {
    public var purpose: String
    public var nextAction: String
    public var modifiedAt: Date

    public init(
        purpose: String = "",
        nextAction: String = "",
        modifiedAt: Date = Date()
    ) {
        self.purpose = purpose
        self.nextAction = nextAction
        self.modifiedAt = modifiedAt
    }
}

public struct SessionAnnotationStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ShellCue", isDirectory: true)
            .appendingPathComponent("session-annotations.json")
    }

    public func load() throws -> [String: SessionAnnotation] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [:] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([String: SessionAnnotation].self, from: data)
    }

    public func save(_ annotations: [String: SessionAnnotation]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(annotations).write(to: fileURL, options: .atomic)
    }
}
