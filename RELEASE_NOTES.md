# S-Info 1.1.0

A visual overhaul with real controls over what the panel shows, plus a server
RAM cache action.

## New

- **Themed UI.** Gradient canvas, subtle grid, glass cards, glow accents,
  animated tab pills and rebuilt metric tiles, charts, container rows and
  history timeline.
- **System / Light / Dark.** Follows macOS by default; force either appearance
  in Settings → Appearance. Every colour adapts.
- **What is visible.** Choose the status pill, hostname, footer, menu bar dot
  and count, the History and Updates tabs, every container-row field, detail
  metrics/charts/mounts, history events, package list, activity log and the
  cache action. Hidden data stays recorded; only the UI changes. "Show
  everything" resets it.
- **RAM cache.** Sync and drop the server's clean page cache (page cache,
  dentries, inodes) with a confirmation, last-cleared time and logged output.
  Applications keep their memory and nothing restarts.
- **New icon.** The Dock icon is now the same two-unit rack as the menu bar
  glyph, generated from one shape.

## Commands

```shell
sudo apt update && sudo apt upgrade -y                     # every 30 days
sudo -n sh -c 'echo 3 > /proc/sys/vm/drop_caches'          # RAM cache
```

Both are logged locally for 30 days. Neither reboots the server.

## Install / upgrade

```shell
brew tap Dhivyadhanush/tap
brew trust Dhivyadhanush/tap
brew install --cask s-info
# or
brew upgrade --cask s-info
```

macOS 14+, key-based SSH, passwordless sudo for the two maintenance actions.
Ad-hoc signed, not notarised.
