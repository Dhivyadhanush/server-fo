import Foundation

// LaunchAgent instead of SMAppService: the app is locally built and ad-hoc
// signed, where SMAppService silently fails outside /Applications.
enum LoginItem {
    static let label = "dev.dhanuz.s-info"

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
        guard enabled,
              let path = Bundle.main.executableURL?.path,
              let plist = NSDictionary(contentsOf: url) as? [String: Any],
              let arguments = plist["ProgramArguments"] as? [String],
              arguments.first != path else { return }
        try? set(true)
    }

    static func set(_ on: Bool) throws {
        if on {
            launchctl(["bootout", "gui/\(getuid())/\(label)"])
            let plist: [String: Any] = [
                "Label": label,
                "ProgramArguments": [Bundle.main.executableURL?.path ?? CommandLine.arguments[0]],
                "RunAtLoad": true,
                "KeepAlive": false,
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
