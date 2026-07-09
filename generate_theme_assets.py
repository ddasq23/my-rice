#!/usr/bin/env python3
"""
Generates, for each theme:
  - themes/<name>/colors.css       (shared by waybar + wofi)
  - themes/<name>/eww-colors.scss
  - themes/<name>/kitty-theme.conf
  - themes/<name>/hypr-colors.conf
  - themes/<name>/dunstrc
  - wallpapers/<name>.png           (original procedural art, no copyright risk)
"""
import math
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).parent
THEMES_DIR = ROOT / "themes"
WALL_DIR = ROOT / "wallpapers"
THEMES_DIR.mkdir(exist_ok=True)
WALL_DIR.mkdir(exist_ok=True)

PALETTES = {
    "catppuccin-mocha": dict(
        base="#1e1e2e", mantle="#181825", surface="#313244", surface2="#45475a",
        text="#cdd6f4", subtext="#a6adc8", accent="#cba6f7", accent2="#89b4fa",
        warning="#f9e2af", critical="#f38ba8", green="#a6e3a1", cursor="#f5e0dc",
        dark=True,
    ),
    "catppuccin-latte": dict(
        base="#eff1f5", mantle="#e6e9ef", surface="#ccd0da", surface2="#bcc0cc",
        text="#4c4f69", subtext="#6c6f85", accent="#8839ef", accent2="#1e66f5",
        warning="#df8e1d", critical="#d20f39", green="#40a02b", cursor="#dc8a78",
        dark=False,
    ),
    "nord": dict(
        base="#2e3440", mantle="#242933", surface="#3b4252", surface2="#434c5e",
        text="#e5e9f0", subtext="#d8dee9", accent="#88c0d0", accent2="#5e81ac",
        warning="#ebcb8b", critical="#bf616a", green="#a3be8c", cursor="#88c0d0",
        dark=True,
    ),
    "gruvbox": dict(
        base="#282828", mantle="#1d2021", surface="#3c3836", surface2="#504945",
        text="#ebdbb2", subtext="#d5c4a1", accent="#d79921", accent2="#fe8019",
        warning="#d79921", critical="#cc241d", green="#98971a", cursor="#fe8019",
        dark=True,
    ),
    "dracula": dict(
        base="#282a36", mantle="#21222c", surface="#44475a", surface2="#565971",
        text="#f8f8f2", subtext="#bfbfd4", accent="#bd93f9", accent2="#ff79c6",
        warning="#f1fa8c", critical="#ff5555", green="#50fa7b", cursor="#bd93f9",
        dark=True,
    ),
    "tokyo-night": dict(
        base="#1a1b26", mantle="#16161e", surface="#24283b", surface2="#414868",
        text="#c0caf5", subtext="#a9b1d6", accent="#7aa2f7", accent2="#bb9af7",
        warning="#e0af68", critical="#f7768e", green="#9ece6a", cursor="#7aa2f7",
        dark=True,
    ),
}


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


# ---------------------------------------------------------------- colors.css
def write_waybar_wofi_colors(name, p):
    out = THEMES_DIR / name / "colors.css"
    out.parent.mkdir(exist_ok=True)
    out.write_text(f"""/* {name} — generated, do not hand-edit; re-run generate_theme_assets.py */
@define-color base       {p['base']};
@define-color surface    {p['surface2']};
@define-color text       {p['text']};
@define-color subtext    {p['subtext']};
@define-color accent     {p['accent']};
@define-color warning    {p['warning']};
@define-color critical   {p['critical']};
""")


# ------------------------------------------------------------ eww-colors.scss
def write_eww_colors(name, p):
    out = THEMES_DIR / name / "eww-colors.scss"
    out.write_text(f"""// {name} — generated, do not hand-edit
$base: {p['base']};
$mantle: {p['mantle']};
$surface: {p['surface']};
$text: {p['text']};
$subtext: {p['subtext']};
$accent: {p['accent']};
$accent2: {p['accent2']};
$warning: {p['warning']};
$critical: {p['critical']};
$green: {p['green']};
""")


# ------------------------------------------------------------- kitty-theme
def write_kitty_theme(name, p):
    out = THEMES_DIR / name / "kitty-theme.conf"
    fg, bg = p["text"], p["base"]
    out.write_text(f"""# {name} — generated, do not hand-edit
foreground              {fg}
background              {bg}
selection_foreground    {bg}
selection_background    {p['cursor']}
cursor                  {p['cursor']}
cursor_text_color       {bg}
url_color               {p['cursor']}

active_border_color     {p['accent']}
inactive_border_color   {p['surface2']}
bell_border_color       {p['warning']}

active_tab_foreground   {bg}
active_tab_background   {p['accent']}
inactive_tab_foreground {fg}
inactive_tab_background {p['mantle']}
tab_bar_background      {p['mantle']}

color0  {p['surface']}
color8  {p['surface2']}
color1  {p['critical']}
color9  {p['critical']}
color2  {p['green']}
color10 {p['green']}
color3  {p['warning']}
color11 {p['warning']}
color4  {p['accent2']}
color12 {p['accent2']}
color5  {p['accent']}
color13 {p['accent']}
color6  {p['accent2']}
color14 {p['accent2']}
color7  {p['text']}
color15 {p['subtext']}
""")


