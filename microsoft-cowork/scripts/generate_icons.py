#!/usr/bin/env python3
"""Generate deterministic PNG icons for the Microsoft 365 app package."""
from __future__ import annotations

import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "appPackage"


def chunk(name: bytes, payload: bytes) -> bytes:
    return struct.pack(">I", len(payload)) + name + payload + struct.pack(">I", zlib.crc32(name + payload) & 0xFFFFFFFF)


def png(path: Path, width: int, height: int, rgba: tuple[int, int, int, int]) -> None:
    row = bytes(rgba) * width
    raw = b"".join(b"\x00" + row for _ in range(height))
    body = b"\x89PNG\r\n\x1a\n"
    body += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    body += chunk(b"IDAT", zlib.compress(raw, 9))
    body += chunk(b"IEND", b"")
    path.write_bytes(body)


png(ROOT / "color.png", 192, 192, (22, 75, 142, 255))
png(ROOT / "outline.png", 32, 32, (255, 255, 255, 255))
