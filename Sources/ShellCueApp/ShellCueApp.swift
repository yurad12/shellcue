import AppKit
import SwiftUI
import ShellCueCore

struct ShellCueApp: App {
    @NSApplicationDelegateAdaptor(ShellCueAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
private final class ShellCueAppDelegate: NSObject, NSApplicationDelegate {
    private let store = SessionStore()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var outsideClickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let content = SessionListView(store: store, onClose: { [weak self] in self?.closePopover() })
            .frame(width: 420, height: 520)
            .task {
                while !Task.isCancelled {
                    self.store.refresh()
                    try? await Task.sleep(for: .seconds(2))
                }
            }
        popover.contentSize = NSSize(width: 420, height: 520)
        popover.contentViewController = NSHostingController(rootView: content)
        // The system character viewer temporarily moves focus away. A transient
        // popover would close before the selected emoji reaches the text view.
        popover.behavior = .applicationDefined

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "ShellCue")
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        statusItem = item
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            let windowID = CGWindowID(event.cgEvent?.getIntegerValueField(
                .mouseEventWindowUnderMousePointer
            ) ?? 0)
            Task { @MainActor in
                guard let self, self.popover.isShown else { return }
                // The system emoji viewer belongs to a separate process.
                // Its clicks must still reach the editor behind it.
                guard !self.isCharacterViewerClick(windowID: windowID) else { return }
                self.closePopover()
            }
        }
    }

    private func isCharacterViewerClick(windowID: CGWindowID) -> Bool {
        // The compact viewer need not be the frontmost app. Check the clicked
        // window's owner as well, without reading window titles or contents.
        if windowID != 0,
           let windows = CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as? [[String: Any]],
           let pid = windows.first?[kCGWindowOwnerPID as String] as? Int32 {
            return NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == "com.apple.CharacterPaletteIM"
        }
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.CharacterPaletteIM"
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
    }

    private func closePopover() {
        popover.performClose(nil)
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            closePopover()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
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
    var editingDraft: SessionEditingDraft?
    private(set) var refreshErrorMessage: String?
    private(set) var operationErrorMessage: String?
    private(set) var deniedTerminalKinds: Set<TerminalKind> = []
    var isRefreshing = false

    var errorMessage: String? {
        operationErrorMessage ?? refreshErrorMessage
    }

    func beginEditing(_ session: TerminalSessionSnapshot) {
        guard editingDraft == nil else { return }
        editingDraft = SessionEditingDraft(session: session, annotation: annotation(for: session))
    }

    func cancelEditing() {
        editingDraft = nil
        operationErrorMessage = nil
    }

    @discardableResult
    func saveEditing() -> Bool {
        guard let draft = editingDraft,
              saveAnnotation(for: draft.session, purpose: draft.purpose, nextAction: draft.nextAction)
        else { return false }
        editingDraft = nil
        return true
    }

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
            operationErrorMessage = "저장된 이름과 메모를 불러오지 못했습니다: \(error.localizedDescription)"
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
        guard let key = session.target.annotationID else { return SessionAnnotation() }
        return annotations[key] ?? SessionAnnotation()
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
    ) -> Bool {
        guard let key = session.target.annotationID else {
            operationErrorMessage = "세션을 식별할 수 없어 저장하지 않았습니다. 새로고침 후 다시 시도하세요."
            return false
        }
        let cleanedPurpose = purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedNextAction = nextAction.trimmingCharacters(in: .whitespacesAndNewlines)
        var updated = annotations
        if cleanedPurpose.isEmpty && cleanedNextAction.isEmpty {
            updated.removeValue(forKey: key)
        } else {
            updated[key] = SessionAnnotation(
                purpose: cleanedPurpose,
                nextAction: cleanedNextAction
            )
        }

        do {
            try annotationStore.save(updated)
            annotations = updated
            operationErrorMessage = nil
            return true
        } catch {
            operationErrorMessage = "이름과 메모를 저장하지 못했습니다: \(error.localizedDescription)"
            return false
        }
    }

    func refresh() {
        isRefreshing = true
        defer { isRefreshing = false }

        var discoveredSessions: [TerminalSessionSnapshot] = []
        var errors: [String] = []
        var deniedKinds: Set<TerminalKind> = []

        for kind in TerminalKind.allCases {
            guard let adapter = adapters[kind] else { continue }
            do {
                discoveredSessions.append(contentsOf: try adapter.discoverSessions())
            } catch {
                errors.append("\(kind.displayName): \(error.localizedDescription)")
                if let adapterError = error as? TerminalAdapterError,
                   case .automationPermissionDenied = adapterError {
                    deniedKinds.insert(kind)
                }
            }
        }

        sessions = discoveredSessions
        projectsBySessionID = Dictionary(uniqueKeysWithValues: sessions.compactMap { session in
            guard let workingDirectory = session.workingDirectory else { return nil }
            return (session.id, projectDetector.detect(from: workingDirectory))
        })
        deniedTerminalKinds = deniedKinds
        refreshErrorMessage = errors.isEmpty ? nil : errors.joined(separator: "\n")
    }

    @discardableResult
    func focus(_ session: TerminalSessionSnapshot) -> Bool {
        do {
            guard let adapter = adapters[session.target.terminal] else {
                throw TerminalAdapterError.invalidTarget
            }
            try adapter.focus(session.target)
            operationErrorMessage = nil
            return true
        } catch {
            operationErrorMessage = error.localizedDescription
            return false
        }
    }

    func openAutomationSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}

