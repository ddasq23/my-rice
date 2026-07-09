# Hyprland Rice

A modular Hyprland setup with 6 bundled themes, a live-tunable Control
Center, an Eww sidebar, and a fully scripted theme switcher — no compositor
restarts required to change anything.

## What's included
- `hypr/hyprland.conf` — main config, keybinds, **layered smooth animations**, borders
- `hypr/colors.conf` — active border-color variables (overwritten on theme switch)
- `hypr/hyprpaper.conf` — wallpaper daemon
- `hypr/hyprlock.conf` — lockscreen
- `waybar/config.jsonc` + `waybar/style.css` + `waybar/colors.css` — status bar
- `wofi/config` + `wofi/style.css` + `wofi/colors.css` — app launcher
- `kitty/kitty.conf` + `kitty/theme.conf` — terminal
- `dunst/dunstrc` — notifications
- `eww/` — sidebar (network, Bluetooth, power plan, Pomodoro, theme picker)
  **and Control Center** (gaps, borders, blur, opacity, animation speed,
  layout, keybind reference)
- `hypr/user-settings.conf` — live tunables, edited by the Control Center
- `hypr/anim-profiles/` — Smooth / Snappy / Off animation presets
- `scripts/term-clock.sh` — floating terminal clock (tty-clock)
- `scripts/theme-switch.sh` / `scripts/theme-picker.sh` — theme system
- `themes/` — 6 bundled themes, each with its own colors for every app
- `wallpapers/` — one procedurally generated wallpaper per theme (original
  art, not scraped — see note below)
- `generate_theme_assets.py` — regenerates every theme file + wallpaper; run
  it again after tweaking a palette in the script

## Install (Arch / Fedora both fine)

```bash
# Arch
sudo pacman -S hyprland waybar wofi kitty dunst hyprpaper hyprlock eww \
  grim slurp wl-clipboard cliphist ttf-jetbrains-mono-nerd pipewire wireplumber \
  networkmanager bluez bluez-utils power-profiles-daemon tty-clock

# Fedora
sudo dnf install hyprland waybar wofi kitty dunst hyprpaper hyprlock eww \
  grim slurp wl-clipboard cliphist jetbrains-mono-fonts-all \
  NetworkManager bluez power-profiles-daemon tty-clock
```
`eww` and `tty-clock` aren't always in default repos — grab `eww` from
https://github.com/elkowar/eww if your package manager doesn't have it.

Then copy each folder into `~/.config/`:

```bash
cp -r hypr waybar wofi kitty dunst eww scripts ~/.config/
chmod +x ~/.config/eww/scripts/*.sh ~/.config/scripts/*.sh
```

## Before you launch
1. Drop a wallpaper at `~/Pictures/wallpapers/mocha.png` (or edit the path in
   `hypr/hyprpaper.conf` / `hyprlock.conf`). Catppuccin's official wallpaper
   pack: https://github.com/catppuccin/wallpapers
2. Install the Catppuccin Mocha cursor theme (`Catppuccin-Mocha-Dark-Cursors`)
   via your package manager or from
   https://github.com/catppuccin/cursors — otherwise remove that line from
   `hyprland.conf`.
3. Make sure `nautilus` and `firefox` exist, or swap `$fileManager` /
   `$browser` in `hyprland.conf` for whatever you actually use.

## Key binds
| Combo | Action |
|---|---|
| Super + Return | Terminal |
| Super + R | App launcher |
| Super + Q | Close window |
| Super + E | File manager |
| Super + V | Toggle floating |
| Super + F | Fullscreen |
| Super + L | Lock screen |
| Super + A | Toggle sidebar (network/BT/power/pomodoro/themes) |
| Super + T | Theme picker (wofi menu) |
| Super + I | Control Center (gaps/borders/blur/animations/layout) |
| Super + C | Toggle floating terminal clock |
| Super + Shift + V | Clipboard history |
| Super + 1-0 | Switch workspace |
| Super + Shift + 1-0 | Move window to workspace |

Everything is modular — swap the accent color (`#cba6f7`, mauve) for any
other Catppuccin accent (blue `#89b4fa`, pink `#f5c2e7`, green `#a6e3a1`)
by editing `waybar/colors.css` and the matching values in `eww/eww.scss`.

## Control Center — customize without touching dotfiles

`Super+I` opens a panel with five tabs:

