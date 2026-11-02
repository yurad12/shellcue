import AppKit
import Foundation
import ShellCueCore

/// Launch bare SwiftPM executables through Launch Services so automation requests
/// belong to ShellCue rather than the terminal or IDE that ran `swift run`.
@main
enum ShellCueLauncher {
    @MainActor
    static func main() {
        do {
            if Bundle.main.bundleURL.pathExtension == "app" {
                if CommandLine.arguments.contains("--diagnose") {
                    diagnose()
                } else {
                    ShellCueApp.main()
                }
                return
            }
            try launchApplication()
        } catch {
            fputs("ShellCue 실행 실패: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    @MainActor
    private static func launchApplication() throws {
        guard let executable = Bundle.main.executableURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        let app = executable.deletingLastPathComponent().appendingPathComponent("ShellCue.app")
        if let running = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleURL?.standardizedFileURL == app.standardizedFileURL
        }) {
            running.activate()
            print("ShellCue가 이미 실행 중입니다. 새 빌드를 적용하려면 앱 메뉴에서 종료한 뒤 다시 실행하세요.")
            return
        }
        let contents = app.appendingPathComponent("Contents")
        let macOS = contents.appendingPathComponent("MacOS")
        let manager = FileManager.default
        try manager.createDirectory(at: macOS, withIntermediateDirectories: true)
        // Atomic replacement avoids copying over a partially written executable.
        try Data(contentsOf: executable).write(to: macOS.appendingPathComponent("ShellCue"), options: .atomic)
        try manager.setAttributes([.posixPermissions: 0o755],
                                  ofItemAtPath: macOS.appendingPathComponent("ShellCue").path)
        guard var info = Bundle.main.infoDictionary else { throw CocoaError(.fileReadCorruptFile) }
        info["CFBundlePackageType"] = "APPL"
        info["LSUIElement"] = true
        let plist = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try plist.write(to: contents.appendingPathComponent("Info.plist"), options: .atomic)
        try run("/usr/bin/codesign", ["--force", "--sign", "-", app.path])
        try run("/usr/bin/codesign", ["--verify", "--strict", app.path])
        var arguments = [app.path]
        if CommandLine.arguments.contains("--diagnose") {
            let log = executable.deletingLastPathComponent().appendingPathComponent("shellcue-diagnostics.log")
            arguments += ["--stdout", log.path, "--stderr", log.path, "--args", "--diagnose"]
            print("연결 진단 결과: \(log.path)")
        }
        try run("/usr/bin/open", arguments)
        print("ShellCue 앱을 메뉴 막대에서 실행했습니다. 종료는 앱 메뉴를 사용하세요.")
    }

    private static func run(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "ShellCue.Launch", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "\(executable)의 실행이 실패했습니다."])
        }
    }

    @MainActor
    private static func diagnose() {
        print("Bundle: \(Bundle.main.bundleIdentifier ?? "unknown")")
        for adapter in [AppleTerminalAdapter() as any TerminalAdapter, ITermAdapter()] {
            do {
                print("\(adapter.kind.displayName): \(try adapter.discoverSessions().count) sessions")
            } catch {
                print("\(adapter.kind.displayName): \(error.localizedDescription)")
            }
        }
    }
}