@MainActor
@Observable
final class SessionEditingDraft {
    let session: TerminalSessionSnapshot
    var purpose: String
    var nextAction: String

    init(session: TerminalSessionSnapshot, annotation: SessionAnnotation) {
        self.session = session
        purpose = annotation.purpose
        nextAction = annotation.nextAction
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
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let draft = store.editingDraft {
                SessionEditorView(
                    draft: draft,
                    onCancel: { store.cancelEditing() },
                    onSave: { store.saveEditing() },
                    onFocus: { if store.focus(draft.session) { onClose() } }
                )
                if let errorMessage = store.operationErrorMessage {
                    errorBanner(errorMessage)
                }
            } else {
                sessionList
            }
        }
        .onExitCommand(perform: onClose)
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
                emptyState
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

    @ViewBuilder
    private var emptyState: some View {
        if !store.deniedTerminalKinds.isEmpty {
            ContentUnavailableView {
                Label(
                    "터미널 접근 권한이 필요해요",
                    systemImage: "lock.trianglebadge.exclamationmark"
                )
            } description: {
                Text("시스템 설정에서 ShellCue의 자동화 접근을 허용한 뒤 새로고침하세요.")
            } actions: {
                Button("자동화 설정 열기") {
                    store.openAutomationSettings()
                }
            }
        } else {
            ContentUnavailableView(
                "열린 터미널이 없어요",
                systemImage: "terminal",
                description: Text("Terminal이나 iTerm2에서 세션을 열고 새로고침하세요.")
            )
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
                if store.focus(session) { onClose() }
            } label: {
                SessionRow(
                    session: session,
                    title: store.displayTitle(for: session),
                    nextAction: store.annotation(for: session).nextAction
                )
            }
            .buttonStyle(.plain)

            Button {
                store.beginEditing(session)
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
            if !store.deniedTerminalKinds.isEmpty {
                Button("설정 열기") {
                    store.openAutomationSettings()
                }
                .buttonStyle(.link)
            }
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
                        .lineLimit(2)
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
    @Bindable var draft: SessionEditingDraft
    let onCancel: () -> Void
    let onSave: () -> Void
    let onFocus: () -> Void

    private var session: TerminalSessionSnapshot { draft.session }

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
                TextField("예: 프론트 개발 서버", text: $draft.purpose)
                    .textFieldStyle(.roundedBorder)
                Text("비워두면 명령이나 세션 번호로 자동 표시합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("다음 할 일 · 메모")
                    .font(.subheadline.weight(.semibold))
                TextEditor(text: $draft.nextAction)
                    .font(.body)
                    .frame(height: 125)
                    .padding(4)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.secondary.opacity(0.3)))
                    .accessibilityLabel("다음 할 일 · 메모")
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
                Button("저장", action: onSave)
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
