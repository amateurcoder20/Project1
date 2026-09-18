#!/usr/bin/env python3
"""Generate placeholder Android launcher icons (no third-party deps)."""
from __future__ import annotations

import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "icons"


def write_png(path: Path, pixels: list[list[tuple[int, int, int, int]]]) -> None:
    height = len(pixels)
    width = len(pixels[0])
    raw = bytearray()
    for row in pixels:
        raw.append(0)
        for r, g, b, a in row:
            raw.extend((r, g, b, a))

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )


def lerp(a: int, b: int, t: float) -> int:
    return int(a + (b - a) * t)


def color_at(x: int, y: int, size: int, *, adaptive_fg: bool) -> tuple[int, int, int, int]:
    nx = x / (size - 1)
    ny = y / (size - 1)
    # Warm wood radial backdrop
    cx, cy = 0.5, 0.48
    d = ((nx - cx) ** 2 + (ny - cy) ** 2) ** 0.5
    t = min(1.0, d * 1.35)
    r = lerp(78, 22, t)
    g = lerp(44, 12, t)
    b = lerp(24, 8, t)
    a = 255
    if adaptive_fg:
        # Transparent corners for Android adaptive icons (safe zone ~66%).
        if d > 0.48:
            a = 0
            r, g, b = 0, 0, 0

    # Board square (centered 4×4)
    left, top, right, bottom = 0.18, 0.18, 0.82, 0.82
    if left <= nx <= right and top <= ny <= bottom:
        u = (nx - left) / (right - left)
        v = (ny - top) / (bottom - top)
        col = min(3, int(u * 4))
        row = min(3, int(v * 4))
        light = (row + col) % 2 == 0
        if light:
            r, g, b = 230, 209, 168
        else:
            r, g, b = 122, 74, 40
        # Inner bevel
        edge = min(u, v, 1 - u, 1 - v)
        if edge < 0.03:
            r, g, b = 42, 22, 12

    def in_circle(px: float, py: float, rad: float) -> bool:
        return (nx - px) ** 2 + (ny - py) ** 2 <= rad ** 2

    def in_rect(x0: float, y0: float, x1: float, y1: float) -> bool:
        return x0 <= nx <= x1 and y0 <= ny <= y1

    # Knight (dark wood) on the lower-left
    knight = (
        in_rect(0.24, 0.62, 0.42, 0.74)
        or in_rect(0.28, 0.46, 0.40, 0.64)
        or in_rect(0.30, 0.34, 0.38, 0.48)
        or in_rect(0.34, 0.30, 0.48, 0.40)
        or in_rect(0.26, 0.28, 0.32, 0.38)
    )
    if knight:
        r, g, b = 32, 16, 8

    # Queen (cream marble) on the upper-right
    queen = (
        in_rect(0.58, 0.64, 0.76, 0.74)
        or in_rect(0.64, 0.40, 0.70, 0.66)
        or in_circle(0.67, 0.38, 0.055)
        or in_rect(0.60, 0.28, 0.64, 0.38)
        or in_rect(0.65, 0.24, 0.69, 0.38)
        or in_rect(0.70, 0.28, 0.74, 0.38)
    )
    if queen:
        r, g, b = 243, 234, 216

    return r, g, b, a


def make(size: int, *, adaptive_fg: bool = False) -> list[list[tuple[int, int, int, int]]]:
    return [[color_at(x, y, size, adaptive_fg=adaptive_fg) for x in range(size)] for y in range(size)]


def solid(size: int, rgb: tuple[int, int, int]) -> list[list[tuple[int, int, int, int]]]:
    r, g, b = rgb
    return [[(r, g, b, 255) for _ in range(size)] for _ in range(size)]


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    write_png(OUT / "icon_192.png", make(192))
    write_png(OUT / "icon_512.png", make(512))
    write_png(OUT / "play_store_512.png", make(512))
    write_png(OUT / "adaptive_foreground_432.png", make(432, adaptive_fg=True))
    write_png(OUT / "adaptive_background_432.png", solid(432, (42, 22, 12)))
    print(f"Wrote icons in {OUT}")


if __name__ == "__main__":
    main()
