cask "dodotidy" do
  version "1.0.3"
  sha256 "9a732b7c4044b62831548be13342a11f4e037502b9280bb477373990d65b843f"

  url "https://github.com/bluewave-labs/DodoTidy/releases/download/v#{version}/DodoTidy-#{version}.dmg"
  name "DodoTidy"
  desc "macOS system cleaner and disk analyzer"
  homepage "https://github.com/bluewave-labs/DodoTidy"

  # Requires macOS 14.0 Sonoma or later
  depends_on macos: ">= :sonoma"

  app "DodoTidy.app"

  zap trash: [
    "~/Library/Preferences/com.dodotidy.app.plist",
  ]

  caveats <<~EOS
    DodoTidy is not notarized. On first launch, you may need to:
    1. Right-click the app and select "Open"
    2. Click "Open" in the security dialog

    Or run: xattr -cr /Applications/DodoTidy.app
  EOS
end
