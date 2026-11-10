# S-Info 1.0.1

Safety and polish for the menu bar server monitor.

## Changes

- **A real Quit button** in the panel header and in Settings → About.
- **Quitting is blocked while apt is running.** S-Info shows a warning and keeps
  the app alive rather than letting Cmd-Q interrupt dpkg mid-transaction.
- The settings sheet is slightly taller, so the maintenance card is fully
  visible.
- The Homebrew cask now uses the current DSL and documents `brew trust`.

## Install

```shell
brew tap Dhivyadhanush/tap
brew trust Dhivyadhanush/tap
brew install --cask s-info
open /Applications/S-Info.app
```

Upgrading from 1.0.0:

```shell
brew upgrade --cask s-info
```

Then open Settings and point it at your server, test the connection, and enable
**Launch at login**.

## Notes

- macOS 14+, key-based SSH, passwordless sudo for the upgrade feature.
- Ad-hoc signed, not notarised. Homebrew installs are not quarantined; manual
  downloads need one `xattr` command (see README).
- Host CPU, memory and network totals remain intentionally out of scope; S-Info
  shows per-application usage only.
