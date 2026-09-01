#!/usr/bin/env python3
"""Check local Markdown links and heading fragments without network access."""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit

LINK = re.compile(r"(?<!!)\[[^\]]+\]\(([^)]+)\)")
HEADING = re.compile(r"^#{1,6}\s+(.+?)\s*$", re.MULTILINE)


def github_slug(heading: str) -> str:
    text = re.sub(r"<[^>]+>", "", heading.strip().lower())
    text = re.sub(r"[^\w\- ]", "", text, flags=re.UNICODE)
    return text.replace(" ", "-")


def product_markdown_files(repo_root: Path) -> list[Path]:
    candidates = [repo_root / "README.md", repo_root / "force-app" / "README.md", repo_root / "microsoft-cowork" / "README.md"]
    candidates.extend((repo_root / "docs").glob("*.md"))
    candidates.extend((repo_root / "microsoft-cowork" / "docs").glob("*.md"))
    return sorted(path for path in candidates if path.is_file())


def check_file(path: Path, repo_root: Path) -> list[str]:
    errors: list[str] = []
    text = path.read_text(encoding="utf-8")
    for raw_target in LINK.findall(text):
        target = raw_target.strip().split(maxsplit=1)[0].strip("<>")
        parsed = urlsplit(target)
        if parsed.scheme in {"http", "https", "mailto", "tel", "data"} or target.startswith("//"):
            continue
        relative = unquote(parsed.path)
        resolved = (path.parent / relative).resolve() if relative else path.resolve()
        try:
            resolved.relative_to(repo_root.resolve())
        except ValueError:
            errors.append(f"{path.relative_to(repo_root)}: link escapes repository: {target}")
            continue
        if not resolved.exists():
            errors.append(f"{path.relative_to(repo_root)}: missing target: {target}")
            continue
        if parsed.fragment and resolved.is_file() and resolved.suffix.lower() == ".md":
            headings = {github_slug(value) for value in HEADING.findall(resolved.read_text(encoding="utf-8"))}
            if unquote(parsed.fragment).lower() not in headings:
                errors.append(f"{path.relative_to(repo_root)}: missing heading fragment: {target}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("paths", nargs="*", type=Path)
    args = parser.parse_args()
    repo_root = args.repo_root.resolve()
    files = [p.resolve() for p in args.paths] if args.paths else product_markdown_files(repo_root)
    errors = [error for path in files for error in check_file(path, repo_root)]
    if errors:
        print("Markdown link validation failed:", file=sys.stderr)
        print("\n".join(f"- {error}" for error in errors), file=sys.stderr)
        return 1
    print(f"Markdown link validation passed: {len(files)} files checked.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
