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
                    while !Task.isCancelled {
                        store.refresh()
                        try? await Task.sleep(for: .seconds(2))
                    }
                }
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
@Observable
final class SessionStore {
    private let adapters: [TerminalKind: any TerminalAdapter]
    private let annotationStore: SessionAnnotationStore
    private let projectDetector: ProjectDetector

    var sessions: [TerminalSessionSnapshot] = []
    var projectsBySessionID: [String: DetectedProject] = [:]
    var annotations: [String: SessionAnnotation] = [:]
    var query = ""
    var errorMessage: String?
    var isRefreshing = false

    init(
        adapters: [any TerminalAdapter] = [AppleTerminalAdapter(), ITermAdapter()],
        annotationStore: SessionAnnotationStore = SessionAnnotationStore(),
        projectDetector: ProjectDetector = ProjectDetector()
    ) {
        self.adapters = Dictionary(uniqueKeysWithValues: adapters.map { ($0.kind, $0) })
        self.annotationStore = annotationStore
        self.projectDetector = projectDetector
        do {
            annotations = try annotationStore.load()
        } catch {
            errorMessage = "저장된 이름과 메모를 불러오지 못했습니다: \(error.localizedDescription)"
        }
    }

    var filteredSessions: [TerminalSessionSnapshot] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return sessions }
        return sessions.filter {
            let annotation = annotation(for: $0)
            return displayTitle(for: $0).localizedCaseInsensitiveContains(trimmedQuery)
                || annotation.nextAction.localizedCaseInsensitiveContains(trimmedQuery)
                || $0.title.localizedCaseInsensitiveContains(trimmedQuery)
                || ($0.workingDirectory?.localizedCaseInsensitiveContains(trimmedQuery) ?? false)
                || ($0.activeCommand?.localizedCaseInsensitiveContains(trimmedQuery) ?? false)
                || $0.target.tty.localizedCaseInsensitiveContains(trimmedQuery)
                || $0.target.terminal.displayName.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    var filteredGroups: [SessionGroup] {
        let grouped = Dictionary(grouping: filteredSessions) { session in
            projectsBySessionID[session.id]?.rootPath ?? "__unknown__"
        }
        return grouped.map { key, sessions in
            let project = sessions.compactMap { projectsBySessionID[$0.id] }.first
            return SessionGroup(
                id: key,
                name: project?.name ?? "경로 확인 필요",
                path: project?.rootPath,
                isGitRepository: project?.isGitRepository ?? false,
                sessions: sessions.sorted {
                    displayTitle(for: $0).localizedStandardCompare(displayTitle(for: $1)) == .orderedAscending
                }
            )
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func annotation(for session: TerminalSessionSnapshot) -> SessionAnnotation {
        annotations[session.id] ?? SessionAnnotation()
    }

    func displayTitle(for session: TerminalSessionSnapshot) -> String {
        let purpose = annotation(for: session).purpose
        guard purpose.isEmpty else { return purpose }
        guard let path = session.workingDirectory, !path.isEmpty else { return session.title }

        let ttyName = URL(fileURLWithPath: session.target.tty).lastPathComponent
            .replacingOccurrences(of: "ttys", with: "")
        return "세션 \(ttyName)"
    }

    func saveAnnotation(
        for session: TerminalSessionSnapshot,
        purpose: String,
        nextAction: String
    ) {
        let cleanedPurpose = purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedNextAction = nextAction.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedPurpose.isEmpty && cleanedNextAction.isEmpty {
            annotations.removeValue(forKey: session.id)
        } else {
            annotations[session.id] = SessionAnnotation(
                purpose: cleanedPurpose,
                nextAction: cleanedNextAction
            )
        }

        do {
            try annotationStore.save(annotations)
            errorMessage = nil
        } catch {
            errorMessage = "이름과 메모를 저장하지 못했습니다: \(error.localizedDescription)"
        }
    }

    func refresh() {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            sessions = try adapters.values.flatMap { try $0.discoverSessions() }
            projectsBySessionID = Dictionary(uniqueKeysWithValues: sessions.compactMap { session in
                guard let workingDirectory = session.workingDirectory else { return nil }
                return (session.id, projectDetector.detect(from: workingDirectory))
            })
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

struct SessionGroup: Identifiable {
    let id: String
    let name: String
    let path: String?
    let isGitRepository: Bool
    let sessions: [TerminalSessionSnapshot]
}

private struct SessionListView: View {
    @Bindable var store: SessionStore
    @State private var editingSession: TerminalSessionSnapshot?

    var body: some View {
        VStack(spacing: 0) {
            if let editingSession {
                SessionEditorView(
                    session: editingSession,
                    annotation: store.annotation(for: editingSession),
                    onCancel: { self.editingSession = nil },
                    onSave: { purpose, nextAction in
                        store.saveAnnotation(
                            for: editingSession,
                            purpose: purpose,
                            nextAction: nextAction
                        )
                        self.editingSession = nil
                    },
                    onFocus: { store.focus(editingSession) }
                )
            } else {
                sessionList
            }
        }
    }

    private var sessionList: some View {
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
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(store.filteredGroups) { group in
                            projectSection(group)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
            }
        }
    }

    private func projectSection(_ group: SessionGroup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: group.isGitRepository ? "shippingbox" : "folder")
                    .font(.caption)
                Text(group.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text("\(group.sessions.count)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .help(group.path ?? "작업 경로를 확인할 수 없습니다.")

            VStack(spacing: 0) {
                ForEach(group.sessions) { session in
                    sessionRow(session)
                    if session.id != group.sessions.last?.id {
                        Divider()
                            .padding(.leading, 32)
                    }
                }
            }
            .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11))
            .clipShape(RoundedRectangle(cornerRadius: 11))
        }
    }

    private func sessionRow(_ session: TerminalSessionSnapshot) -> some View {
        HStack(spacing: 2) {
            Button {
                store.focus(session)
            } label: {
                SessionRow(
                    session: session,
                    title: store.displayTitle(for: session),
                    nextAction: store.annotation(for: session).nextAction
                )
            }
            .buttonStyle(.plain)

            Button {
                editingSession = session
            } label: {
                Image(systemName: "square.and.pencil")
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 34)
            }
            .buttonStyle(.borderless)
            .help("용도와 다음 할 일 편집")
        }
        .padding(.horizontal, 8)
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
            Menu {
                Button("ShellCue 종료") {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("앱 메뉴")
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
    let title: String
    let nextAction: String

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(stateColor(session.state))
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                if !nextAction.isEmpty {
                    Text("↳ \(nextAction)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(sessionDetails)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(shortStateName)
                .font(.system(size: 11))
                .foregroundStyle(stateColor(session.state))
        }
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private var sessionDetails: String {
        [session.target.terminal.displayName, session.activeCommand, session.target.tty]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " · ")
    }

    private var shortStateName: String {
        switch session.state {
        case .waiting: "대기"
        case .running: "실행 중"
        case .unknown: "확인 필요"
        }
    }

    private func stateColor(_ state: ObservedSessionState) -> Color {
        switch state {
        case .running:
            .green
        case .waiting:
            .secondary
        case .unknown:
            .orange
        }
    }
}

private struct SessionEditorView: View {
    let session: TerminalSessionSnapshot
    let onCancel: () -> Void
    let onSave: (String, String) -> Void
    let onFocus: () -> Void

    @State private var purpose: String
    @State private var nextAction: String

    init(
        session: TerminalSessionSnapshot,
        annotation: SessionAnnotation,
        onCancel: @escaping () -> Void,
        onSave: @escaping (String, String) -> Void,
        onFocus: @escaping () -> Void
    ) {
        self.session = session
        self.onCancel = onCancel
        self.onSave = onSave
        self.onFocus = onFocus
        _purpose = State(initialValue: annotation.purpose)
        _nextAction = State(initialValue: annotation.nextAction)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Button(action: onCancel) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                Text("세션 메모")
                    .font(.headline)
                Spacer()
                Text(session.state.displayName)
                    .font(.caption)
                    .foregroundStyle(stateColor)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("용도 이름")
                    .font(.subheadline.weight(.semibold))
                TextField("예: 프론트 개발 서버", text: $purpose)
                    .textFieldStyle(.roundedBorder)
                Text("비워두면 명령이나 세션 번호로 자동 표시합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("다음 할 일 · 메모")
                    .font(.subheadline.weight(.semibold))
                TextField(
                    "예: 모바일 화면 확인 후 커밋하고 리뷰 요청",
                    text: $nextAction,
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
                .lineLimit(4...7)
                Text("여러 줄로 적을 수 있으며 목록에는 두 줄까지 표시됩니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                if let workingDirectory = session.workingDirectory {
                    Label(workingDirectory, systemImage: "folder")
                        .lineLimit(2)
                }
                if let activeCommand = session.activeCommand {
                    Label(activeCommand, systemImage: "terminal")
                        .lineLimit(1)
                }
                Text("터미널 제목: \(session.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("\(session.target.terminal.displayName) · \(session.target.tty)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack {
                Button("터미널로 이동", action: onFocus)
                Spacer()
                Button("취소", action: onCancel)
                Button("저장") {
                    onSave(purpose, nextAction)
                }
                .keyboardShortcut("s", modifiers: .command)
            }
        }
        .padding(16)
    }

    private var stateColor: Color {
        switch session.state {
        case .running:
            .green
        case .waiting, .unknown:
            .secondary
        }
    }
}
