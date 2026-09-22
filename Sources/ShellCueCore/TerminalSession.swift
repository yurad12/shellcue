import Foundation

public enum TerminalKind: String, Codable, CaseIterable, Sendable {
    case appleTerminal
    case iTerm2

    public var displayName: String {
        switch self {
        case .appleTerminal: "Terminal"
        case .iTerm2: "iTerm2"
        }
    }
}

public enum ObservedSessionState: String, Codable, Sendable {
    case waiting
    case running
    case unknown

    public var displayName: String {
        switch self {
        case .waiting: "입력 대기"
        case .running: "실행 중"
        case .unknown: "상태 연결 필요"
        }
    }
}

public struct TerminalTarget: Hashable, Codable, Sendable {
    public let terminal: TerminalKind
    public let windowID: Int?
    public let tabIndex: Int?
    public let sessionID: String?
    public let tty: String

    public init(
        terminal: TerminalKind,
        windowID: Int? = nil,
        tabIndex: Int? = nil,
        sessionID: String? = nil,
        tty: String
    ) {
        self.terminal = terminal
        self.windowID = windowID
        self.tabIndex = tabIndex
        self.sessionID = sessionID
        self.tty = tty
    }
}

public struct TerminalSessionSnapshot: Identifiable, Hashable, Sendable {
    public let id: String
    public let target: TerminalTarget
    public let title: String
    public let state: ObservedSessionState

    public init(
        id: String,
        target: TerminalTarget,
        title: String,
        state: ObservedSessionState
    ) {
        self.id = id
        self.target = target
        self.title = title
        self.state = state
    }
}

@MainActor
public protocol TerminalAdapter {
    var kind: TerminalKind { get }
    func discoverSessions() throws -> [TerminalSessionSnapshot]
    func focus(_ target: TerminalTarget) throws
}

