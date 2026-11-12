# Server-Fo 1.3.4

Menu bar first.

## Changed

- The app is back to being a **menu-bar app** with no main window. Click the
  server-rack icon to open the panel.
- The Dock icon and dashboard window are now **off by default**. They remain an
  optional fallback in **Settings → General → Show Dock icon** for a very full
  menu bar.
- Reopening the app does not force a window unless that fallback is enabled.

Everything else from 1.3.3 is included: Tailscale routing, launch at login,
30-day history, scheduled apt upgrades, RAM cache clear, and the adaptive theme.

## Upgrade

```shell
brew upgrade --cask server-fo
```

If the menu-bar icon is hidden by overflow, pin Server-Fo with Align-MBar or
turn on the optional Dock icon.
