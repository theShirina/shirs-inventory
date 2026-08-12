#!/usr/bin/env python3
"""Verify the shipped specialty item tables against pinned BagFamily evidence."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: verify_specialty_items.py EVIDENCE_JSON SPECIALTY_LUA")

    evidence_path = Path(sys.argv[1])
    lua_path = Path(sys.argv[2])
    evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
    lua = lua_path.read_text(encoding="utf-8")

    expected = {
        "herb": {row["id"] for row in evidence["items"] if row["family"] == 6},
        "enchanting": {row["id"] for row in evidence["items"] if row["family"] == 7},
    }

    def table_ids(table_name: str) -> set[int]:
        match = re.search(
            rf"local {table_name} = \{{(.*?)\n\}}",
            lua,
            flags=re.DOTALL,
        )
        if not match:
            raise SystemExit(f"missing Lua table: {table_name}")
        return {int(value) for value in re.findall(r"\[(\d+)\]\s*=\s*true", match.group(1))}

    actual = {
        "herb": table_ids("herbBagItemIDs"),
        "enchanting": table_ids("enchantingBagItemIDs"),
    }

    for family in ("herb", "enchanting"):
        missing = sorted(expected[family] - actual[family])
        extra = sorted(actual[family] - expected[family])
        if missing or extra:
            raise SystemExit(
                f"{family} table mismatch: missing={missing} extra={extra}"
            )

    overlap = actual["herb"] & actual["enchanting"]
    if overlap:
        raise SystemExit(f"IDs present in both specialty tables: {sorted(overlap)}")

    if evidence["counts"] != {
        "herb": len(actual["herb"]),
        "enchanting": len(actual["enchanting"]),
    }:
        raise SystemExit("evidence counts do not match item records")

    print(f"SPECIALTY_HERB_IDS={len(actual['herb'])}")
    print(f"SPECIALTY_ENCHANTING_IDS={len(actual['enchanting'])}")
    print("SPECIALTY_ITEM_TABLES=PASS")


if __name__ == "__main__":
    main()
