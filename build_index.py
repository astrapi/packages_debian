#!/usr/bin/env python3
"""Generiert packages.json aus allen PKGBUILD-Unterordnern."""

import json
import re
from pathlib import Path

REPO_URL = "https://github.com/astrapi/packages_debian.git"


def parse_pkgbuild(path: Path) -> dict:
    text = path.read_text(errors="replace")

    def get(key):
        m = re.search(rf"^{key}=(.+)", text, re.MULTILINE)
        return m.group(1).strip().strip("'\"") if m else ""

    return {
        "name":         get("pkgname"),
        "pkgver":       get("pkgver"),
        "pkgrel":       get("pkgrel"),
        "pkgdesc":      get("pkgdesc"),
        "arch":         get("arch").strip("()").strip("'\""),
        "distribution": get("distribution"),
    }


def main():
    root = Path(__file__).parent
    packages = []

    for d in sorted(root.iterdir()):
        pkgbuild = d / "PKGBUILD"
        if not d.is_dir() or not pkgbuild.exists():
            continue
        meta = parse_pkgbuild(pkgbuild)
        if not meta["name"]:
            meta["name"] = d.name
        packages.append({
            "name":         meta["name"],
            "pkgver":       meta["pkgver"],
            "pkgrel":       meta["pkgrel"],
            "pkgdesc":      meta["pkgdesc"],
            "arch":         meta["arch"],
            "distribution": meta["distribution"],
            "subdir":       d.name,
            "git_url":      REPO_URL,
        })

    out = root / "packages.json"
    out.write_text(json.dumps(packages, indent=2, ensure_ascii=False) + "\n")
    print(f"packages.json: {len(packages)} Pakete geschrieben.")


if __name__ == "__main__":
    main()
