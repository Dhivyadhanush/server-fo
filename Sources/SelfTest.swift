import AppKit
import Foundation
import SwiftUI

// MARK: - Headless entry points

enum Headless {
    static func handleIfRequested() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard let flag = arguments.first else { return }

        switch flag {
        case "--selftest":
            SelfTest.run()
        case "--probe":
            inspect(dump: false)
        case "--dump":
            inspect(dump: true)
        case "--history":
            history()
        case "--sample":
            recordSample()
        case "--snapshot":
            let rest = Array(arguments.dropFirst())
            let tab: Store.Tab = rest.count > 1
                ? (Store.Tab(rawValue: rest[1].capitalized) ?? .containers)
                : .containers
            snapshot(rest.first, tab: tab)
        case "--snapshot-detail":
            let rest = Array(arguments.dropFirst())
            detailSnapshot(rest.first, path: rest.count > 1 ? rest[1] : nil)
        case "--snapshot-settings":
            settingsSnapshot(arguments.dropFirst().first)
        case "--snapshot-widget":
            widgetSnapshot(arguments.dropFirst().first)
        case "--prune":
            prune()
        case "--tailscale":
            tailscale(arguments.dropFirst().first)
        case "--tailscale-ip":
            tailscaleIP()
        case "--route":
            route()
        case "--toggle":
            DistributedNotificationCenter.default().post(
                name: NSNotification.Name("dev.dhanuz.server-fo.toggle"),
                object: nil
            )
            print("toggle sent")
            exit(0)
        case "--vitals":
            vitals()
        case "--clear-cache":
            clearCache()
        case "--upgrade":
            upgradeIfRequested(force: true)
        case "--upgrade-if-due":
            upgradeIfRequested(force: false)
        case "--loginitem":
            loginItem(arguments.dropFirst().first)
        case "--update":
            updateCheck()
        default:
            return
        }
    }

    private static func runAndExit(_ work: @escaping () async -> Int32) -> Never {
        Task.detached {
            let code = await work()
            exit(code)
        }
        RunLoop.main.run()
        exit(1)
    }

    private static func inspect(dump: Bool) -> Never {
        runAndExit {
            do {
                let raw = try await RemoteProbe.fetch()
                let probe = ProbeParser.parse(raw)
                print("Server-Fo · \(probe.hostname) · \(probe.os)")
                print("kernel \(probe.kernel) · docker \(probe.dockerVersion.isEmpty ? "unavailable" : probe.dockerVersion)")
                print("\(probe.running)/\(probe.containers.count) running · \(probe.aptUpgradable.count) upgradable · reboot \(probe.rebootRequired ? "required" : "not required")")
                print("")
                print("\(pad("NAME", 34)) \(pad("STATE", 10)) \(pad("CPU", 8)) \(pad("MEMORY", 10)) \(pad("RESTARTS", 8))")
                for container in probe.containers {
                    print("\(pad(container.name, 34)) \(pad(container.state, 10)) \(pad(Fmt.percent(container.cpu), 8)) \(pad(Fmt.bytes(container.memUsed), 10)) \(pad("\(container.restarts)", 8))")
                    if dump {
                        print("    image      \(container.image)")
                        print("    stack      \(container.stack)  dir \(container.workingDir)")
                        print("    ports      \(container.shortPorts.isEmpty ? "none" : container.shortPorts)")
                        print("    health     \(container.healthState.label)  uptime \(container.uptime)")
                        print("    network    rx \(Fmt.bytes(container.netRx))  tx \(Fmt.bytes(container.netTx))")
                        print("    block io   r \(Fmt.bytes(container.blkRead))  w \(Fmt.bytes(container.blkWrite))")
                        print("    command    \(container.command)")
                        print("")
                    }
                }
                return 0
            } catch {
                print("error: \(error.localizedDescription)")
                return 1
            }
        }
    }

    private static func history() -> Never {
        let store = HistoryStore()
        let stats = store.stats()
        print("history: \(store.path.path)")
        print("\(stats.samples) samples · \(stats.events) events · \(Fmt.bytes(stats.bytes))")
        print("oldest \(Fmt.dateTime(stats.oldest)) · retention \(HistoryStore.retentionDays) days")
        let runs = store.maintenance(limit: 5)
        if runs.isEmpty {
            print("no upgrade runs recorded")
        } else {
            print("")
            for run in runs {
                print("\(Fmt.dateTime(run.started)) · \(run.trigger) · exit \(run.exitCode)")
            }
        }
        let events = store.events(since: Date().addingTimeInterval(-30 * 86_400), limit: 10)
        if !events.isEmpty {
            print("")
            print("recent state changes:")
            for event in events {
                print("\(Fmt.shortDate(event.ts)) · \(event.name) · \(event.kind) · \(event.detail)")
            }
        }
        exit(0)
    }

    private static func recordSample() -> Never {
        runAndExit {
            do {
                let raw = try await RemoteProbe.fetch()
                let probe = ProbeParser.parse(raw)
                let history = HistoryStore()
                history.recordAndWait(probe)
                history.prune()
                print("recorded \(probe.containers.count) containers for \(probe.hostname)")
                print("history: \(history.stats().samples) samples")
                return 0
            } catch {
                print("error: \(error.localizedDescription)")
                return 1
            }
        }
    }

    private static func snapshot(_ path: String?, tab: Store.Tab = .containers) -> Never {
        let destination = path ?? ".build/snapshot.png"
        Task { @MainActor in
            NSApplication.shared.setActivationPolicy(.accessory)
            let store = Store()
            store.start()
            await waitForProbe(store)

            let root = ZStack {
                AppBackground()
                PanelView(store: store, initialTab: tab)
            }
            .frame(width: Theme.panelWidth, height: Theme.panelHeight)
            exit(await render(root, to: destination) ? 0 : 1)
        }
        RunLoop.main.run()
        exit(1)
    }

    private static func detailSnapshot(_ name: String?, path: String?) -> Never {
        guard let name else {
            print("usage: ServerInfo --snapshot-detail <container> [path]")
            exit(2)
        }
        let destination = path ?? ".build/detail-\(name).png"
        Task { @MainActor in
            NSApplication.shared.setActivationPolicy(.accessory)
            let store = Store()
            store.start()
            await waitForProbe(store)
            let root = ZStack {
                AppBackground()
                ContainerDetailView(store: store, name: name, onBack: {})
            }
            .frame(width: Theme.panelWidth, height: Theme.panelHeight)
            exit(await render(root, to: destination) ? 0 : 1)
        }
        RunLoop.main.run()
        exit(1)
    }

    private static func widgetSnapshot(_ path: String?) -> Never {
        let destination = path ?? ".build/widget.png"
        Task { @MainActor in
            NSApplication.shared.setActivationPolicy(.accessory)
            let store = Store()

            var sample = Probe()
            sample.hostname = "server"
            sample.os = "Ubuntu 24.04.5 LTS"
            sample.kernel = "6.8.0-147-generic"
            sample.dockerVersion = "29.9.0"
            sample.uptimeSeconds = 9 * 86_400 + 4 * 3_600
            sample.rebootRequired = true
            sample.ramTotal = 8 * 1_073_741_824
            sample.ramAvailable = 2_576_980_377
            sample.cpuPercent = 23.4
            sample.cpuCores = 4
            sample.load1 = 0.64
            sample.load5 = 0.41
            sample.load15 = 0.33
            sample.diskTotal = 128 * 1_073_741_824
            sample.diskUsed = 74 * 1_073_741_824
            sample.aptUpgradable = (0..<30).map { "package-\($0)" }
            sample.containers = (0..<16).map { index in
                var container = Container(name: "app-\(index)")
                container.state = index == 15 ? "exited" : "running"
                container.status = container.state
                return container
            }
            store.previewSeed(sample)

            let root = ZStack {
                AppBackground()
                ServerWidgetView(store: store, onClose: {})
                    .padding(10)
            }
            .frame(width: 308, height: 372)

            exit(await render(root, to: destination, size: CGSize(width: 308, height: 372)) ? 0 : 1)
        }
        RunLoop.main.run()
        exit(1)
    }

    private static func settingsSnapshot(_ path: String?) -> Never {
        let destination = path ?? ".build/settings.png"
        Task { @MainActor in
            NSApplication.shared.setActivationPolicy(.accessory)
            let store = Store()
            store.start()
            await waitForProbe(store)
            let root = ZStack {
                AppBackground()
                SettingsView(store: store)
            }
            exit(await render(root, to: destination) ? 0 : 1)
        }
        RunLoop.main.run()
        exit(1)
    }

    @MainActor
    private static func waitForProbe(_ store: Store) async {
        let deadline = Date().addingTimeInterval(25)
        while store.probe == nil, Date() < deadline {
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
    }

    @MainActor
    private static func render<V: View>(
        _ view: V,
        to destination: String,
        size: CGSize = CGSize(width: Theme.panelWidth, height: Theme.panelHeight)
    ) async -> Bool {
        switch ProcessInfo.processInfo.environment["SERVERFO_SNAPSHOT_SCHEME"]?.lowercased() {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: break
        }

        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: size.width, height: size.height)

        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        window.orderFrontRegardless()
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        hosting.layoutSubtreeIfNeeded()

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            print("snapshot failed: no bitmap")
            return false
        }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            print("snapshot failed: no png")
            return false
        }
        let url = URL(fileURLWithPath: (destination as NSString).expandingTildeInPath)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        do {
            try data.write(to: url)
            print("wrote \(url.path)")
            return true
        } catch {
            print("error: \(error.localizedDescription)")
            return false
        }
    }

    private static func prune() -> Never {
        let store = HistoryStore()
        let removed = store.pruneNow()
        print("removed \(removed) rows older than \(HistoryStore.retentionDays) days")
        exit(0)
    }

    private final class LineBox {
        private let lock = NSLock()
        private var lines: [String] = []

        func append(_ line: String) {
            lock.lock()
            lines.append(line)
            lock.unlock()
        }

        var text: String {
            lock.lock()
            defer { lock.unlock() }
            return lines.joined(separator: "\n")
        }
    }

    private static func tailscale(_ value: String?) -> Never {
        guard let value, value == "on" || value == "off" else {
            print("usage: ServerInfo --tailscale on|off")
            exit(2)
        }
        UserDefaults.standard.set(value == "on", forKey: SSHConfig.Keys.useTailscale)
        let config = SSHConfig.current()
        print("tailscale \(value) · \(config.label)")
        exit(0)
    }

    private static func tailscaleIP() -> Never {
        runAndExit {
            if let ip = await Tailscale.piIP() {
                print(ip)
                return 0
            }
            print("could not find the Pi on the tailnet")
            return 1
        }
    }

    private static func route() -> Never {
        let config = SSHConfig.current()
        print("server:    \(config.destination):\(config.port)")
        print("tailscale: \(config.useTailscale ? "on" : "off")")
        print("jump:      \(config.jumpDestination ?? "direct")")
        print("route:     \(config.label)")
        exit(0)
    }

    private static func vitals() -> Never {
        runAndExit {
            do {
                let raw = try await RemoteProbe.fetch()
                let probe = ProbeParser.parse(raw)
                print("host      \(probe.hostname)")
                print("RAM       \(Fmt.bytes(probe.ramUsed)) / \(Fmt.bytes(probe.ramTotal)) · \(Fmt.percent(probe.ramPercent))")
                print("CPU       \(Fmt.percent(probe.cpuPercent)) · \(probe.cpuCores) cores · load \(String(format: "%.2f %.2f %.2f", probe.load1, probe.load5, probe.load15))")
                print("disk      \(Fmt.bytes(probe.diskUsed)) / \(Fmt.bytes(probe.diskTotal)) · \(Fmt.percent(probe.diskPercent))")
                print("uptime    \(Fmt.uptime(probe.uptimeSeconds)) · reboot \(probe.rebootRequired ? "required" : "not required")")
                print("docker    \(probe.running) running · \(probe.stopped) stopped")
                print("updates   \(probe.aptUpgradable.count) pending")
                return 0
            } catch {
                print("error: \(error.localizedDescription)")
                return 1
            }
        }
    }

    private static func clearCache() -> Never {
        runAndExit {
            let started = Date()
            let box = LineBox()
            var code: Int32 = -1

            do {
                let result = try await SSH.execute(
                    Maintenance.cacheScript,
                    config: .current(),
                    timeout: 120
                ) { line in
                    print(line)
                    fflush(stdout)
                    box.append(line)
                }
                code = result.code
            } catch {
                let message = "error: \(error.localizedDescription)"
                print(message)
                box.append(message)
            }

            let finished = Date()
            let history = HistoryStore()
            history.addMaintenance(
                started: started,
                finished: finished,
                trigger: "cache",
                exitCode: Int(code),
                output: box.text
            )
            if code == 0 {
                history.setMeta("lastCacheClear", String(finished.timeIntervalSince1970))
            }
            history.prune()
            print("exit \(code)")
            return code
        }
    }

    private static func upgradeIfRequested(force: Bool) -> Never {
        let store = HistoryStore()

        func date(_ key: String) -> Date? {
            guard let raw = store.meta(key), let epoch = Double(raw) else { return nil }
            return Date(timeIntervalSince1970: epoch)
        }

        let now = Date()
        let firstSeen = date("firstSeen") ?? now
        if store.meta("firstSeen") == nil {
            store.setMeta("firstSeen", String(now.timeIntervalSince1970))
        }
        let lastSuccess = date("lastUpgrade")
        let lastAttempt = date("lastAttempt")

        if !force {
            let next = UpgradeSchedule.next(
                lastSuccess: lastSuccess,
                lastAttempt: lastAttempt,
                firstSeen: firstSeen
            )
            if let next, now < next {
                print("not due until \(Fmt.dateTime(next))")
                exit(0)
            }
        }

        print("running sudo apt update && sudo apt upgrade -y on \(SSHConfig.current().label)")
        runAndExit {
            let started = Date()
            let box = LineBox()
            var code: Int32 = -1

            do {
                let result = try await SSH.execute(
                    Maintenance.script,
                    config: .current(),
                    timeout: 3_600
                ) { line in
                    print(line)
                    fflush(stdout)
                    box.append(line)
                }
                code = result.code
            } catch {
                let message = "error: \(error.localizedDescription)"
                print(message)
                box.append(message)
            }

            let output = box.text
            let finished = Date()
            store.addMaintenance(
                started: started,
                finished: finished,
                trigger: force ? "manual-cli" : "scheduled-cli",
                exitCode: Int(code),
                output: output
            )
            store.setMeta("lastAttempt", String(finished.timeIntervalSince1970))
            if code == 0 {
                store.setMeta("lastUpgrade", String(finished.timeIntervalSince1970))
            }
            store.prune()
            print("exit \(code)")
            return code
        }
    }

    private static func loginItem(_ value: String?) -> Never {
        guard let value, value == "on" || value == "off" else {
            print("usage: ServerInfo --loginitem on|off")
            exit(2)
        }
        do {
            try LoginItem.set(value == "on")
            print("login item \(LoginItem.enabled ? "on" : "off")")
            exit(0)
        } catch {
            print("error: \(error.localizedDescription)")
            exit(1)
        }
    }

    private static func updateCheck() -> Never {
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        runAndExit {
            guard let tag = await UpdateCheck.fetchLatest() else {
                print("v\(current) · could not reach GitHub")
                return 1
            }
            print(UpdateCheck.newer(latest: tag, current: current)
                  ? "v\(current) · \(tag) available (brew upgrade --cask server-fo)"
                  : "v\(current) · up to date")
            return 0
        }
    }

    private static func pad(_ value: String, _ width: Int) -> String {
        if value.count >= width { return String(value.prefix(width)) }
        return value + String(repeating: " ", count: width - value.count)
    }
}

