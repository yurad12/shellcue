import Foundation
import XCTest
@testable import ShellCueCore

final class ProjectDetectorTests: XCTestCase {
    func testFindsGitRootFromNestedDirectory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let nested = root.appendingPathComponent("Sources/Feature", isDirectory: true)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(".git", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let project = ProjectDetector().detect(from: nested.path)

        XCTAssertEqual(project.rootPath, root.path)
        XCTAssertEqual(project.name, root.lastPathComponent)
        XCTAssertTrue(project.isGitRepository)
    }

    func testUsesWorkingDirectoryOutsideGitRepository() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let project = ProjectDetector().detect(from: directory.path)

        XCTAssertEqual(project.rootPath, directory.path)
        XCTAssertFalse(project.isGitRepository)
    }

    func testRecognizesGitWorktreeMarkerFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("gitdir: /tmp/example".utf8)
            .write(to: directory.appendingPathComponent(".git"))
        defer { try? FileManager.default.removeItem(at: directory) }

        XCTAssertTrue(ProjectDetector().detect(from: directory.path).isGitRepository)
    }
}
