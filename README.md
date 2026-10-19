# PassPouch — KeePass-compatible password manager for iOS

<div align="center">

![Platform](https://img.shields.io/badge/platform-iOS-blue)
![Language](https://img.shields.io/badge/language-Swift-orange)
![License](https://img.shields.io/badge/license-GPL--3.0-green)
[![CI](https://github.com/alzimerahmed/PassPouch/actions/workflows/test.yml/badge.svg)](https://github.com/alzimerahmed/PassPouch/actions/workflows/test.yml)

Open-source, KeePass-compatible password manager for iOS — your passwords, your files, your rules.

[Features](#features) • [Building](#building) • [License](#license)

</div>

---

## Features

- Read/write support for KDBX 3 and KDBX 4 databases (plus read for legacy KDB)
- Automatic sync via iOS Files-app providers — iCloud Drive, Dropbox, OneDrive, Google Drive, Box, Nextcloud, SFTP, and more, with zero credential handoff to the app
- Password AutoFill extension (credential provider) for system-wide autofill
- AppLock with Face ID / Touch ID or passcode, plus database lock and clipboard clearing timeouts
- TOTP code viewing (RFC-6238 and Steam TOTP)
- File attachments, custom fields, and custom icons
- Easy switching between multiple databases
- YubiKey challenge-response support
- Accessibility-first UI built on UIKit
- No ads, no tracking, no premium tier — fully free and open source

## Screenshots

Screenshots coming soon — upstream image URLs were removed. Add your own PassPouch screenshots here.

## Tech Stack

| Layer | Technology |
|-------|------------|
| UI | UIKit / Swift |
| Crypto | Argon2, ChaCha20, Salsa20, Twofish, AES (CommonCrypto) |
| Database format | KDBX 3 / KDBX 4 |
| Extension | AutoFill credential provider |

## Project Structure

```
PassPouch/
├── KeePassium.xcworkspace/     # Open this in Xcode
├── KeePassium/                 # Main app target (UI, database handling)
├── KeePassium AutoFill/        # AutoFill credential provider extension
├── KeePassiumLib/              # Shared library code
├── KeePassiumTests/            # Unit tests
├── docs/                       # Documentation (local, not tracked)
├── scripts/                    # Build and tooling scripts
├── LICENSE.txt                 # GPLv3
└── README.md
```

## Building

1. Clone the repo:
   ```
   git clone https://github.com/alzimerahmed/PassPouch.git
   ```
2. Open `KeePassium.xcworkspace` in Xcode 16 or later. All dependencies are already included.
3. Select the **KeePassium** scheme and an iOS simulator, then press `Cmd+R`.

CI verification runs on GitHub Actions for every push and pull request.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feat/my-feature`)
3. Open a pull request against `master`

Please use [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, etc.) for commit messages. Bug reports and feature suggestions are welcome via [GitHub Issues](https://github.com/alzimerahmed/PassPouch/issues).

## Roadmap

- [ ] Full PassPouch rebrand (app identity, icons, naming)
- [ ] Home screen / lock screen widgets
- [ ] App Intents and Siri shortcuts
- [ ] TOTP autofill
- [ ] Database import wizard
- [ ] Breach monitoring
- [ ] Passkey support
- [ ] Apple Watch companion app

## License

PassPouch is released under the [GNU General Public License v3.0](LICENSE.txt).

PassPouch is based on [KeePassium](https://github.com/keepassium/KeePassium), created by Andrei Popleteev / KeePassium Labs. Upstream code remains Copyright ©2018–2025 Andrei Popleteev, KeePassium Labs, and retains its original copyright attribution as required by the GPL.

PassPouch modifications Copyright ©2026 Alzimer Ahmed.
