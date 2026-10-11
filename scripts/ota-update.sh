#!/usr/bin/env bash
# Install the latest published GitHub Release of this rice.
#
# Usage:
#   ota-update.sh [--check] [--force] [--quiet] [<github-repo-url>]
#
# With no URL, use ~/.config/.rice-source, then the official repository. Passing
# a URL once remembers it. Only published, non-prerelease GitHub Releases are
# installed; the updater never pulls untagged changes from the default branch.

set -Eeuo pipefail

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
SRC_FILE="$CFG/.rice-source"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/rice"
VERSION_FILE="$STATE_DIR/release-version"
DEFAULT_REPO_URL="${RICE_DEFAULT_REPO_URL:-https://github.com/ddasq23/my-rice.git}"

REPO_ARG=""
CHECK_ONLY=0
FORCE=0
QUIET=0

usage() {
    cat <<'EOF'
Usage: ota-update.sh [options] [github-repo-url]

Checks GitHub Releases and installs the latest published release. A repository
URL may be supplied once and is then remembered in ~/.config/.rice-source.

Options:
  --check   Check whether a newer release is available without installing it
  --force   Reinstall the latest release even if its tag is already installed
  --quiet   Suppress normal output (used by the systemd timer)
  -h, --help
EOF
}

say() {
    [ "$QUIET" = 1 ] || printf '==> %s\n' "$*"
}

warn() {
    printf 'Rice OTA: %s\n' "$*" >&2
}

die() {
    warn "$*"
    exit 1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --check) CHECK_ONLY=1 ;;
        --force) FORCE=1 ;;
        --quiet) QUIET=1 ;;
        -h|--help) usage; exit 0 ;;
        --*) die "Unknown option: $1 (see --help)" ;;
        *)
            [ -z "$REPO_ARG" ] || die "Only one repository URL may be supplied."
            REPO_ARG="$1"
            ;;
    esac
    shift
done

if [ -n "$REPO_ARG" ]; then
    REPO_URL="$REPO_ARG"
elif [ -n "${RICE_REPO_URL:-}" ]; then
    REPO_URL="$RICE_REPO_URL"
elif [ -s "$SRC_FILE" ]; then
    IFS= read -r REPO_URL < "$SRC_FILE" || true
else
    REPO_URL="$DEFAULT_REPO_URL"
fi

# Accept normal GitHub HTTPS/SSH clone URLs, and reject arbitrary URLs before
# using the repository name to construct an API request.
case "$REPO_URL" in
    https://github.com/*|http://github.com/*)
        REPO_SLUG="${REPO_URL#*://github.com/}"
        ;;
    ssh://git@github.com/*)
        REPO_SLUG="${REPO_URL#ssh://git@github.com/}"
        ;;
    git@github.com:*)
        REPO_SLUG="${REPO_URL#git@github.com:}"
        ;;
    *)
        die "Only GitHub repository URLs are supported (got: $REPO_URL)."
        ;;
esac
REPO_SLUG="${REPO_SLUG%%\?*}"
REPO_SLUG="${REPO_SLUG%%#*}"
REPO_SLUG="${REPO_SLUG%/}"
REPO_SLUG="${REPO_SLUG%.git}"
[[ "$REPO_SLUG" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || \
    die "Invalid GitHub repository URL: $REPO_URL"
REPO_OWNER="${REPO_SLUG%%/*}"
REPO_NAME="${REPO_SLUG#*/}"
[[ "$REPO_OWNER" != . && "$REPO_OWNER" != .. && "$REPO_NAME" != . && "$REPO_NAME" != .. ]] || \
    die "Invalid GitHub repository URL: $REPO_URL"

# Remember an explicitly supplied repository, preserving older command usage.
if [ -n "$REPO_ARG" ]; then
    mkdir -p "$CFG"
    printf '%s\n' "$REPO_URL" > "$SRC_FILE"
fi

for cmd in curl jq tar flock; do
    command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
done

mkdir -p "$STATE_DIR"
exec 9>"$STATE_DIR/ota-update.lock"
if ! flock -n 9; then
    say "Another release check is already running; skipping."
    exit 0
fi

API_URL="https://api.github.com/repos/$REPO_SLUG/releases/latest"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
RELEASE_JSON_FILE="$WORKDIR/release.json"
say "Checking the latest published release of $REPO_SLUG"
if ! HTTP_STATUS="$(curl --silent --show-error --location \
    --connect-timeout 10 --max-time 60 \
    -H 'Accept: application/vnd.github+json' \
    -H 'X-GitHub-Api-Version: 2022-11-28' \
    --output "$RELEASE_JSON_FILE" --write-out '%{http_code}' \
    "$API_URL")"; then
    die "Could not contact GitHub to check for releases."
fi
case "$HTTP_STATUS" in
    200) ;;
    404)
        say "No published release found for $REPO_SLUG yet; nothing to update."
        exit 0
        ;;
    *) die "GitHub's release check failed with HTTP $HTTP_STATUS." ;;
