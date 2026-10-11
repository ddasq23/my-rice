#!/usr/bin/env bash
# ~/.config/hypr/scripts/pkg-search.sh <query>
#
# Prints search results for the pkg-menu fzf list, one package per line:
#   <name> TAB <display text>
# Official repos come from `pacman -Ss` (local sync DB, instant); AUR results
# come from the AUR RPC (name + description, with votes and popularity).
# fzf calls this on every keystroke (fzf --bind 'change:reload:...').
# Needs: pacman, curl, jq, awk.

Q="${1:-}"
# The AUR and pacman both need at least 2 characters to be useful.
[ "${#Q}" -lt 2 ] && exit 0

# --- official repos (core/extra/multilib, local database) -------------------
pacman -Ss -- "$Q" 2>/dev/null | awk '
  /^[^ ]/ {
    split($1, a, "/"); repo = a[1]; name = a[2]; ver = $2
    mark = ($0 ~ /\[installed/) ? "✓" : " "
    next
  }
  {
    sub(/^ +/, "")
    printf "%s\t%s %-5s %-34s %-18s %-10s %s\n", name, mark, "repo", name, ver, repo, $0
  }' | head -n 150

# --- AUR (RPC v5 search, sorted by popularity) -------------------------------
ENC="$(jq -rn --arg q "$Q" '$q|@uri')"
curl -fsS --max-time 5 "https://aur.archlinux.org/rpc/v5/search/${ENC}?by=name-desc" 2>/dev/null \
  | jq -r '.results | sort_by(-.Popularity) | .[:150][]
           | [.Name, .Version, (.NumVotes|tostring), (.Popularity|tostring), (.Description // "")] | @tsv' \
  | awk -F'\t' '{
      printf "%s\t  %-5s %-34s %-18s ★%-6s pop %-8.2f %s\n", $1, "aur", $1, $2, $3, $4, $5
    }'
