# PassPouch — Rules for AI Agents

## Project

PassPouch = open-source KeePass-compatible password manager for iOS (based on KeePassium, GPLv3; upstream: https://github.com/keepassium/KeePassium; our repo: https://github.com/alzimerahmed/PassPouch, owner: Alzimer Ahmed <alzimerahmed84@gmail.com>). Inherits the KeePassium feature set: KDBX 3/4 databases, automatic sync with cloud storage (iCloud Drive, Dropbox, OneDrive, Google Drive, Box, Nextcloud, SFTP), Password AutoFill extension, App/data protection, multiple databases, attachments. Differentiation: clean PassPouch branding, privacy-first, no telemetry.

**License:** GPLv3. Upstream `LICENSE.txt` must be preserved — GPLv3 does not permit relicensing. Our additions carry our copyright notice; upstream copyright stays in LICENSE.txt and source headers where required.

**Scope:** Native iOS app only (Swift, UIKit, Xcode) — main app + AutoFill extension + KeePassiumLib framework. No web client, no Android. All verification is CI-only (see Build/Verify).

## How It Works (domain constraints — read before touching the code)

- **`KeePassiumLib/`** is the core framework: KDBX parsing/crypto (KeePassiumLib/KeePassiumLib), its own Xcode project, unit tests inside the framework target. Database format logic lives here — treat it as the trusted core.
- **`KeePassium/`** is the main app: UIKit + storyboards/xibs, `database/`, `remote-files/` (cloud providers), `premium/` (freemium logic), `settings/`, `challenge-response/`, localization in `*.lproj` folders.
- **`KeePassium AutoFill/`** is the system AutoFill credential provider extension.
- **`KeePassiumTests/`** — app-level tests.
- **`scripts/generate-password-rules.swift`** — codegen for password rules; regenerate, don't hand-edit output.
- **`appconfig-specfile.xml`** — managed-app (EMM/Intune) configuration schema.
- **Localization**: `*.lproj` folders across targets — generated/imported strings are not hand-edited casually; new user-facing strings go in `en.lproj` first.
- **Premium/monetization**: upstream freemium logic (`premium/`, `Configuration.storekit`) — Phase plan decides whether to keep, strip, or neutralize; never ship IAP under PassPouch branding without an explicit phase decision.

## Tech Stack & Conventions (do not fight it)

- **Swift / UIKit**, iOS 17+ deployment target, Xcode project (`KeePassium.xcodeproj` + workspace with KeePassiumLib).
- **SwiftLint** (`.swiftlint.yml`) — respect existing rules.
- **Commits**: Conventional Commits (`type(scope): description`); upstream history style is irrelevant — this repo has fresh history.
- **Bundle identity**: PassPouch branding (`com.passpouch.*` bundle IDs, display name PassPouch) is a planned phase — CI-verified; never change ad hoc. Target/scheme/directory names (`KeePassium*`) remain upstream-named for stability until the rename phase.

## Build / Verify

```bash
# CI (GitHub Actions, .github/workflows/ — PR to master + manual):
#   checks.yml   — macOS runner: xcodebuild build + unit tests (KeePassiumLib + app), SwiftLint
#   test.yml     — calls checks.yml on PRs
```

**Remote-first verification (mandatory):** we do NOT build or test locally — this workspace is Windows and all builds/tests run in GitHub Actions (macOS runner). Local work is edit-only: static review while iterating. Push and let CI verify; a CI green check counts as the gate.

**Signing:** CI runs build + tests only (no signing, no archives, no App Store distribution). Never hardcode signing material; distribution workflows are out of scope until a Release phase adds them with secrets.

## Removed on Purpose — Do NOT Re-add

- Upstream monetization endpoints: PayPal/Revolut/crypto donation links, sponsor badges, keepassium.com purchase/pricing links — replaced with PassPouch identity.
- Upstream badges/links to keepassium.com App Store listing — replaced with PassPouch identity.
- Secret-dependent distribution workflows — none exist; do not add ones requiring secrets we don't have.

## Gotchas

- **No local build safety net** — grep all references (project.pbxproj, workspace, entitlements, Info.plist, workflows) before deleting or renaming anything.
- **`project.pbxproj` is fragile** — prefer xcconfig/SwiftPM-level changes where possible; verify in CI.
- **Generated/licensing files**: `KeePassiumLib/.../licensing/v1-proofs.sha256` is gitignored upstream — do not commit regenerated proofs without understanding them.
- **Premium code paths** touch many screens — stripping freemium is a planned phase, not an ad-hoc edit.
- **Windows checkout**: symlinks and case-sensitive paths can be hostile; avoid `git clean -fdx`.
- **GPLv3**: no proprietary additions; third-party deps must stay GPLv3-compatible.

## Agent Guidelines & Constraints

### Do's
- **Write tests** for new behavior (XCTest in `KeePassiumTests/` or KeePassiumLib tests); run in CI only.
- **Conventional Commits** for our changes.
- **Respect module boundaries** — app logic in `KeePassium/`, database format logic in `KeePassiumLib/`.
- **Plan discipline** — `docs/plan.md` must contain a Quality Gate phase and a Release phase. Every `idea.md` Feature Gap entry maps to a phase or is explicitly deferred. When a phase answers an open question in `docs/research.md`, close it there in the same change.

### Don'ts
- **NO local builds or test runs** — verification is CI-only (user directive; Windows host).
- **NO secrets in code** — signing keys via CI secrets only; none exist yet.
- **NO new heavy dependencies** without a decision record in `docs/research.md` (license must stay GPLv3-compatible).
- **NO deleting resources** without grepping all reference types (pbxproj, Info.plist, entitlements, workflows).
- **NO renaming bundle IDs/product names ad hoc** — that is a planned phase, CI-verified.

## Agent Guidelines & Workflow (this repo's .devin system)

### Resource Discipline (mandatory, non-trivial tasks)
Before any non-trivial task:
1. Read `docs/toolset.md` intent-map (task type → resources)
2. Invoke every skill + sub-agent in that row
3. Read every rule for that task type (`.devin/rules/`)
4. At task end: `code-reviewer` sub-agent on final diff (non-negotiable)
5. Append learnings via `/ce-compound` if durable lesson

Phase implementations (task completes a docs/plan.md row): follow `.devin/prompt/phase.md`.

Skip all this for single-line edits, pure Q&A, reading files.

### Project-Type Filter (native iOS password manager)
Per `docs/toolset.md` intent-map:
- **Skip web-only:** pwa-engineer, seo-specialist (web), css-architect, playwright-design-clone, web-scraper, monorepo-manager, backend-architect (no server), payment-integrator (no IAP in scope), email-engineer, realtime-engineer, search-optimization.
- **Keep universal:** code-reviewer, debugger, test-engineer, security-auditor, performance-engineer, git-master, migration-specialist, docs-writer, build-optimizer, devops-engineer, dx-optimizer, caveman-compressor, vibe-coding-auditor, i18n-specialist, media-optimizer, animation-engineer, frontend-designer (native UI taste), content-writer, database-engineer (KDBX/persistence), search-architect (in-app search), state-manager, type-safety-engineer, file-handler (attachments/imports), pixel-analyst.
- **Quality gates:** CI-only — xcodebuild tests on macOS GitHub Actions. No local builds.

## Communication Style

Default **caveman-lite** (lightly compressed, readable, technically accurate). `/caveman` skill for full/ultra/wenyan modes.

## Quick Task Flow

Quick tasks: `.devin/prompt/quick.md` (commandments) + `.devin/prompt/rules.md` (scoping, verification, escalation). Phased work: `.devin/prompt/phase.md`.

## Key References

> Note: `docs/*.md` files below are the private knowledge layer (gitignored) — they exist only in the local workspace, not for external cloners.

- `docs/toolset.md` — intent map (task type → skills, sub-agents, rules)
- `docs/plan.md` — phased plan + status
- `docs/project.md` — project state/structure
- `docs/tools-log.md` — .devin resources invoked per session
- `docs/CONCEPTS.md` — project vocabulary
- `docs/research.md` — research, ADRs, gotchas, open questions
- `docs/idea.md` — competitive analysis + Feature Gap List
- `docs/design/design-system.md` — UI tokens + rules
