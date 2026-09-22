import SwiftUI
import ShellCueCore

@main
struct ShellCueApp: App {
    @State private var store = SessionStore()

    var body: some Scene {
        MenuBarExtra("ShellCue", systemImage: "terminal.fill") {
            SessionListView(store: store)
                .frame(width: 420, height: 520)
                .task {
                    store.refresh()
                }
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
@Observable
final class SessionStore {
    private let adapters: [TerminalKind: any TerminalAdapter]

    var sessions: [TerminalSessionSnapshot] = []
    var query = ""
    var errorMessage: String?
    var isRefreshing = false

    init(adapters: [any TerminalAdapter] = [AppleTerminalAdapter(), ITermAdapter()]) {
        self.adapters = Dictionary(uniqueKeysWithValues: adapters.map { ($0.kind, $0) })
    }

    var filteredSessions: [TerminalSessionSnapshot] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return sessions }
        return sessions.filter {
            $0.title.localizedCaseInsensitiveContains(trimmedQuery)
                || $0.target.tty.localizedCaseInsensitiveContains(trimmedQuery)
                || $0.target.terminal.displayName.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    func refresh() {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            sessions = try adapters.values
                .flatMap { try $0.discoverSessions() }
                .sorted {
                    if $0.target.terminal == $1.target.terminal {
                        return $0.title.localizedStandardCompare($1.title) == .orderedAscending
                    }
                    return $0.target.terminal.rawValue < $1.target.terminal.rawValue
                }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func focus(_ session: TerminalSessionSnapshot) {
        do {
            try adapters[session.target.terminal]?.focus(session.target)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct SessionListView: View {
    @Bindable var store: SessionStore

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
            Divider()

            if let errorMessage = store.errorMessage {
                errorBanner(errorMessage)
            }

            if store.filteredSessions.isEmpty {
                ContentUnavailableView(
                    "열린 터미널이 없어요",
                    systemImage: "terminal",
                    description: Text("Terminal이나 iTerm2에서 세션을 열고 새로고침하세요.")
                )
            } else {
                List(store.filteredSessions) { session in
                    Button {
                        store.focus(session)
                    } label: {
                        SessionRow(session: session)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("ShellCue")
                .font(.headline)
            Spacer()
            Text("\(store.sessions.count)개 세션")
                .foregroundStyle(.secondary)
            Button {
                store.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(store.isRefreshing)
            .help("새로고침")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var searchField: some View {
        TextField("세션 검색", text: $store.query)
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
            Text(message)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.callout)
        .foregroundStyle(.orange)
        .padding(12)
    }
}

private struct SessionRow: View {
    let session: TerminalSessionSnapshot

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.target.terminal == .iTerm2 ? "rectangle.split.2x1" : "terminal")
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text("\(session.target.terminal.displayName) · \(session.target.tty)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(session.state.displayName)
                .font(.caption)
                .foregroundStyle(session.state == .running ? .green : .secondary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 5)
    }
}

