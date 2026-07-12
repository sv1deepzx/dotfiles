#!/usr/bin/env bash
#
# bootstrap.sh — one-shot setup for a new machine.
#
# Run it manually after cloning your dotfiles:   ./bootstrap.sh
# It is NOT run by chezmoi. The install lists (PACMAN_PKGS, AUR_PKGS) live in
# packages.sh — regenerate that from your current system with ./gen-packages.sh.
# Edit REMOVE_PKGS / REPOS below directly.
# Safe to re-run: installs use --needed, clones skip repos that already exist,
# and removals only touch packages that are actually installed.

set -uo pipefail   # note: no -e, so one failed step won't abort the whole run

# ─────────────────────────────  EDIT THESE  ──────────────────────────────────

PROJECTS_DIR="$HOME/projects"

# KDE / other packages to remove (you'll be asked to confirm)
REMOVE_PKGS=(
    # kmail elisa khelpcenter kmahjongg kpat
)

# Git repos to clone into $PROJECTS_DIR (one URL per line)
REPOS=(
    # git@github.com:sv1deepzx/some-project.git
)

# ──────────────────────────────────────────────────────────────────────────────

msg()  { printf '\n\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  ! %s\033[0m\n' "$*"; }

command -v pacman >/dev/null || { echo "This script is for Arch-based systems (pacman not found)."; exit 1; }
[ "$EUID" -eq 0 ] && { echo "Run as your normal user, not root — it uses sudo where needed."; exit 1; }

# Record the provisioning cutoff (the moment before we install anything) if it
# isn't set yet. The `deps` shell function and gen-packages.sh use it to tell the
# packages you install apart from the ones the installer left behind.
CUTOFF="${XDG_STATE_HOME:-$HOME/.local/state}/deps-cutoff"
if [[ ! -f $CUTOFF ]]; then
    mkdir -p "$(dirname "$CUTOFF")"
    date +%Y-%m-%dT%H:%M:%S > "$CUTOFF"
    msg "Recorded provisioning cutoff → $(cat "$CUTOFF")"
fi

# Load the install lists from packages.sh (sits next to this script).
here="$(dirname "$(realpath "$0")")"
if [[ -f "$here/packages.sh" ]]; then
    source "$here/packages.sh"
else
    warn "packages.sh not found next to bootstrap.sh — nothing to install"
    PACMAN_PKGS=(); AUR_PKGS=()
fi

# 1. Install official-repo packages ------------------------------------------------
if ((${#PACMAN_PKGS[@]})); then
    msg "Installing ${#PACMAN_PKGS[@]} pacman package(s)"
    sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}" || warn "some pacman packages failed"
fi

# 2. Install AUR packages ----------------------------------------------------------
if ((${#AUR_PKGS[@]})); then
    if command -v paru >/dev/null; then
        msg "Installing ${#AUR_PKGS[@]} AUR package(s)"
        paru -S --needed --noconfirm "${AUR_PKGS[@]}" || warn "some AUR packages failed"
    else
        warn "paru not found — skipping AUR packages (${AUR_PKGS[*]})"
    fi
fi

# 3. Remove unwanted packages ------------------------------------------------------
if ((${#REMOVE_PKGS[@]})); then
    installed=()
    for p in "${REMOVE_PKGS[@]}"; do
        pacman -Qq "$p" &>/dev/null && installed+=("$p")
    done
    if ((${#installed[@]})); then
        msg "Removing ${#installed[@]} package(s) — review the list before confirming"
        sudo pacman -Rns "${installed[@]}"   # intentionally no --noconfirm
    else
        msg "Nothing to remove (none of the listed packages are installed)"
    fi
fi

# 4. Clone repos -------------------------------------------------------------------
if ((${#REPOS[@]})); then
    msg "Cloning repos into $PROJECTS_DIR"
    mkdir -p "$PROJECTS_DIR"
    for url in "${REPOS[@]}"; do
        name=$(basename "$url" .git)
        dest="$PROJECTS_DIR/$name"
        if [ -d "$dest" ]; then
            echo "  skip (exists): $name"
        elif git clone "$url" "$dest"; then
            echo "  cloned: $name"
        else
            warn "clone failed: $url"
        fi
    done
fi

# 5. System maintenance: cache + snapshot cleanup ----------------------------------
msg "Configuring maintenance timers"
sudo pacman -S --needed --noconfirm snapper pacman-contrib

# pacman cache: keep only the newest cached version of each package
echo "PACCACHE_ARGS='-k1'" | sudo tee /etc/conf.d/pacman-contrib >/dev/null
sudo systemctl enable --now paccache.timer

# btrfs snapshots: lean retention (only if a 'root' snapper config exists)
if sudo snapper -c root get-config &>/dev/null; then
    sudo snapper -c root set-config \
        NUMBER_CLEANUP=yes NUMBER_LIMIT=10 NUMBER_LIMIT_IMPORTANT=5 \
        TIMELINE_CREATE=no TIMELINE_CLEANUP=yes \
        TIMELINE_LIMIT_HOURLY=5 TIMELINE_LIMIT_DAILY=7 \
        TIMELINE_LIMIT_WEEKLY=0 TIMELINE_LIMIT_MONTHLY=0 TIMELINE_LIMIT_YEARLY=0
    sudo systemctl enable --now snapper-cleanup.timer
else
    warn "no snapper 'root' config — skipping snapshot retention"
fi

msg "Bootstrap complete."
