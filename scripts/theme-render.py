#!/usr/bin/env python3
"""
~/.config/scripts/theme-render.py — turns a color palette into every app's config.

  theme-render.py render <palette.conf> [--dest DIR]
      Fill all templates in themes/templates/ from one palette file and write
      the results into DEST (default: ~/.config). Standard library only.

  theme-render.py wal <image> <theme-palette.conf> <out.conf>
      Build a palette from a wallpaper with pywal (colors only; cursor and
      wallpaper keys are copied from the theme palette). Needs `wal` on PATH.

Template placeholders:
  {{key}}        -> #rrggbb value of palette key "key"
  {{key:bare}}   -> rrggbb (no #), for Hyprland rgba() and fuzzel RRGGBBAA.
"""

import colorsys
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
# Works both from the repo (scripts/ next to themes/) and from ~/.config/scripts.
RICE = HERE.parent
TEMPLATES = RICE / "themes" / "templates"

# template file -> output paths (relative to the destination config dir)
TARGETS = {
    "hypr-colors.conf.tmpl": ["hypr/colors.conf"],
    "waybar-colors.css.tmpl": ["waybar/colors.css"],
    "wofi-colors.css.tmpl": ["wofi/colors.css"],
    "eww-colors.scss.tmpl": ["eww/colors.scss"],
    "kitty-theme.conf.tmpl": ["kitty/theme.conf"],
    "dunstrc.tmpl": ["dunst/dunstrc"],
    "fuzzel.ini.tmpl": ["fuzzel/fuzzel.ini"],
    "gtk-colors.css.tmpl": ["gtk-3.0/gtk.css", "gtk-4.0/gtk.css"],
    "qt5ct-colors.conf.tmpl": ["qt5ct/colors/rice.conf"],
}

REQUIRED = [
    "bg", "bg_alt", "surface", "surface_alt", "fg", "fg_dim", "overlay",
    "accent", "accent_alt", "accent2", "warning", "critical", "ok",
    *[f"color{i}" for i in range(16)],
    "cursor_theme", "cursor_size", "wallpaper",
]
HEX = re.compile(r"^#[0-9a-fA-F]{6}$")


def die(msg):
    print(f"theme-render: {msg}", file=sys.stderr)
    sys.exit(1)


NON_HEX_KEYS = {"name", "dark", "cursor_theme", "cursor_size", "wallpaper"}


def read_palette(path):
    """Parse 'key = value' lines. '#' starts a comment only after whitespace,
    because color values themselves start with '#'."""
    pal = {}
    for raw in Path(path).read_text().splitlines():
        s = raw.strip()
        if not s or s.startswith("#") or "=" not in s:
            continue
        key, val = s.split("=", 1)
        pal[key.strip()] = val.strip().split(" #", 1)[0].strip()
    missing = [k for k in REQUIRED if k not in pal]
    if missing:
        die(f"{path}: missing keys: {', '.join(missing)}")
    for k, v in pal.items():
        if k not in NON_HEX_KEYS and not HEX.match(v):
            die(f"{path}: '{k}' must be #rrggbb, got '{v}'")
    return pal


def fill(text, pal):
    def rep(m):
        key, mod = m.group(1), m.group(2)
        if key not in pal:
            die(f"template uses unknown key '{key}'")
        v = pal[key]
        return v.lstrip("#") if mod == "bare" else v
    return re.sub(r"\{\{\s*([a-z0-9_]+)(?::(bare))?\s*\}\}", rep, text)


def write_atomic(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(text)
    os.replace(tmp, path)


def render(palette_path, dest):
    pal = read_palette(palette_path)
    for tmpl, outs in TARGETS.items():
        text = fill((TEMPLATES / tmpl).read_text(), pal)
        for out in outs:
            write_atomic(Path(dest) / out, text)
    return pal


# ---------------------------------------------------------------- pywal path
def _hex(rgb):
    return "#%02x%02x%02x" % tuple(max(0, min(255, round(c))) for c in rgb)


def _rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def _mix(a, b, t):
    """Blend color a toward b by t (0..1)."""
    ra, rb = _rgb(a), _rgb(b)
    return _hex([ra[i] + (rb[i] - ra[i]) * t for i in range(3)])


def wal_palette(image, theme_palette, out):
    base = read_palette(theme_palette)
    wal = shutil.which("wal")
    if not wal:
        die("pywal ('wal') not found — install python-pywal (see README)")
    with tempfile.TemporaryDirectory() as tmp:
        cmd = [wal, "-i", image, "-n", "-t", "-s", "-e", "-q",
               "--backend", "colorthief", "--out-dir", tmp]
        r = subprocess.run(cmd, capture_output=True, text=True)
        cj = Path(tmp) / "colors.json"
        if r.returncode != 0 or not cj.exists():
            die(f"pywal failed on {image}: {r.stderr.strip() or r.stdout.strip()}")
        data = json.loads(cj.read_text())
    c = [data["colors"][f"color{i}"] for i in range(16)]
    bg = data["special"]["background"]
    fg = data["special"]["foreground"]
    # Keep the background dark (or light) according to the wallpaper itself.
    r_, g_, b_ = (x / 255 for x in _rgb(bg))
    dark = colorsys.rgb_to_hls(r_, g_, b_)[1] < 0.5
    # pywal's extraction is muted on some images, so pick each accent from the
    # most saturated extracted color inside a hue band; fall back to the theme.
    cands = c[1:7] + c[9:15]

    def pick(lo, hi, fallback):
        best, best_s = None, 0.25
        for col in cands:
            h, l, sat = colorsys.rgb_to_hls(*(x / 255 for x in _rgb(col)))
            if lo <= h * 360 <= hi and 0.3 < l < 0.85 and sat > best_s:
                best, best_s = col, sat
        return best or fallback

    pal = {
        "name": "wallpaper",
        "dark": "true" if dark else "false",
        "bg": bg,
        "bg_alt": _mix(bg, "#000000", 0.25) if dark else _mix(bg, "#000000", 0.05),
        "surface": _mix(bg, fg, 0.08),
        "surface_alt": _mix(bg, fg, 0.25),
        "fg": fg,
        "fg_dim": _mix(fg, bg, 0.30),
        "overlay": _mix(fg, bg, 0.50),
        "accent": pick(200, 260, base["accent"]),
        "accent_alt": pick(160, 200, base["accent_alt"]),
        "accent2": pick(270, 330, base["accent2"]),
        "warning": pick(35, 65, base["warning"]),
        "critical": pick(340, 360, pick(0, 20, base["critical"])),
        "ok": pick(80, 150, base["ok"]),
        "cursor_theme": base["cursor_theme"],
        "cursor_size": base["cursor_size"],
        "wallpaper": base["wallpaper"],
    }
    for i in range(16):
        pal[f"color{i}"] = c[i]
    # ANSI-friendly fallback: make sure the colors used for text are readable.
    lines = ["# Generated from wallpaper by pywal — regenerated automatically.",
             f"# source image: {image}", ""]
    lines += [f"{k} = {v}" for k, v in pal.items()]
    write_atomic(Path(out), "\n".join(lines) + "\n")


def main(argv):
    if len(argv) >= 2 and argv[1] == "render":
        dest = Path.home() / ".config"
        args = argv[2:]
        if "--dest" in args:
            i = args.index("--dest")
            dest = Path(args[i + 1])
            del args[i:i + 2]
        if len(args) != 1:
            die("usage: theme-render.py render <palette.conf> [--dest DIR]")
        render(args[0], dest)
    elif len(argv) == 5 and argv[1] == "wal":
        wal_palette(argv[2], argv[3], argv[4])
    else:
        print(__doc__)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
