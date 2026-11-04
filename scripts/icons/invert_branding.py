#!/usr/bin/env python3
"""Invert every branding asset of XPrismLauncher.

The fork's identity is the upstream Prism Launcher artwork with inverted colors, so this
script rewrites the whole icon/logo set in place. It is NOT idempotent - every run inverts
again - so run it once per freshly synced upstream tree:

  * SVG sources  - invert #rgb/#rrggbb(#aa) hex colors, rgb() colors and the white/black
                   keywords, leaving geometry, opacity and gradients untouched.
  * PNG          - invert RGB, keep the alpha channel.
  * ICO          - every entry is a 32bpp DIB (BITMAPINFOHEADER + bottom-up BGRA + AND
                   mask), so the pixel bytes are inverted in place: all seven sizes keep
                   their exact offsets and lengths, nothing is re-encoded.
  * ICNS         - Pillow decodes each size (the 16/32 px chunks are RLE ARGB), the
                   pixels are inverted and the container is rebuilt with PNG chunks
                   (icp4/icp5/ic07..ic14), which macOS accepts; the bplist "info" chunk
                   is preserved verbatim.
  * icon.json    - the 3D-icon background fill (extended-gray 1.0 -> 0.0).

Usage (Pillow is the only dependency; run it through uv):

    uv run --with pillow python scripts/icons/invert_branding.py --out .tools/icons-preview
    uv run --with pillow python scripts/icons/invert_branding.py --apply

Without --apply the inverted files are written under --out (default .tools/icons-preview)
so the result can be inspected before it replaces the real assets.
"""

from __future__ import annotations

import argparse
import io
import json
import re
import struct
import sys
from pathlib import Path

from PIL import Image, ImageOps

REPO_ROOT = Path(__file__).resolve().parents[2]

# Every branded asset, repo-relative. instance_icons.svg and the scalable/instances/*.svg
# object icons (grass block, brick, TNT, chicken) are deliberately absent: they are content
# artwork, not the launcher's logo. ftb_logo.svg is a third-party brand as well.
SVG_FILES = [
    "program_info/org.prismlauncher.PrismLauncher.svg",
    "program_info/org.prismlauncher.PrismLauncher.Source.svg",
    "program_info/org.prismlauncher.PrismLauncher.Social.svg",
    "program_info/org.prismlauncher.PrismLauncher.bigsur.svg",
    "program_info/org.prismlauncher.PrismLauncher.logo.svg",
    "program_info/org.prismlauncher.PrismLauncher.logo-darkmode.svg",
    "program_info/org.prismlauncher.PrismLauncher.logo.source.svg",
    "program_info/prismlauncher-monochrome.Source.svg",
    "program_info/PrismLauncher.icon/Assets/block.svg",
    "program_info/PrismLauncher.icon/Assets/rainbow.svg",
    # In-app artwork that is the same logo: the launcher logo in the UI and the default
    # instance icon.
    "launcher/resources/multimc/scalable/launcher.svg",
    "launcher/resources/multimc/scalable/instances/prismlauncher.svg",
]
PNG_FILES = ["program_info/org.prismlauncher.PrismLauncher_256.png"]
ICO_FILES = ["program_info/prismlauncher.ico"]
ICNS_FILES = ["program_info/prismlauncher.icns"]
JSON_FILES = ["program_info/PrismLauncher.icon/icon.json"]

HEX_RE = re.compile(r"#([0-9a-fA-F]{3,8})\b")
RGB_RE = re.compile(r"rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)")
KEYWORD_RE = re.compile(r'"(\s*)(white|black)(\s*)"', re.IGNORECASE)


def _invert_channel(value: int) -> int:
    return max(0, min(255, 255 - value))


def invert_svg_text(text: str) -> tuple[str, int]:
    """Invert color literals in SVG source, returning the new text and a change count."""
    changes = 0

    def hex_repl(match: re.Match[str]) -> str:
        nonlocal changes
        digits = match.group(1)
        if len(digits) in (3, 4):
            r, g, b = (int(c * 2, 16) for c in digits[:3])
            alpha = digits[3] * 2 if len(digits) == 4 else ""
        elif len(digits) in (6, 8):
            r, g, b = int(digits[0:2], 16), int(digits[2:4], 16), int(digits[4:6], 16)
            alpha = digits[6:] if len(digits) == 8 else ""
        else:
            return match.group(0)
        changes += 1
        return "#%02x%02x%02x%s" % (_invert_channel(r), _invert_channel(g), _invert_channel(b), alpha)

    def rgb_repl(match: re.Match[str]) -> str:
        nonlocal changes
        changes += 1
        r, g, b = (int(match.group(i)) for i in (1, 2, 3))
        return "rgb(%d,%d,%d)" % (_invert_channel(r), _invert_channel(g), _invert_channel(b))

    def keyword_repl(match: re.Match[str]) -> str:
        nonlocal changes
        changes += 1
        inverted = "black" if match.group(2).lower() == "white" else "white"
        return '"%s%s%s"' % (match.group(1), inverted, match.group(3))

    text = HEX_RE.sub(hex_repl, text)
    text = RGB_RE.sub(rgb_repl, text)
    text = KEYWORD_RE.sub(keyword_repl, text)
    return text, changes


