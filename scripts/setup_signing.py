#!/usr/bin/python3
"""Create an app-specific local signing identity; never change system trust."""
import os
import secrets
import shlex
import subprocess
import tempfile
from pathlib import Path

NAME = "Intent Local Development"
ROOT = Path.home() / "Library/Application Support/IntentSigning"
KEYCHAIN = ROOT / "intent-signing.keychain-db"
PASSWORD = ROOT / "keychain-password"


def run(*args):
    return subprocess.run(args, check=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout


def main():
    os.umask(0o077)
    ROOT.mkdir(parents=True, exist_ok=True)
    ROOT.chmod(0o700)
    if KEYCHAIN.exists() and PASSWORD.exists() and (ROOT / "certificate.pem").exists():
        print("Local signing identity already exists.")
        return
    if KEYCHAIN.exists() or PASSWORD.exists() or (ROOT / "certificate.pem").exists():
        raise RuntimeError("Incomplete signing setup. Preserve the existing files and repair the setup before continuing.")
    password = secrets.token_urlsafe(32)
    PASSWORD.write_text(password)
    # create-keychain adds to the search list. Restore it immediately so other
    # projects and the login keychain retain their original configuration.
    previous = shlex.split(run("/usr/bin/security", "list-keychains", "-d", "user"))
    try:
        run("/usr/bin/security", "create-keychain", "-p", password, str(KEYCHAIN))
    finally:
        run("/usr/bin/security", "list-keychains", "-d", "user", "-s", *previous)
    run("/usr/bin/security", "set-keychain-settings", "-lut", "21600", str(KEYCHAIN))
    run("/usr/bin/security", "unlock-keychain", "-p", password, str(KEYCHAIN))
    with tempfile.TemporaryDirectory(prefix="intent-signing-") as temp:
        folder = Path(temp)
        config = folder / "certificate.cnf"
        config.write_text("""[req]
distinguished_name = name
x509_extensions = codesign
prompt = no
[name]
CN = Intent Local Development
[codesign]
basicConstraints = critical,CA:TRUE,pathlen:0
keyUsage = critical,digitalSignature,keyCertSign
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
""")
        private = folder / "private.pem"
        certificate = folder / "certificate.pem"
        archive = folder / "identity.p12"
        passfile = folder / "archive-password"
        passfile.write_text(password)
        run("/usr/bin/openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "3650",
            "-keyout", str(private), "-out", str(certificate), "-config", str(config))
        run("/usr/bin/openssl", "pkcs12", "-export", "-inkey", str(private), "-in", str(certificate),
            "-name", NAME, "-out", str(archive), "-passout", "file:" + str(passfile))
        run("/usr/bin/security", "import", str(archive), "-k", str(KEYCHAIN), "-P", password,
            "-T", "/usr/bin/codesign")
        run("/usr/bin/security", "set-key-partition-list", "-S", "apple-tool:,codesign:", "-s", "-k", password, str(KEYCHAIN))
        # Keep only the public certificate alongside the encrypted keychain.
        (ROOT / "certificate.pem").write_bytes(certificate.read_bytes())
    print("Created Intent's reusable signing identity in its dedicated local keychain.")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        # Do not print command arguments, which may include generated passwords.
        raise SystemExit("Signing setup failed: " + error.stderr.strip())
