import Foundation

public struct DetectedProject: Hashable, Sendable {
    public let name: String
    public let rootPath: String
    public let isGitRepository: Bool

    public init(name: String, rootPath: String, isGitRepository: Bool) {
        self.name = name
        self.rootPath = rootPath
        self.isGitRepository = isGitRepository
    }
}

public struct ProjectDetector: Sendable {
    public init() {}

    public func detect(from workingDirectory: String) -> DetectedProject {
        let startingURL = URL(fileURLWithPath: workingDirectory, isDirectory: true)
            .standardizedFileURL
        var candidate = startingURL

        while true {
            let gitMarker = candidate.appendingPathComponent(".git")
            if FileManager.default.fileExists(atPath: gitMarker.path) {
                return DetectedProject(
                    name: displayName(for: candidate),
                    rootPath: candidate.path,
                    isGitRepository: true
                )
            }

            let parent = candidate.deletingLastPathComponent()
            guard parent.path != candidate.path else { break }
            candidate = parent
        }

        return DetectedProject(
            name: displayName(for: startingURL),
            rootPath: startingURL.path,
            isGitRepository: false
        )
    }

    private func displayName(for url: URL) -> String {
        let name = url.lastPathComponent
        return name.isEmpty ? url.path : name
    }
}
