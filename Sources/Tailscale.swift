import Foundation

/// Reads the local Tailscale status to discover the Raspberry Pi's tailnet
/// address. The configured jump host is the fallback when the CLI is missing
/// or the peer cannot be matched.
enum Tailscale {
    private struct Status: Decodable {
        let Peer: [String: Peer]?
    }

    private struct Peer: Decodable {
        let HostName: String?
        let DNSName: String?
        let TailscaleIPs: [String]?
        let Online: Bool?
    }

    static var cliPath: String? {
        let candidates = [
            "/Applications/Tailscale.app/Contents/MacOS/Tailscale",
            "/usr/local/bin/tailscale",
            "/opt/homebrew/bin/tailscale",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Returns the Pi's IPv4 tailnet address, if it can be found.
    static func piIP() async -> String? {
        guard let output = await run(["status", "--json"]),
              let data = output.data(using: .utf8),
              let status = try? JSONDecoder().decode(Status.self, from: data),
              let peers = status.Peer?.values else {
            return nil
        }

        let configured = UserDefaults.standard.string(forKey: SSHConfig.Keys.jumpHost)

        for peer in peers {
            let name = ((peer.HostName ?? "") + " " + (peer.DNSName ?? "")).lowercased()
            guard name.contains("rasb") || name.contains("rasp") else { continue }
            if peer.Online == false { continue }
            if let ip = peer.TailscaleIPs?.first(where: { $0.contains(".") }) {
                return ip
            }
        }

        // If the peer was renamed, accept the configured address only when the
        // tailnet actually lists it.
        if let configured, !configured.isEmpty {
            for peer in peers where peer.TailscaleIPs?.contains(configured) == true {
                if peer.Online != false { return configured }
            }
        }

        return nil
    }

    private static func run(_ arguments: [String]) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                guard let path = cliPath else {
                    continuation.resume(returning: nil)
                    return
                }

                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = arguments

                let output = Pipe()
                process.standardOutput = output
                process.standardError = Pipe()

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: nil)
                    return
                }

                let watchdog = DispatchWorkItem {
                    if process.isRunning { process.terminate() }
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + 6, execute: watchdog)

                let data = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                watchdog.cancel()

                guard process.terminationStatus == 0 else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: String(decoding: data, as: UTF8.self))
            }
        }
    }
}
