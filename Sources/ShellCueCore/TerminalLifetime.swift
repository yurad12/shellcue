import Foundation

/// A TTY can be reused. Pair it with the root process and its start time.
enum TerminalLifetime {
    static func identities(psOutput: String) -> [String: String] {
        struct Row {
            let pid: Int
            let parent: Int
            let tty: String
            let started: String
        }
        let rows = psOutput.split(whereSeparator: \.isNewline).compactMap { line -> Row? in
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard fields.count == 8, let pid = Int(fields[0]),
                  let parent = Int(fields[1]), fields[2] != "??" else { return nil }
            return Row(pid: pid, parent: parent, tty: String(fields[2]),
                       started: fields[3...7].joined(separator: " "))
        }
        return Dictionary(grouping: rows, by: \.tty).reduce(into: [:]) { result, group in
            let pids = Set(group.value.map(\.pid))
            let roots = group.value.filter { !pids.contains($0.parent) }
            guard roots.count == 1, let root = roots.first else { return }
            result["/dev/\(group.key)"] = "\(root.pid):\(root.started)"
        }
    }

    static func read() -> [String: String] {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,ppid=,tty=,lstart="]
        var environment = ProcessInfo.processInfo.environment
        environment["LC_ALL"] = "C"
        process.environment = environment
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  let text = String(data: data, encoding: .utf8) else { return [:] }
            return identities(psOutput: text)
        } catch {
            return [:]
        }
    }
}