esac
RELEASE_JSON="$(cat "$RELEASE_JSON_FILE")"

if ! LATEST_TAG="$(jq -er '.tag_name | strings | select(length > 0)' <<< "$RELEASE_JSON")"; then
    die "GitHub's latest-release response did not contain a tag name."
fi

CURRENT_TAG=""
if [ -r "$VERSION_FILE" ]; then
    IFS= read -r CURRENT_TAG < "$VERSION_FILE" || true
fi

if [ "$CHECK_ONLY" = 1 ]; then
    if [ -n "$CURRENT_TAG" ] && [ "$CURRENT_TAG" = "$LATEST_TAG" ]; then
        say "Already up to date ($LATEST_TAG)."
    else
        say "Release update available: ${CURRENT_TAG:-installed version unknown} → $LATEST_TAG."
    fi
    exit 0
fi

if [ "$CURRENT_TAG" = "$LATEST_TAG" ] && [ "$FORCE" = 0 ]; then
    say "Already up to date ($LATEST_TAG)."
    exit 0
fi

if ! TARBALL_URL="$(jq -er '.tarball_url | strings | select(length > 0)' <<< "$RELEASE_JSON")"; then
    die "GitHub's latest-release response did not contain a source archive URL."
fi
case "${TARBALL_URL,,}" in
    "https://api.github.com/repos/${REPO_SLUG,,}/tarball/"*|"https://codeload.github.com/${REPO_SLUG,,}/"*) ;;
    *) die "GitHub returned an unexpected source archive URL; refusing to download it." ;;
esac

ARCHIVE="$WORKDIR/release.tar.gz"
SOURCE_DIR="$WORKDIR/source"
mkdir -p "$SOURCE_DIR"
say "Downloading release $LATEST_TAG"
curl --fail --silent --show-error --location \
    --connect-timeout 10 --max-time 180 \
    -H 'Accept: application/vnd.github+json' \
    "$TARBALL_URL" --output "$ARCHIVE" || die "Could not download release $LATEST_TAG."

tar -xzf "$ARCHIVE" --strip-components=1 -C "$SOURCE_DIR" || \
    die "Could not unpack the GitHub release archive."

# GitHub source archives contain one top-level directory. Also support a
# repository that wraps its actual dotfiles in a subdirectory.
RICE_ROOT="$SOURCE_DIR"
if [ ! -f "$RICE_ROOT/hypr/hyprland.conf" ]; then
    CONF="$(find "$SOURCE_DIR" -maxdepth 4 -path '*/hypr/hyprland.conf' -print -quit 2>/dev/null || true)"
    RICE_ROOT="${CONF%/hypr/hyprland.conf}"
fi
if [ -z "$RICE_ROOT" ] || [ ! -f "$RICE_ROOT/hypr/hyprland.conf" ]; then
    die "The release archive does not contain hypr/hyprland.conf; refusing to apply it."
fi

CURRENT_THEME="$(cat "$CFG/current_theme" 2>/dev/null || true)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/.config-backup-rice-ota-$STAMP"
mkdir -p "$BACKUP"
for d in hypr waybar wofi kitty dunst eww scripts themes wallpapers fuzzel gtk-3.0 gtk-4.0 qt5ct; do
    [ -d "$CFG/$d" ] && cp -a "$CFG/$d" "$BACKUP/"
