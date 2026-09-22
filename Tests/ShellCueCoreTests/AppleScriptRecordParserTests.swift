import Testing
@testable import ShellCueCore

@Suite("AppleScript record parser")
struct AppleScriptRecordParserTests {
    @Test("여러 레코드와 빈 필드를 보존한다")
    func parsesRecords() throws {
        let field = AppleScriptRecordParser.fieldSeparator
        let record = AppleScriptRecordParser.recordSeparator
        let output = "1\(field)tty1\(field)title\(record)2\(field)tty2\(field)\(record)"

        let parsed = try AppleScriptRecordParser.parse(output, fields: 3)

        #expect(parsed == [
            ["1", "tty1", "title"],
            ["2", "tty2", ""]
        ])
    }

    @Test("필드 수가 다르면 실패한다")
    func rejectsMalformedRecord() {
        #expect(throws: TerminalAdapterError.self) {
            try AppleScriptRecordParser.parse("only-one-field", fields: 2)
        }
    }
}

