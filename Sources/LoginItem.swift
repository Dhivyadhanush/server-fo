import Foundation

// LaunchAgent instead of SMAppService: the app is locally built and ad-hoc
// signed, where SMAppService silently fails outside /Applications.
enum LoginItem {
    static let label = "dev.dhanuz.server-fo"

    static var url: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var enabled: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// A rebuild or a move leaves the plist pointing at a path that no longer
    /// exists, so fix it on launch instead of silently losing the login item.
    static func repair() {
        // Never let a development build under ~/.build rewrite the login item
        // to a path that gets deleted.
        guard Bundle.main.bundlePath.hasPrefix("/Applications/") else { return }
        guard enabled,
              let path = Bundle.main.executableURL?.path,
              let plist = NSDictionary(contentsOf: url) as? [String: Any],
              let arguments = plist["ProgramArguments"] as? [String],
              arguments.first != path else { return }
        try? set(true)
    }

    /// Installed copies enable the login item on first launch. A user who
    /// turns it off in Settings keeps it off because the flag stays set.
    static func configureOnFirstLaunch() {
        let defaults = UserDefaults.standard
        let key = "serverfo.loginItemConfigured"
        guard !defaults.bool(forKey: key),
              Bundle.main.bundlePath.hasPrefix("/Applications/") else { return }

        // If a LaunchAgent already exists, do not bootout/bootstrap it: the
        // running process may itself be that job. Just remember the choice.
        if !LoginItem.enabled {
            do {
                try set(true)
            } catch {
                // Try again next launch; nothing else depends on this.
                return
            }
        }
        defaults.set(true, forKey: key)
    }

    static func set(_ on: Bool) throws {
        if on {
            launchctl(["bootout", "gui/\(getuid())/\(label)"])
            let plist: [String: Any] = [
                "Label": label,
                "ProgramArguments": [Bundle.main.executableURL?.path ?? CommandLine.arguments[0]],
                "RunAtLoad": true,
                "KeepAlive": ["SuccessfulExit": false],
                "LimitLoadToSessionType": "Aqua",
            ]
            let data = try PropertyListSerialization.data(
                fromPropertyList: plist,
                format: .xml,
                options: 0
            )
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url)
            launchctl(["bootstrap", "gui/\(getuid())", url.path])
        } else {
            launchctl(["bootout", "gui/\(getuid())/\(label)"])
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func launchctl(_ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        try? process.run()
        process.waitUntilExit()
    }
}
