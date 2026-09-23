import Foundation

struct TTYProcessContext: Equatable {
    let state: ObservedSessionState
    let processID: Int
    let activeCommand: String?
    let workingDirectory: String?
}

struct TTYProcessInspector {
    func contexts(for ttys: [String]) -> [String: TTYProcessContext] {
        guard !ttys.isEmpty else { return [:] }

        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,ppid=,pgid=,tpgid=,tty=,comm="]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  let text = String(data: data, encoding: .utf8) else {
                return [:]
            }
            let contexts = TTYProcessStateResolver.resolveContexts(psOutput: text, ttys: ttys)
            let workingDirectories = workingDirectories(
                for: Set(contexts.values.map(\.processID))
            )
            return contexts.mapValues { context in
                TTYProcessContext(
                    state: context.state,
                    processID: context.processID,
                    activeCommand: context.activeCommand,
                    workingDirectory: workingDirectories[context.processID]
                )
            }
        } catch {
            return [:]
        }
    }

    private func workingDirectories(for processIDs: Set<Int>) -> [Int: String] {
        guard !processIDs.isEmpty else { return [:] }

        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = [
            "-a", "-p", processIDs.sorted().map(String.init).joined(separator: ","),
            "-d", "cwd", "-Fpn"
        ]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard let text = String(data: data, encoding: .utf8) else { return [:] }
            return CWDOutputParser.parse(text)
        } catch {
            return [:]
        }
    }
}

enum TTYProcessStateResolver {
    private struct Row {
        let processID: Int
        let parentProcessID: Int
        let processGroupID: Int
        let foregroundProcessGroupID: Int
        let tty: String
        let command: String
    }

    static func resolve(psOutput: String, ttys: [String]) -> [String: ObservedSessionState] {
        let contexts = resolveContexts(psOutput: psOutput, ttys: ttys)
        return Dictionary(uniqueKeysWithValues: ttys.map { tty in
            (tty, contexts[tty]?.state ?? .unknown)
        })
    }

    static func resolveContexts(psOutput: String, ttys: [String]) -> [String: TTYProcessContext] {
        let rows = psOutput.split(whereSeparator: \.isNewline).compactMap(parse)
        return Dictionary(uniqueKeysWithValues: ttys.compactMap { tty in
            let normalizedTTY = normalizeTTY(tty)
            let outerForegroundRows = rows.filter {
                $0.tty == normalizedTTY
                    && $0.foregroundProcessGroupID > 0
                    && $0.processGroupID == $0.foregroundProcessGroupID
            }

            guard !outerForegroundRows.isEmpty else { return nil }

            var relatedProcessIDs = Set(outerForegroundRows.map(\.processID))
            var foundDescendant = true
            while foundDescendant {
                foundDescendant = false
                for row in rows where relatedProcessIDs.contains(row.parentProcessID) {
                    if relatedProcessIDs.insert(row.processID).inserted {
                        foundDescendant = true
                    }
                }
            }

            let foregroundRows = rows.filter {
                relatedProcessIDs.contains($0.processID)
                    && $0.foregroundProcessGroupID > 0
                    && $0.processGroupID == $0.foregroundProcessGroupID
            }
            let state: ObservedSessionState = foregroundRows.allSatisfy {
                isInteractiveShell($0.command)
            } ? .waiting : .running
            guard let representative = foregroundRows.max(by: {
                processDepth($0, rows: rows, relatedProcessIDs: relatedProcessIDs)
                    < processDepth($1, rows: rows, relatedProcessIDs: relatedProcessIDs)
            }) else {
                return nil
            }
            let activeCommand = state == .running ? commandName(representative.command) : nil
            return (
                tty,
                TTYProcessContext(
                    state: state,
                    processID: representative.processID,
                    activeCommand: activeCommand,
                    workingDirectory: nil
                )
            )
        })
    }

    private static func processDepth(
        _ row: Row,
        rows: [Row],
        relatedProcessIDs: Set<Int>
    ) -> Int {
        let rowsByID = Dictionary(uniqueKeysWithValues: rows.map { ($0.processID, $0) })
        var depth = 0
        var parentID = row.parentProcessID
        var visited: Set<Int> = []
        while relatedProcessIDs.contains(parentID),
              let parent = rowsByID[parentID],
              visited.insert(parentID).inserted {
            depth += 1
            parentID = parent.parentProcessID
        }
        return depth
    }

    private static func parse(_ line: Substring) -> Row? {
        let fields = line.split(maxSplits: 5, whereSeparator: \.isWhitespace)
        guard fields.count == 6,
              let processID = Int(fields[0]),
              let parentProcessID = Int(fields[1]),
              let processGroupID = Int(fields[2]),
              let foregroundProcessGroupID = Int(fields[3]) else {
            return nil
        }
        return Row(
            processID: processID,
            parentProcessID: parentProcessID,
            processGroupID: processGroupID,
            foregroundProcessGroupID: foregroundProcessGroupID,
            tty: String(fields[4]),
            command: String(fields[5])
        )
    }

    private static func normalizeTTY(_ tty: String) -> String {
        tty.hasPrefix("/dev/") ? String(tty.dropFirst(5)) : tty
    }

    private static func isInteractiveShell(_ command: String) -> Bool {
        let executable = commandName(command)
        return ["bash", "csh", "dash", "fish", "ksh", "login", "nu", "sh", "tcsh", "zsh"]
            .contains(executable)
    }

    private static func commandName(_ command: String) -> String {
        guard let commandPath = command.split(whereSeparator: \.isWhitespace).first else {
            return command
        }
        return URL(fileURLWithPath: String(commandPath)).lastPathComponent
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

enum CWDOutputParser {
    static func parse(_ output: String) -> [Int: String] {
        var result: [Int: String] = [:]
        var currentProcessID: Int?
        for line in output.split(whereSeparator: \.isNewline) {
            guard let marker = line.first else { continue }
            let value = line.dropFirst()
            switch marker {
            case "p":
                currentProcessID = Int(value)
            case "n":
                if let currentProcessID {
                    result[currentProcessID] = String(value)
                }
            default:
                continue
            }
        }
        return result
    }
}
