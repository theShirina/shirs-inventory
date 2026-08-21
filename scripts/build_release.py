#!/usr/bin/env python3
"""Build a deterministic Shir's Inventory release ZIP."""

from __future__ import annotations

import argparse
import re
import stat
import zipfile
from pathlib import Path

FIXED_TIME = (2020, 1, 1, 0, 0, 0)
ADDON_FILES = (
    "Bindings.lua",
    "Bindings.xml",
    "CREDITS.md",
    "ShirsInventory.toc",
    "ShirsInventoryAccount.lua",
    "ShirsInventoryCore.lua",
    "ShirsInventoryJunk.lua",
    "ShirsInventorySettings.lua",
    "ShirsInventorySortEngine.lua",
    "ShirsInventorySpecialtyItems.lua",
    "ShirsInventorySorter.lua",
    "ShirsInventoryUI.lua",
    "THIRD_PARTY_NOTICES.md",
)


def normalized(path: Path) -> bytes:
    return path.read_text(encoding="utf-8").replace("\r\n", "\n").replace("\r", "\n").encode("utf-8")


def member(name: str, data: bytes) -> tuple[zipfile.ZipInfo, bytes]:
    info = zipfile.ZipInfo(name, FIXED_TIME)
    info.compress_type = zipfile.ZIP_DEFLATED
    info.create_system = 3
    info.external_attr = (stat.S_IFREG | 0o644) << 16
    return info, data


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path)
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    addon = root / "addon" / "ShirsInventory"
    actual = tuple(sorted(path.name for path in addon.iterdir() if path.is_file()))
    expected = tuple(sorted(ADDON_FILES))
    if actual != expected:
        raise SystemExit(f"Unexpected addon files: expected {expected!r}, found {actual!r}")

    toc = normalized(addon / "ShirsInventory.toc").decode("utf-8")
    match = re.search(r"^## Version:\s*(\S+)\s*$", toc, re.MULTILINE)
    if not match:
        raise SystemExit("Version missing from ShirsInventory.toc")
    version = match.group(1)
    if version.endswith("-test"):
        raise SystemExit("Refusing to publish a test-version archive")

    readme = f"""Shir's Inventory {version}

Made and tested for a WoW 1.12 client.

INSTALL
1. Extract the ShirsInventory folder into Interface/AddOns.
2. Restart the client.
3. Open your bags. The combined inventory, sorter, and junk tools load as one suite.

Source and updates:
https://github.com/theShirina/shirs-inventory
""".encode("utf-8")

    entries: list[tuple[str, bytes]] = []
    for filename in ADDON_FILES:
        entries.append((f"ShirsInventory/{filename}", normalized(addon / filename)))
    entries.append(("ShirsInventory/LICENSE.txt", normalized(root / "LICENSE")))
    entries.append(("ShirsInventory/README.txt", readme))
    entries.sort(key=lambda item: item[0])

    output_dir = args.output_dir or root / "dist"
    output_dir.mkdir(parents=True, exist_ok=True)
    output = output_dir / f"ShirsInventory-v{version}.zip"
    temporary = output.with_suffix(".zip.tmp")
    with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in entries:
            info, payload = member(name, data)
            archive.writestr(info, payload, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    temporary.replace(output)
    print(output)


if __name__ == "__main__":
    main()
