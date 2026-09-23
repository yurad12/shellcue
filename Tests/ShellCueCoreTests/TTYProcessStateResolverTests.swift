import XCTest
@testable import ShellCueCore

final class TTYProcessStateResolverTests: XCTestCase {
    func testShellInForegroundIsWaiting() {
        let output = """
          101     1   101   101 ttys000 /bin/zsh
          201     1   201   101 ttys001 /bin/zsh
        """

        let states = TTYProcessStateResolver.resolve(
            psOutput: output,
            ttys: ["/dev/ttys000"]
        )

        XCTAssertEqual(states["/dev/ttys000"], .waiting)
    }

    func testForegroundCommandIsRunning() {
        let output = """
          101     1   101   301 ttys000 /bin/zsh
          301   101   301   301 ttys000 /bin/sleep
        """

        let states = TTYProcessStateResolver.resolve(
            psOutput: output,
            ttys: ["/dev/ttys000"]
        )

        XCTAssertEqual(states["/dev/ttys000"], .running)
    }

    func testMissingTTYRemainsUnknown() {
        let states = TTYProcessStateResolver.resolve(psOutput: "", ttys: ["/dev/ttys999"])

        XCTAssertEqual(states["/dev/ttys999"], .unknown)
    }

    func testNestedTerminalShellIsWaiting() {
        let output = """
          100     1   100   100 ttys000 /usr/bin/login
          101   100   100   100 ttys000 zsh (kiro-cli-term)
          102   101   102   102 ttys001 /bin/zsh
        """

        let states = TTYProcessStateResolver.resolve(
            psOutput: output,
            ttys: ["/dev/ttys000"]
        )

        XCTAssertEqual(states["/dev/ttys000"], .waiting)
    }

    func testCommandInNestedTerminalIsRunning() {
        let output = """
          100     1   100   100 ttys000 /usr/bin/login
          101   100   100   100 ttys000 zsh (kiro-cli-term)
          102   101   102   103 ttys001 /bin/zsh
          103   102   103   103 ttys001 /bin/sleep
        """

        let states = TTYProcessStateResolver.resolve(
            psOutput: output,
            ttys: ["/dev/ttys000"]
        )

        XCTAssertEqual(states["/dev/ttys000"], .running)

        let context = TTYProcessStateResolver.resolveContexts(
            psOutput: output,
            ttys: ["/dev/ttys000"]
        )["/dev/ttys000"]
        XCTAssertEqual(context?.processID, 103)
        XCTAssertEqual(context?.activeCommand, "sleep")
    }

    func testParsesWorkingDirectoriesFromLsofOutput() {
        let output = """
        p101
        fcwd
        n/Users/me/Projects/helpdesk
        p202
        fcwd
        n/Users/me/Projects/storefront
        """

        XCTAssertEqual(CWDOutputParser.parse(output), [
            101: "/Users/me/Projects/helpdesk",
            202: "/Users/me/Projects/storefront"
        ])
    }
}
