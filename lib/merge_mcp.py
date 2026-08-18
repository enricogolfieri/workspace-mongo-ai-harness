#!/usr/bin/env python3
"""Merge catalog MCP servers into an existing harness config.

The config file is parsed and missing servers are injected. Existence of the
file is not a skip — only an existing server *name* is skipped unless --force.
Other keys and servers are left intact. No tokens are written.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


def load_catalog(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    servers = data.get("mcpServers")
    if not isinstance(servers, dict) or not servers:
        raise SystemExit(f"catalog {path} has no mcpServers")
    return servers


def load_json(path: Path) -> dict[str, Any]:
    if not path.is_file() or path.stat().st_size == 0:
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise SystemExit(f"{path} is not a JSON object")
    return data


def dump_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def merge_map(
    dest: dict[str, Any],
    catalog: dict[str, Any],
    transform,
    force: bool,
) -> tuple[list[str], list[str]]:
    added: list[str] = []
    skipped: list[str] = []
    for name, spec in catalog.items():
        if name in dest and not force:
            skipped.append(name)
            continue
        dest[name] = transform(spec)
        added.append(name)
    return added, skipped


def identity(spec: dict[str, Any]) -> dict[str, Any]:
    return dict(spec)


def opencode_remote(spec: dict[str, Any]) -> dict[str, Any]:
    url = spec.get("url")
    if not url:
        raise SystemExit("catalog entry missing url")
    return {"type": "remote", "url": url, "enabled": True}


def merge_json_file(
    path: Path,
    key: str,
    catalog: dict[str, Any],
    transform,
    force: bool,
) -> tuple[list[str], list[str]]:
    data = load_json(path)
    bucket = data.get(key)
    if not isinstance(bucket, dict):
        bucket = {}
        data[key] = bucket
    added, skipped = merge_map(bucket, catalog, transform, force)
    if added:
        dump_json(path, data)
    return added, skipped


def toml_has_server(text: str, name: str) -> bool:
    # Match [mcp_servers.name] or [mcp_servers."name"]
    escaped = re.escape(name)
    pat = rf"(?m)^\[mcp_servers\.(?:{escaped}|\"{escaped}\")\]\s*$"
    return re.search(pat, text) is not None


def toml_section(name: str, spec: dict[str, Any]) -> str:
    url = spec.get("url")
    if not url:
        raise SystemExit("catalog entry missing url")
    header = f'[mcp_servers."{name}"]' if re.search(r"[^A-Za-z0-9_]", name) else f"[mcp_servers.{name}]"
    return f"\n{header}\nurl = {json.dumps(url)}\n"


def merge_toml_file(
    path: Path,
    catalog: dict[str, Any],
    force: bool,
) -> tuple[list[str], list[str]]:
    text = path.read_text(encoding="utf-8") if path.is_file() else ""
    if text and not text.endswith("\n"):
        text += "\n"
    added: list[str] = []
    skipped: list[str] = []
    pieces: list[str] = []
    for name, spec in catalog.items():
        if toml_has_server(text, name) and not force:
            skipped.append(name)
            continue
        if toml_has_server(text, name) and force:
            # Drop the existing table so we can append a replacement.
            text = re.sub(
                rf"(?ms)^\[mcp_servers\.(?:{re.escape(name)}|\"{re.escape(name)}\")\]\s*\n(?:[^[\n][^\n]*\n)*",
                "",
                text,
            )
        pieces.append(toml_section(name, spec))
        added.append(name)
    if added:
        path.parent.mkdir(parents=True, exist_ok=True)
        body = text.rstrip() + "\n" + "".join(pieces)
        path.write_text(body.lstrip("\n") if not path.is_file() else body, encoding="utf-8")
    return added, skipped


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--harness", required=True, choices=["cursor", "claude", "opencode", "codex"])
    p.add_argument("--file", required=True)
    p.add_argument("--catalog", required=True)
    p.add_argument("--force", action="store_true")
    args = p.parse_args()

    catalog = load_catalog(Path(args.catalog))
    dest = Path(args.file)

    if args.harness in ("cursor", "claude"):
        added, skipped = merge_json_file(dest, "mcpServers", catalog, identity, args.force)
    elif args.harness == "opencode":
        added, skipped = merge_json_file(dest, "mcp", catalog, opencode_remote, args.force)
    else:
        added, skipped = merge_toml_file(dest, catalog, args.force)

    for name in added:
        print(f"  added {name}")
    for name in skipped:
        print(f"  exists {name} (skip; use --force to replace)")
    if not added and not skipped:
        print("  nothing to do")
    return 0


if __name__ == "__main__":
    sys.exit(main())