done
[ -f "$CFG/current_theme" ] && cp -a "$CFG/current_theme" "$BACKUP/"
USER_UNIT_DIR="$CFG/systemd/user"
for unit in rice-ota.service rice-ota.timer; do
    if [ -f "$USER_UNIT_DIR/$unit" ]; then
        mkdir -p "$BACKUP/systemd/user"
        cp -a "$USER_UNIT_DIR/$unit" "$BACKUP/systemd/user/"
    fi
done
printf 'Restore with: cp -a %s/. ~/.config/\n' "$BACKUP" > "$BACKUP/RESTORE.txt"

say "Applying release $LATEST_TAG"
for d in hypr waybar wofi kitty dunst eww scripts themes wallpapers fuzzel gtk-3.0 gtk-4.0 qt5ct; do
    if [ -d "$RICE_ROOT/$d" ]; then
        mkdir -p "$CFG/$d"
        if [ "$d" = scripts ] && [ -f "$RICE_ROOT/scripts/ota-update.sh" ]; then
            # Don't truncate the script currently executing; replace it atomically below.
            find "$RICE_ROOT/scripts" -mindepth 1 -maxdepth 1 ! -name ota-update.sh \
                -exec cp -a -t "$CFG/scripts" -- {} +
        else
            cp -a "$RICE_ROOT/$d/." "$CFG/$d/"
        fi
    fi
done
if [ -f "$RICE_ROOT/scripts/ota-update.sh" ]; then
    UPDATE_SCRIPT_TMP="$CFG/scripts/.ota-update.sh.new.$$"
    cp -a "$RICE_ROOT/scripts/ota-update.sh" "$UPDATE_SCRIPT_TMP"
    chmod +x "$UPDATE_SCRIPT_TMP"
    mv -f "$UPDATE_SCRIPT_TMP" "$CFG/scripts/ota-update.sh"
fi

# Keep already-installed units in sync with the scripts, without opting users
# who never enabled the timer into automatic updates.
UNITS_CHANGED=0
for unit in rice-ota.service rice-ota.timer; do
    if [ -f "$USER_UNIT_DIR/$unit" ] && [ -f "$CFG/scripts/$unit" ]; then
        cp -a "$CFG/scripts/$unit" "$USER_UNIT_DIR/$unit"
        UNITS_CHANGED=1
    fi
done
if [ "$UNITS_CHANGED" = 1 ] && command -v systemctl >/dev/null 2>&1; then
    systemctl --user daemon-reload >/dev/null 2>&1 || \
        warn "Updated the rice's systemd units but couldn't reload systemd --user."
fi

chmod +x "$CFG"/scripts/*.sh 2>/dev/null || true
chmod +x "$CFG"/eww/scripts/*.sh 2>/dev/null || true
chmod +x "$CFG"/hypr/scripts/*.sh 2>/dev/null || true

say "Re-applying your current theme (${CURRENT_THEME:-default})"
if [ -n "$CURRENT_THEME" ] && [ -d "$CFG/themes/$CURRENT_THEME" ] && [ -x "$CFG/scripts/theme-switch.sh" ]; then
    if [ "$QUIET" = 1 ]; then
        "$CFG/scripts/theme-switch.sh" "$CURRENT_THEME" >/dev/null 2>&1 || \
            warn "Updated files, but couldn't re-apply theme '$CURRENT_THEME'."
    else
        "$CFG/scripts/theme-switch.sh" "$CURRENT_THEME" || \
            warn "Updated files, but couldn't re-apply theme '$CURRENT_THEME'."
    fi
fi

# Record the tag only after the files have been copied successfully.
VERSION_TMP="$VERSION_FILE.tmp.$$"
printf '%s\n' "$LATEST_TAG" > "$VERSION_TMP"
mv -f "$VERSION_TMP" "$VERSION_FILE"

command -v hyprctl >/dev/null 2>&1 && hyprctl reload >/dev/null 2>&1 || true
notify-send -a "Rice OTA" "Updated to GitHub release $LATEST_TAG" 2>/dev/null || true
say "Updated to $LATEST_TAG. Backup kept at: $BACKUP"
