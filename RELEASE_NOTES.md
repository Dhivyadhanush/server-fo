# Server-Fo 1.6.1

Security hardening, a flatter UI, and two startup/state fixes.

## Connection security

- **Strict host-key pinning:** `StrictHostKeyChecking=yes`; a changed key is a
  hard failure.
- **Key-only SSH:** password and keyboard-interactive auth are disabled, with no
  agent/X11 forwarding and no local commands.
- **No persistent control socket:** every refresh is a fresh, short-lived SSH
  session.
- **IPv4 forced** for the Tailscale jump, fixing intermittent banner timeouts.
- The Pi only forwards TCP ciphertext; SSH remains end-to-end between the Mac and
  the server.

## Server

- Password SSH disabled on both the Pi and `server1`.
- `server1` no longer has `NOPASSWD: ALL`. Admin sudo still needs the account
  password; only these exact commands are passwordless:
  ```
  /usr/bin/apt update
  /usr/bin/apt upgrade -y
  /usr/bin/env DEBIAN_FRONTEND=noninteractive /usr/bin/apt upgrade -y
  /usr/sbin/sysctl -w vm.drop_caches=3
  ```
- RAM cache clearing now uses `sysctl` instead of a passwordless `sh` root
  shell.

## Local data

- History folder `0700`; SQLite/WAL/SHM and lock file `0600`.
- Settings has a **Security** section with the client protections and a copyable
  hardening summary.
- FileVault is on; the SSH key is `0600` in a `0700` `~/.ssh`.

## UI

- Flatter, calmer panel and widget: solid canvas, solid accent tab, flat cards
  and bars; removed radial glows, the grid and gradient fills.
- Native Form settings with route-aware address editing.
- Fixed the blank refresh control while a refresh is running.

## Fixes

- Retained the `--toggle` notification observer.
- Synchronized widget visibility to preferences immediately.
- Kept the optional Dock fallback off unless explicitly enabled.

## Upgrade

```shell
brew upgrade --cask server-fo
```
