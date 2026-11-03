# dotfiles

Minimal Hyprland desktop.

![screenshot](screenshot.png)

## Setup

```sh
git clone https://github.com/bymaul/dotfiles ~/dotfiles
cd ~/dotfiles
sudo pacman -S --needed - < pkglist.txt
./install.sh
```

- Desktop, shell, and terminal configs live here; `install.sh` symlinks them into `$HOME`.
- Safe to re-run. Useful flags: `--dry-run`, `--verify`, `--backup`, `--no-plugins`, `-y/--yes`, `--remove`, `--category core|extras`.
- Categories: `core` (hypr, quickshell, zsh, starship, tmux, git, foot, bin) and `extras` (bat, btop, fastfetch, lazygit, nvim, mise, yazi, agents).
- Install one category: `./install.sh --category core` or a single package: `./install.sh nvim`.

## Theming

Every app color config is generated from one palette file in `theme/palettes/`.

```sh
theme list                       # presets and the active one
theme set gruvbox                # apply a preset everywhere
theme set wallpaper              # derive the palette from the current wallpaper (matugen)
theme set wallpaper --image ~/Pictures/wall.jpg
theme apply                      # re-render the saved scheme
```

Presets ship for Vague, Gruvbox, Catppuccin Mocha, Tokyo Night, and Nord. The active scheme is stored as `colorscheme` in `~/.local/share/quickshell/settings.json`; Quickshell reads the rendered palette from `~/.local/state/quickshell/palette.json`. Adding a preset is just dropping a new JSON file in `theme/palettes/`.

foot and Hyprland reload immediately. btop, yazi, lazygit, and nvim pick up the change on next launch.

## Notes

- Needs a Nerd Font. `starship` installs itself on first `zsh` run.
- Power, display scale, and theming live in the Settings popup. Lid-close handling needs `qs-power-logind --apply` + reboot.
- Tweak Hyprland directly in `hypr/hyprland.lua`.
- ASUS laptops only: `sudo pacman -S asusctl` unlocks Quiet / Balanced / Performance + charge limit.