- **General** — gaps in/out, border size, rounding, plus one-click presets
  (Compact / Cozy / Spacious)
- **Effects** — blur toggle + size, active/inactive window opacity
- **Motion** — animation profile: Smooth (default), Snappy (fast, minimal
  overshoot), or Off (for weak GPUs)
- **Layout** — Dwindle (BSP tiling) vs Master (one big window + stack)
- **Keys** — read-only keybind reference so you don't have to open
  `hyprland.conf` to remember a shortcut

**"Reset to defaults"** at the bottom puts everything back to the values
this rice ships with.

How it applies changes: every tab except Motion uses `hyprctl keyword` to
push the change straight to the running compositor — no reload, no
flicker — and simultaneously rewrites `hypr/user-settings.conf` so it
survives a reboot. Motion is the one exception: swapping animation curves
needs a `hyprctl reload`, which is still fast, just not instant like the
others.

You'll never need to hand-edit `hyprland.conf` for any of this. If you
*do* want to add more tunables later (window rules, gesture sensitivity,
whatever), the pattern to copy is: add a variable to `user-settings.conf`,
reference it with `$varName` in `hyprland.conf`, and add a case to
`eww/scripts/settings-set.sh`.



Themes: **Catppuccin Mocha, Catppuccin Latte** (light), **Nord, Gruvbox,
Dracula, Tokyo Night**. Switch with `Super+T` (wofi menu) or from the
sidebar's theme row (colored dots, `Super+A`).

Each theme carries its own colors for Waybar, Wofi, Eww, Kitty, Dunst, and
Hyprland's border gradient, plus a matching wallpaper — all pre-generated,
nothing is computed at switch time. `theme-switch.sh` just copies the
right files into place and pushes the change live:

- **Hyprland borders** — `hyprctl keyword` sets them directly on the running
  compositor. No reload, no flicker.
- **Wallpaper** — swapped via `hyprctl hyprpaper` IPC, not a restart.
- **Eww** — `eww reload` recompiles in place.
- **Waybar** — reload signal first, quick respawn as fallback.
- **Dunst** — respawns (no live-reload signal exists for it, but it's a
  sub-100ms process start so it's not noticeable).
- **Kitty** — new windows pick up the theme immediately; windows already
  open keep their colors until reopened (Kitty doesn't support hot theme
  swap unless you enable `allow_remote_control`).

None of this touches Hyprland's animation/layout config, so there's no
compositor restart and no stutter — the whole switch is copy-a-few-KB-of-
text-files plus a couple of IPC calls.

### Adding your own theme
Add a palette entry to `PALETTES` in `generate_theme_assets.py` and rerun
`python3 generate_theme_assets.py` — it regenerates every app's colors and a
matching wallpaper for the new theme automatically. It'll show up in the
`Super+T` menu and the sidebar as soon as the folder exists under `themes/`.

### About the wallpapers
The "official" Catppuccin wallpaper repo was taken down, and the community
forks that replaced it are grab-bags of unattributed images from random
corners of the internet — not something I'll bundle into your config. So
instead each theme gets an original, procedurally generated wallpaper
(gradient sky, layered mountains, glow) built from that theme's own palette
in `generate_theme_assets.py`. Swap in your own art anytime by dropping a
PNG at `wallpapers/<theme-name>.png`.
- Network toggle/data usage needs **NetworkManager** (`nmcli`) — if you use
  `iwd` or `systemd-networkd` instead, edit `eww/scripts/network.sh`.
- Bluetooth toggle needs **bluez** (`bluetoothctl`).
- Power-plan chips need **power-profiles-daemon** (`powerprofilesctl`) — most
  laptops have this; if `powerprofilesctl get` fails, that service isn't
  running (`systemctl enable --now power-profiles-daemon`).
- Pomodoro state lives in `/tmp/eww_pomodoro_state` and resets on reboot —
  that's intentional, it's a scratch file, not a database.

## License
No license has been chosen yet — until one is added, all rights are
reserved by default and others technically can't reuse this beyond viewing
it on GitHub. If you want people to freely copy/remix your rice (common for
dotfiles repos), consider adding an [MIT](https://choosealicense.com/licenses/mit/)
or [Unlicense](https://choosealicense.com/licenses/unlicense/) license —
GitHub can generate one for you when creating the repo, or via
**Add file → Create new file → LICENSE** and typing `license` to pick a
template.
