# S-Info 1.0.3

The final polish release for 1.0.

## Fix

- **Update checks now match the toggle.** Settings showed "Check GitHub for
  updates" as on, but the store read an unset preference as off, so a fresh
  install never asked GitHub for a newer release. An absent key now means
  enabled. Everything from 1.0.2 (correct minute-based sampling) and 1.0.1
  (Quit safety) is included.

## Install / upgrade

```shell
brew tap Dhivyadhanush/tap
brew trust Dhivyadhanush/tap
brew install --cask s-info
# or, from an earlier version:
brew upgrade --cask s-info
```

macOS 14+, key-based SSH, passwordless sudo for the scheduled upgrade.
Ad-hoc signed, not notarised.
