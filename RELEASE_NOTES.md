# Server-Fo 1.3.2

Tailscale routing, launch at login, and a startup reliability fix.

## Start at login, reliably

- The background store now starts from the app itself. Previously it waited for
  the menu-bar label's `onAppear`, which can be delayed indefinitely when the
  menu bar is full — the app stayed alive but never refreshed or sampled.
- Installed copies still add themselves as a login item on first launch.
- Turn launch at login off in **Settings → General**.

## Tailscale

- Globe toggle in the header and **Settings → Connection**.
- Mac → Raspberry Pi over Tailscale (`pi@100.117.187.32`) → Pi forwards SSH to
  `server1@192.168.1.22` on its LAN.
- The Pi's tailnet IP is discovered from `tailscale status --json`, saved as the
  jump host, and shown in Settings and the footer.
- This is what to use on a hotspot or away from the server's LAN; the direct LAN
  route stays available with the toggle off.

## Upgrade

```shell
brew upgrade --cask server-fo
```

Existing history and settings are preserved. The current network is a hotspot,
so leave **Tailscale on** for this Mac.

## CLI

```shell
ServerInfo --tailscale on|off
ServerInfo --tailscale-ip
ServerInfo --route
```
