import Foundation

// One menu bar item per user, even when two copies of the app exist (the
// /Applications install and a build under ~/dev). The kernel releases the
// flock when the process dies.
enum InstanceLock {
    private static var descriptor: Int32 = -1

    static func acquire() -> Bool {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let path = directory.appendingPathComponent("Server-Fo.lock").path
        descriptor = open(path, O_CREAT | O_RDWR, 0o644)
        // Fail open: a broken lock must not make the app unlaunchable.
        guard descriptor >= 0 else { return true }
        return flock(descriptor, LOCK_EX | LOCK_NB) == 0
    }
}
