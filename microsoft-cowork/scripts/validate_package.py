#!/usr/bin/env python3
"""Offline structural validator for the Mortgate Copilot Cowork package."""
from __future__ import annotations

import argparse
import json
import re
import struct
import sys
import zipfile
from pathlib import Path

SKILL_FRONTMATTER = re.compile(
    r"^---\nname: ([a-z0-9]+(?:-[a-z0-9]+)*)\ndescription: (.+)\n---\n",
    re.DOTALL,
)


def png_size(path: Path) -> tuple[int, int]:
    raw = path.read_bytes()
    if raw[:8] != b"\x89PNG\r\n\x1a\n" or raw[12:16] != b"IHDR":
        raise ValueError(f"{path} is not a PNG with an IHDR chunk")
    return struct.unpack(">II", raw[16:24])


def validate(package_root: Path, archive: Path | None) -> list[str]:
    errors: list[str] = []
    manifest_path = package_root / "manifest.json"
    try:
        manifest = json.loads(manifest_path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        return [f"manifest: {error}"]

    if manifest.get("manifestVersion") != "1.28":
        errors.append("manifestVersion must be 1.28")
    if manifest.get("agentConnectors"):
        errors.append("v1 must remain skills-only; agentConnectors is not allowed")

    skills = manifest.get("agentSkills")
    if not isinstance(skills, list) or not skills:
        errors.append("agentSkills must contain at least one skill")
    elif len(skills) > 20:
        errors.append("Cowork supports at most 20 skills per package")
    else:
        for entry in skills:
            folder_value = entry.get("folder") if isinstance(entry, dict) else None
            if not isinstance(folder_value, str):
                errors.append("every agentSkills entry needs a folder")
                continue
            folder = package_root / folder_value.removeprefix("./")
            skill_path = folder / "SKILL.md"
            try:
                text = skill_path.read_text()
            except OSError:
                errors.append(f"missing {skill_path.relative_to(package_root)}")
                continue
            match = SKILL_FRONTMATTER.match(text)
            if not match:
                errors.append(f"invalid SKILL.md frontmatter: {skill_path.relative_to(package_root)}")
                continue
            if match.group(1) != folder.name:
                errors.append(f"skill name must match folder: {folder.name}")

    for icon, expected_size in (("color.png", (192, 192)), ("outline.png", (32, 32))):
        try:
            if png_size(package_root / icon) != expected_size:
                errors.append(f"{icon} must be {expected_size[0]}x{expected_size[1]}")
        except (OSError, ValueError) as error:
            errors.append(str(error))

    if archive:
        try:
            with zipfile.ZipFile(archive) as bundle:
                names = set(bundle.namelist())
        except (OSError, zipfile.BadZipFile) as error:
            errors.append(f"archive: {error}")
        else:
            required = {"manifest.json", "color.png", "outline.png"}
            missing = required - names
            if missing:
                errors.append(f"archive missing: {', '.join(sorted(missing))}")
            skill_count = sum(name.endswith("/SKILL.md") for name in names)
            expected_count = len(skills) if isinstance(skills, list) else 0
            if skill_count != expected_count:
                errors.append(f"archive has {skill_count} skills; expected {expected_count}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package-root", type=Path, default=Path("appPackage"))
    parser.add_argument("--archive", type=Path)
    args = parser.parse_args()
    errors = validate(args.package_root, args.archive)
    if errors:
        print("Cowork package validation failed:", file=sys.stderr)
        print("\n".join(f"- {error}" for error in errors), file=sys.stderr)
        return 1
    print("Cowork package validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
