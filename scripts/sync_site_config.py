#!/usr/bin/env python3
"""identity.json → site/config.json + 아이콘 복사. 표시 문자열은 identity가 출처."""
from __future__ import annotations

import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IDENTITY = ROOT / "Alog/Sources/MonitorKit/Resources/identity.json"
ICON = ROOT / "Alog/Resources/AppIcon-1024.png"
OUT = ROOT / "site"


def main() -> None:
    ident = json.loads(IDENTITY.read_text(encoding="utf-8"))
    owner = ident["githubOwner"]
    repo = ident["githubRepo"]
    github = f"https://github.com/{owner}/{repo}"
    config = {
        "displayName": ident["displayName"],
        "developerName": ident.get("developerName", ""),
        "copyright": ident.get("copyright", ""),
        "githubOwner": owner,
        "githubRepo": repo,
        "githubURL": github,
        "downloadURL": f"{github}/releases/latest/download/{ident['bundleFileName']}.dmg",
        "releasesURL": f"{github}/releases/latest",
        "minOS": "macOS 26",
    }
    (OUT / "config.json").write_text(
        json.dumps(config, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    if ICON.is_file():
        shutil.copyfile(ICON, OUT / "app-icon.png")
    print("wrote", OUT / "config.json")


if __name__ == "__main__":
    main()
