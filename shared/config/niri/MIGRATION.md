# Migrating the desktop Niri configuration

Use this on the desktop after pulling the shared laptop/desktop Niri layout.
The shared entry point loads `common.kdl` and then the profile selected by
`active.kdl`.

## 1. Update the checkout

Do not pull over uncommitted machine-local changes:

```sh
cd ~/.dotfiles
git status --short
git pull --ff-only origin main
```

If the status is not empty, preserve those changes before pulling.

## 2. Preserve the desktop's current config

```sh
backup_dir="$HOME/.local/state/niri-migration"
mkdir -p "$backup_dir"
if [ -e "$HOME/.config/niri/config.kdl" ] && \
   [ ! -e "$backup_dir/config.kdl" ]; then
    cp -aL "$HOME/.config/niri/config.kdl" "$backup_dir/config.kdl"
fi
```

The backup is deliberately dereferenced so it remains usable if the old
config was itself a symlink.

## 3. Link the shared entry point

```sh
mkdir -p ~/.config/niri
ln -sfn ~/.dotfiles/shared/config/niri/config.kdl ~/.config/niri/config.kdl
```

## 4. Select and validate the desktop profile

```sh
~/.dotfiles/shared/config/niri/use-profile desktop
niri validate -c ~/.config/niri/config.kdl
```

The selector reloads a running Niri session. If Niri is not running yet, the
desktop profile will be loaded at the next start.

Verify the selection and link targets:

```sh
readlink ~/.dotfiles/shared/config/niri/active.kdl
readlink -f ~/.config/niri/config.kdl
```

The first command should print `desktop.kdl`; the second should resolve to the
shared `config.kdl` in this checkout.

## Recovery

To return to the pre-migration desktop config:

```sh
if [ -L ~/.config/niri/config.kdl ]; then
    unlink ~/.config/niri/config.kdl
fi
cp -a ~/.local/state/niri-migration/config.kdl ~/.config/niri/config.kdl
```

This removes only the config symlink, never its shared target, before restoring
the backup into place.
