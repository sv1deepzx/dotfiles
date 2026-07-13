# dotfiles

Personal CachyOS + KDE Plasma (Wayland) setup, managed with [chezmoi](https://chezmoi.io).
Configs are chezmoi-managed; packages, repos, and system maintenance are handled by
`bootstrap.sh`.

## New-machine setup

Assumes a fresh CachyOS install (KDE Plasma), logged in as your normal user, online.

### 1. Install chezmoi and clone this repo

```sh
sudo pacman -S --needed git chezmoi
chezmoi init sv1deepzx        # clones to ~/.local/share/chezmoi — does NOT apply yet
```

`chezmoi init sv1deepzx` is shorthand for `https://github.com/sv1deepzx/dotfiles.git`
(HTTPS, so no SSH key needed for a public repo). This also brings down `bootstrap.sh`
and friends, which live in the repo but are never deployed to `$HOME`.

### 2. (optional) SSH key — only if you want your project repos cloned

The `REPOS` in `bootstrap.sh` use `git@github.com:…` URLs, so they need an SSH key
registered on GitHub:

```sh
ssh-keygen -t ed25519 -C "sdeepzx@gmail.com"
cat ~/.ssh/id_ed25519.pub     # add at https://github.com/settings/keys
```

Skip it and bootstrap just warns and moves on — re-run it later once the key is set up.

### 3. Run bootstrap

```sh
~/.local/share/chezmoi/bootstrap.sh
```

In order, it: records the provisioning cutoff → installs your packages (repo + AUR +
language) → removes unwanted packages (asks first) → clones your repos → sets up the
pacman-cache and btrfs-snapshot cleanup timers. Needs your sudo password. Idempotent —
safe to re-run.

### 4. Apply the dotfiles

```sh
chezmoi apply
```

Run this **after** bootstrap, so the tools the configs expect (starship, zoxide, fzf…)
already exist and your first shell isn't full of "command not found".

### 5. Finishing touches

- Set the wallpaper from `~/.local/share/chezmoi/Nordic-mountain-wallpaper.jpg`
  (System Settings → Wallpaper).
- Log out and back in (or reboot) to pick up the zsh, KDE, and service changes.

## Why this order

- **chezmoi first** — it's what clones everything, including `bootstrap.sh` (which is in
  the repo but chezmoi-ignored, so it isn't written to `$HOME`).
- **bootstrap before apply** — install the software before laying down configs that
  reference it.
- **the cutoff is automatic** — bootstrap stamps `~/.local/state/deps-cutoff` at the
  moment it runs (before installing anything), so `deps` correctly tells your packages
  apart from the installer's on this machine too.

## Keeping it in sync

- Installed a package you want to keep? Run `gendeps` (regenerates `packages.sh`), then commit.
- Changed a tracked config in a GUI/editor? `chezmoi re-add`, then commit.
- Language-level installs (`npm -g`, `cargo install`, `pipx`) can't be auto-detected —
  add them by hand to the `NPM_PKGS` / `CARGO_PKGS` / `PIPX_PKGS` arrays in `bootstrap.sh`.
- `deps` lists what you've installed since provisioning; `deps -a` lists everything.

## Layout

| Path | What it is |
|------|------------|
| `dot_*`, `dot_config/*` | Dotfiles chezmoi deploys to `$HOME` (zshrc, kitty, gitconfig, KDE…) |
| `dot_config/modify_kwinrc` | Keeps KWin settings reproducible without the volatile `[Tiling]` churn |
| `bootstrap.sh` | New-machine provisioning (repo-only, not deployed) |
| `packages.sh` | Generated install list sourced by bootstrap — refresh with `gendeps` |
| `gen-packages.sh` | Regenerates `packages.sh` from the live system (aliased to `gendeps`) |
| `Nordic-mountain-wallpaper.jpg` | Wallpaper, applied by hand |
| _(not in repo)_ `~/.local/state/deps-cutoff` | Per-machine provisioning timestamp |
