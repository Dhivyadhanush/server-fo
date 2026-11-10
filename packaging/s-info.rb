cask "s-info" do
  version "__VERSION__"
  sha256 "__SHA__"

  url "https://github.com/Dhivyadhanush/s-info/releases/download/v#{version}/S-Info.zip"
  name "S-Info"
  desc "Menu bar Docker and server monitor with 30-day history and apt upgrades"
  homepage "https://github.com/Dhivyadhanush/s-info"

  depends_on macos: :sonoma

  app "S-Info.app"

  # Ad-hoc signed, so Gatekeeper cannot verify it. macOS 27 refuses to run a
  # quarantined copy (the "Not Opened" dialog offers to move it to the Trash),
  # so clear the download flag the same way --no-quarantine would.
  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "#{appdir}/S-Info.app"]
  end

  uninstall quit: "dev.dhanuz.s-info"

  zap trash: [
    "~/Library/Application Support/S-Info",
    "~/Library/LaunchAgents/dev.dhanuz.s-info.plist",
    "~/Library/Preferences/dev.dhanuz.s-info.plist",
  ]
end