def invert_png(source: Path, target: Path) -> str:
    with Image.open(source) as image:
        mode = image.mode
        converted = image.convert("RGBA") if mode not in ("RGB", "RGBA", "LA", "L") else image
        inverted = ImageOps.invert(converted.convert("RGB"))
        if converted.mode in ("RGBA", "LA", "L"):
            inverted = inverted.convert("RGBA")
            inverted.putalpha(converted.convert("RGBA").getchannel("A"))
        inverted.save(target, format="PNG", optimize=True)
        return f"{image.size[0]}x{image.size[1]} {mode}"


def invert_ico(source: Path, target: Path) -> str:
    data = bytearray(source.read_bytes())
    count = struct.unpack_from("<H", data, 4)[0]
    details = []
    for index in range(count):
        entry = 6 + 16 * index
        length, offset = struct.unpack_from("<II", data, entry + 8)
        header_size, width, height2 = struct.unpack_from("<Iii", data, offset)
        # biPlanes (offset 12) sits between biHeight and biBitCount (offset 14).
        bpp = struct.unpack_from("<H", data, offset + 14)[0]
        if header_size != 40 or bpp != 32 or height2 != 2 * width:
            raise SystemExit(f"{source.name}: entry {index} is not a 32bpp DIB with mask - refusing to touch it")
        pixel_start = offset + header_size
        pixel_end = pixel_start + width * width * 4  # BGRA; the AND mask stays as is
        if pixel_end > offset + length:
            raise SystemExit(f"{source.name}: entry {index} pixel data does not fit into the entry")
        for position in range(pixel_start, pixel_end, 4):
            data[position] ^= 0xFF  # B
            data[position + 1] ^= 0xFF  # G
            data[position + 2] ^= 0xFF  # R
            # data[position + 3] is alpha - untouched on purpose
        details.append(f"{width}px")
    target.write_bytes(bytes(data))
    return "entries: " + ", ".join(details)


ICNS_SIZES = [16, 32, 64, 128, 256, 512, 1024]
# PNG-capable chunk types, in the same order/pairs the upstream file used.
ICNS_LAYOUT = [
    ("icp4", 16),
    ("ic11", 32),
    ("icp5", 32),
    ("ic12", 64),
    ("ic07", 128),
    ("ic13", 256),
    ("ic08", 256),
    ("ic14", 512),
    ("ic09", 512),
    ("ic10", 1024),
]


def _icns_chunks(blob: bytes) -> list[tuple[str, bytes]]:
    if blob[0:4] != b"icns":
        raise SystemExit("not an ICNS file")
    chunks: list[tuple[str, bytes]] = []
    position = 8
    while position + 8 <= len(blob):
        kind = blob[position : position + 4].decode("ascii", "replace")
        (length,) = struct.unpack_from(">I", blob, position + 4)
        if length < 8 or position + length > len(blob):
            raise SystemExit(f"broken ICNS chunk {kind!r} at {position}")
        chunks.append((kind, blob[position + 8 : position + length]))
        position += length
    return chunks


# Chunk type -> edge length in pixels. ic04/ic05 are RLE-encoded ARGB, the rest are PNG.
ICNS_CHUNK_SIZE = {
    "icp4": 16,
    "ic04": 16,
    "icp5": 32,
    "ic05": 32,
    "icp6": 64,
    "ic11": 32,
    "ic12": 64,
    "ic07": 128,
    "ic08": 256,
    "ic13": 256,
    "ic09": 512,
    "ic14": 512,
    "ic10": 1024,
}


def _decode_icns_chunk(kind: str, payload: bytes) -> Image.Image:
    if payload[:8] == b"\x89PNG\r\n\x1a\n":
        with Image.open(io.BytesIO(payload)) as image:
            image.load()
            return image.convert("RGBA")
    if kind not in ICNS_CHUNK_SIZE:
        raise SystemExit(f"cannot decode ICNS chunk {kind!r}")
    # Pillow knows how to expand the RLE ARGB variants, but only through a container.
    mini = b"icns" + struct.pack(">I", 16 + len(payload)) + kind.encode("ascii")
    mini += struct.pack(">I", 8 + len(payload)) + payload
    with Image.open(io.BytesIO(mini)) as image:
        image.load()
        return image.convert("RGBA")


