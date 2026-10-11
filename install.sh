#!/usr/bin/env bash
# install.sh — installs my-rice (Hyprland rice) on Arch or an Arch-based distro.
#
# Usage (from a clone of the repo):
#   ./install.sh [options]
# One-liner (fresh Arch install):
#   bash <(curl -fsSL https://raw.githubusercontent.com/ddasq23/my-rice/main/install.sh)
#
# Options:
#   --minimal       install only [base] + [aur] from packages.txt (no extras)
#   --no-backup     don't back up existing configs before replacing them
#   --themes-only   only copy themes/wallpapers/scripts and apply the theme
#   --no-packages   skip package installs and system services
#   --auto-update   enable the daily GitHub Release updater (off by default)
#   --dry-run       print every action, change nothing
#   -h, --help      show this help
#
# What it does (in order):
#   1. checks it's Arch (or Arch-based) and not running as root
#   2. installs base tools (git, base-devel, jq, curl)
#   3. installs yay (or uses paru) and every package in packages.txt
#   4. backs up existing configs that differ from mine -> ~/.config-backup-<date>
#   5. copies the dotfiles into ~/.config (and links `theme-switch`)
#   6. enables NetworkManager, bluetooth and power-profiles-daemon
#   7. creates the Qt palette config and applies the default theme + wallpaper
#   8. prints a summary — then log out and back in
#
# Safe to re-run: packages use --needed, files are overwritten with the repo
# version, a backup is only made when something actually differs, and services
# are only enabled when they aren't already.
# Environment overrides (mostly for testing): RICE_REPO_URL, RICE_REPO_BRANCH,
# RICE_OS_RELEASE_FILE, HOME.

set -Eeuo pipefail

# ----------------------------------------------------------------- settings
REPO_URL="${RICE_REPO_URL:-https://github.com/ddasq23/my-rice.git}"
REPO_BRANCH="${RICE_REPO_BRANCH:-main}"
OS_RELEASE_FILE="${RICE_OS_RELEASE_FILE:-/etc/os-release}"
CFG="$HOME/.config"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/.config-backup-$STAMP"
LOG_FILE="$HOME/.cache/my-rice-install.log"
BACKUP_MADE=0

# Folders this rice owns inside ~/.config (copied over, backed up first).
RICE_DIRS=(hypr waybar wofi kitty dunst eww scripts themes wallpapers fuzzel gtk-3.0 gtk-4.0 qt5ct)
THEME_DIRS=(themes wallpapers scripts)   # what --themes-only touches

MINIMAL=0; NO_BACKUP=0; THEMES_ONLY=0; NO_PACKAGES=0; AUTO_UPDATE=0; DRY_RUN=0
AUTO_UPDATE_STATUS="off (opt-in)"
HELPER=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo /)"

# ------------------------------------------------------------------ output
if [ -t 1 ]; then
    RED=$'\e[31m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'; BLUE=$'\e[34m'
    BOLD=$'\e[1m'; DIM=$'\e[2m'; RST=$'\e[0m'
else
    RED=""; GREEN=""; YELLOW=""; BLUE=""; BOLD=""; DIM=""; RST=""
fi

step() { printf '\n%s==> %s%s\n' "$BOLD$BLUE" "$*" "$RST"; }
info() { printf '    %s\n' "$*"; }
ok()   { printf '    %s✔%s %s\n' "$GREEN" "$RST" "$*"; }
warn() { printf '    %s!%s %s\n' "$YELLOW" "$RST" "$*"; }
die()  { printf '\n%s✘ %s%s\n' "$RED$BOLD" "$*" "$RST" >&2; exit 1; }

# run CMD... : execute, or only print when --dry-run is set.
run() {
    if [ "$DRY_RUN" = 1 ]; then
        printf '    %s[dry-run]%s %s\n' "$DIM" "$RST" "$*"
    else
        "$@"
    fi
}

