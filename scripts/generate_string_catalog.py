#!/usr/bin/env python3
"""Builds RoundUpSaver/Resources/Localizable.xcstrings from the compiler's extracted strings.

Usage: build the app once (SWIFT_EMIT_LOC_STRINGS=YES is set on the app target), then run
    python3 scripts/generate_string_catalog.py
Xcode keeps the catalog in sync automatically when building from the IDE; this script exists
so the catalog can also be regenerated from the command line / CI.
"""
import glob
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(ROOT, "RoundUpSaver", "Resources", "Localizable.xcstrings")
DERIVED = os.path.expanduser(
    "~/Library/Developer/Xcode/DerivedData/RoundUpSaver-*/Build/Intermediates.noindex/"
    "RoundUpSaver.build/Debug-iphonesimulator/RoundUpSaver.build/Objects-normal/*/*.stringsdata"
)
# Stub data for UI tests and previews is never shown to customers
EXCLUDED_SOURCES = {"UITestingDependencies.swift"}

keys = {}
for path in glob.glob(DERIVED):
    with open(path) as handle:
        data = json.load(handle)
    if os.path.basename(data.get("source", "")) in EXCLUDED_SOURCES:
        continue
    for entry in data.get("tables", {}).get("Localizable", []):
        keys.setdefault(entry["key"], entry.get("comment") or "")

if not keys:
    raise SystemExit("No extracted strings found. Build the app first.")

existing = {}
if os.path.exists(CATALOG):
    with open(CATALOG) as handle:
        existing = json.load(handle).get("strings", {})

strings = {}
for key in sorted(keys):
    entry = dict(existing.get(key, {}))
    # Pure format strings (e.g. "%@%@" for a sign and an amount) have nothing to translate
    if not re.search(r"[A-Za-z]", re.sub(r"%(\d+\$)?(lld|@|ld|d|f)", "", key)):
        entry["shouldTranslate"] = False
    if keys[key]:
        entry["comment"] = keys[key]
    strings[key] = entry

os.makedirs(os.path.dirname(CATALOG), exist_ok=True)
with open(CATALOG, "w") as handle:
    json.dump({"sourceLanguage": "en", "strings": strings, "version": "1.0"}, handle, indent=2, sort_keys=True)
    handle.write("\n")

print(f"Wrote {len(strings)} strings to {os.path.relpath(CATALOG, ROOT)}")
