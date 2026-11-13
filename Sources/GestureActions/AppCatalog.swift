import Foundation

public struct InstalledApp: Equatable {
    public let name: String
    public let path: String
}

/// Finds applications installed on this Mac (scans the standard app folders).
public final class AppCatalog {
    private let searchPaths: [String]

    public init(searchPaths: [String] = AppCatalog.defaultSearchPaths) {
        self.searchPaths = searchPaths
    }

    public static var defaultSearchPaths: [String] {
        ["/Applications", "/Applications/Utilities", "/System/Applications",
         "/System/Applications/Utilities",
         FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path]
    }

    /// All installed apps, sorted by name, without duplicates.
    public func installedApps() -> [InstalledApp] {
        var seen = Set<String>()
        var apps: [InstalledApp] = []
        for dir in searchPaths {
            let items = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
            for item in items where item.hasSuffix(".app") && !item.hasPrefix(".") {
                let name = String(item.dropLast(4))
                if seen.insert(name).inserted { apps.append(InstalledApp(name: name, path: dir + "/" + item)) }
            }
        }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func search(_ query: String) -> [InstalledApp] {
        let all = installedApps()
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? all : all.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }
}
