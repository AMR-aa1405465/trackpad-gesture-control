import Foundation

/// Guarantees only ONE process listens to the trackpad at a time (otherwise the background
/// service and an interactive session would both fire every action).
final class InstanceLock {
    private let url: URL
    private var fd: Int32 = -1

    init(url: URL) { self.url = url }

    /// True if this process now owns the lock (held until the process exits).
    func tryAcquire() -> Bool {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        fd = open(url.path, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { return false }
        return flock(fd, LOCK_EX | LOCK_NB) == 0
    }
}
