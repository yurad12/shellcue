import Foundation

public enum TerminalAdapterError: LocalizedError {
    case scriptCreationFailed
    case scriptFailed(String)
    case malformedOutput(String)
    case invalidTarget

    public var errorDescription: String? {
        switch self {
        case .scriptCreationFailed:
            "AppleScript를 만들 수 없습니다."
        case .scriptFailed(let message):
            "터미널 연결에 실패했습니다: \(message)"
        case .malformedOutput(let output):
            "터미널이 예상하지 못한 데이터를 반환했습니다: \(output)"
        case .invalidTarget:
            "이 터미널 세션의 위치 정보가 올바르지 않습니다."
        }
    }
}

@MainActor
public struct AppleScriptRunner {
    public init() {}

    public func run(_ source: String) throws -> String {
        guard let script = NSAppleScript(source: source) else {
            throw TerminalAdapterError.scriptCreationFailed
        }

        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            let message = (error[NSAppleScript.errorMessage] as? String)
                ?? error.description
            throw TerminalAdapterError.scriptFailed(message)
        }
        return result.stringValue ?? ""
    }
}

public enum AppleScriptRecordParser {
    public static let fieldSeparator = "\u{001F}"
    public static let recordSeparator = "\u{001E}"

    public static func parse(_ output: String, fields expectedFieldCount: Int) throws -> [[String]] {
        let records = output.split(separator: Character(recordSeparator), omittingEmptySubsequences: true)
        return try records.map { record in
            let fields = record
                .split(separator: Character(fieldSeparator), omittingEmptySubsequences: false)
                .map(String.init)
            guard fields.count == expectedFieldCount else {
                throw TerminalAdapterError.malformedOutput(String(record))
            }
            return fields
        }
    }
}

func appleScriptLiteral(_ value: String) -> String {
    value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\r", with: " ")
        .replacingOccurrences(of: "\n", with: " ")
}

