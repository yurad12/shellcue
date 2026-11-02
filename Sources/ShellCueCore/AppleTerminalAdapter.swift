import Foundation

@MainActor
public struct AppleTerminalAdapter: TerminalAdapter {
    public let kind = TerminalKind.appleTerminal
    private let runner: AppleScriptRunner

    public init(runner: AppleScriptRunner = AppleScriptRunner()) {
        self.runner = runner
    }

    public func discoverSessions() throws -> [TerminalSessionSnapshot] {
        let output = try runner.run(Self.discoveryScript)
        let records = try AppleScriptRecordParser.parse(output, fields: 5)
        let processContexts = TTYProcessInspector().contexts(for: records.map { $0[2] })
        let lifetimes = TerminalLifetime.read()

        return try records.map { fields in
            guard let windowID = Int(fields[0]), let tabIndex = Int(fields[1]) else {
                throw TerminalAdapterError.malformedOutput(fields.joined(separator: "|"))
            }

            let tty = fields[2]
            let processContext = processContexts[tty]
            let title = fields[3].isEmpty ? "새 터미널" : fields[3]
            let state: ObservedSessionState = fields[4] == "true" ? .running : .waiting
            let target = TerminalTarget(
                terminal: .appleTerminal,
                windowID: windowID,
                tabIndex: tabIndex,
                tty: tty,
                lifetimeID: lifetimes[tty]
            )
            return TerminalSessionSnapshot(
                id: target.annotationID ?? "terminal:unverified:\(tty)",
                target: target,
                title: title,
                state: state,
                workingDirectory: processContext?.workingDirectory,
                activeCommand: processContext?.activeCommand
            )
        }
    }

    public func focus(_ target: TerminalTarget) throws {
        guard target.terminal == kind,
              let lifetimeID = target.lifetimeID,
              TerminalLifetime.read()[target.tty] == lifetimeID else {
            throw TerminalAdapterError.invalidTarget
        }

        let result = try runner.run("""
        if application "Terminal" is not running then return "missing"
        tell application "Terminal"
            repeat with targetWindow in windows
                repeat with targetTab in tabs of targetWindow
                    if tty of targetTab is "\(appleScriptLiteral(target.tty))" then
                        set selected tab of targetWindow to targetTab
                        set frontmost of targetWindow to true
                        activate
                        return "focused"
                    end if
                end repeat
            end repeat
        end tell
        return "missing"
        """)
        guard result == "focused" else { throw TerminalAdapterError.invalidTarget }
    }

    private static let discoveryScript = """
    set fieldSeparator to ASCII character 31
    set recordSeparator to ASCII character 30
    set resultText to ""
    set terminalRunning to application "Terminal" is running
    if terminalRunning then
        tell application "Terminal"
            repeat with terminalWindow in windows
                set windowID to id of terminalWindow
                set tabCount to count tabs of terminalWindow
                repeat with tabIndex from 1 to tabCount
                    set terminalTab to tab tabIndex of terminalWindow
                    set tabTTY to tty of terminalTab
                    set tabTitle to custom title of terminalTab
                    set tabBusy to busy of terminalTab
                    set resultText to resultText & windowID & fieldSeparator & tabIndex & fieldSeparator & tabTTY & fieldSeparator & tabTitle & fieldSeparator & tabBusy & recordSeparator
                end repeat
            end repeat
        end tell
    end if
    return resultText
    """
}
