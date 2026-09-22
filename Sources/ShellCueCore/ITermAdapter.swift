import Foundation

@MainActor
public struct ITermAdapter: TerminalAdapter {
    public let kind = TerminalKind.iTerm2
    private let runner: AppleScriptRunner

    public init(runner: AppleScriptRunner = AppleScriptRunner()) {
        self.runner = runner
    }

    public func discoverSessions() throws -> [TerminalSessionSnapshot] {
        let output = try runner.run(Self.discoveryScript)
        return try AppleScriptRecordParser.parse(output, fields: 6).map { fields in
            guard let windowID = Int(fields[0]) else {
                throw TerminalAdapterError.malformedOutput(fields.joined(separator: "|"))
            }

            let sessionID = fields[1]
            let tty = fields[2]
            let title = fields[3].isEmpty ? "새 iTerm 세션" : fields[3]
            let isProcessing = fields[4] == "true"
            let isAtPrompt = fields[5] == "true"
            let state: ObservedSessionState = isAtPrompt ? .waiting : (isProcessing ? .running : .unknown)
            let target = TerminalTarget(
                terminal: .iTerm2,
                windowID: windowID,
                sessionID: sessionID,
                tty: tty
            )
            return TerminalSessionSnapshot(
                id: "iterm:\(sessionID)",
                target: target,
                title: title,
                state: state
            )
        }
    }

    public func focus(_ target: TerminalTarget) throws {
        guard target.terminal == kind, let sessionID = target.sessionID else {
            throw TerminalAdapterError.invalidTarget
        }
        let escapedSessionID = appleScriptLiteral(sessionID)

        _ = try runner.run("""
        tell application "iTerm2"
            activate
            repeat with terminalWindow in windows
                repeat with terminalTab in tabs of terminalWindow
                    repeat with terminalSession in sessions of terminalTab
                        if id of terminalSession is "\(escapedSessionID)" then
                            select terminalSession
                            select terminalTab
                            select terminalWindow
                            return
                        end if
                    end repeat
                end repeat
            end repeat
        end tell
        """)
    }

    private static let discoveryScript = """
    set fieldSeparator to ASCII character 31
    set recordSeparator to ASCII character 30
    set resultText to ""
    set iTermRunning to application "iTerm2" is running
    if iTermRunning then
        tell application "iTerm2"
            repeat with terminalWindow in windows
                set windowID to id of terminalWindow
                repeat with terminalTab in tabs of terminalWindow
                    repeat with terminalSession in sessions of terminalTab
                        set sessionID to id of terminalSession
                        set sessionTTY to tty of terminalSession
                        set sessionName to name of terminalSession
                        set sessionProcessing to is processing of terminalSession
                        set sessionAtPrompt to is at shell prompt of terminalSession
                        set resultText to resultText & windowID & fieldSeparator & sessionID & fieldSeparator & sessionTTY & fieldSeparator & sessionName & fieldSeparator & sessionProcessing & fieldSeparator & sessionAtPrompt & recordSeparator
                    end repeat
                end repeat
            end repeat
        end tell
    end if
    return resultText
    """
}
