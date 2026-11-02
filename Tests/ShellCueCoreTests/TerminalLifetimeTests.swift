import XCTest
@testable import ShellCueCore

final class TerminalLifetimeTests: XCTestCase {
    func testForegroundCommandDoesNotChangeIdentity() {
        let shell = "100 1 ttys001 Thu Sep 24 10:00:00 2026"
        let running = shell + "\n200 100 ttys001 Thu Sep 24 10:05:00 2026"
        XCTAssertEqual(TerminalLifetime.identities(psOutput: shell),
                       TerminalLifetime.identities(psOutput: running))
        XCTAssertNotNil(TerminalLifetime.identities(psOutput: shell)["/dev/ttys001"])
    }

    func testReusedTTYAndPIDHaveDifferentIdentity() {
        let old = TerminalLifetime.identities(psOutput: "100 1 ttys001 Thu Sep 24 10:00:00 2026")
        let new = TerminalLifetime.identities(psOutput: "100 1 ttys001 Thu Sep 24 11:00:00 2026")
        XCTAssertNotEqual(old["/dev/ttys001"], new["/dev/ttys001"])
    }

    func testAmbiguousOrMissingProcessDoesNotProduceIdentity() {
        XCTAssertTrue(TerminalLifetime.identities(psOutput: "malformed\n100 1 ?? Thu Sep 24 10:00:00 2026").isEmpty)
        XCTAssertTrue(TerminalLifetime.identities(psOutput: """
        100 1 ttys001 Thu Sep 24 10:00:00 2026
        200 1 ttys001 Thu Sep 24 10:05:00 2026
        """).isEmpty)
    }

    func testMovingTabsPreservesAnnotationKey() {
        let original = TerminalTarget(terminal: .appleTerminal, windowID: 1,
                                      tabIndex: 1, tty: "/dev/ttys001", lifetimeID: "100:start")
        let moved = TerminalTarget(terminal: .appleTerminal, windowID: 2,
                                   tabIndex: 3, tty: "/dev/ttys001", lifetimeID: "100:start")
        XCTAssertEqual(original.annotationID, moved.annotationID)
        XCTAssertNotNil(original.annotationID)
    }

    func testUnverifiedTerminalCannotReuseLegacyAnnotationKey() {
        let target = TerminalTarget(terminal: .appleTerminal, windowID: 1,
                                    tabIndex: 1, tty: "/dev/ttys001")
        XCTAssertNil(target.annotationID)
    }

    func testITermKeepsExistingAnnotationKeys() {
        let target = TerminalTarget(terminal: .iTerm2, windowID: 99,
                                    sessionID: "session-1", tty: "/dev/ttys001")
        XCTAssertEqual(target.annotationID, "iterm:session-1")
    }

    func testPersistedMemoReconnectsAfterMoveButNotTTYReuse() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = SessionAnnotationStore(fileURL: folder.appendingPathComponent("annotations.json"))
        let original = TerminalTarget(terminal: .appleTerminal, windowID: 1, tabIndex: 1,
                                      tty: "/dev/ttys001", lifetimeID: "100:old")
        let moved = TerminalTarget(terminal: .appleTerminal, windowID: 2, tabIndex: 2,
                                   tty: "/dev/ttys001", lifetimeID: "100:old")
        let replacement = TerminalTarget(terminal: .appleTerminal, tty: "/dev/ttys001",
                                         lifetimeID: "100:new")
        let memo = SessionAnnotation(purpose: "API", nextAction: "로그 확인")
        try store.save([try XCTUnwrap(original.annotationID): memo])
        let reloaded = try SessionAnnotationStore(fileURL: store.fileURL).load()
        XCTAssertEqual(reloaded[try XCTUnwrap(moved.annotationID)], memo)
        XCTAssertNil(reloaded[try XCTUnwrap(replacement.annotationID)])
    }
}
