#!/usr/bin/env bash

set -euo pipefail

if [[ ! -r /etc/arch-release ]]; then
    printf 'This bootstrap supports Arch Linux only.\n' >&2
    exit 1
fi

packages=(
    emacs-wayland
    git
    base-devel
    pkgconf
    cmake
    ninja
    ccache
    gperf
    openssl
    zlib
    ttf-firacode-nerd
    yt-dlp
    mpv
    go
    gopls
    typst
    odin
)

missing=()
for package in "${packages[@]}"; do
    if ! pacman -Q "$package" &>/dev/null; then
        missing+=("$package")
    fi
done

if ((${#missing[@]})); then
    printf 'Installing missing Arch packages: %s\n' "${missing[*]}"
    sudo pacman -S --needed "${missing[@]}"
else
    printf 'Arch packages are already installed.\n'
fi

printf '\nBootstrap complete. Start Emacs; remaining packages and grammars install automatically.\n'
