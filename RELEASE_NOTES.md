# Server-Fo 1.2.0

The app formerly known as **S-Info** is now **Server-Fo**.

## Rename

- New app: `Server-Fo.app`, bundle `dev.dhanuz.server-fo`, executable
  `ServerInfo`.
- New Homebrew cask: **`server-fo`**. The old `s-info` cask is retired.
- New data location: `~/Library/Application Support/Server-Fo`.
- This is a clean break — a fresh history database and fresh preferences. Old
  S-Info data is not migrated.

## Install

```shell
brew tap Dhivyadhanush/tap
brew trust Dhivyadhanush/tap
brew install --cask server-fo
open /Applications/Server-Fo.app
```

If S-Info is already installed, remove it first so there is only one app:

```shell
brew uninstall --cask --zap s-info
brew install --cask server-fo
```

## Same features

Docker containers grouped by stack, per-application CPU/memory/network/I/O,
mounts and logs on demand, 30-day local history, a scheduled
`sudo apt update && sudo apt upgrade -y` every 30 days, a RAM cache clear, the
adaptive light/dark theme, and the visibility controls.

No Apple developer account is involved. The cask clears the download quarantine
flag so the ad-hoc-signed app opens normally on macOS 27.

macOS 14+, key-based SSH, passwordless sudo for the maintenance actions.
