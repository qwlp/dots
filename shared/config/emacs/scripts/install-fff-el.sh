#!/usr/bin/env bash
set -euo pipefail

fff_el_rev=fa713c34176e52b0699ca8935676044a1f6faf44
# Keep this aligned with the fff-nvim revision in fff.el's flake.lock: the
# Emacs frontend decodes the C structs at fixed ABI offsets.
fff_nvim_rev=8912a1abdbdcb91b73cda91058b378e4233ab58f
emacs_ffi_rev=037c8c5e718a7e335bde041b1b19f86ee879e508
install_dir="${XDG_STATE_HOME:-$HOME/.local/state}/emacs/site-lisp/fff"
build_dir=$(mktemp -d)
trap 'rm -rf "$build_dir"' EXIT

git clone --quiet https://github.com/JonasThowsen/fff.el "$build_dir/fff.el"
git clone --quiet https://github.com/dmtrKovalenko/fff.nvim "$build_dir/fff.nvim"
git clone --quiet https://github.com/tromey/emacs-ffi "$build_dir/emacs-ffi"
git -C "$build_dir/fff.el" checkout --quiet "$fff_el_rev"
git -C "$build_dir/fff.nvim" checkout --quiet "$fff_nvim_rev"
git -C "$build_dir/emacs-ffi" checkout --quiet "$emacs_ffi_rev"

cargo build --release --manifest-path "$build_dir/fff.nvim/Cargo.toml" -p fff-c
cc -shared -fPIC -I/usr/include \
  -o "$build_dir/emacs-ffi/ffi-module.so" \
  "$build_dir/emacs-ffi/ffi-module.c" -lltdl -lffi

mkdir -p "$install_dir"
install -m 0644 "$build_dir/fff.el/emacs/fff.el" "$install_dir/fff.el"
install -m 0644 "$build_dir/fff.el/emacs/ffi.el" "$install_dir/ffi.el"
install -m 0755 "$build_dir/emacs-ffi/ffi-module.so" "$install_dir/ffi-module.so"
install -m 0755 "$build_dir/fff.nvim/target/release/libfff_c.so" "$install_dir/libfff_c.so"

printf 'Installed fff.el in %s\n' "$install_dir"