def invert_icns(source: Path, target: Path) -> str:
    blob = source.read_bytes()
    chunks = _icns_chunks(blob)

    images: dict[int, Image.Image] = {}
    skipped: list[str] = []
    for kind, payload in chunks:
        if kind not in ICNS_CHUNK_SIZE:
            continue
        size = ICNS_CHUNK_SIZE[kind]
        if size in images:
            continue
        try:
            frame = _decode_icns_chunk(kind, payload)
        except Exception:
            # Pillow has no decoder for the RLE ARGB ic04/ic05 chunks; those sizes are
            # rebuilt below from the neighbouring PNG variants instead.
            skipped.append(f"{kind}:{size}")
            continue
        if frame.size != (size, size):
            frame = frame.resize((size, size), Image.LANCZOS)
        inverted = ImageOps.invert(frame.convert("RGB")).convert("RGBA")
        inverted.putalpha(frame.getchannel("A"))
        images[size] = inverted

    # Fill holes (if any) by downscaling the nearest larger variant, then upscaling the
    # nearest smaller one, so the rebuilt container always carries the full size set.
    for size in ICNS_SIZES:
        if size in images:
            continue
        larger = [s for s in images if s > size]
        source_size = min(larger) if larger else max(images)
        images[size] = images[source_size].resize((size, size), Image.LANCZOS)

    out = bytearray(b"icns\0\0\0\0")
    emitted: list[str] = []
    for kind, size in ICNS_LAYOUT:
        buffer = io.BytesIO()
        images[size].save(buffer, format="PNG", optimize=True)
        payload = buffer.getvalue()
        out += kind.encode("ascii") + struct.pack(">I", len(payload) + 8) + payload
        emitted.append(f"{kind}:{size}")
    for kind, payload in chunks:
        if kind == "info":  # bplist metadata - keep verbatim
            out += kind.encode("ascii") + struct.pack(">I", len(payload) + 8) + payload
            emitted.append("info")
    struct.pack_into(">I", out, 4, len(out))
    target.write_bytes(bytes(out))
    note = f" (rescaled: {', '.join(skipped)})" if skipped else ""
    return "chunks: " + ", ".join(emitted) + note


def invert_icon_json(source: Path, target: Path) -> str:
    document = json.loads(source.read_text(encoding="utf-8"))
    fill = document.get("fill", {}).get("solid")
    if fill != "extended-gray:1.00000,1.00000":
        raise SystemExit(f"{source.name}: unexpected background fill {fill!r}")
    document["fill"]["solid"] = "extended-gray:0.00000,0.00000"
    target.write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return "fill: white -> black"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--apply", action="store_true", help="overwrite the assets in program_info")
    group.add_argument("--out", type=Path, help="write results to this directory instead of program_info")
    args = parser.parse_args()
    if not args.apply and not args.out:
        parser.error("choose --apply or --out DIR")

    root = REPO_ROOT if args.apply else args.out.resolve()
    actions: list[tuple[Path, Path, str]] = []
    for name in SVG_FILES:
        actions.append((REPO_ROOT / name, root / name, "svg"))
    for name in PNG_FILES:
        actions.append((REPO_ROOT / name, root / name, "png"))
    for name in ICO_FILES:
        actions.append((REPO_ROOT / name, root / name, "ico"))
    for name in ICNS_FILES:
        actions.append((REPO_ROOT / name, root / name, "icns"))
    for name in JSON_FILES:
        actions.append((REPO_ROOT / name, root / name, "json"))

    for source, target, kind in actions:
        if not source.is_file():
            raise SystemExit(f"missing branding asset: {source}")
        target.parent.mkdir(parents=True, exist_ok=True)
        if kind == "svg":
            text, changes = invert_svg_text(source.read_text(encoding="utf-8"))
            target.write_text(text, encoding="utf-8")
            print(f"svg   {source.name:<60} {changes} colors")
        elif kind == "png":
            print(f"png   {source.name:<60} {invert_png(source, target)}")
        elif kind == "ico":
            print(f"ico   {source.name:<60} {invert_ico(source, target)}")
        elif kind == "icns":
            print(f"icns  {source.name:<60} {invert_icns(source, target)}")
        else:
            print(f"json  {source.name:<60} {invert_icon_json(source, target)}")

    print(f"\nwritten to {root}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
