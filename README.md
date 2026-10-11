# my-rice — Hyprland rice for Arch

A modular Hyprland setup: eight complete themes that restyle everything at
once, a Performance Mode toggle, a fuzzy app menu whose colors follow your
wallpaper, a popup installer for official and AUR packages, and a Control
Center for live tuning. Nothing needs a reboot to change.

> **Supported system: Arch Linux and Arch-based distributions only**
> (EndeavourOS, Manjaro, CachyOS, Garuda, …). Other distributions are not
> supported, and `install.sh` refuses to run on them.

## Screenshots

<!-- Add screenshots here, e.g. ![Desktop](docs/screenshots/desktop.png) -->
*Screenshots coming soon.*

---

## Requirements

- Arch or an Arch-based distro, installed and booting
- A normal user with `sudo` (don't run the installer as root)
- Internet access
- Hyprland is installed by the installer, but a working GPU driver is yours to set up

## Install

### One line (fresh install)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ddasq23/my-rice/main/install.sh)
```

### From a clone

```bash
git clone https://github.com/ddasq23/my-rice.git
cd my-rice
./install.sh            # full install
```

Then **log out and back in** and pick the Hyprland session (or reboot).

### Installer options

| Flag | Effect |
|---|---|
| `--minimal` | Only the required packages (skips the `[extras]` sections) |
| `--no-backup` | Don't back up existing configs before replacing them |
| `--themes-only` | Only copy themes, wallpapers and scripts, then apply the theme |
| `--no-packages` | Skip package installs and services (copy + theme only) |
| `--dry-run` | Print every action and change nothing |

`install.sh` is safe to re-run. It stops with a message on the first failed
step, and it prints the log path (`~/.cache/my-rice-install.log`).

### Manual install

1. Install the packages in `packages.txt` (see the commands below).
2. Copy the folders into `~/.config`:
   ```bash
   for d in hypr waybar wofi kitty dunst eww scripts themes wallpapers fuzzel gtk-3.0 gtk-4.0 qt5ct; do
     mkdir -p ~/.config/$d && cp -r $d/. ~/.config/$d/
   done
   cp current_theme ~/.config/
   chmod +x ~/.config/scripts/*.sh ~/.config/scripts/*.py ~/.config/hypr/scripts/*.sh ~/.config/eww/scripts/*.sh
   ```
3. Enable services: `sudo systemctl enable --now NetworkManager bluetooth power-profiles-daemon`
4. Apply the theme: `~/.config/scripts/theme-switch.sh catppuccin-mocha`

### What gets installed

The full list is in [`packages.txt`](packages.txt). Edit that file to add or remove packages.

| Section | Contents |
|---|---|
| `[base]` (official) | hyprland, xdg-desktop-portal-hyprland/gtk, waybar, kitty, dunst, libnotify, hyprpaper, hyprlock, fuzzel, papirus-icon-theme, grim, slurp, wl-clipboard, cliphist, ttf-jetbrains-mono-nerd, adwaita-icon-theme, pipewire(+pulse), wireplumber, networkmanager, bluez(+utils), power-profiles-daemon, brightnessctl, playerctl, qt5ct, python, jq, fzf, curl, git, base-devel |
| `[aur]` (required) | python-pywal (wallpaper colors), python-colorthief (its backend), eww (sidebar) |
| `[extras]` (optional) | wofi, tty-clock, pavucontrol, nautilus, firefox, python-pillow |
| `[extras-aur]` (optional) | bibata-cursor-theme, catppuccin-cursors-mocha, catppuccin-cursors-latte |

Packages in `[base]` and `[aur]` are installed by `yay` (or `paru`). `yay` is
built from the AUR if you have neither. You can also install the list by hand:

```bash
sudo pacman -S --needed hyprland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk waybar kitty dunst libnotify hyprpaper hyprlock fuzzel papirus-icon-theme grim slurp wl-clipboard cliphist ttf-jetbrains-mono-nerd adwaita-icon-theme pipewire pipewire-pulse wireplumber networkmanager bluez bluez-utils power-profiles-daemon brightnessctl playerctl qt5ct python jq fzf curl git base-devel
yay -S --needed python-pywal python-colorthief eww
```

---

## Features

### Performance Mode — `SUPER+SHIFT+P` or click the Waybar icon

Turns off blur, shadows, animations, transparency, rounded corners and gaps
through `hyprctl --batch keyword`. There's no reload, so it switches instantly.
It also swaps Waybar to a lighter config without the CPU and memory modules,
and sets the power profile to `performance` through power-profiles-daemon,
which needs no root.

- **ON** shows `󰓅 PERF` in the bar (highlighted). **OFF** shows `󰾆 NORMAL`.
- **OFF** restores your values from `hypr/user-settings.conf` and your active
  animation profile, so you get your normal visuals back.
- The state is saved in `~/.local/state/rice/performance` and survives reboots.
  It's re-applied at login.
- Power profile: the profile you had before is restored on OFF.

Files: `hypr/scripts/performance-mode.sh`, `hypr/scripts/waybar-launch.sh`,
`waybar/config-performance.jsonc`.

Limitation: kitty's background opacity isn't changed. Kitty only reloads its
config on restart.

### Themes — `SUPER+T` or the sidebar dots

Eight themes ship in `themes/`: **Catppuccin Mocha, Catppuccin Latte, Nord,
Gruvbox, Dracula, Tokyo Night, Rosé Pine, and AMOLED** (pure black, for OLED).

A theme switch changes all of these at once:

- Hyprland borders and the cursor
- Waybar, wofi, Eww, kitty, dunst
- the app menu (fuzzel)
- GTK 3/4 colors and the dark/light hint
- Qt colors (qt5ct)
- the wallpaper (`wallpapers/<theme>.png`)

```bash
~/.config/scripts/theme-switch.sh nord    # apply a theme
~/.config/scripts/theme-switch.sh --list  # list themes
```

Each theme is one file: `themes/<name>/palette.conf`. It contains named colors,
the 16 ANSI colors, the cursor theme, and the default wallpaper. Every app's
config is rendered from it by `scripts/theme-render.py` using the templates in
`themes/templates/`. You never edit the generated files.

#### Add your own theme

```bash
cp -r ~/.config/themes/nord ~/.config/themes/my-theme
$EDITOR ~/.config/themes/my-theme/palette.conf   # change the colors; set wallpaper = my-theme.png
cp my-wallpaper.png ~/.config/wallpapers/my-theme.png
~/.config/scripts/theme-switch.sh my-theme
```

It appears in the `SUPER+T` menu as soon as its folder exists. To add it to the
sidebar's colored dots, add a `theme-dot` line in `eww/eww.yuck`.

Cursor themes come from the AUR. If the named cursor theme isn't installed,
the rice falls back to Adwaita and tells you so.

**Colors from theme vs. from wallpaper** — `SUPER+SHIFT+C` or the `⇄` row in the
`SUPER+T` menu. Wallpaper mode runs pywal on the current wallpaper and uses the
result for every app's colors. Changing the wallpaper then recolors everything.
The choice is saved in `~/.local/state/rice/color-source`.

Set a new wallpaper with `~/.config/hypr/scripts/wallpaper-set.sh <image>`.

### App installer — `SUPER+SHIFT+I`

A floating terminal with a fuzzy-search popup over the official repos and the AUR.

1. Pick **Install / search**. Type 2+ letters. The results come from `pacman`
   and the AUR RPC. Each line shows the source, version, AUR votes, and
   popularity, plus the description.
2. `TAB` to select one or more packages, then `ENTER`. The helper (yay) shows
   its progress in the terminal.
3. **Remove installed packages** lists explicitly installed packages with their
   descriptions. Selected packages are removed with `pacman -Rns`.
4. **Update everything** runs `yay -Syu`, which covers the repos and the AUR.

Files: `hypr/scripts/pkg-menu.sh`, `hypr/scripts/pkg-search.sh`.

### App menu — `SUPER+R`

**fuzzel** is the launcher. I picked it over wofi (GTK, noticeably slower to
start) and rofi-wayland (heavier, and needs more configuration). It's a single
small Wayland binary. It starts in milliseconds, has built-in fuzzy matching,
and shows icons from Papirus.

Its colors are rendered from the active palette: the theme's colors, or the
wallpaper's colors when the color source is `wallpaper`. Every switch
regenerates `fuzzel/fuzzel.ini`, the Waybar CSS, and the border colors.

Color extraction uses **pywal** (`wal --backend colorthief`). It's pure Python,
without ImageMagick. The extracted accents are checked by hue, and the theme's
values are used as a fallback.

### Control Center — `SUPER+I`

Live tuning for gaps, borders, rounding, blur, opacity, layout and animation
profile. Changes apply instantly and are saved to `hypr/user-settings.conf`. If
you change something while Performance Mode is on, the value is saved and
applies when you turn it off.

---

## Keybind cheat sheet

`SUPER` = Windows key.

| Keys | Action |
|---|---|
| `SUPER + Return` | Terminal (kitty) |
| `SUPER + R` | App menu (fuzzel) |
| `SUPER + T` | Theme picker (+ color source toggle) |
| `SUPER + SHIFT + C` | Colors from **theme ⇄ wallpaper** |
| `SUPER + SHIFT + I` | **App installer** (install / remove / update) |
| `SUPER + SHIFT + P` | **Performance Mode** on/off |
| `SUPER + I` | Control Center (gaps, blur, animations, layout) |
| `SUPER + A` | Sidebar (network, Bluetooth, power, Pomodoro, themes) |
| `SUPER + C` | Floating terminal clock |
| `SUPER + SHIFT + V` | Clipboard history |
| `SUPER + SHIFT + U` | Pull the latest rice from GitHub (OTA) |
| `SUPER + L` | Lock screen |
| `SUPER + Q` | Close window |
| `SUPER + E` | File manager |
| `SUPER + B` | Browser |
| `SUPER + V` | Toggle floating |
| `SUPER + F` | Fullscreen |
| `SUPER + P` / `SUPER + J` | Pseudo-tile / toggle split |
| `SUPER + M` | Exit Hyprland |
| `SUPER + arrows` | Move focus |
| `SUPER + 1…0` | Switch workspace |
| `SUPER + SHIFT + 1…0` | Move window to workspace |
| `SUPER + S` / `SUPER + SHIFT + S` | Scratchpad show / send |
| `SUPER + drag` | Move / resize window (mouse) |
| `Print` / `SUPER + Print` | Screenshot region / full screen → clipboard |

> `SUPER + I` is the Control Center, so the app installer uses `SUPER + SHIFT + I`.

---

## Troubleshooting

**Install stops at a package.** Fix the reported package or mirror problem and
re-run `./install.sh`. It's safe to repeat. Check `~/.cache/my-rice-install.log`.
If an AUR package fails to build, run `yay -Syu` first and re-run.

**`yay` is missing.** Install it by hand: `git clone https://aur.archlinux.org/yay-bin.git && cd yay-bin && makepkg -si`.

**Wallpaper colors don't apply / "pywal not installed".** Run
`yay -S --needed python-pywal python-colorthief`. Then toggle again with `SUPER + SHIFT + C`.

**Cursor is Adwaita, not the theme's cursor.** Install the cursor package for
that theme, e.g. `yay -S bibata-cursor-theme`, then switch the theme again.

**Qt apps don't match the theme.** In `qt5ct` (run `qt5ct`), set Appearance →
Color scheme path to `~/.config/qt5ct/colors/rice.conf`. The installer does this
automatically only when `qt5ct.conf` doesn't exist yet.

**Performance Mode is stuck on.** Run
`~/.config/hypr/scripts/performance-mode.sh off`, or delete
`~/.local/state/rice/performance`.

**Waybar missing after a theme switch.** Run `pkill waybar; ~/.config/hypr/scripts/waybar-launch.sh`. Check the config with `waybar -l debug` in a terminal.

**Wallpaper resets after reboot.** Fixed in this version: `hyprpaper.conf` is
rewritten on each wallpaper change. If it's still wrong, check
`~/.local/state/rice/wallpaper`.

**NetworkManager conflicts with iwd or systemd-networkd.** Use one network
manager. The network widget uses `nmcli`.

**`theme-switch` isn't found.** Add `~/.local/bin` to your PATH, or call the full path `~/.config/scripts/theme-switch.sh`.

**Kitty windows keep the old colors.** Only new windows pick up the change.
Open a new window, or restart kitty.

---

## Uninstall and rollback

Every time `install.sh` replaces files, it first copies the folders that
differ into `~/.config-backup-<date>`. Each backup has a `RESTORE.txt`.

**Roll back to the previous configs:**

```bash
ls -d ~/.config-backup-*                       # pick a backup
cp -a ~/.config-backup-20261011-223140/. ~/.config/
```

**Turn off the rice but keep your system:**

```bash
rm -f ~/.local/bin/theme-switch
systemctl --user disable --now rice-ota.timer 2>/dev/null
rm -rf ~/.local/state/rice
```

Then restore a backup as above. Packages are left installed. Remove them with
`sudo pacman -Rns <name>`, or use the app installer's remove menu.

**Auto-update (optional, off by default):** `scripts/rice-ota.timer` can check
GitHub daily. Disable it with `systemctl --user disable --now rice-ota.timer`.

---

## Customizing without touching dotfiles

- **Gaps, blur, opacity, layout, animations:** Control Center (`SUPER + I`).
- **Colors:** edit `themes/<name>/palette.conf`, then `theme-switch.sh <name>`.
- **Packages:** edit `packages.txt`.
- **Wallpapers:** drop a PNG in `wallpapers/` and set `wallpaper = <file>` in the palette.

Files that are generated on every theme switch (don't edit these):
`hypr/colors.conf`, `hypr/hyprpaper.conf`, `waybar/colors.css`,
`wofi/colors.css`, `eww/colors.scss`, `kitty/theme.conf`, `dunst/dunstrc`,
`fuzzel/fuzzel.ini`, `gtk-3.0/gtk.css`, `gtk-4.0/gtk.css`, `qt5ct/colors/rice.conf`.

Older per-theme files (`themes/<name>/colors.css`, `kitty-theme.conf`, …) are
no longer read. `generate_theme_assets.py` still generates the wallpaper art.

## License

No license has been chosen yet. Until one is added, all rights are reserved
by default.
