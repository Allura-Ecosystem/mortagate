#!/usr/bin/env python3
"""Validate Mortgate's exact, non-mutating catalog export contract."""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path, PurePosixPath
from typing import Any

EXPECTED_PACKAGE_ID = "mortagate-cowork"
EXPECTED_DESTINATION = "packages/mortagate-cowork"
EXPECTED_REPOSITORY = "https://github.com/Allura-Ecosystem/mortagate.git"
REQUIRED_PROVENANCE = {
    "sourceRepository",
    "sourceCommit",
    "contractPath",
    "contractSha256",
    "generatedBy",
}


def _safe_relative(value: object) -> bool:
    if not isinstance(value, str) or not value or "\\" in value:
        return False
    path = PurePosixPath(value)
    return not path.is_absolute() and ".." not in path.parts and str(path) == value


def _tracked_under(repo_root: Path, source_root: str) -> set[str]:
    result = subprocess.run(
        ["git", "ls-files", "--", source_root],
        cwd=repo_root,
        check=True,
        text=True,
        capture_output=True,
    )
    prefix = f"{source_root}/"
    return {
        line.removeprefix(prefix)
        for line in result.stdout.splitlines()
        if line.startswith(prefix)
    }


def validate_contract(repo_root: Path, contract: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if contract.get("schemaVersion") != 1:
        errors.append("schemaVersion must be 1")
    if contract.get("packageId") != EXPECTED_PACKAGE_ID:
        errors.append(f"packageId must be {EXPECTED_PACKAGE_ID}")

    canonical = contract.get("canonical")
    if not isinstance(canonical, dict):
        return errors + ["canonical must be an object"]
    if canonical.get("repository") != EXPECTED_REPOSITORY:
        errors.append(f"canonical.repository must be {EXPECTED_REPOSITORY}")
    source_root_value = canonical.get("sourceRoot")
    if not _safe_relative(source_root_value) or not isinstance(source_root_value, str):
        errors.append("canonical.sourceRoot must be a normalized relative path")
        return errors
    source_root = source_root_value

    destination = contract.get("destination")
    if not isinstance(destination, dict):
        errors.append("destination must be an object")
    else:
        if destination.get("path") != EXPECTED_DESTINATION:
            errors.append(f"destination.path must be {EXPECTED_DESTINATION}")
        if destination.get("status") != "future-generated-export":
            errors.append("destination.status must remain future-generated-export until published")
        if destination.get("mode") != "pinned-generated-export":
            errors.append("destination.mode must be pinned-generated-export")

    export = contract.get("export")
    if not isinstance(export, dict):
        return errors + ["export must be an object"]
    includes = export.get("include")
    excludes_raw = export.get("exclude")
    if not isinstance(includes, list) or not all(_safe_relative(p) for p in includes):
        errors.append("export.include must contain only normalized relative paths")
        includes = []
    if includes != sorted(set(includes)):
        errors.append("export.include must be sorted and contain no duplicates")

    if not isinstance(excludes_raw, list):
        errors.append("export.exclude must be an array")
        excludes_raw = []
    excludes: list[str] = []
    for entry in excludes_raw:
        if not isinstance(entry, dict) or not _safe_relative(entry.get("path")):
            errors.append("every export.exclude entry needs a normalized relative path")
            continue
        if not isinstance(entry.get("reason"), str) or not entry["reason"].strip():
            errors.append(f"excluded path {entry['path']} needs a reason")
        excludes.append(entry["path"])
    if excludes != sorted(set(excludes)):
        errors.append("export.exclude must be sorted and contain no duplicates")

    overlap = set(includes) & set(excludes)
    if overlap:
        errors.append(f"paths cannot be both included and excluded: {', '.join(sorted(overlap))}")

    source_dir = repo_root / source_root
    if not source_dir.is_dir():
        errors.append(f"source root does not exist: {source_root}")
    for relative in includes:
        path = source_dir / relative
        if not path.is_file():
            errors.append(f"included file does not exist: {source_root}/{relative}")
        elif path.is_symlink():
            errors.append(f"included file must not be a symlink: {source_root}/{relative}")
    for relative in excludes:
        if not (source_dir / relative).exists():
            errors.append(f"excluded file does not exist: {source_root}/{relative}")

    try:
        tracked = _tracked_under(repo_root, source_root)
    except (OSError, subprocess.CalledProcessError) as error:
        errors.append(f"cannot enumerate tracked source files: {error}")
    else:
        classified = set(includes) | set(excludes)
        unclassified = tracked - classified
        stale = classified - tracked
        if unclassified:
            errors.append(f"tracked source files are unclassified: {', '.join(sorted(unclassified))}")
        if stale:
            errors.append(f"contract paths are not tracked: {', '.join(sorted(stale))}")

    provenance = contract.get("provenance")
    if not isinstance(provenance, dict):
        errors.append("provenance must be an object")
    else:
        fields = provenance.get("requiredFields")
        if not isinstance(fields, list) or set(fields) != REQUIRED_PROVENANCE:
            errors.append("provenance.requiredFields must declare the complete generation receipt")
        if provenance.get("contractPath") != "catalog-export.json":
            errors.append("provenance.contractPath must be catalog-export.json")

    authority = contract.get("authority")
    if not isinstance(authority, dict) or authority.get("downstreamIsAuthority") is not False:
        errors.append("authority.downstreamIsAuthority must be false")
    return errors


def load_contract(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise ValueError("contract root must be an object")
    return value


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--contract", type=Path)
    args = parser.parse_args()
    repo_root = args.repo_root.resolve()
    contract_path = args.contract or repo_root / "catalog-export.json"
    contract: dict[str, Any] = {}
    try:
        contract = load_contract(contract_path)
        errors = validate_contract(repo_root, contract)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        errors = [f"contract: {error}"]
    if errors:
        print("Catalog export validation failed:", file=sys.stderr)
        print("\n".join(f"- {error}" for error in errors), file=sys.stderr)
        return 1
    includes_count = len(contract.get("export", {}).get("include", []))
    excludes_count = len(contract.get("export", {}).get("exclude", []))
    print(f"Catalog export validation passed: {includes_count} included files, {excludes_count} documented exclusion(s).")
    print("Future destination: allura-plugins/packages/mortagate-cowork")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
