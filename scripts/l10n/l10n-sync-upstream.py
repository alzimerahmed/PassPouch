#!/usr/bin/env python3
"""PassPouch L10n sync (Phase 9, ADR-011).

Folds upstream KeePassium-L10n translations into the in-tree *.lproj tables.
Upstream keeps translations in a separate repo (github.com/keepassium/KeePassium-L10n);
this script merges a local checkout of that repo into our KeePassium/*.lproj
folders so translations ship atomically with code. No network access: point it
at a local checkout.

For each key present in the upstream table for a language:
  - key absent in ours            -> add (new upstream translation)
  - key present in ours           -> upstream wins (fresh translation)
Keys only in ours are untouched (PassPouch-specific strings).

Usage:
  python3 scripts/l10n/l10n-sync-upstream.py /path/to/KeePassium-L10n [repo_root]
"""
import re
import shutil
import sys
from pathlib import Path

KEY_RE = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;\s*$')


def parse_strings_file(path: Path):
    entries = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        m = KEY_RE.match(line)
        if m:
            entries[m.group(1)] = m.group(2)
    return entries


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    upstream_root = Path(sys.argv[1])
    repo_root = Path(sys.argv[2]) if len(sys.argv) > 2 else Path.cwd()
    app_lproj_root = repo_root / "KeePassium"
    if not upstream_root.is_dir():
        print(f"Upstream checkout not found: {upstream_root}")
        return 2

    added = updated = 0
    for upstream_lproj in sorted(upstream_root.glob("*.lproj")):
        lang = upstream_lproj.name
        target_dir = app_lproj_root / lang
        target_file = target_dir / "Localizable.strings"
        upstream_file = upstream_lproj / "Localizable.strings"
        if not upstream_file.exists():
            continue
        upstream_entries = parse_strings_file(upstream_file)
        target_dir.mkdir(exist_ok=True)
        if target_file.exists():
            ours = parse_strings_file(target_file)
            merged = dict(ours)
            for key, value in upstream_entries.items():
                if key not in ours:
                    added += 1
                elif ours[key] != value:
                    updated += 1
                merged[key] = value
            lines = [f'"{k}" = "{v}";' for k, v in merged.items()]
            target_file.write_text("\n".join(lines) + "\n", encoding="utf-8")
        else:
            shutil.copyfile(upstream_file, target_file)
            added += len(upstream_entries)
            print(f"Created {lang}/Localizable.strings ({len(upstream_entries)} keys)")

    print(f"Sync complete: {added} keys added, {updated} updated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
