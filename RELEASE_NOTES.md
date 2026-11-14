# Server-Fo 1.4.1

A reliable menu-bar item.

## Fixed

- Replaced SwiftUI’s `MenuBarExtra` with a real `NSStatusItem`, created at launch.
  This fixes the case where the app was running but no menu-bar item appeared.
- **⌃⌥⌘S** opens the panel even when the menu-bar icon is hidden by overflow.
- Right-click the status item for **Open panel**, **Server widget** and **Quit**.
- `ServerInfo --toggle` opens the panel from the terminal.

## Widget

The floating server widget is unchanged: RAM, CPU/load, disk, uptime, Docker,
updates and reboot state. It is still off until enabled in **Settings → General →
Show server widget**.

The server itself is currently unreachable from the Pi, so the widget cannot
show live numbers until it is back online.

## Upgrade

```shell
brew upgrade --cask server-fo
```
