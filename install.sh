#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

info() { printf '\033[32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[31m[-]\033[0m %s\n' "$*" >&2; exit 1; }
ask()  { printf '\033[34m[?]\033[0m %s [y/N] ' "$*"; read -r _ans; [ "${_ans,,}" = "y" ]; }

[ "$EUID" -eq 0 ]            && die "Run as a regular user (sudo will be called when needed)"
command -v sudo >/dev/null   || die "sudo not found"

# ── 1. System packages ────────────────────────────────────────────────────────

info "Updating package lists..."
sudo apt-get update -qq

info "Installing packages..."
sudo apt-get install -y \
    7zip alacritty arandr autorandr brightnessctl cmake curl \
    dunst entr etckeeper feh flameshot gcc gdb git i3 i3lock \
    keepassxc linux-headers-amd64 maim make mingw-w64 mpv nasm \
    neovim numlockx picom pipx pkg-config polybar pulsemixer \
    python3 python3-pip rofi rsync screen sxiv thunar tmux vim \
    wget wireguard xterm zsh zsh-autosuggestions zsh-syntax-highlighting

# ── 2. System config files ────────────────────────────────────────────────────

info "Deploying system config files..."
sudo install -Dm644 "$DOTFILES/etc/X11/xorg.conf.d/20-keyboard.conf" \
    /etc/X11/xorg.conf.d/20-keyboard.conf
sudo install -Dm644 "$DOTFILES/etc/modprobe.d/kvm-blacklist.conf" \
    /etc/modprobe.d/kvm-blacklist.conf
sudo install -Dm644 "$DOTFILES/etc/bash.bashrc" /etc/bash.bashrc
sudo install -Dm644 "$DOTFILES/etc/screenrc"    /etc/screenrc
sudo install -Dm644 "$DOTFILES/etc/tmux.conf"   /etc/tmux.conf
sudo install -Dm644 "$DOTFILES/etc/vim/vimrc"   /etc/vim/vimrc

# ── 3. User dotfiles (symlinks) ───────────────────────────────────────────────

info "Creating user directories..."
mkdir -p \
    "$HOME/.config" \
    "$HOME/.local/bin" \
    "$HOME/.local/share/applications" \
    "$HOME/.local/state" \
    "$HOME/.cache"

info "Linking ~/.config/* directories..."
for d in "$DOTFILES"/.config/*/; do
    ln -sfn "$d" "$HOME/.config/$(basename "$d")"
done

info "Linking ~/.local/bin scripts..."
for f in "$DOTFILES"/.local/bin/*; do
    chmod +x "$f"
    ln -sf "$f" "$HOME/.local/bin/$(basename "$f")"
done

info "Linking desktop entries..."
for f in "$DOTFILES"/.local/share/applications/*; do
    ln -sf "$f" "$HOME/.local/share/applications/$(basename "$f")"
done

info "Linking root dotfiles..."
ln -sf  "$DOTFILES/.profile"     "$HOME/.profile"
ln -sf  "$DOTFILES/.xsession"    "$HOME/.xsession"
ln -sf  "$DOTFILES/.gdbinit"     "$HOME/.gdbinit"
ln -sf  "$DOTFILES/.editrc"      "$HOME/.editrc"
ln -sfn "$DOTFILES/.binaryninja" "$HOME/.binaryninja"

# ── 4. Default shell ──────────────────────────────────────────────────────────

if [ "$SHELL" != "$(command -v zsh)" ]; then
    info "Setting zsh as default shell..."
    chsh -s "$(command -v zsh)"
fi

# ── 5. Neovim plug ───────────────────────────────────────────────────────────

info "Installing vim-plug for neovim..."
curl -fsSLo "${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/autoload/plug.vim" \
    --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# ── 6. Optional tools ─────────────────────────────────────────────────────────

if ask "Install pwndbg?"; then
    info "Installing pwndbg..."
    curl -qsL 'https://install.pwndbg.re' | sh -s -- -t pwndbg-gdb
fi

if ask "Install Rust (rustup)?"; then
    info "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

if ask "Install Brave browser?"; then
    info "Installing Brave..."
    curl -fsS https://dl.brave.com/install.sh | sh
fi

# ── 7. pipx tools ─────────────────────────────────────────────────────────────

info "Installing pipx tools (ropper, exegol, argcomplete)..."
pipx install ropper
pipx install exegol
pipx install argcomplete

# ── 8. Docker Engine ──────────────────────────────────────────────────────────

if ask "Install Docker Engine?"; then
    info "Installing Docker..."
    sudo apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg \
        -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    . /etc/os-release
    sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: ${VERSION_CODENAME}
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
    sudo apt-get update -qq
    sudo apt-get install -y \
        docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker "$USER"
    warn "Docker: log out and back in for group membership to take effect"
fi

# ── 9. Obsidian ───────────────────────────────────────────────────────────────

if ask "Install Obsidian?"; then
    info "Installing Obsidian..."
    wget -qO /tmp/obsidian.deb \
        https://github.com/obsidianmd/obsidian-releases/releases/download/v1.12.7/obsidian_1.12.7_amd64.deb
    sudo dpkg -i /tmp/obsidian.deb
    rm /tmp/obsidian.deb
fi

# ── Done ──────────────────────────────────────────────────────────────────────

info "Install complete."
info "Next: run 'exegol install' to pull the pentest Docker image."
warn "Reboot (or re-login) to apply: shell change, docker group, KVM blacklist."
