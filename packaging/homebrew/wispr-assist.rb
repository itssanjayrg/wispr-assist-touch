# Template for a Homebrew cask. Copy to your tap (homebrew-<tap>/Casks/wispr-assist.rb) and replace
# OWNER/REPO and the sha256 (printed by the release workflow) for each release.
cask "wispr-assist" do
  version "0.1.0"
  sha256 "REPLACE_WITH_DMG_SHA256"

  url "https://github.com/OWNER/REPO/releases/download/v#{version}/WisprAssist-#{version}.dmg"
  name "Wispr Assist"
  desc "Floating Globe and delete-line control for macOS text fields"
  homepage "https://github.com/OWNER/REPO"

  depends_on macos: ">= :ventura"

  app "Wispr Assist.app"

  zap trash: [
    "~/Library/Preferences/app.wisprassist.WisprAssist.plist",
    "~/Library/Logs/WisprAssist.log",
  ]
end
