# Changelog

All notable changes to S-Info. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and releases use
[Semantic Versioning](https://semver.org/).

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
- Tag-driven GitHub release workflow producing a universal `S-Info.zip`, and a
  Homebrew cask in `Dhivyadhanush/homebrew-tap`.

### Notes

- Host CPU, overall memory and network totals are intentionally excluded; the
  dynamic island tracks those. S-Info only reports per-application figures.
- The app never reboots the server, even when a kernel upgrade asks for it.
- Requires key-based SSH and, for upgrades only, passwordless sudo.
