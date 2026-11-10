import Foundation

// MARK: - Connection settings

struct SSHConfig {
    var host: String
    var user: String
    var port: Int
    var identity: String

    enum Keys {
        static let host = "sinfo.ssh.host"
        static let user = "sinfo.ssh.user"
        static let port = "sinfo.ssh.port"
        static let identity = "sinfo.ssh.identity"
    }

    static func current() -> SSHConfig {
        let defaults = UserDefaults.standard
        return SSHConfig(
            host: defaults.string(forKey: Keys.host) ?? "192.168.1.22",
            user: defaults.string(forKey: Keys.user) ?? "server1",
            port: defaults.integer(forKey: Keys.port) == 0 ? 22 : defaults.integer(forKey: Keys.port),
            identity: defaults.string(forKey: Keys.identity) ?? ""
        )
    }

    var destination: String {
        user.isEmpty ? host : "\(user)@\(host)"
    }

    var isValid: Bool {
        !host.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var label: String {
        "\(destination):\(port)"
    }
}

// MARK: - Errors

enum SSHError: LocalizedError {
    case notConfigured
    case unreachable(String)
    case commandFailed(Int32, String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "No server configured. Open Settings and enter the SSH host."
        case .unreachable(let message):
            return "Could not reach the server. \(message)"
        case .commandFailed(let code, let message):
            let tail = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return tail.isEmpty ? "Remote command exited \(code)." : tail
        }
    }
}

// MARK: - Runner

enum SSH {
    /// Runs a shell script on the server through stdin, so no quoting rules
    /// apply to the script body.
    static func run(
        _ script: String,
        config: SSHConfig = .current(),
        timeout: TimeInterval = 45,
        onLine: ((String) -> Void)? = nil
    ) async throws -> String {
        let result = try await execute(
            script, config: config, timeout: timeout, onLine: onLine
        )
        guard result.code == 0 else {
            throw SSHError.commandFailed(result.code, tail(result.output))
        }
        return result.output
    }

    static func execute(
        _ script: String,
        config: SSHConfig,
        timeout: TimeInterval,
        onLine: ((String) -> Void)?
    ) async throws -> (code: Int32, output: String) {
        guard config.isValid else { throw SSHError.notConfigured }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
                process.arguments = arguments(for: config) + [config.destination, "bash -s"]

                let input = Pipe()
                let output = Pipe()
                process.standardInput = input
                process.standardOutput = output
                process.standardError = output

                var collected = Data()
                let lock = NSLock()
                let group = DispatchGroup()

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: SSHError.unreachable(error.localizedDescription))
                    return
                }

                // Feed the script and close stdin. 1.5 KB fits in the pipe
                // buffer, so this cannot block before the remote shell starts.
                input.fileHandleForWriting.write(Data(script.utf8))
                try? input.fileHandleForWriting.close()

                group.enter()
                DispatchQueue.global(qos: .utility).async {
                    var pending = Data()
                    while true {
                        let chunk = output.fileHandleForReading.availableData
                        if chunk.isEmpty { break }

                        lock.lock()
                        collected.append(chunk)
                        lock.unlock()

                        guard let onLine else { continue }
                        pending.append(chunk)
                        while let newline = pending.firstIndex(of: 0x0A) {
                            let lineData = pending[..<newline]
                            pending = Data(pending[pending.index(after: newline)...])
                            let line = String(decoding: lineData, as: UTF8.self)
                            onLine(line)
                        }
                    }
                    if !pending.isEmpty, let onLine {
                        onLine(String(decoding: pending, as: UTF8.self))
                    }
                    group.leave()
                }

                var timedOut = false
                var watchdog: DispatchWorkItem?
                if timeout > 0 {
                    let item = DispatchWorkItem {
                        if process.isRunning {
                            timedOut = true
                            process.terminate()
                        }
                    }
                    watchdog = item
                    DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: item)
                }

                process.waitUntilExit()
                watchdog?.cancel()
                group.wait()

                lock.lock()
                let data = collected
                lock.unlock()

                let text = String(decoding: data, as: UTF8.self)
                if timedOut {
                    continuation.resume(
                        throwing: SSHError.unreachable("Timed out after \(Int(timeout))s.")
                    )
                } else {
                    continuation.resume(returning: (process.terminationStatus, text))
                }
            }
        }
    }

    private static func arguments(for config: SSHConfig) -> [String] {
        let socket = "/tmp/sinfo-\(getuid())-%C"
        var args = [
            "-T",
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=8",
            "-o", "ServerAliveInterval=15",
            "-o", "ServerAliveCountMax=3",
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", "LogLevel=ERROR",
            "-o", "ControlMaster=auto",
            "-o", "ControlPath=\(socket)",
            "-o", "ControlPersist=300",
        ]
        if config.port != 22 {
            args += ["-p", String(config.port)]
        }
        let identity = config.identity.trimmingCharacters(in: .whitespaces)
        if !identity.isEmpty {
            args += ["-i", (identity as NSString).expandingTildeInPath]
        }
        return args
    }

    private static func tail(_ text: String, lines: Int = 12) -> String {
        let pieces = text.split(separator: "\n", omittingEmptySubsequences: true)
        return pieces.suffix(lines).joined(separator: "\n")
    }
}

// MARK: - Remote probe

enum RemoteProbe {
    /// Every value the panel needs, in one SSH round trip. Overall host CPU,
    /// memory and network are deliberately absent: the dynamic island already
    /// tracks those, and this app is about the applications on the server.
    static let script = """
    export LC_ALL=C
    export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    echo '###META'
    echo "host=$(hostname 2>/dev/null)"
    echo "os=$(. /etc/os-release 2>/dev/null; echo "$PRETTY_NAME")"
    echo "kernel=$(uname -r 2>/dev/null)"
    echo "uptime=$(cut -d. -f1 /proc/uptime 2>/dev/null)"
    echo "docker=$(docker version --format '{{.Server.Version}}' 2>/dev/null)"
    echo "reboot=$([ -f /var/run/reboot-required ] && echo 1 || echo 0)"
    echo '###APT'
    apt list --upgradable 2>/dev/null | tail -n +2 | cut -d/ -f1
    echo '###PS'
    docker ps -a --format '{{json .}}' 2>/dev/null
    echo '###STATS'
    docker stats --no-stream --format '{{json .}}' 2>/dev/null
    echo '###INSPECT'
    if [ -n "$(docker ps -aq 2>/dev/null)" ]; then
      docker inspect -f '{{.Name}}|{{.RestartCount}}|{{.HostConfig.RestartPolicy.Name}}|{{.HostConfig.Memory}}|{{.State.StartedAt}}' $(docker ps -aq) 2>/dev/null
    fi
    """

    static func fetch(config: SSHConfig = .current()) async throws -> String {
        try await SSH.run(script, config: config, timeout: 45)
    }
}
