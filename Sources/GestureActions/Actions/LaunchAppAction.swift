import AppKit
import GestureCore

/// Launches (or focuses) an application by name, e.g. "Safari".
public struct LaunchAppAction: Action {
    public let appName: String
    public var summary: String { "Launch app \(appName)" }

    public init(appName: String) { self.appName = appName }

    public func perform() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", appName]
        try process.run()
    }
}
