#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
swift build -c release
mkdir -p dist/Intent.app/Contents/MacOS dist/Intent.app/Contents/Resources
cp .build/release/Intent dist/Intent.app/Contents/MacOS/Intent
cp Resources/Info.plist dist/Intent.app/Contents/Info.plist
for bundle in .build/release/*.bundle(N); do
    cp -R "$bundle" dist/Intent.app/Contents/Resources/
    cp -R "$bundle" dist/Intent.app/Contents/MacOS/
done
xattr -cr dist/Intent.app
/usr/bin/python3 scripts/sign_app.py
print "Built: $PWD/dist/Intent.app"
