# Server-Fo 1.4.2

Login-item safety fix.

## Fixed

- A local development build could rewrite the login item to
  `~/s-info/.build/Server-Fo.app`. Removing that build then made launchd fail
  with `EX_CONFIG`. Only the installed `/Applications/Server-Fo.app` may repair
  the login item now.
- The LaunchAgent is verified to point at `/Applications/Server-Fo.app`.

This includes 1.4.1’s real `NSStatusItem` menu-bar item and ⌃⌥⌘S hotkey.

## Upgrade

```shell
brew upgrade --cask server-fo
```

The server itself is currently unreachable from the Pi, so the server widget
shows the connection state instead of host numbers until it is back.
