#!/usr/bin/python3
"""Sign Intent with its existing local identity, refusing ad-hoc fallback."""
import subprocess
from pathlib import Path

ROOT = Path.home() / "Library/Application Support/IntentSigning"
KEYCHAIN = ROOT / "intent-signing.keychain-db"
PASSWORD = ROOT / "keychain-password"
APP = Path(__file__).resolve().parent.parent / "dist/Intent.app"


def main():
    if not KEYCHAIN.exists() or not PASSWORD.exists():
        raise SystemExit("Run /usr/bin/python3 scripts/setup_signing.py once before building. Refusing ad-hoc signing because it invalidates permissions.")
    password = PASSWORD.read_text()
    try:
        subprocess.run(["/usr/bin/security", "unlock-keychain", "-p", password, str(KEYCHAIN)],
                       check=True, capture_output=True, text=True)
        subprocess.run(["/usr/bin/codesign", "--force", "--deep", "--sign", "Intent Local Development",
                        "--keychain", str(KEYCHAIN), "--timestamp=none", str(APP)], check=True)
        subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(APP)], check=True)
    except subprocess.CalledProcessError as error:
        raise SystemExit("Signing failed; no ad-hoc fallback was applied. " + (error.stderr or ""))


if __name__ == "__main__":
    main()
