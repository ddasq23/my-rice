#!/usr/bin/env bash
# ~/.config/hypr/scripts/pkg-menu.sh   (SUPER+SHIFT+I)
#
# Floating installer popup. Runs inside `kitty --class pkg-menu` (see the
# window rule in hyprland.conf). Search + install from official repos and the
# AUR, remove installed packages, or update everything — no browser needed.
#
#   Install   : type 2+ letters, TAB to multi-select, ENTER to install
#   Remove    : pick installed packages (TAB multi-select) -> pacman -Rns
#   Update    : full upgrade of repos + AUR (yay -Syu)
#
# AUR helper: yay (bootstrapped from the AUR if neither yay nor paru exists).

set -uo pipefail

SCRIPTS="$HOME/.config/hypr/scripts"

pause() { echo; read -rp "Press ENTER to close..." _; }

ensure_helper() {
    if command -v yay >/dev/null 2>&1; then echo yay; return; fi
    if command -v paru >/dev/null 2>&1; then echo paru; return; fi

    echo "==> No AUR helper found. Installing yay-bin from the AUR..."
    sudo pacman -S --needed --noconfirm git base-devel || return 1
    local tmp; tmp="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" || return 1
    (cd "$tmp/yay-bin" && makepkg -si) || return 1
    rm -rf "$tmp"
    echo yay
}

HELPER="$(ensure_helper)" || { echo "Could not install an AUR helper."; pause; exit 1; }

ACTION="$(printf '%s\n' \
    "Install / search packages" \
    "Remove installed packages" \
    "Update everything (repos + AUR)" \
    "Quit" \
  | fzf --prompt 'pkg ❯ ' --height 40% --reverse --border \
        --header 'Choose an action (ESC to quit)')"

case "$ACTION" in
    "Install / search packages")
        # fzf re-runs pkg-search.sh on every keystroke; --disabled stops fzf
        # from re-filtering, because the search itself is the filter.
        SEL="$(: | fzf --multi --disabled --delimiter $'\t' --with-nth 2.. \
                   --prompt 'search ❯ ' --height 90% --reverse --border \
                   --header 'TAB select · ENTER install · type 2+ letters' \
                   --bind "change:reload:$SCRIPTS/pkg-search.sh {q}")"
        [ -z "$SEL" ] && exit 0
        mapfile -t NAMES < <(printf '%s\n' "$SEL" | cut -f1)
        echo "==> Installing: ${NAMES[*]}"
        "$HELPER" -S --needed "${NAMES[@]}"
        echo "==> Install finished (exit $?)."
        pause
        ;;
    "Remove installed packages")
        # Name + description for every explicitly installed package.
        SEL="$(pacman -Qei 2>/dev/null | awk -F': ' '
                /^Name/        { n = $2 }
                /^Description/ { printf "%s\t%-30s %s\n", n, n, $2 }' \
              | fzf --multi --delimiter $'\t' --with-nth 2.. \
                    --prompt 'remove ❯ ' --height 90% --reverse --border \
                    --header 'TAB select · ENTER remove (pacman -Rns, also drops unneeded deps)')"
        [ -z "$SEL" ] && exit 0
        mapfile -t NAMES < <(printf '%s\n' "$SEL" | cut -f1)
        echo "==> Removing: ${NAMES[*]}"
        sudo pacman -Rns "${NAMES[@]}"
        echo "==> Remove finished (exit $?)."
        pause
        ;;
    "Update everything (repos + AUR)")
        "$HELPER" -Syu
        echo "==> Update finished (exit $?)."
        pause
        ;;
    *)
        exit 0
        ;;
esac
