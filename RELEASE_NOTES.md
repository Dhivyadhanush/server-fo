# Server-Fo 1.3.3

An always-available way to open the app.

## New

- **Dock icon + dashboard window.** Click the Server-Fo Dock icon, open the app
  again from Launchpad, or use **Settings → About → Open dashboard** to get the
  full panel in a normal window.
- This fixes the case where the menu-bar icon is hidden because the menu bar is
  full: the app kept running but there was no visible way to open it.
- **Settings → General → Show Dock icon** turns the Dock icon off if you prefer a
  pure menu-bar app.

## Also included

- Tailscale toggle: Mac → `pi@100.117.187.32` → `server1@192.168.1.22`.
- Launch at login, with background work now starting from the app itself rather
  than waiting for the menu-bar label.
- 30-day history, scheduled apt upgrades, RAM cache clear, themed UI.

## Upgrade

```shell
brew upgrade --cask server-fo
```

Existing data and settings are preserved.