# ----------------------------------------------------------- hypr-colors.conf
def write_hypr_colors(name, p):
    out = THEMES_DIR / name / "hypr-colors.conf"
    a = p["accent"].lstrip("#")
    a2 = p["accent2"].lstrip("#")
    s = p["surface2"].lstrip("#")
    out.write_text(f"""# {name} — generated, do not hand-edit
$borderActive1 = rgba({a}ee)
$borderActive2 = rgba({a2}ee)
$borderInactive = rgba({s}80)
""")


# ------------------------------------------------------------------ dunstrc
def write_dunstrc(name, p):
    out = THEMES_DIR / name / "dunstrc"
    out.write_text(f"""# {name} — generated, do not hand-edit
[global]
    monitor = 0
    follow = mouse
    width = 300
    height = 300
    origin = top-right
    offset = 10x40
    scale = 0
    notification_limit = 5

    progress_bar = true
    progress_bar_height = 10
    progress_bar_frame_width = 1
    progress_bar_min_width = 150
    progress_bar_max_width = 300

    corner_radius = 12
    transparency = 10
    frame_width = 2
    frame_color = "{p['accent']}"

    font = JetBrainsMono Nerd Font 10
    line_height = 2
    markup = full
    format = "<b>%s</b>\\n%b"
    alignment = left
    vertical_alignment = center
    show_age_threshold = 60
    ellipsize = middle
    ignore_newline = no
    stack_duplicates = true
    hide_duplicate_count = false
    show_indicators = yes

    icon_position = left
    min_icon_size = 32
    max_icon_size = 48

    sort = yes
    idle_threshold = 120

[urgency_low]
    background = "{p['base']}"
    foreground = "{p['text']}"
    timeout = 5

[urgency_normal]
    background = "{p['base']}"
    foreground = "{p['text']}"
    timeout = 8

[urgency_critical]
    background = "{p['base']}"
    foreground = "{p['critical']}"
    frame_color = "{p['critical']}"
    timeout = 0
""")


# --------------------------------------------------------------- wallpaper
def gen_wallpaper(name, p, w=1920, h=1080, seed=0):
    random.seed(hash(name) & 0xffff)
    base = hex_to_rgb(p["base"])
    mantle = hex_to_rgb(p["mantle"])
    accent = hex_to_rgb(p["accent"])
    accent2 = hex_to_rgb(p["accent2"])
    text = hex_to_rgb(p["text"])

    img = Image.new("RGB", (w, h), base)
    draw = ImageDraw.Draw(img)

    # Sky gradient: mantle (top) -> base (mid) -> accent-tinted horizon glow
    horizon_glow = lerp(base, accent, 0.35 if p["dark"] else 0.15)
    for y in range(h):
        t = y / h
        if t < 0.7:
            c = lerp(mantle, base, t / 0.7)
        else:
            c = lerp(base, horizon_glow, (t - 0.7) / 0.3)
        draw.line([(0, y), (w, y)], fill=c)

    # Stars (only for dark themes)
    if p["dark"]:
        for _ in range(220):
            x = random.randint(0, w - 1)
            y = random.randint(0, int(h * 0.55))
            r = random.choice([1, 1, 1, 2])
            b = random.uniform(0.3, 1.0)
            col = lerp(base, text, b)
            draw.ellipse([x - r, y - r, x + r, y + r], fill=col)

    # Glowing moon/sun
    moon_x, moon_y, moon_r = int(w * 0.78), int(h * 0.28), 90
    glow = Image.new("RGB", (w, h), base)
    gdraw = ImageDraw.Draw(glow)
    gdraw.ellipse([moon_x - moon_r, moon_y - moon_r, moon_x + moon_r, moon_y + moon_r], fill=accent2)
    glow = glow.filter(ImageFilter.GaussianBlur(70))
    img = Image.blend(img, glow, 0.55)
    draw = ImageDraw.Draw(img)
    draw.ellipse([moon_x - moon_r, moon_y - moon_r, moon_x + moon_r, moon_y + moon_r], fill=accent)

    # Layered mountain silhouettes (parallax look)
    layers = [
        (0.62, lerp(base, mantle, 0.2), 6),
        (0.72, lerp(mantle, (0, 0, 0), 0.15) if p["dark"] else lerp(base, mantle, 0.5), 5),
        (0.85, mantle, 4),
    ]
    for base_y_frac, color, peaks in layers:
        base_y = int(h * base_y_frac)
        pts = [(0, h)]
        step = w / peaks
        for i in range(peaks + 1):
            x = int(i * step)
            jitter = random.randint(-int(h * 0.06), int(h * 0.10))
            pts.append((x, base_y - jitter - int(h * 0.05)))
        pts.append((w, h))
        draw.polygon(pts, fill=color)

    # Subtle accent-colored fog band near the base
    fog = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    fdraw = ImageDraw.Draw(fog)
    fdraw.rectangle([0, int(h * 0.8), w, h], fill=(*accent, 30))
    img = Image.alpha_composite(img.convert("RGBA"), fog).convert("RGB")

    img = img.filter(ImageFilter.SMOOTH)
    out_path = WALL_DIR / f"{name}.png"
    img.save(out_path, "PNG", optimize=True)
    print(f"wrote {out_path} ({img.size[0]}x{img.size[1]})")


def main():
    for name, p in PALETTES.items():
        write_waybar_wofi_colors(name, p)
        write_eww_colors(name, p)
        write_kitty_theme(name, p)
        write_hypr_colors(name, p)
        write_dunstrc(name, p)
        gen_wallpaper(name, p)
    print(f"\nGenerated {len(PALETTES)} themes: {', '.join(PALETTES)}")


if __name__ == "__main__":
    main()
