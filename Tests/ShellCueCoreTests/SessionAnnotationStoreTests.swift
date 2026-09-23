import Foundation
import XCTest
@testable import ShellCueCore

final class SessionAnnotationStoreTests: XCTestCase {
    func testSavesAndLoadsAnnotations() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SessionAnnotationStore(fileURL: directory.appendingPathComponent("annotations.json"))
        let annotations = [
            "iterm:session-1": SessionAnnotation(
                purpose: "Docker 로그",
                nextAction: "오류가 다시 나면 로그 저장",
                modifiedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        ]

        try store.save(annotations)
        let loaded = try store.load()

        XCTAssertEqual(loaded, annotations)
    }

    func testMissingFileLoadsAsEmpty() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("annotations.json")

        XCTAssertEqual(try SessionAnnotationStore(fileURL: fileURL).load(), [:])
    }
}
