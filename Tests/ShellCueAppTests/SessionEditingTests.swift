import Foundation
import XCTest
import ShellCueCore
@testable import ShellCueApp

@MainActor
final class SessionEditingTests: XCTestCase {
    private let session = TerminalSessionSnapshot(
        id: "iterm:test", target: TerminalTarget(terminal: .iTerm2, sessionID: "test", tty: "/dev/ttys001"),
        title: "test", state: .waiting
    )

    private func temporaryFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testRefreshAndReopeningEditorKeepDraftWithoutSavingIt() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let storage = SessionAnnotationStore(fileURL: folder.appendingPathComponent("notes.json"))
        let store = SessionStore(adapters: [], annotationStore: storage)
        store.beginEditing(session)
        let draft = try XCTUnwrap(store.editingDraft)
        draft.purpose = "서버 🐳"
        draft.nextAction = "첫 줄\n\n다음 줄 👩🏽‍💻"

        store.refresh()
        store.beginEditing(session)

        XCTAssertTrue(store.editingDraft === draft)
        XCTAssertEqual(store.editingDraft?.nextAction, "첫 줄\n\n다음 줄 👩🏽‍💻")
        XCTAssertTrue(try storage.load().isEmpty)
    }

    func testSaveEndsEditingAndReloadsMultilineEmojiNote() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let storage = SessionAnnotationStore(fileURL: folder.appendingPathComponent("notes.json"))
        let store = SessionStore(adapters: [], annotationStore: storage)
        store.beginEditing(session)
        store.editingDraft?.purpose = "서버 🐳"
        store.editingDraft?.nextAction = "첫 줄\n\n다음 줄 ✅"

        XCTAssertTrue(store.saveEditing())
        XCTAssertNil(store.editingDraft)
        let reloaded = SessionStore(adapters: [], annotationStore: storage)
        reloaded.beginEditing(session)
        XCTAssertEqual(reloaded.editingDraft?.purpose, "서버 🐳")
        XCTAssertEqual(reloaded.editingDraft?.nextAction, "첫 줄\n\n다음 줄 ✅")
    }

    func testSaveFailureKeepsDraftAndShowsError() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("notes.json")
        let store = SessionStore(adapters: [], annotationStore: SessionAnnotationStore(fileURL: file))
        store.beginEditing(session)
        store.editingDraft?.nextAction = "이 입력은 남아야 한다 ✅"
        // A directory at the file path forces an actual disk write failure.
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)

        XCTAssertFalse(store.saveEditing())
        XCTAssertEqual(store.editingDraft?.nextAction, "이 입력은 남아야 한다 ✅")
        XCTAssertNotNil(store.operationErrorMessage)
        XCTAssertTrue(store.annotations.isEmpty)
    }

    func testCancelDiscardsDraftButKeepsSavedNote() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = SessionStore(adapters: [], annotationStore: SessionAnnotationStore(
            fileURL: folder.appendingPathComponent("notes.json")
        ))
        XCTAssertTrue(store.saveAnnotation(for: session, purpose: "원래 이름", nextAction: "저장한 메모"))
        store.beginEditing(session)
        store.editingDraft?.nextAction = "취소할 내용"
        store.cancelEditing()
        store.beginEditing(session)
        XCTAssertEqual(store.editingDraft?.nextAction, "저장한 메모")
    }

    func testMissingAdapterDoesNotReportSuccessfulFocusOrDiscardDraft() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = SessionStore(adapters: [], annotationStore: SessionAnnotationStore(
            fileURL: folder.appendingPathComponent("notes.json")
        ))
        store.beginEditing(session)
        store.editingDraft?.nextAction = "작성 중"
        XCTAssertFalse(store.focus(session))
        XCTAssertNotNil(store.operationErrorMessage)
        XCTAssertEqual(store.editingDraft?.nextAction, "작성 중")
    }
}
