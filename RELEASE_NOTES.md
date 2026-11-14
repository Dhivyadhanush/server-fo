# Server-Fo 1.4.0

A floating server-vitals widget.

## New

- **RAM** used / total and percentage.
- **CPU** utilisation, core count and 1/5/15-minute load average.
- **Root disk** used / total and percentage.
- **Uptime**, **Docker running count**, **pending updates** and
  **reboot-required** flag.
- Always-on-top, draggable card that remembers its position and updates on the
  normal refresh cycle.
- **Settings → General → Show server widget** enables it; the X on the card hides
  it. It reappears at login while enabled.
- Uses the same SSH/Tailscale route as the panel. Host metrics were added to the
  existing probe (`/proc/meminfo`, `/proc/stat`, `/proc/loadavg`, `df -Pk /`).

## Open

Open the menu-bar panel → gear → General → **Show server widget**.

## Upgrade

```shell
brew upgrade --cask server-fo
```

Existing history and settings are preserved. The widget is off until enabled.
