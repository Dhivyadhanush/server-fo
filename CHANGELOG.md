# Changelog

All notable changes to Server-Fo. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and releases use
[Semantic Versioning](https://semver.org/).

## [1.4.2] — 2026-11-14

### Fixed

- A development build under `.build` could rewrite the login item to its own
  path, which then disappeared and made the app fail to start with
  `EX_CONFIG`. Only an app installed under `/Applications` may repair the login
  item now.

## [1.4.1] — 2026-11-14

### Fixed

- Replaced SwiftUI `MenuBarExtra` with a plain `NSStatusItem`. The status item is
  created directly at launch instead of depending on a SwiftUI scene, which was
  not reliably inserting on this Mac.
- **⌃⌥⌘S** opens the same popover when the icon is hidden by menu-bar overflow.
- Right-clicking the status item offers **Open panel**, **Server widget** and
  **Quit**.
- `--toggle` opens the panel of a running instance from the terminal.
- Removed the now-unused menu-bar dot/count visibility toggles.

## [1.4.0] — 2026-11-14

### Added

- A floating **server vitals widget**: RAM, CPU + load average, root disk, uptime,
  Docker running count, pending package updates and reboot-required state.
  Always-on-top, draggable, remembers its position, and follows the same
  refresh interval and Tailscale route as the panel.
- **Settings → General → Show server widget** enables it; the card's close
  button hides it. It reappears at login while enabled.
- Host metrics come from `/proc/meminfo`, `/proc/stat`, `/proc/loadavg` and
  `df -Pk /` in the existing single SSH probe.

## [1.3.4] — 2026-11-12

### Changed

- The menu bar is the only normal entry point again. The optional Dock icon and
  dashboard window are **off by default**; enable **Settings → General → Show
  Dock icon** only if a full menu bar hides the status item.
- Opening the app again no longer forces the dashboard window unless the Dock
  fallback is enabled.

## [1.3.3] — 2026-11-12

### Added

- A Dock icon and a normal **dashboard window**. Clicking the Dock icon, opening
  the app again from Launchpad, or choosing **Open dashboard** in Settings shows
  the panel in a regular window. This is the fallback when the menu bar is full
  and the status item is hidden.
- Settings → General → **Show Dock icon** (on by default) controls it.

## [1.3.2] — 2026-11-12

### Fixed

- Background work now starts from the app itself, not only from the menu bar
  label's `onAppear`. On a full menu bar, or before the status item is inserted,
  that callback could be delayed indefinitely and leave the app running but
  idle: no refresh, no samples, no scheduled upgrades.
- The app records `lastLaunch` in its history metadata, which makes startup
  diagnostics possible.

## [1.3.1] — 2026-11-12

### Fixed

- First-launch login-item setup no longer bootouts a LaunchAgent that is
  already managing the running process, which could have restarted the app in a
  loop. It now only creates the agent when none exists and records the choice.

## [1.3.0] — 2026-11-12

### Added

- **Tailscale jump-host toggle** in the panel header and Settings → Connection.
  When on, the Mac connects to the Raspberry Pi over Tailscale
  (`pi@100.117.187.32`) and the Pi forwards the SSH session to
  `server1@192.168.1.22` on its LAN.
- Tailscale peer discovery: the Pi's current IPv4 tailnet address is read from
  `tailscale status --json`, saved as the jump host, and shown in Settings and
  the footer. The saved address is the fallback when discovery is unavailable.
- `--tailscale on|off`, `--tailscale-ip` and `--route` headless commands.
- Installed copies add themselves as a login item on first launch. Turning it
  off in Settings keeps it off.
- `KeepAlive` now restarts the app after a crash, but not after a manual Quit.

### Changed

- Settings order now puts Connection above the long visibility list.
- The footer shows `via Tailscale` while the jump route is active.

## [1.2.0] — 2026-11-10

### Changed

- Renamed the app from **S-Info** to **Server-Fo**.
- New bundle identifier `dev.dhanuz.server-fo`, executable `ServerInfo`, app
  bundle `Server-Fo.app`, support folder `~/Library/Application Support/Server-Fo`,
  lock file `Server-Fo.lock`, and LaunchAgent `dev.dhanuz.server-fo`.
- New Homebrew token `server-fo`. The old `s-info` cask is removed from the tap.
- This is a clean break: the new app starts with a fresh history database and
  fresh preferences. Old S-Info data is not migrated.

## [1.1.0] — 2026-11-10

### Added

- A themed interface with a gradient canvas, subtle grid, glass cards, glow
  accents, animated tab selection and redesigned metric tiles and charts.
- Appearance setting: follow macOS (default), or force Light or Dark. The whole
  palette, including chart and status colours, adapts to both.
- Settings → **What is visible**: toggle the status pill, hostname, footer, menu
  bar dot and count, the History and Updates tabs, each container-row field
  (image, uptime, ports, health, restarts, CPU, memory, stack counts), detail
  metrics/charts/mounts, history events, pending packages, activity log and the
  cache action. Toggles are instant, remembered, and have a "Show everything"
  reset.
- **RAM cache** action: `sync` then
  `sudo -n sh -c 'echo 3 > /proc/sys/vm/drop_caches'`, with a confirmation, last
  cleared time and a logged result.
- `--clear-cache` headless command.
- The app icon is now the same two-unit rack as the menu bar glyph, drawn from a
  single shape in `Resources/icon.swift`.

### Changed

- The activity log now labels package runs and cache runs separately, and the
  pending-package list and logs sit in the new card style.
- Settings is reorganised around appearance, visibility and connection, with
  compact visibility chips.
- Container rows, the detail hero, history timeline and update countdown ring
  were rebuilt for the new theme.

### Fixed

- Light-mode contrast for CPU, memory, status and chart colours.
- The settings snapshot no longer forces the system appearance over the
  requested one.

## [1.0.3] — 2026-11-10

### Fixed

- The "Check GitHub for updates" toggle showed as on but the store treated an
  unset preference as off, so a fresh install never checked. An absent key now
  means enabled, matching the UI.

## [1.0.2] — 2026-11-10

### Fixed

- The history sample interval was interpreted as seconds instead of minutes, so
  the default "every 5 minutes" actually wrote a sample on every refresh. It now
  samples at the chosen minute interval, keeping the 30-day database small.
  Existing rows are left alone and age out normally.

## [1.0.1] — 2026-11-10

### Added

- A Quit button in the panel header and in Settings → About.

### Fixed

- Quitting while `apt upgrade` is running is now blocked with an explanation,
  so a stray Cmd-Q cannot interrupt dpkg mid-transaction.
- The settings sheet is tall enough to show the maintenance card without
  scrolling past a cut-off card.

### Changed

- The Homebrew cask uses the current DSL (`depends_on macos: :sonoma`) and drops
  the deprecated `postflight`; Homebrew installs are not quarantined anyway.
- Install docs mention `brew trust`, which Homebrew requires before loading a
  third-party cask.

## [1.0.0] — 2026-11-10

First release.

### Added

- Menu bar app for one server over SSH, with a server glyph in the menu bar and
  a dot when a container is unhealthy or stopped.
- Container list grouped by compose stack: live CPU, memory used, ports, image,
  uptime, health, restarts; sort by CPU/memory/name/restarts; filter across
  name, image, stack and port.
- Per-container detail: CPU, memory (only real limits), network rx/tx, block
  I/O, PIDs, restart policy, image, command, compose metadata, plus on-demand
  mounts and the last 80 log lines.
- Rolling 30-day history in local SQLite: a sample every 5 minutes, state-change
  events, per-container CPU/memory charts for 24h, 7d and 30d, and automatic
  deletion of anything older than 30 days.
- Maintenance tab: pending package list, reboot-required badge, a manual
  `sudo apt update && sudo apt upgrade -y`, live streamed output and a log of
  past runs.
- Automatic upgrade every 30 days, enabled by default, with a 24-hour retry on
  failure and a catch-up run at the next refresh after the due time.
- Settings for SSH host/user/port/identity, refresh and sample intervals, launch
  at login, menu bar badge and update checks.
- Headless commands: `--probe`, `--dump`, `--history`, `--sample`, `--prune`,
  `--upgrade`, `--upgrade-if-due`, `--update`, `--loginitem`, `--selftest`, and
  snapshot renderers for the docs.
- Tag-driven GitHub release workflow producing a universal `Server-Fo.zip`, and a
  Homebrew cask in `Dhivyadhanush/homebrew-tap`.

### Notes

- Host CPU, overall memory and network totals are intentionally excluded; the
  dynamic island tracks those. Server-Fo only reports per-application figures.
- The app never reboots the server, even when a kernel upgrade asks for it.
- Requires key-based SSH and, for upgrades only, passwordless sudo.
