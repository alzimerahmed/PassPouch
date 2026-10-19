# PassPouch — KeePass-compatible password manager for iOS

<div align="center">

![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-blue)
![Language](https://img.shields.io/badge/language-Swift-orange)
![UI](https://img.shields.io/badge/UI-UIKit%20%2B%20SwiftUI-lightgrey)
![License](https://img.shields.io/badge/license-GPL--3.0-green)
[![CI](https://github.com/alzimerahmed/PassPouch/actions/workflows/test.yml/badge.svg)](https://github.com/alzimerahmed/PassPouch/actions/workflows/test.yml)
[![Release](https://img.shields.io/github/v/release/alzimerahmed/PassPouch)](https://github.com/alzimerahmed/PassPouch/releases)

*Open-source, KeePass-compatible password manager for iOS — your passwords, your files, no accounts, no tracking.*

[Download](https://github.com/alzimerahmed/PassPouch/releases) • [Features](#features) • [Building](#building) • [License](#license)

</div>

---

## Features

- **KDBX 3 / KDBX 4** databases (read/write), read-only legacy KDB — full KeePass compatibility
- **Cloud sync through iOS file providers** — iCloud Drive, Dropbox, OneDrive, Google Drive, Box, Nextcloud, SFTP apps — credentials never pass through PassPouch
- **Direct WebDAV backend** with ETag conflict protection (conditional writes, no silent overwrites)
- **Password AutoFill extension** — system-wide autofill, QuickType inline suggestions, TOTP autofill, quick unlock
- **Strong crypto** — Argon2, ChaCha20, AES, Twofish, Salsa20; YubiKey challenge-response support
- **Passkeys in KDBX** — view entries' passkeys, WebAuthn assertion in AutoFill, Bitwarden `fido2Credentials` import
- **Breach check (HIBP)** — opt-in, k-anonymity model: only a 5-char SHA-1 prefix leaves the device
- **Encrypted share links** — `passpouch://` links carry an AES-256-GCM-encrypted snapshot; the key stays in the URL fragment and nothing touches a server
- **Emergency access** — offline Shamir secret sharing (M-of-N) of your master password plus a printable Emergency Kit PDF
- **CSV import wizard** — auto-detects 1Password, Bitwarden, Apple Passwords, Chrome/Edge, Firefox exports
- **Apple Watch companion** — opt-in per-entry snapshots with live TOTP, wiped when the phone locks
- **Widgets, App Intents, Siri Shortcuts**, QR TOTP scanning, attachments, custom fields and icons
- **AppLock** — Face ID / Touch ID / passcode, database lock and clipboard-clearing timeouts
- **Free and open source** — no ads, no tracking, no telemetry, no premium tier, no paywall

## Install

PassPouch is distributed as an unsigned IPA on the [Releases](https://github.com/alzimerahmed/PassPouch/releases) page. Install it with a tool that signs it using your own Apple ID:

- [AltStore](https://altstore.io) or [SideStore](https://sidestore.io) — add the downloaded IPA from the Files app
- [Sideloadly](https://sideloadly.io) — drag the IPA in and sign with your Apple ID

Free Apple ID signatures expire after 7 days; AltStore and SideStore can refresh automatically. PassPouch is not on the App Store — see [ADR-018](docs/research.md) for why (GPL distribution terms).

## Tech Stack

| Layer | Technology |
|-------|------------|
| UI | UIKit (existing surface) + SwiftUI (new screens) |
| Database format | KDBX 3 / KDBX 4 (KeePassiumLib framework) |
| Crypto | Argon2, ChaCha20, Salsa20, Twofish, AES, CryptoKit AES-GCM, GF(256) Shamir |
| Extensions | AutoFill credential provider, WidgetKit, watchOS 10 companion |
| macOS | Mac Catalyst (quick-access window) |
| CI | GitHub Actions (macos-26, Xcode 26): SwiftLint + build + XCTest |

## Project Structure

```
PassPouch/
├── KeePassium.xcworkspace/   # Open this in Xcode
├── KeePassium/               # Main app (UI, remote files, settings, watch sharing)
├── KeePassium AutoFill/      # AutoFill credential provider extension
├── KeePassiumLib/            # Core framework: Core/ Sync/ Premium/ UI/ boundaries
├── PassPouchWatch/           # watchOS companion app
├── PassPouchWidgets/         # Home-screen widgets
├── KeePassiumTests/          # Unit tests
├── KeePassiumUITests/        # UI smoke tests
├── scripts/                  # Build and l10n tooling
├── LICENSE.txt               # GPLv3
└── README.md
```

## Building

1. `git clone https://github.com/alzimerahmed/PassPouch.git`
2. Open `KeePassium.xcworkspace` in Xcode 26 or later — all dependencies are vendored/included.
3. Select the **KeePassium** scheme and an iOS 17+ simulator or device, then press `Cmd+R`.

CI runs SwiftLint, a full build, and the unit + UI smoke test suites on every push and pull request to `master`. Pushing a `v*` tag builds an unsigned IPA and publishes it on the Releases page automatically.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feat/my-feature`)
3. Open a pull request against `master`

Use [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, …) for commit messages. Bug reports and feature suggestions go to [GitHub Issues](https://github.com/alzimerahmed/PassPouch/issues).

## Roadmap

- [x] Full PassPouch rebrand (identity, bundle IDs, icon)
- [x] Home-screen widgets, App Intents, Siri Shortcuts
- [x] TOTP autofill + QuickType inline suggestions
- [x] CSV import wizard
- [x] Passkey support + Bitwarden passkey import
- [x] Breach check (HIBP k-anonymity)
- [x] Apple Watch companion
- [x] Encrypted share links + emergency access (Shamir)
- [x] macOS quick-access window
- [ ] Signed builds (blocked on Apple Developer account)
- [ ] Native SFTP transport (deferred — use an SFTP file-provider app meanwhile)
- [ ] App Store / TestFlight distribution (blocked on developer account + GPL review)

## Changelog

See [GitHub Releases](https://github.com/alzimerahmed/PassPouch/releases) for version notes; in-app history is under Settings → App History.

## License

PassPouch is released under the [GNU General Public License v3.0](LICENSE.txt).

PassPouch is based on [KeePassium](https://github.com/keepassium/KeePassium), created by Andrei Popleteev / KeePassium Labs. Upstream code remains Copyright ©2018–2025 Andrei Popleteev, KeePassium Labs, and retains its original copyright attribution as required by the GPL.

PassPouch modifications Copyright ©2026 Alzimer Ahmed.
