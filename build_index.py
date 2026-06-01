#!/usr/bin/env python3
"""Generiert packages.json aus allen debian/control-Unterordnern."""

import json
import re
from pathlib import Path

REPO_URL = "https://github.com/astrapi/packages_debian.git"


def parse_control(path: Path) -> dict:
    text = path.read_text(errors="replace")

    def get(key):
        m = re.search(rf"^{key}:\s*(.+)", text, re.MULTILINE | re.IGNORECASE)
        return m.group(1).strip() if m else ""

    return {
        "name":    get("Package"),
        "version": get("Version"),
        "arch":    get("Architecture"),
        "pkgdesc": get("Description"),
    }


def main():
    root = Path(__file__).parent
    packages = []

    for d in sorted(root.iterdir()):
        control = d / "debian" / "control"
        if not d.is_dir() or not control.exists():
            continue
        meta = parse_control(control)
        if not meta["name"]:
            meta["name"] = d.name
        packages.append({
            "name":    meta["name"],
            "version": meta["version"],
            "arch":    meta["arch"],
            "pkgdesc": meta["pkgdesc"],
            "subdir":  d.name,
            "git_url": REPO_URL,
        })

    out = root / "packages.json"
    out.write_text(json.dumps(packages, indent=2, ensure_ascii=False) + "\n")
    print(f"packages.json: {len(packages)} Pakete geschrieben.")


if __name__ == "__main__":
    main()
