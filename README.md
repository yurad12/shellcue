# ShellCue

When you have many terminals open, it can be hard to remember what each one is for. ShellCue is a macOS menu bar app that brings your Terminal and iTerm2 sessions into one list. Give each session a name and a note so you can find your way back.

Sessions are grouped by working folder. Click a session to return to its tab or split pane. You can search names and notes, and use multiple lines and emoji in notes.

## Install and use

ShellCue needs macOS 14 or later. Each ZIP supports the same chip type as the Mac that built it: Apple Silicon or Intel.

1. Unzip the file and move `ShellCue.app` to Applications.
2. Open the app and click the ShellCue icon in the menu bar at the top of the screen. The app has no Dock icon or main window.
3. Open a session in Terminal or iTerm2. When ShellCue asks to control your terminal app, allow access to the app you use.
4. Click a session to go to it, or click its edit button to add a name and note. Press `⌘S` to save.

Press **Control + Option + Space** (`⌃⌥Space`) from any app to open or close ShellCue. When the session list opens, type to search, use **↑ / ↓** to select a session, and press **Enter** to switch to it. Each time you reopen the list, the search starts empty. An unfinished note opens in the editor instead.

The selected row stays on the same session during updates. If that session closes, choose another row before pressing Enter. Arrow keys and Enter keep their normal text editing behavior in notes and while composing text in the search field.

If the shortcut is unavailable, the app menu shows a message. You can still open ShellCue with the menu bar icon.

Click the menu bar icon again, press Esc, or click outside to close the panel. The emoji picker stays open for input. The panel also closes after a successful switch to a terminal.

Closing the panel keeps your draft while ShellCue is running. Reopen the panel to keep editing. Save with `⌘S`, or choose **취소** (Cancel) to discard the draft. Unsaved drafts do not survive quitting the app. The list shows up to two lines of a saved note.

To quit, open the menu on the right side of the panel and choose **ShellCue 종료** (Quit ShellCue). The app currently uses Korean labels.

If sessions are missing and you see a permission message, check **System Settings → Privacy & Security → Automation → ShellCue** and allow access to your terminal app.

The app package is a test build with a local signature. It does not have Developer ID signing or Apple notarization yet, so macOS may block copies downloaded from the internet.

## Your data

Names and notes are saved on your Mac in this file:

```text
~/Library/Application Support/ShellCue/session-annotations.json
```

You do not need an account or extra shell scripts. ShellCue does not save terminal output or command history. “Running” and “Waiting” describe the current session state, not whether a task succeeded or failed.

## Development

You need Swift 6.1 or later and a compatible version of Xcode. Run these commands from the project folder:

```sh
swift build
swift run ShellCue
```

`swift run ShellCue` creates and opens a development app, then returns control to your terminal. ShellCue keeps running in the menu bar. After changing code, quit ShellCue from its app menu and run the command again.

To build the app and ZIP:

```sh
./scripts/package-app.sh
```

The files are saved as `dist/ShellCue.app` and `dist/ShellCue-0.1.0-<architecture>.zip`.

To check the terminal connection, quit ShellCue and run `swift run ShellCue --diagnose`. The results are saved in `shellcue-diagnostics.log` in the build folder.

See [AGENTS.md](AGENTS.md) for project rules and [BACKLOG.md](docs/BACKLOG.md) for upcoming work. The backlog is written in Korean.
