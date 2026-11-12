import Foundation

@MainActor
public struct VSCodeAdapter: TerminalAdapter {
    public let kind = TerminalKind.vscode
    private let directory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/ShellCue/vscode")

    public init() {}
    private struct Window: Decodable {
        let version: Int
        let windowID: String
        let updatedAt: Double
        let terminals: [Session]
    }
    private struct Session: Decodable {
        let id: String
        let name: String
        let cwd: String?
        let state: String
    }
    private func windows() -> [Window] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }.compactMap {
            guard let data = try? Data(contentsOf: $0),
                  let window = try? JSONDecoder().decode(Window.self, from: data),
                  window.version == 1, UUID(uuidString: window.windowID) != nil,
                  Date().timeIntervalSince1970 - window.updatedAt < 4 else { return nil }
            return window
        }
    }
    public func discoverSessions() throws -> [TerminalSessionSnapshot] {
        windows().flatMap { window in
            window.terminals.map { session in
                TerminalSessionSnapshot(
                    id: "vscode:\(window.windowID):\(session.id)",
                    target: TerminalTarget(terminal: .vscode, sessionID: session.id, tty: "", lifetimeID: window.windowID),
                    title: session.name,
                    state: session.state == "running" ? .running : .unknown,
                    workingDirectory: session.cwd
                )
            }
        }
    }
    public func focus(_ target: TerminalTarget) throws {
        guard target.terminal == .vscode, let windowID = target.lifetimeID,
              let sessionID = target.sessionID,
              windows().contains(where: { $0.windowID == windowID && $0.terminals.contains(where: { $0.id == sessionID }) }) else {
            throw TerminalAdapterError.invalidTarget
        }
        let nonce = UUID().uuidString
        let request: [String: Any] = ["nonce": nonce, "terminalID": sessionID, "createdAt": Date().timeIntervalSince1970]
        let requestURL = directory.appendingPathComponent(windowID + ".request")
        try JSONSerialization.data(withJSONObject: request).write(to: requestURL, options: .atomic)
        let responseURL = directory.appendingPathComponent(windowID + ".response")
        let deadline = Date().addingTimeInterval(1.5)
        while Date() < deadline {
            if let data = try? Data(contentsOf: responseURL),
               let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               response["nonce"] as? String == nonce {
                guard response["success"] as? Bool == true else { throw TerminalAdapterError.invalidTarget }
                return
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        throw TerminalAdapterError.invalidTarget
    }
}
