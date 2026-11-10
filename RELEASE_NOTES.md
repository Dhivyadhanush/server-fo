# S-Info 1.0.0

A menu bar app for one server: Docker containers, per-application usage, a
30-day history, and a logged `apt` upgrade every 30 days.

## Highlights

- **Per-application detail, not host totals.** CPU, memory, network, block I/O,
  PIDs, restarts, ports, compose metadata, mounts and recent logs — for every
  container. Host CPU/RAM/network stay in the dynamic island.
- **30-day history.** A sample every 5 minutes plus start/stop/restart/health
  events, stored locally and deleted automatically once it is older than a
  month.
- **Scheduled maintenance.** Runs exactly `sudo apt update && sudo apt upgrade -y`
  every 30 days (on by default), streams the output live, stores the log, and
  retries after 24 hours if it fails. No reboot, no dist-upgrade, no autoremove.
- **Native and small.** SwiftUI menu bar app, one SSH round trip per refresh,
  no daemon and no stored credentials.

## Install

```shell
brew tap Dhivyadhanush/tap
brew trust Dhivyadhanush/tap
brew install --cask s-info
open /Applications/S-Info.app
```

Then open Settings and point it at your server (default
`server1@192.168.1.22`), test the connection, and enable **Launch at login**.

## Requirements

- macOS 14 or newer.
- SSH key access; the app runs `/usr/bin/ssh` in batch mode.
- Passwordless sudo for the upgrade feature (viewing works without it).

## Notes

- Ad-hoc signed, not notarised. Homebrew installs are not quarantined; manual downloads need one `xattr` command (see README).
- The app must be running for background sampling and the 30-day schedule; the
  login item is recommended.
- If the Mac is asleep when an upgrade is due, it runs at the first refresh
  after wake.

## Checksums

`S-Info.zip` SHA-256: see the `.sha256` asset attached to this release.
