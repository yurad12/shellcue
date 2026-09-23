import XCTest
@testable import ShellCueCore

final class AppleScriptRecordParserTests: XCTestCase {
    func testParsesRecordsAndPreservesEmptyFields() throws {
        let field = AppleScriptRecordParser.fieldSeparator
        let record = AppleScriptRecordParser.recordSeparator
        let output = "1\(field)tty1\(field)title\(record)2\(field)tty2\(field)\(record)"

        let parsed = try AppleScriptRecordParser.parse(output, fields: 3)

        XCTAssertEqual(parsed, [
            ["1", "tty1", "title"],
            ["2", "tty2", ""]
        ])
    }

    func testRejectsMalformedRecord() {
        XCTAssertThrowsError(
            try AppleScriptRecordParser.parse("only-one-field", fields: 2)
        ) { error in
            XCTAssertTrue(error is TerminalAdapterError)
        }
    }
}
