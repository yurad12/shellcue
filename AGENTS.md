# Working on ShellCue

ShellCue is a menu bar app that helps people find open Terminal and iTerm2 sessions and return to their work. When adding a feature, check whether it makes this easier.

## Keep these rules

- Never replace a user's name or note with an automatic guess.
- If you cannot confirm a session's state or identity, do not guess its state or switch to an unverified session.
- Do not save terminal output or sensitive command arguments. Keep data on the user's Mac.
- A failure in one terminal app must not hide sessions from the other app.
- Do not require extra shell scripts. Collecting command success and failure history is outside the current scope.
- Keep session discovery and switching in separate adapters for each terminal app. Building a terminal, running or stopping commands, and controlling sessions inside SSH or tmux are outside the current scope.

## When making changes

- Read `README.md` for usage and development commands, and `docs/BACKLOG.md` for remaining work.
- Work on one problem at a time. When behavior changes, update the related instructions too.
- Add tests where needed for logic changes. Run `swift test` before finishing.
- Check terminal connections and UI changes in the actual app. Report test results and real app checks separately.
- Keep the README focused on the product and how to use it. Keep remaining work in BACKLOG, in Korean. Use Git for completed work and change history.
