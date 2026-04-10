# dotfiles

## Install

```bash
git clone <repo-url> ~/dotfiles
cd ~/dotfiles
./install.sh
```

Then reboot, and run `exegol install` to pull the pentest Docker image.

## What install.sh does

1. Installs all apt packages
2. Deploys system config files to `/etc/` (requires sudo)
3. Symlinks `~/.config/*`, `~/.local/bin/*`, and root dotfiles to the repo — `git pull` to update
4. Sets zsh as default shell
5. Installs vim-plug for neovim
6. Prompts before installing: pwndbg, Rust, Brave, Docker, Obsidian