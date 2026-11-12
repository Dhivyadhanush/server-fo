# Server-Fo 1.3.0

Tailscale routing and launch-at-login.

## Tailscale

- A **Tailscale toggle** now sits in the panel header (globe icon) and in
  **Settings → Connection**.
- When enabled: Mac → Raspberry Pi over Tailscale (`pi@100.117.187.32`) → Pi
  forwards the SSH session to `server1@192.168.1.22` on its LAN.
- The Pi's tailnet IPv4 is discovered from `tailscale status --json`, saved as
  the jump host, and shown in Settings and the footer. The saved address is the
  fallback if discovery fails.
- The jump only forwards TCP; the Mac still authenticates directly to server1,
  so the Pi does not need a key for server1.
- Requires the Tailscale app running on the Mac and the Pi online. Key-based SSH
  to the Pi is still required.

## Open at login

- An installed copy registers itself as a login item on first launch, so the
  menu bar app is there when you log in.
- Turn it off in **Settings → General**; it stays off.
- If the app crashes, launchd restarts it. A manual **Quit** stays quit.

## Upgrade

```shell
brew upgrade --cask server-fo
```

Your existing Server-Fo 1.2.0 history and settings are preserved. The Tailscale
toggle is off by default.

## New CLI

```shell
ServerInfo --tailscale on|off
ServerInfo --tailscale-ip
ServerInfo --route
```
