# S-Info 1.0.2

A history sampling fix.

## Fix

- **Sample interval is now really in minutes.** 1.0.1 read the "every 5 minutes"
  setting as five seconds and took a sample on every refresh (every 30 seconds
  by default). That meant about 46,000 rows a day instead of about 4,600. 1.0.2
  uses the chosen interval properly; the default is one sample per 5 minutes.
  Existing history is untouched and continues to age out at 30 days.

Everything from 1.0.1 is included: the Quit button, the guard that blocks
quitting while apt runs, and the current Homebrew cask.

## Install / upgrade

```shell
brew tap Dhivyadhanush/tap
brew trust Dhivyadhanush/tap
brew install --cask s-info
# or, from 1.0.1:
brew upgrade --cask s-info
```

Ad-hoc signed, not notarised. macOS 14+, key-based SSH, passwordless sudo for
the upgrade feature.
