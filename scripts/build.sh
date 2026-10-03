#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
swift build -c release
# Sign outside iCloud Documents, where file-provider Finder metadata races signing.
stage=$(mktemp -d "${TMPDIR:-/tmp}/intent-build.XXXXXX")
trap 'rm -rf "$stage"' EXIT
app="$stage/Intent.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/Intent "$app/Contents/MacOS/Intent"
cp Resources/Info.plist "$app/Contents/Info.plist"
for bundle in .build/release/*.bundle(N); do
    ditto --norsrc --noextattr "$bundle" "$app/Contents/Resources/${bundle:t}"
    ditto --norsrc --noextattr "$bundle" "$app/Contents/MacOS/${bundle:t}"
done
/usr/bin/python3 scripts/sign_app.py "$app"
mkdir -p dist
installed="$HOME/Applications/Intent.app"
if [[ -e "$installed" ]]; then
    identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$installed/Contents/Info.plist")
    [[ "$identifier" == "dev.vedant.intent" ]] || { print -u2 "Refusing to replace an unrelated app at $installed"; exit 1; }
fi
mkdir -p "$HOME/Applications"
rm -rf "$installed"
ditto --norsrc --noextattr "$app" "$installed"
codesign --verify --deep --strict "$installed"
rm -rf dist/Intent.app
ln -s "$installed" dist/Intent.app
print "Built: $installed (also available through $PWD/dist/Intent.app)"
