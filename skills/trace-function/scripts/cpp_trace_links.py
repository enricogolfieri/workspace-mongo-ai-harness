#!/usr/bin/env python3
"""Static C++ link finder for trace-function skill.

This script only reads source files. It uses conservative regex heuristics to
surface candidate definitions, callers, callees, and branch gates. The agent
must still verify every final edge by reading source.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


CPP_EXTS = {
    ".c",
    ".cc",
    ".cpp",
    ".cxx",
    ".h",
    ".hh",
    ".hpp",
    ".hxx",
    ".ipp",
    ".inl",
}

SKIP_DIRS = {
    ".git",
    ".idea",
    ".vscode",
    "__pycache__",
    "bazel-bin",
    "bazel-mongo",
    "bazel-out",
    "bazel-testlogs",
    "build",
    "dist-test",
    "install",
    "node_modules",
    "python3-venv",
}

CONTROL_WORDS = {
    "alignas",
    "catch",
    "co_await",
    "co_return",
    "co_yield",
    "decltype",
    "delete",
    "for",
    "if",
    "new",
    "noexcept",
    "requires",
    "return",
    "sizeof",
    "switch",
    "throw",
    "while",
}

CAST_WORDS = {
    "const_cast",
    "dynamic_cast",
    "reinterpret_cast",
    "static_cast",
}

CALL_RE = re.compile(
    r"(?<![\w:~])(?P<name>(?:[A-Za-z_]\w*::)*(?:~?[A-Za-z_]\w*|operator[^\s(]+))\s*\("
)
BRANCH_RE = re.compile(
    r"\b(if|else\s+if|switch|case|default|return|throw|uassert|massert|invariant)\b"
)


@dataclass(frozen=True)
class SourceFile:
    path: Path
    relpath: str
    lines: list[str]


@dataclass(frozen=True)
class FunctionDef:
    name: str
    simple_name: str
    relpath: str
    line: int
    start_idx: int
    end_idx: int
    signature: str


@dataclass(frozen=True)
class CallSite:
    name: str
    simple_name: str
    relpath: str
    line: int
    text: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Find static C++ definition/call candidates for a function name."
    )
    parser.add_argument("function", help="Function name, e.g. foo or Class::foo")
    parser.add_argument("--root", default=".", help="Repository root or subtree to scan")
    parser.add_argument("--max-depth", type=int, default=3, help="Recursive callee depth")
    parser.add_argument(
        "--max-files",
        type=int,
        default=12000,
        help="Maximum C++ files to scan before stopping",
    )
    parser.add_argument(
        "--max-callees-per-func",
        type=int,
        default=40,
        help="Limit recursive expansion per function definition",
    )
    parser.add_argument("--json", action="store_true", help="Emit JSON instead of markdown")
    return parser.parse_args()


def clean_line(line: str) -> str:
    """Remove common single-line noise while preserving rough brace positions."""
    line = re.sub(r"//.*", "", line)
    line = re.sub(r'"(?:\\.|[^"\\])*"', '""', line)
    line = re.sub(r"'(?:\\.|[^'\\])*'", "''", line)
    return line


def iter_cpp_files(root: Path, max_files: int) -> tuple[list[Path], bool]:
    files: list[Path] = []
    truncated = False
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [
            d
            for d in dirnames
            if d not in SKIP_DIRS and not d.startswith("bazel-") and not d.startswith(".cache")
        ]
        for filename in filenames:
            path = Path(dirpath) / filename
            if path.suffix in CPP_EXTS:
                files.append(path)
                if len(files) >= max_files:
                    return sorted(files), True
    return sorted(files), truncated


def read_sources(root: Path, max_files: int) -> tuple[list[SourceFile], bool]:
    paths, truncated = iter_cpp_files(root, max_files)
    sources: list[SourceFile] = []
    for path in paths:
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        try:
            relpath = path.relative_to(root).as_posix()
        except ValueError:
            relpath = path.as_posix()
        sources.append(SourceFile(path=path, relpath=relpath, lines=text.splitlines()))
    return sources, truncated


def simple_name(name: str) -> str:
    tail = name.split("::")[-1]
    if tail.startswith("~"):
        return tail[1:]
    return tail


def is_probable_definition_start(line: str) -> bool:
    stripped = clean_line(line).strip()
    if not stripped or stripped.startswith("#"):
        return False
    if "(" not in stripped:
        return False
    first = re.split(r"\W+", stripped, maxsplit=1)[0]
    if first in CONTROL_WORDS or first in CAST_WORDS:
        return False
    if stripped.endswith(":"):
        return False
    return bool(CALL_RE.search(stripped))


def signature_block(lines: list[str], start_idx: int, lookahead: int = 12) -> tuple[str, int] | None:
    parts: list[str] = []
    for idx in range(start_idx, min(len(lines), start_idx + lookahead)):
        cleaned = clean_line(lines[idx]).strip()
        parts.append(cleaned)
        joined = " ".join(parts)
        brace_pos = joined.find("{")
        semi_pos = joined.find(";")
        if semi_pos != -1 and (brace_pos == -1 or semi_pos < brace_pos):
            return None
        if brace_pos != -1:
            return joined[: brace_pos + 1], idx
    return None


def extract_definition_name(signature: str) -> str | None:
    paren = signature.find("(")
    if paren == -1:
        return None
    prefix = signature[:paren].strip()
    matches = list(
        re.finditer(r"(?:[A-Za-z_]\w*::)*(?:~?[A-Za-z_]\w*|operator[^\s(]+)$", prefix)
    )
    if not matches:
        return None
    name = matches[-1].group(0)
    if name in CONTROL_WORDS or name in CAST_WORDS:
        return None
    return name


def find_body_end(lines: list[str], open_idx: int) -> int:
    depth = 0
    seen_open = False
    for idx in range(open_idx, len(lines)):
        cleaned = clean_line(lines[idx])
        for char in cleaned:
            if char == "{":
                depth += 1
                seen_open = True
            elif char == "}":
                depth -= 1
                if seen_open and depth <= 0:
                    return idx
    return len(lines) - 1


def find_definitions(source: SourceFile) -> list[FunctionDef]:
    defs: list[FunctionDef] = []
    idx = 0
    while idx < len(source.lines):
        line = source.lines[idx]
        if not is_probable_definition_start(line):
            idx += 1
            continue
        block = signature_block(source.lines, idx)
        if block is None:
            idx += 1
            continue
        signature, open_idx = block
        name = extract_definition_name(signature)
        if name is None:
            idx += 1
            continue
        end_idx = find_body_end(source.lines, open_idx)
        defs.append(
            FunctionDef(
                name=name,
                simple_name=simple_name(name),
                relpath=source.relpath,
                line=idx + 1,
                start_idx=idx,
                end_idx=end_idx,
                signature=" ".join(signature.split()),
            )
        )
        idx = max(idx + 1, end_idx + 1)
    return defs


def calls_in_range(source: SourceFile, start_idx: int, end_idx: int) -> list[CallSite]:
    calls: list[CallSite] = []
    for idx in range(start_idx, min(end_idx + 1, len(source.lines))):
        text = source.lines[idx].strip()
        cleaned = clean_line(source.lines[idx])
        for match in CALL_RE.finditer(cleaned):
            name = match.group("name")
            base = simple_name(name)
            if base in CONTROL_WORDS or base in CAST_WORDS:
                continue
            calls.append(
                CallSite(
                    name=name,
                    simple_name=base,
                    relpath=source.relpath,
                    line=idx + 1,
                    text=text,
                )
            )
    return calls


def branch_gates_in_range(source: SourceFile, start_idx: int, end_idx: int) -> list[dict[str, Any]]:
    gates: list[dict[str, Any]] = []
    for idx in range(start_idx, min(end_idx + 1, len(source.lines))):
        text = source.lines[idx].strip()
        if not text:
            continue
        if BRANCH_RE.search(clean_line(text)):
            gates.append({"path": source.relpath, "line": idx + 1, "text": text})
    return gates


def query_matches_def(query: str, func: FunctionDef) -> bool:
    q_simple = simple_name(query)
    if "::" in query:
        return func.name == query or func.name.endswith(f"::{query}") or func.simple_name == q_simple
    return func.simple_name == query


def query_matches_call(query: str, call: CallSite) -> bool:
    q_simple = simple_name(query)
    if "::" in query:
        return call.name == query or call.name.endswith(f"::{query}") or call.simple_name == q_simple
    return call.simple_name == query


def source_by_relpath(sources: list[SourceFile]) -> dict[str, SourceFile]:
    return {source.relpath: source for source in sources}


def index_definitions(defs: list[FunctionDef]) -> dict[str, list[FunctionDef]]:
    index: dict[str, list[FunctionDef]] = {}
    for func in defs:
        index.setdefault(func.simple_name, []).append(func)
        index.setdefault(func.name, []).append(func)
    return index


def caller_candidates(
    query: str, sources_by_path: dict[str, SourceFile], defs: list[FunctionDef]
) -> list[dict[str, Any]]:
    callers: list[dict[str, Any]] = []
    for func in defs:
        source = sources_by_path[func.relpath]
        for call in calls_in_range(source, func.start_idx, func.end_idx):
            if call.line == func.line:
                continue
            if query_matches_call(query, call):
                callers.append({"caller": func, "call": call})
    return callers


def callee_candidates(
    func: FunctionDef,
    sources_by_path: dict[str, SourceFile],
    def_index: dict[str, list[FunctionDef]],
) -> list[dict[str, Any]]:
    source = sources_by_path[func.relpath]
    entries: list[dict[str, Any]] = []
    seen: set[tuple[str, int, str]] = set()
    for call in calls_in_range(source, func.start_idx, func.end_idx):
        if call.line == func.line:
            continue
        key = (call.name, call.line, call.text)
        if key in seen:
            continue
        seen.add(key)
        matches = def_index.get(call.simple_name, [])
        entries.append(
            {
                "call": call,
                "definition_candidates": matches[:8],
                "definition_count": len(matches),
            }
        )
    return entries


def recursive_edges(
    roots: list[FunctionDef],
    sources_by_path: dict[str, SourceFile],
    def_index: dict[str, list[FunctionDef]],
    max_depth: int,
    max_callees_per_func: int,
) -> list[dict[str, Any]]:
    edges: list[dict[str, Any]] = []
    queue: list[tuple[FunctionDef, int]] = [(root, 0) for root in roots]
    visited: set[tuple[str, int, int]] = set()
    while queue:
        func, depth = queue.pop(0)
        visit_key = (func.relpath, func.line, depth)
        if visit_key in visited or depth >= max_depth:
            continue
        visited.add(visit_key)
        callees = callee_candidates(func, sources_by_path, def_index)[:max_callees_per_func]
        for entry in callees:
            call = entry["call"]
            candidates = entry["definition_candidates"]
            if not candidates:
                continue
            edge = {
                "depth": depth + 1,
                "caller": func,
                "call": call,
                "definition_candidates": candidates,
                "definition_count": entry["definition_count"],
            }
            edges.append(edge)
            if len(candidates) == 1:
                queue.append((candidates[0], depth + 1))
    return edges


def func_to_dict(func: FunctionDef) -> dict[str, Any]:
    return {
        "name": func.name,
        "simple_name": func.simple_name,
        "path": func.relpath,
        "line": func.line,
        "signature": func.signature,
    }


def call_to_dict(call: CallSite) -> dict[str, Any]:
    return {
        "name": call.name,
        "simple_name": call.simple_name,
        "path": call.relpath,
        "line": call.line,
        "text": call.text,
    }


def build_report(args: argparse.Namespace) -> dict[str, Any]:
    root = Path(args.root).resolve()
    sources, truncated = read_sources(root, args.max_files)
    sources_by_path = source_by_relpath(sources)
    defs: list[FunctionDef] = []
    for source in sources:
        defs.extend(find_definitions(source))
    def_index = index_definitions(defs)
    matched_defs = [func for func in defs if query_matches_def(args.function, func)]

    return {
        "query": args.function,
        "root": root.as_posix(),
        "files_scanned": len(sources),
        "truncated": truncated,
        "definitions": [func_to_dict(func) for func in matched_defs],
        "callers": [
            {"caller": func_to_dict(item["caller"]), "call": call_to_dict(item["call"])}
            for item in caller_candidates(args.function, sources_by_path, defs)
        ],
        "callees": [
            {
                "from": func_to_dict(func),
                "calls": [
                    {
                        "call": call_to_dict(entry["call"]),
                        "definition_count": entry["definition_count"],
                        "definition_candidates": [
                            func_to_dict(candidate)
                            for candidate in entry["definition_candidates"]
                        ],
                    }
                    for entry in callee_candidates(func, sources_by_path, def_index)
                ],
                "branch_gates": branch_gates_in_range(
                    sources_by_path[func.relpath], func.start_idx, func.end_idx
                ),
            }
            for func in matched_defs
        ],
        "recursive_edges": [
            {
                "depth": edge["depth"],
                "caller": func_to_dict(edge["caller"]),
                "call": call_to_dict(edge["call"]),
                "definition_count": edge["definition_count"],
                "definition_candidates": [
                    func_to_dict(candidate) for candidate in edge["definition_candidates"]
                ],
            }
            for edge in recursive_edges(
                matched_defs,
                sources_by_path,
                def_index,
                args.max_depth,
                args.max_callees_per_func,
            )
        ],
    }


def print_markdown(report: dict[str, Any]) -> None:
    print(f"# Static C++ trace candidates for `{report['query']}`")
    print()
    print(f"- Root: `{report['root']}`")
    print(f"- C++ files scanned: {report['files_scanned']}")
    if report["truncated"]:
        print("- Warning: scan stopped at --max-files; narrow --root or raise --max-files")
    print()

    print("## Candidate definitions")
    if not report["definitions"]:
        print("- None found")
    for func in report["definitions"]:
        print(f"- `{func['name']}()`  `{func['path']}:{func['line']}`")
        print(f"  `{func['signature']}`")
    print()

    print("## Candidate callers")
    if not report["callers"]:
        print("- None found")
    for item in report["callers"][:200]:
        caller = item["caller"]
        call = item["call"]
        print(
            f"- `{caller['name']}()` calls `{call['name']}()` at "
            f"`{call['path']}:{call['line']}`"
        )
        print(f"  `{call['text']}`")
    if len(report["callers"]) > 200:
        print(f"- ... {len(report['callers']) - 200} more caller candidates omitted")
    print()

    print("## Direct callee candidates from matched definitions")
    for group in report["callees"]:
        source = group["from"]
        print(f"### `{source['name']}()`  `{source['path']}:{source['line']}`")
        if not group["calls"]:
            print("- No calls found")
        for entry in group["calls"][:120]:
            call = entry["call"]
            print(
                f"- `{call['name']}()` at `{call['path']}:{call['line']}` "
                f"({entry['definition_count']} definition candidates)"
            )
            print(f"  `{call['text']}`")
            for candidate in entry["definition_candidates"][:3]:
                print(f"  - candidate `{candidate['name']}()` `{candidate['path']}:{candidate['line']}`")
        if len(group["calls"]) > 120:
            print(f"- ... {len(group['calls']) - 120} more callee candidates omitted")
        print()
        print("Branch gate candidates:")
        if not group["branch_gates"]:
            print("- None found")
        for gate in group["branch_gates"][:80]:
            print(f"- `{gate['path']}:{gate['line']}` `{gate['text']}`")
        if len(group["branch_gates"]) > 80:
            print(f"- ... {len(group['branch_gates']) - 80} more branch gates omitted")
        print()

    print("## Recursive project-local edge candidates")
    if not report["recursive_edges"]:
        print("- None found")
    for edge in report["recursive_edges"][:300]:
        caller = edge["caller"]
        call = edge["call"]
        print(
            f"- depth {edge['depth']}: `{caller['name']}()` -> `{call['name']}()` "
            f"at `{call['path']}:{call['line']}` "
            f"({edge['definition_count']} definition candidates)"
        )
        for candidate in edge["definition_candidates"][:3]:
            print(f"  - candidate `{candidate['name']}()` `{candidate['path']}:{candidate['line']}`")
    if len(report["recursive_edges"]) > 300:
        print(f"- ... {len(report['recursive_edges']) - 300} more edge candidates omitted")


def main() -> int:
    args = parse_args()
    report = build_report(args)
    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        print_markdown(report)
    return 0


if __name__ == "__main__":
    sys.exit(main())
