# Server-Fo 1.3.1

Tailscale routing, launch-at-login, and a login-item setup fix.

## Tailscale

- A **Tailscale toggle** in the panel header (globe icon) and in
  **Settings → Connection**.
- When enabled: Mac → Raspberry Pi over Tailscale (`pi@100.117.187.32`) → Pi
  forwards the SSH session to `server1@192.168.1.22` on its LAN.
- The Pi's tailnet IPv4 is discovered from `tailscale status --json`, saved as
  the jump host, and shown in Settings and the footer. The saved address is the
  fallback if discovery fails.
- The jump only forwards TCP; the Mac authenticates directly to server1, so the
  Pi does not need a key for server1.
- Requires the Tailscale app running on the Mac and the Pi online. Key-based SSH
  to the Pi is required.

## Open at login

- An installed copy registers itself as a login item on first launch.
- Turn it off in **Settings → General**; it stays off.
- 1.3.1 fixes first-launch setup so it never boots out a LaunchAgent that is
  already running the app.

## Upgrade

```shell
brew upgrade --cask server-fo
```

Existing Server-Fo 1.2.0 history and settings are preserved. The Tailscale
toggle is off by default.

## CLI

```shell
ServerInfo --tailscale on|off
ServerInfo --tailscale-ip
ServerInfo --route
```
