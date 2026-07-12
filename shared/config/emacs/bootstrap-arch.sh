#!/usr/bin/env bash

set -euo pipefail

if [[ ! -r /etc/arch-release ]]; then
    printf 'This bootstrap supports Arch Linux only.\n' >&2
    exit 1
fi

packages=(
    emacs-wayland
    git
    rclone
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

tdlib_prefix="${HOME}/.local"
tdlib_version="1.8.64"
tdlib_commit="0ce538bbe1b3e3bc488ae04590ec06b2197c9c5d"
tdlib_header="${tdlib_prefix}/include/td/telegram/td_json_client.h"
tdlib_library="${tdlib_prefix}/lib/libtdjson.so.${tdlib_version}"

if [[ ! -f "$tdlib_header" || ! -f "$tdlib_library" ]]; then
    # Compile in RAM (/tmp is tmpfs on Arch) to maximize I/O performance
    build_root="/tmp/emacs-bootstrap/tdlib"

    # Auto-detect available cores. On your i7-13620H (16 threads), this will target 15 jobs.
    default_jobs=$(($(nproc 2>/dev/null || echo 16) - 1))
    build_jobs="${TDLIB_BUILD_JOBS:-$default_jobs}"

    printf 'Building TDLib %s in %s using %s parallel jobs\n' "$tdlib_version" "$build_root" "$build_jobs"

    # Reset build directory
    rm -rf "$build_root"
    mkdir -p "$build_root"

    git clone --filter=blob:none https://github.com/tdlib/td.git "$build_root/source"
    git -C "$build_root/source" checkout "$tdlib_commit"

    # Configure using Ninja and ccache to maximize speed
    cmake \
        -S "$build_root/source" \
        -B "$build_root/build" \
        -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$tdlib_prefix" \
        -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
        -DCMAKE_C_COMPILER_LAUNCHER=ccache

    cmake --build "$build_root/build" \
        --target tdjson tdjson_static \
        --parallel "$build_jobs"

    cmake --install "$build_root/build"

    # Clean up RAM immediately after a successful install
    rm -rf "$build_root"
else
    printf 'TDLib %s is already installed in %s.\n' "$tdlib_version" "$tdlib_prefix"
fi

printf '\nBootstrap complete. Start Emacs; remaining packages and grammars install automatically.\n'