// MARK: - Self test

enum SelfTest {
    static func run() -> Never {
        var failures = 0

        func check(_ name: String, _ condition: Bool, _ detail: String = "") {
            if condition {
                print("ok   \(name)")
            } else {
                failures += 1
                print("FAIL \(name)\(detail.isEmpty ? "" : " — \(detail)")")
            }
        }

        // Byte parsing covers the decimal units docker uses for I/O and the
        // binary units it uses for memory.
        check("bytes MiB", ProbeParser.bytes("20.44MiB") == 21_432_893,
              "\(ProbeParser.bytes("20.44MiB"))")
        check("bytes kB", ProbeParser.bytes("24.6kB") == 24_600)
        check("bytes GiB", ProbeParser.bytes("6.736GiB") == 7_232_724_926)
        check("bytes B", ProbeParser.bytes("0B") == 0)
        check("bytes empty", ProbeParser.bytes("") == 0)

        let fixture = """
        ###META
        host=server
        os=Ubuntu 24.04.5 LTS
        kernel=6.8.0-90-generic
        uptime=432001
        docker=29.9.0
        reboot=0
        ram_total=8000000
        ram_available=2000000
        cpu=12.5
        cores=4
        load=0.50 0.40 0.30
        disk_total=100000000
        disk_used=25000000
        ###APT
        linux-image-6.8.0-91
        openssl
        ###PS
        {"Names":"web","Image":"registry.example.com/team/nginx:1.27","State":"running","Status":"Up 2 days (healthy)","HealthStatus":"healthy","RunningFor":"2 days ago","CreatedAt":"2026-01-01 10:00:00 +0000 UTC","Ports":"0.0.0.0:8080->80/tcp, [::]:8080->80/tcp","Networks":"homenet","Labels":"com.docker.compose.project=stack,com.docker.compose.service=web,com.docker.compose.project.working_dir=/opt/stacks/stack,com.docker.compose.project.config_files=/opt/stacks/stack/compose.yaml","Command":"\\"/docker-entrypoint.sh\\"","Mounts":"/data"}
        ###STATS
        {"Name":"web","CPUPerc":"1.5%","MemUsage":"120MiB / 1GiB","MemPerc":"1.7%","NetIO":"1kB / 2kB","BlockIO":"3kB / 4kB","PIDs":"9"}
        ###INSPECT
        /web|2|unless-stopped|1073741824|2026-01-01T10:00:00Z
        """

        let probe = ProbeParser.parse(fixture)
        check("meta host", probe.hostname == "server", probe.hostname)
        check("meta os", probe.os == "Ubuntu 24.04.5 LTS")
        check("meta docker", probe.dockerVersion == "29.9.0")
        check("pending packages", probe.aptUpgradable == ["linux-image-6.8.0-91", "openssl"], "\(probe.aptUpgradable)")
        check("host ram total", probe.ramTotal == 8_192_000_000, "\(probe.ramTotal)")
        check("host ram used", probe.ramUsed == 6_144_000_000, "\(probe.ramUsed)")
        check("host ram percent", probe.ramPercent == 75, "\(probe.ramPercent)")
        check("host cpu", probe.cpuPercent == 12.5, "\(probe.cpuPercent)")
        check("host cores", probe.cpuCores == 4)
        check("host load", probe.load1 == 0.5 && probe.load15 == 0.3)
        check("host disk", probe.diskPercent == 25, "\(probe.diskPercent)")
        check("container count", probe.containers.count == 1)
        check("running count", probe.running == 1)

        if let web = probe.containers.first {
            check("name", web.name == "web")
            check("cpu", web.cpu == 1.5)
            check("memory used", web.memUsed == 125_829_120, "\(web.memUsed)")
            check("memory limit", web.memLimit == 1_073_741_824, "\(web.memLimit)")
            check("restarts", web.restarts == 2)
            check("restart policy", web.restartPolicy == "unless-stopped")
            check("compose project", web.project == "stack")
            check("compose service", web.service == "web")
            check("image short", web.imageShort == "nginx:1.27", web.imageShort)
            check("ports deduplicated", web.shortPorts == "8080→80", web.shortPorts)
            check("health", web.healthState == .healthy)
            check("running", web.isRunning)
        }

        check("version newer", UpdateCheck.newer(latest: "v1.2.0", current: "1.1.9"))
        check("version equal", !UpdateCheck.newer(latest: "v1.1.0", current: "1.1.0"))
        check("version shorter", UpdateCheck.newer(latest: "v1.2", current: "1.1.9"))

        check("menu bar icon bundled", Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png") != nil)
        check("app icon bundled", Bundle.main.url(forResource: "AppIcon", withExtension: "icns") != nil)

        // Retention and metadata, on a throwaway database.
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("serverfo-selftest-\(UUID().uuidString).sqlite")
        let history = HistoryStore(path: temporary)
        history.setMeta("probe", "value")
        check("meta round trip", history.meta("probe") == "value")

        let old = Date().addingTimeInterval(-40 * 86_400)
        history.addMaintenance(started: old, finished: old, trigger: "test", exitCode: 0, output: "old")
        history.addMaintenance(started: Date(), finished: Date(), trigger: "test", exitCode: 0, output: "new")
        check("maintenance rows", history.maintenance().count == 2)
        let removed = history.pruneNow()
        check("retention removes old rows", removed >= 1, "\(removed)")
        check("recent row kept", history.maintenance().count == 1)

        try? FileManager.default.removeItem(at: temporary)
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: temporary.path + "-wal"))
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: temporary.path + "-shm"))

        check("sample is 5 minutes by default", SampleCadence.seconds(fromSetting: 0) == 300)
        check("sample setting is minutes", SampleCadence.seconds(fromSetting: 15) == 900)

        check(
            "schedule waits 30 days",
            UpgradeSchedule.next(
                lastSuccess: Date(timeIntervalSince1970: 0),
                lastAttempt: nil,
                firstSeen: nil
            ) == Date(timeIntervalSince1970: 30 * 86_400)
        )
        check(
            "failed run retries tomorrow",
            UpgradeSchedule.next(
                lastSuccess: nil,
                lastAttempt: Date(timeIntervalSince1970: 100),
                firstSeen: Date(timeIntervalSince1970: 0)
            ) == Date(timeIntervalSince1970: 100 + 86_400)
        )

        print("")
        print(failures == 0 ? "selftest passed" : "selftest failed: \(failures) failure(s)")
        exit(failures == 0 ? 0 : 1)
    }
}
