#!/usr/bin/env python3
"""PassPouch localization sanity check (Phase 9, ADR-011).

Validates the in-tree *.lproj/Localizable.strings tables without needing
Xcode (CI-runnable on any runner with Python):

  1. Every Localizable.strings parses (no duplicate keys, no syntax errors).
  2. All language tables use the same key set (no key dropped in translation).
  3. Format specifiers (%@, %d, %1$@ ...) match between the reference (en,
     taken from NSLocalizedString(value:) in code is not parseable here, so
     the largest table is used as reference) and each translation — the main
     pseudo-locale failure mode (crashes from specifier mismatches).

Exit code 0 = structurally clean (missing translations are warnings only,
because en strings live in code via NSLocalizedString(value:) and translations
are added via scripts/l10n-sync-upstream.py).

Usage: python3 scripts/l10n/l10n-check.py [repo_root]
"""
import re
import sys
from pathlib import Path

KEY_RE = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;\s*$')
SPEC_RE = re.compile(r"%(?:\d+\$)?[@dDuUxXoOfeEgGcCsSpaAF]")


def parse_strings_file(path: Path):
    """Returns (dict key->value, list of error strings)."""
    entries = {}
    errors = []
    text = path.read_text(encoding="utf-8")
    for lineno, line in enumerate(text.splitlines(), 1):
        stripped = line.strip()
        if not stripped or stripped.startswith("//") or stripped.startswith("/*"):
            continue
        m = KEY_RE.match(line)
        if not m:
            if '"' in line and "=" in line:
                errors.append(f"{path.name}:{lineno}: unparseable line: {stripped[:80]}")
            continue
        key, value = m.group(1), m.group(2)
        if key in entries:
            errors.append(f"{path.name}:{lineno}: duplicate key {key!r}")
        entries[key] = value
    return entries, errors


def specifiers(value: str):
    return sorted(SPEC_RE.findall(value))


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    lproj_dirs = sorted(root.glob("KeePassium/*.lproj"))
    tables = {}
    structural_errors = []

    for lproj in lproj_dirs:
        strings_path = lproj / "Localizable.strings"
        if not strings_path.exists():
            continue  # en.lproj: en strings live in code (NSLocalizedString value:)
        entries, errors = parse_strings_file(strings_path)
        structural_errors.extend(errors)
        tables[lproj.name] = entries

    if not tables:
        print("No Localizable.strings tables found")
        return 1

    # Reference = table with the most keys (closest to complete upstream set).
    reference_lang = max(tables, key=lambda lang: len(tables[lang]))
    reference = tables[reference_lang]
    print(f"Reference table: {reference_lang} ({len(reference)} keys)")

    missing = 0
    for lang, entries in sorted(tables.items()):
        if lang == reference_lang:
            continue
        absent = set(reference) - set(entries)
        extra = set(entries) - set(reference)
        for key in sorted(absent):
            print(f"MISSING  {lang}: {key}")
            missing += 1
        for key in sorted(extra):
            print(f"EXTRA    {lang}: {key}")
        for key in set(entries) & set(reference):
            if specifiers(entries[key]) != specifiers(reference[key]):
                print(
                    f"SPECIFIER MISMATCH {lang}: {key} "
                    f"{specifiers(entries[key])} != {specifiers(reference[key])}"
                )
                missing += 1

    for err in structural_errors:
        print(f"ERROR    {err}")

    print(
        f"Checked {len(tables)} tables, {len(reference)} keys; "
        f"{missing} missing/mismatched, {len(structural_errors)} structural errors"
    )
    return 1 if structural_errors else 0


if __name__ == "__main__":
    sys.exit(main())
