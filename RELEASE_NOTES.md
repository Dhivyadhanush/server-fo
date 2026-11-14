# Server-Fo 1.5.0

Settings now match Copilot Usage’s native Form layout.

## Changed

- Grouped macOS `Form` sections, standard fields, toggles and pickers.
- **Only the active route’s address is editable:**
  - Tailscale on → Tailscale IP editable, server host read-only.
  - Tailscale off → server host editable, Tailscale IP read-only.
  - The inactive Pi-user field is disabled as well.
- A footer explains the active mode and how to edit the other address.
- Appearance, refresh, history, maintenance, visibility, general and about are
  now native sections instead of custom cards.

## Upgrade

```shell
brew upgrade --cask server-fo
```

The server is still offline, so live container/vitals data will appear once it
is back on `192.168.1.22` (or the new address you set while direct mode is on).
