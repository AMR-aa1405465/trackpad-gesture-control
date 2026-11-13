import Foundation

/// Installs/removes a macOS LaunchAgent so the listener starts automatically at login.
/// The agent runs `trackpad-gestures run` (headless; no menu) and is restarted if it crashes.
struct LaunchAgentManager {
    static let label = "com.trackpad-gestures.agent"

    enum AgentError: Error, CustomStringConvertible {
        case launchctlFailed(String)
        var description: String {
            switch self { case .launchctlFailed(let m): return "launchctl failed: \(m)" }
        }
    }

    let executablePath: String
    let directory: URL

    init(executablePath: String = LaunchAgentManager.currentExecutable(),
         directory: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")) {
        self.executablePath = executablePath
        self.directory = directory
    }

    static func currentExecutable() -> String {
        URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath().path
    }

    var plistURL: URL { directory.appendingPathComponent("\(Self.label).plist") }
    var logURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/trackpad-gestures.log")
    }

    var isInstalled: Bool { FileManager.default.fileExists(atPath: plistURL.path) }

    /// Whether launchd currently has the agent loaded (i.e. it is running now).
    var isRunning: Bool { launchctl(["print", domainTarget]).status == 0 }

    /// True when the binary lives in a debug build folder (login item should use release).
    var usesDebugBuild: Bool { executablePath.contains("/debug/") }

    func plistData() throws -> Data {
        let plist: [String: Any] = [
            "Label": Self.label,
            "ProgramArguments": [executablePath, "run"],
            "RunAtLoad": true,
            // Restart after a crash, but not after a clean exit (e.g. "already running").
            "KeepAlive": ["SuccessfulExit": false],
            "ThrottleInterval": 30,
            "ProcessType": "Interactive",
            "StandardOutPath": logURL.path,
            "StandardErrorPath": logURL.path,
        ]
        return try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    }

    /// Install and start the agent now (it will also start at every login).
    func enable() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try plistData().write(to: plistURL)
        _ = launchctl(["bootout", domainTarget])  // replace any older copy
        let result = launchctl(["bootstrap", "gui/\(getuid())", plistURL.path])
        guard result.status == 0 else { throw AgentError.launchctlFailed(result.output) }
    }

    /// Stop the agent and remove it from login items.
    func disable() throws {
        _ = launchctl(["bootout", domainTarget])
        if isInstalled { try FileManager.default.removeItem(at: plistURL) }
    }

    private var domainTarget: String { "gui/\(getuid())/\(Self.label)" }

    private func launchctl(_ args: [String]) -> (status: Int32, output: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do { try p.run() } catch { return (-1, "\(error)") }
        p.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (p.terminationStatus, out.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