on_error() {
    local rc=$1 line=$2
    printf '\n%s✘ Installation stopped at line %s (exit code %s).%s\n' "$RED$BOLD" "$line" "$rc" "$RST" >&2
    printf '  Read the output above, fix the cause, then run install.sh again —\n' >&2
    printf '  it is safe to re-run. Full log: %s\n' "$LOG_FILE" >&2
    if [ "$BACKUP_MADE" = 1 ]; then
        printf '  Your previous configs are in: %s\n' "$BACKUP_DIR" >&2
    fi
    exit "$rc"
}
trap 'on_error $? $LINENO' ERR

usage() { sed -n '2,33p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//'; }

# ---------------------------------------------------------------- arguments
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --minimal)     MINIMAL=1 ;;
            --no-backup)   NO_BACKUP=1 ;;
            --themes-only) THEMES_ONLY=1; NO_PACKAGES=1 ;;
            --no-packages) NO_PACKAGES=1 ;;
            --auto-update) AUTO_UPDATE=1 ;;
            --dry-run)     DRY_RUN=1 ;;
            -h|--help)     usage; exit 0 ;;
            *) die "Unknown option: $1 (see --help)" ;;
        esac
        shift
    done
}

# ------------------------------------------------------------------- checks
check_system() {
    [ -r "$OS_RELEASE_FILE" ] || die "Can't read $OS_RELEASE_FILE — is this Linux?"
    local ID="" ID_LIKE=""
    # shellcheck disable=SC1090
    . "$OS_RELEASE_FILE"
    if [[ " $ID ${ID_LIKE:-} " != *" arch "* ]]; then
        die "Unsupported system: ${PRETTY_NAME:-$ID}.
  my-rice supports Arch Linux and Arch-based distributions only
  (EndeavourOS, Manjaro, CachyOS, Garuda, ...). Other distributions are not supported."
    fi
    command -v pacman >/dev/null 2>&1 || die "pacman not found — is this really an Arch-based system?"
    if [ "$(id -u)" -eq 0 ]; then
        die "Don't run this as root. Run it as your normal user — sudo is used where needed."
    fi
    ok "Arch-based system detected (${PRETTY_NAME:-$ID})"
}

# Read one section of packages.txt: read_section base -> prints package names.
read_section() {
    awk -v want="$1" '
        /^[[:space:]]*#/ { next }
        /^\[/ { sec = $0; gsub(/[][ ]/, "", sec); next }
        NF { gsub(/#.*/, ""); if ($1 != "" && sec == want) print $1 }
    ' "$SRC/packages.txt"
}

# ------------------------------------------------------------------- steps
ensure_base_tools() {
    step "[2/8] Base tools"
    run sudo pacman -S --needed --noconfirm git base-devel curl jq
    ok "git, base-devel, curl, jq"
}

ensure_helper() {
    step "[3/8] AUR helper"
    if command -v yay >/dev/null 2>&1; then HELPER=yay
    elif command -v paru >/dev/null 2>&1; then HELPER=paru
    else
        info "Neither yay nor paru found — building yay-bin from the AUR"
        HELPER=yay
        if [ "$DRY_RUN" = 1 ]; then
            run git clone https://aur.archlinux.org/yay-bin.git
            run makepkg -si --noconfirm
        else
            local tmp; tmp="$(mktemp -d)"
            git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
            (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
            rm -rf "$tmp"
        fi
    fi
    ok "Using AUR helper: $HELPER"
}

install_packages() {
    step "[3/8] Packages (from packages.txt)"
    local -a base aur extras extras_aur
    mapfile -t base < <(read_section base)
    mapfile -t aur < <(read_section aur)
    mapfile -t extras < <(read_section extras)
    mapfile -t extras_aur < <(read_section extras-aur)

    info "required: ${#base[@]} official + ${#aur[@]} AUR"
    if [ "${#base[@]}" -gt 0 ]; then run "$HELPER" -S --needed --noconfirm "${base[@]}"; fi
    if [ "${#aur[@]}" -gt 0 ]; then run "$HELPER" -S --needed --noconfirm "${aur[@]}"; fi
    ok "required packages installed"

    if [ "$MINIMAL" = 1 ]; then
        info "--minimal: skipping optional extras"
        return
    fi
    # Optional packages: a failure only warns, so one missing AUR name can't block the rice.
    if [ "$DRY_RUN" = 1 ]; then
        run "$HELPER" -S --needed --noconfirm "${extras[@]}" "${extras_aur[@]}"
    else
        if [ "${#extras[@]}" -gt 0 ] && ! "$HELPER" -S --needed --noconfirm "${extras[@]}"; then
            warn "some optional official packages failed — see the output above"
        fi
        if [ "${#extras_aur[@]}" -gt 0 ] && ! "$HELPER" -S --needed --noconfirm "${extras_aur[@]}"; then
            warn "some optional AUR packages failed (cursor themes are optional)"
        fi
    fi
    ok "optional extras processed"
}

check_commands() {
    local missing=() c
    for c in Hyprland waybar kitty fuzzel fzf jq python3 hyprctl; do
        command -v "$c" >/dev/null 2>&1 || missing+=("$c")
    done
    if [ "${#missing[@]}" -gt 0 ]; then
        warn "not found on PATH: ${missing[*]} (the rice needs these — check the package step)"
    else
        ok "all core commands are on PATH"
    fi
}

# Files rendered from themes/<name>/palette.conf. They are regenerated on every
# install/theme switch, so they never count as "your changes" on their own
# (a backup still copies them whenever a hand-written file in the folder differs).
GENERATED_FILES=(
    hypr/colors.conf hypr/hyprpaper.conf waybar/colors.css wofi/colors.css
    kitty/theme.conf dunst/dunstrc eww/colors.scss fuzzel/fuzzel.ini
    gtk-3.0/gtk.css gtk-4.0/gtk.css qt5ct/colors/rice.conf
)

# config_differs SRC DST REL: true (0) if a hand-written file shipped in the repo
# folder SRC is missing or different in DST.
config_differs() {
    local src="$1" dst="$2" rel="$3" f
    [ -e "$dst" ] || return 0
    while IFS= read -r -d '' f; do
        f="${f#./}"
        local skip=0 g
        for g in "${GENERATED_FILES[@]}"; do [ "$rel/$f" = "$g" ] && skip=1; done
        [ "$skip" = 1 ] && continue
        cmp -s "$src/$f" "$dst/$f" || return 0
    done < <(cd "$src" && find . -type f -print0)
    return 1
}

backup_existing() {
    step "[4/8] Backup existing configs"
    if [ "$NO_BACKUP" = 1 ]; then warn "--no-backup: existing configs will be overwritten without a copy"; return; fi
    local dirs=("${RICE_DIRS[@]}")
    [ "$THEMES_ONLY" = 1 ] && dirs=("${THEME_DIRS[@]}")
    local d made=0
    for d in "${dirs[@]}"; do
        local dst="$CFG/$d"
        [ -e "$dst" ] || continue
        # Only back up when a file I ship differs from what's on disk.
        if ! config_differs "$SRC/$d" "$dst" "$d"; then continue; fi
        run mkdir -p "$BACKUP_DIR"
        run cp -a "$dst" "$BACKUP_DIR/"
        made=1
        BACKUP_MADE=1
    done
    if [ "$made" = 1 ]; then
        ok "backed up to $BACKUP_DIR"
        if [ "$DRY_RUN" = 0 ]; then
            printf 'Restore with:  cp -a %s/. ~/.config/\n' "$BACKUP_DIR" > "$BACKUP_DIR/RESTORE.txt"
        fi
    else
        ok "nothing to back up (configs already match or don't exist yet)"
    fi
}

copy_dotfiles() {
    step "[5/8] Installing dotfiles into $CFG"
    local dirs=("${RICE_DIRS[@]}")
    [ "$THEMES_ONLY" = 1 ] && dirs=("${THEME_DIRS[@]}")
    local d
    for d in "${dirs[@]}"; do
        [ -d "$SRC/$d" ] || { warn "missing in repo: $d (skipped)"; continue; }
        run mkdir -p "$CFG/$d"
        run cp -r "$SRC/$d/." "$CFG/$d/"
    done
    # current_theme is only seeded once, so re-running never resets your choice.
    if [ ! -f "$CFG/current_theme" ]; then run cp "$SRC/current_theme" "$CFG/current_theme"; fi
    # Remember the install source for the release updater, but preserve a user's
    # existing choice when re-running the installer.
    if [ ! -f "$CFG/.rice-source" ]; then
        if [ "$DRY_RUN" = 1 ]; then
            info "[dry-run] remember update source: $REPO_URL"
        else
            printf '%s\n' "$REPO_URL" > "$CFG/.rice-source"
        fi
    fi

    run chmod +x "$CFG"/scripts/*.sh "$CFG"/scripts/*.py "$CFG"/hypr/scripts/*.sh 2>/dev/null || true
    [ -d "$CFG/eww/scripts" ] && run chmod +x "$CFG"/eww/scripts/*.sh 2>/dev/null || true

    run mkdir -p "$HOME/.local/bin"
    run ln -sfn "$CFG/scripts/theme-switch.sh" "$HOME/.local/bin/theme-switch"
    ok "dotfiles copied; 'theme-switch' linked into ~/.local/bin"
}

setup_qt() {
    local f="$CFG/qt5ct/qt5ct.conf"
    if [ -f "$f" ]; then
        ok "qt5ct.conf already exists — left untouched (see README → Themes → Qt)"
        return
    fi
    if [ "$DRY_RUN" = 1 ]; then
        printf '    %s[dry-run]%s write %s\n' "$DIM" "$RST" "$f"
        return
    fi
    mkdir -p "$(dirname "$f")"
    cat > "$f" <<EOF
# Created by my-rice install.sh. Qt colors come from the active theme.
[Appearance]
color_scheme_path=$CFG/qt5ct/colors/rice.conf
custom_palette=true
EOF
    ok "created qt5ct.conf (Qt apps follow the theme)"
}

enable_services() {
    step "[6/8] System services"
    if [ "$NO_PACKAGES" = 1 ]; then info "skipped (--no-packages / --themes-only)"; return; fi
    if ! command -v systemctl >/dev/null 2>&1; then warn "systemctl not found — skipping services"; return; fi
    local unit
    for unit in NetworkManager bluetooth power-profiles-daemon; do
        if ! systemctl list-unit-files "$unit.service" --no-legend 2>/dev/null | grep -q "$unit"; then
            warn "$unit.service not installed — skipped"
            continue
        fi
        if systemctl is-enabled --quiet "$unit" 2>/dev/null; then
            ok "$unit already enabled"
        else
            run sudo systemctl enable --now "$unit"
            ok "$unit enabled"
        fi
    done
    if systemctl is-active --quiet iwd 2>/dev/null || systemctl is-active --quiet systemd-networkd 2>/dev/null; then
        warn "iwd or systemd-networkd is active — NetworkManager may conflict. The rice's network widget uses nmcli."
    fi
}

setup_auto_update() {
    [ "$AUTO_UPDATE" = 1 ] || return 0
    step "Daily GitHub Release auto-update"
    if ! command -v systemctl >/dev/null 2>&1; then
        warn "systemctl not found — couldn't enable the release updater"
        return 0
    fi
    if [ ! -f "$SRC/scripts/rice-ota.service" ] || [ ! -f "$SRC/scripts/rice-ota.timer" ]; then
        warn "release updater systemd units are missing from the source"
        return 0
    fi

    local unit_dir="$HOME/.config/systemd/user"
    run mkdir -p "$unit_dir"
    run cp "$SRC/scripts/rice-ota.service" "$unit_dir/rice-ota.service"
    run cp "$SRC/scripts/rice-ota.timer" "$unit_dir/rice-ota.timer"
    if ! run systemctl --user daemon-reload; then
        warn "couldn't reload the user systemd manager; enable rice-ota.timer after logging in"
        return 0
    fi
    if ! run systemctl --user enable --now rice-ota.timer; then
        warn "couldn't enable the timer; run 'systemctl --user enable --now rice-ota.timer' after logging in"
        return 0
    fi
    if [ "$DRY_RUN" = 1 ]; then
        AUTO_UPDATE_STATUS="would enable"
        ok "would enable daily GitHub Release checks"
    else
        AUTO_UPDATE_STATUS="enabled"
        ok "daily GitHub Release checks enabled"
    fi
}

apply_theme() {
    step "[7/8] Default theme + wallpaper"
    local theme
    theme="$(cat "$CFG/current_theme" 2>/dev/null || echo catppuccin-mocha)"
    if [ ! -f "$CFG/themes/$theme/palette.conf" ]; then
        warn "theme '$theme' not found — falling back to catppuccin-mocha"
        theme=catppuccin-mocha
        run bash -c "echo $theme > '$CFG/current_theme'"
    fi
    # Renders every app's colors + sets the wallpaper. Works without a running
    # session too: live steps are skipped and apply at login.
    run "$CFG/scripts/theme-switch.sh" "$theme"
    ok "theme '$theme' applied (wallpaper + colors)"
}

summary() {
    step "[8/8] Done"
    local theme; theme="$(cat "$CFG/current_theme" 2>/dev/null || echo '?')"
    cat <<EOF
    ${GREEN}my-rice is installed.${RST}

    Theme        : $theme   (change with SUPER+T)
    Packages     : $([ "$NO_PACKAGES" = 1 ] && echo skipped || echo "from packages.txt (minimal=$MINIMAL)")
    Backup       : $([ "$BACKUP_MADE" = 1 ] && echo "$BACKUP_DIR" || echo "none needed")
    Auto-update  : $AUTO_UPDATE_STATUS
    Log          : $LOG_FILE

    ${BOLD}Next:${RST}
      1. Log out, then log back in and pick the Hyprland session
         (or reboot). Cursor, Qt and the Hyprland env vars load at login.
      2. Try: SUPER+R app menu · SUPER+T themes · SUPER+SHIFT+I app installer
              SUPER+SHIFT+P performance mode · SUPER+SHIFT+C color source

    Full cheat sheet and troubleshooting: README.md
EOF
}

# -------------------------------------------------------------------- main
main() {
    parse_args "$@"
    mkdir -p "$(dirname "$LOG_FILE")"
    check_system
    # Running from the one-liner: there is no repo next to this script yet.
    if [ ! -f "$SCRIPT_DIR/hypr/hyprland.conf" ] && [ -z "${RICE_SRC:-}" ]; then
        step "Fetching my-rice"
        if ! command -v git >/dev/null 2>&1; then
            run sudo pacman -S --needed --noconfirm git
        fi
        local tmp; tmp="$(mktemp -d)"
        git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" "$tmp/my-rice"
        export RICE_SRC="$tmp/my-rice"
        exec bash "$tmp/my-rice/install.sh" "$@"
    fi
    SRC="${RICE_SRC:-$SCRIPT_DIR}"
    [ -f "$SRC/hypr/hyprland.conf" ] || die "Repo files not found in $SRC"
    [ "$DRY_RUN" = 1 ] && warn "DRY RUN — nothing will be changed"

    # Everything below is logged to $LOG_FILE as well as shown on screen.
    exec > >(tee -a "$LOG_FILE") 2>&1

    step "[1/8] System check"
    ok "repo: $SRC"

    if [ "$THEMES_ONLY" = 0 ] && [ "$NO_PACKAGES" = 0 ]; then
        ensure_base_tools
        ensure_helper
        install_packages
        check_commands
    else
        step "[2-3/8] Packages"
        info "skipped (--themes-only / --no-packages)"
    fi

    backup_existing
    copy_dotfiles
    setup_qt
    enable_services
    apply_theme
    setup_auto_update
    summary
}

main "$@"
